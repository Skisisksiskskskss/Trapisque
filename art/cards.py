"""
The cards' icons, in the emblem style the characters' emblems use (art/badge.py): a round
badge in the card's category colour (red traps, green assists, navy board pieces,
orange potions, the gold coin), a cream field, and the card's symbol on it in its own
colours, outlined thick. tools/art.py calls sprites().

    cards/<item id>      one per card (Items.lua): the card's face, its token on the
                         board, wherever the card is shown
    cards/token_<kind>   the tokens lying on the board's tiles (a card of that kind to
                         win): the kind's symbol in cream on a field of its colour
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from badge import INK, Badge, circ, ell, mix, poly, rot, rrect, smooth, star  # noqa: E402
from emblems import crescent, flame_paths, sparkle  # noqa: E402

PX = 136

CATEGORY = {
    "trap": "#D64545",
    "assist": "#3E9F5B",
    "neutral": "#2F4C6E",
    "potion": "#E8643C",
    "coin": "#E7B023",
}
FIELD, FIELD_D = "#FFF5E4", "#EBD9BC"

# the symbols' colours
STEEL, STEEL_D = "#C9CED6", "#8E95A1"
IRON, IRON_D = "#5A5D68", "#3C3E47"
WOOD, WOOD_D = "#B87333", "#7A4A1F"
ROPE, ROPE_D = "#D8B57A", "#A9824A"
GOLD, GOLD_D = "#F5C14B", "#C98E1E"
RED, RED_D = "#E0533F", "#A8342A"
GREEN, GREEN_D = "#4FBF68", "#2E8A47"
BLUE, BLUE_D = "#4A9BE0", "#2B6CA8"
ICE, ICE_D = "#BEE8F7", "#7FC2DF"
NAVY, NAVY_D = "#3A5A86", "#24395A"
ORANGE, ORANGE_D = "#FF8A3D", "#D4561C"
YELLOW, YELLOW_D = "#FFD84A", "#E0A21E"
MUD, MUD_D = "#9C6B3A", "#6A4522"
CREAM, CREAM_D = "#FFF6E6", "#E2CFAF"
GLASS, GLASS_D = "#E8F6FA", "#B9DCE6"


def badge(cat):
    b = Badge(PX)
    c = CATEGORY[cat]
    b.badge(c, FIELD, FIELD_D, mix(c, INK, 0.45), mix(c, INK, 0.7))
    return b


def token_badge(cat):
    b = Badge(PX)
    c = CATEGORY[cat]
    b.badge(mix(c, "#FFFFFF", 0.2), c, mix(c, INK, 0.38), mix(c, INK, 0.5), mix(c, INK, 0.78))
    return b


def strokes_shadow(b, items):
    for d, w in items:
        b.stroke(d, "#000000", w + 2 * b.ow, 0.2, transform="translate(1 2.2)")


# ---------------------------------------------------------------------------
# traps
# ---------------------------------------------------------------------------


def spike(b):
    plate = rrect(22, 64, 56, 9, 3.5)
    side = [poly([(34, 36), (42.5, 66), (25.5, 66)]), poly([(66, 36), (74.5, 66), (57.5, 66)])]
    mid = poly([(50, 19), (60.5, 66), (39.5, 66)])
    b.shadow([plate, mid] + side)
    for d in side:
        b.part(d, STEEL, STEEL_D, cut=(1.2, 0.6))
    b.part(mid, STEEL, STEEL_D, cut=(1.6, 0.6))
    for x0, y0, x1, y1 in ((48.4, 26, 45, 58), (32.6, 42, 30.4, 60), (64.6, 42, 62.4, 60)):
        b.stroke(f"M {x0} {y0} L {x1} {y1}", "#FFFFFF", 1.8, 0.75)
    b.part(plate, IRON, IRON_D, cut=(0.6, 1.2))


def grog(b):
    hole = ell(50, 71, 27, 7.5)
    head = "M 27 71 C 26 48, 36 29, 50 29 C 64 29, 74 48, 73 71 Z"
    b.shadow([head])
    b.part(hole, "#3B2C24", None)
    b.part("M 34 33 L 31 22 L 41 30 Z", CREAM, CREAM_D, cut=(0.5, 0.6), ow=1.8)
    b.part("M 66 33 L 69 22 L 59 30 Z", CREAM, CREAM_D, cut=(0.5, 0.6), ow=1.8)
    b.part(head, "#6CC04A", "#3F8A33", cut=(2.0, 1.6))
    for x in (40.5, 59.5):
        b.part(circ(x, 46, 6.6), "#FFFFFF", "#D9DEE6", cut=(0.6, 0.8), ow=1.8)
        b.fill(circ(x + 1.2, 47.2, 3.1), INK)
    b.part(rrect(36, 55.5, 28, 10, 5), "#5A1F22", None, ow=1.8)
    for x in (41, 47.5, 54, 60):
        b.fill(poly([(x - 2.4, 55.8), (x + 2.4, 55.8), (x, 60.4)]), "#FFFFFF")


def fire(b):
    outer, inner = flame_paths(50, 47, 1.0)
    b.shadow([outer])
    b.part(outer, ORANGE, ORANGE_D, cut=(1.8, 2.2))
    b.part(inner, YELLOW, YELLOW_D, cut=(1.0, 1.4), ow=1.8)


def ice(b):
    top = poly([(50, 21), (75, 33.5), (50, 46), (25, 33.5)])
    left = poly([(25, 33.5), (50, 46), (50, 77), (25, 64.5)])
    right = poly([(75, 33.5), (50, 46), (50, 77), (75, 64.5)])
    b.shadow([top, left, right])
    b.part(left, "#A9DEF4", "#86C9E6", cut=(0.6, 0.6))
    b.part(right, "#7CC2E2", "#5EA6C9", cut=(0.6, 0.6))
    b.part(top, "#E9F8FD", "#CDEBF6", cut=(0.6, 0.6))
    b.stroke("M 29 40 L 29 60", "#FFFFFF", 2.2, 0.8)
    b.stroke("M 33 37 L 45 43", "#FFFFFF", 2.2, 0.8)
    b.part(sparkle(67, 25, 7.4), "#FFFFFF", None, ow=1.4)


def snare(b):
    stake = poly([(27, 24), (35, 24), (35, 60), (31, 69), (27, 60)])
    loop = ell(55, 61, 19, 9.5)
    rope = "M 34.5 33 C 46 29, 58 34, 57.5 48"
    b.shadow([stake])
    strokes_shadow(b, [(loop, 5.2), (rope, 5.2)])
    b.part(stake, WOOD, WOOD_D, cut=(1.2, 0.8))
    b.lines([(loop, 5.2)], ROPE, ROPE_D)
    b.add(f'<path d="{loop}" fill="none" stroke="{ROPE_D}" stroke-width="1.6" stroke-dasharray="2 3.6"/>')
    b.lines([(rope, 5.2)], ROPE, ROPE_D)
    b.add(f'<path d="{rope}" fill="none" stroke="{ROPE_D}" stroke-width="1.6" stroke-dasharray="2 3.6"/>')
    b.part(rrect(52.5, 46.5, 10, 9, 3), ROPE, ROPE_D, cut=(0.6, 0.8), ow=1.8)
    b.part(rrect(25.5, 30, 11, 6, 2.4), ROPE, ROPE_D, cut=(0.4, 0.6), ow=1.6)


def mudslide(b):
    """A puddle of mud, and the arrow it sends you back along."""
    puddle = ("M 20 63 C 20 55, 30 52.5, 38 54 C 43 49.5, 56 48.5, 62 52 C 70 50, 80.5 55, 79.5 62.5 "
              "C 78.5 70, 67 73.5, 57 71.5 C 49 75, 35 75, 29 71 C 23 70, 20 67, 20 63 Z")
    arrow = "M 70 42 C 63 28, 43 26, 33.5 36"
    head = poly([(24.5, 38), (36.5, 29), (39.5, 42)])
    b.shadow([puddle, head])
    strokes_shadow(b, [(arrow, 6.2)])
    b.part(puddle, MUD, MUD_D, cut=(1.6, 1.8))
    b.stroke("M 30 58 C 36 54.5, 44 53.5, 50 54.5", "#C99560", 2.4, 0.9)
    for x, y, r in ((61, 60, 2.8), (40, 65, 2.2), (68.5, 64, 1.6)):
        b.part(circ(x, y, r), "#B98352", None, ow=1.0)
    b.lines([(arrow, 6.2)], RED, RED_D)
    b.part(head, RED, RED_D, cut=(0.6, 0.8))


def banana(b):
    inner = "M 45 36 C 40 46, 36 56, 34 64 L 66 64 C 64 56, 60 46, 55 36 Z"
    left = "M 44.5 32 C 36 42, 28 56, 23.5 71 C 32 70, 40 62.5, 46.5 52 Z"
    right = "M 55.5 32 C 64 42, 72 54, 76.5 69 C 68 68.5, 60 60.5, 53.5 52 Z"
    front = "M 44 34 C 42 50, 44 66, 50 78.5 C 56 66, 58 50, 56 34 Z"
    top = "M 45 25 L 55 25 L 57 35 L 43 35 Z"
    b.shadow([left, right, front, top])
    b.part(inner, "#FFF1C4", "#EAD596", cut=(0.6, 0.8))
    b.part(left, YELLOW, YELLOW_D, cut=(1.2, 1.4))
    b.part(right, YELLOW, YELLOW_D, cut=(1.2, 1.4))
    b.part(front, YELLOW, YELLOW_D, cut=(1.4, 1.2))
    b.part(top, YELLOW, YELLOW_D, cut=(0.6, 0.8))
    b.part(rrect(46.5, 18.5, 7, 8, 2.4), "#6B4A22", None, ow=1.8)
    for x, y in ((24.5, 70), (75.5, 68), (50, 77.5)):
        b.fill(circ(x, y, 2.2), "#6B4A22")


def wall(b):
    w = rrect(21, 30, 58, 42, 3.5)
    b.shadow([w])
    b.part(w, "#E07A4F", "#B4532F", cut=(1.0, 1.4))
    c = b.clip(w)
    b.add(f'<g clip-path="{c}">')
    for y in (44, 58):
        b.stroke(f"M 21 {y} L 79 {y}", "#7E3524", 2.2)
    for row, xs in ((0, (36, 52, 68)), (1, (28, 44, 60, 76)), (2, (36, 52, 68))):
        y0 = 30 + row * 14
        for x in xs:
            b.stroke(f"M {x} {y0} L {x} {y0 + 14}", "#7E3524", 2.2)
    for x, y in ((24, 33), (40, 47), (56, 33), (48, 61)):
        b.stroke(f"M {x} {y} L {x + 8} {y}", "#FFFFFF", 1.6, 0.4)
    b.add("</g>")


# ---------------------------------------------------------------------------
# assists
# ---------------------------------------------------------------------------


def speed_boost(b):
    bolt = poly([(56, 17), (33, 53), (48, 53), (41, 82), (69, 43), (54, 43), (66, 17)])
    streaks = [("M 21 40 L 31 40", 4.0), ("M 18 51 L 30 51", 4.0), ("M 22 62 L 31 62", 4.0)]
    strokes_shadow(b, streaks)
    b.shadow([bolt])
    b.lines(streaks, "#7FD3F0", "#4AA6CC", ow=1.8)
    b.part(bolt, YELLOW, YELLOW_D, cut=(1.6, 1.4))
    b.stroke("M 55.5 22 L 39 49", "#FFFFFF", 2.0, 0.65)


def bounce_pad(b):
    base = rrect(29, 69, 42, 8, 3.5)
    coil = "M 37 69 L 63 63.5 L 37 58 L 63 52.5 L 37 47"
    pad = rrect(27, 36.5, 46, 10.5, 5.2)
    up = [("M 39 30 L 50 21.5 L 61 30", 4.6)]
    b.shadow([base, pad])
    strokes_shadow(b, [(coil, 4.4)] + up)
    b.part(base, IRON, IRON_D, cut=(0.6, 1.0))
    b.lines([(coil, 4.4)], STEEL, STEEL_D)
    b.part(pad, GREEN, GREEN_D, cut=(1.0, 1.4))
    b.lines(up, GOLD, GOLD_D)


def moonwalk(b):
    moon = crescent(50, 43, 20, 59.5, 36.5, 16.5)
    arrow = "M 70.5 63 C 62 72, 44 73.5, 33 66"
    head = poly([(26.5, 61), (37.5, 59.5), (33, 70.5)])
    b.shadow([moon, head])
    strokes_shadow(b, [(arrow, 5.0)])
    b.part(moon, "#FFE38A", "#E3B444", cut=(1.6, 1.6))
    b.lines([(arrow, 5.0)], BLUE, BLUE_D)
    b.part(head, BLUE, BLUE_D, cut=(0.6, 0.8))
    b.part(star(68, 30, 5.4, 2.3, 5), "#FFFFFF", None, ow=1.4)


def clover(b):
    heart = "M 0 0 C -3.4 -5, -14 -9, -14 -18 C -14 -24.5, -7.5 -27, -3.8 -24.5 C -1.6 -23, 0 -21, 0 -19.5 C 0 -21, 1.6 -23, 3.8 -24.5 C 7.5 -27, 14 -24.5, 14 -18 C 14 -9, 3.4 -5, 0 0 Z"
    stem = "M 50 50 C 52 60, 56 70, 62 77"
    strokes_shadow(b, [(stem, 4.6)])
    for a in (0, 90, 180, 270):
        b.fill(heart, "#000000", 0.2, f"translate(51 50.2) rotate({a + 45})")
    b.lines([(stem, 4.6)], GREEN_D, mix(GREEN_D, INK, 0.3))
    for a in (0, 90, 180, 270):
        b.add(f'<g transform="translate(50 48) rotate({a + 45})">')
        b.part(heart, GREEN, GREEN_D, cut=(1.0, 1.4))
        b.stroke("M 0 -3 L 0 -16", "#2B7A42", 1.6, 0.8)
        b.add("</g>")


def compass(b):
    ring = circ(50, 53, 25.5)
    b.shadow([ring])
    b.lines([(circ(50, 25, 4.2), 3.4)], GOLD, GOLD_D, ow=1.6)
    b.part(ring, GOLD, GOLD_D, cut=(1.4, 1.6))
    b.part(circ(50, 53, 19.5), "#FFFBF2", "#E9DCC4", cut=(0.6, 0.8), ow=1.8)
    for a in range(0, 360, 90):
        x0, y0 = 50 + math.sin(math.radians(a)) * 16.5, 53 - math.cos(math.radians(a)) * 16.5
        x1, y1 = 50 + math.sin(math.radians(a)) * 13.4, 53 - math.cos(math.radians(a)) * 13.4
        b.stroke(f"M {x0:.2f} {y0:.2f} L {x1:.2f} {y1:.2f}", "#8C7A5A", 1.8)
    b.add('<g transform="rotate(32 50 53)">')
    b.part(poly([(50, 37), (54.6, 53), (45.4, 53)]), RED, RED_D, cut=(0.6, 0.4), ow=1.6)
    b.part(poly([(45.4, 53), (54.6, 53), (50, 69)]), STEEL, STEEL_D, cut=(0.6, 0.4), ow=1.6)
    b.add("</g>")
    b.part(circ(50, 53, 2.8), GOLD, None, ow=1.4)


def juice(b):
    body = rrect(31, 30, 38, 48, 7)
    cap = rrect(42.5, 22.5, 15, 8.5, 2.5)
    b.shadow([body, cap])
    b.part(cap, IRON, IRON_D, cut=(0.4, 0.8))
    b.part(body, "#F4F7FA", "#CDD5DE", cut=(0.8, 1.2))
    for y in (61, 50.5, 40):
        b.part(rrect(36, y, 28, 8.4, 2.6), GREEN, GREEN_D, cut=(0.4, 0.8), ow=1.4)
    b.part(poly([(53, 33.5), (42, 52.5), (49.5, 52.5), (46, 72), (59, 48.5), (51.5, 48.5), (57, 33.5)]), YELLOW, YELLOW_D, cut=(0.8, 0.8), ow=1.8)


def shield(b):
    d = "M 50 19 C 60 24.5, 69.5 26, 76.5 26 C 76.5 51, 68 69, 50 79 C 32 69, 23.5 51, 23.5 26 C 30.5 26, 40 24.5, 50 19 Z"
    inner = "M 50 26 C 57.5 30, 64.5 31.5, 69.5 31.5 C 69 50.5, 62.5 64.5, 50 72 C 37.5 64.5, 31 50.5, 30.5 31.5 C 35.5 31.5, 42.5 30, 50 26 Z"
    b.shadow([d])
    b.part(d, BLUE, BLUE_D, cut=(1.8, 1.8))
    b.part(inner, "#7DB9EA", "#4E92CB", cut=(1.0, 1.0), ow=1.4)
    b.part(star(50, 49, 11.5, 5.2, 5), GOLD, GOLD_D, cut=(0.8, 1.0), ow=1.8)


def bridge(b):
    water = "M 21 66 C 27 63, 33 69, 39 66 C 45 63, 51 69, 57 66 C 63 63, 69 69, 79 66 L 77 74 C 66 78.5, 34 78.5, 23 74 Z"
    arch = "M 20 60 C 32 38, 68 38, 80 60 L 71 62 C 62 49, 38 49, 29 62 Z"
    b.shadow([arch])
    b.part(water, BLUE, BLUE_D, cut=(0.6, 1.0))
    b.stroke("M 30 70.5 C 34 68.5, 38 72, 42 70", "#FFFFFF", 1.8, 0.8)
    b.stroke("M 58 70.5 C 62 68.5, 66 72, 70 70", "#FFFFFF", 1.8, 0.8)
    b.part(arch, WOOD, WOOD_D, cut=(1.0, 1.4))
    c = b.clip(arch)
    b.add(f'<g clip-path="{c}">')
    for x in (32, 40, 48, 56, 64, 72):
        b.stroke(f"M {x} 38 L {x - 2} 64", WOOD_D, 1.6, 0.8)
    b.add("</g>")
    posts = [("M 27 50 L 27 38", 3.6), ("M 50 41.5 L 50 30", 3.6), ("M 73 50 L 73 38", 3.6)]
    rail = [("M 25 40 C 36 27, 64 27, 75 40", 3.6)]
    b.lines(posts + rail, WOOD, WOOD_D, ow=1.8)


def key(b):
    tf = "rotate(-38 50 50)"
    bow = circ(31, 50, 12.5)
    shaft = rrect(41, 46, 37, 8, 3)
    bits = [rrect(62, 53, 5.4, 9, 1.6), rrect(70.5, 53, 5.4, 12.5, 1.6)]
    b.add('<g transform="translate(1 2.4)">')
    for d in [bow, shaft] + bits:
        b.fill(d, "#000000", 0.22, tf)
    b.add("</g>")
    b.add(f'<g transform="{tf}">')
    for d in bits:
        b.part(d, GOLD, GOLD_D, cut=(0.4, 0.8), ow=1.8)
    b.part(shaft, GOLD, GOLD_D, cut=(0.4, 1.2))
    b.part(bow, GOLD, GOLD_D, cut=(1.4, 1.6))
    b.part(circ(31, 50, 5), "#F3E3C6", None, ow=1.6)
    b.add("</g>")


def boots(b):
    boot = "M 34 22 L 57 22 L 57 52 C 66 53, 75 58, 76.5 66 L 76.5 71 L 32.5 71 L 33 30 Z"
    sole = rrect(30, 69, 49, 7, 2.6)
    b.shadow([boot, sole])
    b.part(boot, YELLOW, YELLOW_D, cut=(1.6, 1.2))
    b.part(rrect(31.5, 20, 27.5, 7.4, 2.6), "#FFE892", YELLOW_D, cut=(0.4, 0.8), ow=1.8)
    b.part(sole, IRON, IRON_D, cut=(0.4, 0.8))
    b.fill("M 58 56 C 62 57, 64 60, 63 63 C 62 65, 59 64, 58.5 61.5 Z", "#9BCF2E")
    b.part("M 39 71 C 39 76, 42 78, 44 78 C 46 78, 47.5 76, 47.5 71 Z", "#9BCF2E", "#6DA020", cut=(0.4, 0.6), ow=1.4)


def lantern(b):
    b.glow(50, 50, 22, 22, "#FFD45A", 0.55)
    body = rrect(36.5, 32, 27, 33, 4)
    cap = poly([(35, 33), (65, 33), (59, 25), (41, 25)])
    base = rrect(33.5, 64, 33, 8, 3)
    b.shadow([body, base])
    b.lines([(circ(50, 20.5, 4.4), 3.0)], IRON, IRON_D, ow=1.6)
    b.part(body, "#FFF1B8", "#F2D27A", cut=(0.8, 1.0))
    outer, inner = flame_paths(50, 49, 0.36)
    b.part(outer, ORANGE, ORANGE_D, cut=(0.4, 0.6), ow=1.2)
    b.part(inner, YELLOW, None, ow=0.01)
    b.lines([("M 43 33 L 43 64", 2.6), ("M 57 33 L 57 64", 2.6)], IRON, None, ow=1.0)
    b.part(cap, IRON, IRON_D, cut=(0.4, 0.8))
    b.part(base, IRON, IRON_D, cut=(0.4, 0.8))


def cloak(b):
    d = "M 50 21 C 58.5 21, 63 27.5, 62.5 34.5 L 73.5 73.5 C 64.5 78.5, 35.5 78.5, 26.5 73.5 L 37.5 34.5 C 37 27.5, 41.5 21, 50 21 Z"
    hood = "M 50 25 C 56 25, 59 30, 58.5 35.5 C 55 38.5, 45 38.5, 41.5 35.5 C 41 30, 44 25, 50 25 Z"
    b.shadow([d])
    b.part(d, RED, RED_D, cut=(1.8, 1.2))
    b.fill(hood, "#5A1E22")
    b.stroke("M 44 40 C 42 52, 40 64, 38 75", RED_D, 1.8, 0.8)
    b.stroke("M 56 40 C 58 52, 60 64, 62 75", RED_D, 1.8, 0.8)
    b.part(circ(50, 40.5, 3.6), GOLD, None, ow=1.4)
    outer, inner = flame_paths(50, 59, 0.3)
    b.part(outer, GOLD, GOLD_D, cut=(0.3, 0.5), ow=1.3)


def skates(b):
    boot = "M 33 24 L 53.5 24 L 55 50 C 63 51, 71 55.5, 72.5 62 L 72.5 65.5 L 31 65.5 Z"
    blade = rrect(25, 70, 52, 5.4, 2.7)
    b.shadow([boot, blade])
    b.lines([("M 36 65 L 36 71", 3.4), ("M 66 65 L 66 71", 3.4)], STEEL, STEEL_D, ow=1.4)
    b.part(blade, STEEL, STEEL_D, cut=(0.4, 0.8))
    b.part(boot, RED, RED_D, cut=(1.4, 1.2))
    b.part(rrect(31.5, 21.5, 23.5, 7, 2.6), CREAM, CREAM_D, cut=(0.4, 0.8), ow=1.8)
    for y in (34, 41, 48):
        b.stroke(f"M 39 {y} L 51 {y + 2}", "#FFFFFF", 1.8, 0.85)


def harpoon(b):
    tf = "rotate(-40 50 50)"
    shaft = rrect(21, 47.5, 42, 5, 2.5)
    head = poly([(61, 43.5), (79, 50), (61, 56.5), (64, 50)])
    barbs = [poly([(62, 44), (55.5, 38.5), (60, 47)]), poly([(62, 56), (55.5, 61.5), (60, 53)])]
    b.add('<g transform="translate(1 2.4)">')
    for d in [shaft, head]:
        b.fill(d, "#000000", 0.22, tf)
    b.add("</g>")
    coil = ell(32, 66, 11, 6)
    strokes_shadow(b, [(coil, 3.4)])
    b.lines([(coil, 3.4), ("M 21 66 C 24 58, 28 56, 33 55", 3.4)], ROPE, ROPE_D, ow=1.6)
    b.add(f'<g transform="{tf}">')
    b.part(shaft, WOOD, WOOD_D, cut=(0.4, 1.0))
    for d in barbs:
        b.part(d, STEEL, STEEL_D, cut=(0.4, 0.4), ow=1.8)
    b.part(head, STEEL, STEEL_D, cut=(0.8, 1.0))
    b.part(rrect(55, 46, 6, 8, 1.6), IRON, None, ow=1.6)
    b.add("</g>")


def grapple(b):
    prongs = [("M 50 63 C 40 67, 31.5 61, 30.5 47", 5.4), ("M 50 63 C 60 67, 68.5 61, 69.5 47", 5.4)]
    tips = [poly([(25.5, 49), (30.5, 39.5), (35.5, 49)]), poly([(64.5, 49), (69.5, 39.5), (74.5, 49)])]
    shank = rrect(46.8, 30, 6.4, 34, 2.6)
    strokes_shadow(b, prongs)
    b.shadow([shank] + tips)
    b.lines([("M 50 16 L 50 26", 3.0)], ROPE, ROPE_D, ow=1.6)
    b.lines([(circ(50, 27.5, 4.2), 3.0)], IRON, IRON_D, ow=1.6)
    b.lines(prongs, STEEL, STEEL_D)
    for d in tips:
        b.part(d, STEEL, STEEL_D, cut=(0.4, 0.6), ow=1.8)
    b.part(shank, STEEL, STEEL_D, cut=(0.8, 0.6))
    b.part(poly([(44.5, 64), (55.5, 64), (50, 75)]), STEEL, STEEL_D, cut=(0.4, 0.6), ow=1.8)


# ---------------------------------------------------------------------------
# board pieces
# ---------------------------------------------------------------------------


def teleporter(b):
    b.glow(50, 50, 30, 30, "#7FD3F0", 0.5)
    outer = circ(50, 50, 26)
    b.shadow([outer])
    b.part(outer, NAVY, NAVY_D, cut=(1.2, 1.4))
    b.part(circ(50, 50, 19.5), BLUE, BLUE_D, cut=(0.8, 1.0), ow=1.4)
    b.part(circ(50, 50, 12), "#BFE9F8", "#86CBE6", cut=(0.6, 0.8), ow=1.2)
    pts = []
    th = 0.0
    while th <= 9.0:
        r = 1.0 + 2.1 * th
        pts.append((50 + math.cos(th) * r, 50 + math.sin(th) * r))
        th += 0.25
    b.stroke(smooth(pts), "#FFFFFF", 2.2, 0.9)
    for x, y, r in ((74, 26, 6.4), (26, 74, 5.2)):
        b.part(sparkle(x, y, r), "#FFFFFF", None, ow=1.3)


def spore_warper(b):
    cap = "M 22 54 C 22 34, 36 22, 50 22 C 64 22, 78 34, 78 54 C 68 59, 32 59, 22 54 Z"
    stem = "M 41 55 C 40 63, 39 70, 38 76 L 62 76 C 61 70, 60 63, 59 55 Z"
    b.shadow([cap, stem])
    b.part(stem, CREAM, CREAM_D, cut=(1.0, 0.8))
    b.part(cap, NAVY, NAVY_D, cut=(1.6, 1.8))
    for x, y, r in ((36, 40, 4.4), (51, 31, 3.6), (63, 42, 4.0), (47, 47, 2.6)):
        b.fill(circ(x, y, r), CREAM)
    for x, y, r in ((73, 24, 2.6), (79, 33, 1.8), (27, 26, 2.0)):
        b.part(circ(x, y, r), "#BFE9F8", None, ow=1.2)


def conveyor(b):
    belt = rrect(20, 51, 60, 22, 11)
    b.shadow([belt])
    b.part(belt, IRON, IRON_D, cut=(0.8, 1.2))
    for x in (31, 50, 69):
        b.part(circ(x, 62, 7.2), STEEL, STEEL_D, cut=(0.6, 0.8), ow=1.6)
        b.fill(circ(x, 62, 2.2), IRON_D)
    arrow = poly([(26, 33), (56, 33), (56, 25.5), (76, 38.5), (56, 51.5), (56, 44), (26, 44)])
    b.shadow([arrow])
    b.part(arrow, GOLD, GOLD_D, cut=(1.0, 1.2))


def sands(b):
    dune = "M 20 72 C 30 56, 40 48, 52 48 C 64 48, 72 58, 80 72 Z"
    b.shadow([dune])
    b.part(dune, "#E8C77E", "#C29A4F", cut=(1.6, 1.4))
    b.stroke("M 33 64 C 39 60, 45 59, 50 60", "#C29A4F", 1.8)
    b.stroke("M 55 56 C 61 56, 66 59, 70 64", "#C29A4F", 1.8)
    right = poly([(28, 25), (58, 25), (58, 19), (73, 29.5), (58, 40), (58, 34), (28, 34)])
    left = poly([(72, 41), (42, 41), (42, 35), (27, 45.5), (42, 56), (42, 50), (72, 50)])
    b.shadow([right, left])
    b.part(left, RED, RED_D, cut=(0.6, 0.8), ow=1.8)
    b.part(right, GREEN, GREEN_D, cut=(0.6, 0.8), ow=1.8)


# ---------------------------------------------------------------------------
# potions: one flask, a different brew in each
# ---------------------------------------------------------------------------


def flask(b, liquid, liquid_d, mark):
    body = circ(50, 58, 21)
    neck = rrect(43.5, 26, 13, 17, 3.4)
    cork = rrect(41.5, 18.5, 17, 9, 3)
    b.shadow([body, neck])
    b.part(neck, GLASS, GLASS_D, cut=(0.4, 0.4), ow=2.0)
    b.part(body, GLASS, GLASS_D, cut=(0.8, 1.0))
    c = b.clip(circ(50, 58, 20.2))
    b.add(f'<g clip-path="{c}">')
    b.fill("M 20 56 C 32 52, 44 60, 56 55 C 64 52, 72 54, 80 56 L 80 90 L 20 90 Z", liquid)
    b.fill("M 20 70 C 40 76, 60 76, 80 70 L 80 90 L 20 90 Z", liquid_d, 0.6)
    b.add("</g>")
    b.stroke("M 37 47 C 39.5 43, 43 41, 46 40.5", "#FFFFFF", 2.2, 0.85)
    b.part(cork, WOOD, WOOD_D, cut=(0.4, 0.8), ow=2.0)
    mark(b)


def thief_potion(b):
    def mark(b):
        b.part("M 36 60 C 40 55.5, 60 55.5, 64 60 C 62 66, 56 67, 50 64.5 C 44 67, 38 66, 36 60 Z", "#33303A", None, ow=1.4)
        for x in (43.5, 56.5):
            b.fill(ell(x, 61, 3.6, 2.2), "#FFFFFF")
    flask(b, RED, RED_D, mark)


def phoenix_potion(b):
    def mark(b):
        outer, inner = flame_paths(50, 62, 0.34)
        b.part(outer, YELLOW, YELLOW_D, cut=(0.4, 0.5), ow=1.3)
        b.part(inner, "#FFFFFF", None, ow=0.01)
    flask(b, ORANGE, ORANGE_D, mark)


def xray_potion(b):
    def mark(b):
        b.part("M 37 62 C 42 55, 58 55, 63 62 C 58 69, 42 69, 37 62 Z", "#FFFFFF", None, ow=1.4)
        b.fill(circ(50, 62, 4.2), "#2E8A47")
        b.fill(circ(50, 62, 1.9), INK)
    flask(b, GREEN, GREEN_D, mark)


def telepathy_potion(b):
    def mark(b):
        for r in (4, 8.5, 13):
            b.stroke(f"M {50 - r:.1f} 66 A {r} {r} 0 0 1 {50 + r:.1f} 66", "#FFFFFF", 2.2, 0.95)
        b.fill(circ(50, 66, 2.2), "#FFFFFF")
    flask(b, "#E07AB6", "#B4528C", mark)


def time_potion(b):
    def mark(b):
        b.lines([("M 50 55 L 50 71", 2.6), ("M 44.5 58 L 55.5 58", 2.4), ("M 41 66 C 42 72, 58 72, 59 66", 2.4)], "#FFFFFF", None, ow=0.8)
        b.lines([(circ(50, 53, 2.4), 1.8)], "#FFFFFF", None, ow=0.8)
    flask(b, NAVY, NAVY_D, mark)


def jeopardy_potion(b):
    def mark(b):
        b.part(poly([(37, 57.5), (55, 57.5), (55, 54), (63, 59.5), (55, 65), (55, 61.5), (37, 61.5)]), "#FFFFFF", None, ow=1.2)
        b.part(poly([(63, 66), (45, 66), (45, 62.5), (37, 68), (45, 73.5), (45, 70), (63, 70)]), "#FFFFFF", None, ow=1.2)
    flask(b, GOLD, GOLD_D, mark)


def coin(b):
    disc = circ(50, 50, 26)
    b.shadow([disc])
    b.part(disc, GOLD, GOLD_D, cut=(1.6, 2.0))
    b.stroke(circ(50, 50, 20), GOLD_D, 2.0)
    b.part(star(50, 50, 12.5, 5.6, 5), "#FFE08A", GOLD_D, cut=(0.6, 0.8), ow=1.8)
    b.stroke("M 33 41 A 18 18 0 0 1 41 32", "#FFFFFF", 2.2, 0.75)


# ---------------------------------------------------------------------------
# the tokens on the board: the kind's symbol in cream on its colour
# ---------------------------------------------------------------------------


def token_trap(b):
    skull = "M 50 24 C 63 24, 71 33, 71 45 C 71 52, 67 57, 63 59 L 63 66 C 63 69, 61 71, 58 71 L 42 71 C 39 71, 37 69, 37 66 L 37 59 C 33 57, 29 52, 29 45 C 29 33, 37 24, 50 24 Z"
    b.shadow([skull])
    b.part(skull, CREAM, CREAM_D, cut=(1.4, 1.6))
    for x in (41.5, 58.5):
        b.fill(ell(x, 46, 5.4, 6), "#3A2A2A")
    b.fill(poly([(50, 51.5), (53, 57.5), (47, 57.5)]), "#3A2A2A")
    for x in (45, 50, 55):
        b.stroke(f"M {x} 63 L {x} 70", "#3A2A2A", 1.8)


def token_assist(b):
    heart = "M 50 75 C 42 68, 24 57, 24 41.5 C 24 32, 31 26, 38.5 26 C 44 26, 48 29.5, 50 33.5 C 52 29.5, 56 26, 61.5 26 C 69 26, 76 32, 76 41.5 C 76 57, 58 68, 50 75 Z"
    b.shadow([heart])
    b.part(heart, CREAM, CREAM_D, cut=(1.6, 1.8))
    b.part(rrect(46.5, 36.5, 7, 24, 2.5), "#3E9F5B", None, ow=1.4)
    b.part(rrect(38, 45, 24, 7, 2.5), "#3E9F5B", None, ow=1.4)


def token_neutral(b):
    pts = []
    th = 0.0
    while th <= 9.6:
        r = 1.6 + 2.6 * th
        pts.append((50 + math.cos(th) * r, 50 + math.sin(th) * r))
        th += 0.25
    d = smooth(pts)
    strokes_shadow(b, [(d, 5.4)])
    b.lines([(d, 5.4)], CREAM, CREAM_D)


def token_potion(b):
    body = circ(50, 58, 19)
    neck = rrect(44, 28, 12, 15, 3.2)
    b.shadow([body, neck])
    b.part(neck, CREAM, CREAM_D, cut=(0.4, 0.4))
    b.part(body, CREAM, CREAM_D, cut=(1.2, 1.4))
    c = b.clip(circ(50, 58, 18.4))
    b.add(f'<g clip-path="{c}">')
    b.fill("M 20 58 C 32 54, 44 62, 56 57 C 64 54, 72 56, 80 58 L 80 90 L 20 90 Z", "#E8643C", 0.9)
    b.add("</g>")
    b.part(rrect(42, 21.5, 16, 8, 2.8), "#B87333", "#7A4A1F", cut=(0.4, 0.6), ow=1.8)


def token_coin(b):
    s = star(50, 51, 24, 10.5, 5)
    b.shadow([s])
    b.part(s, CREAM, CREAM_D, cut=(1.4, 1.6))


CARDS = [
    ("spike", "trap", spike), ("grog", "trap", grog), ("fire", "trap", fire), ("ice", "trap", ice),
    ("snare", "trap", snare), ("mudslide", "trap", mudslide), ("banana", "trap", banana), ("wall", "trap", wall),
    ("speed_boost", "assist", speed_boost), ("bounce_pad", "assist", bounce_pad), ("moonwalk", "assist", moonwalk),
    ("clover", "assist", clover), ("compass", "assist", compass), ("juice", "assist", juice), ("shield", "assist", shield),
    ("bridge", "assist", bridge), ("key", "assist", key), ("boots", "assist", boots), ("lantern", "assist", lantern),
    ("cloak", "assist", cloak), ("skates", "assist", skates), ("harpoon", "assist", harpoon), ("grapple", "assist", grapple),
    ("teleporter", "neutral", teleporter), ("spore_warper", "neutral", spore_warper), ("conveyor", "neutral", conveyor),
    ("sands", "neutral", sands),
    ("thief_potion", "potion", thief_potion), ("phoenix_potion", "potion", phoenix_potion), ("xray_potion", "potion", xray_potion),
    ("telepathy_potion", "potion", telepathy_potion), ("time_potion", "potion", time_potion),
    ("jeopardy_potion", "potion", jeopardy_potion),
    ("coin", "coin", coin),
]
TOKENS = [("trap", token_trap), ("assist", token_assist), ("neutral", token_neutral), ("potion", token_potion), ("coin", token_coin)]


def sprites():
    out = []
    for name, cat, draw in CARDS:
        b = badge(cat)
        draw(b)
        out.append((name, b.svg()))
    for kind, draw in TOKENS:
        b = token_badge(kind)
        draw(b)
        out.append(("token_" + kind, b.svg()))
    return out
