"""Municipal street lamp: octagonal grey pole on a concrete footing, curved arm, flat luminaire.
The city grid went down after 04:17, so the lamp head is dark (no glow part).
Variants: street_lamp (upright), street_lamp_bent (pole kinked and leaning, snapped cable hanging)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

H = 6.5


def build(bent):
    k0 = len(L.parts())
    L.cyl("foot", 0.32, 0.35, mat="concrete", verts=8, bevel=0.03)
    L.cyl("base", 0.17, 0.9, (0, 0, 0.35), mat="metal", verts=8, bevel=0.02, r2=0.13)
    L.box("hatch", (0.1, 0.02, 0.3), (0, -0.15, 0.75), mat="metal_dark", bevel=0.005, segs=1)
    k_up = len(L.parts())
    L.cyl("pole", 0.11, H - 1.25, (0, 0, 1.25), mat="metal", verts=8, bevel=0.01, r2=0.07)
    # curved arm toward -Y (over the street) from 5 short segments
    x, z = 0.0, H
    a = 90.0
    for i in range(6):
        ln = 0.32
        rad = math.radians(a)
        L.cyl("arm", 0.055, ln + 0.04, (0, -x, z), mat="metal", rot=(90 - a, 0, 0), verts=6, bevel=0)
        x += math.cos(rad) * ln
        z += math.sin(rad) * ln
        a -= 18
    L.box("head", (0.34, 0.9, 0.14), (0, -x - 0.35, z - 0.02), mat="metal_dark", rot=(-6, 0, 0), bevel=0.04)
    L.box("lens", (0.26, 0.7, 0.03), (0, -x - 0.35, z - 0.1), mat="glass", rot=(-6, 0, 0), bevel=0.01, segs=1)
    L.snowcap("shead", (0.3, 0.8, 0.07), (0, -x - 0.35, z + 0.05), rot=(-6, 0, 0), droop=0.4)
    # municipal banner bracket + small sign plate
    L.box("plate", (0.03, 0.42, 0.3), (0.12, 0, 2.7), mat="plate_blue", bevel=0.01, segs=1)
    L.text("platet", "AZERBAYCAN CD.", 0.045, (0.137, 0, 2.7), mat="sign_white", rot=(90, 0, 90), depth=0.004)
    up = L.since(k_up)
    if bent:
        # kink at 1.25 m: lean 17 degrees sideways-forward, snapped power cable to the ground
        for o in up:
            o.location.z -= 1.25
        L.parent_to(up, (0, 0, 1.25), (-9, 14, 0))
        from mathutils import Matrix, Vector
        M = Matrix.Translation((0, 0, 1.25)) @ Matrix.Rotation(math.radians(14), 4, "Y") @ Matrix.Rotation(math.radians(-9), 4, "X")
        top = M @ Vector((0, 0, 4.6))
        pts = [tuple(top), (top.x + 0.6, top.y + 0.3, 3.3), (top.x + 1.0, top.y + 0.5, 1.6), (top.x + 1.2, top.y + 0.4, 0.4),
               (top.x + 1.6, top.y, 0.05), (top.x + 2.8, top.y - 0.6, 0.05)]
        for p0, p1 in zip(pts, pts[1:]):
            L.rod("cable", p0, p1, 0.025, mat="car_trim", verts=5)
        L.blob("crack_snow", (1.4, 1.0, 0.1), (0.4, 0.5, 0), mat="snow")
    else:
        L.blob("foot_snow", (1.2, 0.9, 0.12), (0.1, 0.15, 0), mat="snow")


out = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()
for v in ("street_lamp", "street_lamp_bent"):
    if only and v not in only:
        continue
    L.reset(seed=31)
    build(v.endswith("bent"))
    L.finish(v, out, tex=512, snow=0.8, ao=0.8, ao_dist=0.5, edge=0.4, edge_r=0.015, grime=0.3, grime_h=0.6)
