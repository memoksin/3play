"""12 people of the 3026 solar flare, 16x16 logical, exported 4x (64x64). Fit shows them at 32 px, so 1 logical px = 2 screen px.
Same method as tools/sprites/kahramanmaras/people.py: one body per age class (ADULT / ELDER / CHILD); a person = head rows
+ class body + props, coloured by a palette of named slots. Fill only, then `autoline` adds the 1 px dark silhouette outline.
Light from the upper left: light column on the left edge, shade + dark on the right and below.
3026 look: everyone wears a suit with a glowing tech collar (Q) in a role colour; the head (helmet, visor, hat, hair)
and one prop carry the role."""
from pix import new, paint, over, autoline, export, LINE

# Slot letters: S skin s skin shade r blush | H hair h hair shade | A hat/helmet a shade W light/shine
# V visor/lens v visor shade | Q collar glow q collar shade | L suit light C suit c suit shade D suit dark (arm gaps)
# I dark-hair shine | G gloves/hands | E belt e belt shade | P trousers p trousers shade | B boots | K prop k prop shade | O line
BASE = dict(O=LINE, S="#fdcbb0", s="#fca790", r="#f68181", B="#3e3546", P="#484a77", p="#323353",
            W="#ffffff", E="#3e3546", e="#2e222f", G="#c7dcd0", V="#8fd3ff", v="#4d9be6", I="#625565")

# ---- class bodies (rows below the head) -----------------------------------------------------------
ADULT = [                     # rows 8..15: suit, sleeves split by a dark fold, belt
    "..LCCCCCCCCCcc..",
    "..LDCCCCCCCcDc..",
    "..LDCCCCCCCcDc..",
    "..GDLCCCCCCcDG..",
    "...LEEEEEEeee...",
    "....PPp..PPp....",
    "....BBB..BBB....",
    "................",
]
ELDER = [                     # rows 9..15: long robe to the ankles, slight stoop
    "..LCCCCCCCcc....",
    "..LDCCCCCcDc....",
    "..LDCCCCCcDcG...",
    "..LCCCCCCCcc....",
    "..LCCCCCCCccc...",
    "...LCCCCCCcc....",
    "....BB..BBB.....",
]
CHILD = [                     # rows 9..15: short suit
    "...LCCCCCCcc....",
    "...LDCCCCcDc....",
    "...GDCCCCcDG....",
    "....LEEEEee.....",
    "....PPp.PPp.....",
    "....BBB.BBB.....",
    "................",
]
COLLAR = "...QQQQQQQQqq..."
KID_COLLAR = "....QQQQQQqq...."


def rows(head, body, top=0):
    out = ["." * 16] * top + head + body
    return (out + ["." * 16] * 16)[:16]


# ---- the twelve -------------------------------------------------------------------------------------
def amara():                  # doctor: high bun, white coat open over a teal suit, stethoscope, red cross badge
    head = ["......IHh.......",
            ".....HIHHHh.....",
            "....HIHHHHHh....",
            "....HSSSSSSh....",
            "....SSOSSOSs....",
            "....SSSSSSSs....",
            ".....SSSSss.....",
            "...LCKYYKCCc...."]
    art = rows(head, ADULT)
    art = over(art, ["..LCCKYYKCCCcc..",                                  # coat open over a teal shirt, stethoscope
                     "..LDXKYYKCCcDc..",                                 # red cross badge on the coat
                     "..LDCCYYCkCcDc..",
                     "..GDLCYYCCCcDG..",
                     "...LCCYYCCccc..."], 0, 8)
    return art, dict(
        S="#cd683d", s="#9e4539", H="#4c3e24", h="#2e222f", I="#694f62", L="#ffffff", C="#c7dcd0", c="#9babb2", D="#7f708a",
        Q="#ffffff", q="#c7dcd0", Y="#0eaf9b", G="#c7dcd0", K="#484a77", k="#7f708a", X="#e83b3b", P="#0b8a8f", p="#0b5e65", B="#3e3546")


def kenji():                  # engineer: yellow hard helmet with a headlamp, orange suit, hi-vis stripe, tool belt
    head = ["................",
            ".....AAAAAa.....",
            "....AWAYYAAa....",
            "...aaaaaaaaaa...",
            "....HSOSSOSH....",
            "....SSSSSSSs....",
            ".....SSSSss.....",
            COLLAR]
    art = rows(head, ADULT)
    art = over(art, ["..LTTTTTTTTtc.."], 0, 10)                           # reflective stripe
    art = over(art, ["KkEEgEEKk"], 3, 12)                                 # tools in the belt, buckle
    return art, dict(
        A="#f9c22b", a="#f79617", W="#fbff86", Y="#ffffff", H="#2e222f", Q="#fbff86", q="#f9c22b",
        L="#fbb954", C="#f79617", c="#cd683d", D="#9e4539", T="#c7dcd0", t="#9babb2", G="#3e3546",
        E="#4c3e24", e="#2e222f", g="#f9c22b", K="#9babb2", k="#7f708a", P="#9e4539", p="#7a3045", B="#3e3546")


def lia():                    # child 7: pigtails with glowing ties, pink suit, star patch
    head = ["................",
            "................",
            ".....HHHHHh.....",
            "....HHHHHHHh....",
            "..RHHSSSSSShHR..",
            "..HhSSOSSOSsHh..",
            "..HhSrSSSSrsHh..",
            "..h..SSSSss..h..",
            KID_COLLAR]
    art = rows(head, CHILD)
    art = over(art, ["Y"], 5, 10)
    return art, dict(
        H="#cd683d", h="#9e4539", R="#30e1b9", Q="#30e1b9", q="#0eaf9b", L="#f68181", C="#ed8099", c="#cf657f",
        D="#a24b6f", G="#fdcbb0", Y="#fbff86", E="#a24b6f", e="#753c54", P="#484a77", p="#323353", B="#4d65b4")


def tomas():                  # farmer: wide straw hat, olive overalls over a cream shirt, wheat sprig
    head = ["................",
            "......AAAa......",
            ".....nnnnnn.....",
            "..aAAAAAAAAAaa..",
            "....HSOSSOSH....",
            "....SSSSSSSs....",
            ".....SSSSss.....",
            COLLAR]
    art = rows(head, ADULT)
    art = over(art, ["..YDYYYYYYYyDy..", "..YDCCCCCCCcDy..", "..GDLCCCCCCcDG..", "...LCCCCCCccc..."], 0, 9)
    art = over(art, ["Kk", "K.", "Kk", "K.", "K.", "K."], 13, 6)          # wheat sprig in the right hand
    return art, dict(
        S="#e6904e", s="#cd683d", A="#fbb954", a="#cd683d", n="#9e4539", H="#4c3e24", Q="#91db69", q="#239063",
        L="#a2a947", C="#676633", c="#4c3e24", D="#4c3e24", Y="#b2ba90", y="#92a984", G="#e6904e",
        K="#f9c22b", k="#e6904e", P="#676633", p="#4c3e24", B="#4c3e24")


def noor():                   # elder: white bun, gold glasses, long violet robe, cane with a glowing grip
    head = ["......HHh.......",
            ".....HHHHHh.....",
            "....HHHHHHHh....",
            "....HSSSSSSh....",
            "....gOgSgOgh....",
            "....SSSSSSSs....",
            ".....SSSSss.....",
            COLLAR]
    art = rows(head, ELDER, 1)
    art = over(art, ["Q", "K", "K", "K", "K", "K", "K"], 12, 9)
    art = over(art, ["Q", "Q", "Q", "Q", "Q", "q"], 6, 9)                 # glowing trim down the robe
    return art, dict(
        S="#fca790", s="#f68181", H="#ffffff", h="#c7dcd0", g="#f9c22b", Q="#f04f78", q="#c32454",
        L="#a884f3", C="#905ea9", c="#6b3e75", D="#45293f", G="#e6904e", K="#9babb2", B="#45293f")


def ravi():                   # pilot: white helmet, blue visor, navy flight suit with gold wings
    head = ["................",
            ".....AAAAAa.....",
            "....AWAAAAAa....",
            "...AAVVVVVVaa...",
            "...AaVWVVvvaa...",
            "...AaSSSSSsaa...",
            "....aSSSSSsa....",
            COLLAR]
    art = rows(head, ADULT)
    art = over(art, ["YyY"], 4, 9)                                        # wings badge
    art = over(art, ["Z"], 10, 9)
    return art, dict(
        S="#e6904e", s="#cd683d", A="#ffffff", a="#9babb2", W="#ffffff", V="#8fd3ff", v="#4d9be6",
        Q="#f9c22b", q="#f79617", L="#4d9be6", C="#4d65b4", c="#484a77", D="#323353", G="#ffffff",
        Y="#f9c22b", y="#f79617", Z="#e83b3b", E="#c7dcd0", e="#9babb2", P="#484a77", p="#323353", B="#2e222f")


def okafor():                 # teacher: big afro, violet cardigan, glowing tablet held at the chest
    head = [".....HHHHHh.....",
            "...HIIHHHHHhh...",
            "..HIHHHHHHHHhh..",
            "..HHHSSSSSShhh..",
            "..HHSSOSSOSshh..",
            "..HhSSSSSSSshh..",
            "...h.SSSSss.h...",
            COLLAR]
    art = rows(head, ADULT)
    art = over(art, ["kkkkk", "kVVvk", "kVvvk", "GkkkG"], 3, 9)           # tablet
    return art, dict(
        S="#9e4539", s="#6e2727", H="#4c3e24", h="#2e222f", I="#694f62", Q="#8ff8e2", q="#30e1b9",
        L="#a884f3", C="#905ea9", c="#6b3e75", D="#45293f", G="#9e4539", k="#2e222f", V="#8ff8e2", v="#30e1b9",
        E="#6b3e75", e="#45293f", P="#45293f", p="#2e222f", B="#3e3546")


def sol():                    # child 10: spiky hair, goggles on the forehead, teal suit with a sun patch
    head = ["................",
            "....H.HH.HH.....",
            "....HIIHHHHh....",
            "....kVWkkVWk....",
            "....SSSSSSSs....",
            "....SSOSSOSs....",
            "....SrSSSSrs....",
            ".....SSSSss.....",
            KID_COLLAR]
    art = rows(head, CHILD)
    art = over(art, ["Y"], 5, 10)
    return art, dict(
        S="#cd683d", s="#9e4539", r="#9e4539", H="#3e3546", h="#2e222f", k="#2e222f", V="#8fd3ff",
        Q="#f9c22b", q="#f79617", L="#30e1b9", C="#0eaf9b", c="#0b8a8f", D="#0b5e65", G="#cd683d", Y="#f9c22b",
        E="#0b5e65", e="#165a4c", P="#323353", p="#2e222f", B="#e83b3b")


def yuki():                   # botanist: black bob with a leaf clip, mint suit, sprout in a pot
    head = ["................",
            ".....HHHHHh.....",
            "....HIIHHHFh....",
            "...HIHHHHHHhh...",
            "...HHSOSSOShh...",
            "...HHrSSSSrhh...",
            "...HhSSSSSshh...",
            COLLAR]
    art = rows(head, ADULT)
    art = over(art, ["..F.", ".FfF", "..f.", ".KKk", ".KKk", "GkkG"], 3, 8)   # sprout in a clay pot
    return art, dict(
        H="#3e3546", h="#2e222f", F="#91db69", f="#1ebc73", Q="#91db69", q="#1ebc73",
        L="#8ff8e2", C="#30e1b9", c="#0eaf9b", D="#0b8a8f", G="#fdcbb0", K="#cd683d", k="#9e4539",
        E="#0b5e65", e="#165a4c", P="#165a4c", p="#2e222f", B="#3e3546")


def dmitri():                 # technician: blond crop, full beard, AR monocle, steel suit, hazard belt, wrench
    head = ["................",
            ".....HHHHHh.....",
            "....HHHHHHHh....",
            "....HSSSSSSh....",
            "....kVVSSOSs....",
            "....HSSSSSSh....",
            ".....HHHHhh.....",
            COLLAR]
    art = rows(head, ADULT)
    art = over(art, ["YeYeYeYe"], 4, 12)
    art = over(art, ["K.K", "KKK", ".K.", ".K.", ".j."], 12, 8)            # wrench in the right hand
    return art, dict(
        S="#fdcbb0", s="#fca790", H="#cd683d", h="#9e4539", k="#2e222f", V="#e83b3b", Q="#f9c22b", q="#f79617",
        L="#9babb2", C="#7f708a", c="#625565", D="#3e3546", G="#3e3546", Y="#f9c22b", e="#2e222f",
        K="#c7dcd0", j="#9babb2", P="#3e3546", p="#2e222f", B="#2e222f")


def ines():                   # midwife: pink scrub cap, auburn ponytail, rose scrubs, a newborn in her arms
    head = ["................",
            ".....AAAAAa.....",
            "....AWAWAAAa....",
            "....AAAAAAAaHh..",
            "....HSOSSOSHHh..",
            "....SSSSSSSs.h..",
            ".....SSSSss.....",
            COLLAR]
    art = rows(head, ADULT)
    art = over(art, ["...NNNn", "..GNbbnG", "...nnnn"], 3, 9)                # swaddled baby
    return art, dict(
        S="#fca790", s="#f68181", A="#f04f78", a="#c32454", W="#f68181", H="#b33831", h="#6e2727",
        Q="#ffffff", q="#c7dcd0", L="#ed8099", C="#cf657f", c="#a24b6f", D="#753c54", G="#fca790",
        N="#ffffff", n="#c7dcd0", b="#fdcbb0", E="#a24b6f", e="#753c54", P="#a24b6f", p="#753c54", B="#45293f")


def ben():                    # cook: tall toque, white double-breasted jacket, red neckerchief, apron, ladle
    head = [".....WWWWWw.....",
            "....WWWWWWWw....",
            "....WWWWWWww....",
            ".....TTTTTt.....",
            "....HSOSSOSH....",
            "....SSSSSSSs....",
            ".....SSSSss.....",
            COLLAR]
    art = rows(head, ADULT)
    art = over(art, ["..LCKCCKCCCcc..", "..LDCCCCCCCcDc..", "..LDKCCKCCCcDc.."], 0, 8)
    art = over(art, ["...ZZZZZZzzz...", "....ZZz..ZZz...."], 0, 12)            # apron
    art = over(art, ["U", "U", "U", "U", "uu"], 13, 7)                      # ladle
    return art, dict(
        S="#fdcbb0", s="#fca790", H="#694f62", W="#ffffff", w="#c7dcd0", T="#9babb2", t="#7f708a", Q="#e83b3b", q="#ae2334",
        L="#ffffff", C="#c7dcd0", c="#9babb2", D="#7f708a", K="#7f708a", G="#fdcbb0",
        Z="#f57d4a", z="#cd683d", U="#9babb2", u="#c7dcd0", P="#3e3546", p="#2e222f", B="#2e222f")


PEOPLE = dict(amara=amara, kenji=kenji, lia=lia, tomas=tomas, noor=noor, ravi=ravi,
              okafor=okafor, sol=sol, yuki=yuki, dmitri=dmitri, ines=ines, ben=ben)


def draw(fn):
    art, pal = fn()
    assert len(art) == 16 and all(len(r) == 16 for r in art), fn.__name__
    im = new(16, 16)
    paint(im, art, {**BASE, **pal})
    autoline(im)
    return im


def build():
    for name, fn in PEOPLE.items():
        export(draw(fn), "person_%s.png" % name)


if __name__ == "__main__":
    build()
