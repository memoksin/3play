"""Per-clip motion checks for retarget.py (numbers go to work/<name>_report.json and the build log).

- stretch: skinned edge length / rest length (p99.9 and max, and the share of edges outside 0.6-1.6):
  catches coats, sleeves and skirts that tear or fold when a joint bends.
- foot: backward speed of the planted foot (within 12 mm of its lowest point) along the ground = the speed the game
  should move the character at so the feet do not slide; spread = how uneven that speed is in the stance.
- seam: largest bone rotation jump between the last and the first frame (loops: last frame = first).
- pop: largest bone rotation change between two frames (deg).
- hand_drift: largest change of a hand's chest-space position caused by the arm clearance (m).
"""
import math
import numpy as np


def _angle(q1, q2):
    d = abs(q1.dot(q2))
    return math.degrees(2 * math.acos(min(1.0, d)))


def report(R, frames, ref, fps):
    worlds = [R.fk(fr) for fr in frames]
    e = R.edges
    worst, p999, bad = 1.0, 1.0, 0.0
    worst_at = None
    comp = 1.0
    for w in worlds[::2]:
        v = R.skin(w)
        ratio = np.linalg.norm(v[e[:, 0]] - v[e[:, 1]], axis=1) / np.maximum(R.rest_len, 1e-6)
        ok = R.rest_len > 0.004
        ratio = ratio[ok]
        if ratio.max() > worst:
            k = int(np.argmax(ratio))
            ev = e[ok][k]
            worst_at = [R.names[int(np.argmax(R.w[ev[0]]))], R.names[int(np.argmax(R.w[ev[1]]))], round(float(R.rest_len[ok][k]), 4),
                        [round(float(c), 3) for c in (R.co[ev[0]] + R.co[ev[1]]) / 2]]
        worst = max(worst, float(ratio.max()))
        comp = min(comp, float(ratio.min()))
        p999 = max(p999, float(np.percentile(ratio, 99.9)))
        bad = max(bad, float(((ratio > 1.6) | (ratio < 0.6)).mean()))
    feet = {}
    for s in ("Left", "Right"):
        pos = np.array([tuple(w[s + "ToeBase"].translation) for w in worlds])
        z = pos[:, 2]
        planted = z <= z.min() + 0.012
        v = np.diff(pos[:, 1], axis=0) * fps          # backwards (+y) along the ground while planted
        pv = v[planted[:-1] & planted[1:]]
        feet[s] = (float(np.median(pv)) if len(pv) else 0.0, float(np.std(pv)) if len(pv) else 0.0)
    seam = max(_angle(frames[0]["rot"][n], frames[-1]["rot"][n]) for n in frames[0]["rot"])
    pop, pop_at = 0.0, None
    for i, (a, b) in enumerate(zip(frames, frames[1:])):
        for n in a["rot"]:
            g = _angle(a["rot"][n], b["rot"][n])
            if g > pop:
                pop, pop_at = g, [n, i]
    drift = 0.0
    for fr, rf in zip(frames, ref):
        w1, w0 = R.fk(fr), R.fk(rf)
        for s in ("Left", "Right"):
            p1 = w1["Spine"].inverted() @ w1[s + "Hand"].translation
            p0 = w0["Spine"].inverted() @ w0[s + "Hand"].translation
            drift = max(drift, (p1 - p0).length)
    return {"stretch_max": round(worst, 2), "stretch_worst_at": worst_at, "stretch_min": round(comp, 2), "stretch_p999": round(p999, 2),
            "stretch_bad_share": round(bad, 4),
            "foot_speed_mps": round((feet["Left"][0] + feet["Right"][0]) / 2, 3),
            "foot_spread_mps": round(max(feet["Left"][1], feet["Right"][1]), 3),
            "seam_deg": round(seam, 2), "pop_deg": round(pop, 1), "pop_at": pop_at, "hand_drift_m": round(drift, 3)}
