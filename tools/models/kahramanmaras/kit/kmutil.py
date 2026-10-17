"""Build-speed helpers for the big building models."""
import os
import sys
from collections import defaultdict

import bmesh
import bpy

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
import lib as L


def merge_parts():
    """Join parts that share palette key + bevel settings into one object each, before L.finish().
    finish() bevels/converts objects one by one (cost grows with the square of the object count); a block
    has 3-5k parts but only ~150 distinct (material, bevel) groups. Same geometry, same bake."""
    parts = L.parts()
    groups = defaultdict(list)
    for o in parts:
        key = (o["pal"], round(float(o.get("bevel", 0.0)), 4), int(o.get("segs", 2)), round(float(o.get("smooth", 35.0)), 1),
               int(o.get("subsurf", 0)))
        groups[key].append(o)
    new = []
    for key, obs in groups.items():
        if len(obs) == 1:
            new.append(obs[0])
            continue
        bm = bmesh.new()
        for o in obs:
            me = o.data.copy()
            me.transform(o.matrix_basis)
            bm.from_mesh(me)
            bpy.data.meshes.remove(me)
        pal, bevel, segs, smooth, subsurf = key
        n0 = len(L.parts())
        ob = L._obj("m_" + pal, bm, pal, (0, 0, 0), (0, 0, 0), bevel, segs, smooth)
        if subsurf:
            ob["subsurf"] = subsurf
        new.append(ob)
        for o in obs:
            me = o.data
            bpy.data.objects.remove(o)
            if me.users == 0:
                bpy.data.meshes.remove(me)
    parts[:] = new
    return len(new)
