"""
What a tile turns into when something covers it (tools/art.py calls sprites()). The
tile keeps its shape and its place on the trail; its face becomes the stuff that's on
it: slime, thin ice, sand, a conveyor's rubber, a portal... Each is drawn bigger than
the tile and cut to the tile's outline, so nothing hangs over the edge. Each comes in
the two tile shapes, "<stuff>_round" (a stone) and "<stuff>_square" (a slab), drawn from
straight above in ground space: the board squashes them onto the tile the way it
squashes the ground. What moves (a conveyor's ridges, the Shifting Sands' ripples) the
board lays on top, cut to the same outline.

And the things that stand across the trail, facing the way it runs (a wall, a locked
gate): "<thing>_<k>" is turned k x 22.5 degrees on the ground (0: lying left to right),
built as boxes and seen from the board's angle, on a 100 x 125 canvas standing on
(50, FOOT). Turned a quarter round it would be seen exactly end on, a sliver, so that
turn isn't drawn: the board uses the nearest one either side. And a raised
drawbridge's leaf, "leaf_<k>": hinged at the bank, raised steeply and leaning out over
the gap towards k x 22.5 degrees.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props import INK, Art, circ, ell, mix  # noqa: E402

PX = 128  # a face's pixels (a tile's face is about 70 pixels across, close up 200)
ROUND = circ(50, 50, 50)
SQUARE = "M 22 0 L 78 0 C 90 0, 100 10, 100 22 L 100 78 C 100 90, 90 100, 78 100 L 22 100 C 10 100, 0 90, 0 78 L 0 22 C 0 10, 10 0, 22 0 Z"


def blob(cx, cy, r, lobes=5, wobble=0.08, phase=0.0, ry=None, n=36):
    """A smooth closed shape round (cx, cy): a circle whose radius swells and dips."""
    ry = ry or r
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        w = 1 + wobble * math.sin(lobes * t + phase) + wobble * 0.5 * math.sin((lobes + 2) * t + phase * 1.7)
        pts.append((cx + math.cos(t) * r * w, cy + math.sin(t) * ry * w))
    d = f"M {pts[0][0]:.2f} {pts[0][1]:.2f}"
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C {c1[0]:.2f} {c1[1]:.2f}, {c2[0]:.2f} {c2[1]:.2f}, {p2[0]:.2f} {p2[1]:.2f}"
    return d + " Z"


def jagged(cx, cy, r, rnd, n=14, jag=0.22):
    """A broken edge round (cx, cy): straight cuts between points at varying radii."""
    pts = []
    for k in range(n):
        t = 2 * math.pi * (k + rnd.uniform(-0.25, 0.25)) / n
        rr = r * (1 + rnd.uniform(-jag, jag))
        pts.append((cx + math.cos(t) * rr, cy + math.sin(t) * rr))
    return "M " + " L ".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


def poly(pts):
    return "M " + " L ".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


# ---------------------------------------------------------------------------
# faces
# ---------------------------------------------------------------------------


def _face(shape, base, draw, light=0.18, dark=0.2):
    """A tile's face as `base` stuff: lit from the upper left, its texture (`draw`) cut
    to the tile's outline, and its edge a little lighter at the top left and darker at
    the bottom right, so it sits in the tile like the stone it replaces."""
    a = Art(PX, 1.6)
    outline = ROUND if shape == "round" else SQUARE
    a.parts.append(f'<path d="{outline}" fill="{a.grad(base, light, dark, x1=0.1, y1=0.0, x2=0.9, y2=1.0)}"/>')
    a.group(clip=outline)
    draw(a)
    gid = a._id("e")
    a.defs.append(
        f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1">'
        '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.42"/>'
        '<stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/>'
        '<stop offset="0.6" stop-color="#000000" stop-opacity="0"/>'
        '<stop offset="1" stop-color="#000000" stop-opacity="0.3"/></linearGradient>'
    )
    a.parts.append(f'<path d="{outline}" fill="none" stroke="url(#{gid})" stroke-width="10"/>')
    a.end()
    return a.svg()


def _bubbles(a, spots, fill, rim, opacity=0.45):
    for x, y, r in spots:
        a.parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" fill-opacity="{opacity}" stroke="{rim}" stroke-width="{a.ow * 0.9:.2f}"/>')
        a.line(f"M {x - r * 0.55} {y - r * 0.1} A {r * 0.6} {r * 0.6} 0 0 1 {x - r * 0.05} {y - r * 0.6}", "#FFFFFF", a.ow * 0.9, 0.85)


def slime(a):
    """Green goo, swirled darker and lighter, bubbling (some bubbles burst at the edge)."""
    for x, y, r, ph in ((66, 64, 30, 0.4), (20, 78, 22, 2.1), (84, 18, 18, 1.2)):
        a.fill(blob(x, y, r, 4, 0.14, ph), "#6FAE2A", 0.55)
    a.fill(blob(36, 32, 24, 3, 0.16, 0.8), "#B5E36A", 0.55)
    a.fill(blob(30, 26, 9, 3, 0.2, 1.9), "#DDF7A8", 0.5)
    _bubbles(a, ((32, 44, 6.5), (64, 56, 5), (48, 72, 3.6), (74, 30, 3), (92, 70, 7), (8, 58, 6), (58, 96, 5), (52, 42, 2.2), (80, 84, 2.6)), "#CFF39A", "#E9FFC8")


def _ice_texture(a, seed):
    rnd = random.Random(seed)
    # frost: soft lighter patches, then long shines and the odd hairline in the ice
    for x, y, r, ph in ((30, 30, 26, 0.3), (74, 70, 24, 1.7), (80, 18, 14, 2.4), (14, 76, 16, 0.9)):
        a.fill(blob(x, y, r, 5, 0.12, ph), "#EEFAFF", 0.6)
    a.line("M 6 46 L 50 2", "#FFFFFF", 5.2, 0.55)
    a.line("M 18 62 L 66 14", "#FFFFFF", 2.4, 0.45)
    a.line("M 56 98 L 98 54", "#FFFFFF", 3.4, 0.35)
    for d in ("M 64 38 L 72 46 L 70 54", "M 26 70 L 36 66 L 40 74", "M 80 76 L 86 70"):
        a.line(d, "#9CCDE6", 0.9, 0.55)
    for _ in range(10):
        x, y = rnd.uniform(8, 92), rnd.uniform(8, 92)
        a.parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rnd.uniform(0.7, 1.5):.2f}" fill="#FFFFFF" fill-opacity="0.75"/>')


def thinice(a):
    """Thin ice: pale, clear and frosted, a few hairlines in it."""
    _ice_texture(a, 3)


def _crack(a, cx, cy, arms, rnd):
    """Cracks running out from where it broke: dark lines with a lit edge."""
    lines = []
    for k in range(arms):
        t = 2 * math.pi * (k + rnd.uniform(-0.3, 0.3)) / arms
        pts, x, y = [(cx, cy)], cx, cy
        for step in range(5):
            t += rnd.uniform(-0.5, 0.5)
            ln = rnd.uniform(9, 16)
            x, y = x + math.cos(t) * ln, y + math.sin(t) * ln
            pts.append((x, y))
        lines.append(pts)
        # a branch off the middle
        bx, by = pts[2]
        bt = t + rnd.choice((-1, 1)) * rnd.uniform(0.7, 1.2)
        lines.append([(bx, by), (bx + math.cos(bt) * 11, by + math.sin(bt) * 11), (bx + math.cos(bt + 0.4) * 19, by + math.sin(bt + 0.4) * 19)])
    for pts in lines:
        d = "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts)
        a.line(d, "#4F8DB5", 2.0, 0.95)
    for pts in lines:
        d = "M " + " L ".join(f"{x + 0.9:.1f} {y + 0.7:.1f}" for x, y in pts)
        a.line(d, "#FFFFFF", 0.8, 0.9)
    # where it was struck: a ring of chips
    a.line(jagged(cx, cy, 7, rnd, 9, 0.3), "#4F8DB5", 1.4, 0.9)


def thinice_cracked(a):
    """The same ice, cracked right across by whoever landed on it."""
    _ice_texture(a, 3)
    _crack(a, 52, 48, 6, random.Random(11))


def hole(a):
    """Where the ice gave way: open water inside a ring of broken ice, chunks afloat."""
    _ice_texture(a, 3)
    rnd = random.Random(5)
    edge = jagged(50, 52, 33, rnd, 15, 0.2)
    a.parts.append(f'<path d="{edge}" fill="#FFFFFF" stroke="#86C0DE" stroke-width="5"/>')
    gid = a._id("w")
    a.defs.append(f'<radialGradient id="{gid}" cx="0.45" cy="0.42" r="0.6"><stop offset="0" stop-color="#2E6E93"/><stop offset="1" stop-color="#173F5C"/></radialGradient>')
    a.parts.append(f'<path d="{edge}" fill="url(#{gid})"/>')
    a.group(clip=edge)
    for y, x0, x1 in ((40, 30, 56), (56, 42, 72), (68, 28, 50)):
        a.line(f"M {x0} {y} C {x0 + (x1 - x0) * 0.3} {y - 3}, {x0 + (x1 - x0) * 0.7} {y + 3}, {x1} {y}", "#5FA3C8", 1.6, 0.8)
    # the ice's broken edge, seen in the water a little below it
    a.line(edge, "#0E2A3E", 4, 0.5)
    a.end()
    for cx, cy, r, ph in ((38, 46, 6, 0.4), (62, 62, 4.6, 2.0), (58, 38, 3.4, 1.1)):
        chunk = jagged(cx, cy, r, random.Random(int(cx * 7)), 6, 0.25)
        a.shape(chunk, "#E4F7FF", 0.3, 0.2, outline="#6FA9CB")


def ice(a):
    """The Ice trap: the tile frozen solid, big crystal facets with a frost rime."""
    rnd = random.Random(9)
    pts = [(rnd.uniform(-10, 110), rnd.uniform(-10, 110)) for _ in range(9)]
    shades = ("#C6EBF8", "#9AD6EE", "#B4E3F4", "#8ACDEA", "#D8F3FC")
    for i in range(len(pts)):
        p, q = pts[i], pts[(i + 3) % len(pts)]
        a.fill(poly([(50, 50), p, q]), shades[i % len(shades)], 0.55)
    for p in pts:
        a.line(f"M 50 50 L {p[0]:.1f} {p[1]:.1f}", "#FFFFFF", 1.1, 0.6)
    a.line("M 8 40 L 44 4", "#FFFFFF", 5, 0.6)
    a.line("M 22 58 L 60 20", "#FFFFFF", 2.2, 0.5)
    # frost round the rim
    a.line(ROUND, "#FFFFFF", 12, 0.35)


def mud(a):
    """Wet mud: darker puddles, lighter smears and shining wet spots."""
    for x, y, r, ph in ((60, 60, 28, 0.6), (18, 30, 18, 2.2), (86, 22, 14, 1.4)):
        a.fill(blob(x, y, r, 4, 0.14, ph), "#6B4226", 0.8)
    for d in ("M 8 46 C 24 40, 42 40, 58 46", "M 26 76 C 40 70, 58 72, 76 78", "M 52 16 C 62 12, 76 12, 90 16"):
        a.line(d, "#B07E52", 3, 0.7)
    for x, y, rx, ry in ((64, 52, 7, 3.2), (24, 34, 5, 2.4), (44, 82, 6, 2.6)):
        a.fill(ell(x, y, rx, ry), "#D9B48A", 0.55)
    for x, y, r in ((78, 80, 3.2), (14, 64, 2.6), (36, 14, 2.2)):
        a.shape(blob(x, y, r, 3, 0.15, x), "#8E7A62", 0.3, 0.3, outline="#4E2F18")


def portal(a):
    """A Teleporter pad: runes on a ring round a swirl of light, glowing in the middle."""
    a.glow(50, 50, 40, 40, "#BFD3FF", 0.6)
    for r, o in ((44, 0.5), (34, 0.65)):
        a.line(circ(50, 50, r), "#8EA4F2", 2, o)
    for k in range(3):
        t0 = k * 2 * math.pi / 3
        pts = []
        for i in range(24):
            t = t0 + i * 0.22
            rr = 4 + i * 1.6
            pts.append((50 + math.cos(t) * rr, 50 + math.sin(t) * rr))
        a.line("M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts), "#E6EEFF", 2.6, 0.85)
    for k in range(10):
        t = 2 * math.pi * k / 10 + 0.2
        x, y = 50 + math.cos(t) * 39, 50 + math.sin(t) * 39
        a.fill(f"M {x - 2.4} {y} L {x} {y - 2.4} L {x + 2.4} {y} L {x} {y + 2.4} Z", "#FFFFFF", 0.95)
    a.fill(circ(50, 50, 6), "#FFFFFF", 0.95)


def sand(a):
    """Loose sand, speckled, with soft dunes (its ripples the board draws, moving)."""
    rnd = random.Random(21)
    for x, y, r, ph in ((30, 70, 26, 0.4), (76, 26, 22, 1.6)):
        a.fill(blob(x, y, r, 4, 0.12, ph), "#D7B36A", 0.4)
    a.fill(blob(66, 70, 18, 3, 0.15, 2.2), "#F6E2B0", 0.5)
    for _ in range(70):
        x, y = rnd.uniform(0, 100), rnd.uniform(0, 100)
        a.parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rnd.uniform(0.5, 1.2):.2f}" fill="{rnd.choice(("#B8914E", "#FFF2CC", "#C9A55E"))}" fill-opacity="0.8"/>')


def water(a):
    """A river running over the tile: deeper patches, lighter streaks, flecks of foam."""
    for x, y, r, ph in ((68, 66, 26, 0.5), (22, 26, 18, 1.9)):
        a.fill(blob(x, y, r, 4, 0.14, ph), "#3591BD", 0.6)
    for y, x0, x1 in ((24, 10, 56), (42, 34, 92), (60, 4, 48), (78, 40, 96)):
        a.line(f"M {x0} {y} C {x0 + (x1 - x0) * 0.3} {y - 4}, {x0 + (x1 - x0) * 0.7} {y + 4}, {x1} {y}", "#8AD3EE", 2.4, 0.8)
    rnd = random.Random(31)
    for _ in range(14):
        x, y = rnd.uniform(4, 96), rnd.uniform(4, 96)
        a.fill(ell(x, y, rnd.uniform(1.2, 2.6), rnd.uniform(0.6, 1.2)), "#FFFFFF", 0.8)


def lava(a):
    """Lava: molten underneath, plates of dark crust riding on it, the cracks glowing."""
    a.fill(blob(50, 50, 34, 4, 0.12, 2.4), "#FF9A2A", 0.95)
    a.fill(blob(54, 46, 16, 3, 0.15, 1.1), "#FFD45A", 0.95)
    rnd = random.Random(41)
    for cx, cy, r in ((16, 22, 16), (82, 18, 14), (86, 78, 17), (18, 82, 15), (52, 92, 10), (94, 48, 9), (6, 52, 10)):
        a.shape(jagged(cx, cy, r, rnd, 7, 0.2), "#4A2016", 0.15, 0.25, outline="#2A0E08")
    for d in ("M 30 40 L 40 46 L 38 58", "M 62 60 L 70 66 L 78 64"):
        a.line(d, "#FFE38A", 1.4, 0.9)


def cog(a):
    """A brass plate with a gear cut into it: the gears turn under whoever ends a round
    here."""
    teeth = 12
    pts = []
    for k in range(teeth * 2):
        t = 2 * math.pi * k / (teeth * 2) + 0.13
        r = 38 if k % 2 == 0 else 31
        for dt in (-0.09, 0.09):
            pts.append((50 + math.cos(t + dt) * r, 50 + math.sin(t + dt) * r))
    gear = poly(pts)
    a.parts.append(f'<path d="{gear}" fill="#B5841E" fill-opacity="0.85" stroke="#8A6212" stroke-width="1.4" stroke-linejoin="round"/>')
    a.parts.append(f'<path d="{gear}" fill="none" stroke="#F4D27A" stroke-width="0.9" transform="translate(-0.9 -0.9)" stroke-opacity="0.8"/>')
    a.fill(circ(50, 50, 22), "#E8BB4E", 1)
    a.line(circ(50, 50, 22), "#8A6212", 1.4)
    for k in range(4):
        t = k * math.pi / 2 + 0.4
        a.line(f"M {50 + math.cos(t) * 8} {50 + math.sin(t) * 8} L {50 + math.cos(t) * 21} {50 + math.sin(t) * 21}", "#B5841E", 4.2)
    a.fill(circ(50, 50, 8), "#F4D27A", 1)
    a.line(circ(50, 50, 8), "#8A6212", 1.2)
    a.fill(circ(50, 50, 2.6), "#5A3E0C", 1)
    for k in range(8):
        t = 2 * math.pi * k / 8
        x, y = 50 + math.cos(t) * 45, 50 + math.sin(t) * 45
        a.fill(circ(x, y, 1.6), "#8A6212", 0.9)
        a.fill(circ(x - 0.5, y - 0.5, 0.7), "#FFF2C0", 0.9)


def embers(a):
    """Scorched by a Blast Off: charred plates, still glowing in the cracks between."""
    rnd = random.Random(51)
    a.fill(ROUND, "#FF7A2A", 0.25)
    for cx, cy, r in ((22, 24, 18), (64, 18, 16), (86, 50, 15), (60, 58, 16), (24, 66, 17), (52, 92, 14), (90, 90, 12), (8, 96, 10), (40, 40, 10)):
        a.shape(jagged(cx, cy, r, rnd, 7, 0.18), "#3A2A26", 0.1, 0.2, outline="#FF8A2A")
    for _ in range(14):
        x, y = rnd.uniform(6, 94), rnd.uniform(6, 94)
        a.fill(circ(x, y, rnd.uniform(0.8, 1.8)), rnd.choice(("#FFC23A", "#FF7A2A")), 0.95)


def belt(a):
    """A conveyor's rubber, worn smooth (its ridges the board draws, moving)."""
    rnd = random.Random(61)
    for _ in range(90):
        x, y = rnd.uniform(0, 100), rnd.uniform(0, 100)
        a.fill(circ(x, y, rnd.uniform(0.4, 0.9)), "#2E3240" if rnd.random() < 0.6 else "#6B7385", 0.6)
    a.line("M 4 40 L 40 4", "#FFFFFF", 6, 0.08)


def planks(a):
    """A drawbridge's deck: weathered boards (their seams the board lays across the
    way the trail runs), knots and nail heads."""
    rnd = random.Random(71)
    for x, y, r, ph in ((30, 30, 24, 0.4), (74, 70, 22, 1.8)):
        a.fill(blob(x, y, r, 4, 0.14, ph), "#A27448", 0.35)
    for x, y in ((24, 62), (70, 30), (58, 84)):
        a.fill(ell(x, y, 3.4, 1.8), "#7A5230", 0.7)
        a.line(ell(x, y, 5.4, 3), "#7A5230", 0.8, 0.5)
    for _ in range(30):
        x, y = rnd.uniform(0, 100), rnd.uniform(0, 100)
        a.fill(ell(x, y, rnd.uniform(2, 6), 0.5), "#8A5E36", 0.35)


def canal(a):
    """The water in the gap under a raised drawbridge: dark, a slow ripple, foam."""
    for x, y, r, ph in ((60, 60, 30, 0.6), (24, 28, 18, 2.0)):
        a.fill(blob(x, y, r, 4, 0.14, ph), "#1E4645", 0.6)
    for y, x0, x1 in ((30, 16, 60), (52, 34, 88), (72, 10, 54)):
        a.line(f"M {x0} {y} C {x0 + (x1 - x0) * 0.3} {y - 3}, {x0 + (x1 - x0) * 0.7} {y + 3}, {x1} {y}", "#5D9A93", 2, 0.75)
    rnd = random.Random(81)
    for _ in range(8):
        x, y = rnd.uniform(6, 94), rnd.uniform(6, 94)
        a.fill(ell(x, y, rnd.uniform(1, 2), rnd.uniform(0.5, 1)), "#DCEBE6", 0.7)


# (name, base colour, texture)
FACES = [
    ("slime", "#8BC93A", slime),
    ("thinice", "#CBEFFC", thinice),
    ("thinice_cracked", "#C4EBFA", thinice_cracked),
    ("hole", "#CBEFFC", hole),
    ("ice", "#A9DDF2", ice),
    ("mud", "#8A5A34", mud),
    ("portal", "#3C55B8", portal),
    ("sand", "#E9C77F", sand),
    ("water", "#4FB3DC", water),
    ("lava", "#F2541B", lava),
    ("cog", "#D9A93F", cog),
    ("embers", "#3A302C", embers),
    ("belt", "#4A4E5A", belt),
    ("planks", "#B98A5A", planks),
    ("canal", "#2C5B5A", canal),
]

# ---------------------------------------------------------------------------
# things standing across the trail, turned to face the way it runs
# ---------------------------------------------------------------------------

K = 0.72  # BoardLayout.Style.squash: the ground seen a little from the side
FOOT = 80  # where it stands, down its canvas
TALL = 125  # the canvas's height (it's 100 wide): room for one turned end-on
TURNS = 8  # 22.5 degrees apart (a wall turned half way round is the same wall)
EDGE_ON = 4  # (not drawn: see above)


class Scene:
    """Boxes and bars in map units (x right, y toward you, z up), drawn back to front."""

    def __init__(self, size, yaw):
        self.s = 100 / size  # canvas units per map unit
        self.c, self.sn = math.cos(yaw), math.sin(yaw)
        self.items = []  # (depth, draw(a))

    def g(self, u, w):
        """(along, across) the thing -> the ground."""
        return u * self.c - w * self.sn, u * self.sn + w * self.c

    def p(self, x, y, z):
        return 50 + self.s * x, FOOT + self.s * (y * K - z)

    def pt(self, u, w, z):
        x, y = self.g(u, w)
        return self.p(x, y, z)

    def box(self, u0, w0, z0, L, T, H, color, outline, texture=None, top=None):
        """A box L long, T thick, H high, its middle at (u0, w0), its foot at z0."""
        _, depth = self.g(u0, w0)
        self.items.append((depth, lambda a: self._box(a, u0, w0, z0, L, T, H, color, outline, texture, top)))

    def _box(self, a, u0, w0, z0, L, T, H, color, outline, texture, top):
        corners = [(-L / 2, -T / 2), (L / 2, -T / 2), (L / 2, T / 2), (-L / 2, T / 2)]
        normals = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        for i in range(4):
            (ua, wa), (ub, wb) = corners[i], corners[(i + 1) % 4]
            nu, nw = normals[i]
            nx, ny = nu * self.c - nw * self.sn, nu * self.sn + nw * self.c
            if ny <= 1e-6:
                continue  # facing away
            # lit from the upper left: brighter the more it faces left
            k = 0.78 - 0.32 * nx - 0.12 * ny
            face = mix(color, "#FFFFFF", k - 0.7) if k > 0.7 else mix(color, "#000000", 0.7 - k)
            quad = [
                self.pt(u0 + ua, w0 + wa, z0),
                self.pt(u0 + ub, w0 + wb, z0),
                self.pt(u0 + ub, w0 + wb, z0 + H),
                self.pt(u0 + ua, w0 + wa, z0 + H),
            ]
            a.parts.append(f'<path d="{poly(quad)}" fill="{face}" stroke="{outline}" stroke-width="{a.ow:.2f}" stroke-linejoin="round"/>')
            if texture:
                length = math.hypot(ub - ua, wb - wa)
                texture(a, lambda t, z, ua=ua, wa=wa, ub=ub, wb=wb: self.pt(u0 + ua + (ub - ua) * t, w0 + wa + (wb - wa) * t, z0 + z), length, H)
        lid = [self.pt(u0 + u, w0 + w, z0 + H) for u, w in corners]
        a.parts.append(f'<path d="{poly(lid)}" fill="{top or mix(color, "#FFFFFF", 0.22)}" stroke="{outline}" stroke-width="{a.ow:.2f}" stroke-linejoin="round"/>')

    def bar(self, u, w, z0, z1, width, color, outline):
        """An upright bar (an iron rod): a line from z0 to z1."""
        _, depth = self.g(u, w)
        self.items.append((depth, lambda a: self._bar(a, u, w, z0, z1, width, color, outline)))

    def _bar(self, a, u, w, z0, z1, width, color, outline):
        (x0, y0), (x1, y1) = self.pt(u, w, z0), self.pt(u, w, z1)
        a.line(f"M {x0:.2f} {y0:.2f} L {x1:.2f} {y1:.2f}", outline, width + a.ow * 1.4)
        a.line(f"M {x0:.2f} {y0:.2f} L {x1:.2f} {y1:.2f}", color, width)
        a.fill(f"M {x1 - width:.2f} {y1:.2f} L {x1:.2f} {y1 - width * 2.2:.2f} L {x1 + width:.2f} {y1:.2f} Z", color)

    def rail(self, u0, u1, w, z, width, color, outline):
        """A horizontal bar from u0 to u1."""
        _, depth = self.g((u0 + u1) / 2, w)
        self.items.append((depth + 0.001, lambda a: self._rail(a, u0, u1, w, z, width, color, outline)))

    def _rail(self, a, u0, u1, w, z, width, color, outline):
        (x0, y0), (x1, y1) = self.pt(u0, w, z), self.pt(u1, w, z)
        a.line(f"M {x0:.2f} {y0:.2f} L {x1:.2f} {y1:.2f}", outline, width + a.ow * 1.4)
        a.line(f"M {x0:.2f} {y0:.2f} L {x1:.2f} {y1:.2f}", color, width)

    def draw(self, a):
        for _, fn in sorted(self.items, key=lambda it: it[0]):
            fn(a)

    def shadow(self, a, half_u, half_w):
        """A soft shadow on the ground round its footprint."""
        pts = [self.pt(u, w, 0) for u in (-half_u, half_u) for w in (-half_w, half_w)]
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        a.shadow((min(xs) + max(xs)) / 2 + 2, (min(ys) + max(ys)) / 2 + 2, (max(xs) - min(xs)) / 2 + 6, (max(ys) - min(ys)) / 2 + 4, 0.3)


def _canvas(units):
    a = Art(120, units)
    a.tall = True
    return a


def _svg_tall(a):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="120" height="{int(120 * TALL / 100)}" viewBox="0 0 100 {TALL}">'
        + "<defs>" + "".join(a.defs) + "</defs>" + "".join(a.parts) + "</svg>"
    )


BRICK, BRICK_L, BRICK_O, MORTAR = "#D8744A", "#EE9A6C", "#8A3E22", "#F2D7B8"


def _top_bricks(a, sc, L, T, H):
    """The wall's top: a course of bricks laid along it."""
    (x0, y0), (x1, y1) = sc.pt(-L / 2, 0, H), sc.pt(L / 2, 0, H)
    a.line(f"M {x0:.2f} {y0:.2f} L {x1:.2f} {y1:.2f}", MORTAR, a.ow * 1.1, 0.9)
    u = -L / 2 + 0.26
    while u < L / 2 - 0.04:
        for w0, w1 in ((-T / 2, 0), (0, T / 2)):
            (x0, y0), (x1, y1) = sc.pt(u + (0.13 if w0 < 0 else 0), w0, H), sc.pt(u + (0.13 if w0 < 0 else 0), w1, H)
            a.line(f"M {x0:.2f} {y0:.2f} L {x1:.2f} {y1:.2f}", MORTAR, a.ow * 1.1, 0.9)
        u += 0.26


def _bricks(a, at, length, height):
    """Mortar lines on a wall's face: courses, and staggered joints between."""
    rows = 5
    for r in range(1, rows):
        (x0, y0), (x1, y1) = at(0, height * r / rows), at(1, height * r / rows)
        a.line(f"M {x0:.2f} {y0:.2f} L {x1:.2f} {y1:.2f}", MORTAR, a.ow * 1.1, 0.9)
    brick = 0.26
    for r in range(rows):
        z0, z1 = height * r / rows, height * (r + 1) / rows
        off = brick / 2 if r % 2 else 0
        u = off + brick
        while u < length - 0.04:
            t = u / length
            (x0, y0), (x1, y1) = at(t, z0), at(t, z1)
            a.line(f"M {x0:.2f} {y0:.2f} L {x1:.2f} {y1:.2f}", MORTAR, a.ow * 1.1, 0.9)
            u += brick


def wall(k):
    """A short brick wall across the trail (it crumbles once someone gets over it)."""
    size = 1.55
    a = _canvas(size)
    sc = Scene(size, k * math.pi / TURNS)
    L, T, H = 1.18, 0.3, 0.56
    sc.shadow(a, 0.62, 0.18)
    # a couple of bricks fallen at its foot
    sc.box(-0.36, 0.34, 0, 0.14, 0.08, 0.06, BRICK, BRICK_O, top=BRICK_L)
    sc.box(0.44, 0.3, 0, 0.12, 0.08, 0.06, BRICK, BRICK_O, top=BRICK_L)
    sc.box(0, 0, 0, L, T, H, BRICK, BRICK_O, texture=_bricks, top=BRICK_L)
    sc.items.append((99, lambda a: _top_bricks(a, sc, L, T, H)))
    sc.draw(a)
    return _svg_tall(a)


STONE, STONE_O = "#B5AE9F", "#6F695D"
IRON, IRON_L, IRON_O = "#454A57", "#7A8194", "#22252C"
GOLD, GOLD_D = "#F2C23A", "#B5841E"


def gate(k):
    """A locked iron gate between two stone posts, across the trail."""
    size = 1.5
    a = _canvas(size)
    yaw = k * math.pi / TURNS
    sc = Scene(size, yaw)
    sc.shadow(a, 0.66, 0.16)
    for u in (-0.52, 0.52):
        sc.box(u, 0, 0, 0.2, 0.2, 0.74, STONE, STONE_O)
        sc.box(u, 0, 0.74, 0.26, 0.26, 0.08, mix(STONE, "#FFFFFF", 0.15), STONE_O)
    for i in range(5):
        sc.bar(-0.3 + i * 0.15, 0, 0, 0.62, 2.0, IRON_L, IRON_O)
    for z in (0.12, 0.5):
        sc.rail(-0.42, 0.42, 0, z, 2.2, IRON_L, IRON_O)
    sc.draw(a)
    # the padlock, hanging on the side that faces you
    side = 1 if math.cos(yaw) >= 0 else -1
    x, y = sc.pt(0, 0.05 * side, 0.34)
    a.line(f"M {x - 3} {y - 1} C {x - 3} {y - 7}, {x + 3} {y - 7}, {x + 3} {y - 1}", "#7E6A3A", a.ow * 2)
    a.shape(f"M {x - 4.5} {y - 1.5} L {x + 4.5} {y - 1.5} L {x + 4.5} {y + 6} L {x - 4.5} {y + 6} Z", GOLD, outline=GOLD_D)
    a.fill(circ(x, y + 2, 1.1), "#5A3E0C")
    return _svg_tall(a)


WOOD, WOOD_D, WOOD_O = "#B98A5A", "#8A5E36", "#5E3E22"
LEAF_TURNS = 16  # a leaf leans one way: all the way round
LEAF_RISE = math.radians(64)  # how steeply it's raised


def _v(a, b, t=1.0):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _box_faces(c, ex, ey, ez, color, outline):
    """A box's six faces from its corner `c` and its three edges, each with its outward
    way: [(quad, normal, colour, outline, kind)]."""
    def add(p, q):
        return tuple(p[i] + q[i] for i in range(3))

    def neg(q):
        return tuple(-v for v in q)

    def unit(q):
        n = math.sqrt(sum(v * v for v in q)) or 1
        return tuple(v / n for v in q)

    c1 = add(add(add(c, ex), ey), ez)  # the far corner
    out = []
    for e1, e2, n, base in ((ex, ey, neg(ez), c), (ex, ey, ez, add(c, ez)), (ex, ez, neg(ey), c), (ex, ez, ey, add(c, ey)), (ey, ez, neg(ex), c), (ey, ez, ex, add(c, ex))):
        quad = [base, add(base, e1), add(add(base, e1), e2), add(base, e2)]
        out.append((quad, unit(n), color, outline, "side"))
    del c1
    return out


def leaf(k):
    """One leaf of a raised drawbridge: the deck of its tile swung up on its hinge at the
    bank, leaning out over the gap towards k x 22.5 degrees, planked, with iron bands, a
    post at each end of the hinge and chains from the posts' tops to its tip."""
    size = 2.6
    a = _canvas(size)
    s_ = 100 / size
    foot = 92

    def P(x, y, z):
        return 50 + s_ * x, foot + s_ * (y * K - z)

    t = k * 2 * math.pi / LEAF_TURNS
    px, py = math.cos(t), math.sin(t)  # the way it leans (along the trail)
    qx, qy = -py, px  # across the trail: the hinge
    W, Ln, Th = 1.3, 1.45, 0.14
    rise = (px * math.cos(LEAF_RISE), py * math.cos(LEAF_RISE), math.sin(LEAF_RISE))
    nrm = (-px * math.sin(LEAF_RISE), -py * math.sin(LEAF_RISE), math.cos(LEAF_RISE))

    def corner(u, l, off=0.0):
        # u: -1..1 across, l: 0..1 hinge to tip, off: below the deck's top face
        return (
            qx * u * W / 2 + rise[0] * l * Ln - nrm[0] * off,
            qy * u * W / 2 + rise[1] * l * Ln - nrm[1] * off,
            rise[2] * l * Ln - nrm[2] * off + Th,
        )

    # the deck: a slab, its top face planked
    faces = _box_faces(corner(-1, 0, Th), tuple(qx * W * v for v in (1,)) + (qy * W, 0.0), tuple(rise[i] * Ln for i in range(3)), tuple(nrm[i] * Th for i in range(3)), WOOD, WOOD_O)
    deck = [corner(-1, 0), corner(1, 0), corner(1, 1), corner(-1, 1)]
    # the posts at the ends of the hinge
    posts = []
    for u in (-1.2, 1.2):
        bx, by = qx * u * W / 2, qy * u * W / 2
        top = (bx, by, 1.62)
        posts.append(top)
        faces += _box_faces((bx - 0.08, by - 0.08, 0), (0.16, 0, 0), (0, 0.16, 0), (0, 0, 1.62), "#8A6A44", "#4A3620")
        faces += _box_faces((bx - 0.11, by - 0.11, 1.62), (0.22, 0, 0), (0, 0.22, 0), (0, 0, 0.08), IRON_L, IRON_O)
    view = (0, 1, K)
    foot_pts = [P(p[0], p[1], 0) for p in deck] + [P(p[0], p[1], 0) for p in posts]
    xs, ys = [p[0] for p in foot_pts], [p[1] for p in foot_pts]
    a.shadow((min(xs) + max(xs)) / 2 + 2, (min(ys) + max(ys)) / 2 + 3, (max(xs) - min(xs)) / 2 + 5, (max(ys) - min(ys)) / 2 + 4, 0.3)
    shown = [f for f in faces if sum(f[1][m] * view[m] for m in range(3)) > 1e-6]

    def depth(f):
        return sum(p[1] + p[2] * K for p in f[0]) / len(f[0])

    shown.sort(key=depth)
    for quad, n, base, outline, _ in shown:
        light = 0.72 - 0.3 * n[0] - 0.1 * n[1] + 0.2 * n[2]
        color = mix(base, "#FFFFFF", light - 0.7) if light > 0.7 else mix(base, "#000000", 0.7 - light)
        pts = [P(*p) for p in quad]
        a.parts.append(f'<path d="{poly(pts)}" fill="{color}" stroke="{outline}" stroke-width="{a.ow:.2f}" stroke-linejoin="round"/>')
        # the deck's top: its boards and two iron bands
        if base == WOOD and abs(sum(n[m] * nrm[m] for m in range(3)) - 1) < 1e-3:
            a0, a1, b1, b0 = deck
            boards = 6
            for i in range(1, boards):
                p0, p1 = P(*_v(a0, a1, i / boards)), P(*_v(b0, b1, i / boards))
                a.line(f"M {p0[0]:.2f} {p0[1]:.2f} L {p1[0]:.2f} {p1[1]:.2f}", WOOD_D, a.ow * 1.1, 0.85)
            for l in (0.22, 0.8):
                p0, p1 = P(*_v(a0, b0, l)), P(*_v(a1, b1, l))
                a.line(f"M {p0[0]:.2f} {p0[1]:.2f} L {p1[0]:.2f} {p1[1]:.2f}", IRON, a.ow * 2.6, 0.95)
    # chains from the posts' tops to the tip's corners
    for top, u in zip(posts, (-1, 1)):
        p0, p1 = P(*top), P(*corner(u, 1))
        a.line(f"M {p0[0]:.2f} {p0[1]:.2f} L {p1[0]:.2f} {p1[1]:.2f}", "#2A2C34", a.ow * 2.2)
        a.parts.append(f'<path d="M {p0[0]:.2f} {p0[1]:.2f} L {p1[0]:.2f} {p1[1]:.2f}" fill="none" stroke="#9AA0AE" stroke-width="{a.ow * 1.2:.2f}" stroke-dasharray="1.6 1.2"/>')
    return _svg_tall(a)


STANDING = [("wall", wall), ("gate", gate)]


def sprites():
    out = []
    for name, base, draw in FACES:
        for shape in ("round", "square"):
            out.append((f"{name}_{shape}", _face(shape, base, draw)))
    for name, build in STANDING:
        for k in range(TURNS):
            if k != EDGE_ON:
                out.append((f"{name}_{k}", build(k)))
    for k in range(LEAF_TURNS):
        out.append((f"leaf_{k}", leaf(k)))
    return out
