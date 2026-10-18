"""Kahramanmaras neighbourhood blocks, standing (#123 Fener): 1990s-2000s betonarme apartments in the
plaster colours of the city, 3 to 8 storeys, hip / flat / unfinished (kat irtifaki) roofs, shops or raised
ground floors, balconies, cumba bay windows, stove pipes, dishes, solar heaters. Damage 0-2: X shear cracks,
spalled plaster over hollow brick, broken panes. Built by kit/block.py (cell grid), all four facades dressed.

Modular grid (see kit/block.py): depth 9 m (front = -Y / Godot +Z), widths 9 / 12 / 15 m, ground floor 3.4 m,
upper floors 2.9 m. Blocks stand edge to edge in a row on one street line.
  bld_apt_mint_4     W12  G+4  hip roof, raised ground floor, light damage
  bld_apt_yellow_6   W12  G+6  flat roof, shops (ECZANE, KUAFOR), cracked
  bld_apt_blue_3     W9   G+3  unfinished top floor with rebar, shop, almost intact
  bld_apt_grey_8     W15  G+8  flat roof, corner pilasters, three shops, heavily cracked
  bld_apt_peach_5    W12  G+5  hip roof, shops, cumba bays, cracked
Usage: blender -b --factory-startup --python-exit-code 1 -P tools/models/kahramanmaras/bld_apartment.py -- [--only a,b] [--out dir]
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

VARIANTS = {
    "mint_4": dict(W=12, n=4, plaster="plaster_mint", band="band_brown", ground="residential", roof="hip", damage=1,
                   name="YILDIZ APT.", no="7", patterns=["balcony", "stair", "balcony"], seed=101,
                   lit=((2, 0, "front"),)),
    "yellow_6": dict(W=12, n=6, plaster="plaster_yellow", band="plaster_terra", ground="shops", roof="flat", damage=1.5,
                     name="SEVGİ APT.", no="23", patterns=["balcony_glazed", "stair", "windows"], seed=102,
                     shops={0: [("ECZANE", "car_red", 0.0, None)], 2: [("KUAFÖR", "fabric_blue", 1.0, None)]}),
    "blue_3": dict(W=9, n=3, plaster="plaster_blue", band="band_cream", ground="shops", roof="unfinished", damage=0.6,
                   name="AKSU APT.", no="4", patterns=["balcony", "stair"], seed=103,
                   shops={0: [("MARAŞ DONDURMASI", "sign_white", 0.3, "awning")]}),
    "grey_8": dict(W=15, n=8, plaster="plaster_grey", band=None, corner="plaster_terra", ground="shops", roof="flat", damage=2,
                   name="KARDELEN SİTESİ B BLOK", no="41", patterns=["balcony", "stair", "cumba"], seed=104,
                   shops={0: [("BERBER", "metal_dark", 0.0, None), ("ÇAY OCAĞI", "sign_green", 0.6, None)],
                          2: [("KASAP", "sign_bakkal", 1.0, None), ("TEKEL", "plate_blue", 0.4, None)]}),
    "peach_5": dict(W=12, n=5, plaster="plaster_peach", band="band_cream", ground="shops", roof="hip", damage=1.2,
                    name="ÇINAR APT.", no="12", patterns=["cumba", "stair", "balcony_solid"], seed=105,
                    shops={0: [("FIRIN", "awning", 0.0, None)], 2: [("BAKKAL", "sign_bakkal", 0.5, None)]}),
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
    name = "bld_apt_" + key
    p = L.finish(name, out, tex=2048, snow=0.9, ao=0.85, ao_dist=1.4, edge=0.35, edge_r=0.03,
                 grime=0.3, grime_h=1.2, margin=0.002)
    L.import_stub(p)
