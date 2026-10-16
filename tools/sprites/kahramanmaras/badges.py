"""Warm (flame) and cold (snowflake) badges, 8x8 logical, exported 4x (32x32). Shown at 32 px on the orange /
blue zone badge, so 1 logical px = 4 screen px, the scene grid. Flame: dark outline like the people;
snowflake: dark drop shadow."""
from pix import new, paint, autoline, export, LINE

FLAME = [
    "........",
    "...Y....",
    "...YY...",
    "..YYMY..",
    ".YYMMYY.",
    ".YMCCMY.",
    "..MCCM..",
    "........",
]
SNOW = [                      # 7x7 flake; a dark drop shadow (lower right) instead of an outline keeps the arms thin
    "...W....",
    ".H.W.H..",
    "..WWW...",
    "WWWHWWW.",
    "..WWW...",
    ".H.W.H..",
    "...W....",
    "........",
]


def shadowed(im, art, pal, col):
    paint(im, [r.replace("W", "x").replace("H", "x") for r in art], dict(x=col), 1, 1)
    paint(im, art, pal)


def build():
    im = new(8, 8)
    paint(im, FLAME, dict(Y="#fb6b1d", M="#f9c22b", C="#fbff86"))
    autoline(im, LINE)
    export(im, "warm_icon.png")
    im = new(8, 8)
    shadowed(im, SNOW, dict(W="#ffffff", H="#8fd3ff"), "#323353")
    export(im, "cold_icon.png")


if __name__ == "__main__":
    build()
