"""The two first-person view models of fp_arms.py: the farmer's arms holding the bolt cutters or the hose nozzle.
Tool parts come from tools/models/fire/fp_tools.py (work/fp_tools/*.glb). Camera space (Blender): +x right,
+y forward, +z up, the eye at the origin; Godot gets -z forward, +y up (glTF export).

Every clip is a full pose of every bone, baked at 30 fps from parameters:
  view   the View bone (root): breathing, step bob (the arms and the tool move as one, from the shoulders)
  tool   the tool's pose under View; the hands follow the grips (two-bone IK, fingers solved on the handles)
  open   cutters: half opening angle of the arms (deg); squeeze: fingers pressing in (0..1)
  trigger nozzle: trigger lever pulled (0..1); the index finger follows it
"""
import bpy, json, math, os
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion, Euler

import fp_pose as FP

HERE = Path(__file__).resolve().parent
WORK = HERE / "work"
PARTS = WORK / "fp_tools"
FPS = 30
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

# --- tool constants (tools/models/fire/cutters.py, fp_tools.py)
C_ARM_Y, C_END_Y, C_GRIP_Y, C_GR = 0.12, 0.64, 0.40, 0.021
N_TRIGGER_PIVOT = Vector((0.0, -0.03, 0.034))
N_GRIP_RAKE = 14.0
N_GRIP_C = Vector((0.0, 0.034, -0.012))
N_INLET = Vector((0.0, 0.034 + math.sin(math.radians(14.0)) * 0.112, -0.012 - math.cos(math.radians(14.0)) * 0.112))
N_MUZZLE = Vector((0.0, -0.248, 0.06))
HOSE_R, HOSE_LEN, HOSE_BONES = 0.022, 1.1, 11


def handle_x(s, y):
    if y <= C_ARM_Y:
        return s * 0.035 * y / C_ARM_Y
    return s * (0.035 + 0.055 * (y - C_ARM_Y) / (C_END_Y - C_ARM_Y))


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
    """bones: [(name, parent, rest 4x4 camera space, length)]."""
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    for name, parent, m, ln in bones:
        b = eb.new(name)
        b.head = m.translation
        b.tail = m.translation + m.to_3x3() @ Vector((0, ln, 0))
        b.align_roll(m.to_3x3() @ Vector((0, 0, 1)))
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

    def __init__(self):
        bpy.ops.wm.open_mainfile(filepath=str(WORK / "fp_rig.blend"))
        bpy.context.preferences.filepaths.save_version = 0
        sc = bpy.context.scene
        sc.render.fps, sc.render.fps_base = FPS, 1
        self.rig = bpy.data.objects["fp_rig"]
        self.arms_ob = bpy.data.objects["fp_arms"]
        self.report = {"name": self.name, "clips": {}}
        self.setup_tool()
        self.R = FP.Rig(self.rig, self.arms_ob)
        self.arms = FP.Arms(self.R)
        self.hands = {s: FP.Hand(self.R, s) for s in ("Left", "Right")}
        self.solve_grips()

    # subclasses: setup_tool(), solve_grips(), tool_world(world, p), hand_targets(world, p), fingers(p), extra(world, p)
    def pose(self, p):
        """Full world pose of every bone for parameters p."""
        R = self.R
        world = {}
        V = p.get("view", Matrix.Identity(4))
        world["View"] = R.rest["View"] @ V
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
                        world = {"View": R.rest["View"].copy()}
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
            for n in R.order:
                pb = rig.pose.bones[n]
                q = basis[n].to_quaternion()
                if n in prev:
                    q.make_compatible(prev[n])
                prev[n] = q
                pb.rotation_quaternion = q
                pb.location = basis[n].translation
                pb.keyframe_insert("rotation_quaternion", frame=i)
                pb.keyframe_insert("location", frame=i)
        rig.animation_data.action = None
        self.report["clips"][clip] = {"frames": len(params), "loop": loop,
                                      "reach_max": round(self.report["ik"].get("reach", 0.0), 3),
                                      "twist_deg": self.report["ik"].get("twist_deg")}
        print("CLIP", self.name, clip, json.dumps(self.report["clips"][clip]), flush=True)
        return act

    def set_pose(self, p):
        """Pose the rig (no keys) for a render."""
        basis = self.R.basis(self.pose(p))
        for n in self.R.order:
            pb = self.rig.pose.bones[n]
            pb.rotation_quaternion = basis[n].to_quaternion()
            pb.location = basis[n].translation
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
    PIVOT = Vector((0.0, 1.04, -0.285))     # the tool's pivot bolt, camera space (the head just under the prompt)
    PITCH = -7.5                             # head down (deg)
    OPEN = 7.0                               # half opening of the arms, jaws open (deg)
    CLOSED = 0.6
    GRIP_Y = 0.618                           # hand centre along each handle (tool space): the end cap in the fist

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
        d = Vector((s * 0.055 / (C_END_Y - C_ARM_Y), 1.0, 0.0)).normalized()
        return half_w @ p, (half_w.to_3x3() @ -d).normalized()             # toward the head

    def solve_grips(self):
        R = self.R
        world = {"View": R.rest["View"].copy()}
        world["Tool"] = self.t0()
        self.G = {}
        self.ang = {}
        self.pole = {}
        for s, side, sgn in (("Right", -1, 1.0), ("Left", 1, -1.0)):
            hw = self.half_world(world, side, self.OPEN)
            pt, d = self.grip_line(hw, side)
            poles = [Vector(v) for v in ((sgn * 0.7, -0.25, -1.0), (sgn, -0.2, -0.3), (sgn * 0.3, -1.0, -0.6),
                                        (sgn * 0.8, -0.8, -0.5), (0.0, -0.2, -1.0))]
            hm, (p_h, d_h), self.pole[s] = self.best_grip(s, pt, d, C_GR, poles, along=0.72, diags=(20.0, 30.0, 40.0))
            self.G[s] = hw.inverted() @ hm
            axes = [(p_h, d_h, C_GR + 0.001, 0.12)]
            fing = FP.close_fingers(self.hands[s], axes)
            tgt = p_h + Vector((0, 0, 1)) * (C_GR + 0.006) + d_h * 0.022
            th = FP.thumb_wrap(self.hands[s], axes, tgt)
            fing["Thumb"] = list(th)
            tight = FP.close_fingers(self.hands[s], axes, squeeze=0.003, start=fing)
            tight["Thumb"] = list(th)
            self.ang[s] = (fing, tight)
            self.report.setdefault("grip", {})[s] = {k: [round(float(x), 1) for x in v] for k, v in fing.items()}

    def tool_world(self, world, p):
        world["Tool"] = world["View"] @ p.get("tool", Matrix.Identity(4)) @ self.t0()
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
        out.append(("raise", raise_params(self.idle_p(0.0), GRIPS_C, 12), False))
        out.append(("lower", raise_params(self.idle_p(0.0), GRIPS_C, 9)[::-1], False))
        return out

    def idle_p(self, t):
        p = {"view": breath(t), "tool": about(GRIPS_C, rot(z=0.35 * math.sin(2 * math.pi * t / 4 + 0.8),
                                                             x=0.25 * math.sin(2 * math.pi * 2 * t / 4)))}
        # the hands work the grips now and then: the right one closes harder, the left one eases and takes hold
        p["curl"] = {"Right": 6.0 * pulse(t, 2.2, 2.9), "Left": -9.0 * pulse(t, 0.7, 1.35)}
        p["squeeze"] = 0.35 * pulse(t, 2.2, 2.9)
        return p

    def walk_p(self, ph):
        p = {"view": step_bob(ph)}
        p["tool"] = about(GRIPS_C, rot(x=1.3 * math.sin(4 * math.pi * ph - 0.6), y=1.4 * math.sin(2 * math.pi * ph + 0.4)))
        p["open"] = self.OPEN + 0.5 * math.sin(4 * math.pi * ph - 1.2)
        return p

    def snip_p(self, u):
        p = self.idle_p(0.0)
        p["open"] = self.OPEN + (self.CLOSED - self.OPEN) * u
        p["squeeze"] = u
        p["curl"] = {"Right": 3.0 * u, "Left": 3.0 * u}
        p["tool"] = about(GRIPS_C, rot(x=0.8 * u)) @ Matrix.Translation(Vector((0, 0.008 * u, 0.004 * u)))
        p["view"] = breath(0.0) @ rot(x=-0.4 * u)
        return p


GRIPS_C = Vector((0.0, 0.43, -0.2))         # between the hands: pivot of the tool's sway


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


def raise_params(hold, c, n):
    """n+1 frames from the tool down out of view to the hold pose (frame n = hold)."""
    out = []
    for i in range(n + 1):
        u = i / n
        e = 1 - (1 - u) ** 3                                      # fast then settling
        k = 1 - e
        p = dict(hold)
        low = about(c, rot(x=-38 * k, y=14 * k, z=-8 * k), Vector((0.03 * k, -0.06 * k, -0.30 * k)))
        p["tool"] = low @ hold.get("tool", Matrix.Identity(4))
        p["view"] = hold.get("view", Matrix.Identity(4))
        out.append(p)
    return out


# ---------------------------------------------------------------- the hose nozzle
class Nozzle(ViewModel):
    name = "nozzle"
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
        world["Tool"] = world["View"] @ p.get("tool", Matrix.Identity(4)) @ self.t0()
        world["Trigger"] = world["Tool"] @ self.R.rel["Trigger"] @ rot(x=self.TRIGGER * p.get("trigger", 0.0))
        world["Muzzle"] = world["Tool"] @ self.R.rel["Muzzle"]

    def hand_targets(self, world, p):
        left = world["View"] @ p.get("left", Matrix.Identity(4)) @ self.left_hand
        V = world["View"].to_3x3()
        return {"Right": (world["Tool"] @ self.G["Right"], V @ self.pole["Right"]), "Left": (left, V @ self.pole["Left"])}

    def fingers(self, p):
        out = {}
        for s in ("Left", "Right"):
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
        out.append(("raise", raise_params(self.idle_p(0.0), self.GRIP, 12), False))
        out.append(("lower", raise_params(self.idle_p(0.0), self.GRIP, 9)[::-1], False))
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
        """Water on: trigger held, the nozzle pushed back and up by the jet, shivering with the pressure."""
        w = 2 * math.pi * t
        p = self.idle_p(0.0)
        kick = Vector((0.0015 * math.sin(7 * w), -0.011 + 0.0015 * math.sin(5 * w + 1.0), 0.003 + 0.0012 * math.sin(9 * w)))
        p["tool"] = about(self.GRIP, rot(x=1.6 + 0.35 * math.sin(6 * w + 0.5), z=0.3 * math.sin(4 * w)), kick)
        p["left"] = Matrix.Translation(Vector((0.0, -0.006, 0.004 + 0.001 * math.sin(7 * w + 2.0))))
        p["trigger"] = 1.0
        p["squeeze"] = 1.0
        p["stiff"] = 1.0
        p["view"] = breath(0.0) @ rot(x=0.3 * math.sin(3 * w))
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


TOOLS = {"cutters": Cutters, "nozzle": Nozzle}
