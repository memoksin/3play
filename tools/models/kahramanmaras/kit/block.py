"""Apartment block generator for the Kahramanmaras building set.

A block is a grid of CELLS: floor f (0 = ground floor) x column c (flat / stair, left to right).
Each cell is one of
  solid    plaster volume with its facade (windows, balconies, shops, cracks)
  open     the facade fell away: an exposed room (dollhouse section) with furniture
  open_l / open_r / open_lr   open on the front and on that side too (neighbour gone)
  gone     nothing left (rubble lies below)
  crushed  pancaked storey (all columns of a floor): squeezed rubble, the floors above sit on it
Footprint W x D centred on the origin, ground at z = 0, front = -Y (Godot +Z).
Facades are built for all four sides, so a block can face any way in a big neighbourhood.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
import lib as L
import facade as F
import interior as I
import ruin as R

FH = F.FH
SL = F.SL
WT = 0.25          # outer wall thickness (exposed rooms)
PAINTS = ["int_paint_a", "int_paint_b", "int_paint_c", "int_paint_d", "int_paint_e"]


def columns(W, stair=2.4):
    """Column layout (x0, x1, kind) for a width."""
    if W <= 10.5:
        return [(-W / 2, W / 2 - stair, "flat"), (W / 2 - stair, W / 2, "stair")]
    return [(-W / 2, -stair / 2, "flat"), (-stair / 2, stair / 2, "stair"), (stair / 2, W / 2, "flat")]


class Block:
    def __init__(self, cfg):
        c = dict(W=12.0, D=9.0, n=5, G=3.4, plaster="plaster_beige", band="plaster_terra", corner=None,
                 ground="shops", shops=None, name="APT.", no="1", patterns=None, roof="hip", damage=1,
                 cells=None, lean=None, seed=1, lit=(), crushed_h=0.7, plinth="stone_clad", side_pipes=True,
                 back_balconies=True, rooms=None, recess=None, rubble=True, ground_damage=0)
        c.update(cfg)
        self.c = c
        self.r = random.Random(c["seed"])
        self.W, self.D, self.n = c["W"], c["D"], c["n"]
        self.cols = columns(self.W)
        self.nf = self.n + 1
        self.cells = {}
        for f in range(self.nf):
            for i in range(len(self.cols)):
                self.cells[(f, i)] = "solid"
        for k, v in (c["cells"] or {}).items():
            self.cells[k] = v
        # floor heights / levels (crushed storeys squash)
        self.hf = []
        for f in range(self.nf):
            h = c["G"] if f == 0 else FH
            if all(self.cells[(f, i)] == "crushed" for i in range(len(self.cols))):
                h = c["crushed_h"]
            self.hf.append(h)
        self.zf = [0.0]
        for f in range(1, self.nf + 1):
            self.zf.append(self.zf[-1] + self.hf[f - 1])
        self.top = self.zf[self.nf]
        self.patterns = c["patterns"] or self._default_patterns()
        self.room_kinds = {}

    # ------------------------------------------------------------------ helpers
    def kind(self, f, i):
        if i < 0 or i >= len(self.cols) or f < 0 or f >= self.nf:
            return "out"
        return self.cells[(f, i)]

    def is_open(self, f, i):
        return self.kind(f, i).startswith("open")

    def _default_patterns(self):
        r = self.r
        pats = []
        opts = ["balcony", "balcony_glazed", "balcony_solid", "windows", "cumba"]
        for (x0, x1, kind) in self.cols:
            pats.append(r.choice(opts) if kind == "flat" else "stair")
        # mirror symmetric blocks
        if len(self.cols) == 3:
            pats[2] = pats[0] if r.random() < 0.7 else pats[2]
        return pats

    def side_us(self):
        D = self.D
        n = max(2, int(D / 3.0))
        return [-D / 2 + (j + 0.5) * D / n for j in range(n)]

    # ------------------------------------------------------------------ facades
    def facade(self, face, f, i):
        """Build the facade elements of one cell face in the wall frame and move them onto the face.
        Returns the list of window rects (u, v, w, h) used (for cracks + interior windows)."""
        r = self.r
        c = self.c
        x0, x1, ck = self.cols[i]
        cw = x1 - x0
        cx = (x0 + x1) / 2
        z0 = self.zf[f]
        h = self.hf[f]
        dmg = c["damage"]
        k = len(L.parts())
        rects = []
        lit = (f, i, face) in c["lit"]

        def pane_broken():
            return r.random() < 0.12 * dmg

        def shut():
            return r.choice([0, 0, 0, 0.3, 0.6, 1.0])

        if face == "front":
            u_lo, u_hi = -cw / 2, cw / 2
            pat = self.patterns[i]
            if f == 0:
                if ck == "stair":
                    F.entrance(0, c["name"], c["no"], r=r)
                    rects.append((0, 0.36, 1.3, 2.3))
                    rects.append((0, 2.9, 2.4, 0.6))
                elif c["ground"] == "shops":
                    shops = (c["shops"] or {}).get(i) or [("BAKKAL", "sign_bakkal", 0.5, None)]
                    m = len(shops)
                    sw = (cw - 0.4) / m
                    for j, s in enumerate(shops):
                        sign, smat, shutter, awn = (list(s) + [None] * 4)[:4]
                        u = -cw / 2 + 0.2 + (j + 0.5) * sw
                        F.shopfront(u, sw - 0.2, sign, smat, shutter or 0.0, h=min(2.75, h - 0.6), damage=c["ground_damage"], r=r, awning=awn)
                        rects.append((u, 0, sw, h))
                else:
                    us = [-cw / 4, cw / 4] if cw > 4 else [0]
                    for u in us:
                        F.window(u, 1.2, 1.2, 1.35, bars=True, shutter=shut(), broken=pane_broken(), r=r)
                        rects.append((u, 1.2, 1.2, 1.6))
            else:
                if ck == "stair":
                    F.window(0, 1.55, 0.75, 1.05, mull=False, box=False, broken=pane_broken(), r=r)
                    rects.append((0, 1.55, 0.75, 1.05))
                else:
                    side = -1 if cx < 0 else 1           # balcony on the outer side, mirrored
                    if pat.startswith("balcony"):
                        bw = min(3.4, cw - 1.5)
                        ub = side * (cw / 2 - bw / 2 - 0.25)
                        kind = {"balcony": "open", "balcony_glazed": "glazed", "balcony_solid": "solid"}[pat]
                        items = r.sample(["tup", "dish", "chairs", "rug", "laundry", "plants", "sacks", "snow", "pepper"], 2)
                        F.balcony(ub, 0.12, bw, 1.2, kind=kind, par=c["band"] or "plaster_terra", broken=pane_broken(), items=items,
                                  lit=lit, r=r)
                        rects.append((ub, 0.0, bw, h))
                        uw = -side * (cw / 2 - 0.85)
                        if abs(uw - ub) > bw / 2 + 0.7:
                            F.window(uw, 0.95, 1.1, 1.4, shutter=shut(), broken=pane_broken(), pane="window_glow" if lit else "glass", r=r)
                            rects.append((uw, 0.95, 1.1, 1.6))
                    elif pat == "cumba":
                        cwid = min(2.8, cw - 1.6)
                        uc = side * (cw / 2 - cwid / 2 - 0.4)
                        F.cumba(uc, 0.0, cwid, 0.7, plaster=c["plaster"], r=r)
                        rects.append((uc, 0, cwid, h))
                        uw = -side * (cw / 2 - 0.7)
                        F.window(uw, 0.95, 0.8, 1.35, shutter=shut(), broken=pane_broken(), r=r)
                        rects.append((uw, 0.95, 0.8, 1.6))
                    else:
                        us = [-cw / 4, cw / 4]
                        for j, u in enumerate(us):
                            F.window(u, 0.95, 1.3, 1.4, shutter=shut(), broken=pane_broken(),
                                     pane="window_glow" if (lit and j == 0) else "glass", r=r)
                            rects.append((u, 0.95, 1.3, 1.6))
            loc, yaw = (cx, -self.D / 2, z0), 0
        elif face == "back":
            u_lo, u_hi = -cw / 2, cw / 2
            if ck == "stair":
                if f > 0:
                    F.window(0, 1.55, 0.75, 1.05, mull=False, box=False, broken=pane_broken(), r=r)
                    rects.append((0, 1.55, 0.75, 1.05))
                else:
                    F.door(0, 0.0, 1.0, 2.1, mat="glass", frame="metal_dark")
                    rects.append((0, 0, 1.0, 2.2))
            else:
                us = [-cw / 4, cw / 4] if cw > 3.6 else [0]
                small_bal = c["back_balconies"] and f > 0 and cw > 4.0 and (f + i) % 2 == 0
                for j, u in enumerate(us):
                    if small_bal and j == 0:
                        F.balcony(u, 0.12, 2.0, 0.9, kind="open", par=c["band"] or "plaster_terra", broken=pane_broken(),
                                  items=r.sample(["laundry", "tup", "sacks", "plants"], 1), r=r)
                        rects.append((u, 0, 2.0, h))
                    else:
                        v = 1.2 if f == 0 else 0.95
                        F.window(u, v, 1.1, 1.3, shutter=shut(), broken=pane_broken(), bars=(f == 0), box=(f > 0), r=r)
                        rects.append((u, v, 1.1, 1.5))
            loc, yaw = (cx, self.D / 2, z0), 180
        else:  # left / right
            u_lo, u_hi = -self.D / 2, self.D / 2
            for j, u in enumerate(self.side_us()):
                v = 1.2 if f == 0 else 0.95
                if f == 0 and c["ground"] == "shops" and j == len(self.side_us()) - 1:
                    F.window(u, 0.5, 1.6, 2.0, mull=False, box=False, broken=pane_broken(), r=r)
                    rects.append((u, 0.5, 1.6, 2.1))
                    continue
                pane = "window_glow" if (lit and j == 1) else "glass"
                F.window(u, v, 1.1, 1.35, shutter=shut(), broken=pane_broken(), bars=(f == 0), pane=pane, r=r)
                rects.append((u, v, 1.1, 1.55))
            if f > 0 and c["side_pipes"] and r.random() < 0.5:
                u = r.choice(self.side_us()) + 0.75
                F.stove_pipe(u, 2.0)
                rects.append((u, 2.0, 0.5, 2.0))
            if f > 0 and r.random() < 0.3:
                u = self.side_us()[0] - 0.95
                if u > u_lo + 0.4:
                    F.ac_unit(u, 1.4)
                    rects.append((u, 1.4, 0.9, 0.7))
            if f > 1 and r.random() < 0.25:
                F.dish(self.side_us()[-1] + 0.9, 2.2, yaw=r.uniform(-30, 30))
            if face == "left":
                loc, yaw = (x0, 0, z0), -90
            else:
                loc, yaw = (x1, 0, z0), 90
        # plinth on the ground floor (stone base)
        if f == 0 and c["plinth"] and not (face == "front" and c["ground"] == "shops" and ck != "stair"):
            L.box("plinth", (u_hi - u_lo, 0.06, 0.45), ((u_lo + u_hi) / 2, -0.02, 0.225), mat=c["plinth"], bevel=0.01, segs=1)
        # damage marks on the wall: cracks in the piers, spalled plaster
        if dmg > 0 and h > 1.5:
            self._wall_damage(rects, u_lo, u_hi, h, dmg, f)
        F.on_face(L.since(k), loc, yaw)
        return rects

    def _wall_damage(self, rects, u_lo, u_hi, h, dmg, f):
        r = self.r

        def free(u, v, s):
            for (ru, rv, rw, rh) in rects:
                if abs(u - ru) < rw / 2 + s * 0.6 and rv - s * 0.9 < v < rv + rh + s * 0.9:
                    return False
            return u_lo + s < u < u_hi - s
        span = u_hi - u_lo
        lower = 1.0 if f <= 2 else 0.55           # lower storeys take more shear
        want = span / 6.0 * dmg * lower * r.uniform(0.5, 1.2)
        placed = 0
        for t in range(40):
            if placed >= want:
                break
            s = r.uniform(0.45, 0.85)
            u = r.uniform(u_lo, u_hi)
            v = r.uniform(0.9, h - 0.6)
            if not free(u, v, s):
                continue
            roll = r.random()
            if roll < 0.3:
                F.x_crack(u, v, s, r)
            elif roll < 0.7:
                # diagonal stair-step crack running from a window corner
                d = r.choice([-1, 1])
                F.run_crack(u - d * s, v - s * 1.1, u + d * s * r.uniform(0.6, 1.2), v + s * 1.1, r, wob=0.1, n=7, w=0.028)
            else:
                F.spall(u, v, s * 1.4, s * 1.0, r)
                if r.random() < 0.5:
                    F.run_crack(u + s * 0.6, v, u + s * 1.6, v - s * 0.9, r, wob=0.08, n=4, w=0.025)
            rects.append((u, v - s, s * 2, s * 2))
            placed += 1
        # floor-line crack (horizontal) on badly hit storeys
        if dmg >= 2 and r.random() < 0.5:
            F.run_crack(u_lo + 0.3, 0.1, u_hi - 0.3, 0.15, r, wob=0.08, n=8, w=0.03)

    # ------------------------------------------------------------------ cells
    def solid(self, f, i):
        c = self.c
        x0, x1, ck = self.cols[i]
        cw = x1 - x0
        cx = (x0 + x1) / 2
        z0, h = self.zf[f], self.hf[f]
        D = self.D
        mat = c["plaster"]
        if f == 0 and c["ground"] == "shops" and ck != "stair":
            mat = "concrete_dark"
        L.box("core", (cw, D, h), (cx, 0, z0), mat=mat, base=True, bevel=0.03, segs=1)
        if f == 0 and c["ground"] == "shops" and ck != "stair":
            # stone-clad piers between shops and plaster sides/back over the dark shop box
            L.box("gside", (cw, D - 0.5, h), (cx, 0.25, z0), mat=c["plaster"], base=True, bevel=0.03, segs=1)
            for s in (-1, 1):
                L.box("pier", (0.4, 0.5, h), (cx + s * (cw / 2 - 0.2), -D / 2 + 0.2, z0), mat="stone_clad", base=True, bevel=0.025, segs=1)
        # band at the floor line
        ext_l = 0.06 if self.kind(f, i - 1) in ("out",) else 0.0
        ext_r = 0.06 if self.kind(f, i + 1) in ("out",) else 0.0
        if c["band"] and f > 0:
            L.box("band", (cw + ext_l + ext_r, D + 0.12, 0.22), (cx + (ext_r - ext_l) / 2, 0, z0 - 0.11), mat=c["band"], base=True, bevel=0.02, segs=1)
        if c["corner"] and f > 0:
            for (edge, ex) in ((i == 0, x0), (i == len(self.cols) - 1, x1)):
                if edge:
                    for sy in (-1, 1):
                        L.box("pil", (0.36, 0.36, h), (ex, sy * (D / 2), z0), mat=c["corner"], base=True, bevel=0.03, segs=1)
        self.facade("front", f, i)
        self.facade("back", f, i)
        if i == 0:
            self.facade("left", f, i)
        if i == len(self.cols) - 1:
            self.facade("right", f, i)
        # exposed side next to a gone / open neighbour: broken plaster + brick over the party wall
        for side, nb in ((-1, i - 1), (1, i + 1)):
            nk = self.kind(f, nb)
            if nk == "gone" or (nk.startswith("open") and False):
                self._cut_face(f, i, side)
        # broken top under a gone cell
        if self.kind(f + 1, i) == "gone" or (f == self.nf - 1 and c["roof"] == "broken"):
            self._broken_top(f, i)

    def _cut_face(self, f, i, side):
        """Party wall left standing where the neighbour cell is gone: torn plaster, brick, slab ends."""
        r = self.r
        x0, x1, ck = self.cols[i]
        z0, h = self.zf[f], self.hf[f]
        x = x0 if side < 0 else x1
        k = len(L.parts())
        F.spall(r.uniform(-2, 2), h * 0.5, r.uniform(1.4, 2.4), r.uniform(1.0, 1.8), r)
        F.spall(r.uniform(-3, 3), h * 0.4, r.uniform(0.8, 1.4), r.uniform(0.6, 1.0), r)
        F.run_crack(-self.D / 2 + 0.4, h * 0.2, self.D / 2 - 0.4, h * 0.8, r, wob=0.3, w=0.05)
        L.box("slabend", (self.D, 0.12, SL), (0, -0.04, -SL / 2 + 0.02), mat="concrete_raw", bevel=0.02, segs=1)
        F.on_face(L.since(k), (x, 0, z0), -90 if side < 0 else 90)
        F.rebar_fringe((x, -self.D / 2 + 0.3, z0), (x, self.D / 2 - 0.3, z0), 8, out=(side, 0, 0), r=r)

    def _broken_top(self, f, i):
        """Top of a cell whose storey above fell away: jagged slab, rubble and rebar on it."""
        r = self.r
        x0, x1, ck = self.cols[i]
        cw = x1 - x0
        cx = (x0 + x1) / 2
        z = self.zf[f] + self.hf[f]
        R.slab(cw + 0.3, self.D + 0.2, (cx, 0, z + SL / 2 - 0.02), (0, 0, 0), t=SL, r=r, j=0.25)
        R.scatter(cx, 0, cw, self.D, 0.5, int(cw * self.D * 0.5), r, z=z + SL)
        R.mound(cx + r.uniform(-0.6, 0.6), r.uniform(-1.5, 1.5), cw * 0.6, self.D * 0.5, r.uniform(0.25, 0.45), r, z=z + SL - 0.05)
        for (px, py) in ((x0 + 0.2, -self.D / 2 + 0.2), (x1 - 0.2, -self.D / 2 + 0.2), (x0 + 0.2, self.D / 2 - 0.2), (x1 - 0.2, self.D / 2 - 0.2)):
            stub = r.uniform(0.2, 1.1)
            L.box("colstub", (0.35, 0.35, stub), (px, py, z + SL), mat="concrete_raw", base=True,
                  rot=(r.uniform(-6, 6), r.uniform(-6, 6), 0), bevel=0.03, segs=1)
            for j in range(4):
                L.rod("filiz", (px + (j % 2 - 0.5) * 0.2, py + (j // 2 - 0.5) * 0.2, z + SL + stub - 0.1),
                      (px + (j % 2 - 0.5) * 0.4 + r.uniform(-0.4, 0.4), py + (j // 2 - 0.5) * 0.4 + r.uniform(-0.4, 0.4), z + SL + stub + r.uniform(0.4, 1.0)),
                      0.016, mat="rebar", verts=4)

    def open_cell(self, f, i):
        """Exposed room(s): the front wall (and maybe a side wall) fell away."""
        r = self.r
        c = self.c
        x0, x1, ck = self.cols[i]
        cw = x1 - x0
        cx = (x0 + x1) / 2
        z0, h = self.zf[f], self.hf[f]
        D = self.D
        kind = self.kind(f, i)
        open_l = kind in ("open_l", "open_lr") or self.kind(f, i - 1) == "gone"
        open_r = kind in ("open_r", "open_lr") or self.kind(f, i + 1) == "gone"
        side_open = open_l or open_r
        rec = (c["recess"] or {}).get((f, i), 0.0)          # how far the slab broke back from the front
        paint = PAINTS[(f * 3 + i) % len(PAINTS)]
        paint2 = PAINTS[(f * 3 + i + 2) % len(PAINTS)]
        room_d = (D - WT) if side_open else r.uniform(3.6, 4.2)
        y_front = -D / 2 + rec
        y_back = -D / 2 + room_d
        floor_mat = "int_wood" if (f + i) % 3 else "int_tile"
        # --- floor slab: jagged on the open edges, rebar, a sagging lip
        edges = [0] + ([3] if open_l else []) + ([1] if open_r else [])
        sl_w = cw + (0.25 if open_l else 0) + (0.25 if open_r else 0) - 0.02
        sl_cx = cx + (-0.125 if open_l else 0) + (0.125 if open_r else 0)
        sl_d = y_back - y_front + 0.3
        R.slab(sl_w, sl_d, (sl_cx, (y_front + y_back) / 2 - 0.15, z0 - SL / 2 + 0.01), (0, 0, 0), t=SL, r=r, edges=edges, j=0.3)
        L.box("floorfin", (cw - 0.3, y_back - y_front - 0.45, 0.03), (cx, (y_front + y_back) / 2 + 0.1, z0 + 0.0), mat=floor_mat, base=True, bevel=0)
        # --- ceiling: the slab of the cell above (solid core / open slab) or a broken remnant
        above = self.kind(f + 1, i)
        if above == "solid":
            L.box("ceil", (cw - 0.1, y_back - y_front, 0.02), (cx, (y_front + y_back) / 2, z0 + h - 0.03), mat="int_ceiling", base=True, bevel=0)
        if above in ("gone", "out"):
            # roof slab broke off: remnant hanging from the back wall
            R.slab(cw * r.uniform(0.6, 0.95), r.uniform(0.8, 1.6), (cx + r.uniform(-0.4, 0.4), y_back - 0.6, z0 + h - 0.15),
                   (r.uniform(8, 22), r.uniform(-6, 6), 0), t=SL, r=r, edges=(0, 1, 3))
        # --- back wall: the rest of the flat is a solid block behind the room (or the building's back wall)
        if side_open:
            L.box("backw", (cw, WT, h), (cx, D / 2 - WT / 2, z0), mat=c["plaster"], base=True, bevel=0.02, segs=1)
            self.facade("back", f, i)
            # partition between the front room (salon) and the back room, with a doorway
            d1 = r.uniform(3.8, 4.4)
            yp = -D / 2 + d1
            door_u = cx + r.uniform(-cw * 0.2, cw * 0.2)
            for (a, b) in ((x0 + 0.02, door_u - 0.5), (door_u + 0.5, x1 - 0.02)):
                if b - a > 0.2:
                    L.box("part", (b - a, 0.12, h - 0.02), ((a + b) / 2, yp, z0), mat=paint, base=True, bevel=0.01, segs=1)
            L.box("parth", (1.0, 0.12, h - 2.1), (door_u, yp, z0 + 2.1), mat=paint, base=True, bevel=0.01, segs=1)
            L.box("partb", (cw - 0.04, 0.02, 0.1), (cx, yp - 0.07, z0 + 0.05), mat="f_wood", bevel=0)
            L.box("paintback", (cw - 0.04, 0.02, h - 0.05), (cx, D / 2 - WT - 0.012, z0), mat=paint2, base=True, bevel=0)
            # inner windows of the back wall
            for (u, v, ww, hh) in [(-cw / 4, 0.95, 1.1, 1.3), (cw / 4, 0.95, 1.1, 1.3)] if cw > 3.6 else [(0, 0.95, 1.1, 1.3)]:
                kk = len(L.parts())
                F.window(0, v, ww, hh, box=False, sill=False, mull=False, r=r)
                L.parent_to(L.since(kk), (cx - u, D / 2 - WT - 0.02, z0), (0, 0, 180))
            front_kind = (self.c["rooms"] or {}).get((f, i), r.choice(["salon", "salon", "kitchen", "study"]))
            back_kind = r.choice(["bedroom", "kitchen", "bedroom"])
            kk = len(L.parts())
            I.room(front_kind, cw - 0.1, d1 - rec - 0.1, h - 0.03, paint, r=r, open_left=open_l, open_right=open_r,
                   wear=1.0, edge_items=not open_l and not open_r)
            I.put(L.since(kk), cx, y_front + 0.05, z0)
            kk = len(L.parts())
            I.room(back_kind, cw - 0.1, D - WT - d1 - 0.15, h - 0.03, paint2, r=r, open_left=open_l, open_right=open_r,
                   wear=0.8, lamp=True, edge_items=False)
            I.put(L.since(kk), cx, yp + 0.08, z0)
        else:
            L.box("rest", (cw, D - room_d, h), (cx, (y_back + D / 2) / 2, z0), mat=c["plaster"], base=True, bevel=0.03, segs=1)
            L.box("paintback", (cw - 0.04, 0.02, h - 0.05), (cx, y_back - 0.012, z0), mat=paint, base=True, bevel=0)
            self.facade("back", f, i)
            # flat door to the hall in the back wall
            du = cx + (cw / 2 - 0.8) * (1 if (f + i) % 2 else -1)
            L.box("hall", (0.9, 0.03, 2.05), (du, y_back - 0.02, z0), mat="glass_broken", base=True, bevel=0)
            for s in (-1, 1):
                L.box("dfr", (0.08, 0.06, 2.1), (du + s * 0.49, y_back - 0.03, z0), mat="f_wood_light", base=True, bevel=0)
            L.box("dfrt", (1.06, 0.06, 0.08), (du, y_back - 0.03, z0 + 2.1), mat="f_wood_light", base=True, bevel=0)
            kind_r = (self.c["rooms"] or {}).get((f, i), r.choice(["salon", "bedroom", "kitchen", "salon", "study"]))
            self.room_kinds[(f, i)] = kind_r
            kk = len(L.parts())
            I.room(kind_r, cw - 0.3, room_d - rec - 0.12, h - 0.03, paint, r=r, open_left=open_l, open_right=open_r, wear=1.0)
            I.put(L.since(kk), cx, y_front + 0.05, z0)
        # --- side walls
        for side, nb, is_open in ((-1, i - 1, open_l), (1, i + 1, open_r)):
            xe = x0 if side < 0 else x1
            nk = self.kind(f, nb)
            ylen = (D - WT) if side_open else room_d
            if is_open:
                # a torn stub of the side wall at the back
                kk = len(L.parts())
                F.wall_chunk(r.uniform(0.8, 2.0), h * r.uniform(0.5, 0.95), WT, edges=("top", "left"), mat=c["plaster"], r=r)
                L.parent_to(L.since(kk), (xe, D / 2 - WT, z0), (0, 0, 90 if side < 0 else -90))
                continue
            if nk == "solid":
                L.box("paintside", (0.02, ylen - 0.05, h - 0.05), (xe - side * 0.012, -D / 2 + ylen / 2, z0), mat=paint, base=True, bevel=0)
            elif nk.startswith("open"):
                if side > 0:   # one partition between two open rooms, built by the left one
                    L.box("party", (0.16, ylen, h), (xe, -D / 2 + ylen / 2 + (rec * 0.5), z0), mat=paint, base=True, bevel=0.02, segs=1)
            else:
                # outer wall of an end cell: exterior plaster, its facade comes from the side facade pass
                L.box("sidew", (WT, ylen, h), (xe - side * WT / 2, -D / 2 + ylen / 2, z0), mat=c["plaster"], base=True, bevel=0.02, segs=1)
                L.box("paintside", (0.02, ylen - 0.05, h - 0.05), (xe - side * (WT + 0.012), -D / 2 + ylen / 2, z0), mat=paint, base=True, bevel=0)
                face = "left" if side < 0 else "right"
                rects = self.facade(face, f, i)
                # matching windows on the inside
                for (u, v, ww, hh) in rects:
                    yy = -u if side < 0 else u
                    if -D / 2 < yy < -D / 2 + ylen - 0.6 and hh < 1.7 and ww < 1.3:
                        kk = len(L.parts())
                        F.window(0, v, ww, hh - 0.2, box=False, sill=False, mull=False, r=r)
                        L.parent_to(L.since(kk), (xe - side * (WT + 0.02), yy, z0), (0, 0, 90 if side < 0 else -90))
        # --- facade remnants on the open front: corner column stubs and a torn spandrel
        for s in (-1, 1):
            if (s < 0 and open_l) or (s > 0 and open_r):
                continue
            if r.random() < 0.65:
                hh = h * r.uniform(0.35, 1.0)
                L.box("colrem", (0.3, 0.3, hh), (cx + s * (cw / 2 - 0.15), y_front + 0.15, z0), mat=c["plaster"], base=True,
                      rot=(0, 0, 0), bevel=0.03, segs=1)
                F.rebar_fringe((cx + s * (cw / 2 - 0.15), y_front + 0.15, z0 + hh), (cx + s * (cw / 2 - 0.15) + 0.01, y_front + 0.16, z0 + hh), 4,
                               out=(0, 0, 0), droop=(0.2, 0.7), length=(0.05, 0.2), r=r)
        if r.random() < 0.6 and rec < 0.3:
            ww = r.uniform(1.0, cw * 0.5)
            kk = len(L.parts())
            F.wall_chunk(ww, r.uniform(0.5, 0.95), 0.2, edges=("top", "left", "right"), mat=c["plaster"], amp=0.25, r=r)
            L.parent_to(L.since(kk), (cx + r.uniform(-cw / 2 + 0.2, cw / 2 - 0.2 - ww), y_front - 0.02, z0), (0, 0, 0))
        # hanging broken band strip / slab lip drooping over the edge
        if r.random() < 0.5:
            lw = r.uniform(1.0, 2.2)
            L.box("lip", (lw, 0.6, SL), (cx + r.uniform(-cw / 4, cw / 4), y_front - 0.25, z0 - 0.25), mat="concrete",
                  rot=(r.uniform(25, 50), r.uniform(-8, 8), 0), bevel=0.03, segs=1)

    def crushed(self, f):
        r = self.r
        z0, h = self.zf[f], self.hf[f]
        R.crushed_layer(self.W + 0.7, self.D + 0.7, 0, 0, z0, h, r, density=0.75)
        # plaster + brick bulging out of the band, a few bigger wall pieces caught in it
        for i in range(int(self.W / 1.5)):
            x = -self.W / 2 + 0.6 + i * 1.5 + r.uniform(-0.3, 0.3)
            L.blob("bulge", (r.uniform(0.9, 1.6), r.uniform(0.6, 1.0), h * 0.45), (x, -self.D / 2 - 0.15, z0 + h * 0.1),
                   mat=r.choice(["debris_brick", "debris_grey", "brick_hollow"]), lumpy=0.25, subdiv=1)
        for i in range(2):
            kk = len(L.parts())
            F.wall_chunk(r.uniform(1.2, 2.0), r.uniform(0.6, 1.0), 0.2, edges=("top", "left", "right"), mat=self.c["plaster"], r=r)
            L.parent_to(L.since(kk), (r.uniform(-self.W / 2, self.W / 2 - 2), -self.D / 2 - 0.4, z0 + 0.1), (r.uniform(-30, -10), r.uniform(-15, 15), 0))
        for i in range(int(self.W / 2.2)):
            R.squeezed_frame(-self.W / 2 + 1.2 + i * 2.2 + r.uniform(-0.3, 0.3), -self.D / 2 - 0.05, z0 + 0.05, 0, r=r)
        for i in range(int(self.D / 3)):
            R.squeezed_frame(-self.W / 2 - 0.05, -self.D / 2 + 1.5 + i * 3, z0 + 0.05, -90, r=r)
        for x in (-self.W / 3, self.W / 3):
            R.bent_rail(x, -self.D / 2 - 0.5, z0 + h * 0.5, 3.0, r=r)
        # slab under the crushed storey bulges out
        R.slab(self.W + 0.5, self.D + 0.5, (0, 0, z0 - SL / 2), (0, 0, 0), t=SL, r=r, j=0.2)

    # ------------------------------------------------------------------ roofs
    def roof(self):
        c = self.c
        r = self.r
        top_f = self.nf - 1
        all_solid = all(self.kind(top_f, i) == "solid" for i in range(len(self.cols)))
        z = self.top
        if c["roof"] == "hip" and all_solid:
            L.box("cornice", (self.W + 0.3, self.D + 0.3, 0.3), (0, 0, z), mat=c["band"] or "concrete", base=True, bevel=0.04)
            hip_roof(self.W, self.D, z + 0.3, r=r, damage=c["damage"])
            return
        for i, (x0, x1, ck) in enumerate(self.cols):
            if self.kind(top_f, i) != "solid":
                continue
            cw = x1 - x0
            cx = (x0 + x1) / 2
            if c["roof"] == "unfinished":
                unfinished_top(x0, x1, self.D, z, r, first=(i == 0), last=(i == len(self.cols) - 1))
            elif c["roof"] == "broken":
                pass
            else:
                flat_top(x0, x1, self.D, z, r, c["band"] or "concrete", first=(i == 0), last=(i == len(self.cols) - 1),
                         stair=(ck == "stair"))

    # ------------------------------------------------------------------ all
    def build(self):
        c = self.c
        r = self.r
        k_lean = None
        lean_from = None
        for f in range(self.nf):
            if lean_from is None and c["lean"] and f > 0 and self.kind(f - 1, 0) == "crushed":
                lean_from = f
                k_lean = len(L.parts())
            if c["lean"] and lean_from is None and c["lean"].get("from") == f:
                lean_from = f
                k_lean = len(L.parts())
            if all(self.kind(f, i) == "crushed" for i in range(len(self.cols))):
                self.crushed(f)
                continue
            for i in range(len(self.cols)):
                kd = self.kind(f, i)
                if kd == "solid":
                    self.solid(f, i)
                elif kd.startswith("open"):
                    self.open_cell(f, i)
        self.roof()
        if c.get("post") and k_lean is not None:
            c["post"](self, L.since(k_lean), lean_from)
        elif c["lean"] and k_lean is not None:
            lf = lean_from
            piv = (c["lean"].get("px", 0.0), c["lean"].get("py", -self.D / 2), self.zf[lf])
            objs = L.since(k_lean)
            L.parent_to(objs, (-piv[0], -piv[1], -piv[2]), (0, 0, 0))
            L.parent_to(objs, piv, (c["lean"].get("rx", 0), c["lean"].get("ry", 0), c["lean"].get("rz", 0)))
            L.parent_to(objs, (c["lean"].get("dx", 0.0), c["lean"].get("dy", 0.0), 0), (0, 0, 0))
        # rubble under gone cells, debris at the foot, snow drifts
        if c["rubble"]:
            for i, (x0, x1, ck) in enumerate(self.cols):
                gone = sum(1 for f in range(self.nf) if self.kind(f, i) == "gone")
                if gone:
                    lowest = min(f for f in range(self.nf) if self.kind(f, i) == "gone")
                    zb = self.zf[lowest] if lowest > 0 else 0.0
                    if lowest == 0:
                        R.rubble_heap((x0 + x1) / 2, -0.8, (x1 - x0) + 3.0, self.D + 2.5, min(1.0 + gone * 0.5, 3.5), r,
                                      plaster=c["plaster"], slabs=gone + 1, walls=2, household_n=6 + gone)
                    else:
                        # what fell from up there lies in front of the block
                        R.rubble_heap((x0 + x1) / 2 + r.uniform(-0.5, 0.5), -self.D / 2 - 2.2, (x1 - x0) + 2.5, 4.2, 0.6 + gone * 0.35, r,
                                      plaster=c["plaster"], slabs=gone, walls=1 + gone // 2, household_n=4 + gone * 2, density=0.7)
            # a pancaked storey spits its infill out onto the pavement
            crushed_fs = [f for f in range(self.nf) if all(self.kind(f, i) == "crushed" for i in range(len(self.cols)))]
            if crushed_fs:
                hh = 0.7 + 0.25 * len(crushed_fs)
                R.rubble_heap(0, -self.D / 2 - 1.4, self.W + 2.0, 3.6, hh, r, plaster=c["plaster"], slabs=2, walls=1,
                              household_n=4 + 2 * len(crushed_fs), density=0.7)
                R.scatter(0, 0, self.W + 3.0, self.D + 3.0, 0.2, 50, r, size=(0.12, 0.45), ring=True)
            # open rooms shed things: rubble in front of them
            opens = [(f, i) for (f, i), v in self.cells.items() if v.startswith("open")]
            if opens:
                xs = [(self.cols[i][0] + self.cols[i][1]) / 2 for f, i in opens]
                cx = sum(xs) / len(xs)
                R.rubble_heap(cx, -self.D / 2 - 1.7, max(4.0, (max(xs) - min(xs)) + 4.0), 3.4, 0.5 + 0.12 * len(opens), r,
                              plaster=c["plaster"], slabs=2, walls=1 + len(opens) // 3, household_n=3 + len(opens), density=0.6)
        if c["damage"] > 0:
            for i in range(int(6 * c["damage"])):
                L.box("deb", (r.uniform(0.12, 0.4), r.uniform(0.1, 0.3), r.uniform(0.05, 0.14)),
                      (r.uniform(-self.W / 2, self.W / 2), -self.D / 2 - r.uniform(0.3, 1.8), 0.04),
                      mat=r.choice([c["plaster"], "brick_hollow", "concrete_raw", "roof_tile"]),
                      rot=(0, 0, r.uniform(0, 180)), bevel=0.02, segs=1)
        R.snow_drifts(0, 0, self.W + 0.8, self.D + 0.8, 7, r)


# ---------------------------------------------------------------------------------------------
# roofs
# ---------------------------------------------------------------------------------------------

def hip_roof(W, D, z0, ov=0.5, ridge_h=None, r=None, damage=0):
    """Kiremit hip roof: solid core + tile rows (snow on each row's top) + ridge/hip caps, heaters, chimneys."""
    r = r or L.rng()
    ridge_h = ridge_h or min(3.0, D * 0.33)
    hw, hd = W / 2 + ov, D / 2 + ov
    rl = max(0.3, hw - hd)
    v = [(-hw, -hd, z0), (hw, -hd, z0), (hw, hd, z0), (-hw, hd, z0), (-rl, 0, z0 + ridge_h), (rl, 0, z0 + ridge_h)]
    fcs = [(3, 2, 1, 0), (0, 1, 5, 4), (1, 2, 5), (2, 3, 4, 5), (3, 0, 4)]
    L.mesh("roof", v, fcs, mat="roof_tile", smooth=5)
    L.box("fascia", (2 * hw, 2 * hd, 0.16), (0, 0, z0 - 0.08), mat="frame", bevel=0.02, segs=1)
    a = math.atan2(ridge_h, hd)
    S = math.hypot(hd, ridge_h)
    n = int(S / 0.55)
    ad = math.degrees(a) + 11.0
    missing = set()
    if damage >= 2:
        missing = {r.randint(0, n - 1) for _ in range(2)}
    for i in range(n):
        t = (i + 0.5) / n
        z = z0 + t * ridge_h + 0.06
        run = hd * (1 - t)
        half_f = rl + run
        half_s = run
        if i in missing:   # a strip of tiles slid off: battens show
            for j in range(int(half_f * 2 / 0.6)):
                L.box("batten", (0.05, S / n, 0.04), (-half_f + 0.3 + j * 0.6, -run, z - 0.02), mat="wood", rot=(math.degrees(a), 0, 0), bevel=0)
        else:
            L.box("trf", (2 * half_f, S / n + 0.06, 0.1), (0, -run, z), mat="roof_tile", rot=(ad, 0, 0), bevel=0.015, segs=1)
        L.box("trb", (2 * half_f, S / n + 0.06, 0.1), (0, run, z), mat="roof_tile", rot=(-ad, 0, 0), bevel=0.015, segs=1)
        if half_s > 0.15:
            L.box("trr", (S / n + 0.06, 2 * half_s, 0.1), (rl + run, 0, z), mat="roof_tile", rot=(0, ad, 0), bevel=0.015, segs=1)
            L.box("trl", (S / n + 0.06, 2 * half_s, 0.1), (-rl - run, 0, z), mat="roof_tile", rot=(0, -ad, 0), bevel=0.015, segs=1)
    L.box("ridge", (2 * rl + 0.3, 0.26, 0.2), (0, 0, z0 + ridge_h + 0.08), mat="roof_tile", bevel=0.06)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.rod("hip", (sx * hw, sy * hd, z0 + 0.05), (sx * rl, 0, z0 + ridge_h + 0.1), 0.12, mat="roof_tile", verts=6)

    def rz(x, y):
        return z0 + ridge_h * min(1 - abs(y) / hd, (1 - (abs(x) - rl) / hd) if abs(x) > rl else 1)
    for x in ([-W * 0.2, W * 0.22] if W > 10 else [0.0]):
        y = -hd * 0.45
        solar_heater(x, y, rz(x, y) - 0.15, r=r)
    chimney(-W * 0.36, hd * 0.4, rz(-W * 0.36, hd * 0.4) - 0.3)
    chimney(W * 0.33, hd * 0.5, rz(W * 0.33, hd * 0.5) - 0.3, 1.9)
    antenna(W * 0.07, hd * 0.25, rz(W * 0.07, hd * 0.25) - 0.1)


def solar_heater(x, y, z, yaw=0, r=None):
    k = len(L.parts())
    L.box("sp", (1.0, 1.9, 0.07), (-0.55, 0, 0.6), mat="solar_glass", rot=(38, 0, 0), bevel=0.02, segs=1)
    L.box("sp2", (1.0, 1.9, 0.07), (0.55, 0, 0.6), mat="solar_glass", rot=(38, 0, 0), bevel=0.02, segs=1)
    L.box("spf", (2.2, 1.95, 0.05), (0, 0, 0.56), mat="metal", rot=(38, 0, 0), bevel=0, segs=1)
    L.cyl("tank", 0.28, 2.3, (-1.15, 0.85, 1.35), mat="tank_white", rot=(0, 90, 0), verts=12, bevel=0.04)
    for sx in (-0.9, 0.9):
        L.box("leg", (0.05, 0.05, 1.1), (sx, 0.85, 0.55), mat="metal", bevel=0)
        L.box("leg2", (0.05, 1.6, 0.05), (sx, 0.05, 0.05), mat="metal", rot=(-25, 0, 0), bevel=0)
    return L.parent_to(L.since(k), (x, y, z), (0, 0, yaw))


def water_tank(x, y, z, r=None):
    """Rooftop water tank (su deposu) on a steel stand."""
    k = len(L.parts())
    L.cyl("wt", 0.55, 1.2, (0, 0, 0.5), mat="tank_white", verts=14, bevel=0.05)
    L.cyl("wtl", 0.58, 0.1, (0, 0, 1.7), mat="tank_white", verts=14, r2=0.3, bevel=0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box("wts", (0.06, 0.06, 0.5), (sx * 0.4, sy * 0.4, 0.25), mat="metal", bevel=0)
    L.rod("wtp", (0.5, 0, 0.6), (0.9, 0, 0.0), 0.03, mat="metal_dark", verts=5)
    return L.parent_to(L.since(k), (x, y, z), (0, 0, 0))


def chimney(x, y, z, h=1.6):
    L.box("chim", (0.55, 0.55, h), (x, y, z), mat="plaster_terra", bevel=0.03, base=True)
    L.box("chimc", (0.75, 0.75, 0.1), (x, y, z + h), mat="concrete", bevel=0.02, base=True)


def antenna(x, y, z):
    L.cyl("ant", 0.02, 2.2, (x, y, z), mat="metal", verts=5, bevel=0)
    for i in range(4):
        L.box("antb", (0.9 - i * 0.15, 0.02, 0.02), (x, y, z + 1.4 + i * 0.22), mat="metal", bevel=0)


def flat_top(x0, x1, D, z, r, parapet, first, last, stair=False):
    """Flat roof slab with a parapet, water tanks, solar heaters, dishes, a stair housing."""
    cw = x1 - x0
    cx = (x0 + x1) / 2
    L.box("rslab", (cw + (0.15 if first else 0) + (0.15 if last else 0), D + 0.3, 0.18),
          (cx + (-0.075 if first else 0) + (0.075 if last else 0), 0, z), mat="concrete", base=True, bevel=0.03, segs=1)
    ph = 0.75
    L.box("parf", (cw, 0.18, ph), (cx, -D / 2 - 0.06, z + 0.18), mat=parapet, base=True, bevel=0.025, segs=1)
    L.box("parb", (cw, 0.18, ph), (cx, D / 2 + 0.06, z + 0.18), mat=parapet, base=True, bevel=0.025, segs=1)
    if first:
        L.box("parl", (0.18, D + 0.3, ph), (x0 - 0.06, 0, z + 0.18), mat=parapet, base=True, bevel=0.025, segs=1)
    if last:
        L.box("parr", (0.18, D + 0.3, ph), (x1 + 0.06, 0, z + 0.18), mat=parapet, base=True, bevel=0.025, segs=1)
    L.box("cap", (cw, 0.26, 0.06), (cx, -D / 2 - 0.06, z + 0.18 + ph), mat="concrete", base=True, bevel=0.01, segs=1)
    L.box("capb", (cw, 0.26, 0.06), (cx, D / 2 + 0.06, z + 0.18 + ph), mat="concrete", base=True, bevel=0.01, segs=1)
    zt = z + 0.18
    if stair:
        L.box("stairhouse", (cw - 0.2, 3.0, 2.4), (cx, 1.5, zt), mat="plaster_grey", base=True, bevel=0.03, segs=1)
        L.box("shroof", (cw + 0.1, 3.3, 0.15), (cx, 1.5, zt + 2.4), mat="concrete", base=True, bevel=0.02, segs=1)
        kk = len(L.parts())
        F.wood_door(0, 0, 0.9, 2.0)
        F.on_face(L.since(kk), (cx, 0.0, zt), 0)
        water_tank(cx, 1.5, zt + 2.55, r)
    else:
        solar_heater(cx + r.uniform(-0.6, 0.6), -D * 0.2, zt, r=r)
        if r.random() < 0.7:
            water_tank(cx + r.uniform(-1, 1), D * 0.25, zt, r)
        for j in range(r.randint(1, 3)):
            kk = len(L.parts())
            L.cyl("dpole", 0.025, 1.2, (0, 0, 0), mat="metal", verts=5, bevel=0)
            L.cyl("dish", 0.32, 0.09, (0, -0.08, 1.15), mat="tank_white", rot=(-70, 0, 0), verts=12, r2=0.19, bevel=0.01)
            L.parent_to(L.since(kk), (cx + r.uniform(-cw / 2 + 0.5, cw / 2 - 0.5), r.uniform(D * 0.05, D * 0.4), zt), (0, 0, r.uniform(-40, 40)))


def unfinished_top(x0, x1, D, z, r, first, last):
    """Kat irtifaki: the owner's 'one more floor later' — columns with rebar sprouting (filiz), half-laid
    brick, a stack of bricks and a ladder."""
    cw = x1 - x0
    cx = (x0 + x1) / 2
    L.box("rslab", (cw, D, 0.2), (cx, 0, z), mat="concrete_new", base=True, bevel=0.03, segs=1)
    zt = z + 0.2
    xs = [x0 + 0.2] + ([x1 - 0.2] if last else [x1 - 0.2])
    ys = [-D / 2 + 0.2, 0.0, D / 2 - 0.2]
    for x in xs:
        for y in ys:
            hh = r.choice([0.25, 0.4, 1.2, 2.4])
            L.box("ucol", (0.35, 0.35, hh), (x, y, zt), mat="concrete_new", base=True, bevel=0.025, segs=1)
            for j in range(4):
                ox, oy = (j % 2 - 0.5) * 0.22, (j // 2 - 0.5) * 0.22
                L.rod("filiz", (x + ox, y + oy, zt + hh - 0.05), (x + ox * 1.6 + r.uniform(-0.12, 0.12), y + oy * 1.6 + r.uniform(-0.12, 0.12), zt + hh + r.uniform(0.6, 1.1)),
                      0.014, mat="rebar", verts=4)
    # half-laid hollow brick wall at the back
    rows = r.randint(3, 7)
    for row in range(rows):
        n = int((cw - 0.6) / 0.3) - (row // 2)
        for j in range(n):
            L.box("ubr", (0.28, 0.19, 0.19), (x0 + 0.45 + j * 0.3 + (0.15 if row % 2 else 0), D / 2 - 0.3, zt + 0.1 + row * 0.2),
                  mat="brick_hollow", bevel=0.01, segs=1)
    # brick pallet + sand
    for j in range(3):
        for q in range(3):
            L.box("pal", (0.29, 0.19, 0.19), (cx - 0.3 + q * 0.3, -1.2 + j * 0.2, zt + 0.1), mat="brick_hollow", bevel=0.01, segs=1)
    L.box("pal2", (0.9, 0.6, 0.38), (cx, -1.0, zt + 0.2), mat="brick_hollow", base=True, bevel=0.02, segs=1)
    L.blob("sand", (1.4, 1.0, 0.35), (cx + 1.2, 1.0, zt), mat="clay", lumpy=0.12, subdiv=2)
    kk = len(L.parts())
    for s in (-1, 1):
        L.box("lad", (0.05, 0.05, 2.6), (s * 0.22, 0, 1.3), mat="wood", bevel=0)
    for j in range(8):
        L.box("rung", (0.44, 0.04, 0.04), (0, 0, 0.25 + j * 0.3), mat="wood", bevel=0)
    L.parent_to(L.since(kk), (cx - cw * 0.3, D / 2 - 0.6, zt), (-18, 0, 0))
