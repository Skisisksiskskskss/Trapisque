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


def bush(units=1.1):
    a = Art(160, units)
    a.shadow(50, 93, 33, 4)
    a.shape("M 17 92 C 9 91, 8 79, 17 76 C 14 65, 27 58, 36 65 C 38 52, 57 50, 61 61 C 67 52, 84 56, 83 69 C 93 71, 93 90, 82 92 Z", LEAF, 0.3, 0.3)
    a.line("M 36 65 C 35 70, 37 74, 41 76 M 61 61 C 60 66, 62 70, 66 71", LEAF_D, a.ow * 0.8, 0.7)
    for cx, cy, rx, ry, rot in ((30, 70, 4, 2.2, -30), (50, 59, 4.5, 2.4, -20), (71, 62, 3.6, 2, -35)):
        a.parts.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})" fill="{LEAF_L}" fill-opacity="0.85"/>')
    return a.svg()


def _boulder(a, body, top, side):
    a.shape(body, STONE, 0.22, 0.3)
    a.fill(top, STONE_L, 0.9)
    a.fill(side, STONE_D, 0.45)


def rock(units=1.0):
    a = Art(160, units)
    a.shadow(50, 92, 36, 4.5)
    _boulder(
        a,
        "M 22 92 C 18 80, 24 66, 36 60 C 45 53, 62 51, 72 57 C 82 63, 88 78, 84 92 Z",
        "M 36 60 C 45 53.5, 61 52, 71 57.5 C 64 62, 50 63.5, 38 65.5 Z",
        "M 72 57 C 82 63, 88 78, 84 92 L 73 92 C 76 80, 76 68, 72 57 Z",
    )
    # a pebble at its foot
    a.shape("M 10 93 C 9 88, 13 85, 18 86 C 22 87, 23 90, 22 93 Z", STONE, 0.22, 0.3)
    return a.svg()


def rock_sea(units=1.0):
    a = Art(160, units)
    _boulder(
        a,
        "M 22 88 C 20 78, 28 68, 40 64 C 50 61, 64 62, 72 68 C 79 73, 81 82, 79 88 Z",
        "M 40 64 C 50 61.5, 63 62.5, 71 67.5 C 63 70, 50 70.5, 41 71 Z",
        "M 72 68 C 79 73, 81 82, 79 88 L 70 88 C 72 81, 72 74, 72 68 Z",
    )
    a.shape("M 80 89 C 80 85, 84 83, 87 84 C 90 85, 91 87, 90 89 Z", STONE, 0.22, 0.3)
    foam(a, 16, 94, 89, 5)
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
    a = Art(320, units)
    a.shadow(50, 94, 44, 5)
    a.shape("M 10 93 C 6 76, 11 52, 24 38 C 32 29, 43 23, 54 24 C 67 25, 79 32, 86 45 C 93 58, 93 78, 89 93 Z", STONE, 0.25, 0.32)
    a.fill("M 24 38 C 32 29.5, 43 24, 54 24.5 C 64 25, 72 28, 78 34 C 64 33, 44 35, 28 43 Z", STONE_L, 0.9)
    a.fill("M 86 45 C 93 58, 93 78, 89 93 L 80 93 C 84 76, 84 58, 80 41 Z", STONE_D, 0.4)
    # two caves for eyes, one for the nose, a wide one for the mouth
    a.shape("M 26 55 C 25 46, 32 41, 39 43 C 45 45, 47 53, 43 59 C 39 64, 27 63, 26 55 Z", CAVE, 0.08, 0.1)
    a.shape("M 57 47 C 62 41, 72 42, 75 49 C 78 57, 72 63, 65 62 C 58 61, 53 53, 57 47 Z", CAVE, 0.08, 0.1)
    a.shape("M 46 68 C 47 64, 49 62, 50.5 62 C 52 62, 54 65, 55 68 C 53 70, 48 70, 46 68 Z", CAVE, 0.08, 0.1)
    a.shape("M 29 78 C 39 83, 61 83, 73 77 C 72 85, 66 91, 60 93 L 40 93 C 34 91, 30 85, 29 78 Z", CAVE, 0.08, 0.1)
    for x0, w, h in ((37, 6, 5.5), (48, 6.5, 6), (59, 6, 5)):
        a.fill(f"M {x0} 81 L {x0 + w} 81.4 C {x0 + w - 0.8} {81 + h}, {x0 + 0.8} {81 + h}, {x0} 81 Z", STONE_L, 0.95)
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
    """Seen from above (it lies flat): planks across, posts down both sides."""
    a = Art(320, units)
    a.shape("M 0 31 L 100 31 L 100 69 L 0 69 Z", WOOD_L, 0.18, 0.25, x1=0, y1=0, x2=0, y2=1)
    for x in range(8, 100, 9):
        a.line(f"M {x} 32 L {x} 68", WOOD_D, a.ow * 0.9, 0.55)
    for x in (5, 50, 95):
        for y in (27.5, 72.5):
            a.shape(circ(x, y, 4.6), WOOD_D, 0.3, 0.25)
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


def mangrove(units=2.0):
    a = Art(256, units)
    a.shadow(50, 94, 34, 4)
    # stilt roots arching into the mud, the trunk, then the canopy over it all
    for d in ("M 47 66 C 38 68, 28 78, 24 93", "M 48 70 C 42 76, 39 84, 38 93", "M 52 70 C 58 76, 61 84, 62 93", "M 53 66 C 62 68, 72 78, 76 93"):
        a.line(d, mix(BARK, INK, 0.55), a.ow * 3.4)
        a.line(d, BARK, a.ow * 1.6)
    a.shape("M 45 72 C 46 60, 46 50, 44 40 L 56 40 C 54 50, 54 60, 55 72 Z", BARK, 0.25, 0.3, x1=0, y1=0.5, x2=1, y2=0.5)
    a.shape("M 14 46 C 8 40, 12 30, 21 30 C 21 20, 33 14, 42 19 C 47 10, 62 10, 66 19 C 76 15, 88 22, 86 32 C 94 35, 94 46, 86 49 C 82 55, 70 56, 64 51 C 58 56, 44 56, 38 51 C 30 56, 18 53, 14 46 Z", SWAMP, 0.28, 0.32)
    a.line("M 42 19 C 40 24, 41 28, 44 31 M 66 19 C 67 24, 66 28, 62 31 M 38 51 C 40 47, 44 45, 48 45", SWAMP_D, a.ow * 0.8, 0.6)
    for cx, cy, rx, ry, rot in ((26, 34, 4.5, 2.4, -25), (50, 20, 5, 2.6, -10), (74, 26, 4, 2.2, -30)):
        a.parts.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})" fill="{SWAMP_L}" fill-opacity="0.8"/>')
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
    a = Art(160, units)
    a.glow(52, 91, 42, 7, LAVA, 0.45)
    body = "M 20 92 C 16 80, 22 66, 34 60 C 44 53, 62 52, 72 58 C 82 64, 88 78, 84 92 Z"
    a.shape(body, BASALT, 0.25, 0.32)
    a.fill("M 34 60 C 44 54, 61 53, 71 58.5 C 63 63, 49 64, 36 66 Z", BASALT_L, 0.8)
    # split by one glowing seam
    seam = "M 12 82 C 26 77, 40 80, 50 76.5 C 60 73, 72 76, 92 70"
    a.group(clip=body)
    a.line(seam, LAVA, a.ow * 1.8)
    a.line(seam, LAVA_GLOW, a.ow * 0.7)
    a.end()
    return a.svg()


def charred(units=1.4):
    a = Art(192, units)
    a.shadow(50, 94, 20, 3)
    coal = "#3A3330"
    a.shape(
        "M 43 94 C 45 86, 46 76, 46 64 C 46 56, 44 48, 40 40 L 36 33 L 39 31 L 44 38 C 45 32, 45 26, 43 18 L 46 17 "
        "C 49 25, 50 32, 49 40 C 52 36, 56 33, 61 30 L 63 33 C 58 36, 54 40, 52 46 C 52 58, 53 76, 57 94 Z",
        coal, 0.3, 0.3,
    )
    a.line("M 48 60 L 48 80", "#5A4E48", a.ow * 0.8, 0.7)
    # still smouldering at the broken tips
    a.fill(circ(44.5, 17.5, 1.8) + " " + circ(62, 31.5, 1.6), LAVA)
    a.glow(44.5, 17.5, 6, 6, LAVA_GLOW, 0.5)
    return a.svg()


def vent(units=1.1):
    a = Art(160, units)
    a.shadow(50, 92, 34, 4)
    for cx, cy, r, op in ((50, 46, 13, 0.6), (44, 32, 11, 0.45), (52, 20, 9, 0.3)):
        a.glow(cx, cy, r, r, "#F4F1EC", op)
    a.shape("M 18 92 C 22 82, 32 74, 42 72 L 58 72 C 68 74, 78 82, 82 92 Z", BASALT, 0.28, 0.32)
    a.shape(ell(50, 73, 9, 3), "#1E1816", 0.05, 0.1)
    a.fill(ell(50, 73.6, 5, 1.4), LAVA, 0.9)
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
]


def sprites():
    return [(name, draw()) for name, draw, _ in SPRITES]
