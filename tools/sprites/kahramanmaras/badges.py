"""Warm (flame) and cold (snowflake) badges, 8x8 logical, exported 4x (32x32)."""
import os
from common import Canvas, export, ART, ascii_art, LINE

FLAME = dict(O=LINE, Y="#fb6b1d", M="#f9c22b", C="#fbff86")
SNOW = dict(B="#4d9be6", H="#8fd3ff", W="#ffffff")
FLAME_ART = ["....O...", "...OYO..", "..OYYYO.", ".OYYMYYO", ".OYMMMYO", ".OYMCMYO", ".OYMCMYO", "..OOOOO."]
SNOW_ART = ["...BB...", "B..BB..B", ".B.BB.B.", "BBBHHBBB", "BBBHHBBB", ".B.BB.B.", "B..BB..B", "...BB..."]


def build():
    for name, art, pal in (("warm", FLAME_ART, FLAME), ("cold", SNOW_ART, SNOW)):
        c = Canvas(8, 8, 1)
        ascii_art(c, art, pal)
        export([c], os.path.join(ART, "%s_icon.png" % name), 4)


if __name__ == "__main__":
    build()
