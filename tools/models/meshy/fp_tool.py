"""The two first-person view models of fp_arms.py: the farmer's arms holding the bolt cutters or the hose nozzle.
Tool parts come from tools/models/fire/fp_tools.py (work/fp_tools/*.glb). Camera space (Blender): +x right,
+y forward, +z up, the eye at the origin; Godot gets -z forward, +y up (glTF export).

Every clip is a full pose of every bone, baked at 30 fps from parameters:
  view   the View bone (root): breathing, step bob (the arms and the tool move as one, from the shoulders)
  tool   the tool's pose under View; the hands follow the grips (two-bone IK, fingers solved on the handles)
  open   cutters: half opening angle of the arms (deg); squeeze: fingers pressing in (0..1)
  trigger nozzle: trigger lever pulled (0..1); the index finger follows it
The nozzle's interaction clips (pickup, attach, valve: fire.gd holds the camera where the clip wants it) give every
part in camera space instead: tool_m / right_m / left_m / coupling_m (matrices), poles, hand_ang (finger angles),
roots (the arms' roots moved, bent down to a prop), hose_free (the left hand off the hose: it hangs), turn (the
valve wheel, 0..1, on the Turn bone) and scale (a part that is not there: bone scale HIDE, e.g. the nozzle before
the grab). Ref<Act>O/X/Y bones hold the prop's frame in camera space for fire.gd's camera lock.
"""
import bpy, bmesh, json, math, os, re
from collections import Counter
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion, Euler

import fp_pose as FP

HERE = Path(__file__).resolve().parent
WORK = HERE / "work"
PARTS = WORK / "fp_tools"
FPS = 30
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

# --- tool constants (tools/models/fire/cutters.py, fp_tools.py: the view model's cutters are CUT_SCALE times
# cutters.py's, a 0.92 m / 36 in bolt cutter that fits the farmer's big gloves, with the grips a little slimmer)
CUT_SCALE = 1.2
C_ARM_Y, C_END_Y, C_GRIP_Y = 0.12 * CUT_SCALE, 0.64 * CUT_SCALE, 0.40 * CUT_SCALE
C_GR = 0.0235                            # grip radius (fp_tools.py CUT_GR)
C_RIB = C_GR * 1.12                      # over the grip's rings: what the palm and the fingers rest on
N_TRIGGER_PIVOT = Vector((0.0, -0.03, 0.034))
N_GRIP_RAKE = 14.0
N_GRIP_C = Vector((0.0, 0.034, -0.012))
N_INLET = Vector((0.0, 0.034 + math.sin(math.radians(14.0)) * 0.112, -0.012 - math.cos(math.radians(14.0)) * 0.112))
N_MUZZLE = Vector((0.0, -0.248, 0.06))
HOSE_R, HOSE_LEN, HOSE_BONES = 0.022, 1.1, 11

# --- the props the nozzle's arms work on (fire.gd locks the camera to them while a clip plays). Godot, prop-local:
# valve.tscn (tools/models/fire/valve.py: the models shifted -0.2 m in x) and hose.tscn (hose.py).
G2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))   # Godot (x, y, z) -> Blender (x, -z, y)
B2G = G2B.transposed()
WHEEL_C = Vector((0.0, 0.92, 0.26))      # the handwheel's hub (valve.tscn Wheel), turning about the valve's +z
WHEEL_R, RIM_R = 0.095, 0.014            # valve.py wheel(): rim radius, rim tube radius
OUTLET_TOP = Vector((0.16, 0.70, 0.12))  # the coupling's top seated on the ribbed connector (valve.tscn Coupling)
CPL_R, CPL_NUT_R, CPL_LEN = 0.031, 0.036, 0.075   # hose.py coupling_v: sleeve, nut (across flats), top -> hose
COIL_NOZZLE_LOC = Vector((0.42, -0.98, 0.033))     # hose.py NOZZLE_LOC / NOZZLE_ROT: the nozzle lying by the coil
COIL_NOZZLE_ROT = (0.0, 90.0, -70.0)               # (Blender, coil-local; x, y, z deg applied z(y(x)))
REF_LEN = 0.25
CPL_REST = Matrix.Translation(Vector((0.0, 0.3, -0.7)))
TURN_REST = Matrix.Translation(Vector((0.0, -1.0, -1.0)))
TURN_M = 0.1
HIDE = 1e-3                              # bone scale of a part that is not there (the nozzle before the grab)
# clip lengths (s) and moments; fire.gd reads the moments from the clips (the scale keys), the lengths too
PICKUP_T, PICK_GRAB = 1.8, 0.9
ATTACH_T, ATTACH_SWAP = 2.1, 1.45
VALVE_T = 2.6
LOCK_IN = 0.4                            # fire.gd LOCK_IN: the camera reaches its lock; no contact before this
VALVE_TURNS = 1.0                        # valve.gd TURNS


def handle_x(s, y):
    k = CUT_SCALE
    if y <= C_ARM_Y:
        return s * 0.035 * k * y / C_ARM_Y
    return s * k * (0.035 + 0.055 * (y - C_ARM_Y) / (C_END_Y - C_ARM_Y))


def rot(x=0.0, y=0.0, z=0.0):
    """Rotation (4x4): about z, then y, then x... applied as Rx @ Ry @ Rz (degrees)."""
    return (Matrix.Rotation(math.radians(x), 4, "X") @ Matrix.Rotation(math.radians(y), 4, "Y")
            @ Matrix.Rotation(math.radians(z), 4, "Z"))


def ease(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- scene helpers
def import_part(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(PARTS / f"{name}.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in meshes:
        o.data.transform(o.matrix_world)
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    if len(meshes) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for o in meshes:
            o.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
    ob = meshes[0]
    ob.name = ob.data.name = name
    return ob


def add_bones(rig, bones):
    """bones: [(name, parent or None (a root), rest 4x4 camera space, length)]."""
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    for name, parent, m, ln in bones:
        b = eb.new(name)
        b.head = m.translation
        b.tail = m.translation + m.to_3x3() @ Vector((0, ln, 0))
        b.align_roll(m.to_3x3() @ Vector((0, 0, 1)))
        if parent:
            b.parent = eb[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for name, *_ in bones:
        rig.pose.bones[name].rotation_mode = "QUATERNION"


def skin(ob, rig, weights):
    """weights: bone -> per-vertex weight array (or a float for all)."""
    for g in list(ob.vertex_groups):
        ob.vertex_groups.remove(g)
    n = len(ob.data.vertices)
    for bone, w in weights.items():
        g = ob.vertex_groups.new(name=bone)
        w = np.full(n, w) if np.isscalar(w) else w
        for i in np.flatnonzero(w > 1e-4):
            g.add([int(i)], float(w[i]), "REPLACE")
    ob.parent = rig
    ob.matrix_parent_inverse = Matrix.Identity(4)
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig


# ---------------------------------------------------------------- base: arms + one tool
class ViewModel:
    """Arms rig + one tool; subclasses set up the tool and the hold pose and give the clip parameters."""
    name = ""
    REACH_WARN = 0.97
    SHOULDER = Vector((0.0, 0.0, 0.0))       # the arms' roots moved by this (camera space) for this tool
    SPLIT_FINGERS = False                    # cut the glove where two fingers touch in the rest mesh (split_fingers)
    SCALE = {}                               # bone -> scale in every clip unless a frame's p["scale"] says otherwise

    def __init__(self):
        bpy.ops.wm.open_mainfile(filepath=str(WORK / "fp_rig.blend"))
        bpy.context.preferences.filepaths.save_version = 0
        sc = bpy.context.scene
        sc.render.fps, sc.render.fps_base = FPS, 1
        self.rig = bpy.data.objects["fp_rig"]
        self.arms_ob = bpy.data.objects["fp_arms"]
        self.report = {"name": self.name, "clips": {}}
        self.setup_tool()
        if self.SPLIT_FINGERS:
            self.split_fingers()
        self.R = FP.Rig(self.rig, self.arms_ob)
        self.arms = FP.Arms(self.R)
        self.hands = {s: FP.Hand(self.R, s) for s in ("Left", "Right")}
        self.solve_grips()

    def split_fingers(self):
        """In the Meshy glove the thumb tip is fused to the side of the index finger, and the index tip to the
        middle one; the fused patch takes weights from both, so once the fingers part (a power grip) it pulls
        out into a long needle. Splits the mesh between faces of two different fingers (where either side is a
        middle or end phalanx: the webs at the knuckles stay joined) and leaves each side only its own finger's
        weights."""
        ob = self.arms_ob
        names = [g.name for g in ob.vertex_groups]
        finger = {}
        for i, n in enumerate(names):
            m = re.match(r"(Left|Right)Hand(Thumb|Index|Middle|Ring|Pinky)(\d)$", n)
            if m:
                finger[i] = (m.group(1) + m.group(2), int(m.group(3)))
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        dl = bm.verts.layers.deform.verify()

        def dom(v):
            d = v[dl]
            return finger.get(max(d.keys(), key=lambda g: d[g])) if len(d) else None

        face_f = {}
        for f in bm.faces:
            ids = [dom(v) for v in f.verts]
            fid = Counter(i[0] if i else None for i in ids).most_common(1)[0][0]
            face_f[f] = (fid, max((i[1] for i in ids if i and i[0] == fid), default=0))
        cut = []
        for e in bm.edges:
            if len(e.link_faces) == 2:
                (fa, ka), (fb, kb) = (face_f[f] for f in e.link_faces)
                if fa and fb and fa != fb and max(ka, kb) >= 2:
                    cut.append(e)
        bmesh.ops.split_edges(bm, edges=cut)
        cleaned = 0
        for v in bm.verts:
            fs = {face_f[f][0] for f in v.link_faces if f in face_f}
            if len(fs) != 1 or None in fs:
                continue
            fid = fs.pop()
            d = v[dl]
            drop = [g for g in d.keys() if g in finger and finger[g][0] != fid]
            if drop:
                for g in drop:
                    del d[g]
                tot = sum(d.values())
                for g in d.keys():
                    d[g] = d[g] / tot
                cleaned += 1
        bm.to_mesh(ob.data)
        bm.free()
        self.report["split_fingers"] = {"edges": len(cut), "vertices_cleaned": cleaned}

    # subclasses: setup_tool(), solve_grips(), tool_world(world, p), hand_targets(world, p), fingers(p), extra(world, p)
    def pose(self, p):
        """Full world pose of every bone for parameters p."""
        R = self.R
        world = {}
        V = p.get("view", Matrix.Identity(4))
        world["View"] = R.rest["View"] @ V @ Matrix.Translation(self.SHOULDER + p.get("roots", Vector()))
        self.tool_world(world, p)
        rep = self.report.setdefault("ik", {})
        for s, (hand, pole) in self.hand_targets(world, p).items():
            self.arms.solve(world, s, hand, pole, rep)
        ang = self.fingers(p)
        for s in ("Left", "Right"):
            for f in FP.FINGERS:
                a = ang[s][f]
                par = world[s + "Hand"]
                for k in range(3):
                    n = f"{s}Hand{f}{k + 1}"
                    if f == "Thumb" and k == 0:
                        r = Matrix.Rotation(math.radians(a[1]), 4, "Z") @ Matrix.Rotation(math.radians(a[0]), 4, "X")
                    else:
                        r = Matrix.Rotation(math.radians(a[k + (1 if f == "Thumb" else 0)]), 4, "X")
                    world[n] = par @ R.rel[n] @ r
                    par = world[n]
        self.extra(world, p)
        # anything not set: at rest under its parent
        for n in R.order:
            if n not in world:
                pn = R.parent[n]
                world[n] = (world[pn] @ R.rel[n]) if pn else R.rest[n].copy()
        return world

    def best_grip(self, s, pt, d, radius, poles, along=0.74, diags=(18.0,), want=None, want_w=2.0):
        """Hand matrix, grip line and elbow pole for a handle (axis through pt along d) with the least
        forearm twist and wrist bend (the forearm turns about +-80 deg, the wrist bends about 35 deg
        comfortably), over hand turns about the handle, palm diagonals and elbow directions (poles).
        want: a direction the palm should face (weighted by want_w)."""
        R = self.R
        best = None
        d = d.normalized()
        e1 = d.orthogonal().normalized()
        e2 = d.cross(e1)
        for pole in poles:
            for diag in diags:
                for sign in (1.0, -1.0):
                    for k in range(24):
                        a = 2 * math.pi * k / 24
                        pref = e1 * math.cos(a) + e2 * math.sin(a)
                        hm, line = self.hands[s].place_axis(pt, d, pref, radius, sign=sign, along=along, diag=diag)
                        world = {"View": self.view_rest()}
                        rep = {}
                        E = self.arms.solve(world, s, hm, pole, rep)
                        tw = abs(rep["twist_deg"][s])
                        fo = (hm.translation - E).normalized()
                        wrist = math.degrees(fo.angle(hm.to_3x3() @ Vector((0, 1, 0))))
                        cost = tw / 80.0 + max(0.0, wrist - 35.0) / 15.0 + max(0.0, tw - 85.0) / 20.0
                        if want is not None:
                            n = hm.to_3x3() @ Vector((0, 0, 1))
                            cost += want_w * (1 - n.dot(want.normalized()))
                        if best is None or cost < best[0]:
                            best = (cost, hm, line, pole, round(tw, 1), round(wrist, 1), sign, diag,
                                    [round(x, 2) for x in hm.to_3x3() @ Vector((0, 0, 1))])
        self.report.setdefault("grip_choice", {})[s] = {"twist": best[4], "wrist": best[5], "sign": best[6],
                                                        "diag": best[7], "palm": best[8], "pole": list(best[3])}
        return best[1], best[2], best[3]

    def view_rest(self):
        return self.R.rest["View"] @ Matrix.Translation(self.SHOULDER)

    def view0(self, world):
        """The camera-space frame the tool is placed in (the View bone without the shoulder offset)."""
        return world["View"] @ Matrix.Translation(-self.SHOULDER)

    def wrist(self, s, hm, E):
        """Wrist angles (deg) of hand matrix hm with the elbow at E: extension (+, the hand bent toward its
        back) / flexion (-), ulnar (+, toward the little finger) / radial (-) deviation."""
        f = hm.to_3x3().transposed() @ (hm.translation - E).normalized()        # the forearm in hand space
        ext = math.degrees(math.atan2(f.z, f.y))
        uln = math.degrees(math.atan2(f.x * self.hands[s].index_side, f.y))
        return ext, uln

    def anat_grip(self, s, pt, d, radius, poles, palm, along=0.72, diags=(30.0, 40.0, 50.0, 60.0), palm_tol=30.0):
        """Like best_grip, by the wrist's own ranges: forearm twist about neutral (palm toward the body's midline
        with the elbow bent), wrist extension -15..45 deg (a power grip likes ~15), ulnar / radial deviation
        -10..30 (likes ~10), the thumb side up, the palm within palm_tol deg of `palm` (the side it holds the
        handle from), the hand within reach. Searches hand turns about the handle, palm diagonals, elbow poles."""
        R = self.R
        H = self.hands[s]
        best = None
        d = d.normalized()
        e1 = d.orthogonal().normalized()
        e2 = d.cross(e1)
        palm = palm.normalized()
        for pole in poles:
            for diag in diags:
                for k in range(36):
                    a = 2 * math.pi * k / 36
                    pref = e1 * math.cos(a) + e2 * math.sin(a)
                    hm, line = H.place_axis(pt, d, pref, radius, sign=1.0, along=along, diag=diag)
                    n = hm.to_3x3() @ Vector((0, 0, 1))
                    off = math.degrees(n.angle(palm))
                    if off > palm_tol + 30:
                        continue
                    world = {"View": self.view_rest()}
                    rep = {}
                    E = self.arms.solve(world, s, hm, pole, rep)
                    tw = abs(rep["twist_deg"][s])
                    ext, uln = self.wrist(s, hm, E)
                    thumb_up = (hm.to_3x3() @ Vector((H.index_side, 0, 0))).z
                    cost = (tw / 90.0 + max(0.0, tw - 60.0) / 15.0
                            + ((ext - 15.0) / 35.0) ** 2 + max(0.0, ext - 45.0) / 6.0 + max(0.0, -15.0 - ext) / 6.0
                            + ((uln - 10.0) / 30.0) ** 2 + max(0.0, uln - 30.0) / 5.0 + max(0.0, -10.0 - uln) / 5.0
                            + max(0.0, off - palm_tol) / 10.0 + max(0.0, 0.3 - thumb_up) * 3.0
                            + max(0.0, rep["reach"] - 0.95) * 50.0)
                    if best is None or cost < best[0]:
                        best = (cost, hm, line, pole, dict(twist=round(tw, 1), ext=round(ext, 1), uln=round(uln, 1),
                                                           diag=diag, palm=[round(x, 2) for x in n],
                                                           reach=round(rep["reach"], 3), pole=list(pole),
                                                           cost=round(cost, 3)))
        self.report.setdefault("grip_choice", {})[s] = best[4]
        return best[1], best[2], best[3]

    def bake(self, clip, params, loop):
        R = self.R
        rig = self.rig
        act = bpy.data.actions.new(clip + ("_loop" if loop else ""))
        act.use_fake_user = True
        if not rig.animation_data:
            rig.animation_data_create()
        rig.animation_data.action = act
        prev = {}
        reach = 0.0
        self.report["ik"] = {}
        for i, p in enumerate(params):
            world = self.pose(p)
            basis = R.basis(world)
            scale = dict(self.SCALE, **p.get("scale", {}))
            for n in R.order:
                pb = rig.pose.bones[n]
                q = basis[n].to_quaternion()
                if n in prev:
                    q.make_compatible(prev[n])
                prev[n] = q
                pb.rotation_quaternion = q
                pb.location = basis[n].translation
                pb.scale = (scale.get(n, 1.0),) * 3
                pb.keyframe_insert("rotation_quaternion", frame=i)
                pb.keyframe_insert("location", frame=i)
                pb.keyframe_insert("scale", frame=i)
        rig.animation_data.action = None
        self.report["clips"][clip] = {"frames": len(params), "loop": loop,
                                      "reach_max": round(self.report["ik"].get("reach", 0.0), 3),
                                      "twist_deg": self.report["ik"].get("twist_deg")}
        print("CLIP", self.name, clip, json.dumps(self.report["clips"][clip]), flush=True)
        return act

    def set_pose(self, p):
        """Pose the rig (no keys) for a render."""
        basis = self.R.basis(self.pose(p))
        scale = dict(self.SCALE, **p.get("scale", {}))
        for n in self.R.order:
            pb = self.rig.pose.bones[n]
            pb.rotation_quaternion = basis[n].to_quaternion()
            pb.location = basis[n].translation
            pb.scale = (scale.get(n, 1.0),) * 3
        bpy.context.view_layer.update()

    def export(self, path, actions):
        rig = self.rig
        for pb in rig.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.ops.object.select_all(action="DESELECT")
        rig.select_set(True)
        for o in bpy.data.objects:
            if o.type == "MESH" and o.parent == rig:
                o.select_set(True)
        keep = set(actions)
        for a in list(bpy.data.actions):
            if a not in keep:
                bpy.data.actions.remove(a)
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                  export_image_format="JPEG", export_jpeg_quality=90,
                                  export_animation_mode="ACTIONS", export_animations=True,
                                  export_force_sampling=True, export_optimize_animation_size=False,
                                  export_all_influences=False, export_yup=True, export_apply=False,
                                  export_def_bones=False)
        print("EXPORT", path, flush=True)


# ---------------------------------------------------------------- the bolt cutters
class Cutters(ViewModel):
    name = "cutters"
    PIVOT = Vector((0.0, 1.2, -0.15))        # the tool's pivot bolt, camera space (the jaws just under the crosshair)
    PITCH = 11.0                             # head up (deg): the handles rise from the hands to the head
    OPEN = 7.0                               # half opening of the arms, jaws open (deg)
    CLOSED = 0.6
    SPLIT_FINGERS = True
    GRIP_Y = 0.725                           # hand centre along each handle (tool space), the end cap under the heel
    # the arms' roots a little forward and up (the farmer's arms are short for a first-person view): the hands
    # reach the handles with the arms still bent; the upper-arm cut and the elbows stay out of frame
    SHOULDER = Vector((0.0, 0.03, 0.12))
    ALONG = 0.72                             # the handle crosses the palm at this share of wrist -> middle knuckle

    def t0(self):
        return Matrix.Translation(self.PIVOT) @ rot(x=self.PITCH) @ rot(z=180.0)

    def setup_tool(self):
        T0 = self.t0()
        add_bones(self.rig, [("Tool", "View", T0, 0.1), ("CutR", "Tool", T0, 0.08), ("CutL", "Tool", T0, 0.08)])
        for part, bone in (("fp_cut_r", "CutR"), ("fp_cut_l", "CutL")):
            ob = import_part(part)
            ob.data.transform(T0)
            skin(ob, self.rig, {bone: 1.0})

    def half_world(self, world, s, open_deg):
        """s = -1: the right half (handle on tool -X = camera +X), +1 the left."""
        return world["Tool"] @ rot(z=-s * open_deg)

    def grip_line(self, half_w, s):
        y = self.GRIP_Y
        p = Vector((handle_x(s, y), y, 0.0))
        d = Vector((s * 0.055 * CUT_SCALE / (C_END_Y - C_ARM_Y), 1.0, 0.0)).normalized()
        return half_w @ p, (half_w.to_3x3() @ -d).normalized()             # toward the head

    def solve_grips(self):
        world = {"View": self.view_rest()}
        world["Tool"] = self.t0()
        self.G = {}
        self.ang = {}
        self.pole = {}
        self.grips_c = Vector((0, 0, 0))                # between the hands: pivot of the tool's sway
        for s, side, sgn in (("Right", -1, 1.0), ("Left", 1, -1.0)):
            hw = self.half_world(world, side, self.OPEN)
            pt, d = self.grip_line(hw, side)
            # elbows down and out to the side, never up: the arms push the handles together
            poles = [Vector((sgn * x, y, z)) for x in (0.2, 0.5, 1.0) for y in (-0.6, -0.2) for z in (-1.0, -0.5, 0.0)]
            # each hand holds its handle from the outside: the palm on its outer, upper side (facing in and down),
            # the fingers close round under it to the inner side, the thumb over the top
            hm, (p_h, d_h), self.pole[s] = self.anat_grip(s, pt, d, C_RIB, poles, Vector((-sgn, 0.0, -0.5)),
                                                          along=self.ALONG, diags=(40.0, 45.0, 50.0, 55.0),
                                                          palm_tol=35.0)
            self.G[s] = hw.inverted() @ hm
            self.grips_c += pt / 2
            axes = [(p_h, d_h, C_RIB + 0.001, 0.12)]
            fing = FP.close_fingers(self.hands[s], axes)
            tgt = p_h + Vector((0, 0, 1)) * (C_RIB + 0.006) + d_h * 0.022
            th = FP.thumb_wrap(self.hands[s], axes, tgt)
            fing["Thumb"] = list(th)
            tight = FP.close_fingers(self.hands[s], axes, squeeze=0.003, start=fing)
            tight["Thumb"] = list(th)
            self.ang[s] = (fing, tight)
            self.report.setdefault("grip", {})[s] = {k: [round(float(x), 1) for x in v] for k, v in fing.items()}

    def tool_world(self, world, p):
        world["Tool"] = self.view0(world) @ p.get("tool", Matrix.Identity(4)) @ self.t0()
        op = p.get("open", self.OPEN)
        world["CutR"] = self.half_world(world, -1, op)
        world["CutL"] = self.half_world(world, 1, op)

    def hand_targets(self, world, p):
        out = {}
        for s, half in (("Right", "CutR"), ("Left", "CutL")):
            out[s] = (world[half] @ self.G[s], world["View"].to_3x3() @ self.pole[s])
        return out

    def fingers(self, p):
        out = {}
        sq = p.get("squeeze", 0.0)
        for s in ("Left", "Right"):
            a, b = self.ang[s]
            extra = p.get("curl", {}).get(s, 0.0)
            out[s] = {f: [x + (y - x) * sq + (extra if f != "Thumb" else 0.0) for x, y in zip(a[f], b[f])] for f in a}
        return out

    def extra(self, world, p):
        pass

    # ---- clips
    def clips(self):
        out = []
        n = 4 * FPS
        out.append(("idle", [self.idle_p(i / FPS) for i in range(n + 1)], True))
        n = FPS
        out.append(("walk", [self.walk_p(i / n) for i in range(n + 1)], True))
        out.append(("snip", [self.snip_p(i / FPS) for i in range(FPS + 1)], False))
        out.append(("raise", raise_params(self.idle_p(0.0), self.grips_c, 12, whole=True), False))
        out.append(("lower", raise_params(self.idle_p(0.0), self.grips_c, 9, whole=True)[::-1], False))
        return out

    def idle_p(self, t):
        p = {"view": breath(t), "tool": about(self.grips_c, rot(z=0.35 * math.sin(2 * math.pi * t / 4 + 0.8),
                                                             x=0.25 * math.sin(2 * math.pi * 2 * t / 4)))}
        # the hands work the grips now and then: the right one closes harder, the left one eases and takes hold
        p["curl"] = {"Right": 3.0 * pulse(t, 2.2, 2.9), "Left": -9.0 * pulse(t, 0.7, 1.35)}
        p["squeeze"] = 0.35 * pulse(t, 2.2, 2.9)
        return p

    def walk_p(self, ph):
        p = {"view": step_bob(ph)}
        p["tool"] = about(self.grips_c, rot(x=1.3 * math.sin(4 * math.pi * ph - 0.6), y=1.4 * math.sin(2 * math.pi * ph + 0.4)))
        p["open"] = self.OPEN + 0.5 * math.sin(4 * math.pi * ph - 1.2)
        return p

    def snip_p(self, u):
        p = self.idle_p(0.0)
        p["open"] = self.OPEN + (self.CLOSED - self.OPEN) * u
        p["squeeze"] = u
        p["curl"] = {"Right": 1.0 * u, "Left": 1.0 * u}
        p["tool"] = about(self.grips_c, rot(x=0.8 * u)) @ Matrix.Translation(Vector((0, 0.008 * u, 0.004 * u)))
        p["view"] = breath(0.0) @ rot(x=-0.4 * u)
        return p


def pulse(t, a, b):
    """0 -> 1 -> 0 between a and b (smooth)."""
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a)) ** 2


def about(c, r, offset=None):
    m = Matrix.Translation(c) @ r @ Matrix.Translation(-c)
    return (Matrix.Translation(offset) @ m) if offset is not None else m


def breath(t, T=4.0):
    """View bone (4x4) for breathing: one breath every T s (loops at T), the arms rise and settle with it."""
    w = 2 * math.pi * t / T
    z = 0.0035 * math.sin(w) + 0.0008 * math.sin(2 * w + 0.7)
    y = 0.0015 * math.sin(w - 0.9)
    x = 0.0012 * math.sin(w + 1.3) + 0.0006 * math.sin(3 * w)
    return Matrix.Translation(Vector((x, y, z))) @ rot(x=0.45 * math.sin(w - 0.5), z=0.25 * math.sin(w + 2.0),
                                                       y=0.3 * math.sin(2 * w + 0.4))


def step_bob(ph):
    """View bone for a walk cycle (ph 0..1 = two steps; fire.gd bobs the hands too, this is what the arms add:
    the tool lagging the body, a dip after each foot lands, a roll from side to side)."""
    w = 2 * math.pi * ph
    z = -0.006 * abs(math.cos(w - 0.35)) + 0.003
    x = 0.0045 * math.sin(w - 0.5)
    y = 0.002 * math.sin(2 * w - 0.9)
    return Matrix.Translation(Vector((x, y, z))) @ rot(z=1.2 * math.sin(w - 0.7), y=1.8 * math.sin(w - 0.2),
                                                       x=0.9 * math.sin(2 * w - 1.1))


def raise_params(hold, c, n, left_c=None, whole=False):
    """n+1 frames from the tool down out of view to the hold pose (frame n = hold). left_c: a free left hand
    (the nozzle's, under the hose) comes up with it, a beat behind. whole: the arms' roots go down with the tool
    (the View bone moves; for a tool held far from the shoulders, which it would pull out of the hands)."""
    out = []
    for i in range(n + 1):
        u = i / n
        e = 1 - (1 - u) ** 3                                      # fast then settling
        k = 1 - e
        p = dict(hold)
        low = about(c, rot(x=-38 * k, y=14 * k, z=-8 * k), Vector((0.03 * k, -0.06 * k, -0.30 * k)))
        p["tool"] = hold.get("tool", Matrix.Identity(4)) if whole else low @ hold.get("tool", Matrix.Identity(4))
        if left_c is not None:
            kl = (1 - max(0.0, u - 0.15) / 0.85) ** 3             # starts a beat later, same settle
            low_l = about(left_c, rot(x=-30 * kl, y=-12 * kl, z=10 * kl), Vector((-0.02 * kl, -0.14 * kl, -0.28 * kl)))
            p["left"] = low_l @ hold.get("left", Matrix.Identity(4))
        p["view"] = (low if whole else Matrix.Identity(4)) @ hold.get("view", Matrix.Identity(4))
        out.append(p)
    return out


# ---------------------------------------------------------------- the hose nozzle
class Nozzle(ViewModel):
    name = "nozzle"
    SCALE = {"Coupling": HIDE}
    GRIP = Vector((0.16, 0.42, -0.15))       # middle of the pistol grip, camera space
    PITCH = 4.0
    YAW = 3.0                                # toward the middle of the view
    TRIGGER = 17.0                           # lever travel (deg)
    LEFT_PT = Vector((-0.06, 0.47, -0.235))  # the hose through the left hand, view space
    LEFT_DIR = Vector((1.0, 0.15, -0.2))     # the hose's direction there (toward the nozzle)
    HOSE_END = Vector((-0.45, 0.15, -0.8))   # where the hose goes, out of view below

    def t0(self):
        return Matrix.Translation(self.GRIP) @ rot(z=self.YAW) @ rot(x=self.PITCH) @ rot(z=180.0)

    def setup_tool(self):
        T0 = self.t0()
        tp = T0 @ Matrix.Translation(N_TRIGGER_PIVOT)
        mz = T0 @ Matrix.Translation(N_MUZZLE) @ rot(z=180.0)
        self.seg = HOSE_LEN / (HOSE_BONES - 1)
        start = T0 @ N_INLET
        hose_rest = Matrix.Translation(start) @ rot(x=-90.0)          # straight down, Y = along the hose
        bones = [("Tool", "View", T0, 0.1), ("Trigger", "Tool", tp, 0.05), ("Muzzle", "Tool", mz, 0.05)]
        for k in range(HOSE_BONES):
            bones.append((f"Hose{k}", "View", hose_rest @ Matrix.Translation(Vector((0, k * self.seg, 0))), self.seg * 0.9))
        bones.append(("Inlet", f"Hose{HOSE_BONES - 1}", hose_rest @ Matrix.Translation(Vector((0, HOSE_LEN, 0))), 0.05))
        # the hose's coupling end (attach: in the left hand, hidden by scale otherwise), the valve wheel's turn as
        # data (Turn's offset from its rest / TURN_M = 0..1 of the wheel's turns) and the props' poses the camera
        # locks to (Ref<Act>O/X/Y: the prop frame's origin and its x / y axis points, REF_LEN away; fire.gd)
        self.cam = self.act_cams()
        bones += [("Coupling", None, CPL_REST, 0.05), ("Turn", None, TURN_REST, 0.05)]
        for act, M in self.cam.items():
            for k, q in (("O", Vector()), ("X", Vector((REF_LEN, 0, 0))), ("Y", Vector((0, REF_LEN, 0)))):
                bones.append((f"Ref{act.capitalize()}{k}", None, Matrix.Translation(M @ q), 0.02))
        add_bones(self.rig, bones)
        ob = import_part("fp_nozzle")
        ob.data.transform(T0)
        skin(ob, self.rig, {"Tool": 1.0})
        ob = import_part("fp_nozzle_trigger")
        ob.data.transform(T0)
        skin(ob, self.rig, {"Trigger": 1.0})
        ob = import_part("fp_hose")
        yv = np.array([v.co.y for v in ob.data.vertices])
        ob.data.transform(hose_rest)
        f = np.clip(yv / self.seg, 0, HOSE_BONES - 1 - 1e-6)
        k0 = np.floor(f).astype(int)
        t = f - k0
        w = {}
        for k in range(HOSE_BONES):
            w[f"Hose{k}"] = np.where(k0 == k, 1 - t, 0.0) + np.where(k0 + 1 == k, t, 0.0)
        skin(ob, self.rig, w)
        ob = import_part("fp_coupling")
        ob.data.transform(CPL_REST)
        skin(ob, self.rig, {"Coupling": 1.0})

    def grip_axis(self):
        rk = math.radians(N_GRIP_RAKE)
        return N_GRIP_C, Vector((0.0, -math.sin(rk), math.cos(rk)))    # tool space, toward the barrel

    def lever(self, trig):
        """Trigger lever line (tool space): pivot -> foot, turned toward the grip by trig."""
        r = Matrix.Rotation(math.radians(self.TRIGGER * trig), 3, "X")
        foot = N_TRIGGER_PIVOT + r @ Vector((0.0, -0.005, -0.092))
        return N_TRIGGER_PIVOT + r @ Vector((0, -0.01, -0.02)), (foot - N_TRIGGER_PIVOT).normalized()

    def solve_grips(self):
        T0 = self.t0()
        self.G = {}
        self.ang = {}
        self.pole = {}
        # right hand: around the pistol grip, index side up, fingers round its front
        c, up = self.grip_axis()
        pt = T0 @ (c + up * 0.012)
        d = (T0.to_3x3() @ up).normalized()
        fwd = (T0.to_3x3() @ Vector((0, -1, 0))).normalized()
        pref = (fwd + Vector((0, 0, -0.25))).normalized()
        hand = self.hands["Right"]
        poles = [Vector(v) for v in ((0.75, -0.3, -1.0), (1.0, -0.2, -0.3), (0.3, -1.0, -0.6), (0.0, -0.2, -1.0))]
        hm, (p_h, d_h), self.pole["Right"] = self.best_grip("Right", pt, d, 0.02, poles, along=0.72, diags=(8.0, 16.0),
                                                            want=Vector((-1.0, 0.5, 0.0)), want_w=1.0)
        self.G["Right"] = T0.inverted() @ hm
        Hi = hm.inverted()
        grip_ax = (p_h, d_h, 0.021, 0.07)

        def lever_ax(trig):
            a, dv = self.lever(trig)
            a_c = Hi @ (T0 @ (a + dv * 0.04))
            d_c = (Hi.to_3x3() @ (T0.to_3x3() @ dv)).normalized()
            return (a_c, d_c, 0.0105, 0.045)

        rest = FP.close_fingers(hand, [grip_ax], fingers=("Middle", "Ring", "Pinky"))
        rest_i = FP.close_fingers(hand, [lever_ax(0.0), grip_ax], fingers=("Index",))
        pull_i = FP.close_fingers(hand, [lever_ax(1.0), grip_ax], fingers=("Index",))
        thumb_t = Hi @ (T0 @ (c + up * 0.03 + Vector((0.026, -0.006, 0.0))))
        th = FP.thumb_wrap(hand, [grip_ax], thumb_t)
        tight = FP.close_fingers(hand, [grip_ax], squeeze=0.003, fingers=("Middle", "Ring", "Pinky"), start=rest)
        a = dict(rest, Index=rest_i["Index"], Thumb=list(th))
        b = dict(tight, Index=pull_i["Index"], Thumb=list(th))
        self.ang["Right"] = (a, b)
        # left hand: palm up under the hose
        hand = self.hands["Left"]
        poles = [Vector(v) for v in ((-0.7, -0.25, -1.0), (-1.0, -0.2, -0.3), (-0.3, -1.0, -0.6), (0.0, -0.2, -1.0))]
        hm, (p_h, d_h), self.pole["Left"] = self.best_grip("Left", self.LEFT_PT, self.LEFT_DIR, HOSE_R, poles, along=0.7,
                                                           diags=(10.0, 20.0, 30.0), want=Vector((0.15, 0.0, 1.0)), want_w=3.0)
        self.left_hand = hm
        self.left_line = (p_h, d_h)
        ax = (p_h, d_h, HOSE_R + 0.001, 0.1)
        fing = FP.close_fingers(hand, [ax])
        th = FP.thumb_wrap(hand, [ax], p_h + Vector((0, 0, 1)) * (HOSE_R + 0.006) + d_h * 0.02)
        fing["Thumb"] = list(th)
        tight = FP.close_fingers(hand, [ax], squeeze=0.003, start=fing)
        tight["Thumb"] = list(th)
        self.ang["Left"] = (fing, tight)
        self.report["grip"] = {s: {k: [round(float(x), 1) for x in v] for k, v in self.ang[s][0].items()} for s in self.ang}

    def tool_world(self, world, p):
        world["Tool"] = p["tool_m"] if "tool_m" in p else world["View"] @ p.get("tool", Matrix.Identity(4)) @ self.t0()
        world["Trigger"] = world["Tool"] @ self.R.rel["Trigger"] @ rot(x=self.TRIGGER * p.get("trigger", 0.0))
        world["Muzzle"] = world["Tool"] @ self.R.rel["Muzzle"]

    def hand_targets(self, world, p):
        """The hands: right on the nozzle's grip, left under the hose; an interaction clip gives them as camera-space
        matrices (right_m / left_m) with their elbow poles (poles)."""
        left = world["View"] @ p.get("left", Matrix.Identity(4)) @ self.left_hand
        V = world["View"].to_3x3()
        poles = p.get("poles", {})
        return {"Right": (p.get("right_m", world["Tool"] @ self.G["Right"]), poles.get("Right", V @ self.pole["Right"])),
                "Left": (p.get("left_m", left), poles.get("Left", V @ self.pole["Left"]))}

    def fingers(self, p):
        out = {}
        for s in ("Left", "Right"):
            if s in p.get("hand_ang", {}):
                out[s] = p["hand_ang"][s]
                continue
            a, b = self.ang[s]
            k = p.get("trigger", 0.0) if s == "Right" else p.get("squeeze", 0.0)
            extra = p.get("curl", {}).get(s, 0.0)
            out[s] = {}
            for f in a:
                kk = k if (s == "Left" or f == "Index") else p.get("squeeze", 0.0)
                out[s][f] = [x + (y - x) * kk + (extra if f not in ("Thumb", "Index") else 0.0) for x, y in zip(a[f], b[f])]
        return out

    def extra(self, world, p):
        """The hose: from the coupling down the grip's line, through the left hand, away out of view."""
        T = world["Tool"]
        c, up = self.grip_axis()
        P0 = T @ N_INLET
        t0 = (T.to_3x3() @ -up).normalized()
        L = world["LeftHand"]
        p_h, d_h = self.left_line
        P1 = L @ p_h
        t1 = (L.to_3x3() @ d_h).normalized()
        if t1.dot(P1 - P0) < 0:
            t1 = -t1
        V = world["View"]
        P2 = V @ self.HOSE_END
        t2 = (V.to_3x3() @ Vector((-0.2, -0.3, -1.0))).normalized()
        free = p.get("hose_free", 0.0)
        if free > 0.0:
            # the left hand off the hose: it hangs from the nozzle (down: the world's down in camera space)
            down = p.get("down", Vector((0, 0, -1)))
            P1 = P1.lerp(P0 + down * 0.3 + t0 * 0.08, free)
            t1 = t1.lerp(down, free).normalized()
            P2 = P2.lerp(P0 + down * 0.9 + (V.to_3x3() @ Vector((-0.25, -0.2, 0.0))), free)
            t2 = t2.lerp(down, free).normalized()
        world["Coupling"] = p.get("coupling_m", CPL_REST)
        world["Turn"] = TURN_REST @ Matrix.Translation(Vector((0.0, TURN_M * p.get("turn", 0.0), 0.0)))
        k1 = 0.45 * (P1 - P0).length
        stiff = p.get("stiff", 0.0)
        pts = bezier(P0, P0 + t0 * k1 * (1 + 0.4 * stiff), P1 - t1 * k1, P1, 24)[:-1] + \
            bezier(P1, P1 + t1 * 0.16, P2 - t2 * 0.3, P2, 30)
        pts = np.array([tuple(q) for q in pts])
        seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        s_acc = np.concatenate([[0], np.cumsum(seg)])
        prev_z = None
        for k in range(HOSE_BONES + 1):
            s_k = min(k * self.seg, HOSE_LEN)
            if s_k <= s_acc[-1]:
                pos = Vector([np.interp(s_k, s_acc, pts[:, j]) for j in range(3)])
                i = min(int(np.searchsorted(s_acc, s_k)), len(pts) - 1)
                i = max(i, 1)
                tan = Vector(tuple(pts[i] - pts[i - 1])).normalized()
            else:
                tan = Vector(tuple(pts[-1] - pts[-2])).normalized()
                pos = Vector(tuple(pts[-1])) + tan * (s_k - s_acc[-1])
            zh = prev_z if prev_z is not None else (T.to_3x3() @ Vector((1, 0, 0)))
            m = FP.frame(tan, zh).to_4x4()
            m.translation = pos
            prev_z = m.to_3x3() @ Vector((0, 0, 1))
            if k < HOSE_BONES:
                world[f"Hose{k}"] = m
            else:
                world["Inlet"] = m

    # ---- clips
    def clips(self):
        out = []
        out.append(("idle", [self.idle_p(i / FPS) for i in range(4 * FPS + 1)], True))
        out.append(("walk", [self.walk_p(i / FPS) for i in range(FPS + 1)], True))
        out.append(("spray", [self.spray_p(i / FPS) for i in range(FPS + 1)], True))
        out.append(("spray_start", [self.start_p(i / FPS) for i in range(10)], False))
        out.append(("raise", raise_params(self.idle_p(0.0), self.GRIP, 12, self.LEFT_PT), False))
        out.append(("lower", raise_params(self.idle_p(0.0), self.GRIP, 9, self.LEFT_PT)[::-1], False))
        self.solve_acts()
        for name, fn, length in (("pickup", self.pickup_p, PICKUP_T), ("attach", self.attach_p, ATTACH_T),
                                 ("valve", self.valve_p, VALVE_T)):
            out.append((name, [fn(i / FPS) for i in range(int(round(length * FPS)) + 1)], False))
        return out

    def idle_p(self, t):
        p = {"view": breath(t)}
        p["tool"] = about(self.GRIP, rot(z=0.5 * math.sin(2 * math.pi * t / 4 + 0.3), x=0.4 * math.sin(2 * math.pi * 2 * t / 4 + 1.0)))
        p["left"] = Matrix.Translation(Vector((0, 0, 0.004 * math.sin(2 * math.pi * t / 4 - 1.2))))
        p["curl"] = {"Right": 5.0 * pulse(t, 1.6, 2.3), "Left": -10.0 * pulse(t, 2.8, 3.5)}
        p["squeeze"] = 0.3 * pulse(t, 1.6, 2.3)
        return p

    def walk_p(self, ph):
        p = {"view": step_bob(ph)}
        p["tool"] = about(self.GRIP, rot(x=1.5 * math.sin(4 * math.pi * ph - 0.6), y=1.6 * math.sin(2 * math.pi * ph + 0.4)))
        p["left"] = Matrix.Translation(Vector((0.004 * math.sin(2 * math.pi * ph), 0, 0.006 * math.sin(4 * math.pi * ph - 1.0))))
        return p

    def spray_p(self, t):
        """Water on: trigger held, the nozzle pushed back and up by the jet and held there against it. Only a slow
        sway (one per loop): the old 4-9 Hz pressure shiver, keyed at 30 fps, buzzed the muzzle and the hose
        (the jet, the hose line) by several mm from frame to frame."""
        w = 2 * math.pi * t
        p = self.idle_p(0.0)
        kick = Vector((0.0004 * math.sin(w + 0.4), -0.011, 0.003 + 0.0004 * math.sin(w)))
        p["tool"] = about(self.GRIP, rot(x=1.6 + 0.12 * math.sin(w + 0.5), z=0.1 * math.sin(w)), kick)
        p["left"] = Matrix.Translation(Vector((0.0, -0.006, 0.004 + 0.0004 * math.sin(w + 2.0))))
        p["trigger"] = 1.0
        p["squeeze"] = 1.0
        p["stiff"] = 1.0
        p["view"] = breath(0.0)
        return p

    def start_p(self, t):
        """0.3 s: trigger pulled in 0.08 s, the jet kicks the nozzle back, settling into the spray loop."""
        u = min(t / 0.08, 1.0)
        a = self.idle_p(0.0)
        b = self.spray_p(0.0)
        kick = math.exp(-((t - 0.1) / 0.05) ** 2)
        e = ease(t / 0.3)
        p = dict(b)
        p["trigger"] = ease(u)
        p["squeeze"] = ease(u)
        p["stiff"] = ease(u)
        p["tool"] = lerp_m(a["tool"], b["tool"], e) @ about(self.GRIP, rot(x=2.5 * kick), Vector((0, -0.012 * kick, 0.004 * kick)))
        p["left"] = lerp_m(Matrix.Identity(4), b["left"], e)
        p["view"] = lerp_m(a["view"], b["view"], e)
        p["curl"] = {"Right": 0.0, "Left": 0.0}
        return p


    # ---- interactions (fire.gd locks the camera to the prop, LOCK_IN s from the start; camera space throughout)
    VALVE_EYE = Vector((0.0, 1.2, 0.68))     # the camera at the valve (Godot, valve-local), pitched VALVE_PITCH deg
    VALVE_PITCH = -12.0
    VALVE_ROOTS = Vector((0.0, 0.11, 0.04))  # the arms' roots while the hands are on the wheel (crouched, leaning in)
    ATTACH_EYE = Vector((0.2, 0.95, 0.55))
    ATTACH_PITCH = -26.0
    ATTACH_ROOTS = Vector((0.0, 0.08, 0.03))
    PICK_EYE = Vector((-0.1, 0.7, 0.2))       # from the coil nozzle's grip (x right, y up, z back of the camera's yaw)
    PICK_YAW = 8.0
    PICK_PITCH = -45.0
    PICK_ROOTS = Vector((0.0, 0.17, -0.05))   # bent down to the ground: the shoulders come forward with the head
    STROKES = ((0.48, 0.8), (0.95, 1.27), (1.42, 1.74), (1.89, 2.21))   # the valve: four 90 deg heaves of the wheel
    STROKE = 90.0

    def act_cams(self):
        """Prop-local (Godot) -> camera (Blender) per interaction: the camera where fire.gd locks it."""
        N = B2G @ coil_nozzle()
        grip = N @ N_GRIP_C
        fwd = N.to_3x3() @ Vector((0, -1, 0))
        yaw = math.degrees(math.atan2(-fwd.x, -fwd.z)) + self.PICK_YAW
        eye = grip + Matrix.Rotation(math.radians(yaw), 3, "Y") @ self.PICK_EYE
        return {"pickup": godot_cam(eye, yaw, self.PICK_PITCH),
                "attach": godot_cam(self.ATTACH_EYE, 0.0, self.ATTACH_PITCH),
                "valve": godot_cam(self.VALVE_EYE, 0.0, self.VALVE_PITCH)}

    def _solve_at(self, roots, fn):
        keep = self.SHOULDER
        self.SHOULDER = keep + roots
        try:
            return fn()
        finally:
            self.SHOULDER = keep

    def _pole_for(self, s, hm, roots, cands):
        """The elbow pole (of cands) with the least forearm twist for hand matrix hm."""
        best = None
        for c in cands:
            rep = {}
            self.arms.solve({"View": self.view_rest() @ Matrix.Translation(roots)}, s, hm, c, rep)
            tw = abs(rep["twist_deg"][s])
            if best is None or tw < best[0]:
                best = (tw, c)
        return best[1]

    def solve_acts(self):
        """Grips on the props: both hands on the valve's rim, the left hand on the hose's coupling, the right hand
        on the nozzle lying by the coil; the hold pose (idle frame 0) the clips start from and end in."""
        hold = self.pose(self.idle_p(0.0))
        self.hold = {n: hold[n].copy() for n in ("Tool", "RightHand", "LeftHand")}
        self.hold_ang = self.fingers(self.idle_p(0.0))
        self.open_ang = {s: {f: [0.25 * x for x in v] for f, v in self.hold_ang[s].items()} for s in self.hold_ang}
        V = self.view_rest().to_3x3()
        self.hold_pole = {s: V @ self.pole[s] for s in ("Left", "Right")}
        rep = self.report.setdefault("acts", {})
        # the valve: the rim at 4 / 10 o'clock (mid-heave: 2 / 8), the palm on its front, fingers round behind it
        M = self.cam["valve"]
        M3 = M.to_3x3()
        c, a, e1, e2 = M @ WHEEL_C, (M3 @ Z).normalized(), M3 @ X, M3 @ Y
        self.wheel = (c, a, e1, e2)
        self.rim = {}
        for s, mid, poles in (("Right", 30.0, ((0.8, -0.3, -1.0), (1.0, 0.0, -0.5), (0.3, -0.5, -1.0), (0.0, -0.2, -1.0))),
                              ("Left", 210.0, ((-0.8, -0.3, -1.0), (-1.0, 0.0, -0.5), (-0.3, -0.5, -1.0), (0.0, -0.2, -1.0)))):
            th = math.radians(mid)
            radial = e1 * math.cos(th) + e2 * math.sin(th)
            pt = c + radial * WHEEL_R
            d = -e1 * math.sin(th) + e2 * math.cos(th)
            hm, _, pole = self._solve_at(self.VALVE_ROOTS, lambda: self.rim_grip(s, pt, d, a, radial, poles))
            Hi = hm.inverted()
            axes = []
            for k in range(-2, 2):
                q0 = c + (e1 * math.cos(th + math.radians(15 * k)) + e2 * math.sin(th + math.radians(15 * k))) * WHEEL_R
                q1 = c + (e1 * math.cos(th + math.radians(15 * k + 15)) + e2 * math.sin(th + math.radians(15 * k + 15))) * WHEEL_R
                axes.append((Hi @ ((q0 + q1) / 2), (Hi.to_3x3() @ (q1 - q0)).normalized(), RIM_R + 0.001, (q1 - q0).length / 2))
            hand = self.hands[s]
            fing = FP.close_fingers(hand, axes)
            fing["Thumb"] = list(FP.thumb_wrap(hand, axes, Hi @ (pt - radial * (RIM_R + 0.004) + a * 0.012)))
            self.rim[s] = (hm, pole, fing, mid)
            rep["valve_" + s] = dict(self.report["grip_choice"][s])
        # the coupling, seated on the connector (P(0, 0)); the hand holds its sleeve, solved mid-twist
        M = self.cam["attach"]
        self.cpl_seat = M @ Matrix.Translation(OUTLET_TOP) @ B2G @ Matrix.Rotation(math.pi, 4, "Z")
        Pm = self.cpl(-30.0, 0.0)
        up = (Pm.to_3x3() @ Z).normalized()
        a = (M.to_3x3() @ Z).normalized()
        e1 = M.to_3x3() @ X
        pt = Pm @ Vector((0, 0, -0.055))
        poles = [Vector(v) for v in ((-0.8, -0.3, -1.0), (-1.0, 0.0, -0.5), (-0.3, -0.5, -1.0), (0.0, -0.2, -1.0))]
        hm, _, pole = self._solve_at(self.ATTACH_ROOTS, lambda: self.best_grip(
            "Left", pt, up, CPL_R, poles, along=0.7, diags=(10.0, 20.0), want=(e1 * 0.6 - a * 0.8), want_w=2.0))
        Hi = hm.inverted()
        hand = self.hands["Left"]
        caps = [(Pm @ Vector((0, 0, -0.049)), CPL_R + 0.001, 0.026), (Pm @ Vector((0, 0, -0.013)), CPL_NUT_R + 0.002, 0.013),
                (Pm @ Vector((0, 0, -0.12)), HOSE_R + 0.001, 0.045)]
        axes = [(Hi @ q, (Hi.to_3x3() @ up).normalized(), r, h) for q, r, h in caps]
        fing = FP.close_fingers(hand, axes)
        fing["Thumb"] = list(FP.thumb_wrap(hand, axes, Hi @ (pt + a * (CPL_R + 0.006))))
        self.cpl_hand = Pm.inverted() @ hm
        self.cpl_grip = (pole, fing)
        rep["attach_Left"] = dict(self.report["grip_choice"]["Left"])
        # the nozzle on the ground: the right hand takes it by the grip as it holds it (the palm comes down on it)
        self.tool_ground = self.cam["pickup"] @ B2G @ coil_nozzle()
        hm = self.tool_ground @ self.G["Right"]
        self.pick_pole = self._pole_for("Right", hm, self.PICK_ROOTS, [Vector(v) for v in (
            (0.8, -0.3, -1.0), (1.0, 0.0, -0.5), (0.3, -0.5, -1.0), (0.0, -0.2, -1.0), (1.0, 0.5, -0.5), (0.5, 0.5, -1.0))])
        # the aside pose of the nozzle while the left hand works the coupling: down and out to the right
        hT = self.hold["Tool"]
        self.tool_aside = Matrix.Translation(Vector((0.07, -0.06, -0.13))) @ about(hT.translation, rot(x=-35.0, y=20.0, z=-15.0)) @ hT

    def rim_grip(self, s, pt, d, a, radial, poles):
        """A hand on the rim (handle through pt along d) for a heave: the forearm near neutral twist at mid-heave
        (it turns STROKE / 2 either way), the wrist not bent past ~35 deg, the palm on the rim's front (toward
        -a) and a little outside it, in reach."""
        H = self.hands[s]
        best = None
        d = d.normalized()
        e1 = d.orthogonal().normalized()
        e2 = d.cross(e1)
        want = (-a * 0.85 - radial * 0.5).normalized()
        for pole in poles:
            pole = Vector(pole)
            for diag in (10.0, 20.0, 30.0):
                for sign in (1.0, -1.0):
                    for k in range(36):
                        ang = 2 * math.pi * k / 36
                        hm, line = H.place_axis(pt, d, e1 * math.cos(ang) + e2 * math.sin(ang), RIM_R, sign=sign,
                                                along=0.7, diag=diag)
                        n = hm.to_3x3() @ Vector((0, 0, 1))
                        tws, wr, reach = [], 0.0, 0.0
                        for rel in (-self.STROKE / 2, 0.0, self.STROKE / 2):
                            m = spin(pt - radial * WHEEL_R, a, rel) @ hm
                            rep = {}
                            E = self.arms.solve({"View": self.view_rest()}, s, m, pole, rep)
                            tws.append(rep["twist_deg"][s])
                            fo = (m.translation - E).normalized()
                            wr = max(wr, math.degrees(fo.angle(m.to_3x3() @ Vector((0, 1, 0)))))
                            reach = max(reach, rep["reach"])
                        tw = max(abs(x) for x in tws)
                        cost = (tw / 60.0 + max(0.0, tw - 75.0) / 10.0 + max(0.0, wr - 35.0) / 10.0
                                + 2.0 * (1 - n.dot(want)) + max(0.0, reach - 0.95) * 50.0)
                        if best is None or cost < best[0]:
                            best = (cost, hm, line, pole, [round(x, 1) for x in tws], round(wr, 1), round(reach, 3))
        self.report.setdefault("grip_choice", {})[s] = {"twists": best[4], "wrist": best[5], "reach": best[6],
                                                        "pole": list(best[3])}
        return best[1], best[2], best[3]

    def cpl(self, twist, drop):
        """The coupling's pose (camera space) turned `twist` deg about its axis, `drop` m below its seat."""
        return self.cpl_seat @ Matrix.Translation(Vector((0, 0, -drop))) @ Matrix.Rotation(math.radians(twist), 4, "Z")

    def _act_base(self, act, roots_k, roots):
        M = self.cam[act]
        return {"view": Matrix.Identity(4), "roots": roots * roots_k, "down": (M.to_3x3() @ -Y).normalized(),
                "hand_ang": {}, "poles": {}, "stiff": 0.0}

    def pickup_p(self, t):
        """Bend down to the nozzle lying by the coil, take it by the grip (PICK_GRAB: the coil's nozzle goes, this
        one shows), lift it into the hold; the left hand comes up under the hose."""
        k_roots = ease((t - 0.2) / 0.45) * (1.0 - ease((t - 1.0) / 0.6))
        p = self._act_base("pickup", k_roots, self.PICK_ROOTS)
        G = self.G["Right"]
        TG = self.tool_ground
        grab = TG @ G
        down = p["down"]
        if t < PICK_GRAB:
            pre = Matrix.Translation(-down * 0.09) @ grab
            m = lerp_m(low(self.hold["RightHand"], 1.0), pre, ease((t - 0.3) / 0.45))
            m = lerp_m(m, grab, ease((t - 0.7) / (PICK_GRAB - 0.08 - 0.7)))
            p["tool_m"] = TG
            p["right_m"] = m
            p["hand_ang"]["Right"] = mix(self.open_ang["Right"], self.hold_ang["Right"], ease((t - 0.74) / 0.12))
            p["scale"] = dict({"Tool": HIDE}, **{f"Hose{k}": HIDE for k in range(HOSE_BONES)})
        else:
            u = ease((t - 0.95) / 0.6)
            tool = lerp_m(TG, self.hold["Tool"], u)
            tool = Matrix.Translation(-down * 0.07 * math.sin(math.pi * u)) @ tool
            p["tool_m"] = tool
            p["hand_ang"]["Right"] = self.hold_ang["Right"]
        p["poles"]["Right"] = self.hold_pole["Right"].lerp(self.pick_pole, ease(t / 0.5) * (1.0 - ease((t - 1.0) / 0.5)))
        kl = ease((t - 1.0) / 0.6)
        p["left_m"] = lerp_m(low(self.hold["LeftHand"], 1.0), self.hold["LeftHand"], kl)
        p["hand_ang"]["Left"] = mix(self.open_ang["Left"], self.hold_ang["Left"], ease((t - 1.35) / 0.25))
        p["hose_free"] = 1.0 - ease((t - 1.15) / 0.45)
        return p

    def attach_p(self, t):
        """The nozzle aside in the right hand; the left hand brings the hose's coupling up under the tap's connector,
        pushes it on, gives it a turn and lets go (ATTACH_SWAP: the tap's own coupling shows), back under the hose."""
        k_roots = ease((t - 0.2) / 0.4) * (1.0 - ease((t - 1.5) / 0.5))
        p = self._act_base("attach", k_roots, self.ATTACH_ROOTS)
        k_aside = ease(t / 0.4) * (1.0 - ease((t - 1.5) / 0.5))
        p["tool_m"] = lerp_m(self.hold["Tool"], self.tool_aside, k_aside)
        p["hand_ang"]["Right"] = self.hold_ang["Right"]
        pole, fing = self.cpl_grip
        hL = self.hold["LeftHand"]
        H = self.cpl_hand
        pre = self.cpl(-60.0, 0.09) @ H
        if t < 0.35:
            p["left_m"] = lerp_m(hL, low(hL, 1.0), ease(t / 0.35))
            p["hand_ang"]["Left"] = mix(self.hold_ang["Left"], self.open_ang["Left"], ease(t / 0.2))
            p["coupling_m"] = low(pre, 1.0) @ H.inverted()
            p["poles"]["Left"] = self.hold_pole["Left"].lerp(pole, ease(t / 0.35))
        elif t < ATTACH_SWAP:
            if t < 0.85:
                hand = lerp_m(low(pre, 1.0), pre, ease((t - 0.35) / 0.5))
                P = hand @ H.inverted()
            elif t < 1.1:
                P = self.cpl(-60.0, 0.09 * (1.0 - ease((t - 0.85) / 0.25)))
                hand = P @ H
            else:
                P = self.cpl(-60.0 + 60.0 * ease((t - 1.1) / 0.25), 0.0)
                hand = P @ H
            k_off = ease((t - 1.36) / (ATTACH_SWAP - 1.36))      # fingers open, the hand eases off toward the camera
            p["left_m"] = Matrix.Translation((self.wheel_axis("attach") * 0.025 + p["down"] * 0.015) * k_off) @ hand
            p["coupling_m"] = P
            p["hand_ang"]["Left"] = mix(mix(self.open_ang["Left"], fing, ease((t - 0.3) / 0.2)), self.open_ang["Left"], k_off)
            p["poles"]["Left"] = pole
        else:
            rel = Matrix.Translation(self.wheel_axis("attach") * 0.025 + p["down"] * 0.015) @ self.cpl(0.0, 0.0) @ H
            k = ease((t - ATTACH_SWAP) / (ATTACH_T - 0.05 - ATTACH_SWAP))
            m = lerp_m(rel, hL, k)
            p["left_m"] = Matrix.Translation(p["down"] * 0.05 * math.sin(math.pi * k)) @ m
            p["hand_ang"]["Left"] = mix(self.open_ang["Left"], self.hold_ang["Left"], ease((t - 1.75) / 0.25))
            p["poles"]["Left"] = pole.lerp(self.hold_pole["Left"], k)
            p["scale"] = {"Coupling": HIDE}
        if t < ATTACH_SWAP:
            p["scale"] = {"Coupling": 1.0}
        p["hose_free"] = ease(t / 0.3) * (1.0 - ease((t - 1.6) / 0.45))
        return p

    def wheel_axis(self, act):
        """The prop's +z (toward the camera) in camera space."""
        return (self.cam[act].to_3x3() @ Z).normalized()

    def wheel_angle(self, t):
        """Degrees the wheel has turned at valve clip time t (counterclockwise, seen from the front)."""
        return sum(self.STROKE * ease((t - a) / (b - a)) for a, b in self.STROKES)

    def valve_p(self, t):
        """Let the nozzle drop, both hands on the rim, four heaves of 90 deg with a regrip between (one turn:
        valve.gd TURNS), let go and reach down out of view (fire.gd then raises the nozzle again: raise)."""
        end = self.STROKES[-1][1]
        k_roots = ease(t / 0.35) * (1.0 - ease((t - end - 0.1) / 0.3))
        p = self._act_base("valve", k_roots, self.VALVE_ROOTS)
        c, a, e1, e2 = self.wheel
        down = p["down"]
        # the nozzle: let go at 0.05 s, it falls away out of view (on its hose)
        hT = self.hold["Tool"]
        tau = max(0.0, t - 0.05)
        fall = min(0.5 * 9.8 * tau * tau, 1.2)
        p["tool_m"] = Matrix.Translation(down * fall + a * 0.1 * min(tau / 0.4, 1.0)) @ \
            about(hT.translation, rot(x=-100.0 * ease(tau / 0.4), z=25.0 * ease(tau / 0.4))) @ hT
        p["hose_free"] = ease(t / 0.15)
        p["turn"] = self.wheel_angle(t) / (360.0 * VALVE_TURNS)
        for s in ("Right", "Left"):
            hm, pole, fing, mid = self.rim[s]

            def at(rel, lift):
                return Matrix.Translation(a * lift) @ spin(c, a, rel) @ hm

            start = -self.STROKE / 2
            hold_m = self.hold[s + "Hand"]
            open_a = self.open_ang[s]
            first = self.STROKES[0][0]
            if t < first:
                # off the nozzle / hose, up to the rim (just short of it till the camera is there: LOCK_IN), onto it
                out = at(start, 0.0).translation - c
                out -= a * out.dot(a)
                pre = Matrix.Translation(a * 0.08 + out * 0.25) @ at(start, 0.0)    # back toward the camera, outside the rim
                m = lerp_m(hold_m, pre, ease((t - 0.06) / (LOCK_IN - 0.06)))
                m = lerp_m(m, at(start, 0.0), ease((t - LOCK_IN) / (first - 0.02 - LOCK_IN)))
                ang = mix(mix(self.hold_ang[s], open_a, ease(t / 0.1)), fing, ease((t - LOCK_IN) / (first - LOCK_IN)))
                p["poles"][s] = self.hold_pole[s].lerp(pole, ease(t / 0.35))
            elif t >= end:
                # let go, back off the wheel, down out of view
                u = ease((t - end) / 0.12)
                m = at(-start, 0.05 * u)
                m = lerp_m(m, low(m, 1.0), ease((t - end - 0.1) / (VALVE_T - end - 0.12)))
                ang = mix(fing, open_a, u)
                p["poles"][s] = pole
            else:
                rel, lift, k = start, 0.0, 1.0
                for i, (sa, sb) in enumerate(self.STROKES):
                    if sa <= t < sb:
                        rel = start + self.STROKE * ease((t - sa) / (sb - sa))
                        break
                    nxt = self.STROKES[i + 1][0] if i + 1 < len(self.STROKES) else None
                    if nxt is not None and sb <= t < nxt:
                        # regrip: open, swing back clear of the rim, close again
                        u = (t - sb) / (nxt - sb)
                        k = 1.0 - pulse(u, 0.0, 1.0) ** 0.5
                        rel = -start - self.STROKE * ease((u - 0.2) / 0.6)
                        lift = 0.03 * math.sin(math.pi * min(max((u - 0.1) / 0.8, 0.0), 1.0))
                        break
                m = at(rel, lift)
                ang = mix(open_a, fing, k)
                p["poles"][s] = pole
            p[s.lower() + "_m"] = m
            p["hand_ang"][s] = ang
        return p


# ---------------------------------------------------------------- empty hands
class Empty(ViewModel):
    """No tool: both hands relaxed and half open, low in front of the body, only the fingers and the backs of the
    hands peeking up over the bottom of the frame (the arms the player sees before he has picked anything up)."""
    name = "empty"
    SPLIT_FINGERS = True
    # wrist (camera space), fingers' direction, the palm's facing (right hand; the left is its mirror)
    WRIST = Vector((0.19, 0.3, -0.335))
    FINGERS = Vector((-0.15, 0.8, 0.5))
    PALM = Vector((-0.8, 0.1, -0.6))
    # half open: knuckle, middle, end joint flexion (deg), more toward the little finger; the thumb loose
    RELAXED = {"Thumb": [8.0, 12.0, 15.0, 15.0], "Index": [16.0, 24.0, 12.0], "Middle": [20.0, 28.0, 14.0],
               "Ring": [24.0, 32.0, 16.0], "Pinky": [28.0, 34.0, 18.0]}

    def setup_tool(self):
        pass

    def solve_grips(self):
        self.H = {}
        self.pole = {}
        for s, sx in (("Right", 1.0), ("Left", -1.0)):
            m = FP.frame(Vector((sx * self.FINGERS.x, self.FINGERS.y, self.FINGERS.z)),
                         Vector((sx * self.PALM.x, self.PALM.y, self.PALM.z))).to_4x4()
            m.translation = Vector((sx * self.WRIST.x, self.WRIST.y, self.WRIST.z))
            self.H[s] = m
            self.pole[s] = self._pole_for(s, m)
        self.report["hold"] = {s: [round(x, 3) for x in self.H[s].translation] for s in self.H}

    def _pole_for(self, s, hm):
        sx = 1.0 if s == "Right" else -1.0
        best = None
        for c in ((0.6, -0.2, -1.0), (1.0, 0.0, -0.6), (0.3, -0.4, -1.0), (0.0, -0.2, -1.0)):
            c = Vector((sx * c[0], c[1], c[2]))
            rep = {}
            self.arms.solve({"View": self.view_rest()}, s, hm, c, rep)
            tw = abs(rep["twist_deg"][s])
            if best is None or tw < best[0]:
                best = (tw, c)
        return best[1]

    def tool_world(self, world, p):
        pass

    def hand_targets(self, world, p):
        V = world["View"]
        return {s: (V @ p.get(s.lower(), Matrix.Identity(4)) @ self.H[s], V.to_3x3() @ self.pole[s])
                for s in ("Right", "Left")}

    def fingers(self, p):
        out = {}
        for s in ("Left", "Right"):
            c = p.get("curl", {}).get(s, 0.0)
            out[s] = {f: [x + (c if f != "Thumb" else 0.3 * c) for x in v] for f, v in self.RELAXED.items()}
        return out

    def extra(self, world, p):
        pass

    def clips(self):
        mid = (self.H["Right"].translation + self.H["Left"].translation) / 2
        return [("idle", [self.idle_p(i / FPS) for i in range(4 * FPS + 1)], True),
                ("walk", [self.walk_p(i / FPS) for i in range(FPS + 1)], True),
                ("raise", raise_params(self.idle_p(0.0), mid, 12, whole=True), False),
                ("lower", raise_params(self.idle_p(0.0), mid, 9, whole=True)[::-1], False)]

    def idle_p(self, t):
        """Breathing; the fingers flex a little now and then, one hand after the other."""
        w = 2 * math.pi * t / 4
        p = {"view": breath(t)}
        p["right"] = Matrix.Translation(Vector((0.0, 0.0, 0.003 * math.sin(w + 0.6))))
        p["left"] = Matrix.Translation(Vector((0.0, 0.0, 0.003 * math.sin(w - 0.4))))
        p["curl"] = {"Right": 6.0 * pulse(t, 0.8, 1.8), "Left": 6.0 * pulse(t, 2.4, 3.4)}
        return p

    def walk_p(self, ph):
        """One loop = two steps: the hands swing a little against each other with the steps."""
        w = 2 * math.pi * ph
        p = {"view": step_bob(ph)}
        sw = 0.012 * math.sin(w)
        p["right"] = Matrix.Translation(Vector((0.0, sw, 0.004 * math.sin(2 * w - 0.8)))) @ about(self.H["Right"].translation, rot(x=4.0 * math.sin(w)))
        p["left"] = Matrix.Translation(Vector((0.0, -sw, 0.004 * math.sin(2 * w - 0.8)))) @ about(self.H["Left"].translation, rot(x=-4.0 * math.sin(w)))
        return p


def lerp_m(a, b, t):
    la, ra, _ = a.decompose()
    lb, rb, _ = b.decompose()
    m = ra.slerp(rb, t).to_matrix().to_4x4()
    m.translation = la.lerp(lb, t)
    return m


def bezier(a, b, c, d, n):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(a * u * u * u + b * 3 * u * u * t + c * 3 * u * t * t + d * t * t * t)
    return out


def mix(a, b, k):
    """Finger angles {finger: [deg]} from a to b."""
    return {f: [x + (y - x) * k for x, y in zip(a[f], b[f])] for f in a}


def low(m, k):
    """A hand / tool matrix taken down out of view (k = 1) like raise_params' low pose."""
    c = m.translation
    return Matrix.Translation(Vector((0.0, -0.12 * k, -0.26 * k))) @ about(c, rot(x=-35.0 * k)) @ m


def spin(c, axis, deg):
    """Rotation by deg about the line through c along axis."""
    return Matrix.Translation(c) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-c)


def godot_cam(eye, yaw, pitch):
    """Prop-local (Godot) -> camera space (Blender) for a camera at eye (prop-local), turned yaw deg about +y and
    pitched (deg, + up) like fire.gd's player and head."""
    cam = Matrix.Translation(eye) @ Matrix.Rotation(math.radians(yaw), 4, "Y") @ Matrix.Rotation(math.radians(pitch), 4, "X")
    return G2B @ cam.inverted()


def coil_nozzle():
    """The nozzle lying by the coil: part space -> coil-local (Blender)."""
    rx, ry, rz = (math.radians(v) for v in COIL_NOZZLE_ROT)
    return (Matrix.Translation(COIL_NOZZLE_LOC) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y")
            @ Matrix.Rotation(rx, 4, "X"))


TOOLS = {"cutters": Cutters, "nozzle": Nozzle, "empty": Empty}
