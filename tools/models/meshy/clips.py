"""Which clips each character gets, and the clips built on top of the retargeted UAL motion.

A frame is {'rot': {bone: basis Quaternion}, 'loc': hips world position}; a builder gets the retargeted UAL
frames (30 fps, last frame = first for loops) and returns new ones. Directions are in the rig's rest space:
+x = the character's left, -y = forward, +z = up. Rotations added to a bone are about rest-space axes and
act in the bone's parent frame, so "bend the spine 6 deg forward" stays forward whatever the clip does.
"""
import math
import numpy as np
from mathutils import Matrix, Quaternion, Vector

FPS = 30
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
FWD = Vector((0, -1, 0))
LEGS = ("LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase")
ARMS = ("LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand")
TRUNK = ("Hips", "Spine02", "Spine01", "Spine", "neck", "Head")


# ---------------------------------------------------------------- frame helpers
def copy(fr):
    return {"rot": {k: q.copy() for k, q in fr["rot"].items()}, "loc": fr["loc"].copy()}


def mean_quat(qs):
    ref = qs[0]
    acc = np.zeros(4)
    for q in qs:
        v = np.array(q)
        acc += v if np.dot(v, np.array(ref)) >= 0 else -v
    return Quaternion(acc / np.linalg.norm(acc))


def amplitude(frames, scale):
    """Scale each bone's motion about its clip-mean pose (scale: {bone: k}, '*' = default; 'loc' for hips)."""
    out = [copy(f) for f in frames]
    for n in frames[0]["rot"]:
        k = scale.get(n, scale.get("*", 1.0))
        if k == 1.0:
            continue
        m = mean_quat([f["rot"][n] for f in frames])
        for o, f in zip(out, frames):
            d = m.rotation_difference(f["rot"][n])          # m @ d = q
            o["rot"][n] = (m @ Quaternion(d.axis, d.angle * k)).normalized() if d.angle > 1e-9 else m.copy()
    k = scale.get("loc", 1.0)
    if k != 1.0:
        m = sum((f["loc"] for f in frames), Vector()) / len(frames)
        for o, f in zip(out, frames):
            o["loc"] = m + (f["loc"] - m) * k
    return out


def retime(frames, factor):
    """Loop played factor times slower (resampled with slerp; last frame stays = first)."""
    n = len(frames) - 1
    m = max(2, int(round(n * factor)))
    out = []
    for i in range(m + 1):
        t = i * n / m
        a = min(int(t), n - 1)
        u = t - a
        f0, f1 = frames[a], frames[a + 1]
        fr = {"rot": {}, "loc": f0["loc"].lerp(f1["loc"], u)}
        for k in f0["rot"]:
            q1 = f1["rot"][k].copy()
            q1.make_compatible(f0["rot"][k])
            fr["rot"][k] = f0["rot"][k].slerp(q1, u)
        out.append(fr)
    return out


def turn(R, fr, bone, axis, deg):
    """Add a rotation about a rest-space axis to a bone (in its parent frame)."""
    if abs(deg) < 1e-9:
        return
    a = (R.rest[bone].to_3x3().inverted() @ axis).normalized()
    fr["rot"][bone] = (Quaternion(a, math.radians(deg)) @ fr["rot"][bone]).normalized()


def set_world_rot(R, fr, world, bone, rot3):
    p = R.parent[bone]
    fr["rot"][bone] = (R.rel[bone].to_3x3().inverted() @ world[p].to_3x3().inverted() @ rot3).to_quaternion().normalized()


def aim(R, fr, bone, direction):
    """Swing a bone so its axis points along direction (world), keeping its twist."""
    world = R.fk(fr)
    cur = world[bone].to_3x3()
    y = (cur @ Y).normalized()
    set_world_rot(R, fr, world, bone, y.rotation_difference(direction.normalized()).to_matrix() @ cur)


def arm_ik(R, fr, side, target, pole, palm=None):
    """Two-bone IK: wrist to target (world), elbow towards pole (direction), palm normal towards palm."""
    world = R.fk(fr)
    s = world[side + "Arm"].translation
    l1 = (R.rest[side + "ForeArm"].translation - R.rest[side + "Arm"].translation).length
    l2 = (R.rest[side + "Hand"].translation - R.rest[side + "ForeArm"].translation).length
    d = target - s
    dist = min(max(d.length, abs(l1 - l2) + 1e-3), l1 + l2 - 1e-3)
    u = d.normalized()
    a = (l1 * l1 + dist * dist - l2 * l2) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0))
    pp = pole - u * pole.dot(u)
    pp = pp.normalized() if pp.length > 1e-6 else Z
    elbow = s + u * a + pp * h
    wrist = s + u * dist
    aim(R, fr, side + "Arm", elbow - s)
    aim(R, fr, side + "ForeArm", wrist - elbow)
    if palm is not None:
        world = R.fk(fr)
        fdir = (wrist - elbow).normalized()
        cur = world[side + "ForeArm"].to_3x3()
        # hand: along the forearm, palm normal (rest: palm down) turned towards `palm`
        rest_h = R.rest[side + "Hand"].to_3x3()
        n_local = rest_h.inverted() @ Vector((0, 0, -1))
        hand = world[side + "Hand"].to_3x3()
        hand = (hand @ Y).normalized().rotation_difference(fdir).to_matrix() @ hand
        n = hand @ n_local
        n_p = (n - fdir * n.dot(fdir)).normalized()
        t_p = (palm - fdir * palm.dot(fdir)).normalized()
        ang = math.atan2(fdir.dot(n_p.cross(t_p)), n_p.dot(t_p))
        hand = Matrix.Rotation(ang, 3, fdir) @ hand
        set_world_rot(R, fr, world, side + "Hand", hand)


def chest_point(R, fr, p_rest):
    """A rest-space point carried by the chest (Spine bone) into this frame."""
    world = R.fk(fr)
    return world["Spine"] @ (R.rest["Spine"].inverted() @ p_rest)


def smoothstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def blend(fa, fb, w):
    out = copy(fa)
    for k in fa["rot"]:
        q = fb["rot"][k].copy()
        q.make_compatible(fa["rot"][k])
        out["rot"][k] = fa["rot"][k].slerp(q, w)
    out["loc"] = fa["loc"].lerp(fb["loc"], w)
    return out


def body_front(R, z, half_x=0.12):
    """Most forward (-y) torso surface point near height z, rest space."""
    co, part = R.co, R.part
    m = (part == 1) & (np.abs(co[:, 2] - z) < 0.04) & (np.abs(co[:, 0]) < half_x)
    return float(co[m, 1].min())


def loop_segment(frames, lo, hi, min_len, max_len, blend_n=8):
    """Best loop inside frames[lo:hi]: pose + velocity match; the tail is blended into the frames before
    the start so the loop is seamless."""
    keys = list(frames[0]["rot"])
    W = {k: (2.0 if k in ARMS else 1.0) for k in keys}

    def dist(i, j):
        d = 0.0
        for k in keys:
            d += W[k] * frames[i]["rot"][k].rotation_difference(frames[j]["rot"][k]).angle ** 2
        d += 20 * (frames[i]["loc"] - frames[j]["loc"]).length ** 2
        return d

    best = None
    for a in range(max(lo, blend_n), hi):
        for b in range(a + min_len, min(a + max_len, hi) + 1):
            c = dist(a, b) + 0.5 * dist(a + 1, b + 1 if b + 1 < len(frames) else b)
            if best is None or c < best[0]:
                best = (c, a, b)
    _, a, b = best
    out = [copy(f) for f in frames[a:b + 1]]
    n = len(out)
    for j in range(blend_n):
        w = smoothstep(0, 1, (j + 1) / blend_n)
        i = n - blend_n + j
        out[i] = blend(out[i], frames[a - blend_n + j + 1], w)
    out[-1] = copy(frames[a])
    return out, (a, b)


# ---------------------------------------------------------------- builders
def build_run(R, frames, name):
    # UAL's jog lunges (thighs ~100 deg apart): calmer stride and arm pump for people in winter coats
    return amplitude(frames, {**{b: 0.72 for b in LEGS}, **{b: 0.8 for b in ARMS}, "Hips": 0.8, "loc": 0.8})


def build_walk_follow(R, frames, name):
    # following someone: shorter, slower steps, small arm swing
    f = amplitude(frames, {**{b: 0.8 for b in LEGS}, **{b: 0.6 for b in ARMS}, "Hips": 0.8, "loc": 0.75})
    return retime(f, 1.3)


def build_walk_tired(R, frames, name):
    f = amplitude(frames, {**{b: 0.75 for b in LEGS}, **{b: 0.45 for b in ARMS}, "Hips": 0.9, "loc": 0.7})
    f = retime(f, 1.4)
    n = len(f) - 1
    for i, fr in enumerate(f):
        ph = 2 * math.pi * i / n
        for b, d in (("Spine02", 8), ("Spine01", 8), ("Spine", 6)):
            turn(R, fr, b, X, d + 1.5 * math.sin(2 * ph))       # stooped, sagging a little on each step
        turn(R, fr, "neck", X, -9)                               # head lifted to look ahead
        turn(R, fr, "Head", X, -5 - 2 * math.sin(2 * ph + 1.0))
        for s in ("Left", "Right"):
            turn(R, fr, s + "UpLeg", X, -7)                      # soft knees, bent hips
            turn(R, fr, s + "Leg", X, 13)
            turn(R, fr, s + "Foot", X, -6)
            turn(R, fr, s + "Arm", X, -10)                       # arms hang forward, elbows bent
            turn(R, fr, s + "ForeArm", X, -14)
        fr["loc"] = fr["loc"] + Vector((0.012 * math.sin(ph), 0, 0))   # heavier side-to-side shift
    return f


def build_shiver(R, frames, name):
    n = len(frames) - 1
    T = n / FPS
    sx = R.rest["LeftArm"].translation.x
    arm_z = R.rest["LeftArm"].translation.z
    k = R.rest["Head"].translation.z / 1.5
    out = []
    for i, base in enumerate(frames):
        t = i / FPS
        fr = copy(base)
        burst = 0.6 + 0.4 * math.sin(2 * math.pi * 2 * t / T)
        trem = burst * (math.sin(2 * math.pi * 16 * t / T) + 0.6 * math.sin(2 * math.pi * 19 * t / T + 1.3))
        for b, d in (("Spine02", 4), ("Spine01", 4), ("Spine", 3)):
            turn(R, fr, b, X, d + 0.9 * trem)                   # hunched, trembling
        turn(R, fr, "neck", X, 4)
        turn(R, fr, "Head", X, 2 + 1.2 * trem)
        turn(R, fr, "LeftShoulder", Y, -11 - 1.8 * trem)        # shoulders pulled up
        turn(R, fr, "RightShoulder", Y, 11 + 1.8 * trem)
        for s in ("Left", "Right"):
            turn(R, fr, s + "UpLeg", X, -3)
            turn(R, fr, s + "Leg", X, 6)
            turn(R, fr, s + "Foot", X, -3)
        # arms crossed, hands rubbing the opposite upper arm
        rub = math.sin(2 * math.pi * 3 * t / T)
        for s, sg, dz, dy in (("Left", 1, 0.0, 0.0), ("Right", -1, -0.07 * k, -0.025)):
            z = arm_z - 0.11 * k + dz
            y = body_front(R, z) - 0.02 + dy
            p = Vector((-sg * (1.05 * sx), y, z + sg * 0.018 * rub * k))
            target = chest_point(R, fr, p)
            pole = (Vector((sg * 0.7, -0.2, -1.0)))
            palm = Vector((sg * 1.0, 0.2, 0))
            arm_ik(R, fr, s, target, pole, palm)
        for s in ("Left", "Right"):
            turn(R, fr, s + "Arm", X, 0.8 * trem)
        out.append(fr)
    out[-1] = copy(out[0])
    return out


def build_trapped(R, frames, name):
    """Lying under rubble (Death01's last pose), raising one arm to wave for help, head lifting to call."""
    base = copy(frames[-1])
    w = R.fk(base)                       # Death01 travels: centre the lying body on the origin
    mid = (w["Head"].translation + (w["LeftFoot"].translation + w["RightFoot"].translation) / 2) / 2
    base["loc"] = base["loc"] - Vector((mid.x, mid.y, 0))
    n = 4 * FPS
    k = R.rest["Head"].translation.z / 1.5
    out = []
    for i in range(n + 1):
        t = i / FPS
        fr = copy(base)
        breath = math.sin(2 * math.pi * 2 * t / 4)
        turn(R, fr, "Spine01", X, 1.2 * breath)
        up = smoothstep(0.1, 0.7, t) * (1 - smoothstep(2.7, 3.3, t))
        call = smoothstep(0.3, 0.9, t) * (1 - smoothstep(2.6, 3.4, t))
        turn(R, fr, "Spine01", X, 6 * call)                     # chest and head lift while calling
        turn(R, fr, "Spine", X, 6 * call)
        turn(R, fr, "neck", X, 18 * call)
        turn(R, fr, "Head", X, 8 * call)
        if up > 1e-3:
            world = R.fk(fr)
            s = world["RightArm"].translation
            L = (R.rest["RightForeArm"].translation - R.rest["RightArm"].translation).length + \
                (R.rest["RightHand"].translation - R.rest["RightForeArm"].translation).length
            side = (world["Spine"].to_3x3() @ (R.rest["Spine"].to_3x3().inverted() @ -X)).normalized()
            wave = math.sin(2 * math.pi * 1.5 * (t - 0.7)) * smoothstep(0.6, 0.9, t) * (1 - smoothstep(2.4, 2.7, t))
            along = (world["Head"].translation - world["Hips"].translation)
            along = (along - Z * along.dot(Z)).normalized()          # towards the head, on the ground
            target = s + Z * (0.88 * L) + side * (0.25 * L) + along * (0.05 * L + 0.32 * L * wave)
            raised = copy(fr)
            arm_ik(R, raised, "Right", target, side - Z * 0.3, palm=-side)
            fr = blend(fr, raised, up)
        out.append(fr)
    out[-1] = copy(out[0])
    return out


def build_dig(R, frames, name):
    a0 = int(len(frames) * 0.22)
    a1 = int(len(frames) * 0.84)
    seg, _ = loop_segment(frames, a0, a1, 40, 90)
    return amplitude(seg, {"LeftArm": 1.25, "RightArm": 1.25, "LeftForeArm": 1.2, "RightForeArm": 1.2})


def build_wave(R, frames, name):
    n = len(frames) - 1
    T = n / FPS
    k = R.rest["Head"].translation.z / 1.5
    out = []
    for i, base in enumerate(frames):
        t = i / FPS
        fr = copy(base)
        turn(R, fr, "Spine01", Y, -2.5)                         # lean away from the raised arm
        turn(R, fr, "Spine", Y, -2.0)
        turn(R, fr, "RightShoulder", Y, 8)
        world = R.fk(fr)
        s = world["RightArm"].translation
        L = (R.rest["RightForeArm"].translation - R.rest["RightArm"].translation).length + \
            (R.rest["RightHand"].translation - R.rest["RightForeArm"].translation).length
        wave = math.sin(2 * math.pi * 4 * t / T)
        side = (world["Spine"].to_3x3() @ (R.rest["Spine"].to_3x3().inverted() @ -X)).normalized()
        fwd = (world["Spine"].to_3x3() @ (R.rest["Spine"].to_3x3().inverted() @ FWD)).normalized()
        target = s + Z * (0.8 * L) + side * (0.2 * L + 0.17 * L * wave) + fwd * 0.08 * L
        arm_ik(R, fr, "Right", target, side * 1.0 - Z * 0.4 + fwd * 0.2, palm=fwd)
        out.append(fr)
    out[-1] = copy(out[0])
    return out


SPECS = {
    "idle": {"source": "Idle_Loop"},
    "walk": {"source": "Walk_Loop", "ground": "constant"},
    "run": {"source": "Jog_Fwd_Loop", "build": build_run, "ground": "constant"},
    "walk_follow": {"source": "Walk_Loop", "build": build_walk_follow, "ground": "constant"},
    "walk_tired": {"source": "Walk_Loop", "build": build_walk_tired, "ground": "constant"},
    "shiver": {"source": "Idle_Loop", "build": build_shiver, "clear": False},
    "trapped": {"source": "Death01", "build": build_trapped, "clear": False, "ground": "constant"},
    "dig": {"source": "Fixing_Kneeling", "build": build_dig, "ground": "constant", "clear": False},
    "wave": {"source": "Idle_Loop", "build": build_wave, "clear_sides": ("Left",)},
}

COMMON = ["idle", "walk", "run", "walk_follow"]
CLIPS_OF = {
    "player": COMMON,
    "mom": COMMON + ["trapped"],
    "child": COMMON + ["shiver", "trapped"],
    "grandpa": COMMON + ["walk_tired", "trapped"],
    "rescuer": ["idle", "walk", "run", "dig", "wave"],
}
