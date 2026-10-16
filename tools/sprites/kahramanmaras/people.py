"""8 winter people, 16x16 logical, exported 4x (64x64). Fit shows them at 32 px, so 1 logical px = 2 screen px.
One body per age class (ADULT / ELDER / TEEN / CHILD, plus the baby bundle); a person = head rows + class body + props,
coloured by a palette of named slots. Fill only, then `autoline` adds the 1 px dark silhouette outline.
Light from the upper left: light column on the left edge, shade + cool violet-blue dark on the right and below."""
from pix import new, paint, over, autoline, export, LINE

# Slot letters: S skin s skin shade r blush | H hair h hair shade | A hat a hat shade W hat light / pompom
# T fur trim | F scarf f scarf shade | L coat light C coat c coat shade D coat dark (folds, arm gaps)
# G mittens | Y sweater y sweater shade | P trousers p trousers shade | B boots | K stick k stick shade | O line
BASE = dict(O=LINE, S="#fdcbb0", s="#fca790", r="#f68181", B="#3e3546", P="#484a77", p="#323353",
            W="#ffffff", T="#c7dcd0", K="#cd683d", k="#9e4539", Y="#c7dcd0", y="#9babb2")

# ---- class bodies (rows below the head) -----------------------------------------------------------
ADULT = [                     # rows 7..15: puffy winter coat, sleeves split by a dark fold
    "..LCCFfCCCCCcc..",
    "..LDCFfCCCCcDc..",
    "..LDCCCCCCCcDc..",
    "..GDLCCCCCCcDG..",
    "...LCCCCCCccc...",
    "....PPp..PPp....",
    "....BBB..BBB....",
    "................",
]
ELDER = [                     # rows 8..15: long coat to the ankles, slight stoop
    "..LCCCCCCCcc....",
    "..LDCCCCCcDc....",
    ".GLDCCCCCcDc....",
    "..LCCCCCCCcc....",
    "..LCCCCCCCccc...",
    "...LCCCCCCcc....",
    "....BB..BBB.....",
    "................",
]
TEEN = [                      # rows 8..15: slimmer coat, longer legs
    "...LCFfCCCcc....",
    "...LDFfCCcDc....",
    "...GDCCCCcDG....",
    "....LCCCCcc.....",
    "....PPp.PPp.....",
    "....PPp.PPp.....",
    "....BBB.BBB.....",
    "................",
]
CHILD = [                     # rows 10..15: short puffy coat
    "...LCCCCCCcc....",
    "...LDCCCCcDc....",
    "...GDCCCCcDG....",
    "....LCCCCcc.....",
    "....BBB.BBB.....",
    "................",
]

# ---- heads (rows from the top) --------------------------------------------------------------------
HEAD_MAN = [                  # short hair, moustache
    "................",
    ".....HHHHHH.....",
    "....HHHHHHHh....",
    "....HhSSSSSh....",
    "....SSOSSOSs....",
    "....SSHHHHSs....",
    ".....SSSSss.....",
    "...FFFFFFFFff...",
]
HEAD_HOOD = [                 # parka hood with fur trim
    ".....LCCCCc.....",
    "....LCTTTTCc....",
    "...LCTHHHHTCc...",
    "...CTHSSSShTc...",
    "...CTSOSSOsTc...",
    "...CTrSSSSrTc...",
    "...cCTSSSsTCc...",
    "...FFTTTTTTff...",
]
HEAD_CAP = [                  # flat cap, grey moustache
    "................",
    ".....AAAAAa.....",
    "....AWAAAAAa....",
    "...aaaaaaaaaa...",
    "....HSOSSOSH....",
    "....SSHHHHSs....",
    ".....SSSSss.....",
    "...FFFFFFFFff...",
]
HEAD_SCARF_OLD = [            # headscarf, grey fringe, tied under the chin (head one row lower: stoop)
    "................",
    ".....AAAAAa.....",
    "....AWAAAAAa....",
    "...AAHHHHHHaa...",
    "...AaSOSSOSaa...",
    "...AaSSSSSsaa...",
    "...AarSssSraa...",
    "....AaaSSsaa....",
]
HEAD_SCARF = [                # headscarf, young face
    "................",
    ".....AAAAAa.....",
    "....AWAAAAAa....",
    "...AAHHHHHHaa...",
    "...AaSOSSOSaa...",
    "...AarSSSSraa...",
    "...AaSSSSSsaa...",
    "....AaaSSsaa....",
]
HEAD_TEEN = [                 # beanie, long hair falling to the shoulders
    "................",
    ".....AAAAAa.....",
    "....AWAAAAAa....",
    "...aaaaaaaaaa...",
    "...HHSOSSOSHh...",
    "...HHrSSSSrHh...",
    "...HHSSSSSsHh...",
    "...HHFFFFffHh...",
]
HEAD_KID = [                  # beanie with pompom
    ".......WW.......",
    "......WWWW......",
    ".....AAAAAa.....",
    "....AWAAAAAa....",
    "....aaaaaaaa....",
    "....SSOSSOSs....",
    "....SrSSSSrs....",
    ".....SSSSss.....",
    "....FFFFFFff....",
    "....Ff..........",
]


def rows(head, body, top=0):
    out = ["." * 16] * top + head + body
    return (out + ["." * 16] * 16)[:16]


# ---- the eight -------------------------------------------------------------------------------------
def mehmet():
    art = over(rows(HEAD_MAN, ADULT), ["cccccc"], 5, 11)                 # puffer quilting seam
    return art, dict(
        H="#4c3e24", h="#2e222f", L="#4d9be6", C="#4d65b4", c="#484a77", D="#323353",
        F="#e83b3b", f="#b33831", G="#3e3546", P="#3e3546", p="#2e222f", B="#2e222f")


def zeynep():
    art = rows(HEAD_HOOD, ADULT)
    art = over(art, ["..LCCTTCCCCcc..", "..LDCCCCCCcDc.."], 1, 7)   # zipped parka, fur collar instead of a scarf
    return art, dict(
        H="#7a3045", h="#45293f", L="#ea4f36", C="#b33831", c="#831c5d", D="#45293f",
        F="#c7dcd0", f="#9babb2", T="#c7dcd0", G="#c7dcd0", P="#323353", p="#2e222f", B="#45293f")


def hasan():
    art = rows(HEAD_CAP, ADULT)
    art = over(art, ["..........K", "..........K", ".........kK", "..........K", "..........K",
                     "..........K", "..........K", "..........K"], 4, 7)   # crutch under the right arm
    art = over(art, ["YYy"], 9, 13)                                       # knee brace on the bad knee
    return art, dict(
        A="#7f708a", a="#625565", W="#9babb2", H="#c7dcd0", L="#ab947a", C="#966c6c", c="#694f62", D="#45293f",
        F="#547e64", f="#374e4a", G="#694f62", P="#3e3546", p="#2e222f", B="#2e222f",
        K="#c7dcd0", k="#9babb2", Y="#c7dcd0", y="#9babb2")


def ayse():
    art = rows(HEAD_SCARF_OLD, ELDER, 1)
    art = over(art, ["K", "K", "K", "K", "K", "K", "K"], 1, 9)             # wooden cane in her right hand
    art = over(art, ["kK", ".G"], 0, 9)
    art = over(art, ["Kk"], 0, 8)
    art = over(art, ["D", ".", "D"], 7, 10)                               # coat buttons
    return art, dict(
        A="#a884f3", a="#905ea9", W="#eaaded", H="#c7dcd0", L="#9babb2", C="#7f708a", c="#625565", D="#3e3546",
        G="#905ea9", B="#45293f", K="#cd683d", k="#9e4539")


def fatma():
    art = rows(HEAD_SCARF, ADULT)
    art = over(art, ["..LCaAAAAaCcc...",                                   # scarf ends over the shoulders
                     "..LDCYWYYyCcDc..",                                   # open coat, round belly
                     "..LDYWYYYYyCDc..",
                     "..GDYYYYYyycDG..",
                     "...LCSyyySScc..."], 0, 8)                            # hands cradling it
    return art, dict(
        A="#1ebc73", a="#239063", W="#91db69", H="#4c3e24", L="#0eaf9b", C="#0b8a8f", c="#0b5e65", D="#323353",
        Y="#fbb954", y="#e6904e", G="#fca790", P="#323353", p="#2e222f", B="#3e3546")


def selin():
    return rows(HEAD_TEEN, TEEN), dict(
        A="#0eaf9b", a="#0b8a8f", W="#8ff8e2", H="#3e3546", h="#2e222f", L="#ed8099", C="#cf657f", c="#a24b6f",
        D="#753c54", F="#f9c22b", f="#f79617", G="#f9c22b", P="#323353", p="#2e222f", B="#3e3546")


def can():
    return rows(HEAD_KID, CHILD), dict(
        A="#1ebc73", a="#239063", W="#ffffff", L="#fbff86", C="#f9c22b", c="#f79617", D="#cd683d",
        F="#4d9be6", f="#4d65b4", G="#4d9be6", B="#484a77")


ELIF = [                      # swaddled baby ("kundak"): knit hat with pompom, lace frame, ribbon round the bundle
    "................",
    ".......WW.......",
    "......AAAa......",
    ".....AWAAAa.....",
    "....LTaaaaTc....",
    "...LCTSSSsTCc...",
    "...LCSOSSOsCc...",
    "...LCrSSSSrCc...",
    "...LCTSSSsTCc...",
    "...LCCTTTTCCc...",
    "...LCCCCCCCCc...",
    "...RRRRQRRRRQ...",
    "....LCCCCCCcc...",
    "....LCCCCCccD...",
    ".....cCCCcDD....",
    "................",
]


def elif_():
    return ELIF, dict(A="#8fd3ff", a="#4d9be6", W="#ffffff", T="#ffffff", L="#f68181", C="#cf657f", c="#a24b6f",
                      D="#753c54", R="#f9c22b", Q="#f79617")


PEOPLE = dict(ayse=ayse, can=can, elif_=elif_, fatma=fatma, hasan=hasan, mehmet=mehmet, selin=selin, zeynep=zeynep)


def draw(fn):
    art, pal = fn()
    im = new(16, 16)
    paint(im, art, {**BASE, **pal})
    autoline(im)
    return im


def build():
    for name, fn in PEOPLE.items():
        export(draw(fn), "person_%s.png" % name.rstrip("_"))


if __name__ == "__main__":
    build()
