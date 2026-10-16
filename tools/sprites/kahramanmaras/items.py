"""Fit items, same grid as the people (1 logical px = 4 px in the file, 2 px on screen):
stove 32x16 logical (128x64, a 2-slot item), blanket / water / medicine 16x16 logical (64x64).
Fill only, then `autoline` adds the 1 px dark outline. Light from the upper left; the stove fire is the only
warm light and it warms the log ends next to it."""
from pix import new, paint, autoline, export

# ---- stove: Turkish iron "soba" with a double teapot (caydanlik) on top and a stack of logs -------------------
# Q pipe / q pipe shade | M teapot steel / m shade / W shine / n lid knob | T top plate chrome / t shade
# L iron light / I iron / i iron shade / c iron dark | O window frame | 1..4 fire dark->core | g handle | B feet
# b bark / R ring lit by the fire / r ring / e ring core
STOVE = [
    ".......n......Qq................",
    "......MWm.....Qq................",
    ".....MMMMm....Qq................",
    "....zzzzzzz...Qq................",
    "...MWMMMMMMm..Qq................",
    ".mMMWMMMMMMm.QQqq...............",
    "..mMMMMMMMmm.QQqq...............",
    ".TTTTTTTTTTTTTTTTTt......RRkkkk.",
    "..LIIIIIIIIIIIIIIic......Rebbkb.",
    "..LIOOOOOOOOOIIiIic......RRdddd.",
    "..LIO1111111OIgIiic....RRkkkkkk.",
    "..LIO1122111OIgiIic....Rebkbbbb.",
    "..LIO1233221OIgIiic....RRdddddd.",
    "..LIO2344332OIIIiic..RRkkkkkkkk.",
    "..ciccccccccccccccc..Rebbbbkbbb.",
    "...BBB.........BBB...RRdddddddd.",
]


def stove():
    im = new(32, 16)                     # the pipe keeps going up off the top edge
    paint(im, STOVE, dict(
        Q="#9babb2", q="#625565", M="#c7dcd0", m="#9babb2", W="#ffffff", n="#2e222f", z="#7f708a",
        T="#c7dcd0", t="#9babb2", L="#7f708a", I="#625565", i="#3e3546", c="#45293f",
        O="#2e222f", g="#f9c22b", B="#2e222f",
        **{"1": "#7a3045", "2": "#fb6b1d", "3": "#f9c22b", "4": "#fbff86"},
        k="#966c6c", b="#694f62", d="#45293f", R="#fbb954", e="#e6904e"))
    autoline(im)
    return im


# ---- blanket: two folded wool blankets, purple tartan on top of red ----------------------------------
BLANKET = [
    "................",
    "................",
    "................",
    "...LLLLLLLLLLl..",
    "..LCCXCCCCXCCCf.",
    "..LXXXXXXXXXXXc.",
    "..LCCXCCCCXCCCf.",
    "..LCCXCCCCXCCcc.",
    "..lcccccccccccc.",
    ".HHHHHHHHHHHHHh.",
    ".HRRYRRRRRYRRRrF",
    ".HYYYYYYYYYYYYrF",
    ".HRRYRRRRRYRRrrF",
    ".HRRYRRRRRYRRrr.",
    "..rrrrrrrrrrrr..",
    "................",
]


def blanket():
    im = new(16, 16)
    paint(im, BLANKET, dict(L="#a884f3", l="#905ea9", C="#905ea9", c="#6b3e75", X="#eaaded", f="#eaaded",
                            H="#ea4f36", h="#b33831", R="#b33831", r="#6e2727", Y="#fbb954", F="#fbb954"))
    autoline(im)
    return im


# ---- water: a 5 l bottle with a carry handle -----------------------------
WATER = [
    "................",
    "......NNNN......",
    "......nnnn......",
    "......HPPhkkk...",
    ".....HPPPPh.k...",
    "....HWPPPPPhk...",
    "...HWPPPPPPPh...",
    "...HWPPPPPPPh...",
    "...HAAAAAAAah...",
    "...HAaVVVVaah...",
    "...HAAAAAAAah...",
    "...HWBBBBBBBh...",
    "...HWBBBBBBbh...",
    "...HBBBBBBbbh...",
    "....hhhhhhhh....",
    "................",
]


def water():
    im = new(16, 16)
    paint(im, WATER, dict(N="#4d65b4", n="#484a77", H="#8fd3ff", h="#4d9be6", P="#8fd3ff", W="#ffffff",
                          B="#4d9be6", b="#4d65b4", A="#ffffff", a="#c7dcd0", V="#4d9be6", k="#c7dcd0"))
    autoline(im)
    return im


# ---- medicine: red first-aid bag, white cross, zip and handle ----------------------------------------
MEDICINE = [
    "................",
    "................",
    "................",
    ".....GGGGGG.....",
    ".....G....G.....",
    "..LLLLLLLLLLLl..",
    "..ZZZZZZZZZZZZ..",
    "..LCCCCWWCCCCc..",
    "..LCCCCWWCCCCc..",
    "..LCCWWWWWWwCc..",
    "..LCCWWWWWWwCc..",
    "..LCCCCWWwCCCc..",
    "..LCCCCWwwCCCc..",
    "..LCCCCCCCCCcc..",
    "..cccccccccccc..",
    "................",
]


def medicine():
    im = new(16, 16)
    paint(im, MEDICINE, dict(G="#625565", L="#f68181", l="#e83b3b", Z="#ae2334", C="#e83b3b", c="#ae2334",
                             W="#ffffff", w="#c7dcd0"))
    autoline(im)
    return im


def build():
    export(stove(), "item_stove.png")
    for name, fn in (("blanket", blanket), ("water", water), ("medicine", medicine)):
        export(fn(), "item_%s.png" % name)


if __name__ == "__main__":
    build()
