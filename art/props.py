"""
The things that stand around the maps' trails, as illustrations, in one style shared
with the playing pieces: smooth shapes lit from the upper left, a thin outline in a
dark shade of each part's own colour, a soft shadow on the ground (or foam where it
meets the sea). tools/art.py calls sprites().

Every drawing is on a 100 x 100 canvas and stands on its bottom middle, like the code-
drawn props it replaces (MapProps), so the board places it the same way. `units` is
the prop's size on the board (BoardLayout.PropSize, or the landmark's size): outlines
are scaled by it, so every prop's line is about as thick on screen. A "<kind>_sea"
drawing is the one used when that prop stands in the water.
"""

INK = "#2A2830"


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def _hex(c):
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    ca, cb = _rgb(a), _rgb(b)
    return _hex(tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3)))


def circ(cx, cy, r):
    return f"M {cx - r} {cy} A {r} {r} 0 1 0 {cx + r} {cy} A {r} {r} 0 1 0 {cx - r} {cy} Z"


def ell(cx, cy, rx, ry):
    return f"M {cx - rx} {cy} A {rx} {ry} 0 1 0 {cx + rx} {cy} A {rx} {ry} 0 1 0 {cx - rx} {cy} Z"


class Art:
    def __init__(self, px, units):
        self.px = px
        self.ow = 3.0 / units  # outline width, in canvas units
        self.defs = []
        self.parts = []
        self.n = 0

    def _id(self, p):
        self.n += 1
        return f"{p}{self.n}"

    def grad(self, base, light=0.3, dark=0.32, x1=0.15, y1=0.0, x2=0.85, y2=1.0):
        gid = self._id("g")
        self.defs.append(
            f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
            f'<stop offset="0" stop-color="{mix(base, "#FFFFFF", light)}"/>'
            f'<stop offset="0.5" stop-color="{base}"/>'
            f'<stop offset="1" stop-color="{mix(base, "#000000", dark)}"/></linearGradient>'
        )
        return f"url(#{gid})"

    def shadow(self, cx, cy, rx, ry, a=0.28):
        self.glow(cx, cy, rx, ry, "#000000", a)

    def glow(self, cx, cy, rx, ry, color, a):
        """A soft spot of colour fading out to its edge (shadows, light, steam)."""
        gid = self._id("s")
        self.defs.append(
            f'<radialGradient id="{gid}"><stop offset="0" stop-color="{color}" stop-opacity="{a}"/>'
            f'<stop offset="0.55" stop-color="{color}" stop-opacity="{a * 0.55:.3f}"/>'
            f'<stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient>'
        )
        self.parts.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="url(#{gid})"/>')

    def shape(self, d, base, light=0.3, dark=0.32, outline=None, flat=False, opacity=1.0, **g):
        fill = base if flat else self.grad(base, light, dark, **g)
        line = outline or mix(base, INK, 0.62)
        op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
        self.parts.append(
            f'<path d="{d}" fill="{fill}"{op} stroke="{line}" stroke-width="{self.ow:.2f}" '
            'stroke-linejoin="round" stroke-linecap="round"/>'
        )

    def fill(self, d, color, opacity=1.0):
        """A detail inside a shape: no outline."""
        self.parts.append(f'<path d="{d}" fill="{color}" fill-opacity="{opacity}"/>')

    def line(self, d, color, width=None, opacity=1.0):
        w = width if width is not None else self.ow
        self.parts.append(
            f'<path d="{d}" fill="none" stroke="{color}" stroke-opacity="{opacity}" stroke-width="{w:.2f}" '
            'stroke-linecap="round" stroke-linejoin="round"/>'
        )

    def group(self, transform="", clip=None, opacity=1.0):
        attrs = ""
        if transform:
            attrs += f' transform="{transform}"'
        if clip:
            cid = self._id("c")
            self.defs.append(f'<clipPath id="{cid}"><path d="{clip}"/></clipPath>')
            attrs += f' clip-path="url(#{cid})"'
        if opacity < 1:
            attrs += f' opacity="{opacity}"'
        self.parts.append(f"<g{attrs}>")

    def end(self):
        self.parts.append("</g>")

    def svg(self):
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.px}" height="{self.px}" viewBox="0 0 100 100">'
            + "<defs>" + "".join(self.defs) + "</defs>" + "".join(self.parts) + "</svg>"
        )


# shared inks
WOOD, WOOD_D, WOOD_L = "#A8703C", "#6E4520", "#C99563"
BARK, BARK_D = "#7A5A3E", "#4E3826"
LEAF, LEAF_D, LEAF_L = "#4FA548", "#2F7334", "#86C860"
SWAMP, SWAMP_D, SWAMP_L = "#4C8A3E", "#2F5E2C", "#7DB35A"
STONE, STONE_L, STONE_D = "#9C9586", "#C3BCAC", "#6F695D"
BASALT, BASALT_L, BASALT_D = "#4A3E38", "#6E5F56", "#2E2624"
IRON, IRON_L = "#3C3C46", "#6B6B78"
SAIL, ROPE = "#F3EAD3", "#8A6A44"
STRAW, STRAW_D = "#E3BE68", "#B8913E"
LAVA, LAVA_GLOW = "#F2541B", "#FFC23A"
CAVE = "#2E2A26"
FOAM = "#FFFFFF"


def foam(a, x0, x1, y, n=4):
    """Water lapping at something standing in it."""
    seg = (x1 - x0) / n
    d = f"M {x0} {y}"
    for i in range(n):
        xa = x0 + seg * i
        d += f" C {xa + seg * 0.25} {y - 2.4}, {xa + seg * 0.75} {y - 2.4}, {xa + seg} {y}"
    a.line(d, FOAM, a.ow * 1.6, 0.85)


def ripple(a, cx, cy, rx, ry):
    """A ring on still water."""
    a.parts.append(
        f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="none" stroke="{FOAM}" '
        f'stroke-opacity="0.55" stroke-width="{a.ow * 1.2:.2f}"/>'
    )


# ---------------------------------------------------------------------------
# the island (Blissful Tricks), and things every map shares
# ---------------------------------------------------------------------------


def palm(units=1.9):
    a = Art(192, units)
    a.shadow(52, 95, 15, 3.4)
    # fronds behind the trunk
    a.shape("M 57 38 C 46 39, 34 48, 25 63 C 36 53, 47 46, 59 42 Z", LEAF_D, 0.1, 0.25)
    a.shape("M 61 38 C 73 41, 83 51, 89 66 C 80 56, 70 47, 59 43 Z", LEAF_D, 0.1, 0.25)
    # the trunk, leaning a little, ringed
    a.shape("M 43 96 C 44 78, 47 58, 54 37 L 60.5 38.5 C 54.5 58, 52.5 78, 53.5 96 Z", WOOD, 0.25, 0.35, x1=0, y1=0.5, x2=1, y2=0.5)
    for y, l, r in ((88, 43.6, 53.0), (79, 44.7, 52.8), (70, 46.1, 53.0), (61, 48.0, 53.9), (52, 50.2, 55.6), (44, 52.4, 57.8)):
        a.line(f"M {l + 0.4} {y} C {l + 2.5} {y + 1.4}, {r - 2.5} {y + 1.4}, {r - 0.4} {y - 0.4}", WOOD_D, a.ow * 0.8, 0.7)
    for cx, cy, r in ((55, 41.5, 3.2), (61.5, 42.5, 3.1), (58.2, 45.4, 2.9)):
        a.shape(circ(cx, cy, r), "#7A5230", 0.3, 0.3)
    # the front fronds, and their midribs
    a.shape("M 58 35 C 46 26, 30 30, 19 50 C 30 39, 45 37, 58 39.5 Z", LEAF, 0.32, 0.25)
    a.shape("M 59.5 35 C 72 26, 87 32, 93 52 C 84 40, 72 37, 60 39.5 Z", LEAF, 0.32, 0.25)
    a.shape("M 57 34 C 51 22, 41 15, 29 17 C 40 22, 48 28, 55.5 37.5 Z", LEAF, 0.38, 0.2)
    a.shape("M 59.5 34 C 66 22, 76 15, 86 16 C 77 21, 69 28, 61.5 37.5 Z", LEAF, 0.38, 0.2)
    for d in ("M 57 37.5 C 45 33, 31 36, 21 48.5", "M 60.5 37.5 C 73 33, 85 38, 91 50", "M 56.3 35.5 C 50 25, 41 19, 31 17.5", "M 60.6 35.5 C 67 25, 75 19, 84 16.5"):
        a.line(d, LEAF_D, a.ow * 0.7, 0.75)
    return a.svg()


def _leaf(x0, y0, x1, y1, w):
    """A pointed leaf from (x0, y0) out to its tip at (x1, y1), `w` wide."""
    dx, dy = x1 - x0, y1 - y0
    n = (dx * dx + dy * dy) ** 0.5 or 1
    nx, ny = -dy / n * w, dx / n * w
    mx, my = x0 + dx * 0.45, y0 + dy * 0.45
    return f"M {x0} {y0} Q {mx + nx:.1f} {my + ny:.1f} {x1} {y1} Q {mx - nx:.1f} {my - ny:.1f} {x0} {y0} Z"


def bush(units=1.1):
    """A low tropical shrub: long pointed leaves fanning out from its foot."""
    a = Art(160, units)
    a.shadow(50, 90, 36, 5, 0.28)
    for tips, color, light in (
        (((16, 50), (84, 48), (50, 26)), LEAF_D, 0.15),
        (((26, 36), (74, 34), (8, 68), (92, 66)), LEAF, 0.3),
        (((36, 46), (64, 44), (22, 78), (78, 78), (50, 52)), mix(LEAF, LEAF_L, 0.5), 0.35),
    ):
        for tx, ty in tips:
            a.shape(_leaf(50, 89, tx, ty, 7.5), color, light, 0.25)
            a.line(f"M 50 89 L {50 + (tx - 50) * 0.8:.1f} {89 + (ty - 89) * 0.8:.1f}", mix(color, INK, 0.35), a.ow * 0.6, 0.6)
    return a.svg()


def _rocks(a, foot=0.0):
    """A boulder and a smaller one in front of it: a lit top, a shaded flank, feet that
    curve with the ground."""
    y = foot
    a.shape(f"M 14 {84 + y} C 11 {74 + y}, 15 {62 + y}, 25 {55 + y} C 31 {50 + y}, 38 {45 + y}, 48 {44 + y} C 58 {43 + y}, 68 {46 + y}, 75 {53 + y} "
            f"C 80 {58 + y}, 82 {66 + y}, 81 {74 + y} C 80 {80 + y}, 78 {84 + y}, 76 {87 + y} C 60 {93 + y}, 30 {93 + y}, 14 {84 + y} Z", STONE, 0.22, 0.3)
    a.fill(f"M 25 {55 + y} C 31 {50 + y}, 38 {45 + y}, 48 {44 + y} C 58 {43 + y}, 68 {46 + y}, 75 {53 + y} C 66 {57 + y}, 52 {59 + y}, 38 {60 + y} C 32 {60 + y}, 28 {58 + y}, 25 {55 + y} Z", STONE_L, 0.85)
    a.fill(f"M 75 {53 + y} C 80 {58 + y}, 82 {66 + y}, 81 {74 + y} C 80 {80 + y}, 78 {84 + y}, 76 {87 + y} C 72 {88.6 + y}, 69 {89.5 + y}, 66 {90 + y} C 70 {80 + y}, 71 {66 + y}, 68 {56 + y} Z", STONE_D, 0.45)
    a.line(f"M 46 {61 + y} L 43 {70 + y} L 47 {78 + y}", STONE_D, a.ow * 0.8, 0.55)
    a.shape(f"M 64 {90 + y} C 62 {83 + y}, 66 {76 + y}, 74 {74 + y} C 82 {72 + y}, 90 {76 + y}, 91 {83 + y} C 92 {88 + y}, 89 {91 + y}, 85 {92 + y} C 78 {94 + y}, 69 {94 + y}, 64 {90 + y} Z", STONE, 0.22, 0.3)
    a.fill(f"M 66 {79 + y} C 69 {75 + y}, 76 {73 + y}, 82 {74 + y} C 86 {75 + y}, 89 {77 + y}, 90 {80 + y} C 84 {81 + y}, 74 {81 + y}, 66 {79 + y} Z", STONE_L, 0.85)
    a.fill(f"M 88 {78 + y} C 91 {81 + y}, 92 {86 + y}, 89 {90 + y} C 87 {91.5 + y}, 85 {92 + y}, 83 {92.5 + y} C 86 {88 + y}, 87 {83 + y}, 88 {78 + y} Z", STONE_D, 0.45)


def rock(units=1.0):
    a = Art(160, units)
    a.shadow(54, 90, 42, 6, 0.3)
    _rocks(a)
    return a.svg()


def rock_sea(units=1.0):
    """The same rocks standing in the sea, the water lapping white round their feet."""
    a = Art(160, units)
    _rocks(a, -3)
    a.line("M 9 85 C 12 90, 22 92.5, 32 92.6 M 40 92.4 C 50 93, 58 92.8, 64 92.2", FOAM, a.ow * 1.6, 0.9)
    a.line("M 66 89.5 C 74 91.4, 84 91, 92 87", FOAM, a.ow * 1.6, 0.9)
    a.line("M 4 92 C 8 95, 16 96.5, 24 96.6 M 74 96 C 82 95.6, 90 94, 95 91", FOAM, a.ow * 1.1, 0.6)
    return a.svg()

def _barrel_upright(a, base_y):
    t = base_y - 58
    a.shape(f"M 30 {t} C 26 {t + 18}, 26 {t + 40}, 30 {base_y} L 70 {base_y} C 74 {t + 40}, 74 {t + 18}, 70 {t} Z", WOOD, 0.3, 0.35, x1=0, y1=0.5, x2=1, y2=0.5)
    a.shape(f"M 30 {t} C 30 {t - 4}, 70 {t - 4}, 70 {t} C 70 {t + 4}, 30 {t + 4}, 30 {t} Z", WOOD_L, 0.15, 0.2)
    for y in (t + 12, t + 46):
        a.shape(f"M 28.3 {y} C 40 {y + 3}, 60 {y + 3}, 71.7 {y} L 71.9 {y + 4.5} C 60 {y + 7.5}, 40 {y + 7.5}, 28.1 {y + 4.5} Z", "#59606B", 0.3, 0.3)
    for x in (40, 50, 60):
        a.line(f"M {x} {t + 3} L {x} {t + 11} M {x} {t + 21} L {x} {t + 44} M {x} {t + 55} L {x} {base_y}", WOOD_D, a.ow * 0.6, 0.5)


def barrel(units=0.8):
    a = Art(160, units)
    a.shadow(50, 91, 26, 4)
    _barrel_upright(a, 90)
    return a.svg()


def barrel_sea(units=0.8):
    """Afloat on its side, bobbing."""
    a = Art(160, units)
    a.group(clip="M 0 0 L 100 0 L 100 87 L 0 87 Z")
    a.group("rotate(-8 50 80)")
    a.shape("M 24 90 C 22 82, 22 70, 26 62 L 74 62 C 78 70, 78 82, 76 90 Z", WOOD, 0.3, 0.35)
    a.shape(ell(25, 76, 5.5, 14), WOOD_L, 0.15, 0.25)
    a.line("M 25 69 L 25 83 M 21.5 72 L 21.5 80", WOOD_D, a.ow * 0.6, 0.5)
    for x in (38, 62):
        a.shape(f"M {x - 2.5} 61 C {x - 4} 70, {x - 4} 82, {x - 2.5} 91 L {x + 2.5} 91 C {x + 1} 82, {x + 1} 70, {x + 2.5} 61 Z", "#59606B", 0.3, 0.3)
    a.end()
    a.end()
    foam(a, 12, 90, 87.5)
    return a.svg()


def gull(units=0.8):
    a = Art(160, units)
    a.shadow(50, 92, 14, 2.6, 0.18)
    grey = "#B9C2CC"
    line = mix(grey, INK, 0.5)
    a.shape("M 47 53 C 42 44, 37 40, 31 39 C 24 39, 17 42, 11 48 C 21 46, 29 47, 35 50 C 40 52, 43 55, 45 57 Z", "#FFFFFF", 0.0, 0.18, outline=line)
    a.shape("M 53 53 C 58 44, 63 40, 69 39 C 76 39, 83 42, 89 48 C 79 46, 71 47, 65 50 C 60 52, 57 55, 55 57 Z", "#FFFFFF", 0.0, 0.18, outline=line)
    a.fill("M 11 48 C 15 44.5, 19 42.4, 23 41.2 C 22 44, 21 45.5, 19.5 46.4 C 16.5 46.4, 13.5 47, 11 48 Z", grey)
    a.fill("M 89 48 C 85 44.5, 81 42.4, 77 41.2 C 78 44, 79 45.5, 80.5 46.4 C 83.5 46.4, 86.5 47, 89 48 Z", grey)
    a.shape(ell(50, 56, 9, 4.6), "#FFFFFF", 0.0, 0.15, outline=line)
    a.shape("M 57.5 55.5 L 63.5 56.6 L 57.5 58.2 Z", "#F0A030", 0.2, 0.2)
    return a.svg()


def hut(units=1.8):
    a = Art(192, units)
    a.shadow(50, 93, 34, 4)
    a.shape("M 31 92 L 31 63 L 69 63 L 69 92 Z", WOOD, 0.25, 0.32)
    for x in (39, 47, 55, 63):
        a.line(f"M {x} 66 L {x} 92", WOOD_D, a.ow * 0.6, 0.45)
    a.shape("M 43 92 L 43 76 C 43 71, 55 71, 55 76 L 55 92 Z", "#3A2A1E", 0.1, 0.1)
    # the thatch, hanging down past the walls
    a.shape("M 16 68 C 28 55, 39 41, 50 27 C 61 41, 72 55, 84 68 C 74 71, 62 70, 50 71 C 38 70, 26 71, 16 68 Z", STRAW, 0.3, 0.3)
    for d in ("M 50 31 L 30 66", "M 50 31 L 40 68", "M 50 31 L 60 68", "M 50 31 L 70 66"):
        a.line(d, STRAW_D, a.ow * 0.7, 0.7)
    return a.svg()


def skullrock(units=2.4):
    """A crag the sea and wind have worn into a skull: a lumpy dome with a ledge for a
    brow, two hollows for eyes, a notch for a nose and a low cave of a mouth hung with
    rock teeth; sand heaped at its foot."""
    a = Art(320, units)
    sand, sand_d = "#E9C27A", "#C99A52"
    a.shadow(52, 91, 48, 7, 0.32)
    body = ("M 9 88 C 5 79, 6 68, 11 60 C 12 52, 16 45, 21 40 C 23 33, 29 26, 37 23 C 43 19, 50 17, 57 18 "
            "C 64 18, 70 20, 75 24 C 81 27, 86 33, 88 40 C 91 44, 93 50, 93 56 C 95 64, 95 74, 92 81 "
            "C 92 84, 91 86, 90 88 C 72 95.5, 28 95.5, 9 88 Z")
    a.shape(body, STONE, 0.22, 0.3)
    a.group(clip=body)
    # the lit dome, the shaded flank, the brow ledge and the cheek under each eye
    a.fill("M 11 60 C 12 52, 16 45, 21 40 C 23 33, 29 26, 37 23 C 43 19, 50 17, 57 18 C 64 18, 70 20, 75 24 "
           "C 81 27, 86 33, 88 40 C 72 35, 50 35, 30 41 C 22 44, 15 50, 11 60 Z", STONE_L, 0.75)
    a.fill("M 88 40 C 91 44, 93 50, 93 56 C 95 64, 95 74, 92 81 C 91 85, 88 89, 80 92 C 85 78, 87 60, 83 46 Z", STONE_D, 0.42)
    a.fill("M 12 58 C 28 49, 70 47, 92 55 L 92 58.5 C 70 51.5, 30 53, 12 62.5 Z", STONE_D, 0.3)
    a.line("M 14 56.5 C 30 48, 70 46, 91 53.5", STONE_L, a.ow * 1.0, 0.7)
    a.fill("M 20 76 C 26 73, 36 74, 42 77 C 36 78.5, 26 78.5, 20 76 Z M 58 74.5 C 64 72, 72 72, 78 74 C 72 76, 64 76.5, 58 74.5 Z", STONE_L, 0.35)
    # weathering
    a.line("M 60 21 L 57 29 L 61 35 L 58 41", STONE_D, a.ow * 0.9, 0.55)
    a.line("M 84 62 L 87 70 L 85 77", STONE_D, a.ow * 0.8, 0.45)
    a.end()
    # the hollows: darkest at the top, under the brow
    hollow = mix(STONE, INK, 0.72)
    for d in (
        "M 21 64 C 19 58, 24 53.5, 30 54 L 37 53 C 42 54, 46 58, 45 63 C 45 68, 42 72, 36 73 L 29 72.5 C 24 71, 22 68, 21 64 Z",
        "M 55 61 C 55 56, 59 52.5, 65 52.5 L 71 53.5 C 76 55, 78.5 59, 77 64 C 76 68.5, 72 71, 67 71 L 61 70.5 C 57 69.5, 55 65.5, 55 61 Z",
        "M 45.5 77 C 46 73.5, 48.5 71, 50.2 71 C 52 71, 54.4 73.6, 55 77 C 52.5 78.6, 48 78.6, 45.5 77 Z",
    ):
        a.shape(d, "#3A322B", 0.12, 0.6, outline=hollow, x1=0, y1=1, x2=0, y2=0)
    # the mouth, and its teeth: rock hanging into it, no two alike
    a.shape("M 25 85 C 35 81.5, 64 80.5, 77 84.5 C 75 88.6, 70 90.8, 64 91.4 L 37 91.8 C 31 90.8, 27 88.4, 25 85 Z", "#3A322B", 0.12, 0.6, outline=hollow, x1=0, y1=1, x2=0, y2=0)
    for x0, w, h in ((32, 5.5, 3.6), (39.5, 6.5, 6.4), (48.5, 5, 4.2), (55, 7, 6.8), (64.5, 5.5, 4.4), (71, 4, 2.6)):
        a.shape(f"M {x0} 83.4 L {x0 + w} 83.1 C {x0 + w * 0.7:.1f} {83.2 + h * 0.6:.1f}, {x0 + w * 0.6:.1f} {83.3 + h:.1f}, {x0 + w * 0.45:.1f} {83.3 + h:.1f} C {x0 + w * 0.3:.1f} {83.3 + h * 0.6:.1f}, {x0 + 0.4} 84.5, {x0} 83.4 Z",
                mix(STONE, STONE_L, 0.3), 0.15, 0.3)
    # moss on the dome
    a.fill("M 32 27 C 38 22, 48 20, 56 21 C 50 24, 42 26, 36 30 C 34 30, 32 29, 32 27 Z", "#7CB257", 0.9)
    a.fill("M 74 27 C 78 29, 82 32, 84 36 C 80 34, 76 32, 73 30 Z", "#7CB257", 0.8)
    # sand heaped against its foot, and a stone or two
    a.shape("M 0 92 C 4 85, 14 83, 22 88 C 18 93, 6 94, 0 92 Z", sand, 0.25, 0.2, outline=sand_d)
    a.shape("M 80 92 C 84 86, 94 85, 100 89 C 98 94, 86 95, 80 92 Z", sand, 0.25, 0.2, outline=sand_d)
    a.shape("M 88 95 C 87 92, 90 90, 93 90.5 C 96 91, 97 93.5, 96 95.5 C 93 96.5, 90 96.5, 88 95 Z", STONE, 0.22, 0.3)
    return a.svg()

def _rigged_ship(a, hull, sail, flag, tatter=False, sail_opacity=1.0):
    a.shape("M 37.5 70 L 37.5 13 L 40.5 13 L 40.5 70 Z", WOOD_D, 0.2, 0.2)
    a.shape("M 62.5 70 L 62.5 21 L 65.5 21 L 65.5 70 Z", WOOD_D, 0.2, 0.2)
    a.line("M 39 13 L 12 58 M 64 21 L 90 56", ROPE, a.ow * 0.8, 0.8)
    if tatter:
        sails = (
            "M 27 18 C 33 16, 46 16, 52 18 C 50 26, 50 30, 51 36 L 47 33 L 44 39 L 40 35 L 35 39 L 31 34 L 27 38 C 25 31, 25 25, 27 18 Z",
            "M 24 43 C 32 41, 48 41, 55 43 C 53 51, 53 56, 54 62 L 49 58 L 45 63 L 39 58 L 34 63 L 29 59 L 24 62 C 21 56, 21 50, 24 43 Z",
            "M 55 26 C 60 24, 70 24, 74 26 C 72.6 33, 72.6 38, 73.5 43 L 69 40 L 65 44 L 61 40 L 55 43 C 53.6 38, 53.6 32, 55 26 Z",
            "M 52 48 C 58 46, 72 46, 77 48 C 75.6 54, 75.6 58, 76.5 63 L 71 59 L 67 63.5 L 62 59 L 57 63 L 52 60 C 50.4 56, 50.4 52, 52 48 Z",
        )
    else:
        sails = (
            "M 27 18 C 33 16, 46 16, 52 18 C 50 26, 50 34, 52 40 C 46 38, 33 38, 27 40 C 25 33, 25 25, 27 18 Z",
            "M 24 43 C 32 41, 48 41, 55 43 C 53 51, 53 58, 55 64 C 48 62, 32 62, 24 64 C 21 57, 21 50, 24 43 Z",
            "M 55 26 C 60 24, 70 24, 74 26 C 72.6 33, 72.6 40, 74 45 C 70 43.5, 60 43.5, 55 45 C 53.6 39, 53.6 32, 55 26 Z",
            "M 52 48 C 58 46, 72 46, 77 48 C 75.6 54, 75.6 59, 77 64 C 72 62.5, 58 62.5, 52 64 C 50.4 59, 50.4 53, 52 48 Z",
        )
    for d in sails:
        a.shape(d, sail, 0.2, 0.18, opacity=sail_opacity)
    a.shape("M 40.5 6 L 54 8 L 50.5 11 L 54 14 L 40.5 13 Z", flag, 0.25, 0.2)
    a.fill(circ(47.2, 9.4, 1.6), "#F3EAD3")
    a.shape("M 8 66 L 80 66 L 88 58 L 95 58 C 94 70, 88 82, 76 88 L 24 88 C 15 84, 10 76, 8 66 Z", hull, 0.22, 0.34)
    a.shape("M 8 66 L 0 57 L 2 56 L 12 66 Z", WOOD_D, 0.2, 0.2)


def ship(units=3.8):
    a = Art(320, units)
    _rigged_ship(a, "#7B4A27", SAIL, "#2B2A33")
    a.fill("M 10 71 L 89 71 C 88.6 73, 88 74.4, 87.4 75.6 L 12 75.6 C 11.2 74.2, 10.6 72.6, 10 71 Z", "#E3B341", 0.95)
    for x in (22, 34, 46, 58, 70):
        a.shape(f"M {x} 78.5 L {x + 5} 78.5 L {x + 5} 82.5 L {x} 82.5 Z", "#2B2A33", 0.1, 0.1)
    foam(a, 14, 86, 89)
    return a.svg()


def wreck(units=3.0):
    """A ship's bow sticking up out of the sea, its mast snapped."""
    a = Art(320, units)
    hull = "#6E4626"
    a.group(clip="M 0 0 L 100 0 L 100 87 L 0 87 Z")
    a.group("rotate(-24 50 86) translate(4 12)")
    a.shape("M 6 60 L 78 60 C 86 60, 92 61, 96 63 C 92 74, 82 82, 66 84 L 16 84 C 10 80, 7 72, 6 60 Z", hull, 0.22, 0.34)
    a.fill("M 8 65 L 92 65 C 91.4 66.6, 90.6 68, 89.6 69.4 L 9 69.4 C 8.5 68, 8.2 66.6, 8 65 Z", "#C9A04A", 0.9)
    # a hole in the side, its ribs showing
    a.shape("M 40 72 C 44 68, 54 68, 58 72 C 60 76, 56 81, 49 81 C 42 81, 38 76, 40 72 Z", CAVE, 0.05, 0.1)
    a.line("M 45 69.5 L 44.5 81 M 51 69 L 51 81.2 M 56 70.6 L 55.4 80", hull, a.ow * 1.3)
    # the mast, snapped, and what's left of a sail
    a.shape("M 58 60 L 59.5 26 L 62 24 L 63 30 L 64.5 27 L 63.6 60 Z", WOOD_D, 0.2, 0.2)
    a.shape("M 61.5 34 L 80 36 C 79 43, 77 48, 79 54 L 74 51 L 71 56 L 68 50 L 63.4 53 Z", SAIL, 0.2, 0.18)
    a.end()
    a.end()
    foam(a, 6, 74, 88)
    return a.svg()


def dock(units=3.2):
    """Seen from above (it lies flat): weathered planks across two beams, a post at each
    corner and one halfway."""
    a = Art(320, units)
    a.shape("M 0 33 L 100 33 L 100 67 L 0 67 Z", WOOD_D, 0.05, 0.2)
    for i, x in enumerate(range(1, 99, 7)):
        tone = mix(WOOD_L, WOOD, (0.0, 0.35, 0.15)[i % 3])
        nudge = (0.0, 0.8, -0.6, 0.4)[i % 4]
        a.shape(f"M {x} {30.5 + nudge} L {x + 6} {30.5 + nudge} L {x + 6} {69.5 + nudge} L {x} {69.5 + nudge} Z", tone, 0.2, 0.25, outline=mix(WOOD_D, INK, 0.25))
        a.fill(circ(x + 3, 35 + nudge, 0.7) + " " + circ(x + 3, 65 + nudge, 0.7), WOOD_D, 0.8)
    for x in (4, 50, 96):
        for y in (27.5, 72.5):
            a.shape(circ(x, y, 4.8), WOOD, 0.35, 0.3)
            a.parts.append(f'<circle cx="{x}" cy="{y}" r="2.6" fill="none" stroke="{WOOD_D}" stroke-width="{a.ow * 0.7:.2f}" stroke-opacity="0.6"/>')
    return a.svg()


# ---------------------------------------------------------------------------
# the fort (Junction Jam)
# ---------------------------------------------------------------------------


def crate(units=0.8):
    a = Art(160, units)
    a.shadow(52, 92, 30, 4)
    a.shape("M 22 92 L 22 56 L 64 56 L 64 92 Z", WOOD, 0.25, 0.3)
    a.shape("M 64 92 L 64 56 L 78 47 L 78 83 Z", mix(WOOD, "#000000", 0.25), 0.1, 0.2)
    a.shape("M 22 56 L 36 47 L 78 47 L 64 56 Z", WOOD_L, 0.15, 0.15)
    # the frame and the brace across the front
    a.line("M 26 60 L 60 60 L 60 88 L 26 88 Z", WOOD_D, a.ow * 0.8, 0.6)
    a.line("M 27 87 L 59 61", WOOD_D, a.ow * 1.6, 0.6)
    return a.svg()


def torch(units=1.0):
    a = Art(160, units)
    a.shadow(50, 93, 14, 3)
    a.glow(50, 26, 26, 22, LAVA_GLOW, 0.35)
    a.shape("M 46.5 93 L 47.5 44 L 52.5 44 L 53.5 93 Z", WOOD, 0.25, 0.3, x1=0, y1=0.5, x2=1, y2=0.5)
    a.shape("M 39 36 L 61 36 C 60 42, 56 46, 50 46 C 44 46, 40 42, 39 36 Z", IRON, 0.35, 0.3)
    a.shape("M 50 6 C 56 15, 63 21, 62 30 C 61 35, 56 38, 50 38 C 44 38, 39 35, 38.5 30 C 38 24, 42 20, 44.5 15 C 45.5 19, 47 21, 49 22 C 48 16, 48 11, 50 6 Z", LAVA, 0.35, 0.15)
    a.fill("M 50 20 C 53.5 25, 56.5 28, 56 32 C 55.5 35, 53 36.6, 50 36.6 C 47 36.6, 44.5 35, 44.3 32 C 44 29, 46.5 27, 48 24.5 C 48.5 26.5, 49.2 27.4, 50.4 27.6 C 49.6 25, 49.4 22.5, 50 20 Z", LAVA_GLOW)
    return a.svg()


def cannon(units=1.3):
    a = Art(160, units)
    a.shadow(50, 92, 36, 4)
    # the carriage, then the barrel resting on it, then the near wheel
    a.shape("M 22 88 L 24 72 L 46 66 L 66 70 L 72 88 Z", WOOD, 0.25, 0.32)
    a.shape("M 16 58 C 15 52, 19 48, 24 48.5 L 80 52 C 83 52.3, 84 54, 84 56 L 84 66 C 84 68, 83 69.7, 80 70 L 24 71.5 C 19 72, 15 66, 16 58 Z", IRON, 0.35, 0.3)
    a.shape("M 82 50.5 L 90 50.5 L 90 71.5 L 82 71.5 Z", IRON, 0.35, 0.3)
    a.fill(ell(90, 61, 1.6, 7.5), "#15151A")
    a.line("M 40 50 L 40 70.6 M 64 51.5 L 64 69.6", IRON_L, a.ow * 0.9, 0.6)
    a.shape(circ(13.5, 60, 4), IRON, 0.35, 0.3)
    a.shape(circ(50, 80, 11), WOOD_D, 0.3, 0.25)
    a.shape(circ(50, 80, 3.4), IRON, 0.3, 0.3)
    a.line("M 50 70 L 50 90 M 40 80 L 60 80", mix(WOOD_D, INK, 0.3), a.ow * 0.9, 0.7)
    return a.svg()


def keep(units=2.6):
    a = Art(320, units)
    a.shadow(50, 94, 34, 4.5)
    a.shape("M 29 93 L 31 38 L 69 38 L 71 93 Z", STONE, 0.3, 0.35, x1=0, y1=0.5, x2=1, y2=0.5)
    # the parapet and its merlons
    a.shape("M 25 40 L 25 27 L 33 27 L 33 32 L 41 32 L 41 27 L 49 27 L 49 32 L 57 32 L 57 27 L 65 27 L 65 32 L 75 32 L 75 27 L 75 40 Z", STONE, 0.3, 0.35, x1=0, y1=0.5, x2=1, y2=0.5)
    for y in (50, 62, 74, 86):
        a.line(f"M {31.2 - (y - 38) * 0.036:.2f} {y} L {68.8 + (y - 38) * 0.036:.2f} {y}", STONE_D, a.ow * 0.6, 0.45)
    a.shape("M 43 93 L 43 79 C 43 72, 57 72, 57 79 L 57 93 Z", "#5A3A22", 0.15, 0.2)
    a.shape("M 47.5 56 C 47.5 52, 52.5 52, 52.5 56 L 52.5 64 L 47.5 64 Z", CAVE, 0.05, 0.1)
    # its flag
    a.shape("M 49 27 L 49 6 L 51 6 L 51 27 Z", WOOD_D, 0.2, 0.2)
    a.shape("M 51 7 C 57 5, 61 9, 68 7 L 68 17 C 61 19, 57 15, 51 17 Z", "#D64545", 0.3, 0.25)
    return a.svg()


def flag(units=2.0):
    a = Art(256, units)
    a.shadow(42, 94, 16, 3)
    a.shape("M 32 94 C 32 88, 36 85, 42 85 C 48 85, 52 88, 52 94 Z", STONE, 0.25, 0.3)
    a.shape("M 40.5 86 L 40.5 12 L 43.5 12 L 43.5 86 Z", WOOD, 0.25, 0.3, x1=0, y1=0.5, x2=1, y2=0.5)
    a.shape(circ(42, 10, 3), "#E2B53D", 0.35, 0.3)
    a.shape("M 43.5 15 C 53 12, 61 19, 72 15 C 76 14, 79 13, 82 12 L 82 40 C 79 41, 76 42, 72 43 C 61 47, 53 40, 43.5 43 Z", "#2B2A33", 0.25, 0.2)
    # skull and crossed bones
    bone = "#F3EAD3"
    a.line("M 54 36 L 70 24 M 54 24 L 70 36", bone, a.ow * 2.2)
    a.fill("M 56.5 27 C 56.5 21.5, 67.5 21.5, 67.5 27 C 67.5 29.5, 66 30.6, 64.6 31 L 64.6 32.6 L 59.4 32.6 L 59.4 31 C 58 30.6, 56.5 29.5, 56.5 27 Z", bone)
    a.fill(circ(59.6, 27, 1.5) + " " + circ(64.4, 27, 1.5), "#2B2A33")
    return a.svg()


# ---------------------------------------------------------------------------
# the swamp (Slimy Swamp)
# ---------------------------------------------------------------------------


def _clump(cx, cy, r, n=7, phase=0.0):
    """A clump of leaves: a round shape with a scalloped, leafy edge."""
    import math

    pts = []
    for k in range(n):
        a0 = phase + k * 2 * math.pi / n
        a1 = a0 + math.pi / n
        pts.append(((cx + math.cos(a0) * r, cy + math.sin(a0) * r), (cx + math.cos(a1) * r * 1.22, cy + math.sin(a1) * r * 1.22)))
    d = f"M {pts[0][0][0]:.1f} {pts[0][0][1]:.1f}"
    for k in range(n):
        (_, (qx, qy)), ((nx, ny), _) = pts[k], pts[(k + 1) % n]
        d += f" Q {qx:.1f} {qy:.1f} {nx:.1f} {ny:.1f}"
    return d + " Z"


def mangrove(units=2.0):
    a = Art(256, units)
    a.shadow(50, 93, 34, 5, 0.3)
    # stilt roots arching into the mud, the trunk, then the canopy: clumps of leaves,
    # the ones behind darker, each lit from the upper left
    for d in ("M 47 66 C 38 68, 28 78, 24 93", "M 48 70 C 42 76, 39 84, 38 93", "M 52 70 C 58 76, 61 84, 62 93", "M 53 66 C 62 68, 72 78, 76 93"):
        a.line(d, mix(BARK, INK, 0.55), a.ow * 3.4)
        a.line(d, BARK, a.ow * 1.6)
    a.shape("M 45 72 C 46 60, 46 50, 44 40 L 56 40 C 54 50, 54 60, 55 72 Z", BARK, 0.25, 0.3, x1=0, y1=0.5, x2=1, y2=0.5)
    for cx, cy, r, tone, light in (
        (28, 34, 12, SWAMP_D, 0.15), (72, 32, 13, SWAMP_D, 0.15), (50, 22, 13, SWAMP_D, 0.15),
        (18, 46, 10, SWAMP, 0.3), (82, 46, 10, SWAMP, 0.3), (38, 30, 13, SWAMP, 0.3), (62, 28, 13, SWAMP, 0.3),
        (34, 47, 12, SWAMP, 0.35), (66, 46, 12, SWAMP, 0.35), (50, 40, 14, mix(SWAMP, SWAMP_L, 0.35), 0.35),
    ):
        a.shape(_clump(cx, cy, r, 7, cx * 0.07), tone, light, 0.3)
        a.fill(ell(cx - r * 0.3, cy - r * 0.38, r * 0.42, r * 0.24), SWAMP_L, 0.55)
    return a.svg()

def _reeds(a, base):
    for d in (
        f"M 46 {base} C 44 {base - 20}, 38 {base - 40}, 30 {base - 50}",
        f"M 49 {base} C 48 {base - 20}, 46 {base - 40}, 44 {base - 64}",
        f"M 53 {base} C 55 {base - 20}, 60 {base - 40}, 68 {base - 50}",
        f"M 51 {base} C 52 {base - 20}, 55 {base - 40}, 58 {base - 58}",
    ):
        a.line(d, mix(SWAMP, INK, 0.5), a.ow * 2.6)
        a.line(d, SWAMP_L, a.ow * 1.2)
    # two cattails on their stalks
    for x0, foot, top in ((40, 47, base - 56), (60, 53, base - 62)):
        a.line(f"M {foot} {base} C {foot + (x0 - foot) * 0.4} {base - 20}, {x0} {top + 20}, {x0} {top}", mix(SWAMP_D, INK, 0.3), a.ow * 1.2)
        a.shape(
            f"M {x0 - 2.8} {top + 12} C {x0 - 3.2} {top + 6}, {x0 - 2.4} {top + 2}, {x0} {top + 1} C {x0 + 2.4} {top + 2}, {x0 + 3.2} {top + 6}, {x0 + 2.8} {top + 12} "
            f"C {x0 + 2} {top + 14}, {x0 - 2} {top + 14}, {x0 - 2.8} {top + 12} Z",
            "#7A5230", 0.3, 0.3,
        )


def reeds(units=1.0):
    a = Art(160, units)
    a.shadow(50, 93, 18, 3)
    _reeds(a, 93)
    return a.svg()


def reeds_sea(units=1.0):
    a = Art(160, units)
    _reeds(a, 90)
    ripple(a, 50, 90, 22, 4)
    return a.svg()


def log(units=1.3):
    a = Art(192, units)
    a.shadow(50, 92, 40, 4)
    a.shape("M 22 70 L 80 68 C 86 68, 88 79, 86 84 C 85 88, 83 90, 80 90 L 22 91 Z", BARK, 0.25, 0.32, x1=0.5, y1=0, x2=0.5, y2=1)
    a.line("M 32 74 C 44 73, 56 73, 70 72 M 28 84 C 40 85, 58 84, 74 84", BARK_D, a.ow * 0.7, 0.55)
    # a broken-off branch, a tuft of moss, and the cut end showing its rings
    a.shape("M 56 69 L 58 60 L 62 59 L 63 68.5 Z", BARK, 0.25, 0.3)
    a.fill("M 36 70.6 C 38 67, 44 66.4, 47 69.8 Z", SWAMP_L, 0.95)
    a.shape(ell(22, 80.5, 7.5, 10.5), "#D9B27A", 0.2, 0.2, outline=mix(BARK, INK, 0.62))
    a.parts.append(f'<ellipse cx="22" cy="80.5" rx="4.4" ry="6.4" fill="none" stroke="#A8783E" stroke-width="{a.ow * 0.8:.2f}"/>')
    a.fill(ell(22, 80.5, 1.5, 2.2), "#A8783E")
    return a.svg()


def stump(units=0.9):
    a = Art(160, units)
    a.shadow(50, 92, 30, 4)
    a.shape("M 26 92 C 30 88, 31 84, 31 76 L 31 62 L 69 62 L 69 76 C 69 84, 70 88, 74 92 Z", BARK, 0.25, 0.32, x1=0, y1=0.5, x2=1, y2=0.5)
    a.line("M 40 66 L 39 88 M 58 66 L 59 88", BARK_D, a.ow * 0.7, 0.5)
    a.shape(ell(50, 62, 19, 6), "#D9B27A", 0.2, 0.2, outline=mix(BARK, INK, 0.62))
    a.parts.append(f'<ellipse cx="50" cy="62" rx="11" ry="3.4" fill="none" stroke="#A8783E" stroke-width="{a.ow * 0.8:.2f}"/>')
    a.fill(ell(50, 62, 3.6, 1.2), "#A8783E")
    return a.svg()


def lily(units=0.9):
    a = Art(160, units)
    ripple(a, 50, 82, 38, 9)
    a.shape("M 50 80 L 63 70 C 77 71, 86 77, 86 82 C 86 89, 70 93, 50 93 C 30 93, 14 89, 14 82 C 14 75, 30 70, 46 70 Z", "#5BAF4C", 0.25, 0.25)
    a.line("M 50 80 L 26 86 M 50 80 L 50 91 M 50 80 L 74 86", "#3F8A3A", a.ow * 0.8, 0.6)
    pink, pink_d = "#F2A3C4", "#D9708F"
    for d in ("M 50 78 C 44 74, 42 67, 44 62 C 48 66, 50 72, 50 78 Z", "M 50 78 C 56 74, 58 67, 56 62 C 52 66, 50 72, 50 78 Z", "M 50 78 C 47 72, 47 63, 50 58 C 53 63, 53 72, 50 78 Z"):
        a.shape(d, pink, 0.3, 0.15, outline=mix(pink_d, INK, 0.4))
    return a.svg()


def sunken(units=3.2):
    """An old ship gone down in the swamp: its stern and a leaning mast still above it."""
    a = Art(320, units)
    hull = "#5E4630"
    a.group(clip="M 0 0 L 100 0 L 100 84 L 0 84 Z")
    a.group("rotate(-5 50 84)")
    a.group("rotate(-12 46 84)")
    a.line("M 46 26 L 16 84", ROPE, a.ow * 0.8, 0.7)
    a.shape("M 43 86 L 44.5 22 L 48 22 L 49 86 Z", WOOD_D, 0.2, 0.2)
    a.shape("M 38 24 L 54 24 L 52 30 L 40 30 Z", WOOD, 0.25, 0.25)
    a.shape("M 48 34 L 67 36 C 66 43, 64 48, 66 55 L 61 52 L 58 57 L 55 51 L 49 53 Z", SAIL, 0.2, 0.18)
    a.end()
    a.shape("M 6 92 L 8 79 L 62 78 L 63 66 L 92 65 L 94 92 Z", hull, 0.22, 0.34)
    a.line("M 10 81 L 62 80.4 M 64 69 L 91 68.4", "#2E2218", a.ow * 0.9, 0.6)
    a.shape("M 72 71 L 79 71 L 79 76 L 72 76 Z", "#E3B341", 0.2, 0.3)
    # moss on the rails
    a.fill("M 18 78.8 C 21 75.8, 27 75.8, 30 78.6 Z M 66 66 C 70 63, 76 63, 79 65.6 Z", SWAMP_L, 0.95)
    a.end()
    a.end()
    ripple(a, 50, 85, 46, 5)
    foam(a, 4, 96, 84.5, 6)
    return a.svg()


def deadtree(units=2.2):
    a = Art(256, units)
    a.shadow(50, 94, 26, 3.5)
    bark = "#6B5A4E"
    a.shape(
        "M 38 94 C 42 88, 44 80, 45 70 C 46 60, 44 52, 40 44 C 34 38, 26 36, 18 30 L 20 27 C 28 31, 36 34, 42 39 "
        "C 43 32, 41 24, 36 16 L 39 14 C 45 22, 47 30, 47 38 C 50 32, 56 28, 62 22 C 66 18, 70 14, 72 9 L 75 11 "
        "C 73 17, 69 22, 64 27 C 58 33, 53 40, 52 48 C 56 46, 62 46, 70 42 C 76 39, 80 36, 84 32 L 86 35 "
        "C 82 40, 77 44, 71 47 C 63 51, 56 52, 53 56 C 53 66, 55 80, 62 94 Z",
        bark, 0.25, 0.3,
    )
    a.fill(ell(49, 72, 2.4, 4), "#2E2622")
    return a.svg()


# ---------------------------------------------------------------------------
# the haunted cove (Haunted Hollow)
# ---------------------------------------------------------------------------


def grave(units=0.9):
    a = Art(160, units)
    a.shape("M 20 93 C 24 84, 40 81, 52 81 C 66 81, 78 85, 82 93 Z", "#5A4A3C", 0.2, 0.3)
    a.group("rotate(5 50 88)")
    a.shape("M 32 88 L 32 48 C 32 34, 68 34, 68 48 L 68 88 Z", STONE, 0.3, 0.35)
    a.fill("M 48 50 L 52 50 L 52 56 L 58 56 L 58 60 L 52 60 L 52 74 L 48 74 L 48 60 L 42 60 L 42 56 L 48 56 Z", STONE_D, 0.7)
    a.end()
    a.fill("M 26 92 C 27 88, 29 86, 31 85.5 C 31 88, 32 90, 33 92 Z M 70 92 C 71 88.5, 73 87, 75 86.5 C 74.6 89, 75 91, 76 92 Z", "#5E7A48", 0.95)
    return a.svg()


def pumpkin(units=0.85):
    a = Art(160, units)
    a.shadow(50, 92, 30, 4)
    orange, orange_d = "#EE8A2E", "#B8601A"
    a.shape("M 50 56 C 30 52, 16 62, 16 75 C 16 87, 30 92, 50 92 C 70 92, 84 87, 84 75 C 84 62, 70 52, 50 56 Z", orange, 0.3, 0.32)
    a.line("M 38 56.5 C 31 65, 31 84, 38 91.5 M 62 56.5 C 69 65, 69 84, 62 91.5 M 50 57 L 50 92", orange_d, a.ow * 0.9, 0.55)
    a.shape("M 47 57 C 47 52, 48 48, 51 44 L 55 46 C 53 49, 52.5 53, 53 57 Z", "#5E7A3A", 0.25, 0.25)
    # the face, lit from inside
    glow = "#FFD35C"
    a.fill("M 32 70 L 40 64 L 42 73 Z M 68 70 L 60 64 L 58 73 Z", glow)
    a.fill("M 32 78 L 38 80 L 41 77 L 46 81 L 50 78 L 54 81 L 59 77 L 62 80 L 68 78 C 66 85, 58 88, 50 88 C 42 88, 34 85, 32 78 Z", glow)
    return a.svg()


def lamp(units=1.2):
    a = Art(192, units)
    a.shadow(50, 94, 14, 3)
    a.glow(50, 30, 30, 28, "#FFD35C", 0.42)
    a.shape("M 42 94 L 44 88 L 56 88 L 58 94 Z", STONE, 0.25, 0.3)
    a.shape("M 48.4 88 L 48.4 40 L 51.6 40 L 51.6 88 Z", IRON, 0.35, 0.3)
    a.shape("M 41 40 L 59 40 L 56 44 L 44 44 Z", IRON, 0.35, 0.3)
    a.shape("M 43 40 L 42 24 L 58 24 L 57 40 Z", "#FFE08A", 0.3, 0.1, outline=mix(IRON, INK, 0.4))
    a.line("M 50 24 L 50 40", IRON, a.ow * 0.9)
    a.shape("M 39 24 L 50 15 L 61 24 Z", IRON, 0.35, 0.3)
    a.shape(circ(50, 13.5, 2.2), IRON, 0.35, 0.3)
    return a.svg()


def fence(units=1.1):
    a = Art(160, units)
    a.shadow(50, 93, 38, 3.5)
    wood = "#8A7A68"
    a.shape("M 12 66 L 88 62 L 88 67 L 12 71 Z", wood, 0.25, 0.3)
    a.shape("M 12 82 L 88 79 L 88 84 L 12 87 Z", wood, 0.25, 0.3)
    for x, top, lean in ((20, 52, 0), (40, 50, 0), (60, 54, 6), (80, 49, 0)):
        a.group(f"rotate({lean} {x} 92)" if lean else "")
        a.shape(f"M {x - 5} 92 L {x - 5} {top + 6} L {x} {top} L {x + 5} {top + 6} L {x + 5} 92 Z", wood, 0.25, 0.3)
        a.end()
    return a.svg()


def mist(units=1.3):
    a = Art(160, units)
    for cx, cy, rx, ry, op in ((38, 76, 30, 10, 0.55), (62, 72, 30, 11, 0.6), (50, 64, 22, 9, 0.5), (74, 80, 20, 7, 0.45), (26, 82, 18, 6, 0.4)):
        a.glow(cx, cy, rx, ry, "#DDE6F0", op)
    return a.svg()


def crypt(units=2.8):
    a = Art(320, units)
    a.shadow(50, 94, 40, 4.5)
    a.shape("M 16 94 L 18 88 L 82 88 L 84 94 Z", STONE_D, 0.25, 0.3)
    a.shape("M 22 88 L 22 48 L 78 48 L 78 88 Z", STONE, 0.3, 0.35, x1=0, y1=0.5, x2=1, y2=0.5)
    a.shape("M 16 49 L 50 24 L 84 49 Z", STONE, 0.35, 0.3)
    a.fill("M 30 46 L 50 31 L 70 46 Z", STONE_D, 0.35)
    for x in (27, 67):
        a.shape(f"M {x} 88 L {x} 52 L {x + 6} 52 L {x + 6} 88 Z", STONE_L, 0.25, 0.25)
    a.shape("M 39 88 L 39 64 C 39 56, 61 56, 61 64 L 61 88 Z", "#3A3644", 0.15, 0.2)
    a.line("M 50 60 L 50 88", "#24222C", a.ow * 0.9, 0.8)
    # a cross on the roof
    a.shape("M 48.5 24 L 48.5 10 L 44 10 L 44 7 L 48.5 7 L 48.5 3 L 51.5 3 L 51.5 7 L 56 7 L 56 10 L 51.5 10 L 51.5 24 Z", STONE, 0.3, 0.3)
    a.fill("M 28 50 C 31 47.6, 35 47.6, 38 50 Z M 70 50 C 72 48, 75 48, 77 50 Z", "#5E7A48", 0.9)
    return a.svg()


def ghostship(units=3.8):
    a = Art(320, units)
    a.glow(50, 50, 52, 44, "#9FE8D6", 0.22)
    a.group(opacity=0.92)
    _rigged_ship(a, "#3E5A66", "#CFE8E2", "#24343C", tatter=True, sail_opacity=0.85)
    for x in (22, 34, 46, 58, 70):
        a.fill(f"M {x} 78.5 L {x + 5} 78.5 L {x + 5} 82.5 L {x} 82.5 Z", "#B6F2E2", 0.8)
    a.end()
    foam(a, 14, 86, 89)
    return a.svg()


# ---------------------------------------------------------------------------
# the volcano (Mount Kaboom)
# ---------------------------------------------------------------------------


def lavarock(units=1.0):
    """Two chunks of basalt, split by glowing cracks."""
    a = Art(160, units)
    a.glow(52, 90, 44, 7, LAVA, 0.38)
    big = "M 16 86 L 13 71 L 23 57 L 41 50 L 58 54 L 67 66 L 65 82 L 59 89 C 45 92.5, 27 91.5, 16 86 Z"
    a.shape(big, BASALT, 0.25, 0.3)
    a.group(clip=big)
    a.fill("M 23 57 L 41 50 L 58 54 L 51 60.5 L 30 62.5 Z", BASALT_L, 0.75)
    a.fill("M 58 54 L 67 66 L 65 82 L 59 89 L 55 74 L 51 60.5 Z", BASALT_D, 0.55)
    for d in ("M 12 74 L 22 71 L 29 76 L 38 73 L 46 78 L 54 75", "M 30 62.5 L 33 68 L 29 76"):
        a.line(d, LAVA, a.ow * 1.9)
        a.line(d, LAVA_GLOW, a.ow * 0.7)
    a.end()
    small = "M 60 90 L 62 77 L 72 69 L 84 71 L 91 80 L 87 90 C 79 93, 67 93, 60 90 Z"
    a.shape(small, BASALT, 0.25, 0.3)
    a.group(clip=small)
    a.fill("M 62 77 L 72 69 L 84 71 L 78 76 L 66 78.5 Z", BASALT_L, 0.75)
    a.fill("M 84 71 L 91 80 L 87 90 L 81 91.5 L 82 80 L 78 76 Z", BASALT_D, 0.55)
    a.line("M 64 84 L 71 82 L 76 86 L 82 84", LAVA, a.ow * 1.6)
    a.line("M 64 84 L 71 82 L 76 86 L 82 84", LAVA_GLOW, a.ow * 0.6)
    a.end()
    return a.svg()


def charred(units=1.4):
    """A tree the lava burnt: a blackened trunk, two snapped branches, embers at the ends."""
    a = Art(192, units)
    a.shadow(50, 91, 22, 4, 0.3)
    coal, coal_l = "#3A3330", "#5E524C"
    trunk = ("M 36 91 C 40 88, 43 82, 44 72 C 45 60, 44 50, 40 40 L 33 31 L 38 28 L 45 37 "
             "C 46 30, 46 24, 44 16 L 49 15 C 52 23, 53 31, 52 40 C 55 35, 59 31, 65 27 L 68 31 "
             "C 62 35, 58 41, 56 48 C 55 60, 56 76, 59 84 C 61 88, 64 90, 67 91 C 57 93.5, 45 93.5, 36 91 Z")
    a.shape(trunk, coal, 0.3, 0.3)
    a.group(clip=trunk)
    a.fill("M 36 91 C 40 88, 43 82, 44 72 C 45 60, 44 50, 41 42 L 46 44 C 48 54, 48 64, 47 74 C 46 84, 43 89, 40 92 Z", coal_l, 0.7)
    a.line("M 50 50 L 49 60 M 52 66 L 51 78 M 47 30 L 48 38", "#6E625A", a.ow * 0.8, 0.6)
    a.end()
    # still smouldering where the branches broke
    for cx, cy in ((35.5, 29.5), (46.5, 15.5), (66.5, 29)):
        a.glow(cx, cy, 6, 6, LAVA_GLOW, 0.5)
        a.fill(circ(cx, cy, 1.7), LAVA)
    return a.svg()


def vent(units=1.1):
    """A smoking vent: a low cone of ash with a glowing mouth."""
    a = Art(160, units)
    a.shadow(50, 90, 40, 5, 0.3)
    for cx, cy, r, op in ((52, 50, 14, 0.55), (46, 35, 12, 0.42), (54, 22, 10, 0.3)):
        a.glow(cx, cy, r, r, "#F4F1EC", op)
    cone = "M 10 88 C 18 80, 30 72, 40 67 L 60 67 C 70 72, 82 80, 90 88 C 72 94.5, 28 94.5, 10 88 Z"
    a.shape(cone, BASALT, 0.25, 0.3)
    a.group(clip=cone)
    a.fill("M 40 67 C 30 72, 18 80, 10 88 C 14 89.6, 19 90.8, 25 91.6 C 29 82, 35 74, 43 69 Z", BASALT_L, 0.55)
    a.fill("M 60 67 C 70 72, 82 80, 90 88 C 86 89.4, 81 90.6, 75 91.5 C 72 82, 66 74, 58 69 Z", BASALT_D, 0.5)
    a.end()
    a.glow(50, 66, 14, 6, LAVA_GLOW, 0.5)
    a.shape(ell(50, 67, 10.5, 3.4), "#1E1816", 0.0, 0.1, outline=mix(BASALT, INK, 0.6))
    a.fill(ell(50, 67.6, 6.4, 1.8), LAVA, 0.95)
    a.fill(ell(50, 67.8, 3.2, 0.9), LAVA_GLOW)
    return a.svg()


def volcano(units=5.2):
    a = Art(384, units)
    a.shadow(50, 95, 48, 4.5)
    # the smoke first (it rises behind the peak)
    for cx, cy, r, op in ((52, 22, 13, 0.55), (60, 12, 11, 0.45), (44, 10, 9, 0.35), (70, 4, 8, 0.3)):
        a.glow(cx, cy, r, r, "#8A8078", op)
    a.shape("M 2 95 C 14 80, 26 60, 36 40 C 39 34, 42 31, 46 31 L 56 31 C 60 31, 63 34, 66 40 C 76 60, 88 80, 98 95 Z", BASALT, 0.28, 0.35)
    a.fill("M 36 40 C 39 34, 42 31, 46 31 L 50 31 C 44 44, 34 62, 22 82 C 16 87, 10 91, 6 92 C 16 80, 26 60, 36 40 Z", BASALT_L, 0.55)
    a.shape(ell(51, 32, 9.5, 3), LAVA, 0.3, 0.1, outline=mix(BASALT, INK, 0.6))
    a.fill(ell(51, 31.6, 5.5, 1.4), LAVA_GLOW)
    # two streams down the front
    for d in ("M 47 33 C 46 42, 42 50, 40 58 C 38 66, 33 72, 30 80", "M 55 33 C 57 44, 62 52, 63 62 C 64 70, 68 76, 72 84"):
        a.line(d, LAVA, a.ow * 3.2)
        a.line(d, LAVA_GLOW, a.ow * 1.2)
    return a.svg()


# (name, drawing, its size on the board)
# ---------------------------------------------------------------------------
# the ice floes (Frostbite Floes)
# ---------------------------------------------------------------------------

SNOW, SNOW_L, SNOW_D = "#EEF4F8", "#FFFFFF", "#B7C8D8"
ICE, ICE_L, ICE_D = "#B4DDF0", "#E4F6FD", "#6CA6C8"
PINE, PINE_D = "#2F6B55", "#1E4A3B"
COAL = "#2B2A33"


def _snow(a, d):
    a.shape(d, SNOW, 0.35, 0.16, outline=SNOW_D)


def _tier(top, base, half):
    h = base - top
    return (f"M {50 - half} {base} C {50 - half * 0.62} {base - h * 0.3}, {50 - half * 0.3} {top + h * 0.35}, 50 {top} "
            f"C {50 + half * 0.3} {top + h * 0.35}, {50 + half * 0.62} {base - h * 0.3}, {50 + half} {base} "
            f"C {50 + half * 0.45} {base + 3}, {50 - half * 0.45} {base + 3}, {50 - half} {base} Z")


def _tiercap(top, base, half):
    h = (base - top) * 0.46
    y = top + h
    w = half * 0.5
    return (f"M 50 {top - 0.6} C {50 - w * 0.4} {top + h * 0.5}, {50 - w * 0.8} {y - h * 0.15}, {50 - w} {y} "
            f"Q {50 - w * 0.66} {y + 3.4}, {50 - w * 0.33} {y} Q 50 {y + 3.6}, {50 + w * 0.33} {y} Q {50 + w * 0.66} {y + 3.4}, {50 + w} {y} "
            f"C {50 + w * 0.8} {y - h * 0.15}, {50 + w * 0.4} {top + h * 0.5}, 50 {top - 0.6} Z")


def pine_snow(units=2.0):
    """A fir in the snow: three tiers of dark needles, snow heaped on each, a stub of
    trunk."""
    a = Art(192, units)
    a.shadow(50, 94, 24, 3.8)
    a.shape("M 46 95 L 46.5 82 L 53.5 82 L 54 95 Z", BARK, 0.25, 0.3)
    tiers = ((42, 84, 33), (23, 63, 26), (8, 42, 19))
    for top, base, half in tiers:
        a.shape(_tier(top, base, half), PINE, 0.22, 0.35)
        if top == 8:
            _snow(a, _tiercap(top, base, half))
        else:
            # snow lying out along the branches, below the tier above
            k = 0.74
            y = top + (base - top) * k
            w = half * k
            for side in (-1, 1):
                x = 50 + side * w * 0.6
                _snow(a, f"M {x - w * 0.42} {y + 1.2} C {x - w * 0.3} {y - 3.4}, {x + w * 0.3} {y - 3.8}, {x + w * 0.42} {y + 0.4} "
                         f"C {x + w * 0.2} {y + 2.6}, {x - w * 0.1} {y + 1.4}, {x - w * 0.42} {y + 1.2} Z")
    return a.svg()


def icerock(units=1.0):
    """Rocks with the snow lying on their tops."""
    a = Art(160, units)
    a.shadow(54, 90, 42, 6, 0.3)
    _rocks(a)
    _snow(a, "M 24 56 C 30 49, 40 44.4, 48 44.4 C 58 44.2, 68 47, 74.8 53 C 70.4 56.4, 65 55, 60 57.8 C 55.4 55.4, 50.4 58.6, 45 56.8 C 39.4 59, 33.6 56.2, 28.4 58.8 C 26.6 58.2, 25.2 57.2, 24 56 Z")
    _snow(a, "M 66.4 78.8 C 69.4 74.6, 76 72.6, 82 73.4 C 86.6 74.2, 89.6 76.6, 90.4 79.8 C 86.4 81.6, 82.4 79.6, 78.2 81.4 C 74 79.6, 70 81.2, 66.4 78.8 Z")
    return a.svg()


def snowman(units=1.3):
    """A snowman the crew built: an eye of coal and a patch over the other, a carrot of
    a nose, a red scarf, a captain's hat and twig arms."""
    a = Art(192, units)
    a.shadow(50, 93, 24, 4)
    a.line("M 34 56 L 21 46 M 25.6 49.4 L 22.8 43.8", BARK, a.ow * 1.6)
    a.line("M 66 56 L 80 49 M 75.2 51.4 L 80 53.6", BARK, a.ow * 1.6)
    a.shape(ell(50, 78, 22, 15.5), SNOW, 0.3, 0.2, outline=SNOW_D)
    a.shape(ell(50, 56, 16, 12), SNOW, 0.3, 0.2, outline=SNOW_D)
    a.shape(circ(50, 37, 10.6), SNOW, 0.3, 0.2, outline=SNOW_D)
    for y in (53, 59, 72, 80):
        a.fill(circ(50, y, 1.5), COAL)
    a.shape("M 39.4 45.6 C 44 48.6, 56 48.6, 60.6 45.6 L 61.2 49.6 C 56 52.6, 44 52.6, 38.8 49.6 Z", "#D64545", 0.25, 0.3)
    a.shape("M 55 49.4 L 59.6 62.6 L 55 63.2 L 51.6 50.6 Z", "#D64545", 0.25, 0.3)
    a.fill(circ(45.6, 35, 1.7), COAL)
    a.line("M 40.4 31.2 L 59.8 36.6", COAL, a.ow * 0.9)
    a.shape(ell(54.8, 35.4, 3.1, 2.7), COAL, flat=True)
    a.shape("M 50 38.4 L 60.4 41 L 50 41.6 Z", "#F08A24", 0.3, 0.2)
    a.shape("M 37.4 28 C 40 18.6, 60 18.6, 62.6 28 C 57 26.4, 43 26.4, 37.4 28 Z", COAL, 0.25, 0.2)
    a.shape("M 31.6 28.8 C 40 24.6, 60 24.6, 68.4 28.8 C 60 31, 40 31, 31.6 28.8 Z", "#3A3944", 0.25, 0.2)
    a.fill(circ(50, 23.4, 1.9), "#F3EAD3")
    return a.svg()


def igloo(units=2.2):
    """A snow-block igloo with its tunnel of a doorway."""
    a = Art(256, units)
    a.shadow(50, 92, 40, 5)
    dome = "M 12 90 C 12 62, 30 42, 52 42 C 74 42, 90 62, 88 90 Z"
    a.shape(dome, SNOW, 0.32, 0.22, outline=SNOW_D)
    a.group(clip=dome)
    for y in (53, 64, 76):
        a.line(f"M 0 {y} C 30 {y - 3}, 70 {y - 3}, 100 {y}", SNOW_D, a.ow * 0.8, 0.85)
    for x, y0, y1 in ((36, 42, 52), (60, 42, 52), (26, 52, 63), (48, 51, 62), (70, 52, 63), (18, 63, 75), (38, 62, 74),
                      (58, 62, 74), (78, 63, 75), (28, 75, 90), (66, 75, 90), (84, 75, 90)):
        a.line(f"M {x} {y0} L {x - 1} {y1}", SNOW_D, a.ow * 0.8, 0.85)
    a.end()
    a.shape("M 28 90 L 28 75 C 28 64, 52 64, 52 75 L 52 90 Z", SNOW, 0.3, 0.2, outline=SNOW_D)
    a.shape("M 33.6 90 L 33.6 77.6 C 33.6 70.6, 46.4 70.6, 46.4 77.6 L 46.4 90 Z", "#2C3A4A", 0.1, 0.2)
    return a.svg()


def iceberg(units=1.8):
    """A berg riding the sea: white peaks lit from the left, blue in their shade."""
    a = Art(192, units)
    body = "M 8 86 L 19 58 L 29 63 L 42 25 L 54 49 L 63 39 L 77 63 L 92 86 Z"
    a.shape(body, ICE_L, 0.2, 0.22, outline=ICE_D)
    a.fill("M 42 25 L 54 49 L 51 86 L 41 86 L 47 52 Z", ICE, 0.95)
    a.fill("M 63 39 L 77 63 L 92 86 L 71 86 L 69 60 Z", ICE, 0.95)
    a.fill("M 42 25 L 35.4 43 L 40.4 45.4 L 44 34 Z", SNOW_L, 0.95)
    a.fill("M 19 58 L 14 72 L 18.4 73 L 21 63 Z", SNOW_L, 0.9)
    foam(a, 6, 94, 87)
    return a.svg()


def _floe(a, cx, cy, rx, ry):
    side = f"M {cx - rx} {cy} C {cx - rx} {cy + ry * 1.7}, {cx + rx} {cy + ry * 1.7}, {cx + rx} {cy} L {cx + rx} {cy + 4} C {cx + rx} {cy + ry * 1.7 + 4}, {cx - rx} {cy + ry * 1.7 + 4}, {cx - rx} {cy + 4} Z"
    a.shape(side, ICE, 0.2, 0.3, outline=ICE_D)
    a.shape(f"M {cx - rx} {cy} C {cx - rx * 0.9} {cy - ry * 1.4}, {cx + rx * 0.9} {cy - ry * 1.4}, {cx + rx} {cy} C {cx + rx * 0.9} {cy + ry * 1.4}, {cx - rx * 0.9} {cy + ry * 1.4}, {cx - rx} {cy} Z", SNOW, 0.35, 0.14, outline=SNOW_D)


def floe(units=1.3):
    """A flat cake of ice afloat, the water lapping its edge."""
    a = Art(160, units)
    _floe(a, 50, 76, 40, 8)
    a.fill(ell(38, 73, 16, 3.4), SNOW_L, 0.85)
    foam(a, 6, 94, 88.6)
    return a.svg()


def seal(units=1.3):
    """A seal hauled out on a little floe, tail and head up."""
    a = Art(160, units)
    _floe(a, 50, 80, 38, 7)
    grey, grey_l = "#8E9AA8", "#B7C1CC"
    a.shape("M 24 78 C 22 70, 34 64, 48 63 C 58 62, 64 58, 68 52 C 70 47, 77 45.6, 80 49.6 C 82.6 54, 79 60, 73 64 "
            "C 67 70, 56 75, 42 76.4 C 34 77, 26 79, 24 78 Z", grey, 0.3, 0.28)
    a.fill("M 30 75 C 40 74, 54 72, 64 66 C 60 71, 50 75.4, 40 76.4 C 35 76.8, 32 76.6, 30 75 Z", grey_l, 0.85)
    a.shape("M 26 76 L 14 70.4 L 15.4 79 Z", grey, 0.3, 0.3)
    a.shape("M 50 73 L 46.4 80 L 55 78.4 Z", grey, 0.3, 0.3)
    a.fill(circ(76.4, 50.6, 1.5), COAL)
    a.fill(circ(80.6, 52, 1.2), COAL)
    a.line("M 80 54 L 86 52.6 M 80 55 L 85.6 56", COAL, a.ow * 0.5, 0.7)
    foam(a, 8, 92, 92)
    return a.svg()


def frozenship(units=3.8):
    """A ship the sea froze round: snow on its yards and rail, icicles off its hull, the
    pack ice heaped about it."""
    a = Art(320, units)
    _rigged_ship(a, "#6E4A30", "#E6ECF0", COAL)
    for d in ("M 27 18 C 33 15, 46 15, 52 18 C 46 20.4, 33 20.4, 27 18 Z", "M 24 43 C 32 40, 48 40, 55 43 C 48 45.4, 32 45.4, 24 43 Z",
              "M 55 26 C 60 23.4, 70 23.4, 74 26 C 70 27.8, 60 27.8, 55 26 Z", "M 52 48 C 58 45.4, 72 45.4, 77 48 C 72 49.8, 58 49.8, 52 48 Z"):
        _snow(a, d)
    _snow(a, "M 7 66 L 80 66 L 88 58 L 95.4 58 C 95.4 60.4, 95 62, 94.4 63.4 L 89 63.4 L 81.4 70 L 9 70 Z")
    for x, h in ((20, 5), (30, 7), (42, 4.6), (56, 6.6), (68, 5), (78, 6)):
        a.shape(f"M {x - 1.8} 87.4 L {x + 1.8} 87.4 L {x} {87.4 + h} Z", ICE_L, 0.2, 0.2, outline=ICE_D)
    for cx, w, h in ((12, 12, 7), (34, 13, 5), (60, 13, 6), (86, 12, 7)):
        a.shape(f"M {cx - w} 95 L {cx - w * 0.45} {95 - h} L {cx + w * 0.3} {95 - h * 0.8} L {cx + w} 95 Z", ICE_L, 0.25, 0.25, outline=ICE_D)
    return a.svg()


# ---------------------------------------------------------------------------
# the reefs (Kraken's Reach)
# ---------------------------------------------------------------------------

KRAKEN, KRAKEN_D, KRAKEN_L = "#B5485E", "#6E2436", "#E08A98"
SUCKER = "#F6D2D2"
REEF_PINK, REEF_ORANGE = "#E86A8E", "#F28C3A"
BONE, BONE_D = "#F2EBDD", "#B5A992"
RUST = "#6B6E78"


def tentacle(units=1.8):
    """One of the Kraken's arms rising out of the sea and curling over at its tip,
    suckers up its inside."""
    a = Art(192, units)
    arm = ("M 34 90 C 30 70, 30 50, 40 34 C 48 22, 62 15, 73 21 C 82 26, 82 38, 73 43 "
           "C 66 46.6, 59.6 41, 62 34.6 C 63.6 30.6, 68.4 31, 68.6 34 C 63 30.6, 55 34.4, 52.4 44 C 50 56, 52 74, 56 90 Z")
    a.shape(arm, KRAKEN, 0.3, 0.32)
    a.fill("M 52.4 44 C 55 34.4, 63 30.6, 68.6 34 C 66.4 34.6, 64.6 36.4, 64 38.4 C 58.4 38.6, 55.4 43.4, 55 50 C 54.4 62, 55.4 76, 58 90 L 56 90 C 52 74, 50 56, 52.4 44 Z", KRAKEN_L, 0.85)
    for x, y, r in ((55.8, 82, 2.2), (54.8, 72, 2.2), (54.6, 62, 2.1), (55.6, 52.4, 2.0), (58.8, 44, 1.8), (63.4, 39.2, 1.5)):
        a.shape(circ(x, y, r), SUCKER, 0.25, 0.25, outline=KRAKEN_D)
    foam(a, 24, 70, 89)
    return a.svg()


def coral(units=1.2):
    """A clump of branching coral on the reef: a pink one and an orange one."""
    a = Art(160, units)
    a.shadow(50, 92, 34, 4.4)
    for d, base in (("M 38 92 L 38 72 L 29 58 M 38 76 L 46 62 L 44 48 M 31 61 L 26 48 M 45 54 L 52 46", REEF_PINK),
                    ("M 62 92 L 64 73 L 73 61 L 75 49 M 64 77 L 56 65 L 58 53 M 72 63 L 81 57", REEF_ORANGE)):
        a.line(d, mix(base, INK, 0.55), 7.6)
        a.line(d, base, 5.2)
        a.line(d, mix(base, "#FFFFFF", 0.4), 1.5, 0.75)
    return a.svg()


def barnacle(units=1.0):
    """Rocks crusted with barnacles, a starfish clinging on."""
    a = Art(160, units)
    a.shadow(54, 90, 42, 6, 0.3)
    _rocks(a)
    for x, y in ((31, 63), (37, 58.6), (34.6, 68), (60, 54.4), (66.4, 58), (71, 77), (78.6, 80.4), (44, 64)):
        a.shape(circ(x, y, 2.3), "#EDE6D6", 0.3, 0.3)
        a.fill(circ(x, y, 0.9), "#5A5248")
    import math
    pts = []
    for k in range(10):
        ang = -math.pi / 2 + k * math.pi / 5
        r = 7.4 if k % 2 == 0 else 3.2
        pts.append((50 + math.cos(ang) * r, 77 + math.sin(ang) * r))
    a.shape("M " + " L ".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z", REEF_ORANGE, 0.3, 0.3)
    return a.svg()


def mast(units=2.0):
    """A sunken ship's mast standing out of the sea: its yard askew, a rag of sail, the
    crow's nest."""
    a = Art(192, units)
    a.shape("M 47 90 L 48 22 L 53 20 L 54 90 Z", WOOD_D, 0.25, 0.25)
    a.shape("M 30 41 L 72 34.6 L 72.6 38.4 L 30.6 44.8 Z", WOOD_D, 0.25, 0.25)
    a.shape("M 33 44.4 L 68 39 C 66 48, 66 54, 68 62 L 62.6 58 L 58.6 64 L 53 58.6 L 47 64 L 41.6 58.6 L 35.6 63 C 33.6 55, 32.4 49, 33 44.4 Z", SAIL, 0.2, 0.18)
    a.shape("M 42 24.4 L 60 22 L 59.2 28.6 L 42.8 30.8 Z", WOOD, 0.25, 0.3)
    a.line("M 50.6 22 L 30.6 44 M 51 22 L 72 37", ROPE, a.ow * 0.7, 0.8)
    foam(a, 30, 72, 89)
    return a.svg()


def anchor(units=1.2):
    """A great anchor run aground, a fluke dug into the sand, its chain trailing off."""
    a = Art(160, units)
    a.shadow(50, 92, 32, 4)
    a.group("rotate(-14 50 72)")
    a.line(circ(50, 20, 5), RUST, 3.6)
    a.line(circ(50, 20, 5), mix(RUST, "#FFFFFF", 0.3), 1.2, 0.7)
    a.shape("M 47 25 L 53 25 L 53 82 L 47 82 Z", RUST, 0.3, 0.3)
    a.shape("M 35 33 L 65 33 L 65 38.4 L 35 38.4 Z", RUST, 0.3, 0.3)
    a.shape("M 27 62 C 30 78, 43 85, 50 85 C 57 85, 70 78, 73 62 L 79 57 L 77 69 C 71 86, 58 92, 50 92 C 42 92, 29 86, 23 69 L 21 57 Z", RUST, 0.3, 0.3)
    a.end()
    for i in range(5):
        a.line(ell(68 + i * 5.4, 90.6 - i * 0.5, 2.8, 1.7), RUST, a.ow * 1.5)
    return a.svg()


def bones(units=1.6):
    """A whale's ribs arching out of the sand, bleached white."""
    a = Art(192, units)
    a.shadow(50, 92, 40, 5, 0.22)
    for x, h, lean in ((22, 30, 6), (36, 40, 5), (52, 46, 3), (68, 40, 1), (82, 28, -1)):
        tip = 92 - h
        d = (f"M {x - 3} 92 C {x - 4} {92 - h * 0.6}, {x + lean} {tip}, {x + lean + 8} {tip + h * 0.08} "
             f"L {x + lean + 8.6} {tip + h * 0.08 + 3.4} C {x + lean + 3} {tip + 5}, {x + 2} {92 - h * 0.55}, {x + 3} 92 Z")
        a.shape(d, BONE, 0.25, 0.3, outline=BONE_D)
    a.shape("M 14 92 C 34 89, 66 89, 90 91 L 90 94.4 C 66 92.6, 34 92.6, 14 95.4 Z", BONE, 0.25, 0.3, outline=BONE_D)
    return a.svg()


def lighthouse(units=3.2):
    """A striped lighthouse on its rocks, its lamp lit."""
    a = Art(256, units)
    a.shadow(50, 93, 32, 4.4)
    a.shape("M 18 94 C 16 86, 25 80, 36 81 L 64 81 C 75 80, 84 86, 82 94 Z", STONE, 0.22, 0.3)
    tower = "M 38 83 L 42 31 L 58 31 L 62 83 Z"
    a.fill(tower, "#F4EFE6")
    a.group(clip=tower)
    for y0 in (40, 57, 74):
        a.fill(f"M 0 {y0} L 100 {y0 - 2} L 100 {y0 + 7} L 0 {y0 + 9} Z", "#D64545")
    a.fill("M 52 0 L 70 0 L 70 100 L 54 100 Z", "#000000", 0.12)
    a.end()
    a.line(tower, mix("#D9CFC0", INK, 0.6), a.ow)
    a.glow(50, 22, 28, 18, "#FFD45A", 0.55)
    a.shape("M 42.4 31 L 42.4 18.6 L 57.6 18.6 L 57.6 31 Z", "#FFE9A0", 0.3, 0.2, outline="#8A6A20")
    a.line("M 50 18.6 L 50 31 M 42.4 24.6 L 57.6 24.6", "#8A6A20", a.ow * 0.7, 0.7)
    a.shape("M 36 31 L 64 31 L 64 35 L 36 35 Z", "#3A3944", 0.25, 0.2)
    a.shape("M 40.4 18.6 C 40.4 10, 59.6 10, 59.6 18.6 Z", "#D64545", 0.25, 0.3)
    a.shape("M 49 9.6 L 51 9.6 L 51 5.4 L 49 5.4 Z", "#3A3944", 0.2, 0.2)
    a.shape("M 46 83 L 46 74 C 46 70.4, 54 70.4, 54 74 L 54 83 Z", "#5A3A22", 0.15, 0.2)
    return a.svg()


def whirlpool(units=5.0):
    """The Kraken's lair, from above (it lies flat): the sea turning round and down into
    the dark, white water streaming in along its arms, and an eye down in the deep."""
    import math
    a = Art(320, units)
    a.glow(50, 50, 50, 50, "#0B1F33", 0.6)
    for k, (r, color) in enumerate(((46, "#2B6A92"), (38, "#235A80"), (30, "#1B486A"), (21, "#133553"), (12, "#0B2138"))):
        a.fill(ell(50 + k * 0.5, 50 + k * 0.4, r, r), color, 0.92)
    for arm in range(5):
        pts = []
        for i in range(48):
            t = i / 47
            ang = arm * 2 * math.pi / 5 + t * 4.6
            rad = 44 * (1 - t) ** 0.9 + 3
            pts.append((50 + math.cos(ang) * rad, 50 + math.sin(ang) * rad))
        a.line("M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts), FOAM, 2.6, 0.5)
        a.line("M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts[:20]), FOAM, 1.2, 0.85)
    # the eye
    a.shape(ell(50, 52, 9, 5.2), "#F2C23A", 0.3, 0.3, outline="#5A3A10")
    a.fill(ell(50, 52, 1.6, 4.4), "#141018")
    a.fill(ell(47, 50.4, 1.6, 1.0), "#FFFFFF", 0.85)
    return a.svg()


# ---------------------------------------------------------------------------
# the clockwork harbour (Clockwork Cove)
# ---------------------------------------------------------------------------

BRASS, BRASS_L, BRASS_D = "#C9963A", "#EBC56E", "#7E5A1C"
COPPER, COPPER_D = "#C46A3C", "#7A3A1C"
BRICK2, BRICK2_D = "#A9553A", "#6E3220"
VERDIGRIS = "#4FA08A"
SMOKE = "#E4E4EA"


def _cog(cx, cy, r, teeth=10, depth=0.18):
    """A cog's outline: a disc with square-ish teeth round it."""
    import math
    pts = []
    n = teeth * 4
    for i in range(n):
        ang = 2 * math.pi * (i + 0.5) / n
        rr = r if i % 4 in (0, 1) else r * (1 - depth)
        pts.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
    return "M " + " L ".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


def gear(units=1.4):
    """A big brass cog half sunk in the ground on its edge, its hub bolted."""
    import math
    a = Art(192, units)
    a.shadow(50, 92, 34, 4.4)
    a.group(clip="M 0 0 L 100 0 L 100 89 L 0 89 Z")
    a.shape(_cog(50, 60, 34, 12), BRASS, 0.32, 0.32)
    a.shape(circ(50, 60, 23), mix(BRASS, BRASS_D, 0.3), 0.2, 0.3)
    for k in range(4):
        ang = k * math.pi / 2 + math.pi / 4
        a.shape(circ(50 + math.cos(ang) * 14, 60 + math.sin(ang) * 14, 4.6), "#3A2A14", 0.05, 0.1)
    a.shape(circ(50, 60, 8), BRASS_L, 0.3, 0.3, outline=BRASS_D)
    a.fill(circ(50, 60, 3), "#3A3944")
    a.end()
    a.shape("M 12 89.4 C 24 84, 76 84, 88 89.4 C 70 93.6, 30 93.6, 12 89.4 Z", "#8A7A62", 0.2, 0.3)
    return a.svg()


def pipes(units=1.2):
    """A copper pipe coming up out of the ground and back down, a valve wheel on top and
    a puff of steam from a joint."""
    a = Art(160, units)
    a.shadow(50, 92, 36, 4.4)
    pipe = ("M 22 92 L 22 54 C 22 40, 33 32, 47 32 L 55 32 C 69 32, 78 40, 78 54 L 78 92 L 68 92 L 68 55 "
            "C 68 47, 63 42, 55 42 L 47 42 C 39 42, 32 47, 32 55 L 32 92 Z")
    a.shape(pipe, COPPER, 0.34, 0.32)
    for d in ("M 19 72 L 35 72 L 35 78 L 19 78 Z", "M 65 68 L 81 68 L 81 74 L 65 74 Z", "M 48 28.4 L 54 28.4 L 54 45.6 L 48 45.6 Z"):
        a.shape(d, COPPER_D, 0.3, 0.3)
    a.line("M 51 28 L 51 20", "#3A3944", 2.0)
    a.line(circ(51, 16, 6.4), "#B23A2E", 2.6)
    a.line("M 44.6 16 L 57.4 16 M 51 9.6 L 51 22.4", "#B23A2E", 1.6)
    for x, y, r in ((86, 62, 6), (91, 54, 7.4), (88, 44, 5.4)):
        a.shape(circ(x, y, r), SMOKE, 0.3, 0.16, opacity=0.85)
    return a.svg()


def smokestack(units=2.2):
    """A tall brick chimney, an iron band round its top, smoke rolling out."""
    a = Art(192, units)
    a.shadow(50, 94, 20, 3.6)
    stack = "M 38 94 L 41 28 L 59 28 L 62 94 Z"
    a.shape(stack, BRICK2, 0.25, 0.32)
    a.group(clip=stack)
    for i, y in enumerate(range(32, 94, 7)):
        a.line(f"M 30 {y} L 70 {y}", BRICK2_D, a.ow * 0.6, 0.6)
        for x in (44, 56) if i % 2 == 0 else (50,):
            a.line(f"M {x} {y} L {x} {y + 7}", BRICK2_D, a.ow * 0.6, 0.6)
    a.end()
    a.shape("M 37 28 L 63 28 L 63 34 L 37 34 Z", "#3A3944", 0.25, 0.2)
    for x, y, r in ((52, 21, 6.6), (60, 14, 7.6), (71, 9, 6.4)):
        a.shape(circ(x, y, r), "#CFCFD6", 0.32, 0.18, opacity=0.92)
    return a.svg()


def buoy(units=1.0):
    """A red and white bell buoy bobbing in the harbour."""
    a = Art(160, units)
    a.shape("M 28 84 C 28 72, 72 72, 72 84 C 64 88, 36 88, 28 84 Z", "#D64545", 0.3, 0.3)
    body = "M 40 75 L 44 40 L 56 40 L 60 75 Z"
    a.shape(body, "#F4EFE6", 0.25, 0.25)
    a.group(clip=body)
    a.fill("M 0 52 L 100 52 L 100 62 L 0 62 Z", "#D64545")
    a.end()
    a.line(body, mix("#D9CFC0", INK, 0.6), a.ow)
    a.shape("M 42.6 40 C 42.6 31, 57.4 31, 57.4 40 Z", BRASS, 0.32, 0.3)
    a.fill(circ(50, 41.4, 1.8), BRASS_D)
    a.shape("M 48.6 31.6 L 51.4 31.6 L 51.4 26 L 48.6 26 Z", "#3A3944", 0.2, 0.2)
    foam(a, 20, 80, 86)
    return a.svg()


def clocktower(units=3.6):
    """The harbour's clock tower: brick, a big clock face, a green copper spire, and a cog
    turning in a window."""
    a = Art(320, units)
    a.shadow(50, 94, 26, 4)
    body = "M 34 94 L 34 36 L 66 36 L 66 94 Z"
    a.shape(body, BRICK2, 0.25, 0.32)
    a.group(clip=body)
    for i, y in enumerate(range(40, 94, 6)):
        a.line(f"M 30 {y} L 70 {y}", BRICK2_D, a.ow * 0.6, 0.55)
        for x in (42, 54, 62) if i % 2 == 0 else (38, 48, 58):
            a.line(f"M {x} {y} L {x} {y + 6}", BRICK2_D, a.ow * 0.6, 0.55)
    a.fill("M 54 30 L 70 30 L 70 100 L 56 100 Z", "#000000", 0.14)
    a.end()
    a.shape("M 31 33 L 69 33 L 69 38 L 31 38 Z", STONE, 0.25, 0.3)
    a.shape(circ(50, 53, 11.4), "#F4EFE6", 0.2, 0.2, outline=BRASS_D)
    import math
    for k in range(12):
        ang = k * math.pi / 6
        a.line(f"M {50 + math.cos(ang) * 8.6:.2f} {53 + math.sin(ang) * 8.6:.2f} L {50 + math.cos(ang) * 10.2:.2f} {53 + math.sin(ang) * 10.2:.2f}", "#3A3944", a.ow * 0.6)
    a.line("M 50 53 L 50 45.4 M 50 53 L 55.6 55.6", "#2B2A33", a.ow * 1.3)
    a.line(circ(50, 53, 11.4), BRASS, 1.8)
    a.shape("M 43 71 L 57 71 L 57 85 L 43 85 Z", "#2C2A30", 0.1, 0.1)
    a.shape(_cog(50, 78, 5.8, 8), BRASS, 0.32, 0.3)
    a.fill(circ(50, 78, 1.6), "#3A3944")
    a.shape("M 31 33 L 50 8 L 69 33 Z", VERDIGRIS, 0.3, 0.32)
    a.shape("M 49 8.4 L 51 8.4 L 51 3 L 49 3 Z", "#3A3944", 0.2, 0.2)
    return a.svg()


def crane(units=3.2):
    """A dockside crane: a timber tower, an iron jib out over the water, a crate hanging
    from its hook."""
    a = Art(320, units)
    a.shadow(40, 94, 20, 3.6)
    a.shape("M 29 94 L 35 30 L 41 30 L 39 94 Z", WOOD, 0.25, 0.3)
    a.shape("M 45 94 L 43 30 L 49 30 L 55 94 Z", WOOD, 0.25, 0.3)
    a.line("M 37.6 82 L 49.6 64 M 50 82 L 38.6 64 M 38 54 L 47.6 40 M 47.6 54 L 38.6 40", WOOD_D, a.ow * 1.4)
    a.shape("M 31 30 L 53 30 L 53 17 L 31 17 Z", "#B23A2E", 0.25, 0.3)
    a.shape("M 35 20 L 40 20 L 40 26 L 35 26 Z", "#F4E2A0", 0.2, 0.2)
    a.shape("M 49 19.4 L 94 9.4 L 94.6 13.4 L 51 25.4 Z", "#3A3944", 0.3, 0.25)
    a.line("M 42 17 L 58 5 L 94 10.4", "#3A3944", a.ow * 1.0)
    a.line("M 88 12 L 88 51", ROPE, a.ow * 1.0)
    a.shape("M 79 51 L 97 51 L 97 69 L 79 69 Z", WOOD_L, 0.25, 0.3)
    a.line("M 79 51 L 97 69 M 97 51 L 79 69", WOOD_D, a.ow * 0.8, 0.6)
    return a.svg()



SPRITES = [
    ("palm", palm, 1.9), ("bush", bush, 1.1), ("rock", rock, 1.0), ("rock_sea", rock_sea, 1.0),
    ("barrel", barrel, 0.8), ("barrel_sea", barrel_sea, 0.8), ("gull", gull, 0.8), ("hut", hut, 1.8),
    ("skullrock", skullrock, 2.4), ("ship", ship, 3.8), ("wreck", wreck, 3.0), ("dock", dock, 3.2),
    ("crate", crate, 0.8), ("torch", torch, 1.0), ("cannon", cannon, 1.3), ("keep", keep, 2.6), ("flag", flag, 2.0),
    ("mangrove", mangrove, 2.0), ("reeds", reeds, 1.0), ("reeds_sea", reeds_sea, 1.0), ("log", log, 1.3),
    ("stump", stump, 0.9), ("lily", lily, 0.9), ("sunken", sunken, 3.2), ("deadtree", deadtree, 2.2),
    ("grave", grave, 0.9), ("pumpkin", pumpkin, 0.85), ("lamp", lamp, 1.2), ("fence", fence, 1.1),
    ("mist", mist, 1.3), ("crypt", crypt, 2.8), ("ghostship", ghostship, 3.8),
    ("lavarock", lavarock, 1.0), ("charred", charred, 1.4), ("vent", vent, 1.1), ("volcano", volcano, 5.2),
    ("pine_snow", pine_snow, 2.0), ("icerock", icerock, 1.0), ("snowman", snowman, 1.3), ("igloo", igloo, 2.2),
    ("iceberg", iceberg, 1.8), ("floe", floe, 1.3), ("seal", seal, 1.3), ("frozenship", frozenship, 3.8),
    ("tentacle", tentacle, 1.8), ("coral", coral, 1.2), ("barnacle", barnacle, 1.0), ("mast", mast, 2.0),
    ("anchor", anchor, 1.2), ("bones", bones, 1.6), ("lighthouse", lighthouse, 3.2), ("whirlpool", whirlpool, 5.0),
    ("gear", gear, 1.4), ("pipes", pipes, 1.2), ("smokestack", smokestack, 2.2), ("buoy", buoy, 1.0),
    ("clocktower", clocktower, 3.6), ("crane", crane, 3.2),
]


def sprites():
    return [(name, draw()) for name, draw, _ in SPRITES]
