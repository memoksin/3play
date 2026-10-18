"""TOPLANMA ALANI (assembly area) sign: green panel on two posts, white pictogram (four people, four
arrows pointing in), bilingual text, small solar lamp on top (the one light that still works).
This is the goal of the Fener minigame: lead the family here."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

PW, PH, PZ = 1.5, 1.8, 1.1     # panel width, height, bottom edge height


def person(u, v, s, y):
    L.ball("head", 0.5, (u, y, v + s * 0.78), mat="sign_white", scale=(s * 0.26, 0.03, s * 0.26), subdiv=2)
    L.prism("body", [(u - s * 0.22, v), (u + s * 0.22, v), (u + s * 0.17, v + s * 0.6), (u - s * 0.17, v + s * 0.6)],
            0.03, (0, y, 0), mat="sign_white", axis="y", bevel=0.0)


def arrow(u, v, ang, s, y):
    pts = [(-0.5, -0.12), (0.1, -0.12), (0.1, -0.3), (0.5, 0.0), (0.1, 0.3), (0.1, 0.12), (-0.5, 0.12)]
    c, sn = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    P = [(u + (x * c - z * sn) * s, v + (x * sn + z * c) * s) for x, z in pts]
    L.prism("arrow", P, 0.03, (0, y, 0), mat="sign_white", axis="y", bevel=0.0)


def build():
    for sx in (-1, 1):
        L.cyl("post", 0.05, PZ + PH + 0.1, (sx * 0.55, 0.06, 0), mat="metal", verts=8, bevel=0.01)
        L.cyl("foot", 0.14, 0.12, (sx * 0.55, 0.06, 0), mat="concrete", verts=8, bevel=0.02)
    L.box("panel", (PW, 0.06, PH), (0, 0, PZ), mat="sign_green", base=True, bevel=0.02)
    y = -0.045
    # white border
    for (w, h, u, v) in [(PW - 0.08, 0.04, 0, PZ + PH - 0.07), (PW - 0.08, 0.04, 0, PZ + 0.07),
                         (0.04, PH - 0.12, -PW / 2 + 0.07, PZ + PH / 2), (0.04, PH - 0.12, PW / 2 - 0.07, PZ + PH / 2)]:
        L.box("border", (w, 0.03, h), (u, y, v), mat="sign_white", bevel=0)
    # pictogram square
    cx, cz, sq = 0.0, PZ + 1.12, 0.95
    for (w, h, u, v) in [(sq, 0.035, cx, cz + sq / 2), (sq, 0.035, cx, cz - sq / 2), (0.035, sq, cx - sq / 2, cz), (0.035, sq, cx + sq / 2, cz)]:
        L.box("sqb", (w, 0.03, h), (u, y, v), mat="sign_white", bevel=0)
    for i, (du, dv) in enumerate([(-0.17, 0.0), (0.0, 0.03), (0.17, 0.0)]):
        person(cx + du, cz + dv - 0.2, 0.32 if i != 1 else 0.36, y - (0.005 if i == 1 else 0))
    for ang, (du, dv) in [(0, (-0.36, 0.0)), (180, (0.36, 0.0)), (-90, (0.0, 0.36)), (90, (0.0, -0.36))]:
        arrow(cx + du, cz + dv, ang, 0.2, y)
    L.text("t1", "TOPLANMA ALANI", 0.135, (0, y - 0.02, PZ + 0.42), mat="sign_white", depth=0.012)
    L.text("t2", "ASSEMBLY AREA", 0.085, (0, y - 0.02, PZ + 0.2), mat="sign_white", depth=0.01)
    # solar lamp on top
    L.box("lamparm", (0.06, 0.4, 0.06), (0, -0.15, PZ + PH + 0.05), mat="metal", bevel=0.01, segs=1)
    L.box("lamp", (0.4, 0.22, 0.08), (0, -0.35, PZ + PH + 0.04), mat="metal_dark", bevel=0.02, segs=1)
    L.box("lampled", (0.34, 0.16, 0.02), (0, -0.35, PZ + PH - 0.005), mat="lamp_warm", bevel=0)
    L.box("solar", (0.5, 0.4, 0.03), (0, 0.08, PZ + PH + 0.25), mat="solar_glass", rot=(35, 0, 0), bevel=0.01, segs=1)
    L.snowcap("ssign", (PW + 0.02, 0.1, 0.08), (0, 0, PZ + PH), droop=0.3)
    L.snowcap("ssolar", (0.45, 0.32, 0.05), (0, 0.06, PZ + PH + 0.27), rot=(35, 0, 0), droop=0.2)
    L.blob("snowfoot", (1.9, 0.9, 0.12), (0, 0.1, 0), mat="snow")


out = L.out_dir_arg("assets/3d/kahramanmaras")
L.reset(seed=41)
build()
L.finish("assembly_sign", out, tex=1024, snow=0.6, ao=0.7, ao_dist=0.4, edge=0.3, edge_r=0.01, grime=0.2, grime_h=0.4)
