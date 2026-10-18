"""Kahramanmaras blocks broken open (#123 Fener): the facade or a whole side fell away and the rooms stand
open like a dollhouse section: sofas, beds, kitchens with the caydanlik on the stove, the soba and its pipe,
curtains blowing out over the broken slab edge, the wall clock stopped at 04:17. Rubble with household
things lies below. No people (figures come from the character assets).

  bld_cut_half     W12 G+5  left flat + stair fell (rubble heap), right flat cut open on its left side
  bld_cut_facade   W12 G+5  front facade peeled off the left flat and the top floors, rooms open to the street
  bld_cut_corner   W12 G+6  front-left corner came off from the 3rd floor up, top floor gone
Same grid as bld_apartment (depth 9, front = -Y). Usage: ... -P bld_cutaway.py -- [--only half,facade]
"""
import os
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "kit"))
import lib as L
import kmpal
import kmutil
from block import Block


def cells(spec):
    out = {}
    for kind, fs, cs in spec:
        for f in fs:
            for c in cs:
                out[(f, c)] = kind
    return out


VARIANTS = {
    "half": dict(W=12, n=5, plaster="plaster_cream", band="band_brown", ground="shops", roof="flat", damage=1.5,
                 name="GÜNEŞ APT.", no="9", patterns=["balcony", "stair", "balcony_glazed"], seed=201, ground_damage=2,
                 shops={2: [("MANAV", "sign_green", 0.0, None)]},
                 cells=cells([("gone", range(0, 6), [0]), ("gone", range(3, 6), [1]), ("open_l", range(3, 6), [2])]),
                 rooms={(3, 2): "kitchen", (4, 2): "salon", (5, 2): "salon"}),
    "facade": dict(W=12, n=5, plaster="plaster_salmon", band="plaster_terra", ground="shops", roof="flat", damage=1.5,
                   name="LALE APT.", no="31", patterns=["balcony", "stair", "balcony"], seed=202, ground_damage=1,
                   shops={0: [("BAKKAL", "sign_bakkal", 0.4, None)], 2: [("KIRTASİYE", "fabric_blue", 1.0, None)]},
                   cells=cells([("open", range(1, 6), [0]), ("open", range(4, 6), [2])]),
                   rooms={(1, 0): "bedroom", (2, 0): "salon", (3, 0): "kitchen", (4, 0): "salon", (5, 0): "bedroom",
                          (4, 2): "study", (5, 2): "salon"},
                   recess={(2, 0): 0.4, (4, 0): 0.7, (5, 2): 0.5}),
    "corner": dict(W=12, n=6, plaster="plaster_olive", band="band_cream", ground="residential", roof="flat", damage=1.8,
                   name="PINAR APT.", no="18", patterns=["windows", "stair", "balcony_glazed"], seed=203,
                   cells=cells([("gone", [6], [0]), ("open_l", [4, 5], [0]), ("open", [3], [0])]),
                   rooms={(3, 0): "salon", (4, 0): "bedroom", (5, 0): "salon"}),
}

kmpal.setup()
out = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()
for key, cfg in VARIANTS.items():
    if only and key not in only:
        continue
    L.reset(seed=cfg["seed"])
    Block(cfg).build()
    kmutil.merge_parts()
    p = L.finish("bld_cut_" + key, out, tex=2048, snow=0.85, ao=0.85, ao_dist=1.3, edge=0.35, edge_r=0.03,
                 grime=0.3, grime_h=1.2, margin=0.002)
    L.import_stub(p)
