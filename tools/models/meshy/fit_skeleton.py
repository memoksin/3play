"""Raw Meshy mesh (no auto-rig) -> Meshy's 24-bone skeleton fitted to it, in the state rig.py's load() returns.

Used by rig.py when out/<name>/rigged.glb is missing and src/<name>_meshy.glb exists (Meshy image-to-3D output,
not rigged: saves the auto-rig credits). rig.py then centres the joints and builds the weights as for the others.
- Scale: total height (hat included) to FIT[name]['height'], feet on z = 0, the symmetry plane on x = 0;
  facing -y (glTF +z) as Meshy's characters.
- Game weight: the mesh is decimated (collapse, UV seams kept) to FIT[name]['tris'].
- Joints: arms from the mesh (texture colours tell glove, bare skin and sleeve apart): the wrist at the narrowest
  cut of the glove's cuff, the elbow one forearm length up the forearm's axis, the shoulder on the upper arm's line;
  trunk and legs at heights measured on this mesh (FIT[name]['z'], m). rig.py moves every joint to the centre of
  its cross-section afterwards.
The transform and the joints go to work/<name>_fit.json (fp_arms.py cuts the full-detail mesh with them).
"""
import bpy, json
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
WORK = HERE / "work"
SIDES = (("Left", 1), ("Right", -1))
ORDER = ["Hips", "Spine02", "Spine01", "Spine", "neck", "Head", "head_end", "headfront",
         "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand",
         "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]
PARENT = {"Spine02": "Hips", "Spine01": "Spine02", "Spine": "Spine01", "neck": "Spine", "Head": "neck",
          "head_end": "Head", "headfront": "Head"}
for _s, _ in SIDES:
    PARENT.update({_s + "Shoulder": "Spine", _s + "Arm": _s + "Shoulder", _s + "ForeArm": _s + "Arm",
                   _s + "Hand": _s + "ForeArm", _s + "UpLeg": "Hips", _s + "Leg": _s + "UpLeg",
                   _s + "Foot": _s + "Leg", _s + "ToeBase": _s + "Foot"})
# Heights (m, after scaling) read off horizontal cuts of the mesh: belt, chest, shoulders, chin, crotch, knee, boot.
FIT = {
    "farmer": dict(height=1.88, tris=4600, forearm=0.255,
                   z=dict(Hips=0.97, Spine02=1.1, Spine01=1.24, Spine=1.4, neck=1.53, Head=1.6, Shoulder=1.45,
                          Arm=1.43, UpLeg=0.9, Leg=0.5, Foot=0.11, ToeBase=0.025),
                   x=dict(Shoulder=0.05, Arm=0.19, UpLeg=0.1, Leg=0.11, Foot=0.12, ToeBase=0.12)),
}


def vertex_colours(me):
    """Texture colour under every vertex (mean of its loops' UVs)."""
    node = next(n for n in me.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
    img = node.image
    w, h = img.size
    px = np.array(img.pixels[:]).reshape(h, w, 4)
    uv = np.zeros((len(me.vertices), 2))
    cnt = np.zeros(len(me.vertices))
    uvl = me.uv_layers[0].data
    for lp in me.loops:
        uv[lp.vertex_index] += uvl[lp.index].uv
        cnt[lp.vertex_index] += 1
    uv /= np.maximum(cnt, 1)[:, None]
    return px[np.clip((uv[:, 1] * h).astype(int), 0, h - 1), np.clip((uv[:, 0] * w).astype(int), 0, w - 1), :3]


def classes(col):
    """glove (dark brown leather), skin (bare forearm), per vertex."""
    r, g, b = col.T
    glove = (r < 0.42) & (g < 0.34) & (b < 0.26) & (r - b > 0.06) & (r > 0.12)
    skin = (r > 0.72) & (r - b > 0.25)
    return glove, skin


def tris_of(me, co):
    me.calc_loop_triangles()
    idx = np.array([tuple(t.vertices) for t in me.loop_triangles])
    return co[idx]


def section_pts(tris, origin, normal):
    from meshy_lib import section
    return section(tris, origin, normal)


def arm_joints(co, tris, glove, skin, sgn, cfg):
    """Wrist, elbow, shoulder of one arm (A-pose) from the mesh."""
    side = co[:, 0] * sgn > 0.28
    g = co[glove & side & (co[:, 2] > 0.6) & (co[:, 2] < 1.35)]
    s = co[skin & side & (co[:, 2] > 0.9) & (co[:, 2] < 1.4)]
    s_c = s.mean(axis=0)
    shoulder0 = np.array([sgn * cfg["x"]["Arm"], s_c[1], cfg["z"]["Arm"]])
    tip = g[np.argmax(np.linalg.norm(g - shoulder0, axis=1))]
    g = g[np.linalg.norm(g - tip, axis=1) < 0.3]              # the glove itself (no dark creases of the sleeve)
    cuff_top = g[np.argmax(np.linalg.norm(g - tip, axis=1))]
    # forearm axis: the bare skin's centre to the glove's cuff
    d = tip - s_c
    d /= np.linalg.norm(d)
    best = None
    t_cuff = float((cuff_top - s_c) @ d)
    for t in np.arange(t_cuff + 0.01, t_cuff + 0.09, 0.004):
        o = s_c + d * t
        p = section_pts(tris, o, d)
        p = p[np.linalg.norm(p - o, axis=1) < 0.09]
        if len(p) < 6:
            continue
        q = p - o
        e1 = np.cross(d, [0, 1.0, 0])
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(d, e1)
        w = (q @ e1).max() - (q @ e1).min() + (q @ e2).max() - (q @ e2).min()
        c = o + e1 * ((q @ e1).max() + (q @ e1).min()) / 2 + e2 * ((q @ e2).max() + (q @ e2).min()) / 2
        if best is None or w < best[0]:
            best = (w, c, t)
    wrist = best[1]
    # forearm direction from the bare skin's principal axis
    u = np.linalg.svd(s - s_c)[2][0]
    u = u if u @ (wrist - s_c) > 0 else -u
    elbow = wrist - u * cfg["forearm"]
    shoulder = shoulder0.copy()
    shoulder[1] = elbow[1]
    return dict(wrist=wrist, elbow=elbow, shoulder=shoulder, tip=tip, cuff=cuff_top, width=best[0])


def normalise(body, height):
    me = body.data
    me.transform(body.matrix_world)
    body.matrix_world = Matrix.Identity(4)
    co = np.array([tuple(v.co) for v in me.vertices])
    lo, hi = co.min(axis=0), co.max(axis=0)
    k = height / (hi[2] - lo[2])
    off = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
    m = Matrix.Diagonal((k, k, k, 1)) @ Matrix.Translation(off)
    me.transform(m)
    return m


def decimate(body, tris):
    import bmesh
    bm = bmesh.new()                       # weld Meshy's split UV charts first, or the seams open while collapsing
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(body.data)
    bm.free()
    have = sum(len(p.vertices) - 2 for p in body.data.polygons)
    if have <= tris:
        return
    mod = body.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = tris / have
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=mod.name)


def load_src(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.import_scene.gltf(filepath=str(HERE / "src" / f"{name}_meshy.glb"))
    body = next(o for o in bpy.data.objects if o.type == "MESH")
    return body


def joints(name, body):
    """Joint heads (rest, metres) for the 24 bones of the scaled full-detail mesh."""
    cfg = FIT[name]
    me = body.data
    co = np.array([tuple(v.co) for v in me.vertices])
    glove, skin = classes(vertex_colours(me))
    tris = tris_of(me, co)
    z, x = cfg["z"], cfg["x"]
    J = {}
    mid_y = lambda zz: float(np.median(co[(np.abs(co[:, 2] - zz) < 0.02) & (np.abs(co[:, 0]) < 0.08), 1]))
    for b in ("Hips", "Spine02", "Spine01", "Spine", "neck", "Head"):
        J[b] = np.array([0.0, mid_y(z[b]), z[b]])
    J["head_end"] = J["Head"] + [0, 0, 0.2]
    J["headfront"] = J["Head"] + [0, -0.1, 0.05]
    arms = {}
    for s, sgn in SIDES:
        a = arm_joints(co, tris, glove, skin, sgn, cfg)
        arms[s] = {k: (v.tolist() if hasattr(v, "tolist") else v) for k, v in a.items()}
        J[s + "Shoulder"] = np.array([sgn * x["Shoulder"], J["Spine"][1], z["Shoulder"]])
        J[s + "Arm"] = a["shoulder"]
        J[s + "ForeArm"] = a["elbow"]
        J[s + "Hand"] = a["wrist"]
        for b in ("UpLeg", "Leg", "Foot"):
            J[s + b] = np.array([sgn * x[b], mid_y(z["Hips"]) if b == "UpLeg" else 0.0, z[b]])
        foot = co[(co[:, 2] < 0.06) & (co[:, 0] * sgn > 0.02)]
        J[s + "ToeBase"] = np.array([sgn * x["ToeBase"], foot[:, 1].min() * 0.55 + foot[:, 1].max() * 0.0, z["ToeBase"]])
    return J, arms


def build(name, body, J):
    arm = bpy.data.armatures.new(name + "_rig")
    rig = bpy.data.objects.new(name + "_rig", arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones
    for n in ORDER:
        b = eb.new(n)
        b.head = Vector(J[n])
        b.tail = b.head + Vector((0, 0, 0.05))
    for n, p in PARENT.items():
        eb[n].parent = eb[p]
    bpy.ops.object.mode_set(mode="OBJECT")
    body.name = body.data.name = name + "_body"
    body.parent = rig
    body.matrix_parent_inverse = Matrix.Identity(4)
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    for n in ORDER:
        body.vertex_groups.new(name=n)
    return rig


def fit(name):
    """rig, body as rig.load() returns them (body decimated to the game weight)."""
    cfg = FIT[name]
    body = load_src(name)
    m = normalise(body, cfg["height"])
    J, arms = joints(name, body)
    WORK.mkdir(exist_ok=True)
    (WORK / f"{name}_fit.json").write_text(json.dumps(
        {"matrix": [list(r) for r in m], "joints": {k: [round(float(c), 4) for c in v] for k, v in J.items()},
         "arms": arms}, indent=1))
    decimate(body, cfg["tris"])
    rig = build(name, body, J)
    return rig, body
