"""
What the board shows on a tile (tools/art.py calls sprites()): instead of an icon, the
tile turns into what's on it. Drawn like the props (lit from the upper left, a thin
outline in a darker shade of each part's own colour, a soft shadow on the ground), on
100 x 100 canvases, in two kinds:

  - things standing on the tile (a banana peel, spikes, a Grog in its hole, a campfire,
    a snare, a wall, a locked gate, a mushroom, the treasure chest, the start flag),
    seen a little from the front like the pieces, standing on the canvas's point
    (50, FOOT): the board puts that point on the tile's middle;
  - what covers the tile's top (ice, mud, water, lava, slime, sand, a portal, embers, a
    conveyor belt), drawn from straight above, round the canvas's middle: the board
    squashes it onto the tile the way it squashes the ground.

Each fits a tile of any shape (a round stone or a square slab).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props import INK, Art, circ, ell, mix  # noqa: E402

PX = 120  # canvas pixels
UNITS = 1.5  # how many map units a canvas covers on the board (sets the outline)
FOOT = 80  # where a standing thing's foot is, down its canvas

STEEL, STEEL_L, STEEL_D = "#A3ABBB", "#D6DCE6", "#596274"
WOOD, WOOD_D, WOOD_L = "#A8703C", "#6E4520", "#C99563"
ROPE, ROPE_D = "#C29A5E", "#8A6A3A"
GOLD, GOLD_D = "#F2C23A", "#B5841E"
BRICK, BRICK_L, MORTAR = "#D8744A", "#EE9A6C", "#F2D7B8"
IRON, IRON_L = "#454A57", "#7A8194"
HOLE = "#241E1C"


def blob(cx, cy, r, lobes=5, wobble=0.08, phase=0.0, ry=None, n=40):
    """A smooth closed shape round (cx, cy): a circle whose radius swells and dips."""
    ry = ry or r
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        w = 1 + wobble * math.sin(lobes * t + phase) + wobble * 0.5 * math.sin((lobes + 2) * t + phase * 1.7)
        pts.append((cx + math.cos(t) * r * w, cy + math.sin(t) * ry * w))
    # Catmull-Rom through the points, as cubic curves
    d = f"M {pts[0][0]:.2f} {pts[0][1]:.2f}"
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C {c1[0]:.2f} {c1[1]:.2f}, {c2[0]:.2f} {c2[1]:.2f}, {p2[0]:.2f} {p2[1]:.2f}"
    return d + " Z"


def cone(x, base, w, h, lean=0.0):
    """A spike: a cone from the ground at x (w either side) up to its point."""
    tx = x + lean
    return (
        f"M {x - w} {base} Q {x - w * 0.35 + lean * 0.4} {base - h * 0.55}, {tx} {base - h} "
        f"Q {x + w * 0.35 + lean * 0.4} {base - h * 0.55}, {x + w} {base} "
        f"Q {x} {base + w * 0.45}, {x - w} {base} Z"
    )


def art():
    return Art(PX, UNITS)


# ---------------------------------------------------------------------------
# standing on the tile
# ---------------------------------------------------------------------------


def banana():
    """A banana peel dropped on the ground: its flaps splayed round it, stem up."""
    a = art()
    a.shadow(50, FOOT + 3, 34, 7, 0.26)
    peel, peel_d, inner, tip = "#F7D44A", "#A07C1A", "#FFF3BE", "#6E4E26"

    def flap(d, light=None):
        a.shape(d, peel, outline=peel_d)
        if light:
            a.fill(light, inner, 0.95)

    # the back flaps, then the body, then the ones falling toward you
    flap("M 44 66 C 34 58, 22 58, 14 66 C 12 70, 14 74, 18 74 C 26 72, 36 72, 46 74 Z",
         "M 20 70 C 26 66, 34 66, 42 70 C 34 70, 26 71, 20 70 Z")
    flap("M 56 66 C 66 58, 78 58, 86 66 C 88 70, 86 74, 82 74 C 74 72, 64 72, 54 74 Z",
         "M 80 70 C 74 66, 66 66, 58 70 C 66 70, 74 71, 80 70 Z")
    a.shape("M 40 72 C 40 62, 44 56, 50 56 C 56 56, 60 62, 60 72 C 60 78, 40 78, 40 72 Z", peel, outline=peel_d)
    a.fill("M 44 70 C 44 64, 47 60, 50 60 C 53 60, 56 64, 56 70 C 53 72, 47 72, 44 70 Z", inner, 0.95)
    flap("M 42 72 C 32 74, 22 80, 18 86 C 20 90, 26 90, 30 88 C 36 82, 42 80, 48 77 Z",
         "M 24 86 C 28 81, 34 78, 42 76 C 36 80, 30 84, 24 86 Z")
    flap("M 58 72 C 68 74, 78 80, 82 86 C 80 90, 74 90, 70 88 C 64 82, 58 80, 52 77 Z",
         "M 76 86 C 72 81, 66 78, 58 76 C 64 80, 70 84, 76 86 Z")
    for cx, cy in ((15, 70), (85, 70), (21, 88), (79, 88)):
        a.shape(ell(cx, cy, 3, 2.4), tip, flat=True)
    # the stem, standing up out of the middle
    a.shape("M 47 58 C 46 50, 48 44, 52 40 L 56 42 C 53 46, 52 52, 53 58 Z", "#E7C23C", outline=peel_d)
    a.shape(ell(54.2, 40.6, 2.6, 2), tip, flat=True)
    return a.svg()


def spike():
    """Steel spikes sticking up out of the tile."""
    a = art()
    a.shadow(52, FOOT + 2, 34, 7, 0.3)
    spikes = [(36, 74, 6, 30, -1.5), (64, 74, 6, 32, 1.5), (50, 78, 7.5, 46, 0), (27, 84, 6, 26, -2), (73, 84, 6, 28, 2), (50, 88, 6, 22, 0.5)]
    for x, base, w, h, lean in spikes:
        # a dark crack in the stone where it comes up
        a.fill(ell(x, base + 0.5, w * 1.25, w * 0.42), HOLE, 0.55)
        a.shape(cone(x, base, w, h, lean), STEEL, 0.45, 0.4, outline=STEEL_D, x1=0.1, y1=0.2, x2=0.9, y2=0.6)
        a.line(f"M {x - w * 0.45} {base - 1} Q {x - w * 0.25 + lean * 0.3} {base - h * 0.5}, {x + lean - 0.4} {base - h + 3}", STEEL_L, a.ow * 0.8, 0.85)
    return a.svg()


def grog():
    """The hungry Grog, peeking out of its hole with its claws on the rim."""
    a = art()
    a.shadow(50, FOOT + 2, 36, 8, 0.25)
    a.shape(ell(50, FOOT, 31, 10), HOLE, flat=True, outline="#120E0D")
    green, green_d = "#6CB443", "#3E7A28"
    # its head, coming up out of the dark
    a.group(clip=f"M 0 0 L 100 0 L 100 {FOOT} A 31 10 0 0 1 19 {FOOT} Z")
    a.shape(f"M 24 {FOOT + 6} C 22 58, 34 40, 50 40 C 66 40, 78 58, 76 {FOOT + 6} Z", green, outline=green_d)
    a.fill("M 34 52 C 38 46, 46 44, 50 44 C 44 47, 38 50, 34 52 Z", "#A6DA7A", 0.8)
    # big eyes, cross brows, a toothy grin
    for x in (41, 59):
        a.shape(circ(x, 57, 6.4), "#FFFFFF", flat=True, outline=green_d)
        a.fill(circ(x + (1.2 if x < 50 else -1.2), 58.4, 3), INK)
    a.line("M 33 49 L 45 53", green_d, a.ow * 1.5)
    a.line("M 67 49 L 55 53", green_d, a.ow * 1.5)
    a.shape("M 35 67 C 42 73, 58 73, 65 67 C 60 77, 40 77, 35 67 Z", "#3A1E22", flat=True, outline=green_d)
    for x in (41, 47, 53, 59):
        a.fill(f"M {x - 2.4} 68.6 L {x} 73 L {x + 2.4} 68.8 Z", "#FFFFFF")
    a.end()
    # the hole's near rim in front of it, and its claws hooked over
    a.line(f"M 19 {FOOT} A 31 10 0 0 0 81 {FOOT}", "#5A4E46", a.ow * 2.2)
    for x, flip in ((24, 1), (76, -1)):
        a.shape(ell(x, FOOT - 1, 6.5, 4), green, outline=green_d)
        for k in (-1, 0, 1):
            cx = x + k * 3.6 * flip
            a.fill(f"M {cx - 1.2} {FOOT + 1.5} L {cx} {FOOT + 4.6} L {cx + 1.2} {FOOT + 1.5} Z", "#FFFFFF")
    return a.svg()


def fire():
    """A campfire: crossed logs and its flames."""
    a = art()
    a.glow(50, FOOT - 4, 40, 18, "#FF8A2A", 0.35)
    a.shadow(50, FOOT + 3, 30, 6, 0.3)
    for d in (
        f"M 26 {FOOT - 2} L 70 {FOOT + 6} C 73 {FOOT + 6.6}, 74 {FOOT + 1}, 71 {FOOT} L 28 {FOOT - 8} C 24 {FOOT - 8.6}, 23 {FOOT - 2.6}, 26 {FOOT - 2} Z",
        f"M 74 {FOOT - 2} L 30 {FOOT + 6} C 27 {FOOT + 6.6}, 26 {FOOT + 1}, 29 {FOOT} L 72 {FOOT - 8} C 76 {FOOT - 8.6}, 77 {FOOT - 2.6}, 74 {FOOT - 2} Z",
    ):
        a.shape(d, WOOD, outline=WOOD_D)
    for cx, cy in ((26.6, FOOT - 5), (73.4, FOOT - 5)):
        a.shape(ell(cx, cy, 2.6, 3.4), WOOD_L, flat=True, outline=WOOD_D)
    a.shape(f"M 50 22 C 56 34, 70 42, 68 58 C 67 70, 58 {FOOT - 2}, 50 {FOOT - 2} C 41 {FOOT - 2}, 32 70, 32 58 C 32 48, 40 44, 42 36 C 46 40, 46 46, 48 48 C 50 40, 47 30, 50 22 Z", "#F5752A", 0.25, 0.15, outline="#B5401A")
    a.fill(f"M 51 40 C 55 48, 62 52, 61 62 C 60 70, 55 {FOOT - 5}, 50 {FOOT - 5} C 45 {FOOT - 5}, 40 70, 40 63 C 40 56, 45 54, 46 49 C 48 52, 49 54, 50 55 C 51 50, 50 46, 51 40 Z", "#FFC93A")
    a.fill(f"M 50 58 C 53 62, 55 66, 54 70 C 53 {FOOT - 7}, 47 {FOOT - 7}, 46 70 C 46 66, 48 62, 50 58 Z", "#FFF1A8")
    for x, y, r in ((30, 30, 1.4), (70, 26, 1.2), (62, 16, 1.0)):
        a.fill(circ(x, y, r), "#FFD25A")
    return a.svg()


def snare():
    """A rope snare: its loop lying open on the ground, tied off to a peg."""
    a = art()
    a.shadow(50, FOOT + 3, 34, 7, 0.24)
    # the peg, at the back
    a.shape(f"M 70 {FOOT - 22} L 77 {FOOT - 22} L 77 {FOOT - 3} L 73.5 {FOOT + 3} L 70 {FOOT - 3} Z", WOOD, outline=WOOD_D)
    a.shape(ell(73.5, FOOT - 22, 3.5, 1.6), WOOD_L, flat=True, outline=WOOD_D)
    # the loop: a thick rope with its twist showing
    loop = ell(44, FOOT + 1, 25, 8.5)
    a.line(loop, ROPE_D, a.ow * 4.4)
    a.line(loop, ROPE, a.ow * 2.8)
    for k in range(18):
        t = 2 * math.pi * k / 18
        x, y = 44 + math.cos(t) * 25, FOOT + 1 + math.sin(t) * 8.5
        a.line(f"M {x - 1.2} {y - 1.4} L {x + 1.2} {y + 1.4}", ROPE_D, a.ow * 0.7, 0.8)
    # the running end, up to the peg and knotted round it
    a.line(f"M 68 {FOOT - 1} C 70 {FOOT - 8}, 71 {FOOT - 13}, 73 {FOOT - 16}", ROPE_D, a.ow * 3.4)
    a.line(f"M 68 {FOOT - 1} C 70 {FOOT - 8}, 71 {FOOT - 13}, 73 {FOOT - 16}", ROPE, a.ow * 2)
    a.shape(ell(73.5, FOOT - 16, 5, 2.6), ROPE, outline=ROPE_D)
    return a.svg()


def wall():
    """A short brick wall across the tile (it crumbles once someone gets over it)."""
    a = art()
    a.shadow(50, FOOT + 3, 42, 7, 0.32)
    top, bottom = 46, FOOT + 2
    face = f"M 12 {top + 6} L 88 {top + 6} L 88 {bottom} L 12 {bottom} Z"
    a.shape(face, BRICK, 0.2, 0.25, outline="#8A3E22", x1=0, y1=0, x2=0.4, y2=1)
    # its top, seen a little from above, with a chunk knocked out of the corner
    a.shape(f"M 16 {top} L 74 {top} L 78 {top + 3} L 84 {top} L 88 {top + 6} L 12 {top + 6} Z", BRICK_L, flat=True, outline="#8A3E22")
    a.group(clip=face)
    rows = [top + 6 + 9 * k for k in range(5)]
    for r, y in enumerate(rows):
        a.line(f"M 12 {y} L 88 {y}", MORTAR, a.ow * 1.1, 0.9)
        off = 0 if r % 2 == 0 else 9
        for x in range(12 + off, 89, 18):
            a.line(f"M {x} {y} L {x} {y + 9}", MORTAR, a.ow * 1.1, 0.9)
    a.fill(f"M 12 {top + 6} L 88 {top + 6} L 88 {top + 9} L 12 {top + 9} Z", "#000000", 0.12)
    a.end()
    a.line(face, "#8A3E22", a.ow)
    # a few bricks fallen at its foot
    for x, y in ((20, FOOT + 6), (80, FOOT + 5)):
        a.shape(f"M {x - 4} {y - 2} L {x + 4} {y - 3} L {x + 4.6} {y + 1} L {x - 3.6} {y + 2} Z", BRICK, flat=True, outline="#8A3E22")
    return a.svg()


def gate():
    """A locked iron gate between two stone posts."""
    a = art()
    a.shadow(50, FOOT + 3, 42, 7, 0.3)
    stone, stone_d = "#B5AE9F", "#6F695D"
    for x in (13, 77):
        a.shape(f"M {x} 34 L {x + 10} 34 L {x + 10} {FOOT + 2} L {x} {FOOT + 2} Z", stone, outline=stone_d)
        a.shape(f"M {x - 2} 28 L {x + 12} 28 L {x + 12} 34 L {x - 2} 34 Z", mix(stone, "#FFFFFF", 0.25), flat=True, outline=stone_d)
    for x in (32, 41, 50, 59, 68):
        a.shape(f"M {x - 1.6} 38 L {x + 1.6} 38 L {x + 1.6} {FOOT} L {x - 1.6} {FOOT} Z", IRON, flat=True, outline="#22252C")
        a.shape(f"M {x - 2.4} 38 L {x} 32 L {x + 2.4} 38 Z", IRON_L, flat=True, outline="#22252C")
    for y in (44, 72):
        a.shape(f"M 23 {y - 2} L 77 {y - 2} L 77 {y + 2} L 23 {y + 2} Z", IRON_L, flat=True, outline="#22252C")
    # the padlock
    a.line("M 45.5 55 C 45.5 47, 54.5 47, 54.5 55", "#7E6A3A", a.ow * 2.2)
    a.shape("M 42 54 L 58 54 L 58 66 L 42 66 Z", GOLD, outline=GOLD_D)
    a.fill(circ(50, 59, 1.8), "#5A4012")
    a.fill("M 49.2 59 L 50.8 59 L 50.6 63 L 49.4 63 Z", "#5A4012")
    return a.svg()


def mushroom():
    """The Spore Warper: a big spotted mushroom puffing spores."""
    a = art()
    a.shadow(50, FOOT + 3, 34, 7, 0.28)
    cap, cap_d, stem = "#B65BD0", "#6E2C86", "#F3E8D2"
    for x, s in ((28, 0.5), (72, 0.42)):
        # two little ones
        a.shape(f"M {x - 4 * s} {FOOT + 2} L {x - 3 * s} {FOOT - 16 * s} L {x + 3 * s} {FOOT - 16 * s} L {x + 4 * s} {FOOT + 2} Z", stem, outline="#9C8E72")
        a.shape(f"M {x - 16 * s} {FOOT - 14 * s} C {x - 15 * s} {FOOT - 34 * s}, {x + 15 * s} {FOOT - 34 * s}, {x + 16 * s} {FOOT - 14 * s} Z", cap, outline=cap_d)
    a.shape(f"M 43 {FOOT + 3} C 42 70, 43 60, 44 52 L 56 52 C 57 60, 58 70, 57 {FOOT + 3} Z", stem, outline="#9C8E72")
    a.shape("M 22 54 C 20 30, 36 20, 50 20 C 64 20, 80 30, 78 54 C 70 58, 30 58, 22 54 Z", cap, outline=cap_d)
    a.fill("M 26 52 C 40 55, 60 55, 74 52 C 66 56, 34 56, 26 52 Z", cap_d, 0.5)
    for x, y, r in ((38, 34, 4.4), (56, 28, 3.6), (64, 42, 4.6), (45, 46, 3), (30, 46, 2.6)):
        a.fill(ell(x, y, r, r * 0.85), "#FFFFFF", 0.92)
    for x, y, r in ((24, 14, 1.8), (36, 8, 1.4), (70, 10, 2), (80, 22, 1.4), (60, 6, 1.2)):
        a.fill(circ(x, y, r), "#E9C8F5", 0.9)
    return a.svg()


def chest():
    """The treasure: a chest bound in gold, with a few coins spilled in front."""
    a = art()
    a.glow(50, 58, 44, 30, "#FFE27A", 0.35)
    a.shadow(50, FOOT + 3, 36, 7, 0.32)
    body = f"M 22 54 L 78 54 L 78 {FOOT + 1} L 22 {FOOT + 1} Z"
    a.shape(body, WOOD, outline=WOOD_D)
    a.shape("M 22 54 C 22 36, 78 36, 78 54 Z", mix(WOOD, "#FFFFFF", 0.1), outline=WOOD_D)
    for x in (30, 70):
        a.shape(f"M {x - 3} {FOOT + 1} L {x - 3} 54 C {x - 3} 46, {x + 3} 44, {x + 3} 41 L {x + 3} {FOOT + 1} Z" if x < 50 else
                f"M {x + 3} {FOOT + 1} L {x + 3} 54 C {x + 3} 46, {x - 3} 44, {x - 3} 41 L {x - 3} {FOOT + 1} Z", GOLD, flat=True, outline=GOLD_D)
    a.shape(f"M 20 52 L 80 52 L 80 57 L 20 57 Z", GOLD, flat=True, outline=GOLD_D)
    a.shape("M 45 55 L 55 55 L 55 66 L 50 69 L 45 66 Z", GOLD, outline=GOLD_D)
    a.fill(circ(50, 60, 1.7), "#5A4012")
    for x, y in ((30, FOOT + 6), (38, FOOT + 8), (68, FOOT + 6)):
        a.shape(ell(x, y, 4, 1.8), GOLD, flat=True, outline=GOLD_D)
    for x, y, s in ((24, 34, 3), (74, 30, 2.4), (56, 26, 2)):
        a.fill(f"M {x} {y - s} L {x + s * 0.3} {y - s * 0.3} L {x + s} {y} L {x + s * 0.3} {y + s * 0.3} L {x} {y + s} L {x - s * 0.3} {y + s * 0.3} L {x - s} {y} L {x - s * 0.3} {y - s * 0.3} Z", "#FFFFFF", 0.95)
    return a.svg()


def flag():
    """The Start: a pennant on a pole, in a cairn of stones."""
    a = art()
    a.shadow(50, FOOT + 3, 26, 6, 0.28)
    a.shape(f"M 40 16 L 44 16 L 44 {FOOT} L 40 {FOOT} Z", WOOD, outline=WOOD_D)
    a.shape(circ(42, 14, 3), GOLD, outline=GOLD_D)
    red, red_d = "#E2483D", "#8E2620"
    a.shape("M 44 18 C 56 20, 70 22, 86 30 C 72 34, 58 38, 44 44 Z", red, outline=red_d)
    a.fill("M 44 28 C 54 29, 64 30, 74 31 C 64 33, 54 35, 44 36 Z", "#FFFFFF", 0.9)
    for cx, cy, rx, ry, c in ((34, FOOT + 1, 9, 5, "#A39B8C"), (52, FOOT + 1.5, 9, 5, "#B7AFA0"), (43, FOOT - 3, 8, 5, "#C9C1B2")):
        a.shape(ell(cx, cy, rx, ry), c, outline="#6F695D")
    return a.svg()


# ---------------------------------------------------------------------------
# covering the tile's top (drawn from above)
# ---------------------------------------------------------------------------


def ice():
    """The tile frozen over: a sheet of ice with a frosty rim, cracks and a shine."""
    a = art()
    sheet = blob(50, 50, 41, 6, 0.06, 0.4)
    a.shape(sheet, "#BDEBFF", 0.35, 0.25, outline="#5EA9D6")
    a.group(clip=sheet)
    a.line(blob(50, 50, 41, 6, 0.06, 0.4), "#FFFFFF", a.ow * 3, 0.55)
    a.line("M 58 30 L 54 44 L 62 52 L 58 64", "#6FB4DD", a.ow * 0.9, 0.9)
    a.line("M 54 44 L 40 48 L 34 60", "#6FB4DD", a.ow * 0.9, 0.9)
    a.line("M 62 52 L 76 56", "#6FB4DD", a.ow * 0.9, 0.9)
    a.line("M 22 44 L 42 24", "#FFFFFF", a.ow * 2.6, 0.75)
    a.line("M 28 54 L 50 30", "#FFFFFF", a.ow * 1.4, 0.6)
    a.end()
    return a.svg()


def mud():
    """A mudslide: a wet puddle of mud, smeared the way it slides, a few splats."""
    a = art()
    pool = blob(50, 52, 38, 5, 0.1, 1.3)
    a.shape(pool, "#8A5A34", 0.2, 0.3, outline="#4E2F18")
    a.fill(blob(46, 54, 22, 4, 0.12, 0.2), "#6B4226", 0.9)
    a.line("M 26 44 C 36 40, 48 40, 58 44", "#B07E52", a.ow * 1.4, 0.8)
    a.line("M 34 64 C 44 60, 56 62, 68 66", "#B07E52", a.ow * 1.2, 0.7)
    a.fill(ell(62, 40, 6, 3), "#C99A6C", 0.6)
    for x, y, r in ((86, 30, 4.4), (14, 70, 3.6), (82, 76, 3)):
        a.shape(blob(x, y, r, 3, 0.15, x), "#8A5A34", flat=True, outline="#4E2F18")
    return a.svg()


def water():
    """The river running over the tile: shallow water with a foamy edge and ripples."""
    a = art()
    pool = blob(50, 50, 42, 5, 0.06, 2.1)
    a.shape(pool, "#5FC3E4", 0.3, 0.2, outline="#2F86AE")
    a.group(clip=pool)
    a.line(blob(50, 50, 42, 5, 0.06, 2.1), "#E8FBFF", a.ow * 2.6, 0.8)
    for y, x0, x1 in ((36, 30, 58), (52, 40, 74), (66, 26, 52)):
        a.line(f"M {x0} {y} C {x0 + (x1 - x0) * 0.3} {y - 4}, {x0 + (x1 - x0) * 0.7} {y + 4}, {x1} {y}", "#FFFFFF", a.ow * 1.3, 0.75)
    a.end()
    return a.svg()


def lava():
    """Molten lava over the tile: hot in the middle, plates of dark crust riding on it."""
    a = art()
    a.glow(50, 50, 50, 50, "#FF8A2A", 0.45)
    pool = blob(50, 50, 40, 5, 0.07, 0.9)
    a.shape(pool, "#F2541B", 0.2, 0.25, outline="#7A220C")
    a.fill(blob(50, 50, 26, 4, 0.12, 2.4), "#FF9A2A", 0.95)
    a.fill(blob(52, 48, 13, 3, 0.15, 1.1), "#FFD45A", 0.95)
    for d in ("M 22 40 L 32 34 L 38 42 L 30 48 Z", "M 64 64 L 76 60 L 78 70 L 68 74 Z", "M 60 24 L 70 26 L 68 32 L 60 31 Z"):
        a.shape(d, "#4A2016", flat=True, outline="#2A0E08")
    return a.svg()


def slime():
    """A slime pool over the tile: green goo, bubbling, dripping off its edge."""
    a = art()
    pool = blob(50, 50, 40, 6, 0.08, 0.2)
    a.shape(pool, "#8BC93A", 0.3, 0.25, outline="#4E7E1A")
    a.fill(blob(56, 44, 16, 3, 0.15, 0.6), "#B5E36A", 0.7)
    for x, y, r in ((36, 40, 5), (60, 60, 4), (46, 64, 2.6), (66, 36, 2.4)):
        a.parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#CFF39A" fill-opacity="0.5" stroke="#E9FFC8" stroke-width="{a.ow * 0.9:.2f}"/>')
    for x, y in ((30, 86), (68, 88)):
        a.shape(f"M {x - 3} {y - 6} C {x - 3} {y - 1}, {x - 2} {y + 2}, {x} {y + 2} C {x + 2} {y + 2}, {x + 3} {y - 1}, {x + 3} {y - 6} Z", "#8BC93A", flat=True, outline="#4E7E1A")
    return a.svg()


def sands():
    """Shifting Sands: a patch of loose sand, rippled round the way it slides you."""
    a = art()
    patch = blob(50, 50, 41, 5, 0.06, 0.7)
    a.shape(patch, "#ECCB82", 0.25, 0.2, outline="#A8823E")
    a.group(clip=patch)
    for r in (30, 21, 12):
        a.line(f"M {50 - r} 50 A {r} {r * 0.9} 0 1 1 {50 + r * 0.7} {50 + r * 0.6}", "#C9A55E", a.ow * 1.3, 0.85)
    a.fill(circ(50, 50, 3), "#B8914E", 0.9)
    a.end()
    return a.svg()


def portal():
    """A Teleporter: a ring of runes round a swirl of light."""
    a = art()
    a.glow(50, 50, 50, 50, "#7FB2FF", 0.5)
    a.shape(circ(50, 50, 38), "#3C55B8", 0.35, 0.3, outline="#1E2A66")
    a.fill(circ(50, 50, 26), "#6F8EF0", 0.9)
    a.line("M 50 50 C 50 42, 62 42, 62 50 C 62 62, 42 64, 40 50 C 38 34, 64 30, 70 46", "#FFFFFF", a.ow * 1.8, 0.9)
    a.line(circ(50, 50, 33), "#BFD3FF", a.ow * 1.6, 0.9)
    for k in range(8):
        t = 2 * math.pi * k / 8 + 0.3
        x, y = 50 + math.cos(t) * 33, 50 + math.sin(t) * 33
        a.fill(f"M {x - 2.4} {y} L {x} {y - 2.4} L {x + 2.4} {y} L {x} {y + 2.4} Z", "#FFFFFF", 0.95)
    return a.svg()


def embers():
    """A tile still burning after a Blast Off: glowing coals and a few small flames."""
    a = art()
    a.glow(50, 50, 48, 48, "#FF7A2A", 0.5)
    for x, y, r, ph in ((36, 44, 9, 0.2), (60, 38, 8, 1.4), (64, 62, 10, 2.2), (40, 64, 8, 3.1), (52, 52, 6, 0.9)):
        coal = blob(x, y, r, 3, 0.18, ph, ry=r * 0.8)
        a.shape(coal, "#3A2A26", 0.15, 0.2, outline="#1E1412")
        a.group(clip=coal)
        # glowing where it's still hot, underneath
        a.fill(ell(x + r * 0.15, y + r * 0.55, r * 0.8, r * 0.45), "#FF7A2A", 0.95)
        a.fill(ell(x + r * 0.2, y + r * 0.7, r * 0.45, r * 0.25), "#FFC23A", 0.95)
        a.end()
    for x, y in ((44, 40), (66, 56)):
        a.fill(f"M {x} {y - 12} C {x + 4} {y - 6}, {x + 5} {y - 2}, {x} {y} C {x - 5} {y - 2}, {x - 4} {y - 6}, {x} {y - 12} Z", "#FFC23A")
    return a.svg()


def belt():
    """A stretch of conveyor belt, running to the right (the board turns it the belt's way)."""
    a = art()
    a.shape("M 6 30 L 94 30 L 94 70 L 6 70 Z", "#4A4E5A", 0.25, 0.3, outline="#22252C")
    for x in (10, 90):
        a.shape(f"M {x - 5} 28 L {x + 5} 28 L {x + 5} 72 L {x - 5} 72 Z", "#8792AD", outline="#3E4555")
        a.fill(f"M {x - 5} 49 L {x + 5} 49 L {x + 5} 51 L {x - 5} 51 Z", "#3E4555", 0.8)
    a.shape("M 6 26 L 94 26 L 94 31 L 6 31 Z", "#8792AD", flat=True, outline="#3E4555")
    a.shape("M 6 69 L 94 69 L 94 74 L 6 74 Z", "#8792AD", flat=True, outline="#3E4555")
    for x in (30, 52, 74):
        a.shape(f"M {x - 7} 38 L {x + 3} 50 L {x - 7} 62 L {x - 1} 62 L {x + 9} 50 L {x - 1} 38 Z", "#FFC23A", flat=True, outline="#9C7414")
    return a.svg()


SPRITES = [
    ("banana", banana), ("spike", spike), ("grog", grog), ("fire", fire), ("snare", snare),
    ("wall", wall), ("gate", gate), ("mushroom", mushroom), ("chest", chest), ("flag", flag),
    ("ice", ice), ("mud", mud), ("water", water), ("lava", lava), ("slime", slime),
    ("sands", sands), ("portal", portal), ("embers", embers), ("belt", belt),
]


def sprites():
    return [(name, draw()) for name, draw in SPRITES]
