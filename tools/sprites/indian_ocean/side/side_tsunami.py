"""Incoming tsunami, side view, 6 frames 96x96 -> 2304x384 (4x), transparent bg.
Swell -> rise -> crest -> breaking with foam. Sprite row 88 lies on the calm sea line (place top at y=SEA_Y-88);
rows 88..91 repeat the bg surface band so the wave base merges with the sea. Code moves it left->right."""
import math, os
from common import Canvas, ART, export, rnd, ease, WAVE_N, WAVE_SEA_ROW, SeaPal


class Pal:
    back, body, face, face_lit, crest = "#4d65b4", "#4d9be6", "#0eaf9b", "#30e1b9", "#8ff8e2"
    deep = "#484a77"
    foam, foam_hi, spray = "#8ff8e2", "#ffffff", "#c7dcd0"
    sea = SeaPal.bands[0]


AMP = [8, 16, 27, 38, 46, 50]
CREST_X = [62, 64, 66, 68, 69, 70]
LIP = [0, 0, 0, 4, 9, 14]          # forward overhang of the breaking crest


def height(x, k):
    a, cx = AMP[k], CREST_X[k]
    wb = 40 + 4 * k
    wf = max(6, 16 - 2 * k)
    d = (x - cx) / (wb if x < cx else wf)
    return a * math.exp(-d * d)


def geometry(k):
    top = {}
    for x in range(WAVE_N):
        h = height(x, k)
        if h >= 0.8:
            top[x] = WAVE_SEA_ROW - round(h)
    lip = []
    L = LIP[k]
    cx, ct = CREST_X[k], WAVE_SEA_ROW - AMP[k]
    for i in range(L + 1):         # lip curve: forward and drooping, thickness 4 -> 2
        t = i / max(1, L)
        lip.append((cx + i, ct + round(L * 0.9 * t * t), 4 - round(2 * t)))
    return top, lip


def draw(c, k, p=Pal):
    top, lip = geometry(k)
    cx = CREST_X[k]
    for x, t in top.items():
        for y in range(t, WAVE_SEA_ROW + 4):
            d = y - t
            if y >= WAVE_SEA_ROW: col = p.sea
            elif d == 0: col = p.crest if x > cx - 12 else p.body
            elif x >= cx - 2 and d < 10: col = p.face_lit if d < 3 else p.face
            elif x >= cx - 2: col = p.body
            elif d < 3: col = p.body
            else:
                col = p.back
                if y > WAVE_SEA_ROW - 6 and (x + y) % 2: col = p.body
                elif d > 14 and (x + y) % 2 == 0 and y < WAVE_SEA_ROW - 8: col = p.deep
            c.put(x, y, col)
    for (x, y, th) in lip:
        for j in range(th):
            c.put(x, y + j, p.foam_hi if j == 0 else (p.crest if j == 1 else p.face_lit))
    # foam on the crest + spray once breaking
    ct = WAVE_SEA_ROW - AMP[k]
    for x in range(cx - 14, cx + 2):
        if x in top and rnd(x, k) > (0.55 if k >= 3 else 0.8):
            c.put(x, top[x], p.foam_hi)
    if k >= 4:
        for i in range(10 + 8 * (k - 4)):
            sx = cx - 8 + int(rnd(i, k) * (LIP[k] + 14))
            sy = ct - 2 - int(rnd(k, i) * (5 + 2 * k))
            c.put(sx, sy, p.foam_hi if i % 3 else p.spray)
    if k == 5:                     # foam pouring down the face below the lip
        lx, ly, _ = lip[-1]
        for y in range(ly + 2, WAVE_SEA_ROW):
            if rnd(y, 7) > 0.35:
                c.put(lx - (y - ly) // 6, y, p.foam if y % 2 else p.foam_hi)


def main():
    frames = []
    for k in range(6):
        c = Canvas(WAVE_N, WAVE_N, 1)
        draw(c, k)
        frames.append(c)
    export(frames, os.path.join(ART, "side_tsunami.png"))


if __name__ == "__main__":
    main()
