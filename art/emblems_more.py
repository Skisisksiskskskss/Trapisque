"""
Two more emblem sets (tools/art.py calls sprites()), drawn like art/emblems.py:

    emblems_more/<character>_parchment   the classic symbol in the character's colour on
                                         a field of parchment, a ring of their colour
    emblems_more/<character>_storm       a new symbol of theirs, in their colour on a
                                         storm-dark field with a gold ring: the Mage's
                                         icicles, the Trapper's anchor, the Fire Starter's
                                         torch, the Naturalist's toadstool, the Warper's
                                         key, the Overseer's compass, the Gambler's
                                         horseshoe and the Cannoneer's powder keg

They're on a sheet of their own so the emblem sheets already uploaded stay as they are
(Icons.emblemSprite looks here when emblems/ has no such set).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from badge import GOLD, GOLD_D, INK, Badge, circ, ell, mix, poly, rrect, star  # noqa: E402
from emblems import CHARACTERS, DESIGNS, PX, Pal, flame_paths, sparkle  # noqa: E402


def scheme(char, kind):
    c = CHARACTERS[char]
    if kind == "parchment":
        return Pal(frame="round", ring=c, field="#F4E7C9", field_dark="#D8C292", rim=mix(c, INK, 0.5),
                   main=c, shade=mix(c, INK, 0.3), ink=mix(c, INK, 0.75), acc=mix(c, "#FFFFFF", 0.55),
                   acc_d=mix(c, "#FFFFFF", 0.2), glow=None, gem=None)
    return Pal(frame="round", ring=GOLD, field=mix("#1E2633", c, 0.18), field_dark="#0F141C", rim=mix("#1E2633", INK, 0.4),
               main=mix(c, "#FFFFFF", 0.25), shade=c, ink=mix(c, INK, 0.8), acc=GOLD, acc_d=GOLD_D, glow=None, gem=None)


def icicles(b, p):
    shelf = rrect(22, 26, 56, 9, 4)
    drips = [poly([(26, 33), (34, 33), (30, 62)]), poly([(38, 33), (50, 33), (44, 78)]), poly([(52, 33), (62, 33), (57, 66)]),
             poly([(64, 33), (74, 33), (69, 54)])]
    b.shadow([shelf] + drips)
    for d in drips:
        b.part(d, p.main, p.shade, p.ink, cut=(0.8, 1.2))
    b.part(shelf, "#FFFFFF", "#CFE6F5", p.ink, cut=(0.4, 0.8))
    b.part(sparkle(70, 72, 6), p.acc, p.acc_d, p.ink, ow=1.6)


def anchor(b, p):
    ring = circ(50, 24, 6.5)
    shank = rrect(46, 28, 8, 44, 3)
    stock = rrect(32, 34, 36, 7, 3)
    arms = "M 22 58 L 30 54 C 32 66, 40 74, 50 74 C 60 74, 68 66, 70 54 L 78 58 L 74 62 C 70 76, 60 82, 50 82 C 40 82, 30 76, 26 62 Z"
    b.shadow([shank, stock, arms, ring])
    b.part(arms, p.main, p.shade, p.ink)
    b.part(shank, p.main, p.shade, p.ink, cut=(0.4, 1.2))
    b.part(stock, p.acc, p.acc_d, p.ink, cut=(0.4, 0.8))
    b.part(ring, p.acc, p.acc_d, p.ink, cut=(0.4, 0.8))
    b.part(circ(50, 24, 2.8), scheme_hole(p), None, p.ink, ow=1.4)


def scheme_hole(p):
    return p.ring if p.ring != GOLD else "#1E2633"


def torch(b, p):
    handle = "M 44 50 L 56 50 L 53 82 L 47 82 Z"
    cup = rrect(39, 44, 22, 9, 3)
    outer, inner = flame_paths(50, 30, 0.62)
    b.shadow([handle, cup, outer])
    b.part(handle, "#B07A45", "#7A4A26", p.ink, cut=(0.4, 1.0))
    b.part(cup, p.acc, p.acc_d, p.ink, cut=(0.4, 0.8))
    b.part(outer, p.main, p.shade, p.ink, cut=(1.0, 1.4))
    b.part(inner, "#FFE45C", "#FFB000", p.ink, cut=(0.6, 0.9), ow=1.4)


def toadstool(b, p):
    stem = "M 42 52 C 42 64, 40 74, 38 80 L 62 80 C 60 74, 58 64, 58 52 Z"
    cap = "M 18 54 C 18 34, 34 22, 50 22 C 66 22, 82 34, 82 54 C 70 58, 30 58, 18 54 Z"
    b.shadow([stem, cap])
    b.part(stem, "#FFF4E0", "#E3CFA8", p.ink, cut=(0.4, 1.0))
    b.part(cap, p.main, p.shade, p.ink)
    for (x, y, r) in ((34, 40, 4.5), (52, 32, 5.5), (66, 44, 4), (46, 48, 3)):
        b.part(circ(x, y, r), "#FFFFFF", None, p.ink, ow=1.2)


def key(b, p):
    bow = circ(34, 50, 14)
    shaft = rrect(44, 46.5, 36, 7, 3)
    bits = [rrect(66, 53, 5, 10, 1.5), rrect(74, 53, 5, 14, 1.5)]
    b.shadow([bow, shaft] + bits)
    for d in bits:
        b.part(d, p.main, p.shade, p.ink, cut=(0.3, 0.8), ow=1.8)
    b.part(shaft, p.main, p.shade, p.ink, cut=(0.4, 1.0))
    b.part(bow, p.main, p.shade, p.ink)
    b.part(circ(34, 50, 6.5), scheme_hole(p), None, p.ink, ow=1.6)
    b.part(sparkle(34, 50, 4.2), p.acc, p.acc_d, p.ink, ow=1.2)


def compass(b, p):
    face = circ(50, 50, 27)
    b.shadow([face])
    b.part(face, p.acc, p.acc_d, p.ink, cut=(1.0, 1.4))
    b.part(circ(50, 50, 21), "#FFF4E0", "#E3CFA8", p.ink, cut=(0.6, 1.0), ow=1.6)
    north = poly([(50, 31), (55, 50), (45, 50)])
    south = poly([(50, 69), (55, 50), (45, 50)])
    b.part(south, "#8A8F99", "#5E636E", p.ink, cut=(0.2, 0.5), ow=1.4)
    b.part(north, p.main, p.shade, p.ink, cut=(0.2, 0.5), ow=1.4)
    b.part(circ(50, 50, 2.6), p.acc, None, p.ink, ow=1.2)


def horseshoe(b, p):
    shoe = "M 26 28 L 38 28 C 38 50, 42 64, 50 64 C 58 64, 62 50, 62 28 L 74 28 C 74 56, 66 76, 50 76 C 34 76, 26 56, 26 28 Z"
    b.shadow([shoe])
    b.part(shoe, p.main, p.shade, p.ink)
    for (x, y) in ((31, 38), (32, 52), (36, 64), (69, 38), (68, 52), (64, 64)):
        b.part(rrect(x - 1.6, y - 2.4, 3.2, 4.8, 1), p.acc, None, p.ink, ow=1.0)
    b.part(sparkle(50, 40, 7), p.acc, p.acc_d, p.ink, ow=1.5)


def keg(b, p):
    body = "M 30 30 C 26 44, 26 60, 30 74 L 70 74 C 74 60, 74 44, 70 30 Z"
    b.shadow([body])
    b.part(body, "#B07A45", "#7A4A26", p.ink, cut=(1.0, 1.6))
    for y in (37, 67):
        b.part(rrect(27.5, y - 3, 45, 6, 2), p.acc, p.acc_d, p.ink, cut=(0.3, 0.6), ow=1.6)
    b.part(ell(50, 30, 20, 4.5), "#C9965F", None, p.ink, ow=1.6)
    b.part(rrect(37, 46, 26, 12, 3), p.main, p.shade, p.ink, cut=(0.3, 0.6), ow=1.6)
    b.stroke("M 58 29 C 62 20, 70 18, 74 14", "#5A4632", 2.6)
    b.part(star(75, 13, 6, 2.2, 6), "#FFC93C", "#E89A1C", p.ink, ow=1.2)


STORM = {
    "mage": icicles,
    "trapper": anchor,
    "fire_starter": torch,
    "naturalist": toadstool,
    "warper": key,
    "overseer": compass,
    "gambler": horseshoe,
    "cannoneer": keg,
}


def emblem(char, kind):
    p = scheme(char, kind)
    b = Badge(PX)
    b.badge(p.ring, p.field, p.field_dark, p.rim, p.ink, p.frame, p.gem)
    draw = DESIGNS[char][0] if kind == "parchment" else STORM[char]
    draw(b, p)
    return b.svg()


def sprites():
    out = []
    for char in CHARACTERS:
        out.append((char + "_parchment", emblem(char, "parchment")))
        out.append((char + "_storm", emblem(char, "storm")))
    return out
