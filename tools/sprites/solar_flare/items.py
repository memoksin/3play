"""Solar flare Fit items, same grid as the people (1 logical px = 4 px in the file, 2 px on screen). Both are 2-slot
items, so 32x16 logical (128x64). Built from parts placed on a blank 32x16 sheet with `over`; fill only, then `autoline`
adds the 1 px dark outline. Light from the upper left."""
from pix import new, paint, over, autoline, export

BLANK = ["." * 32] * 16

# Shared steel: T top plate / t shade | L light edge / I body / i shade / c dark | O window frame | B feet
STEEL = dict(T="#ffffff", t="#c7dcd0", L="#c7dcd0", I="#9babb2", i="#7f708a", c="#625565", O="#3e3546", B="#3e3546")

# ---- seed vault: cryo case with racks of seed vials, a sprout under a glass dome next to it ----------------------
# G/Y/R vial caps | s seeds | f cold interior | k rack | g green LED | b blue LED | x frost light
VAULT_CASE = [                # cols 1..19, rows 4..15
    "TTTTTTTTTTTTTTTTTTt",
    "LIIIIIIIIIIIIIIIIic",
    "LIOOOOOOOOOOOOOIIic",
    "LIOGfYfRfGfYfROIgic",
    "LIOVfVfVfVfVfVOIIic",
    "LIOsfsfsfsfsfsOIbic",
    "LIOkkkkkkkkkkkOIIic",
    "LIOYfGfYfRfGfYOIxic",
    "LIOsfsfsfsfsfsOIIic",
    "LIOOOOOOOOOOOOOIIic",
    "ciiiiiiiiiiiiiiiicc",
    ".BBB..........BBB..",
]
# J glass rim / j rim shade / W shine | a glass inside | F leaf / e leaf shade | d soil
VAULT_DOME = [                # cols 21..29, rows 4..15
    "...JJj...",
    "..JWaaj..",
    ".JWaFaaj.",
    ".JWFFaFj.",
    ".JaFeFFj.",
    ".JaaFaaj.",
    ".JddFddj.",
    "TTTTTTTTt",
    "LIIIIIIic",
    "LIgIIIiic",
    "ciiiiiicc",
    ".BB...BB.",
]


def vault():
    art = over(over(BLANK, VAULT_CASE, 1, 4), VAULT_DOME, 21, 4)
    im = new(32, 16)
    paint(im, art, dict(STEEL, G="#1ebc73", Y="#f9c22b", R="#e83b3b", V="#8fd3ff", s="#fbb954", f="#323353",
                        k="#484a77", g="#91db69", b="#4d9be6", x="#8fd3ff", J="#8fd3ff", j="#4d9be6", W="#ffffff",
                        a="#165a4c", F="#91db69", e="#1ebc73", d="#4c3e24"))
    autoline(im)
    return im


# ---- water recycler: glass tank (water, bubbles), two pipes, filter unit with a drop display, tap with a drop ----
# V water / v water shade / w surface / x bubble | a air in the tank | P pipe / p pipe shade
# n screen / D drop | g green LED | y amber LED | k vent | Q tap / q tap shade
RECYCLER_TANK = [             # cols 1..9, rows 2..15
    ".TTTTTTt.",
    "LIIIIIIic",
    "JWaaaaaaj",
    "JWaaaaxaj",
    "JWwwwwwwj",
    "JWVVVxVvj",
    "JWVVVVVvj",
    "JWVxVVVvj",
    "JWVVVVvvj",
    "JWVVVVvvj",
    "LIIIIIIic",
    "LIgIIIiic",
    "ciiiiiicc",
    ".BB...BB.",
]
RECYCLER_PIPES = [            # cols 10..12, rows 5..12
    "PPP",
    "ppp",
    "...",
    "...",
    "...",
    "...",
    "PPP",
    "ppp",
]
RECYCLER_UNIT = [             # cols 13..29 (tap), rows 4..15
    "TTTTTTTTTTTTTTTt",
    "LIIIIIIIIIIIIIic",
    "LIOOOOOOOIIIIIic",
    "LIOnnDnnOIgIyIic",
    "LIOnDDDnOIIIIIic",
    "LIOnWDdnOIIIIIiQQ",
    "LIOnnddnOIIIIIiqQ",
    "LIOOOOOOOIIIIIic.",
    "LIkkkkkkkkkkkIic.",
    "LIIIIIIIIIIIIIic.",
    "cciiiiiiiiiiiiic.",
    ".BBB.......BBB...",
]
TAP_DROP = ["D", "d"]         # col 29, rows 12..13: a drop falling from the tap


def recycler():
    art = over(over(over(BLANK, RECYCLER_TANK, 1, 2), RECYCLER_PIPES, 10, 5), RECYCLER_UNIT, 13, 4)
    art = over(art, TAP_DROP, 29, 12)
    im = new(32, 16)
    paint(im, art, dict(STEEL, J="#8fd3ff", j="#4d9be6", W="#ffffff", a="#323353", V="#4d9be6", v="#4d65b4",
                        w="#8fd3ff", x="#ffffff", P="#c7dcd0", p="#7f708a", n="#0b5e65", D="#8fd3ff", d="#4d9be6",
                        g="#1ebc73", y="#f9c22b", k="#625565", Q="#c7dcd0", q="#7f708a"))
    autoline(im)
    return im


def build():
    export(vault(), "item_vault.png")
    export(recycler(), "item_recycler.png")


if __name__ == "__main__":
    build()
