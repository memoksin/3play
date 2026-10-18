"""Shared helpers for the Meshy -> UAL pipeline (run inside Blender's Python; numpy comes with Blender)."""
import numpy as np

NAMES = ["player", "mom", "child", "grandpa", "rescuer", "farmer"]
SIDES = (("Left", 1), ("Right", -1))
# Meshy auto-rig: 24 bones. head_end / headfront are unanimated helpers under Head.
CHILD = {"Hips": "Spine02", "Spine02": "Spine01", "Spine01": "Spine", "Spine": "neck", "neck": "Head",
         "Head": "head_end", "LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand",
         "RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
         "LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase",
         "RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase"}
SPINE = ["Hips", "Spine02", "Spine01", "Spine", "neck", "Head"]


def smooth(e0, e1, x):
    """Smoothstep from 0 at e0 to 1 at e1 (e1 < e0 flips it)."""
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def chain_param(P, pts):
    """Closest point of every row of P on the polyline pts: (distance, arc length s). Before the first point
    the first segment is extended (s < 0), after the last one the last segment is extended (s > length)."""
    pts = np.asarray(pts, float)
    best_d = np.full(len(P), np.inf)
    best_s = np.zeros(len(P))
    acc = 0.0
    n = len(pts) - 1
    for k in range(n):
        a, b = pts[k], pts[k + 1]
        ab = b - a
        L = float(np.linalg.norm(ab))
        t = (P - a) @ ab / (L * L)
        tc = np.clip(t, -np.inf if k == 0 else 0, np.inf if k == n - 1 else 1)
        d = np.linalg.norm(P - (a + tc[:, None] * ab), axis=1)
        better = d < best_d
        best_d[better] = d[better]
        best_s[better] = (acc + tc * L)[better]
        acc += L
    return best_d, best_s


def cum_lengths(pts):
    pts = np.asarray(pts, float)
    return np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])


def chain_split(s, cum, blends):
    """Weights (len(cum)-1 columns) for arc length s along a chain whose joints sit at cum; blends[k] is the
    half width of the blend at joint k+1."""
    n = len(cum) - 1
    out = np.zeros((len(s), n))
    carry = np.ones(len(s))
    for k in range(n):
        nxt = smooth(cum[k + 1] - blends[k], cum[k + 1] + blends[k], s) if k + 1 < n else np.zeros(len(s))
        out[:, k] = carry * (1 - nxt)
        carry = carry * nxt
    return out


def section(tris, origin, normal):
    """Points where the triangles (M, 3, 3) cross the plane through origin with the given normal."""
    d = (tris - origin) @ normal
    out = []
    for a, b in ((0, 1), (1, 2), (2, 0)):
        da, db = d[:, a], d[:, b]
        m = (da * db) < 0
        t = da[m] / (da[m] - db[m])
        out.append(tris[m, a] + (tris[m, b] - tris[m, a]) * t[:, None])
    return np.concatenate(out) if out else np.zeros((0, 3))
