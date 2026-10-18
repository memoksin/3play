"""Pose maths for the first-person arms (fp_arms.py): forward kinematics on the rig's rest data, hands placed on
tool grips, two-bone arm IK with the elbow as a hinge and the forearm twist split off, fingers closed on a
handle by contact against the glove's own vertices. Camera space throughout (Blender: +x right, +y forward,
+z up). A pose is {bone: 4x4 world Matrix}; bones not in it follow their parent at rest."""
import math
import numpy as np
from mathutils import Matrix, Vector, Quaternion

FINGERS = ("Thumb", "Index", "Middle", "Ring", "Pinky")
# joint limits (deg) of the finger flexion: knuckle, middle, end joint
LIMITS = {"Thumb": (40, 55, 75), "Index": (92, 105, 80), "Middle": (95, 108, 80), "Ring": (95, 108, 80),
          "Pinky": (95, 108, 80)}


class Rig:
    def __init__(self, rig, mesh):
        self.obj = rig
        self.rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones}
        self.order = [b.name for b in rig.data.bones]         # parents before children
        self.rel = {n: (self.rest[p].inverted() @ self.rest[n]) if p else self.rest[n].copy()
                    for n, p in self.parent.items()}
        self.co = np.array([tuple(v.co) for v in mesh.data.vertices])
        names = [g.name for g in mesh.vertex_groups]
        self.w = np.zeros((len(self.co), len(names)))
        for v in mesh.data.vertices:
            for g in v.groups:
                self.w[v.index, g.group] = g.weight
        self.gnames = names
        dom = np.argmax(self.w, axis=1)
        self.dom = np.array(names)[dom]
        self.domw = self.w[np.arange(len(dom)), dom]

    def verts_of(self, bone, min_w=0.5):
        m = (self.dom == bone) & (self.domw >= min_w)
        return self.co[m]

    def length(self, n):
        return (self.rest[n].translation - self.rest[self.order[0]].translation).length

    def fk(self, local):
        """local: {bone: 4x4 basis (rest-relative)} -> world."""
        out = {}
        for n in self.order:
            p = self.parent[n]
            b = local.get(n, Matrix.Identity(4))
            out[n] = (out[p] @ self.rel[n] @ b) if p else (self.rest[n] @ b)
        return out

    def basis(self, world):
        """world {bone: 4x4} (every bone) -> rest-relative basis per bone."""
        out = {}
        for n in self.order:
            p = self.parent[n]
            ref = (world[p] @ self.rel[n]) if p else self.rest[n]
            out[n] = ref.inverted() @ world[n]
        return out


def frame(y, z_hint):
    """Rotation (3x3) with +Y along y and +Z as close as possible to z_hint."""
    y = y.normalized()
    x = y.cross(z_hint).normalized()
    z = x.cross(y)
    return Matrix((x, y, z)).transposed()


def map_pair(a0, b0, a1, b1):
    """Rotation taking direction a0 to a1 and (the part of b0 across a0) to (the part of b1 across a1)."""
    m0 = Matrix((a0.normalized(), (b0 - a0.normalized() * b0.dot(a0.normalized())).normalized(),
                 a0.normalized().cross(b0).normalized())).transposed()
    m1 = Matrix((a1.normalized(), (b1 - a1.normalized() * b1.dot(a1.normalized())).normalized(),
                 a1.normalized().cross(b1).normalized())).transposed()
    return m1 @ m0.inverted()


def twist_about(q, axis):
    """Twist angle of rotation q about axis (swing-twist decomposition)."""
    v = Vector((q.x, q.y, q.z))
    p = axis * v.dot(axis)
    t = Quaternion((q.w, p.x, p.y, p.z))
    if t.magnitude < 1e-9:
        return 0.0
    t.normalize()
    ang = 2 * math.atan2(Vector((t.x, t.y, t.z)).dot(axis), t.w)
    return (ang + math.pi) % (2 * math.pi) - math.pi


class Arms:
    """Arm chains of one rig: IK to a hand matrix."""

    def __init__(self, R):
        self.R = R
        self.hinge = {}
        for s in ("Left", "Right"):
            sh = R.rest[s + "Arm"].translation
            el = R.rest[s + "ForeArm"].translation
            wr = R.rest[s + "Hand"].translation
            u = (el - sh).normalized()
            fwd = Vector((0, 1, 0))                           # the elbow bends forward (camera +y at rest)
            self.hinge[s] = u.cross(fwd - u * fwd.dot(u)).normalized()
            self.l1 = getattr(self, "l1", {})
            self.l2 = getattr(self, "l2", {})
            self.l1[s] = (el - sh).length
            self.l2[s] = (wr - el).length

    def solve(self, world, s, hand, pole, report=None):
        """Sets world[Arm, ForeArm, ForeArmTwist, Hand] of side s so the hand bone sits at `hand` (4x4), elbow
        towards `pole` (direction). world must already hold the parent of Arm (View)."""
        R = self.R
        sh_m = world[R.parent[s + "Arm"]] @ R.rel[s + "Arm"]
        S = sh_m.translation
        W = hand.translation
        l1, l2 = self.l1[s], self.l2[s]
        d = W - S
        dist = d.length
        if report is not None:
            report["reach"] = max(report.get("reach", 0.0), dist / (l1 + l2))
        dist_c = min(max(dist, abs(l1 - l2) + 1e-3), l1 + l2 - 1e-4)
        u = d.normalized()
        a = (l1 * l1 + dist_c * dist_c - l2 * l2) / (2 * dist_c)
        h = math.sqrt(max(l1 * l1 - a * a, 0.0))
        pp = (pole - u * pole.dot(u))
        pp = pp.normalized() if pp.length > 1e-6 else Vector((0, 0, -1))
        E = S + u * a + pp * h
        Wc = S + u * dist_c
        up_dir = (E - S).normalized()
        fo_dir = (Wc - E).normalized()
        hinge = up_dir.cross(fo_dir)
        hinge = hinge.normalized() if hinge.length > 1e-5 else self.hinge[s]
        rest_up = (R.rest[s + "ForeArm"].translation - R.rest[s + "Arm"].translation).normalized()
        rest_fo = (R.rest[s + "Hand"].translation - R.rest[s + "ForeArm"].translation).normalized()
        h0 = self.hinge[s]
        r_up = map_pair(rest_up, h0, up_dir, hinge)
        r_fo = map_pair(rest_fo, h0, fo_dir, hinge)
        m = (r_up @ R.rest[s + "Arm"].to_3x3()).to_4x4()
        m.translation = S
        world[s + "Arm"] = m
        m = (r_fo @ R.rest[s + "ForeArm"].to_3x3()).to_4x4()
        m.translation = E
        world[s + "ForeArm"] = m
        hm = hand.copy()
        hm.translation = Wc                                    # if out of reach the hand stays on the arm
        world[s + "Hand"] = hm
        # forearm twist: the hand's turn about the forearm (relative to rest) goes to the twist bone
        rel_rest = R.rest[s + "ForeArm"].inverted() @ R.rest[s + "Hand"]
        rel_now = world[s + "ForeArm"].inverted() @ hm
        q = (rel_now.to_quaternion() @ rel_rest.to_quaternion().inverted())
        ang = twist_about(q, Vector((0, 1, 0)))
        tw = world[s + "ForeArm"] @ R.rel[s + "ForeArmTwist"] @ Matrix.Rotation(ang * 0.85, 4, "Y")
        world[s + "ForeArmTwist"] = tw
        if report is not None:
            report.setdefault("twist_deg", {})[s] = round(math.degrees(ang), 1)
        return E


# ---------------------------------------------------------------- grips
class Hand:
    """Rest data of one hand for grips and finger solves (rest space: the hand bone at rest)."""

    def __init__(self, R, s):
        self.R, self.s = R, s
        self.H = R.rest[s + "Hand"]
        Hi = self.H.inverted()
        self.palm = np.array([tuple(Hi @ Vector(p)) for p in R.verts_of(s + "Hand", 0.6)])
        self.seg = {}
        for f in FINGERS:
            for k in (1, 2, 3):
                n = f"{s}Hand{f}{k}"
                self.seg[n] = np.array([tuple(Hi @ Vector(p)) for p in R.verts_of(n, 0.5)])
        mcp = {f: Hi @ R.rest[f"{s}Hand{f}1"].translation for f in FINGERS}
        self.mcp = mcp
        self.L = mcp["Middle"].y                                # wrist -> middle knuckle
        self.index_side = 1.0 if mcp["Index"].x > mcp["Pinky"].x else -1.0

    def grip_line(self, R_handle, along=0.74, diag=18.0, lift=0.0):
        """Point and direction (hand space) of a handle of radius R_handle across the palm: through the palm
        at `along` of the wrist -> knuckle length, `diag` degrees toward the index side distally, touching the
        palm (the palm vertices just clear the handle)."""
        d = Vector((self.index_side * math.cos(math.radians(diag)), math.sin(math.radians(diag)), 0.0))
        P = self.palm
        z = 0.0
        base = Vector((0.0, along * self.L, 0.0))
        for z_try in np.arange(0.0, 0.08, 0.0005):
            c = np.array(tuple(base)) + np.array([0, 0, z_try])
            q = P - c
            off = q - np.outer(q @ np.array(tuple(d)), np.array(tuple(d)))
            # only the palm in front of the line's ends counts
            t = q @ np.array(tuple(d))
            m = np.abs(t) < 0.06
            if (np.linalg.norm(off[m], axis=1) >= R_handle).all():
                z = z_try
                break
        return base + Vector((0, 0, z + lift)), d

    def place_axis(self, line_pt, line_dir, axis_pref, R_handle, sign=1.0, along=0.74, diag=18.0, lift=0.0):
        """Hand bone matrix gripping a handle (axis through line_pt along line_dir): the hand's index side toward
        sign * line_dir, the hand's own axis (wrist -> knuckles) as close as it can to axis_pref."""
        p_h, d_h = self.grip_line(R_handle, along, diag, lift)
        y_h = Vector((0, 1, 0))
        w_h = (y_h - d_h * y_h.dot(d_h)).normalized()
        a = line_dir.normalized() * sign
        w_t = (axis_pref - a * axis_pref.dot(a)).normalized()
        m0 = Matrix((d_h, w_h, d_h.cross(w_h))).transposed()
        m1 = Matrix((a, w_t, a.cross(w_t))).transposed()
        rot = m1 @ m0.inverted()
        m = rot.to_4x4()
        m.translation = line_pt - rot @ p_h
        return m, (p_h, d_h)

    def place(self, line_pt, line_dir, palm_dir, R_handle, along=0.74, diag=18.0, roll=0.0, lift=0.0):
        """Hand bone matrix (camera space) gripping a handle whose axis passes through line_pt along line_dir
        (the hand's index side toward +line_dir), the palm facing palm_dir (turned `roll` deg about the
        handle)."""
        p_h, d_h = self.grip_line(R_handle, along, diag, lift)
        z_h = Vector((0, 0, 1))
        a = line_dir.normalized()
        n = (palm_dir - a * palm_dir.dot(a)).normalized()
        n = Matrix.Rotation(math.radians(roll), 3, a) @ n
        m0 = Matrix((d_h, z_h, d_h.cross(z_h))).transposed()
        m1 = Matrix((a, n, a.cross(n))).transposed()
        rot = m1 @ m0.inverted()
        m = rot.to_4x4()
        m.translation = line_pt - rot @ p_h
        return m, (p_h, d_h)


def close_fingers(hand, axes, squeeze=0.0, fingers=("Index", "Middle", "Ring", "Pinky"), step=1.0, start=None):
    """Curl each finger (flexion about its bones' local X) until its glove vertices touch one of `axes`
    (hand space capsules: (point, direction, radius, half length)). squeeze (m) lets the glove press in.
    Returns {bone: angle deg}."""
    R, s = hand.R, hand.s
    out = {}
    for f in fingers:
        names = [f"{s}Hand{f}{k}" for k in (1, 2, 3)]
        ang = list(start[f]) if start and f in start else [0.0, 0.0, 0.0]
        lim = LIMITS[f]
        active = [True, True, True]
        coupling = (1.0, 1.15, 0.8)

        def segs_world(angs):
            # hand space: hand at identity (rest-relative)
            Hi = hand.H.inverted()
            m = Matrix.Identity(4)
            parent_rest = hand.H
            outp = []
            cur = Matrix.Identity(4)
            prev_rest = hand.H
            for n, a in zip(names, angs):
                rel = prev_rest.inverted() @ R.rest[n]
                cur = cur @ rel @ Matrix.Rotation(math.radians(a), 4, "X")
                prev_rest = R.rest[n]
                outp.append(cur @ R.rest[n].inverted() @ hand.H)   # hand-space pose of the segment's vertices
            return outp

        def penetration(angs):
            mats = segs_world(angs)
            worst = []
            for n, mm in zip(names, mats):
                V = hand.seg[n]
                if len(V) == 0:
                    worst.append(-1.0)
                    continue
                M = np.array(mm)
                P = V @ M[:3, :3].T + M[:3, 3]
                deepest = -1.0
                for (c, dvec, r, half) in axes:
                    c = np.array(tuple(c))
                    dv = np.array(tuple(dvec))
                    q = P - c
                    t = np.clip(q @ dv, -half, half)
                    dist = np.linalg.norm(q - np.outer(t, dv), axis=1)
                    deepest = max(deepest, float((r - squeeze - dist).max()))
                worst.append(deepest)
            return worst

        it = 0
        while any(active) and it < 400:
            it += 1
            trial = [a + (step * coupling[k] if active[k] else 0.0) for k, a in enumerate(ang)]
            trial = [min(t, lim[k]) for k, t in enumerate(trial)]
            if trial == ang:
                break
            pen = penetration(trial)
            hit = [p > 0.0 for p in pen]
            if any(hit):
                j = hit.index(True)
                for k in range(j + 1):
                    active[k] = False
                continue
            for k in range(3):
                if trial[k] >= lim[k]:
                    active[k] = False
            ang = trial
        out[f] = ang
    return out


def thumb_wrap(hand, axes, target, squeeze=0.0):
    """Thumb: knuckle joint turned toward the target (hand space point on the handle's far side), the other
    joints curled until contact. Searches the thumb base's two angles (flex X, swing Z)."""
    R, s = hand.R, hand.s
    names = [f"{s}HandThumb{k}" for k in (1, 2, 3)]
    best = None
    tgt = np.array(tuple(target))
    for ax in np.arange(-10, 41, 5):
        for az in np.arange(-40, 41, 5):
            for a2 in np.arange(0, 56, 5):
                for a3 in np.arange(0, 76, 7.5):
                    cur = Matrix.Identity(4)
                    prev = hand.H
                    pen = -1.0
                    tip = None
                    for k, n in enumerate(names):
                        rel = prev.inverted() @ R.rest[n]
                        rot = (Matrix.Rotation(math.radians(az), 4, "Z") @ Matrix.Rotation(math.radians(ax), 4, "X")) \
                            if k == 0 else Matrix.Rotation(math.radians(a2 if k == 1 else a3), 4, "X")
                        cur = cur @ rel @ rot
                        prev = R.rest[n]
                        mm = np.array(cur @ R.rest[n].inverted() @ hand.H)
                        V = hand.seg[n]
                        if len(V):
                            P = V @ mm[:3, :3].T + mm[:3, 3]
                            for (c, dvec, r, half) in axes:
                                q = P - np.array(tuple(c))
                                dv = np.array(tuple(dvec))
                                t = np.clip(q @ dv, -half, half)
                                dist = np.linalg.norm(q - np.outer(t, dv), axis=1)
                                pen = max(pen, float((r - squeeze - dist).max()))
                            if k == 2:
                                tip = P[np.argmax(P @ (mm[:3, :3] @ np.array([0, 1.0, 0])))]
                    if pen > 0.002 or tip is None:
                        continue
                    cost = float(np.linalg.norm(tip - tgt)) + (0.0 if pen > -0.004 else 0.01)
                    if best is None or cost < best[0]:
                        best = (cost, (ax, az, a2, a3))
    return best[1] if best else (0, 0, 0, 0)
