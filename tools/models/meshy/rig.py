"""Meshy character -> clean rig: unit scale, joints centred in the body, new skin weights.

blender -b --factory-startup --python-exit-code 1 -P tools/models/meshy/rig.py [-- name ...]
In:  out/<name>/rigged.glb (Meshy auto-rig: 24 bones, one mesh, one 2K texture; not modified), or for a model
     that was not auto-rigged src/<name>_meshy.glb through fit_skeleton.py (the same 24 bones fitted to the mesh).
Out: work/<name>_rig.blend, work/<name>_rig.json (joints moved, part sizes).

Meshy's weights pull coats and skirts with the thighs, put hoods on the head and its joints sit at the body
surface (spine at the belly, shoulders behind the arm), so a UAL walk folds the body. Here:
- Joints: elbows, wrists, knees, ankles centred on the limb cross-section; shoulders on the upper arm's
  centre line; spine joints in the torso's depth, slightly towards the back; bone tails at the child joint.
- Weights are a function of position only, so nested shells (Meshy builds coat, skirt and lining as separate
  surfaces at the same place) move together and never cross:
  arms: chain Arm/ForeArm/Hand inside a capsule around the arm, blended into the torso around the shoulder;
  torso: height bands between the spine joints, clavicle on the shoulder tops, head above the jaw (hoods and
  collars outside the skull stay on the neck/chest);
  legs: chain UpLeg/Leg/Foot/ToeBase inside a capsule around the leg;
  coats and skirts below the crotch (outside the leg capsules): Hips, sliding to the thighs (and a little to
  the shins under the knee) towards the hem, split left/right with a soft centre band.
- Two neighbour-averaging passes, max 4 influences.
"""
import bpy, bmesh, json, math, sys
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from meshy_lib import NAMES, SIDES, CHILD, SPINE, smooth, chain_param, cum_lengths, chain_split, section

WORK = HERE / "work"
WORK.mkdir(exist_ok=True)
(WORK / ".gdignore").touch()          # .blend files: keep Godot from importing them
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
# Per character: follow = thigh share at the hem of a coat/skirt (0..1), calf = shin share at the hem below
# the knee, centre = half width (m) of the left/right blend across the front/back of a coat or skirt.
CFG = {
    "player": dict(follow=0.55, calf=0.0, centre=0.05),
    "mom": dict(follow=0.85, calf=0.3, centre=0.13),
    "child": dict(follow=0.55, calf=0.0, centre=0.04),
    "grandpa": dict(follow=0.8, calf=0.15, centre=0.12),
    "rescuer": dict(follow=0.55, calf=0.0, centre=0.05),
    "farmer": dict(follow=0.55, calf=0.0, centre=0.05),
}


def load(name):
    if not (HERE / "out" / name / "rigged.glb").exists():
        from fit_skeleton import fit
        return fit(name)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.import_scene.gltf(filepath=str(HERE / "out" / name / "rigged.glb"))
    for o in list(bpy.data.objects):
        if o.type == "MESH" and not o.data.materials:          # Meshy's stray Icosphere
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = next(o for o in bpy.data.objects if o.type == "MESH")
    rig.name = rig.data.name = name + "_rig"
    body.name = body.data.name = name + "_body"
    if rig.animation_data:
        rig.animation_data_clear()
    mw = body.matrix_world.copy()
    body.parent = None
    body.data.transform(mw)
    body.matrix_world = Matrix.Identity(4)
    rig.data.transform(rig.matrix_world)
    rig.matrix_world = Matrix.Identity(4)
    body.parent = rig
    body.matrix_parent_inverse = Matrix.Identity(4)
    next(m for m in body.modifiers if m.type == "ARMATURE").object = rig
    return rig, body


def welded(body):
    """Positions of the welded mesh (Meshy splits every UV chart), map original -> welded, neighbours."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.verts.ensure_lookup_table()
    W = np.array([tuple(v.co) for v in bm.verts])
    from mathutils.kdtree import KDTree
    kd = KDTree(len(W))
    for i, p in enumerate(W):
        kd.insert(p, i)
    kd.balance()
    to_w = np.array([kd.find(v.co)[1] for v in body.data.vertices])
    nbr = [[e.other_vert(v).index for e in v.link_edges] for v in bm.verts]
    tris = np.array([[tuple(l.vert.co) for l in t] for t in bm.calc_loop_triangles()])
    elen = [[e.calc_length() for e in v.link_edges] for v in bm.verts]
    bm.free()
    return W, to_w, nbr, elen, tris


def box_centre(q):
    return (q.min(axis=0) + q.max(axis=0)) / 2


def fix_joints(rig, W, tris, rep):
    """Centre the joints in the body and point every bone at its child."""
    J = {b.name: np.array(b.head_local) for b in rig.data.bones}
    new = {k: v.copy() for k, v in J.items()}
    height = W[:, 2].max()
    # arms: nearly horizontal T-pose, cut perpendicular to shoulder -> wrist
    for s, sgn in SIDES:
        sh, el, wr = J[s + "Arm"], J[s + "ForeArm"], J[s + "Hand"]
        u = (wr - sh) / np.linalg.norm(wr - sh)
        e_fwd = np.array([0, 1.0, 0]) - u * u[1]
        e_fwd /= np.linalg.norm(e_fwd)
        e_up = np.cross(u, e_fwd)
        rel = W - sh
        t = rel @ u
        perp = rel - np.outer(t, u)
        dist = np.linalg.norm(perp, axis=1)
        L = float((wr - sh) @ u)
        t_el = float((el - sh) @ u)

        def centre_at(tt, width=None, rmax=0.13):
            p = section(tris, sh + u * tt, u) - sh
            p = p - np.outer(p @ u, u)
            p = p[np.linalg.norm(p, axis=1) < rmax]
            if len(p) < 4:
                return None
            c = box_centre(np.stack([p @ e_fwd, p @ e_up], axis=1))
            return sh + u * tt + e_fwd * c[0] + e_up * c[1]

        cen = [(tt, centre_at(tt)) for tt in np.linspace(0.45 * t_el, 0.95 * L, 24)]
        cen = [(tt, c) for tt, c in cen if c is not None]
        upper = np.array([c for tt, c in cen if tt < 0.9 * t_el])
        # straight line through the upper arm centres, extended back to the shoulder
        tu = (upper - sh) @ u
        A = np.stack([tu, np.ones_like(tu)], axis=1)
        coef, *_ = np.linalg.lstsq(A, upper, rcond=None)
        new[s + "Arm"] = coef[1] + coef[0] * 0.0
        new[s + "Arm"][0] = sh[0]
        new[s + "ForeArm"] = centre_at(t_el, 0.012)
        new[s + "Hand"] = centre_at(L - 0.01, 0.012)
        for b in ("ForeArm", "Hand"):
            if new[s + b] is None:
                print("NO CENTRE", s + b, flush=True)
                new[s + b] = J[s + b].copy()
        # clavicle head stays; its tail follows the shoulder
    # legs: vertical, horizontal cuts
    for s, sgn in SIDES:
        hip, kn, an = J[s + "UpLeg"], J[s + "Leg"], J[s + "Foot"]

        def leg_centre(z, around, rmax=0.12):
            q = section(tris, np.array([0, 0, z]), np.array([0, 0, 1.0]))
            q = q[(np.linalg.norm(q[:, :2] - around[:2], axis=1) < rmax) & (q[:, 0] * sgn > 0.0)]
            if len(q) < 4:
                return None, None
            return box_centre(q), q.max(axis=0) - q.min(axis=0)

        a_c, a_size = leg_centre(an[2], an)
        new[s + "Foot"] = np.array([a_c[0], a_c[1], an[2]])
        k_c, k_size = leg_centre(kn[2], kn)
        if k_c is not None and k_size[0] < 0.2:
            new[s + "Leg"] = np.array([k_c[0], k_c[1], kn[2]])
        else:                       # knee hidden in a coat/skirt: on the hip -> ankle line
            f = (hip[2] - kn[2]) / (hip[2] - an[2])
            new[s + "Leg"] = hip + (new[s + "Foot"] - hip) * f
            new[s + "Leg"][2] = kn[2]
        t_c, t_size = leg_centre(hip[2] - 0.17 * height / 1.75, hip)
        if t_c is not None and t_size[0] < 0.19:
            new[s + "UpLeg"][1] = t_c[1]
        else:
            new[s + "UpLeg"][1] = new[s + "Leg"][1]
        rep[s + "_leg_sizes"] = [None if v is None else [round(float(x), 3) for x in v] for v in (t_size, k_size, a_size)]
    # spine: torso depth centre, 15 % of the half depth towards the back (+y); x on the symmetry plane
    for b in ("Hips", "Spine02", "Spine01", "Spine"):
        z = J[b][2]
        q = section(tris, np.array([0, 0, z]), np.array([0, 0, 1.0]))
        q = q[np.abs(q[:, 0]) < 0.1]
        y0, y1 = q[:, 1].min(), q[:, 1].max()
        new[b] = np.array([0.0, (y0 + y1) / 2 + 0.15 * (y1 - y0) / 2, z])
    head_v = W[W[:, 2] > J["Head"][2] + 0.04]
    head_v = head_v[np.abs(head_v[:, 0]) < 0.16]
    hc = box_centre(head_v)
    hd = head_v[:, 1].max() - head_v[:, 1].min()
    new["Head"] = np.array([0.0, hc[1] + 0.15 * hd / 2, J["Head"][2]])
    new["neck"] = np.array([0.0, (new["Spine"][1] + new["Head"][1]) / 2, J["neck"][2]])
    for s, sgn in SIDES:
        new[s + "Shoulder"][1] = (new["Spine"][1] + new[s + "Arm"][1]) / 2
    rep["moved_cm"] = {k: [round(float(x) * 100, 1) for x in new[k] - J[k]] for k in new if np.linalg.norm(new[k] - J[k]) > 0.002}

    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    for k, v in new.items():
        eb[k].head = Vector(v)
    for b in eb:
        if b.name in CHILD:
            b.tail = eb[CHILD[b.name]].head
    for s, _ in SIDES:
        h, f = eb[s + "Hand"], eb[s + "ForeArm"]
        h.tail = h.head + (h.head - f.head).normalized() * 0.08 * height / 1.75
        t = eb[s + "ToeBase"]
        t.tail = t.head + Vector((0, -0.06 * height / 1.75, 0))
    eb["head_end"].head = eb["Head"].head + Vector((0, 0, 0.2 * height / 1.75))
    eb["Head"].tail = eb["head_end"].head
    eb["head_end"].tail = eb["head_end"].head + Vector((0, 0, 0.05))
    eb["headfront"].head = eb["Head"].head + Vector((0, -0.1, 0.05))
    eb["headfront"].tail = eb["headfront"].head + Vector((0, -0.05, 0))
    for b in eb:
        b.use_connect = False
        d = (b.tail - b.head).normalized()
        b.align_roll(Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((0, 0, 1)))
    bpy.ops.object.mode_set(mode="OBJECT")
    return {b.name: np.array(b.head_local) for b in rig.data.bones}, {b.name: np.array(b.tail_local) for b in rig.data.bones}


def hem_height(tris, top):
    """Lowest height where a coat or skirt still crosses the body's centre plane below the crotch (pants
    legs leave a gap at x = 0)."""
    hem = top
    for z in np.arange(top, 0.05, -0.005):
        q = section(tris, np.array([0, 0, z]), np.array([0, 0, 1.0]))
        if (np.abs(q[:, 0]) < 0.006).any():
            hem = z
        else:
            break
    return float(hem)


def build_weights(rig, W, tris, nbr, elen, J, T, cfg, rep):
    names = [b.name for b in rig.data.bones]
    BI = {n: i for i, n in enumerate(names)}
    N = len(W)
    height = W[:, 2].max()
    k = height / 1.75                         # proportions relative to a 1.75 m adult
    x, y, z = W.T
    w = np.zeros((N, len(names)))

    # --- torso bands between the spine joints (by height)
    zs = [J[b][2] for b in SPINE]
    torso = np.zeros((N, len(names)))
    carry = np.ones(N)
    for i, b in enumerate(SPINE):
        if i + 1 < len(SPINE):
            half = 0.45 * (zs[i + 1] - zs[i]) if b != "neck" else 0.02 * k
            if b == "Hips":
                half = 0.03 * k
            nxt = smooth(zs[i + 1] - half, zs[i + 1] + half, z)
        else:
            nxt = np.zeros(N)
        torso[:, BI[b]] += carry * (1 - nxt)
        carry = carry * nxt
    # head: only inside the skull's horizontal radius; hoods, collars and scarves outside it stay on neck/Spine
    head_z = J["Head"][2]
    hv = W[(z > head_z + 0.05 * k) & (np.abs(x) < 0.15 * k)]
    h_c = box_centre(hv)
    h_r = (hv.max(axis=0) - hv.min(axis=0)) / 2
    rad = np.hypot((x - h_c[0]) / h_r[0], (y - h_c[1]) / h_r[1])
    rep["head_box"] = [round(float(v), 3) for v in list(h_c) + list(h_r)]
    out_skull = smooth(1.05, 1.3, rad) * smooth(head_z + 0.12 * k, head_z, z)
    hw = torso[:, BI["Head"]] * out_skull
    torso[:, BI["Head"]] -= hw
    torso[:, BI["neck"]] += hw
    # clavicles carry the shoulder tops
    for s, sgn in SIDES:
        sx = J[s + "Arm"][0] * sgn
        c = 0.6 * smooth(0.35 * sx, 0.85 * sx, x * sgn) * smooth(J[s + "Arm"][2] - 0.1 * k, J[s + "Arm"][2] + 0.02 * k, z)
        torso *= (1 - c)[:, None]
        torso[:, BI[s + "Shoulder"]] += c

    # --- legs and coat/skirt below the crotch
    lower = np.zeros((N, len(names)))
    leg_m = np.zeros(N)
    side_l = smooth(-cfg["centre"], cfg["centre"], x)            # 1 = left (+x)
    hip_z = (J["LeftUpLeg"][2] + J["RightUpLeg"][2]) / 2
    hem = hem_height(tris, hip_z)
    rep["hem_z"] = round(hem, 3)
    below_hem = smooth(hem + 0.01, hem - 0.02, z)
    low = min(hem, (J["LeftLeg"][2] + J["RightLeg"][2]) / 2)
    all_leg = smooth(low, low - 0.04 * k, z)                    # shins and boots: everything is leg
    for s, sgn in SIDES:
        pts = [J[s + "UpLeg"], J[s + "Leg"], J[s + "Foot"], J[s + "ToeBase"], T[s + "ToeBase"]]
        d, sa = chain_param(W, pts)
        cum = cum_lengths(pts)
        # leg capsule radius along the leg: measured below the coat, generous at the thigh
        r = np.interp(sa, [0, cum[1], cum[2], cum[3], cum[4]],
                      np.array([0.11, 0.075, 0.065, 0.06, 0.05]) * k)
        side = smooth(-0.015, 0.015, x * sgn)
        r = r + 0.06 * k * below_hem          # under the coat: wider legs, coat vents hanging lower stay coat
        m = side * np.maximum(1 - smooth(r, r + 0.035 * k, d), all_leg) * smooth(-0.04 * k, 0.07 * k, sa)
        # crotch: the inner top of both thighs stays mostly on Hips, so a wide stride does not tear it
        m *= 1 - 0.7 * (1 - smooth(0.01, 0.05 * k, np.abs(x))) * (1 - smooth(0.1 * k, 0.2 * k, sa))
        split = chain_split(sa, cum, [0.04 * k, 0.03 * k, 0.025 * k])
        for i, b in enumerate(("UpLeg", "Leg", "Foot", "ToeBase")):
            lower[:, BI[s + b]] += m[:, None][:, 0] * split[:, i]
        leg_m += m
    leg_m = np.clip(leg_m, 0, 1)
    # coat / skirt: below the hip joints and outside the leg capsules
    knee_z = (J["LeftLeg"][2] + J["RightLeg"][2]) / 2
    drop = hip_z - z
    follow = cfg["follow"] * smooth(0.0, 0.28 * k, drop)
    calf = cfg["calf"] * smooth(knee_z + 0.04 * k, knee_z - 0.18 * k, z)
    skirt = np.zeros((N, len(names)))
    skirt[:, BI["Hips"]] = 1 - follow
    for s, sgn in SIDES:
        sw = side_l if sgn > 0 else 1 - side_l
        skirt[:, BI[s + "UpLeg"]] += follow * sw * (1 - calf)
        skirt[:, BI[s + "Leg"]] += follow * sw * calf
    below = smooth(hip_z - 0.02 * k, hip_z - 0.1 * k, z)           # where the skirt rule replaces the torso bands
    rest = (1 - leg_m)[:, None] * (below[:, None] * skirt + (1 - below)[:, None] * torso)
    body = lower + rest

    # --- arms: capsule around Arm -> ForeArm -> Hand -> hand tip, blended into the body around the shoulder
    arm_m_total = np.zeros(N)
    final = body.copy()
    for s, sgn in SIDES:
        pts = [J[s + "Arm"], J[s + "ForeArm"], J[s + "Hand"], T[s + "Hand"]]
        d, sa = chain_param(W, pts)
        cum = cum_lengths(pts)
        r = np.interp(sa, [0, cum[1], cum[2], cum[3]], np.array([0.085, 0.075, 0.07, 0.07]) * k)
        # radius limit only along the upper arm (keeps the torso side under the armpit out); past mid upper
        # arm everything along the arm is arm, so fingers spread wider than the capsule stay on the hand
        far = 0.09 * k * smooth(0.45 * cum[1], 0.7 * cum[1], sa)
        radial = 1 - smooth(r + far, r + far + 0.03 * k, d)
        m = smooth(-0.035 * k, 0.045 * k, sa) * radial * smooth(0.0, 0.03, x * sgn)
        split = chain_split(sa, cum, [0.035 * k, 0.02 * k])
        chain = np.zeros((N, len(names)))
        for i, b in enumerate(("Arm", "ForeArm", "Hand")):
            chain[:, BI[s + b]] = split[:, i]
        final = final * (1 - m)[:, None] + chain * m[:, None]
        arm_m_total += m
    w = final
    w /= np.maximum(w.sum(axis=1, keepdims=True), 1e-9)
    # neighbour averaging (edge-length weighted), twice
    for _ in range(2):
        avg = np.zeros_like(w)
        for i in range(N):
            if nbr[i]:
                iw = 1 / np.maximum(np.array(elen[i]), 1e-4)
                avg[i] = (w[nbr[i]] * iw[:, None]).sum(axis=0) / iw.sum()
            else:
                avg[i] = w[i]
        w = 0.5 * w + 0.5 * avg
    order = np.argsort(-w, axis=1)
    w[np.arange(N)[:, None], order[:, 4:]] = 0
    w[w < 0.01] = 0
    w /= w.sum(axis=1, keepdims=True)
    assert np.isfinite(w).all()
    part = np.where(arm_m_total > 0.5, "arm", np.where(leg_m > 0.5, "leg", np.where((below > 0.5) & (leg_m <= 0.5), "skirt", "torso")))
    part = np.where((part == "torso") & (w[:, BI["Head"]] > 0.5), "head", part)
    rep["parts"] = {p: int((part == p).sum()) for p in sorted(set(part))}
    return w, names, part


def main():
    for name in ARGS or NAMES:
        rep = {"name": name}
        rig, body = load(name)
        W, to_w, nbr, elen, tris = welded(body)
        rep["height_m"] = round(float(W[:, 2].max() - W[:, 2].min()), 3)
        rep["tris"] = sum(len(p.vertices) - 2 for p in body.data.polygons)
        J, T = fix_joints(rig, W, tris, rep)
        w, names, part = build_weights(rig, W, tris, nbr, elen, J, T, CFG[name], rep)
        for g in list(body.vertex_groups):
            body.vertex_groups.remove(g)
        groups = {n: body.vertex_groups.new(name=n) for n in names}
        for vi, wi in enumerate(to_w):
            for bi in np.flatnonzero(w[wi]):
                groups[names[bi]].add([vi], float(w[wi, bi]), "REPLACE")
        pa = body.data.attributes.new("qa_part", "INT", "POINT")
        PARTS = ["head", "torso", "arm", "leg", "skirt"]
        for vi, wi in enumerate(to_w):
            pa.data[vi].value = PARTS.index(part[wi])
        bpy.ops.wm.save_as_mainfile(filepath=str(WORK / f"{name}_rig.blend"))
        (WORK / f"{name}_rig.json").write_text(json.dumps(rep, indent=1))
        print("RIG", json.dumps(rep), flush=True)


main()
