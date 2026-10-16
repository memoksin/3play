"""8 winter people, 32x32 logical, exported 2x (64x64). One geometry (person) + one palette/params entry per person."""
import os
from common import Canvas, rbox, export, ART, LINE

BASE = dict(line=LINE, skin="#fdcbb0", skin_sh="#fca790", eye="#2e222f", mouth="#9e4539",
            hair="#4c3e24", hat="#c7dcd0", hat_hi="#ffffff", band="#9babb2", pom="#ffffff",
            scarf="#9babb2", scarf_sh="#7f708a", coat="#625565", coat_hi="#7f708a", coat_sh="#3e3546",
            pants="#3e3546", boots="#2e222f", glove="#625565", stache=None, blanket_sh="#ed8099")
# geometry keys: top (head top y), hw/hh (head size), bw (body width), hat style, hairstyle, tail (scarf tail side)
PEOPLE = {
    "ayse": dict(p=dict(scarf="#a884f3", scarf_sh="#905ea9", hair="#c7dcd0", coat="#7f708a", coat_hi="#9babb2", coat_sh="#625565",
                        pants="#484a77", glove="#905ea9"),
                 g=dict(top=7, hw=10, hh=9, bw=15, hat="headscarf", neck="#905ea9", tail=0)),
    "mehmet": dict(p=dict(hair="#2e222f", coat="#4d65b4", coat_hi="#4d9be6", coat_sh="#484a77", pants="#323353",
                          scarf="#b33831", scarf_sh="#6e2727", stache="#2e222f", glove="#3e3546"),
                   g=dict(top=4, hw=10, hh=9, bw=18, hat="none", hair="short", tail=-1)),
    "zeynep": dict(p=dict(hair="#9e4539", hat="#c7dcd0", band="#9babb2", coat="#b33831", coat_hi="#ea4f36", coat_sh="#831c5d",
                          scarf="#c7dcd0", scarf_sh="#9babb2", pants="#3e3546", glove="#c7dcd0"),
                   g=dict(top=5, hw=10, hh=9, bw=16, hat="beanie", hair="long", tail=1)),
    "can": dict(p=dict(hat="#1ebc73", hat_hi="#91db69", band="#239063", pom="#fbff86", coat="#f9c22b", coat_hi="#fbff86",
                       coat_sh="#f79617", scarf="#4d9be6", scarf_sh="#4d65b4", pants="#484a77", glove="#4d9be6"),
                g=dict(top=10, hw=9, hh=8, bw=12, hat="beanie", hair="short", tail=1, pompom=1)),
    "selin": dict(p=dict(hair="#7a3045", hat="#4d9be6", hat_hi="#8fd3ff", band="#4d65b4", coat="#cf657f", coat_hi="#ed8099",
                         coat_sh="#a24b6f", scarf="#f9c22b", scarf_sh="#f79617", pants="#323353", glove="#f9c22b"),
                  g=dict(top=7, hw=9, hh=9, bw=14, hat="beanie", hair="long", tail=-1)),
    "hasan": dict(p=dict(hair="#c7dcd0", hat="#625565", hat_hi="#7f708a", band="#3e3546", coat="#966c6c", coat_hi="#ab947a",
                         coat_sh="#694f62", scarf="#547e64", scarf_sh="#374e4a", pants="#3e3546", stache="#c7dcd0", glove="#694f62"),
                  g=dict(top=6, hw=10, hh=9, bw=16, hat="cap", hair="short", tail=1)),
    "fatma": dict(p=dict(scarf="#239063", scarf_sh="#165a4c", hair="#4c3e24", coat="#374e4a", coat_hi="#547e64", coat_sh="#313638",
                         pants="#313638", glove="#165a4c"),
                  g=dict(top=5, hw=10, hh=9, bw=17, hat="headscarf", neck="#165a4c", tail=0)),
}
ELIF = dict(skin="#fdcbb0", skin_sh="#fca790", hat="#8fd3ff", hat_hi="#ffffff", band="#4d9be6", pom="#ffffff",
            blanket="#f68181", blanket_hi="#fca790", blanket_sh="#cf657f", stripe="#fdcbb0", eye="#2e222f", mouth="#9e4539")


def person(c, p, g):
    o, cx = p["line"], 16
    ht, hw, hh, bw = g["top"], g["hw"], g["hh"], g["bw"]
    hx, bx = cx - hw // 2, cx - bw // 2
    bt = ht + hh - 1
    bh = 28 - bt + 1
    for lx in (cx - 4, cx):                                   # legs + boots
        rbox(c, lx, 28, 4, 3, p["pants"], o)
        c.rect(lx, 30, 4, 1, p["boots"])
    if g.get("hair") == "long":                               # hair behind head and shoulders
        rbox(c, hx - 1, ht, hw + 2, hh + 5, p["hair"], o)
    for sx in (bx - 2, bx + bw - 1):                          # sleeves + gloves
        rbox(c, sx, bt + 1, 3, 11, p["coat_sh"] if sx > bx else p["coat"], o)
        rbox(c, sx, bt + 10, 3, 3, p["glove"], o)
    rbox(c, bx, bt, bw, bh, p["coat"], o)                     # coat
    c.rect(bx + 1, bt + 2, 1, bh - 5, p["coat_hi"])
    c.rect(bx + bw - 3, bt + 2, 2, bh - 4, p["coat_sh"])
    c.rect(bx, 27, bw, 1, p["coat_sh"])
    c.rect(cx, bt + 4, 1, bh - 7, p["coat_sh"])
    sw = hw + 2                                               # neck scarf
    rbox(c, cx - sw // 2, ht + hh - 1, sw, 3, p["scarf"], o)
    c.rect(cx - sw // 2 + 1, ht + hh + 1, sw - 2, 1, p["scarf_sh"])
    t = g.get("tail", 0)
    if t:
        tx = cx + t * 3 - 1
        rbox(c, tx, ht + hh + 1, 3, 8, p["scarf"], o)
        c.rect(tx + 2, ht + hh + 2, 1, 6, p["scarf_sh"])
        c.rect(tx, ht + hh + 8, 3, 1, p["scarf_sh"])
    hat = g["hat"]
    if hat == "headscarf":
        rbox(c, hx - 1, ht - 1, hw + 2, hh + 3, p["scarf"], o)
        rbox(c, hx + 1, ht + 2, hw - 2, hh - 3, p["skin"], p["scarf_sh"])
        c.rect(hx + 2, ht + 2, hw - 4, 1, p["hair"])
        c.rect(hx, ht + 1, 1, hh, p["scarf_sh"])
        c.rect(hx + hw - 1, ht + 1, 1, hh, p["scarf_sh"])
        c.rect(hx + 1, ht, hw - 2, 1, g["neck"])
        c.rect(cx - 2, ht + hh + 1, 4, 2, g["neck"])
    else:
        rbox(c, hx, ht, hw, hh, p["skin"], o)
        c.rect(hx + hw - 2, ht + 3, 1, hh - 5, p["skin_sh"])
        if g["hair"] == "short" or hat == "none":
            c.rect(hx, ht, hw, 2, p["hair"])
            c.rect(hx, ht + 2, 1, 2, p["hair"])
            c.rect(hx + hw - 1, ht + 2, 1, 2, p["hair"])
        if hat == "beanie":
            rbox(c, hx - 1, ht - 2, hw + 2, 5, p["hat"], o)
            c.rect(hx - 1, ht + 1, hw + 2, 2, p["band"])
            c.rect(hx + 1, ht - 1, 2, 1, p["hat_hi"])
            if g.get("pompom"):
                rbox(c, cx - 2, ht - 5, 4, 3, p["pom"], o)
        elif hat == "cap":
            rbox(c, hx - 1, ht - 2, hw + 2, 4, p["hat"], o)
            c.rect(hx + 1, ht - 1, 3, 1, p["hat_hi"])
            rbox(c, hx - 2, ht + 1, hw + 4, 2, p["band"], o)
            c.put(hx, ht + 3, p["hair"]); c.put(hx + hw - 1, ht + 3, p["hair"])
    ey = ht + 4
    c.put(cx - 3, ey, p["eye"]); c.put(cx + 2, ey, p["eye"])
    c.put(cx - 4, ey + 2, p["skin_sh"]); c.put(cx + 3, ey + 2, p["skin_sh"])
    if p["stache"]:
        c.rect(cx - 3, ey + 2, 6, 1, p["stache"])
    else:
        c.rect(cx - 1, ey + 3, 2, 1, p["mouth"])


def bundle(c, p):
    o, cx = LINE, 16
    rbox(c, 6, 15, 20, 16, p["blanket"], o)                   # blanket bundle
    c.rect(7, 16, 2, 13, p["blanket_hi"])
    c.rect(22, 18, 3, 12, p["blanket_sh"])
    for y in (21, 25, 29):
        c.rect(7, y, 18, 1, p["stripe"])
    rbox(c, 10, 6, 12, 10, p["skin"], o)                      # head
    c.rect(20, 9, 1, 5, p["skin_sh"])
    rbox(c, 9, 3, 14, 6, p["hat"], o)                         # little hat
    c.rect(9, 6, 14, 2, p["band"])
    c.rect(11, 4, 2, 1, p["hat_hi"])
    c.put(13, 10, p["eye"]); c.put(18, 10, p["eye"])
    c.put(12, 12, p["skin_sh"]); c.put(19, 12, p["skin_sh"])
    c.rect(15, 13, 2, 1, p["mouth"])
    rbox(c, 8, 14, 16, 4, p["blanket_hi"], o)                 # blanket fold over chin
    c.rect(9, 15, 14, 1, p["blanket"])
    rbox(c, 11, 19, 3, 2, p["skin"], o)                       # tiny hand


def build():
    for name, d in PEOPLE.items():
        c = Canvas(32, 32, 1)
        person(c, {**BASE, **d["p"]}, d["g"])
        export([c], os.path.join(ART, "person_%s.png" % name), 2)
    c = Canvas(32, 32, 1)
    bundle(c, ELIF)
    export([c], os.path.join(ART, "person_elif.png"), 2)


if __name__ == "__main__":
    build()
