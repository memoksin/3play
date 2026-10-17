"""Retarget Quaternius UAL clips (and clips built on them) onto the rigs from rig.py, export one GLB each.

blender -b --factory-startup --python-exit-code 1 -P tools/models/meshy/retarget.py [-- name ...]
In:  work/<name>_rig.blend, UAL1_Standard.glb (Universal Animation Library [Standard], Quaternius, CC0;
     $UAL or ~/Downloads/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb).
Out: assets/3d/kahramanmaras/meshy_<name>.glb (512 px JPEG texture, clips named <clip>_loop: Godot strips
     the suffix and loops them), work/<name>_anim.blend, work/<name>_report.json.

Retarget maths as in pf_3d tools/anim/bloom/retarget_ual.py: per frame the UAL bone's world rotation times
a rest delta; the arm and leg chains are rest-aligned (the UAL bone's rest direction swung onto ours) so the
T-pose/A-pose and leg splay differences do not leak into every clip. Hips translation scaled by hip height.
Then, on top of the UAL motion (clips.py): slower and tired walks, a cold shiver, a trapped-under-rubble
loop, a kneeling dig loop and a wave. Arm clearance: per frame the arm chain is tested against the skinned
body (numpy skinning, star-shaped slices in chest and hip space); a penetrating arm is swung outward about
the chest's forward axis, the swing eased at <= 3 deg/frame (loops wrap). Grounding: lowest skinned vertex.
"""
import bpy, json, math, os, sys
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from meshy_lib import NAMES
import clips as C
import motion_quality as MQ

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
UAL = os.environ.get("UAL", str(Path.home() / "Downloads/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb"))
DEST = HERE.parents[2] / "assets/3d/kahramanmaras"
WORK = HERE / "work"
FPS = 30
TEX = 512
MAX_STEP_DEG = 3.0

MAP = [
    ("Hips", "pelvis"), ("Spine02", "spine_01"), ("Spine01", "spine_02"), ("Spine", "spine_03"),
    ("neck", "neck_01"), ("Head", "Head"),
    ("LeftShoulder", "clavicle_l"), ("LeftArm", "upperarm_l"), ("LeftForeArm", "lowerarm_l"), ("LeftHand", "hand_l"),
    ("RightShoulder", "clavicle_r"), ("RightArm", "upperarm_r"), ("RightForeArm", "lowerarm_r"), ("RightHand", "hand_r"),
    ("LeftUpLeg", "thigh_l"), ("LeftLeg", "calf_l"), ("LeftFoot", "foot_l"), ("LeftToeBase", "ball_l"),
    ("RightUpLeg", "thigh_r"), ("RightLeg", "calf_r"), ("RightFoot", "foot_r"), ("RightToeBase", "ball_r"),
]
BONES = [p for p, _ in MAP]
UAL_OF = dict(MAP)
REST_ALIGN = {f"{s}{p}": f"{s}{q}" for s in ("Left", "Right") for p, q in
              (("Shoulder", "Shoulder"), ("Arm", "Arm"), ("ForeArm", "ForeArm"), ("Hand", "ForeArm"),
               ("UpLeg", "UpLeg"), ("Leg", "Leg"))}


class Rig:
    """Rest data, forward kinematics and numpy skinning of one character."""

    def __init__(self, rig, body):
        self.obj, self.body = rig, body
        self.rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones}
        self.length = {b.name: b.length for b in rig.data.bones}
        self.rel = {n: (self.rest[p].inverted() @ self.rest[n]) if p else self.rest[n] for n, p in self.parent.items()}
        names = [b.name for b in rig.data.bones]
        self.names = names
        me = body.data
        self.co = np.array([tuple(v.co) for v in me.vertices])
        self.w = np.zeros((len(self.co), len(names)))
        gi = {g.index: names.index(g.name) for g in body.vertex_groups}
        for v in me.vertices:
            for g in v.groups:
                self.w[v.index, gi[g.group]] = g.weight
        self.w /= self.w.sum(axis=1, keepdims=True)
        self.part = np.array([a.value for a in me.attributes["qa_part"].data])   # head torso arm leg skirt
        self.rest_inv = np.array([np.array(self.rest[n].inverted()) for n in names])
        self.used = [i for i in range(len(names)) if self.w[:, i].any()]
        self.edges = np.array([tuple(e.vertices) for e in me.edges])
        self.rest_len = np.linalg.norm(self.co[self.edges[:, 0]] - self.co[self.edges[:, 1]], axis=1)

    def fk(self, frame):
        """frame: {'rot': {bone: Quaternion basis}, 'loc': Vector hips world position} -> world 4x4 per bone."""
        out = {}
        for n in self.names:
            q = frame["rot"].get(n, Quaternion())
            p = self.parent[n]
            if p is None:
                m = self.rest[n] @ q.to_matrix().to_4x4()
                m.translation = frame["loc"]
            else:
                m = out[p] @ self.rel[n] @ q.to_matrix().to_4x4()
            out[n] = m
        return out

    def skin(self, world):
        M = np.array([np.array(world[n]) for n in self.names]) @ self.rest_inv
        out = np.zeros_like(self.co)
        h = np.c_[self.co, np.ones(len(self.co))]
        for i in self.used:
            out += self.w[:, i:i + 1] * (h @ M[i].T)[:, :3]
        return out

    def basis_of(self, world):
        """World matrices -> basis rotations (+ hips location)."""
        rot = {}
        for n in BONES:
            p = self.parent[n]
            if p is None:
                b = self.rest[n].inverted() @ world[n]
            else:
                b = self.rel[n].inverted() @ world[p].inverted() @ world[n]
            rot[n] = b.to_quaternion().normalized()
        return {"rot": rot, "loc": world["Hips"].translation.copy()}


def load_ual(rig):
    before_a = {a.name for a in bpy.data.actions}
    existing = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=UAL)
    imported = [o for o in bpy.data.objects if o not in existing]
    src = next(o for o in imported if o.type == "ARMATURE")
    acts = {a.name: a for a in bpy.data.actions if a.name not in before_a}
    return src, imported, acts


class Retarget:
    def __init__(self, R, src):
        self.R, self.src = R, src
        rig = R.obj
        sw = src.matrix_world
        self.S = rig.data.bones["LeftUpLeg"].head_local.z / (sw @ src.data.bones["thigh_l"].head_local).z
        src_w = sw.to_3x3()

        def align(pn):
            if pn not in REST_ALIGN:
                return Matrix.Identity(3)
            q = REST_ALIGN[pn]
            sb, tb = src.data.bones[UAL_OF[q]], rig.data.bones[q]
            sd = (src_w @ (sb.tail_local - sb.head_local)).normalized()
            td = (tb.tail_local - tb.head_local).normalized()
            return sd.rotation_difference(td).to_matrix()

        self.align = align
        self.delta = {pn: (align(pn) @ src_w @ src.data.bones[un].matrix_local.to_3x3()).inverted() @ R.rest[pn].to_3x3()
                      for pn, un in MAP}
        self.src_rest_head = {un: sw @ src.data.bones[un].head_local for _, un in MAP}
        # straightened legs reach lower than the bound splayed ones: lift the hips by the difference
        frame = {"rot": {}, "loc": R.rest["Hips"].translation.copy()}
        low0 = R.skin(R.fk(frame))[:, 2].min()
        for s in ("Left", "Right"):
            th, sh, ft = (R.rest[f"{s}{b}"].to_3x3() for b in ("UpLeg", "Leg", "Foot"))
            a_th, a_sh = align(f"{s}UpLeg"), align(f"{s}Leg")
            frame["rot"][f"{s}UpLeg"] = (th.inverted() @ a_th.inverted() @ th).to_quaternion()
            frame["rot"][f"{s}Leg"] = (sh.inverted() @ a_th @ a_sh.inverted() @ sh).to_quaternion()
            frame["rot"][f"{s}Foot"] = (ft.inverted() @ a_sh @ ft).to_quaternion()
        self.leg_lift = float(low0 - R.skin(R.fk(frame))[:, 2].min())

    def sample(self, act, f0=None, f1=None):
        """Frames of a UAL action at FPS (scene is at FPS when UAL is imported, so frames are integers)."""
        src, R = self.src, self.R
        src.animation_data.action = act
        if act.slots:
            src.animation_data.action_slot = act.slots[0]
        a0, a1 = (int(round(v)) for v in act.frame_range)
        f0 = a0 if f0 is None else f0
        f1 = a1 if f1 is None else f1
        out = []
        sc = bpy.context.scene
        for f in range(f0, f1 + 1):
            sc.frame_set(f)
            world = {}
            for pn, un in MAP:
                sm = src.matrix_world @ src.pose.bones[un].matrix
                m = (sm.to_3x3().normalized() @ self.delta[pn]).to_4x4()
                if pn == "Hips":
                    m.translation = R.rest[pn].translation + (sm.translation - self.src_rest_head[un]) * self.S
                    m.translation.z += self.leg_lift
                else:
                    p = R.parent[pn]
                    m.translation = (world[p] @ R.rel[pn]).translation
                world[pn] = m
            out.append(R.basis_of(world))
        return out


# ---------------------------------------------------------------- arm clearance
BINS = 48


class Envelope:
    """Star-shaped slices of a point cloud around a bone's axis, in that bone's space (Y up the bone)."""

    def __init__(self, pts):
        self.y = np.linspace(pts[:, 1].min(), pts[:, 1].max(), 30)
        dy = self.y[1] - self.y[0]
        self.r = np.zeros((len(self.y), BINS))
        a, rad = self.polar(pts)
        for i, y in enumerate(self.y):
            m = np.abs(pts[:, 1] - y) < dy * 1.5
            np.maximum.at(self.r[i], a[m], rad[m])

    @staticmethod
    def polar(p):
        return ((np.arctan2(p[:, 2], p[:, 0]) % (2 * np.pi)) / (2 * np.pi) * BINS).astype(int) % BINS, np.hypot(p[:, 0], p[:, 2])

    def depth(self, p, pad):
        a, rad = self.polar(p)
        yi = np.clip(np.round(np.interp(p[:, 1], self.y, np.arange(len(self.y)))).astype(int), 0, len(self.y) - 1)
        d = self.r[yi, a] + pad - rad
        d[(p[:, 1] < self.y[0]) | (p[:, 1] > self.y[-1])] = -1
        return d


class Clearance:
    UPPER = ("Spine02", "Spine01", "Spine", "neck", "LeftShoulder", "RightShoulder")

    def __init__(self, R):
        self.R = R
        dom = np.array(R.names)[np.argmax(R.w, axis=1)]
        part = R.part
        self.upper = np.isin(dom, self.UPPER) & (part == 1)
        self.lower = ((part == 1) & (dom == "Hips")) | (part == 4) | ((part == 3) & np.isin(dom, ["LeftUpLeg", "RightUpLeg"]))
        self.radius = {}
        for s in ("Left", "Right"):
            for b in ("Arm", "ForeArm", "Hand"):
                n = s + b
                bb = R.obj.data.bones[n]
                h, t = np.array(bb.head_local), np.array(bb.tail_local)
                u = (t - h) / np.linalg.norm(t - h)
                m = (dom == n) & (part == 2)
                q = R.co[m] - h
                d = np.linalg.norm(q - np.outer(q @ u, u), axis=1)
                self.radius[n] = float(np.percentile(d, 60)) if len(d) else 0.04

    def samples(self, world, s):
        pts, rad = [], []
        for b, t0 in (("Arm", 0.55), ("ForeArm", 0.0), ("Hand", 0.0)):
            n = s + b
            L = self.R.length[n]
            for t in np.linspace(t0, 1, 7):
                pts.append(tuple(world[n] @ Vector((0, L * t, 0))))
                rad.append(self.radius[n] * 0.85)
        return np.array(pts), np.array(rad)

    def envelopes(self, world, skinned):
        out = []
        for mask, bone in ((self.upper, "Spine"), (self.lower, "Hips")):
            inv = np.array(world[bone].inverted())
            p = skinned[mask] @ inv[:3, :3].T + inv[:3, 3]
            out.append((bone, Envelope(p), inv))
        return out

    def depth(self, envs, pts, rad):
        d = -1.0
        for _, env, inv in envs:
            p = pts @ inv[:3, :3].T + inv[:3, 3]
            d = max(d, float(env.depth(p, rad + 0.006).max()))
        return d


def swing_arm(R, frame, world, side, deg):
    """Swing the upper arm outward about the chest's forward axis through the shoulder joint."""
    if abs(deg) < 1e-6:
        return frame
    sgn = 1 if side == "Left" else -1
    fwd = (world["Spine"].to_3x3() @ (R.rest["Spine"].to_3x3().inverted() @ Vector((0, -1, 0)))).normalized()
    rot = Matrix.Rotation(math.radians(deg) * sgn, 3, fwd)      # left arm: outward = towards +x
    n = side + "Arm"
    par = world[R.parent[n]]
    cur = world[n].to_3x3()
    new = rot @ cur
    local = (R.rel[n].to_3x3().inverted() @ par.to_3x3().inverted() @ new).to_quaternion()
    out = {"rot": dict(frame["rot"]), "loc": frame["loc"]}
    out["rot"][n] = local.normalized()
    return out


def ease(need, loop):
    """Smallest envelope >= need that changes at most MAX_STEP_DEG per frame (wrapping for loops)."""
    need = np.asarray(need, float)
    n = len(need)
    idx = np.arange(n)
    out = np.zeros(n)
    for g in np.flatnonzero(need > 0):
        dist = np.abs(idx - g)
        if loop:
            dist = np.minimum(dist, n - 1 - dist)
        out = np.maximum(out, need[g] - MAX_STEP_DEG * dist)
    return out


def clear_arms(R, CL, frames, loop, rep, sides=("Left", "Right")):
    needs = {s: [] for s in sides}
    for fr in frames:
        world = R.fk(fr)
        envs = CL.envelopes(world, R.skin(world))
        for s in sides:
            need = 0
            for deg in range(0, 61, 2):
                f2 = swing_arm(R, fr, world, s, deg)
                w2 = R.fk(f2) if deg else world
                pts, rad = CL.samples(w2, s)
                if CL.depth(envs, pts, rad) <= 0:
                    need = deg
                    break
            else:
                need = 60
            needs[s].append(need)
    applied = {s: ease(needs[s], loop) for s in needs}
    if loop:                 # last frame repeats the first
        for s in applied:
            applied[s][-1] = applied[s][0]
    out = []
    for i, fr in enumerate(frames):
        for s in sides:
            fr = swing_arm(R, fr, R.fk(fr), s, float(applied[s][i]))
        out.append(fr)
    rep["arm_swing_max_deg"] = {s: float(applied[s].max()) for s in applied}
    return out


# ---------------------------------------------------------------- grounding
def ground(R, frames, mode, rep):
    lows = np.array([R.skin(R.fk(fr))[:, 2].min() for fr in frames])
    if mode == "per_frame":
        shift = -lows
    elif mode == "constant":
        shift = np.full(len(lows), -lows.min())
    else:
        shift = np.zeros(len(lows))
    for fr, d in zip(frames, shift):
        fr["loc"] = fr["loc"] + Vector((0, 0, float(d)))
    rep["ground"] = {"mode": mode, "low_before": [round(float(lows.min()), 4), round(float(lows.max()), 4)]}
    return frames


def bake(R, name, frames):
    rig = R.obj
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    prev = {}
    for i, fr in enumerate(frames):
        for n in BONES:
            pb = rig.pose.bones[n]
            q = fr["rot"][n].copy()
            if n in prev:
                q.make_compatible(prev[n])
            prev[n] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=i)
            if n == "Hips":
                pb.location = R.rest["Hips"].inverted().to_3x3() @ (fr["loc"] - R.rest["Hips"].translation)
                pb.keyframe_insert("location", frame=i)
    rig.animation_data.action = None
    return act


def main():
    for name in ARGS or NAMES:
        bpy.ops.wm.open_mainfile(filepath=str(WORK / f"{name}_rig.blend"))
        bpy.context.preferences.filepaths.save_version = 0
        sc = bpy.context.scene
        sc.render.fps, sc.render.fps_base = FPS, 1
        rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
        body = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent is rig)
        for pb in rig.pose.bones:
            pb.rotation_mode = "QUATERNION"
        rig.animation_data_create()
        R = Rig(rig, body)
        src, imported, acts = load_ual(rig)
        if not src.animation_data:
            src.animation_data_create()
        RT = Retarget(R, src)
        CL = Clearance(R)
        rep = {"name": name, "translation_scale": RT.S, "leg_lift": RT.leg_lift, "clips": {}}
        print(name, "S", round(RT.S, 3), "lift", round(RT.leg_lift, 4), flush=True)
        made = []
        for clip in C.CLIPS_OF[name]:
            spec = C.SPECS[clip]
            crep = {"source": spec["source"]}
            frames = RT.sample(acts[spec["source"]], *spec.get("range", (None, None)))
            raw = frames
            frames = spec["build"](R, frames, name) if "build" in spec else frames
            ref = [dict(fr) for fr in frames]
            if spec.get("clear", True) and not os.environ.get("NOCLEAR"):
                frames = clear_arms(R, CL, frames, True, crep, spec.get("clear_sides", ("Left", "Right")))
            frames = ground(R, frames, spec.get("ground", "per_frame"), crep)
            crep.update(MQ.report(R, frames, ref, FPS))
            crep["frames"] = len(frames)
            rep["clips"][clip] = crep
            made.append(bake(R, clip + "_loop", frames))
            print("CLIP", name, clip, json.dumps(crep), flush=True)
        for o in imported:
            bpy.data.objects.remove(o, do_unlink=True)
        for a in list(bpy.data.actions):
            if a not in made:
                bpy.data.actions.remove(a)
        for pb in rig.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        sc.frame_set(0)
        for img in bpy.data.images:
            if img.size[0] > TEX:
                img.scale(TEX, TEX)
        attr = body.data.attributes.get("qa_part")
        bpy.ops.wm.save_as_mainfile(filepath=str(WORK / f"{name}_anim.blend"))
        if attr:
            body.data.attributes.remove(attr)
        bpy.ops.object.select_all(action="DESELECT")
        rig.select_set(True)
        body.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(DEST / f"meshy_{name}.glb"), export_format="GLB", use_selection=True,
                                  export_image_format="JPEG", export_jpeg_quality=85,
                                  export_animation_mode="ACTIONS", export_animations=True,
                                  export_force_sampling=True, export_optimize_animation_size=False,
                                  export_all_influences=False, export_yup=True, export_apply=False)
        rep["tris"] = sum(len(p.vertices) - 2 for p in body.data.polygons)
        (WORK / f"{name}_report.json").write_text(json.dumps(rep, indent=1))
        print("DONE", name, flush=True)


main()
