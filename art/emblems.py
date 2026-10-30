"""
The characters' emblems (tools/art.py calls sprites()): no faces, just a badge and a
symbol that stands for each one, in the emblem style (art/badge.py).

    emblems/<character>          the classic one: a cream symbol on a field of their colour
    emblems/<character>_ghost    the Ghost Crew emblem (from Treasure Chests): another
                                 symbol of theirs, glowing mint on a dark field, a wispy rim
    emblems/<character>_gilded   the Gilded emblem (mastery 8): another symbol in gold on a
                                 deep field of their colour, a sunburst rim and a gem

Each set is a different design and a different colour scheme, and each symbol is
something the character is about: the Mage's snowflake (Blizzard), an ice crystal and a
frost moon; the Trapper's bear trap, lasso and bounty star; the Fire Starter's flame,
match and rocket (Blast Off); the Naturalist's sprout, paw print (Stampede) and parrot
feather; the Warper's spiral, hourglass and comet; the Overseer's spyglass, eye and
ship's wheel; the Gambler's dice, spade and poker chip; the Cannoneer's cannonball,
cannon and a burst. Classic is also the emblem on their playing piece (art/pieces.py).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from badge import (CREAM, CREAM_D, GOLD, GOLD_D, INK, Badge, circ, ell, mix,  # noqa: E402
                   poly, rot, rrect, smooth, star)

PX = 160

# the characters' colours (Theme.Character)
CHARACTERS = {
    "mage": "#2F7FD0",
    "trapper": "#EE8A2E",
    "fire_starter": "#D64545",
    "naturalist": "#3E9F5B",
    "warper": "#D35A9C",
    "overseer": "#E7B023",
    "gambler": "#22A094",
    "cannoneer": "#93633A",
}

SPECTRAL = "#8EE6CF"


class Pal:
    def __init__(self, **kw):
        self.__dict__.update(kw)


def scheme(char, kind):
    c = CHARACTERS[char]
    if kind == "ghost":
        return Pal(frame="wisp", ring=mix(SPECTRAL, c, 0.22), field=mix(c, "#0E2A33", 0.8), field_dark="#071419",
                   rim=mix("#1E4C48", c, 0.15), main="#E6FFF7", shade="#9CD8C8", ink="#0A2125",
                   acc=mix(SPECTRAL, c, 0.35), acc_d=mix("#4A9E8E", c, 0.35), glow="#A8FFE6", gem=None)
    if kind == "gilded":
        return Pal(frame="rays", ring=GOLD, field=mix(c, INK, 0.42), field_dark=mix(c, INK, 0.7),
                   rim=mix(c, INK, 0.55), main="#FFD45E", shade="#D2952A", ink="#45300A",
                   acc=mix(c, "#FFFFFF", 0.22), acc_d=mix(c, INK, 0.25), glow=None, gem=c)
    acc, acc_d = GOLD, GOLD_D
    if char == "overseer":
        acc, acc_d = "#2F4C6E", "#1F344E"
    elif char == "trapper":
        acc, acc_d = "#6B4A2E", "#4A321E"
    return Pal(frame="round", ring=mix(c, "#FFFFFF", 0.18), field=c, field_dark=mix(c, INK, 0.4),
               rim=mix(c, INK, 0.5), main=CREAM, shade=CREAM_D, ink=mix(c, INK, 0.8),
               acc=acc, acc_d=acc_d, glow=None, gem=None)


def flame_paths(cx, cy, s):
    """A flame (outer, inner) about 64 x s tall round (cx, cy)."""
    def tr(d_pts):
        return [(cx + (x - 50) * s, cy + (y - 47) * s) for x, y in d_pts]

    outer = tr([(50, 15), (58, 27), (72, 35), (72, 54), (72, 69), (62, 79), (50, 79), (38, 79), (28, 70), (28, 56),
                (28, 45), (34, 39), (39, 31), (40, 39), (43, 44), (47, 45.5), (45, 35), (45, 25), (50, 15)])
    inner = tr([(51, 44), (55, 51), (62, 56), (62, 63.5), (62, 70.5), (57, 74.5), (50.5, 74.5), (44, 74.5),
                (39.5, 70), (39.5, 64), (39.5, 58.5), (43, 56), (45, 51.5), (46, 55), (48, 57), (50.5, 57.5),
                (49.5, 52.5), (49, 48), (51, 44)])

    def curve(p):
        d = f"M {p[0][0]:.2f} {p[0][1]:.2f}"
        for i in range(1, len(p) - 1, 3):
            d += f" C {p[i][0]:.2f} {p[i][1]:.2f}, {p[i + 1][0]:.2f} {p[i + 1][1]:.2f}, {p[i + 2][0]:.2f} {p[i + 2][1]:.2f}"
        return d + " Z"

    return curve(outer), curve(inner)


def crescent(cx1, cy1, r1, cx2, cy2, r2):
    """The disc (cx1, cy1, r1) with the disc (cx2, cy2, r2) bitten out of it."""
    dx, dy = cx2 - cx1, cy2 - cy1
    d = math.hypot(dx, dy)
    a = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, r1 * r1 - a * a))
    mx, my = cx1 + a * dx / d, cy1 + a * dy / d
    p1 = (mx + h * dy / d, my - h * dx / d)
    p2 = (mx - h * dy / d, my + h * dx / d)
    return (f"M {p1[0]:.2f} {p1[1]:.2f} A {r1} {r1} 0 1 0 {p2[0]:.2f} {p2[1]:.2f} "
            f"A {r2} {r2} 0 0 1 {p1[0]:.2f} {p1[1]:.2f} Z")


def sparkle(cx, cy, r):
    return star(cx, cy, r, r * 0.34, 4)


# ---------------------------------------------------------------------------
# the classic emblems
# ---------------------------------------------------------------------------


def snowflake(b, p):
    items = []
    for k in range(6):
        a = math.radians(-90 + k * 60)
        dx, dy = math.cos(a), math.sin(a)
        items.append((f"M 50 50 L {50 + dx * 27:.2f} {50 + dy * 27:.2f}", 6.4))
        for dist, blen in ((12.5, 9.0), (20.5, 6.2)):
            bx, by = 50 + dx * dist, 50 + dy * dist
            for side in (-1, 1):
                ba = a + side * math.radians(55)
                items.append((f"M {bx:.2f} {by:.2f} L {bx + math.cos(ba) * blen:.2f} {by + math.sin(ba) * blen:.2f}", 4.6))
    for d, w in items:
        b.stroke(d, "#000000", w + 2 * b.ow, 0.24, transform="translate(1 2.4)")
    b.lines(items, p.main, p.shade, p.ink)
    hexa = poly([(50 + math.cos(math.radians(-90 + k * 60)) * 7, 50 + math.sin(math.radians(-90 + k * 60)) * 7) for k in range(6)])
    b.part(hexa, p.acc, p.acc_d, p.ink, cut=(0.8, 1.1))


def beartrap(b, p):
    """A bear trap from the front, sprung open: its jaws a U of iron, teeth along their
    inside, the pan in the bottom and the spring bar under it (as on the piece)."""
    jaw = "M 24 25 C 24 53, 35 72, 50 72 C 65 72, 76 53, 76 25 L 67 25 C 67 47, 60 62.5, 50 62.5 C 40 62.5, 33 47, 33 25 Z"
    teeth = []
    for (x0, y0), (x1, y1), (x2, y2) in (((33.2, 26.4), (45.2, 31.4), (33.6, 36.4)), ((34.2, 38.4), (46.2, 43.4), (35.2, 48.4)),
                                          ((36.8, 50), (46.6, 54), (39.6, 58.4))):
        teeth.append(poly([(x0, y0), (x1, y1), (x2, y2)]))
        teeth.append(poly([(100 - x0, y0), (100 - x1, y1), (100 - x2, y2)]))
    bar = rrect(28.5, 69.5, 43, 7.4, 3.2)
    b.shadow([jaw, bar])
    b.part(bar, p.acc, p.acc_d, p.ink, cut=(0.5, 1.0))
    for x in (29, 71):
        b.part(circ(x, 73.2, 4.4), p.acc, p.acc_d, p.ink, cut=(0.6, 0.8), ow=1.8)
    for d in teeth:
        b.part(d, "#FFFFFF", p.shade, p.ink, cut=(0.5, 0.8), ow=1.8)
    b.part(jaw, p.main, p.shade, p.ink, cut=(1.6, 1.8))
    b.part(ell(50, 57.5, 9.5, 3.4), p.acc, p.acc_d, p.ink, cut=(0.4, 0.6), ow=1.6)


def flame(b, p):
    outer, inner = flame_paths(50, 47, 1.0)
    b.shadow([outer])
    b.part(outer, p.main, p.shade, p.ink, cut=(1.8, 2.2))
    b.part(inner, p.acc, p.acc_d, p.ink, cut=(1.0, 1.4), ow=1.6)


def sprout(b, p):
    stem = "M 50.5 77 C 50.5 71, 50.5 63, 51.5 55"
    right = "M 51.5 55 C 51.5 41, 60 31, 74 27.5 C 74.5 41, 66 52.5, 51.5 55 Z"
    left = "M 49.5 61.5 C 42.5 52, 32.5 49, 25 52.5 C 30.5 61, 40.5 65.5, 49.5 61.5 Z"
    b.stroke(stem, "#000000", 5.5 + 2 * b.ow, 0.24, transform="translate(1 2.4)")
    b.shadow([right, left])
    b.lines([(stem, 5.5)], p.main, p.shade, p.ink)
    b.part(left, p.main, p.shade, p.ink)
    b.part(right, p.main, p.shade, p.ink)
    b.stroke("M 53.5 52.5 C 59 43, 65 35, 71.5 30", p.acc, 2.2)
    b.stroke("M 47 60.2 C 41 56.4, 34.5 54, 28.4 53.6", p.acc, 2.2)


def spiral(b, p):
    pts = []
    th = 0.0
    while th <= 7.6:
        r = 2.4 + 3.35 * th
        pts.append((50 + math.cos(th + 1.2) * r, 51 + math.sin(th + 1.2) * r))
        th += 0.22
    d = smooth(pts)
    b.stroke(d, "#000000", 6.6 + 2 * b.ow, 0.24, transform="translate(1 2.4)")
    b.lines([(d, 6.6)], p.main, p.shade, p.ink)
    s = sparkle(72, 27, 8)
    b.shadow([s])
    b.part(s, p.acc, p.acc_d, p.ink, cut=(0.6, 0.8))
    b.part(sparkle(27.5, 72, 5), p.acc, p.acc_d, p.ink, cut=(0.4, 0.6), ow=1.8)


def spyglass(b, p):
    tf = "rotate(-36 50 50)"
    parts = [rrect(19, 45.2, 14, 9.6, 2.4), rrect(31, 43.2, 20, 13.6, 2.6), rrect(49, 40.8, 20, 18.4, 3), rrect(67, 38.4, 13, 23.2, 4)]
    bands = [rrect(29.6, 42.4, 3.6, 15.2, 1.2), rrect(47.6, 39.8, 3.6, 20.4, 1.2), rrect(65.6, 37.4, 3.6, 25.2, 1.2)]
    b.add(f'<g transform="translate(1 2.4)">')
    for d in parts:
        b.fill(d, "#000000", 0.24, tf)
    b.add("</g>")
    b.add(f'<g transform="{tf}">')
    for d in parts:
        b.part(d, p.main, p.shade, p.ink, cut=(0.4, 1.6))
    for d in bands:
        b.part(d, p.acc, p.acc_d, p.ink, cut=(0.2, 0.9), ow=1.7)
    b.part(ell(80.2, 50, 2.6, 9.6), "#BFE6F5", "#7FB8CF", p.ink, cut=(0.3, 0.8), ow=1.7)
    b.add("</g>")
    b.part(sparkle(80, 22.5, 6.4), "#FFFFFF", None, p.ink, ow=1.5)


def dice(b, p):
    back = rrect(28, 30, 22, 22, 5.5)
    front = rrect(42, 43, 26, 26, 6.4)
    b.add('<g transform="translate(1 2.4)">')
    b.fill(back, "#000000", 0.24, "rotate(-16 39 41)")
    b.fill(front, "#000000", 0.24, "rotate(12 55 56)")
    b.add("</g>")
    b.add('<g transform="rotate(-16 39 41)">')
    b.part(back, p.main, p.shade, p.ink)
    for x, y in ((33.5, 35.5), (39, 41), (44.5, 46.5)):
        b.fill(circ(x, y, 2.3), p.field)
    b.add("</g>")
    b.add('<g transform="rotate(12 55 56)">')
    b.part(front, p.main, p.shade, p.ink)
    for x in (48.6, 61.4):
        for y in (49.2, 56, 62.8):
            b.fill(circ(x, y, 2.5), p.field)
    b.add("</g>")


def bomb(b, p):
    ball = circ(45, 58, 18.5)
    cap = rrect(50.5, 35.5, 12, 8.4, 2)
    b.shadow([ball])
    b.add('<g transform="rotate(40 56.5 39.7)">')
    b.part(cap, p.main, p.shade, p.ink, cut=(0.4, 0.9))
    b.add("</g>")
    b.part(ball, p.main, p.shade, p.ink, cut=(2.4, 2.8))
    b.stroke("M 34 52 C 34.5 46, 38.5 42, 44 41", "#FFFFFF", 2.6, 0.7)
    fuse = "M 60.5 36 C 62.5 30.5, 66 28, 69.5 27"
    b.lines([(fuse, 3.0)], mix(p.acc, INK, 0.25) if p.acc != GOLD else "#7A5A3A", None, p.ink, ow=1.4)
    burst = star(71, 26.5, 8, 3.2, 8, -90)
    b.part(burst, "#FFC23D" if p.frame == "round" else p.acc, "#E08A1E" if p.frame == "round" else p.acc_d, p.ink, cut=(0.5, 0.7), ow=1.6)


# ---------------------------------------------------------------------------
# the Ghost Crew emblems
# ---------------------------------------------------------------------------


def crystal(b, p):
    centre = poly([(50, 16), (57.5, 26), (57.5, 66), (50, 76), (42.5, 66), (42.5, 26)])
    left = poly([(38, 33), (43.5, 40), (43.5, 64), (38, 71), (32.5, 64), (32.5, 40)])
    right = poly([(62, 36), (67.5, 43), (67.5, 64), (62, 71), (56.5, 64), (56.5, 43)])
    b.shadow([centre])
    b.add('<g transform="rotate(-20 38 71)">')
    b.part(left, p.acc, p.acc_d, p.ink, cut=(1.0, 1.2))
    b.stroke("M 38 33 L 38 71", p.acc_d, 1.6, 0.8)
    b.add("</g>")
    b.add('<g transform="rotate(20 62 71)">')
    b.part(right, p.acc, p.acc_d, p.ink, cut=(1.0, 1.2))
    b.stroke("M 62 36 L 62 71", p.acc_d, 1.6, 0.8)
    b.add("</g>")
    b.part(centre, p.main, p.shade, p.ink, cut=(1.4, 1.6))
    b.stroke("M 50 16 L 50 76", p.shade, 1.8)
    b.part(sparkle(63, 24, 5.6), "#FFFFFF", None, p.ink, ow=1.4)


def lasso(b, p):
    loop = ell(45, 41, 22, 14.5)
    tail = "M 57.5 54.5 C 61 61, 53 66, 57 72 C 59.5 75.5, 63 76, 65 75"
    b.stroke(loop, "#000000", 6 + 2 * b.ow, 0.24, transform="translate(1 2.4) rotate(-12 45 41)")
    b.stroke(tail, "#000000", 6 + 2 * b.ow, 0.24, transform="translate(1 2.4)")
    b.add('<g transform="rotate(-12 45 41)">')
    b.lines([(loop, 6)], p.main, p.shade, p.ink)
    b.add(f'<path d="{loop}" fill="none" stroke="{p.shade}" stroke-width="2" stroke-dasharray="2.2 4.4" transform="translate(-0.35 -0.5)"/>')
    b.add("</g>")
    b.lines([(tail, 6)], p.main, p.shade, p.ink)
    b.add(f'<path d="{tail}" fill="none" stroke="{p.shade}" stroke-width="2" stroke-dasharray="2.2 4.4" transform="translate(-0.35 -0.5)"/>')
    b.part(rrect(52, 49, 10, 9, 3), p.acc, p.acc_d, p.ink, cut=(0.6, 0.9))


def match(b, p):
    stick = "M 33 75 L 57 41"
    b.stroke(stick, "#000000", 7 + 2 * b.ow, 0.24, transform="translate(1 2.4)")
    b.lines([(stick, 7)], p.main, p.shade, p.ink)
    b.add('<g transform="rotate(35 59 38)">')
    b.part(ell(59, 38, 5.6, 7.4), p.acc, p.acc_d, p.ink, cut=(0.8, 1.1))
    b.add("</g>")
    outer, inner = flame_paths(62.5, 24.5, 0.42)
    b.part(outer, p.main, p.shade, p.ink, cut=(0.8, 1.0), ow=1.8)
    b.part(inner, p.acc, p.acc_d, p.ink, cut=(0.4, 0.6), ow=1.2)


def paw(b, p):
    pad = "M 50 49 C 58.5 49, 67.5 57.5, 66.5 66 C 66 72.5, 59 74, 50 72 C 41 74, 34 72.5, 33.5 66 C 32.5 57.5, 41.5 49, 50 49 Z"
    toes = [("rotate(-28 33.5 43)", ell(33.5, 43, 5.6, 7.4)), ("rotate(-9 44.5 33.5)", ell(44.5, 33.5, 5.8, 7.8)),
            ("rotate(9 55.5 33.5)", ell(55.5, 33.5, 5.8, 7.8)), ("rotate(28 66.5 43)", ell(66.5, 43, 5.6, 7.4))]
    b.shadow([pad])
    for tf, d in toes:
        b.fill(d, "#000000", 0.24, f"translate(1 2.4) {tf}")
    b.part(pad, p.main, p.shade, p.ink)
    for tf, d in toes:
        b.add(f'<g transform="{tf}">')
        b.part(d, p.main, p.shade, p.ink, cut=(0.9, 1.2))
        b.add("</g>")


def hourglass(b, p):
    glass = "M 35 27 L 65 27 C 65 39, 55 44.5, 53 50 C 55 55.5, 65 61, 65 73 L 35 73 C 35 61, 45 55.5, 47 50 C 45 44.5, 35 39, 35 27 Z"
    b.shadow([glass, rrect(29, 20, 42, 7.5, 3), rrect(29, 72.5, 42, 7.5, 3)])
    b.lines([("M 32 25 L 32 75", 3.4), ("M 68 25 L 68 75", 3.4)], p.acc, p.acc_d, p.ink, ow=1.6)
    b.part(glass, p.main, p.shade, p.ink, cut=(1.0, 1.0))
    b.fill("M 40 72.5 C 42 66, 47 62.5, 50 61.5 C 53 62.5, 58 66, 60 72.5 Z", p.acc)
    b.fill("M 41.5 32 L 58.5 32 C 56.5 38.5, 52 42.5, 50 45.5 C 48 42.5, 43.5 38.5, 41.5 32 Z", p.acc)
    b.stroke("M 50 46 L 50 61", p.acc, 1.4)
    b.part(rrect(29, 20, 42, 7.5, 3), p.acc, p.acc_d, p.ink, cut=(0.4, 0.9))
    b.part(rrect(29, 72.5, 42, 7.5, 3), p.acc, p.acc_d, p.ink, cut=(0.4, 0.9))


def eye(b, p):
    almond = "M 18 50 C 30 31, 70 31, 82 50 C 70 69, 30 69, 18 50 Z"
    b.shadow([almond])
    b.lines([("M 50 28.5 L 50 21", 3.2), ("M 35.5 31.5 L 32 25.5", 3.2), ("M 64.5 31.5 L 68 25.5", 3.2)], p.main, p.shade, p.ink, ow=1.6)
    b.part(almond, p.main, p.shade, p.ink, cut=(0.8, 1.6))
    b.part(circ(50, 50, 12.5), p.acc, p.acc_d, p.ink, cut=(0.8, 1.2), ow=1.6)
    b.fill(circ(50, 50, 5.6), p.ink)
    b.fill(circ(46, 46, 2.6), "#FFFFFF", 0.95)


def spade(b, p):
    d = ("M 50 17 C 56 27, 74 37, 74 52 C 74 61, 67 66, 60 66 C 56 66, 53 64.5, 52 62.5 C 52.5 67.5, 55 72, 59.5 76.5 "
         "L 40.5 76.5 C 45 72, 47.5 67.5, 48 62.5 C 47 64.5, 44 66, 40 66 C 33 66, 26 61, 26 52 C 26 37, 44 27, 50 17 Z")
    b.shadow([d])
    b.part(d, p.main, p.shade, p.ink, cut=(1.8, 2.2))
    b.part(sparkle(63, 41, 4.6), "#FFFFFF", None, p.ink, ow=1.2)


def cannon(b, p):
    barrel = "M 25 43 C 21 43, 19 46, 19 50 C 19 54, 21 57, 25 57 L 68 54.5 L 68 45.5 Z"
    muzzle = rrect(66.5, 41.5, 9, 17, 3.2)
    tf = "rotate(-20 48 48)"
    b.add('<g transform="translate(1 2.4)">')
    b.fill(barrel, "#000000", 0.24, tf)
    b.fill(circ(41, 64, 12), "#000000", 0.24)
    b.add("</g>")
    b.add(f'<g transform="{tf}">')
    b.part(barrel, p.main, p.shade, p.ink, cut=(0.6, 1.8))
    b.part(muzzle, p.main, p.shade, p.ink, cut=(0.6, 1.4))
    b.part(rrect(36, 42.8, 4, 15, 1.4), p.acc, p.acc_d, p.ink, cut=(0.2, 0.8), ow=1.5)
    b.add("</g>")
    b.part(circ(41, 64, 12), p.acc, p.acc_d, p.ink, cut=(1.0, 1.2))
    spokes = []
    for k in range(6):
        a = math.radians(k * 60 + 15)
        spokes.append((f"M 41 64 L {41 + math.cos(a) * 8.6:.2f} {64 + math.sin(a) * 8.6:.2f}", 2.2))
    b.lines(spokes, p.main, None, p.ink, ow=1.0)
    b.part(circ(41, 64, 3.2), p.main, None, p.ink, ow=1.4)


# ---------------------------------------------------------------------------
# the Gilded emblems
# ---------------------------------------------------------------------------


def moon(b, p):
    d = crescent(46, 51, 25, 58, 43, 21)
    b.shadow([d])
    b.part(d, p.main, p.shade, p.ink, cut=(1.8, 2.0))
    s1, s2 = star(66.5, 62, 8, 3.4, 5), sparkle(69, 31, 6.2)
    b.shadow([s1, s2])
    b.part(s1, p.acc, p.acc_d, p.ink, cut=(0.6, 0.8), ow=1.7)
    b.part(s2, p.acc, p.acc_d, p.ink, cut=(0.4, 0.6), ow=1.5)


def sheriff(b, p):
    s = star(50, 50, 27, 15.5, 6)
    knobs = [circ(50 + math.cos(math.radians(-90 + k * 60)) * 27.5, 50 + math.sin(math.radians(-90 + k * 60)) * 27.5, 3.8) for k in range(6)]
    b.shadow([s] + knobs)
    for d in knobs:
        b.part(d, p.main, p.shade, p.ink, cut=(0.6, 0.8), ow=1.8)
    b.part(s, p.main, p.shade, p.ink, cut=(1.6, 2.0))
    b.part(circ(50, 50, 10), p.acc, p.acc_d, p.ink, cut=(0.8, 1.0), ow=1.8)
    b.part(star(50, 50, 6, 2.6, 5), p.main, None, p.ink, ow=1.2)


def rocket(b, p):
    tf = "rotate(35 50 50)"
    body = "M 50 18 C 59.5 26, 62.5 38, 61.5 57 L 38.5 57 C 37.5 38, 40.5 26, 50 18 Z"
    fins = ["M 39.5 46 L 29.5 59 L 29.5 66 L 40.5 60 Z", "M 60.5 46 L 70.5 59 L 70.5 66 L 59.5 60 Z"]
    fire = "M 43.5 61 C 43.5 69, 46.5 75, 50 81 C 53.5 75, 56.5 69, 56.5 61 Z"
    b.add('<g transform="translate(1 2.4)">')
    for d in [body] + fins:
        b.fill(d, "#000000", 0.24, tf)
    b.add("</g>")
    b.add(f'<g transform="{tf}">')
    b.part(fire, "#FF9A3C", "#E0561E", p.ink, cut=(0.5, 1.0), ow=1.7)
    b.part(fire.replace("50 81", "50 74").replace("43.5 69", "46 68").replace("56.5 69", "54 68"), "#FFE08A", None, p.ink, ow=0.01)
    for d in fins:
        b.part(d, p.acc, p.acc_d, p.ink, cut=(0.6, 0.9))
    b.part(body, p.main, p.shade, p.ink, cut=(1.6, 1.0))
    b.part(rrect(42.5, 56, 15, 5.4, 1.6), p.acc_d, None, p.ink, ow=1.6)
    b.part(circ(50, 37, 5.2), "#BFE6F5", "#7FB8CF", p.ink, cut=(0.6, 0.8), ow=1.7)
    b.add("</g>")


def feather(b, p):
    # its spine from the quill end (lower left) to the tip (upper right), and its vane
    spine = [(30 + 44 * t + 6 * math.sin(math.pi * t), 76 - 50 * t + 3 * math.sin(math.pi * t)) for t in [k / 40 for k in range(41)]]
    left, right = [], []
    for i, (x, y) in enumerate(spine):
        t = i / 40
        if t < 0.2:
            continue
        j = min(i + 1, 40)
        k = max(i - 1, 0)
        tx, ty = spine[j][0] - spine[k][0], spine[j][1] - spine[k][1]
        n = math.hypot(tx, ty)
        nx, ny = -ty / n, tx / n
        w = 12 * math.sin(math.pi * (t - 0.2) / 0.8) ** 0.6 + 0.6
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w * 0.86, y - ny * w * 0.86))
    vane = smooth(left + list(reversed(right)), closed=True)
    quill = smooth(spine[:10])
    b.shadow([vane])
    b.stroke(quill, "#000000", 3.4 + 2 * b.ow, 0.24, transform="translate(1 2.4)")
    b.part(vane, p.main, p.shade, p.ink, cut=(1.4, 1.6))
    # the barbs, and two notches in the vane
    for i in range(12, 38, 4):
        x, y = spine[i]
        b.stroke(f"M {x:.2f} {y:.2f} L {x + 6.5:.2f} {y + 4.5:.2f}", p.shade, 1.5, 0.9)
        b.stroke(f"M {x:.2f} {y:.2f} L {x - 5:.2f} {y - 5.5:.2f}", p.shade, 1.5, 0.9)
    b.stroke(smooth(spine[8:39]), p.shade, 2.2)
    b.lines([(quill, 3.4)], p.main, p.shade, p.ink, ow=1.5)


def comet(b, p):
    trails = [("M 55 45 C 47 53, 38 61, 25 69", 7.0), ("M 51.5 40 C 43 44, 34 48, 23 51.5", 5.0), ("M 59 50.5 C 55 57, 49 66, 42 76", 5.0)]
    for d, w in trails:
        b.stroke(d, "#000000", w + 2 * b.ow, 0.24, transform="translate(1 2.4)")
    b.lines(trails, p.acc, p.acc_d, p.ink)
    s = star(62, 37, 15, 6.6, 5, -90)
    b.shadow([s])
    b.part(s, p.main, p.shade, p.ink, cut=(1.4, 1.8))


def wheel(b, p):
    spokes = []
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        spokes.append((f"M 50 50 L {50 + math.cos(a) * 25:.2f} {50 + math.sin(a) * 25:.2f}", 4.2))
    handles = []
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        handles.append((f"M {50 + math.cos(a) * 24:.2f} {50 + math.sin(a) * 24:.2f} L {50 + math.cos(a) * 29.5:.2f} {50 + math.sin(a) * 29.5:.2f}", 6.4))
    for d, w in spokes + handles:
        b.stroke(d, "#000000", w + 2 * b.ow, 0.24, transform="translate(1 2.4)")
    b.stroke(circ(50, 50, 18.5), "#000000", 6 + 2 * b.ow, 0.24, transform="translate(1 2.4)")
    b.lines(spokes + handles, p.main, p.shade, p.ink)
    b.lines([(circ(50, 50, 18.5), 6)], p.main, p.shade, p.ink)
    b.part(circ(50, 50, 6.4), p.acc, p.acc_d, p.ink, cut=(0.8, 1.0))


def chip(b, p):
    disc = circ(50, 50, 27)
    b.shadow([disc])
    b.part(disc, p.main, p.shade, p.ink, cut=(1.6, 2.0))
    for k in range(8):
        a = k * 45
        d = rrect(47, 23.6, 6, 7.2, 1.6)
        b.add(f'<g transform="rotate({a} 50 50)">')
        b.fill(d, p.acc)
        b.add("</g>")
    b.stroke(circ(50, 50, 16), p.shade, 2.0)
    b.part(star(50, 50, 9.5, 4.2, 5), p.acc, p.acc_d, p.ink, cut=(0.6, 0.8), ow=1.6)


def burst(b, p):
    pts = []
    for k in range(22):
        a = math.radians(-90 + k * 360 / 22)
        r = (29.5 if k % 4 == 0 else 26) if k % 2 == 0 else 17.5
        pts.append((50 + math.cos(a) * r, 51 + math.sin(a) * r))
    outer = poly(pts)
    pts = []
    for k in range(18):
        a = math.radians(-74 + k * 20)
        r = 15 if k % 2 == 0 else 8.5
        pts.append((50 + math.cos(a) * r, 51 + math.sin(a) * r))
    inner = poly(pts)
    b.shadow([outer])
    b.part(outer, p.main, p.shade, p.ink, cut=(1.6, 2.0))
    b.part(inner, p.acc, p.acc_d, p.ink, cut=(0.8, 1.0), ow=1.7)
    b.part(circ(50, 51, 4.2), "#FFFFFF", None, p.ink, ow=1.2)


DESIGNS = {
    "mage": (snowflake, crystal, moon),
    "trapper": (beartrap, lasso, sheriff),
    "fire_starter": (flame, match, rocket),
    "naturalist": (sprout, paw, feather),
    "warper": (spiral, hourglass, comet),
    "overseer": (spyglass, eye, wheel),
    "gambler": (dice, spade, chip),
    "cannoneer": (bomb, cannon, burst),
}

SETS = ("classic", "ghost", "gilded")


def emblem(char, kind):
    p = scheme(char, kind)
    b = Badge(PX)
    b.badge(p.ring, p.field, p.field_dark, p.rim, p.ink, p.frame, p.gem)
    if p.glow:
        b.glow(50, 50, 30, 30, p.glow, 0.45)
    draw = DESIGNS[char][SETS.index(kind)]
    draw(b, p)
    return b.svg()


def sprites():
    out = []
    for char in CHARACTERS:
        out.append((char, emblem(char, "classic")))
        out.append((char + "_ghost", emblem(char, "ghost")))
        out.append((char + "_gilded", emblem(char, "gilded")))
    return out
