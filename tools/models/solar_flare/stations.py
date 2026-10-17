"""Solar flare 3026 (#124): the "cities" around the network that a stray beam can black out.

Orbital rings (Batı / Doğu Halkası) run along the left and right side of the board, the Parker station
truss runs along the top (sun side), with a gate where the flare enters. All pieces are ONE CELL (4 m)
long and tile end to end. ORIGIN = BEAM CENTRE of the piece (beam height), centre of its length.
Blackout: hide the child mesh `<name>_glow`.

Variants:
  ring_module   4 m along Godot Z. Inner side (windows, pod) faces Godot +X: use it as is on the WEST
                ring, rotate 180 deg about Y for the EAST ring.
  ring_end      cap for both ring ends: docking hub + mast. Its open side (rails) faces Godot +Z:
                as is at the sun end of a ring, rotated 180 deg at the Earth end.
  parker_module 4 m along Godot X, front (windows) faces Godot +Z (towards the board).
  parker_gate   4 m along Godot X: open gate the flare comes through, bracket pylons with warm lights.
  parker_end    end of the truss: big solar array + hub. Open side faces Godot +X.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

C = 4.0


def ring_module():
    h = C / 2
    for z in (0.95, -0.95):
        L.cyl("rail", 0.15, C, (0, -h, z), mat="hull_grey", rot=(-90, 0, 0), verts=8, bevel=0.02)
    # outer hull band (the ring proper) on the far side
    L.box("band", (0.14, C - 0.04, 2.5), (-0.62, 0, 0), mat="hull_white", bevel=0.04)
    L.box("bandt", (0.18, C - 0.04, 0.16), (-0.62, 0, 1.2), mat="trim_blue", bevel=0.03, segs=1)
    L.box("bandb", (0.18, C - 0.04, 0.16), (-0.62, 0, -1.2), mat="trim_blue", bevel=0.03, segs=1)
    for y in (-1.0, 1.0):
        L.box("panel", (0.06, 1.7, 1.9), (-0.72, y, 0), mat="solar_cell", bevel=0.015, segs=1)
    # pressurised pod with windows facing the board (+X) and up
    L.cyl("pod", 0.55, 2.7, (0.15, -1.35, 0), mat="hull_white", rot=(-90, 0, 0), verts=12, bevel=0.03)
    for s in (-1, 1):
        L.cyl("podcap", 0.58, 0.14, (0.15, s * 1.35 - (0.14 if s < 0 else 0), 0), mat="trim_blue", rot=(-90, 0, 0), verts=12, bevel=0.02)
        L.ball("podend", 0.5, (0.15, s * 1.42, 0), mat="hull_grey", scale=(0.9, 0.45, 0.9), subdiv=2)
    for i in range(6):
        y = -1.05 + i * 0.42
        L.box("win", (0.04, 0.22, 0.16), (0.69, y, 0.08), mat="city_window", bevel=0)
        L.box("winf", (0.05, 0.3, 0.05), (0.69, y, -0.05), mat="hull_grey", bevel=0)
        L.box("roofw", (0.18, 0.26, 0.04), (0.33, y, 0.52), mat="city_window", rot=(0, 30, 0), bevel=0)
    # truss: one diagonal bay per module (the next module draws the next bay)
    L.rod("diag", (0, -h, 0.95), (0, 0, -0.95), 0.05, mat="hull_grey", verts=5)
    L.rod("diag2", (0, 0, -0.95), (0, h, 0.95), 0.05, mat="hull_grey", verts=5)
    L.rod("vert", (0, -h + 0.05, 0.95), (0, -h + 0.05, -0.95), 0.07, mat="hull_grey", verts=6)
    L.rod("arm", (0, 0, 0.95), (-0.55, 0, 0.95), 0.06, mat="hull_grey", verts=6)
    L.rod("arm2", (0, 0, -0.95), (-0.55, 0, -0.95), 0.06, mat="hull_grey", verts=6)
    L.ball("nav", 0.06, (-0.62, 0, 1.32), mat="led_blue", subdiv=1)


def ring_end():
    # rails come in from -Y (towards the board) into a vertical hub
    for z in (0.95, -0.95):
        L.cyl("rail", 0.15, 1.2, (0, -2.0, z), mat="hull_grey", rot=(-90, 0, 0), verts=8, bevel=0.02)
    L.cyl("hub", 0.95, 3.0, (0, -0.2, -1.5), mat="hull_white", verts=12, bevel=0.05)
    L.cyl("hubt", 1.0, 0.2, (0, -0.2, 1.1), mat="trim_blue", verts=12, bevel=0.03)
    L.cyl("hubb", 1.0, 0.2, (0, -0.2, -1.3), mat="trim_blue", verts=12, bevel=0.03)
    L.cyl("cap", 0.7, 0.3, (0, -0.2, 1.5), mat="hull_grey", verts=12, r2=0.45, bevel=0.03)
    L.cyl("mast", 0.06, 1.6, (0, -0.2, 1.8), mat="hull_grey", verts=6, bevel=0)
    L.ball("navt", 0.09, (0, -0.2, 3.42), mat="led_red", subdiv=1)
    for i in range(10):
        a = math.radians(i * 36)
        L.box("win", (0.04, 0.16, 0.2), (math.cos(a) * 0.96, -0.2 + math.sin(a) * 0.96, 0.3), mat="city_window",
              rot=(0, 0, math.degrees(a)), bevel=0)
    for s in (-1, 1):
        L.box("wing", (0.08, 1.8, 2.6), (s * 1.9, -0.2, 0.0), mat="solar_cell", bevel=0.02, segs=1)
        L.box("wingf", (0.1, 1.9, 0.08), (s * 1.9, -0.2, 1.32), mat="hull_grey", bevel=0.01, segs=1)
        L.rod("wboom", (s * 0.95, -0.2, 0), (s * 1.86, -0.2, 0), 0.06, mat="hull_grey", verts=6)
    L.cyl("dish", 0.55, 0.16, (0, -0.2, -3.2), mat="hull_white", verts=14, r2=0.2, bevel=0.02)


def truss_x(x0, x1, z0=-0.35, z1=0.35, y0=-0.35, y1=0.35):
    """Box truss along X: four longerons + zigzag diagonals on front and top."""
    ln = x1 - x0
    for y in (y0, y1):
        for z in (z0, z1):
            L.cyl("lon", 0.07, ln, (x0, y, z), mat="hull_grey", rot=(0, 90, 0), verts=6, bevel=0.0)
    n = max(1, int(round(ln / 0.7)))
    step = ln / n
    for i in range(n):
        xa, xb = x0 + i * step, x0 + (i + 1) * step
        za, zb = (z0, z1) if i % 2 == 0 else (z1, z0)
        L.rod("dz", (xa, y0, za), (xb, y0, zb), 0.035, mat="hull_grey", verts=4)
        L.rod("dz2", (xa, y1, za), (xb, y1, zb), 0.035, mat="hull_grey", verts=4)
        L.rod("dy", (xa, y0, z1), (xb, y1, z1), 0.035, mat="hull_grey", verts=4)
        L.rod("frame", (xa, y0, z0), (xa, y0, z1), 0.04, mat="hull_grey", verts=4)


def parker_module():
    h = C / 2
    truss_x(-h, h)
    # habitat module riding on the truss, windows to the board (-Y)
    L.box("mod", (2.4, 1.2, 1.0), (0, 0.1, 0.85), mat="hull_white", bevel=0.08)
    L.box("modt", (2.5, 1.25, 0.14), (0, 0.1, 0.42), mat="trim_blue", bevel=0.03, segs=1)
    L.box("modr", (2.2, 1.0, 0.1), (0, 0.1, 1.4), mat="hull_grey", bevel=0.03, segs=1)
    for x in (-0.7, 0.0, 0.7):
        L.box("roofw", (0.4, 0.5, 0.03), (x, 0.1, 1.46), mat="city_window", bevel=0)
    for x in (-0.6, 0.6):
        L.box("win", (0.36, 0.04, 0.22), (x, -0.51, 0.9), mat="city_window", bevel=0)
    L.box("rad", (1.6, 0.05, 0.9), (0, 0.95, 0.6), mat="foil_silver", bevel=0.01, segs=1)
    L.rod("radarm", (0, 0.7, 0.85), (0, 0.93, 0.6), 0.04, mat="hull_grey", verts=5)
    L.cyl("ant", 0.03, 0.6, (0.9, 0.3, 1.45), mat="hull_grey", verts=5, bevel=0)
    L.ball("nav", 0.05, (0.9, 0.3, 2.06), mat="led_blue", subdiv=1)


def parker_gate():
    h = C / 2
    gap = 1.25
    truss_x(-h, -gap)
    truss_x(gap, h)
    for s in (-1, 1):
        x = s * gap
        L.box("pylon", (0.36, 0.7, 2.6), (x, 0, 0.1), mat="hull_white", bevel=0.06)
        L.box("pylonb", (0.4, 0.74, 0.16), (x, 0, -1.1), mat="trim_orange", bevel=0.03, segs=1)
        L.box("pylont", (0.4, 0.74, 0.16), (x, 0, 1.3), mat="trim_orange", bevel=0.03, segs=1)
        L.box("pylonl", (0.06, 0.08, 1.9), (x - s * 0.19, -0.36, 0.1), mat="led_orange", bevel=0)
        L.box("pylonl2", (0.06, 0.08, 1.9), (x - s * 0.19, 0.36, 0.1), mat="led_orange", bevel=0)
        L.cyl("emit", 0.16, 0.22, (x - s * 0.24, 0, 0.0), mat="hull_dark", rot=(0, 90, 0), verts=10, bevel=0.02, base=False)
        L.cyl("emitl", 0.1, 0.05, (x - s * 0.36, 0, 0.0), mat="led_orange", rot=(0, 90, 0), verts=10, bevel=0, base=False)
    # gate lintel over the opening + ring frame around the beam line
    L.box("lintel", (2 * gap + 0.4, 0.5, 0.22), (0, 0, 1.45), mat="hull_grey", bevel=0.04)
    n = 16
    for i in range(n):
        a = 2 * math.pi * i / n
        if math.sin(a) < -0.55:
            continue
        L.box("ringseg", (0.12, 0.24, 0.42), (math.cos(a) * 1.05, 0.0, math.sin(a) * 1.05), mat="hull_dark" if i % 2 else "trim_orange",
              rot=(0, -math.degrees(a), 0), bevel=0.02, segs=1)
    L.box("sign", (1.3, 0.05, 0.3), (0, -0.27, 1.45), mat="trim_orange", bevel=0.01, segs=1)
    for sx in (-1, 1):
        L.box("pyltop", (0.24, 0.5, 0.03), (sx * gap, 0, 1.39), mat="led_orange", bevel=0)
    L.box("lintell", (2 * gap - 0.2, 0.1, 0.03), (0, 0, 1.57), mat="led_orange", bevel=0)


def parker_end():
    truss_x(-2.0, 0.6)
    L.cyl("hub", 0.8, 2.0, (-0.2, 0, -1.0), mat="hull_white", rot=(0, 0, 0), verts=12, bevel=0.05)
    L.cyl("hubt", 0.85, 0.18, (-0.2, 0, 0.75), mat="trim_blue", verts=12, bevel=0.03)
    L.cyl("dome", 0.6, 0.4, (-0.2, 0, 1.0), mat="hull_grey", verts=12, r2=0.3, bevel=0.03)
    for i in range(8):
        a = math.radians(i * 45)
        L.box("win", (0.04, 0.14, 0.18), (-0.2 + math.cos(a) * 0.81, math.sin(a) * 0.81, 0.2), mat="city_window",
              rot=(0, 0, math.degrees(a)), bevel=0)
    # solar array: two big wings out past the end, along Y
    L.rod("boom", (-0.2, 0, 0.0), (-2.6, 0, 0.0), 0.08, mat="hull_grey", verts=6)
    for s in (-1, 1):
        L.box("wing", (2.2, 1.5, 0.06), (-2.2, s * 1.0, 0.0), mat="solar_cell", bevel=0.02, segs=1)
        L.box("wingf", (2.3, 0.08, 0.08), (-2.2, s * 1.76, 0.0), mat="hull_grey", bevel=0.01, segs=1)
        for k in range(1, 4):
            L.box("wgrid", (0.03, 1.5, 0.07), (-3.3 + k * 0.55, s * 1.0, 0.0), mat="hull_grey", bevel=0)
    L.ball("nav", 0.07, (-0.2, 0, 1.45), mat="led_red", subdiv=1)


out = L.out_dir_arg("assets/3d/solar_flare")
only = L.variants_arg()
for name, fn in (("ring_module", ring_module), ("ring_end", ring_end), ("parker_module", parker_module),
                 ("parker_gate", parker_gate), ("parker_end", parker_end)):
    if only and name not in only:
        continue
    L.reset(seed=71)
    fn()
    L.finish(name, out, tex=1024, ground=False, snow=0.0, ao=0.75, ao_dist=0.6, edge=0.45, edge_r=0.02, tone=0.08)
