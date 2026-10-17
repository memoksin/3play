"""Solar flare 3026 (#124): orbital habitat inside the satellite network (Lagrange-4, Hilal, Vega, Kepler).
A spinning wheel station: segmented torus with lit windows, four spokes, a long hub with docking ports,
a solar mirror on top. A beam that touches it blacks it out.

ORIGIN = BEAM CENTRE = wheel centre. The wheel lies flat (axis = Godot Y): spin the node about its own Y.
Tilt a parent node (~18 deg) in the scene so the ring reads from the fixed camera.
Blackout: hide the child mesh `habitat_glow` (all windows + nav lights), keep the rest.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

R = 1.5        # wheel radius (tube centre)
TR = 0.3       # tube radius
N = 16


def build():
    pts = [(math.cos(2 * math.pi * i / N) * R, math.sin(2 * math.pi * i / N) * R, 0.0) for i in range(N)]
    for i in range(N):
        p0, p1 = pts[i], pts[(i + 1) % N]
        L.rod("tube", p0, p1, TR, mat="hull_white" if i % 2 else "hull_grey", verts=10)
        a = 2 * math.pi * (i + 0.5) / N
        deg = math.degrees(a)
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        # window bands: outer wall (3 portholes) and a glazed strip on top
        for j in (-1, 0, 1):
            aa = a + j * 0.09
            L.box("win", (0.03, 0.1, 0.12), (math.cos(aa) * (R + TR - 0.02), math.sin(aa) * (R + TR - 0.02), 0.02),
                  mat="city_window", rot=(0, 0, math.degrees(aa)), bevel=0)
        if i % 2 == 0:
            L.box("roof", (0.12, 0.42, 0.03), (mx, my, TR - 0.02), mat="city_window", rot=(0, 0, deg), bevel=0)
        else:
            L.box("roofp", (0.2, 0.44, 0.04), (mx, my, TR - 0.03), mat="solar_cell", rot=(0, 0, deg), bevel=0.01, segs=1)
    for i in range(N):
        p = pts[i]
        a = math.degrees(2 * math.pi * i / N)
        L.cyl("joint", TR + 0.05, 0.12, (p[0], p[1], 0), mat="trim_blue" if i % 4 == 0 else "hull_grey",
              rot=(90, 0, a), verts=10, bevel=0.015, base=False)
    # spokes + hub
    for i in range(4):
        a = math.radians(i * 90 + 11.25)
        L.rod("spoke", (math.cos(a) * 0.3, math.sin(a) * 0.3, 0), (math.cos(a) * (R - TR + 0.05), math.sin(a) * (R - TR + 0.05), 0),
              0.075, mat="hull_grey", verts=6)
        L.box("lift", (0.16, 0.16, 0.2), (math.cos(a) * 0.85, math.sin(a) * 0.85, 0), mat="trim_blue",
              rot=(0, 0, math.degrees(a)), bevel=0.02, segs=1)
    L.cyl("hub", 0.34, 1.7, (0, 0, -0.85), mat="hull_white", verts=12, bevel=0.03)
    L.cyl("hubband", 0.37, 0.18, (0, 0, -0.09), mat="trim_blue", verts=12, bevel=0.02)
    for z, s in ((0.85, 1), (-0.85, -1)):
        L.cyl("dock", 0.24, 0.16, (0, 0, z if s > 0 else z - 0.16), mat="hull_grey", verts=10, bevel=0.02)
        L.cyl("dockring", 0.18, 0.04, (0, 0, z + 0.16 if s > 0 else z - 0.2), mat="hull_dark", verts=10, bevel=0.01)
    for z in (0.5, -0.5):
        for i in range(6):
            a = math.radians(i * 60)
            L.box("hwin", (0.03, 0.09, 0.09), (math.cos(a) * 0.345, math.sin(a) * 0.345, z), mat="city_window",
                  rot=(0, 0, math.degrees(a)), bevel=0)
    # solar mirror on a short mast above the hub, a radiator below
    L.cyl("mmast", 0.05, 0.5, (0, 0, 1.0), mat="hull_grey", verts=6, bevel=0)
    L.cyl("smirror", 0.62, 0.1, (0, 0, 1.45), mat="hull_white", verts=16, r2=0.5, bevel=0.02)
    L.cyl("smface", 0.52, 0.02, (0, 0, 1.55), mat="solar_cell", verts=16, bevel=0)
    for i in range(3):
        a = math.radians(i * 120 + 30)
        L.box("rad", (0.04, 0.5, 0.62), (math.cos(a) * 0.55, math.sin(a) * 0.55, -1.05), mat="foil_silver",
              rot=(0, 0, math.degrees(a) + 90), bevel=0.01, segs=1)
    # nav lights on the rim
    for i in range(4):
        a = math.radians(i * 90 + 45)
        L.ball("nav", 0.05, (math.cos(a) * (R + TR + 0.02), math.sin(a) * (R + TR + 0.02), 0.16),
               mat="led_red" if i % 2 else "led_blue", subdiv=1)


out = L.out_dir_arg("assets/3d/solar_flare")
L.reset(seed=61)
build()
L.finish("habitat", out, tex=1024, ground=False, snow=0.0, ao=0.75, ao_dist=0.5, edge=0.45, edge_r=0.02, tone=0.08)
