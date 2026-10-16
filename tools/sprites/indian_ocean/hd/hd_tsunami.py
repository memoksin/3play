"""HD incoming tsunami, side view, 1024x1024 x 6 -> hd_tsunami.png 6144x1024, transparent bg.
Frames: swell, rise, tall wall, curling crest, crest breaking (foam/spray), collapse. The wave travels left->right:
long back on the left, steep face on the right. Sprite row WAVE_SEA_ROW (880) lies on the sea surface; rows below
are sea water fading out so the base merges with the bg sea."""
import math, os
from hd_common import (ART, N, OUTW, OUTLINE, new, mask, shape, Pen, fill, lin, vgrad, outline, cel, glow, blur,
                       mul, union, sub, erode, dilate, inv, shift, sheet, down, path, rnd, WAVE_SEA_ROW, SeaPal)

SR = WAVE_SEA_ROW


class Pal:
    back_deep, back, body, crest = "#323353", "#4d65b4", "#4d9be6", "#8fd3ff"
    face_deep, face, face_lit, face_hi = "#0b5e65", "#0b8a8f", "#0eaf9b", "#30e1b9"
    barrel = "#0b5e65"
    flow = "#8fd3ff"
    foam, foam_shade, spray = "#ffffff", "#8ff8e2", "#c7dcd0"
    sea_top, sea = SeaPal.surface, SeaPal.top


AMP = [110, 240, 430, 560, 640, 470]
CREST_X = [560, 590, 620, 640, 660, 640]
LIP = [0, 0, 0, 150, 240, 220]
FOAM = [0.2, 0.4, 0.6, 0.8, 1.0, 1.0]


def height(x, k):
    a, cx = AMP[k], CREST_X[k]
    wb = 430 + 50 * k
    wf = max(95, 230 - 30 * k)
    d = (x - cx) / (wb if x < cx else wf)
    return a * math.exp(-d * d)


def geometry(k):
    """Masks: body (one closed silhouette above the sea row; with a curling lip for k>=3), lip, face region."""
    cx, ct = CREST_X[k], SR - AMP[k]
    L = LIP[k]
    if not L:
        top = [(x, SR - height(x, k)) for x in range(0, N + 1, 8)]
        sil = top + [(N, SR + 2), (0, SR + 2)]
        lip = mask()
        outer = []
    else:
        back = [(x, SR - height(x, k)) for x in range(0, cx, 8)] + [(cx, ct)]
        if k < 5:
            tip = (cx + 0.95 * L, ct + 0.55 * L)
            outer = path((cx, ct), ((cx + 0.55 * L, ct - 0.28 * L), (cx + 1.08 * L, ct + 0.05 * L), tip), n=30)
            hollow = (cx + 0.22 * L, ct + 0.40 * L)
            inner = path(tip, ((cx + 0.82 * L, ct + 0.30 * L), (cx + 0.45 * L, ct + 0.22 * L), hollow), n=24)
            foot = (cx + 0.55 * L + 170, SR)
            face = path(hollow, ((cx + 0.02 * L, ct + 0.75 * L), (cx + 0.1 * L, SR - 140), foot), n=30)
        else:               # collapse: the lip has slammed down onto the sea
            tip = (cx + 1.05 * L, SR - 30)
            outer = path((cx, ct), ((cx + 0.6 * L, ct - 0.25 * L), (cx + 1.15 * L, ct + 0.35 * L), tip), n=30)
            hollow = (cx + 0.35 * L, ct + 0.55 * L)
            inner = path(tip, ((cx + 0.95 * L, ct + 0.55 * L), (cx + 0.6 * L, ct + 0.3 * L), hollow), n=24)
            foot = (cx + 0.6 * L, SR)
            face = path(hollow, ((cx + 0.15 * L, ct + 0.8 * L), (cx + 0.3 * L, SR - 80), foot), n=30)
        sil = back + outer[1:] + inner[1:] + face[1:] + [(N, SR + 2), (0, SR + 2)]
        lipm = shape(lambda q: q.poly([(cx - 10, ct)] + outer[1:] + inner[1:]))
        lip = lipm
    bodym = shape(lambda q: q.poly(sil))
    face_line = path((cx - 70, ct - 20), ((cx - 120, (ct + SR) / 2), (cx - 220, SR + 10)), n=20)
    facem = shape(lambda q: q.poly(face_line + [(N, SR + 10), (N, ct - 60)]))
    top = [(x, SR - height(x, k)) for x in range(0, cx, 8)]
    return dict(body=bodym, lip=lip, outer=outer, face=blur(facem, 30), top=top, cx=cx, ct=ct, L=L)


def draw(k, p=Pal):
    g = geometry(k)
    cx, ct, L = g["cx"], g["ct"], g["L"]
    im = new()
    above = shape(lambda q: q.rect(0, 0, N, SR))
    # foam mass on the crest (and down the face when breaking)
    fm = mask()
    fp = Pen(fm)
    crest = [(x, y) for x, y in g["top"] if x > cx - 60 - 200 * FOAM[k]] + [(cx, ct)]
    crest += g["outer"][: int(len(g["outer"]) * 0.8)]
    nb = int(5 + 18 * FOAM[k])
    for i in range(nb):
        x, y = crest[int(i / max(1, nb - 1) * (len(crest) - 1))]
        r = (12 + 22 * rnd(i, k)) * (0.5 + 0.6 * FOAM[k])
        fp.ell(x, y - r * 0.2, r, r * 0.8)
    if k == 4:                  # water thrown from the tip falls as a foam curtain
        tx, ty = CREST_X[k] + 0.95 * L, ct + 0.55 * L
        fall = path((tx, ty), ((tx + 40, (ty + SR) / 2), (tx + 30, SR - 10)), n=20)
        for i, (x, y) in enumerate(fall):
            fp.ell(x + 6 * math.sin(i * 1.3), y, 22 + 8 * (i / len(fall)), 20)
    if k == 5:                  # collapse: a big foam mass where the lip lands
        for i in range(16):
            x = cx + 0.5 * L + i * 34 + 20 * math.sin(i * 2.3)
            y = SR - 20 - 90 * rnd(i, 51) * (1 - abs(i - 8) / 9)
            r = 30 + 30 * rnd(i, 52)
            fp.ell(min(x, N - 100), y, r, r * 0.8)
    for i in range(7):          # foam skirt at the foot of the face
        x = cx + 60 + i * 40 + 10 * math.sin(i)
        fp.ell(x, SR - 6, 30 - 2 * i, 14)
    fm = mul(fm, shape(lambda q: q.rect(0, 0, N - 20, SR + 10)))
    solid = union(g["body"], fm)
    ol = mul(dilate(solid, OUTW), shape(lambda q: q.rect(0, 0, N, SR - 6)))
    fill(im, ol, OUTLINE)
    # sea rows: surface colour fading out downwards
    sea = shape(lambda q: q.rect(0, SR - 6, N, N))
    fade = vgrad([(SR, (255, 255, 255, 255)), (SR + 70, (255, 255, 255, 255)), (N, (255, 255, 255, 0))]).getchannel("A")
    hfade = lin((N - 260, 0), (N - 20, 0), [(0, (255, 255, 255, 255)), (1, (255, 255, 255, 0))]).getchannel("A")
    fill(im, mul(mul(sea, fade), hfade), vgrad([(SR - 6, p.sea_top), (SR + 14, p.sea), (N, p.sea)]))
    # body: deep back -> lighter toward the crest, teal on the face
    bm = mul(g["body"], above)
    fill(im, bm, lin((0, SR), (cx, ct), [(0, p.back_deep), (0.45, p.back), (0.85, p.body), (1, p.crest)]))
    fill(im, mul(bm, g["face"]), vgrad([(ct, p.face_hi), (ct + 160, p.face_lit), ((ct + SR) / 2 + 80, p.face), (SR, p.face_deep)]))
    # flow lines following the back slope
    fl = mask()
    flp = Pen(fl)
    for j, d in enumerate((70, 160, 270, 390)):
        pts = [(x, y + d * (1 - 0.3 * (x / N))) for x, y in g["top"] if 30 < x < cx - 60 - j * 30]
        if len(pts) > 2:
            flp.line(pts, 12 - 2 * j)
    fill(im, mul(blur(fl, 2), erode(bm, 20)), p.flow, 0.35)
    cel(im, bm, p.crest, 0, -22, alpha=0.8)           # lit skin on top
    if L:
        lm = mul(blur(g["lip"], 16), bm)
        fill(im, lm, lin((cx, ct), (cx + L, ct + L * 0.6), [(0, p.face_hi), (0.6, p.face_lit), (1, p.face)]), 0.85)
        under = mul(mul(bm, inv(shift(bm, 0, -26))), dilate(g["lip"], 20))
        fill(im, mul(blur(under, 3), bm), p.barrel, 0.8)           # shaded underside of the curl
        cel(im, lm, p.foam_shade, -6, -18, alpha=0.9)
    glow(im, mul(fm, above), 14, p.foam_shade, 0.4)
    fill(im, fm, p.foam)
    cel(im, fm, p.foam_shade, 8, 12, alpha=0.9)
    # spray + mist once breaking
    if k >= 3:
        dm = mask()
        dp = Pen(dm)
        mist = mask()
        mp = Pen(mist)
        n = 16 + 14 * (k - 3)
        for i in range(n):
            a = rnd(i, k + 3)
            x = cx - 120 + a * (L + 260)
            y = ct - 30 - rnd(k, i) * (90 + 60 * (k - 3))
            r = 5 + 9 * rnd(i, 2 * k)
            if 20 < x < N - 20 and y > 20:
                dp.ell(x, y, r)
                mp.ell(x, y, r * 3.5)
        glow(im, mist, 26, p.spray, 0.45)
        fill(im, dm, p.foam, 0.95)
    return down(im)


def main():
    sheet([[draw(k) for k in range(6)]], os.path.join(ART, "hd_tsunami.png"))


if __name__ == "__main__":
    main()
