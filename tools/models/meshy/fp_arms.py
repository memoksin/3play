"""First-person arms of the Meshy farmer: his gloved forearms and hands, rigged with finger joints, holding the
fire game's tools, animated -> assets/3d/fire/fp_cutters.glb and fp_nozzle.glb (FireSkin.hand_cutters_model /
hand_nozzle_model through scenes/minigames/fire/art/hand_*.tscn).

blender -b --factory-startup --python-exit-code 1 -P tools/models/meshy/fp_arms.py [-- stage ...]
In:  src/farmer_meshy.glb (full detail), work/farmer_fit.json + work/farmer_rig.blend (rig.py: scale and the
     centred arm joints), work/fp_tools/*.glb (tools/models/fire/fp_tools.py: the tool parts).
Out: work/fp_mesh.blend (stage mesh), work/fp_rig.blend (stage rig), the two GLBs (stage anim),
     work/fp_report.json.

Stages:
- mesh: each arm cut from the full-detail mesh at mid upper arm (well below the frame in every pose), the cut
  capped; one Catmull-Clark level (Meshy's fingers are ~70 vertices each: they bend as round tubes now), the
  texture carried over exactly (linear UVs through the subdivision) and baked into its own 1024 px layout.
- rig: bones per arm Arm, ForeArm, ForeArmTwist, Hand and 3 per finger (Thumb1-3 ... Pinky1-3), found on
  the mesh: the hand sliced across its axis every 2 mm, each finger a track of section loops (shared vertices)
  from its tip into the palm, joints at anatomical shares of the finger length. Weights:
  arm chain along the bone line; fingers by surface-distance cells around each fingertip, a phalanx per
  segment with narrow blends at the knuckles (clean glove creases), the knuckles blending into the palm.
- anim: tool parts on their own bones, both hands placed on the grips by two-bone IK (elbows down and out),
  fingers closed on the handles by a contact solver against the glove's own vertices, every clip baked.
"""
import bpy, bmesh, json, math, sys
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from meshy_lib import smooth, chain_param, cum_lengths, chain_split

WORK = HERE / "work"
DEST = HERE.parents[2] / "assets/3d/fire"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SIDES = (("Left", 1), ("Right", -1))
TEX = 1024
CUT_AT = 0.45          # share of the upper arm (shoulder -> elbow) where the arm is cut


# ---------------------------------------------------------------- stage: mesh
def rig_joints():
    """Centred joints of the farmer rig (rig.py), rest space of the scaled mesh."""
    bpy.ops.wm.open_mainfile(filepath=str(WORK / "farmer_rig.blend"))
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    return {b.name: np.array(b.head_local) for b in rig.data.bones}


def load_full():
    fit = json.loads((WORK / "farmer_fit.json").read_text())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.import_scene.gltf(filepath=str(HERE / "src" / "farmer_meshy.glb"))
    body = next(o for o in bpy.data.objects if o.type == "MESH")
    body.data.transform(body.matrix_world)
    body.matrix_world = Matrix.Identity(4)
    body.data.transform(Matrix(fit["matrix"]))
    return body


def cut_arm(bm, J, s):
    """Keep the arm of side s past the cut plane (the part connected to its fingertips); cap the cut."""
    sh, el = J[s + "Arm"], J[s + "ForeArm"]
    n = (el - sh) / np.linalg.norm(el - sh)
    p = sh + (el - sh) * CUT_AT
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(p), plane_no=Vector(n), clear_inner=True)
    bm.verts.ensure_lookup_table()

    def flood(seed):
        out = {seed}
        stack = [seed]
        while stack:
            v = stack.pop()
            for e in v.link_edges:
                o = e.other_vert(v)
                if o not in out:
                    out.add(o)
                    stack.append(o)
        return out

    # Meshy built the forearm + glove as its own shell (open at the top, inside the rolled cuff); the sleeve
    # from the cut down to the roll belongs to the body shell
    wr = J[s + "Hand"]
    fdir = (wr - el) / np.linalg.norm(wr - el)
    co = np.array([tuple(v.co) for v in bm.verts])
    rel = co - el
    t = rel @ fdir
    off = np.linalg.norm(rel - np.outer(t, fdir), axis=1)
    far = bm.verts[int(np.argmax(np.where(off < 0.12, t, -np.inf)))]     # the longest fingertip
    keep = flood(far)
    rest = [v for v in bm.verts if v not in keep]
    mid = (p + el) / 2                                                   # on the upper arm below the cut
    near = min(rest, key=lambda v: np.linalg.norm(np.array(v.co) - mid))
    sleeve = flood(near)
    sl = np.array([tuple(v.co) for v in sleeve])
    print("ARM", s, "hand shell", len(keep), "sleeve", len(sleeve), "sleeve bbox", sl.min(0).round(3), sl.max(0).round(3), flush=True)
    keep |= sleeve
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v not in keep], context="VERTS")
    # cap every open loop on the cut plane with a fan to its centre
    bnd = [e for e in bm.edges if e.is_boundary]
    loops = []
    seen = set()
    for e in bnd:
        if e in seen:
            continue
        loop = []
        cur, v = e, e.verts[0]
        while cur not in seen:
            seen.add(cur)
            loop.append(v)
            v = cur.other_vert(v)
            nxt = [x for x in v.link_edges if x.is_boundary and x not in seen]
            if not nxt:
                break
            cur = nxt[0]
        loops.append(loop)
    caps = []
    for loop in loops:
        if len(loop) < 3:
            continue
        c = bm.verts.new(Vector(np.mean([np.array(v.co) for v in loop], axis=0)))
        for a, b in zip(loop, loop[1:] + loop[:1]):
            try:
                f = bm.faces.new((b, a, c))
                caps.append(f)
            except ValueError:
                pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return caps, len(loops)


def stage_mesh():
    J = rig_joints()
    body = load_full()
    src_img = next(n for n in body.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE").image
    arms = []
    rep = {}
    for s, sgn in SIDES:
        me = body.data.copy()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        caps, nloops = cut_arm(bm, J, s)
        for f in bm.faces:
            f.material_index = 0
        for f in caps:
            f.material_index = 1
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("arm_" + s, me)
        bpy.context.scene.collection.objects.link(ob)
        rep[s] = {"tris_orig": sum(len(p.vertices) - 2 for p in me.polygons), "cut_loops": nloops}
        arms.append(ob)
    bpy.data.objects.remove(body, do_unlink=True)
    # one mesh, two materials: the arm (texture) and the cap (sleeve inside)
    bpy.ops.object.select_all(action="DESELECT")
    for o in arms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arms[0]
    bpy.ops.object.join()
    ob = arms[0]
    ob.name = ob.data.name = "fp_arms"
    me = ob.data
    while len(me.materials) < 2:
        me.materials.append(None)
    cap = bpy.data.materials.new("fp_cap")
    cap.diffuse_color = (0.09, 0.075, 0.05, 1)
    me.materials[1] = cap
    # subdivide: linear UVs keep the texture where it was on every original triangle
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = sub.render_levels = 1
    sub.uv_smooth = "NONE"
    sub.boundary_smooth = "ALL"
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=sub.name)
    me.uv_layers[0].name = "orig"
    new = me.uv_layers.new(name="UVMap")
    me.uv_layers.active = new
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, area_weight=0.0, correct_aspect=True,
                             scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    # bake: the source texture through "orig" -> new layout
    img = bpy.data.images.new("fp_arms_albedo", TEX, TEX, alpha=False)
    m = me.materials[0]
    m.name = "fp_arms"
    nt = m.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = src_img
    tx.interpolation = "Cubic"
    uvn = nt.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "orig"
    nt.links.new(uvn.outputs["UV"], tx.inputs["Vector"])
    nt.links.new(tx.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    tgt = nt.nodes.new("ShaderNodeTexImage")
    tgt.image = img
    nt.nodes.active = tgt
    cap.use_nodes = True
    cnt = cap.node_tree
    ct = cnt.nodes.new("ShaderNodeTexImage")
    ct.image = img
    cnt.nodes.active = ct
    cap_bsdf = cnt.nodes.get("Principled BSDF")
    cap_bsdf.inputs["Base Color"].default_value = (0.09, 0.075, 0.05, 1)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 4
    sc.cycles.device = "CPU"
    sc.render.bake.margin = 8
    sc.render.bake.use_clear = True
    sc.render.bake.target = "IMAGE_TEXTURES"
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    # cap faces bake black-ish through their emission-less material: give the cap an emission colour first
    cnt.nodes.remove(cap_bsdf)
    cem = cnt.nodes.new("ShaderNodeEmission")
    cem.inputs["Color"].default_value = (0.085, 0.07, 0.048, 1)
    cnt.links.new(cem.outputs["Emission"], cnt.nodes["Material Output"].inputs["Surface"])
    bpy.ops.object.bake(type="EMIT")
    me.uv_layers.remove(me.uv_layers["orig"])
    # final material: the baked texture, roughness of the source; the cap shares the arm material
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = img
    nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 0.8
    bsdf.inputs["Metallic"].default_value = 0.0
    for p in me.polygons:
        p.material_index = 0
    me.materials.pop(index=1)
    bpy.data.materials.remove(cap)
    img.pack()
    rep["tris"] = sum(len(p.vertices) - 2 for p in me.polygons)
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK / "fp_mesh.blend"))
    print("MESH", json.dumps(rep), flush=True)
    return rep


# ---------------------------------------------------------------- stage: rig
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Pinky")
WEB = 0.27            # share of a finger (MCP -> tip) inside the palm, before the web between the fingers
PHAL = (0.48, 0.30)   # proximal, middle phalanx share of the finger (the distal one is the rest)


class Graph:
    """Edge graph of a mesh for surface (geodesic) distances."""

    def __init__(self, me):
        self.co = np.array([tuple(v.co) for v in me.vertices])
        self.nbr = [[] for _ in me.vertices]
        for e in me.edges:
            a, b = e.vertices
            d = float(np.linalg.norm(self.co[a] - self.co[b]))
            self.nbr[a].append((b, d))
            self.nbr[b].append((a, d))

    def dist(self, seeds, cutoff=np.inf, allowed=None):
        import heapq
        out = np.full(len(self.co), np.inf)
        pq = []
        for i in seeds:
            out[i] = 0.0
            pq.append((0.0, i))
        heapq.heapify(pq)
        while pq:
            d, i = heapq.heappop(pq)
            if d > out[i] or d > cutoff:
                continue
            for j, w in self.nbr[i]:
                if allowed is not None and not allowed[j]:
                    continue
                nd = d + w
                if nd < out[j]:
                    out[j] = nd
                    heapq.heappush(pq, (nd, j))
        return out


def section_loops(co, tris, dv, h):
    """Closed loops where the plane dv = h cuts the triangles: [(centroid, radius, points, vertex ids)]."""
    d = dv[tris] - h
    out_pts, keys, pairs = {}, [], []
    cross = (d[:, [0, 1, 2]] * d[:, [1, 2, 0]]) < 0
    for t in np.flatnonzero(cross.sum(axis=1) == 2):
        ks = []
        for e in np.flatnonzero(cross[t]):
            i, j = tris[t, e], tris[t, (e + 1) % 3]
            k = (min(i, j), max(i, j))
            if k not in out_pts:
                f = (h - dv[i]) / (dv[j] - dv[i])
                out_pts[k] = co[i] + (co[j] - co[i]) * f
            ks.append(k)
        pairs.append(ks)
    par = {k: k for k in out_pts}

    def find(k):
        while par[k] != k:
            par[k] = par[par[k]]
            k = par[k]
        return k

    for a, b in pairs:
        par[find(a)] = find(b)
    groups = {}
    for k in out_pts:
        groups.setdefault(find(k), []).append(k)
    loops = []
    for ks in groups.values():
        P = np.array([out_pts[k] for k in ks])
        c = P.mean(axis=0)
        loops.append((c, float(np.linalg.norm(P - c, axis=1).mean()), P, {v for k in ks for v in k}))
    return loops


def find_hand(G, J, s, tris_all):
    """Fingers of one hand (rest space of the scaled mesh): the hand is cut across its axis every 3 mm from
    the fingertips to the wrist; every finger is its own closed loop of the cut until it joins the palm at
    its web. Loops are tracked level to level: a loop that appears is a fingertip, loops that join end
    their fingers. Returns joints {finger: [base, j2, j3, tip]}, the palm normal, the per-vertex finger cell
    (-1 = palm) and a report."""
    co = G.co
    w, el = J[s + "Hand"], J[s + "ForeArm"]
    u = (w - el) / np.linalg.norm(w - el)
    t = (co - w) @ u
    off = np.linalg.norm((co - w) - np.outer(t, u), axis=1)
    region = (t > -0.03) & (off < 0.16)
    # the glove shell only (the sleeve is another shell)
    tip0 = int(np.argmax(np.where(region, t, -np.inf)))
    reach = G.dist([tip0], allowed=region)
    hand = region & np.isfinite(reach)
    a = co[tip0] - w
    a /= np.linalg.norm(a)
    dv = (co - w) @ a
    tris = tris_all[hand[tris_all].all(axis=1)]
    step = 0.002
    tracks = []
    levels = []
    for h in np.arange(dv[hand].max() - 0.0005, 0.01, -step):
        loops = section_loops(co, tris, dv, h)
        levels.append((h, loops))
        alive = [tr for tr in tracks if tr["end"] is None]
        seen = set()
        for li, lp in enumerate(loops):
            # same surface strip as the level before: the cuts share mesh vertices
            near = [tr for tr in alive if tr["verts"] & lp[3]]
            if len(near) == 1 and id(near[0]) not in seen:
                near[0]["pts"].append((h, lp[0], lp[1], li))
                near[0]["verts"] = lp[3]
                seen.add(id(near[0]))
                continue
            for tr in near:
                tr["end"] = h
            tracks.append({"pts": [(h, lp[0], lp[1], li)], "verts": lp[3], "end": None, "start": h,
                           "palm": len(near) > 1})
            seen.add(id(tracks[-1]))
        for tr in alive:
            if tr["end"] is None and id(tr) not in seen:
                tr["end"] = h                                   # vanished (a bump of the surface)
    fingers = [tr for tr in tracks if not tr["palm"] and tr["start"] - (tr["end"] or 0.0) > 0.035]
    rep = {"tracks": len(tracks), "fingers": len(fingers),
           "lens": [round(tr["start"] - (tr["end"] or 0.0), 3) for tr in fingers]}
    print("TRACKS", s, json.dumps(rep), flush=True)
    assert len(fingers) == 5, ("fingers", s, rep)
    thumb = min(fingers, key=lambda tr: tr["start"])
    others = [tr for tr in fingers if tr is not thumb]
    side = thumb["pts"][0][1] - w
    side -= a * (side @ a)
    side /= np.linalg.norm(side)
    others.sort(key=lambda tr: -(tr["pts"][0][1] @ side))
    named = dict(zip(FINGERS, [thumb] + others))
    # per-vertex cells: the finger whose loop the vertex's own cut passes through (nearest level)
    cell = np.full(len(co), -1)
    lev_h = np.array([lv[0] for lv in levels])
    owner = {}
    for f, name in enumerate(FINGERS):
        for h, c, r, li in named[name]["pts"]:
            owner[(round(h, 5), li)] = f
    for i in np.flatnonzero(hand):
        k = int(np.argmin(np.abs(lev_h - dv[i])))
        h, loops = levels[k]
        if not loops:
            continue
        li = int(np.argmin([np.linalg.norm(lp[2] - co[i], axis=1).min() for lp in loops]))
        cell[i] = owner.get((round(h, 5), li), -1)
    out = {}
    for f, name in enumerate(FINGERS):
        tr = named[name]
        pts = [p[1] for p in tr["pts"]]
        cen = np.array(pts)
        seg = np.linalg.norm(np.diff(cen, axis=0), axis=1)
        ds = np.concatenate([[0], np.cumsum(seg)])
        k = min(len(cen) - 1, max(3, len(cen) // 2))
        dirn = cen[0] - cen[k]
        dirn /= np.linalg.norm(dirn)
        mine = np.flatnonzero(cell == f)
        tipv = co[mine[np.argmax((co[mine] - cen[0]) @ dirn)]]
        lead = float((tipv - cen[0]) @ dirn)                    # the very tip is ahead of the first loop
        free = ds[-1] + lead
        base_dir = cen[-1] - cen[max(0, len(cen) - 1 - k)]
        base_dir /= np.linalg.norm(base_dir)

        def on_line(x, cen=cen, ds=ds, lead=lead, dirn=dirn, base_dir=base_dir):
            x = x - lead
            if x <= 0:
                return cen[0] + dirn * (-x)
            if x <= ds[-1]:
                return np.array([np.interp(x, ds, cen[:, j]) for j in range(3)])
            return cen[-1] + base_dir * (x - ds[-1])

        r = float(np.median([p[2] for p in tr["pts"]]))
        out[name] = dict(on_line=on_line, free=free, tip=tipv - dirn * 0.004, dir=dirn, r=r, line=cen)
    # palm normal: thumb side x finger direction (left hand), mirrored for the right
    fdir = out["Middle"]["dir"]
    t_side = side - fdir * (side @ fdir)
    t_side /= np.linalg.norm(t_side)
    n = np.cross(fdir, t_side) if s == "Left" else np.cross(t_side, fdir)
    n /= np.linalg.norm(n)
    joints = {}
    for name in FINGERS[1:]:
        F = out[name]
        L = F["free"] / (1 - WEB)
        joints[name] = [F["on_line"](L), F["on_line"](L * (1 - PHAL[0])), F["on_line"](L * (1 - PHAL[0] - PHAL[1])), F["tip"]]
    T = out["Thumb"]
    t_mcp = T["on_line"](T["free"])
    joints["Thumb"] = [w + (t_mcp - w) * 0.3, t_mcp, T["on_line"](0.42 * T["free"]), T["tip"]]
    rep.update({k: {"free": round(float(out[k]["free"]), 4), "r": round(out[k]["r"], 4)} for k in FINGERS})
    return joints, n, cell, hand, rep


# Shoulders in camera space (Blender: x right, y forward, z up; the camera looks along +y): the arms hang
# from here. Under the eyes instead of ~8 cm behind them, the usual first-person framing: the hands reach the
# tool held out at a comfortable distance (the upper arms never show).
SHOULDER_MID = Vector((0.0, 0.0, -0.3))


def bone_names(s):
    out = [s + "Arm", s + "ForeArm", s + "ForeArmTwist", s + "Hand"]
    for f in FINGERS:
        out += [f"{s}Hand{f}{k}" for k in (1, 2, 3)]
    return out


def to_cam(J):
    """Rest space of the character (facing -y) -> camera space (facing +y), shoulders at SHOULDER_MID."""
    mid = (Vector(J["LeftArm"]) + Vector(J["RightArm"])) / 2
    rot = Matrix.Rotation(math.pi, 4, "Z")
    return Matrix.Translation(SHOULDER_MID) @ rot @ Matrix.Translation(-mid)


def finger_weights(co, cell, hand, joints, rep, nbr):
    """Columns Hand + 15 finger bones for the hand vertices of one side."""
    n = len(co)
    W = np.zeros((n, 16))
    total = np.zeros(n)
    for f, name in enumerate(FINGERS):
        P = joints[name]
        d, sa = chain_param(co, P)
        cum = cum_lengths(P)
        r = rep[name]["r"]
        if name == "Thumb":
            near = 0.7 * (1 - smooth(1.4 * r, 2.6 * r, d)) * smooth(-0.004, 0.016, sa)
        else:
            near = (1 - smooth(1.3 * r, 2.3 * r, d)) * smooth(-0.012, 0.008, sa)
        amt = np.where(cell == f, smooth(-0.012, 0.008, sa) if name != "Thumb" else 1.0, np.where(cell < 0, near, 0.0))
        amt = amt * hand
        split = chain_split(sa, cum, [0.005 if name != "Thumb" else 0.008, 0.004])
        W[:, 1 + 3 * f:4 + 3 * f] = amt[:, None] * split
        total += amt
    k = np.maximum(total, 1.0)
    W[:, 1:] /= k[:, None]
    W[:, 0] = 1 - W[:, 1:].sum(axis=1)
    # one neighbour pass on the hand (softens the cell borders in the webs, keeps the creases narrow)
    avg = W.copy()
    for i in np.flatnonzero(hand):
        if nbr[i]:
            avg[i] = W[[j for j, _ in nbr[i]]].mean(axis=0)
    W = np.where(hand[:, None], 0.6 * W + 0.4 * avg, W)
    return W


def stage_rig():
    J = rig_joints()
    bpy.ops.wm.open_mainfile(filepath=str(WORK / "fp_mesh.blend"))
    bpy.context.preferences.filepaths.save_version = 0
    ob = bpy.data.objects["fp_arms"]
    me = ob.data
    G = Graph(me)
    me.calc_loop_triangles()
    tris_all = np.array([tuple(lt.vertices) for lt in me.loop_triangles])
    co = G.co
    hands = {}
    report = {}
    names = ["View"] + bone_names("Left") + bone_names("Right")
    BI = {nm: i for i, nm in enumerate(names)}
    Wt = np.zeros((len(co), len(names)))
    for s, sgn in SIDES:
        joints, n, cell, hand, rep = find_hand(G, J, s, tris_all)
        hands[s] = (joints, n)
        report[s] = rep
        side = co[:, 0] * sgn > 0
        # arm chain: shoulder -> elbow -> wrist -> middle knuckle
        P = [J[s + "Arm"], J[s + "ForeArm"], J[s + "Hand"], joints["Middle"][0]]
        d, sa = chain_param(co, P)
        cum = cum_lengths(P)
        split = chain_split(sa, cum, [0.05, 0.025])
        tw = smooth(cum[1] + 0.04, cum[2] - 0.01, sa)              # twist share along the forearm
        Wt[side, BI[s + "Arm"]] = split[side, 0]
        Wt[side, BI[s + "ForeArm"]] = split[side, 1] * (1 - tw[side])
        Wt[side, BI[s + "ForeArmTwist"]] = split[side, 1] * tw[side]
        hw = split[:, 2] * side
        F = finger_weights(co, cell, hand & side, joints, rep, G.nbr)
        Wt[:, BI[s + "Hand"]] += hw * F[:, 0]
        for f, name in enumerate(FINGERS):
            for k in range(3):
                Wt[:, BI[f"{s}Hand{name}{k + 1}"]] += hw * F[:, 1 + 3 * f + k]
    Wt[Wt < 0.004] = 0
    order = np.argsort(-Wt, axis=1)
    Wt[np.arange(len(co))[:, None], order[:, 4:]] = 0
    Wt /= Wt.sum(axis=1, keepdims=True)
    # armature (character rest space), then everything into camera space
    arm = bpy.data.armatures.new("fp_rig")
    rig = bpy.data.objects.new("fp_rig", arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones
    M = to_cam(J)
    Minv = M.inverted()
    v = eb.new("View")
    v.head = Minv @ Vector((0, 0, 0))
    v.tail = Minv @ Vector((0, 0.1, 0))
    v.align_roll(Minv.to_3x3() @ Vector((0, 0, 1)))
    for s, sgn in SIDES:
        joints, n = hands[s]
        nv = Vector(n)

        def bone(name, h, t, parent, roll_to):
            b = eb.new(name)
            b.head, b.tail = Vector(h), Vector(t)
            b.parent = eb[parent]
            b.align_roll(roll_to)
            return b

        up = Vector((0, 0, 1))
        mid_k = joints["Middle"][0]
        bone(s + "Arm", J[s + "Arm"], J[s + "ForeArm"], "View", nv)
        bone(s + "ForeArm", J[s + "ForeArm"], J[s + "Hand"], s + "Arm", nv)
        bone(s + "ForeArmTwist", (J[s + "ForeArm"] + J[s + "Hand"]) / 2, J[s + "Hand"], s + "ForeArm", nv)
        bone(s + "Hand", J[s + "Hand"], mid_k, s + "ForeArm", nv)
        palm_c = np.mean([joints[f][0] for f in FINGERS[1:]], axis=0) * 0.6 + J[s + "Hand"] * 0.4
        for name in FINGERS:
            P = joints[name]
            if name == "Thumb":
                tdir = P[3] - P[1]
                tdir /= np.linalg.norm(tdir)
                to = palm_c + n * 0.012 - P[1]
                to = to - tdir * (to @ tdir)
                roll = Vector(to / np.linalg.norm(to))
            else:
                roll = nv
            par = s + "Hand"
            for k in range(3):
                bone(f"{s}Hand{name}{k + 1}", P[k], P[k + 1], par, roll)
                par = f"{s}Hand{name}{k + 1}"
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.data.transform(M)
    me.transform(M)
    for b in rig.data.bones:
        b.use_deform = True
    for g in list(ob.vertex_groups):
        ob.vertex_groups.remove(g)
    groups = {nm: ob.vertex_groups.new(name=nm) for nm in names}
    for i in range(len(co)):
        for bi in np.flatnonzero(Wt[i]):
            groups[names[bi]].add([i], float(Wt[i, bi]), "REPLACE")
    ob.parent = rig
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    report["hands"] = {s: {"joints": {k: [[round(float(c), 4) for c in p] for p in v] for k, v in hands[s][0].items()},
                           "palm": [round(float(c), 4) for c in hands[s][1]]} for s in hands}
    (WORK / "fp_hands.json").write_text(json.dumps(report, indent=1))
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK / "fp_rig.blend"))
    print("RIGGED", len(names), "bones", flush=True)


def stage_anim():
    import fp_tool
    rep = {}
    for name in [a for a in ARGS if a in fp_tool.TOOLS] or list(fp_tool.TOOLS):
        vm = fp_tool.TOOLS[name]()
        acts = [vm.bake(clip, params, loop) for clip, params, loop in vm.clips()]
        bpy.ops.wm.save_as_mainfile(filepath=str(WORK / f"fp_{name}.blend"))
        vm.export(DEST / f"fp_{name}.glb", acts)
        rep[name] = vm.report
    old = json.loads((WORK / "fp_report.json").read_text()) if (WORK / "fp_report.json").exists() else {}
    old.update(rep)
    (WORK / "fp_report.json").write_text(json.dumps(old, indent=1, default=str))


STAGES = {"mesh": stage_mesh, "rig": stage_rig, "anim": stage_anim}

if __name__ == "__main__":
    for st in [a for a in ARGS if a in STAGES] or list(STAGES):
        STAGES[st]()
