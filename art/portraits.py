"""
The eight pirates as portraits, head and shoulders, for the round portraits (cards, the
player chips, the results, character select). tools/art.py calls sprites().

A simple, flat cartoon style: big chunky shapes, each in one flat colour with a line in
a dark shade of its own colour, and at most one flat shadow on a big part (under a hat
brim, under the chin). Faces are front on and plain: dot eyes (or a line or an arc
when they're lidded, shut or winking), bar brows, a simple nose and mouth. Each pirate
is told apart by their head's shape, their hat and hair, and the one thing they carry.

On a 100 x 100 canvas (rendered at 224 px): the face near (50, 52), shoulders running
off the bottom edge, so a circle cropping the canvas keeps the face and the hat.
"""

INK = "#2A2228"
OUT = 1.7  # the line round a shape
IN = 1.3  # lines inside it


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def _hex(c):
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    ca, cb = _rgb(a), _rgb(b)
    return _hex(tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3)))


def ink(c):
    """A part's line: a dark shade of its own colour."""
    return mix(c, INK, 0.66)


def dark(c, t=0.22):
    """A part's flat shadow."""
    return mix(c, "#3A1E30", t)


def circ(cx, cy, r):
    return f"M {cx - r} {cy} A {r} {r} 0 1 0 {cx + r} {cy} A {r} {r} 0 1 0 {cx - r} {cy} Z"


def ell(cx, cy, rx, ry):
    return f"M {cx - rx} {cy} A {rx} {ry} 0 1 0 {cx + rx} {cy} A {rx} {ry} 0 1 0 {cx - rx} {cy} Z"


def rrect(x0, y0, x1, y1, r):
    return (f"M {x0 + r} {y0} L {x1 - r} {y0} Q {x1} {y0}, {x1} {y0 + r} L {x1} {y1 - r} Q {x1} {y1}, {x1 - r} {y1} "
            f"L {x0 + r} {y1} Q {x0} {y1}, {x0} {y1 - r} L {x0} {y0 + r} Q {x0} {y0}, {x0 + r} {y0} Z")


class Flat:
    def __init__(self):
        self.defs = []
        self.parts = []
        self.n = 0

    def shape(self, d, color, line=None, w=OUT):
        """A part: flat colour, its line."""
        self.parts.append(
            f'<path d="{d}" fill="{color}" stroke="{line or ink(color)}" stroke-width="{w}" '
            'stroke-linejoin="round" stroke-linecap="round"/>'
        )

    def fill(self, d, color, opacity=1.0):
        """A detail inside a part: no line."""
        op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
        self.parts.append(f'<path d="{d}" fill="{color}"{op}/>')

    def line(self, d, color, w=IN, opacity=1.0):
        op = f' stroke-opacity="{opacity}"' if opacity < 1 else ""
        self.parts.append(
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}"{op} stroke-linecap="round" stroke-linejoin="round"/>'
        )

    def shadow(self, part, d, color):
        """One flat shadow, cut to `part`'s outline (drawn just before its line)."""
        self.n += 1
        cid = f"c{self.n}"
        self.defs.append(f'<clipPath id="{cid}"><path d="{part}"/></clipPath>')
        self.parts.append(f'<g clip-path="url(#{cid})"><path d="{d}" fill="{color}"/></g>')

    def part(self, d, color, shadow=None, line=None, w=OUT):
        """A part with its one shadow: the fill, the shadow, then the line over both."""
        self.fill(d, color)
        if shadow:
            self.shadow(d, shadow, dark(color))
        self.line(d, line or ink(color), w)

    def svg(self):
        return (
            '<svg xmlns="http://www.w3.org/2000/svg" width="224" height="224" viewBox="0 0 100 100">'
            + "<defs>" + "".join(self.defs) + "</defs>" + "".join(self.parts) + "</svg>"
        )


# ---------------------------------------------------------------------------
# features
# ---------------------------------------------------------------------------

EYE = "#24191E"
MOUTH = "#5A2228"
CHEEK = "#F08A84"


def dots(a, y, gap=6.4, rx=1.9, ry=2.5, look=0.0, cx=50):
    """Two dot eyes, looking `look` to the side."""
    for x in (cx - gap, cx + gap):
        a.fill(ell(x + look, y, rx, ry), EYE)


def lidded(a, x, y, w=2.6, look=0.0, skin="#F2C9A8"):
    """A half-shut eye: the lower half of a dot under a straight lid."""
    a.fill(f"M {x - w + look} {y} A {w} {w * 1.05} 0 0 0 {x + w + look} {y} Z", EYE)
    a.line(f"M {x - w - 0.8} {y - 0.2} L {x + w + 0.8} {y - 0.2}", EYE, 1.5)


def arc(a, x, y, w=2.8, up=True, width=1.7):
    """A shut eye: an arc (up: smiling)."""
    if up:
        a.line(f"M {x - w} {y + 0.8} Q {x} {y - w * 0.9}, {x + w} {y + 0.8}", EYE, width)
    else:
        a.line(f"M {x - w} {y - 0.8} Q {x} {y + w * 0.9}, {x + w} {y - 0.8}", EYE, width)


def bar(a, x0, y0, x1, y1, color, w=2.6):
    """A brow: a thick rounded bar."""
    a.line(f"M {x0} {y0} L {x1} {y1}", color, w)


def cheeks(a, y, gap=11, r=3.2, opacity=0.55):
    for x in (50 - gap, 50 + gap):
        a.fill(circ(x, y, r), CHEEK, opacity)


def ears(a, y, gap, skin, r=4):
    for x in (50 - gap, 50 + gap):
        a.shape(circ(x, y, r), skin)


def shoulders(a, color, top=80, wide=40, shadow=True):
    d = f"M {50 - wide - 6} 104 C {50 - wide - 4} {top + 8}, {50 - wide * 0.6} {top}, 50 {top} C {50 + wide * 0.6} {top}, {50 + wide + 4} {top + 8}, {50 + wide + 6} 104 Z"
    a.part(d, color, shadow=f"M 30 {top - 2} C 36 {top + 7}, 64 {top + 7}, 70 {top - 2} Z" if shadow else None)


def neck(a, skin, top=64, w=8, bottom=84):
    a.part(f"M {50 - w} {top} L {50 - w} {bottom} L {50 + w} {bottom} L {50 + w} {top} Z", skin,
           shadow=f"M {50 - w - 2} {top} L {50 + w + 2} {top} L {50 + w + 2} {top + 6} C {50 + w / 2} {top + 9}, {50 - w / 2} {top + 9}, {50 - w - 2} {top + 6} Z")


def braid(a, x, y, n, color, tie):
    """A braid hanging from (x, y): plaits leaning left and right in turn, tied off."""
    for k in range(n):
        lean = 26 if k % 2 == 0 else -26
        cx, cy = x + (0.7 if k % 2 == 0 else -0.7), y + k * 4.4
        a.parts.append(f'<g transform="rotate({lean} {cx} {cy})">')
        a.shape(ell(cx, cy, 3.6, 2.6), color, w=1.3)
        a.parts.append("</g>")
    end = y + n * 4.4 - 1.6
    a.shape(rrect(x - 2.6, end, x + 2.6, end + 2.6, 0.8), tie, w=1.2)
    a.shape(f"M {x - 2} {end + 2.6} L {x - 2.8} {end + 6.4} L {x + 2.8} {end + 6.4} L {x + 2} {end + 2.6} Z", color, w=1.2)


def hand(a, x, y, skin, r=4.6):
    """A mitten of a hand, holding something."""
    a.shape(f"M {x - r} {y + r * 0.2} C {x - r} {y - r}, {x + r} {y - r}, {x + r} {y + r * 0.2} C {x + r} {y + r * 1.1}, {x - r} {y + r * 1.1}, {x - r} {y + r * 0.2} Z", skin)
    a.line(f"M {x - r * 0.5} {y - r * 0.15} L {x + r * 0.55} {y - r * 0.15}", ink(skin), 1.0, 0.8)


# ---------------------------------------------------------------------------
# the eight
# ---------------------------------------------------------------------------

GOLD = "#F0BE3A"
WHITE = "#F8F5EE"


def mage():
    """The frost sorcerer: an egg of a head under a tall bent hat hung with icicles, a
    huge white cloud of a beard, a red bulb of a nose, a crystal staff."""
    a = Flat()
    skin, robe, hat, band = "#F2CBAE", "#2566A8", "#2F7FD0", "#A6DAF7"
    shoulders(a, robe)
    # the staff, behind his shoulder
    a.shape("M 80 104 L 80 40 L 85 40 L 85 104 Z", "#9A6A3E")
    a.shape("M 82.5 22 L 89 33 L 82.5 44 L 76 33 Z", "#BFEAFF", line="#4C9FD0")
    a.fill("M 82.5 25 L 85 33 L 82.5 33 Z", "#FFFFFF", 0.9)
    a.part(ell(50, 52, 15, 18), skin, shadow="M 30 30 L 70 30 L 70 43 C 60 46, 40 46, 30 43 Z")
    dots(a, 51)
    # brows like snow, under the brim
    for x0, x1 in ((37, 47), (53, 63)):
        a.shape(f"M {x0} 46.6 C {x0 + 2} 43.6, {x1 - 2} 43.4, {x1} 46 C {x1 - 3} 48, {x0 + 3} 48.2, {x0} 46.6 Z", WHITE, line="#9AA6B8", w=1.2)
    # the beard, the moustache, the nose
    beard = "M 34 58 C 31 72, 34 86, 42 94 C 44 90, 47 89, 50 92 C 53 89, 56 90, 58 94 C 66 86, 69 72, 66 58 C 60 64, 40 64, 34 58 Z"
    a.part(beard, WHITE, shadow="M 30 58 C 40 68, 60 68, 70 58 L 70 66 C 60 74, 40 74, 30 66 Z", line="#9AA6B8")
    a.shape("M 50 60 C 46 58, 40 59, 36 63.4 C 41 66, 46 65, 50 62.6 C 54 65, 59 66, 64 63.4 C 60 59, 54 58, 50 60 Z", WHITE, line="#9AA6B8", w=1.2)
    a.shape(circ(50, 57, 3.6), "#E8766C")
    # the hat: tall, bent, a pale band, a snowflake, icicles off the brim
    a.part("M 33 41 C 36 30, 42 16, 52 9 C 58 5, 67 4, 73 9 C 66 10, 62 14, 61 20 C 64 28, 66 35, 67 41 Z", hat,
           shadow="M 58 0 L 80 0 L 80 44 L 62 44 C 64 34, 61 24, 58 16 Z")
    a.shape("M 34.4 36 C 44 34, 56 34, 65.6 36 L 66.6 41 C 56 39.4, 44 39.4, 33.4 41 Z", band)
    for k in range(3):
        import math
        t = k * math.pi / 3
        dx, dy = math.cos(t) * 3.4, math.sin(t) * 3.4
        a.line(f"M {49 - dx} {25 - dy} L {49 + dx} {25 + dy}", WHITE, 1.3)
    a.shape(ell(50, 42, 26, 5), hat)
    for x, h in ((30, 5), (37, 7), (63, 6), (70, 4.6)):
        a.shape(f"M {x - 2} 43.6 L {x + 2} 43.6 L {x} {43.6 + h} Z", "#D6F1FF", line="#6FB4DD", w=1.0)
    return a.svg()


def trapper():
    """The trapper: a round face, freckles, a set squint and a smirk, a coonskin cap with
    its ringed tail, a ginger braid, a coil of rope on her shoulder."""
    a = Flat()
    skin, coat, fur, cap, hair = "#F6CFA8", "#EE8A2E", "#F4E6C8", "#94877A", "#D9692A"
    shoulders(a, coat)
    a.shape("M 26 86 C 34 80, 42 78, 50 78 C 58 78, 66 80, 74 86 C 68 90, 32 90, 26 86 Z", fur)
    # the braid over her shoulder
    braid(a, 33, 64, 5, hair, "#3E9F5B")
    a.part(circ(50, 54, 17.5), skin, shadow="M 30 34 L 70 34 L 70 44 C 60 47, 40 47, 30 44 Z")
    cheeks(a, 60)
    for x, y in ((37.6, 57.4), (40, 59.6), (37.2, 61), (62.4, 57.4), (60, 59.6), (62.8, 61)):
        a.fill(circ(x, y, 0.65), "#B9764A")
    lidded(a, 43.6, 53.6)
    lidded(a, 56.4, 53.6)
    bar(a, 39.6, 48.4, 46.6, 49.6, hair, 2.4)
    bar(a, 53.4, 49.6, 60.4, 48.4, hair, 2.4)
    a.shape("M 48.4 57.6 C 49.4 55.4, 51.6 55.6, 52 58 C 51 58.8, 49.4 58.8, 48.4 57.6 Z", "#E8A982", line=ink(skin), w=1.0)
    a.line("M 44.6 63.2 C 48 64.4, 52.6 64.2, 56.4 61.2", MOUTH, 1.5)
    # the coonskin cap, its ringed tail hanging down past her ear
    tail = "M 62 40 C 72 42, 78 52, 77 64 C 76.4 71, 72 75, 68.4 72 C 70 62, 68 52, 60 45 Z"
    a.fill(tail, cap)
    a.shadow(tail, "M 60 50 L 80 50 L 80 54.4 L 60 54.4 Z M 60 59 L 80 59 L 80 63.4 L 60 63.4 Z M 60 67.6 L 80 67.6 L 80 80 L 60 80 Z", "#3E3630")
    a.line(tail, ink(cap))
    a.part("M 31 47 C 30 34, 39 27, 50 27 C 61 27, 70 34, 69 47 C 60 44, 40 44, 31 47 Z", cap, shadow="M 30 42 C 40 39, 60 39, 70 42 L 70 50 L 30 50 Z")
    a.line("M 40 31 L 42 37 M 50 28 L 50 35 M 60 31 L 58 37", "#6E6258", 1.2)
    # its furry brim
    brim = "M 30 47"
    for k in range(8):
        x0 = 30 + k * 5
        brim += f" Q {x0 + 2.5} {41.4 - (1.2 if k % 2 else 0)}, {x0 + 5} {44.6 if k < 7 else 47}"
    brim += " L 70 49 C 60 46.4, 40 46.4, 30 49 Z"
    a.shape(brim, "#C8BCAE")
    # a coil of rope on her other shoulder
    for k in range(3):
        a.line(ell(73, 88 - k * 1.6, 9 - k * 0.8, 3.6), "#8A6A3A", 3.2)
        a.line(ell(73, 88 - k * 1.6, 9 - k * 0.8, 3.6), "#C29A5E", 1.8)
    return a.svg()


def fire_starter():
    """The fire starter: a square head in a polka-dot bandana, a wink and a big grin, a
    gold hoop, a lit match held up."""
    a = Flat()
    skin, shirt, scarf = "#8C5A3A", "#D64545", "#E0443C"
    shoulders(a, shirt)
    a.shape("M 42 80 L 50 92 L 58 80 Z", "#3A2228")
    a.part(rrect(33, 36, 67, 72, 9), skin, shadow="M 30 30 L 70 30 L 70 44 C 60 47, 40 47, 30 44 Z")
    ears(a, 56, 17.4, skin, 3.8)
    a.line(circ(32, 61, 2.6), GOLD, 1.5)
    arc(a, 43.4, 53.6, up=False)
    dots(a, 53.6, rx=2.1, ry=2.7, cx=56.6, gap=0)
    bar(a, 39.6, 48.6, 47, 49.4, "#2A1A16", 2.6)
    bar(a, 53, 48.6, 60.4, 47.6, "#2A1A16", 2.6)
    a.shape("M 48 59 C 48.6 56, 51.4 56, 52 59 C 51 60, 49 60, 48 59 Z", "#704530", line=ink(skin), w=1.0)
    # the big grin, and a goatee under it
    grin = "M 40.6 62.4 C 46 64, 54 64, 59.4 62.4 C 58.4 69, 41.6 69, 40.6 62.4 Z"
    a.part(grin, MOUTH, line="#2A1014", w=1.3)
    a.shadow(grin, "M 38 60 L 62 60 L 62 64.8 C 54 66, 46 66, 38 64.8 Z", WHITE)
    a.shape("M 46.4 69.6 L 53.6 69.6 L 50 74.6 Z", "#2A1A16")
    # the bandana, knotted at the side
    a.part("M 32 47 C 31 36, 39 30, 50 30 C 61 30, 69 36, 68 47 C 60 44.6, 40 44.6, 32 47 Z", scarf,
           shadow="M 30 42 C 40 40, 60 40, 70 42 L 70 50 L 30 50 Z")
    for x, y in ((40, 36), (50, 33.4), (60, 36), (45, 41), (55, 41)):
        a.fill(circ(x, y, 1.6), WHITE)
    a.shape("M 67 40 C 72 38, 76 41, 74 44 C 71 45, 68 44, 67 40 Z", scarf)
    a.shape("M 71 43 L 78 52 L 74 54 L 69.6 45 Z", scarf)
    # the match, burning
    a.shape("M 79.6 62 L 81.6 62 L 81.6 78 L 79.6 78 Z", "#F2D9A8")
    a.shape(ell(80.6, 61, 2.2, 2.8), "#C23A2A")
    a.shape("M 80.6 44 C 84 49, 86 53, 84.6 56.6 C 83.6 59, 77.6 59, 76.6 56.6 C 75.6 53, 77.6 49, 80.6 44 Z", "#FF9A2A")
    a.fill("M 80.6 50 C 82.4 53, 83 55, 82.2 56.8 C 81.6 58, 79.6 58, 79 56.8 C 78.4 55, 79 53, 80.6 50 Z", "#FFE17A")
    hand(a, 80.6, 80, skin)
    return a.svg()


def naturalist():
    """The naturalist: a round, happy face, braids, a crown of leaves with a flower, her
    parrot on her shoulder."""
    a = Flat()
    skin, shirt, hair, leaf = "#C68A5E", "#3E9F5B", "#3A2620", "#5CB84E"
    shoulders(a, shirt)
    for x in (32, 68):
        braid(a, x, 60, 4, hair, "#E0443C")
    a.shape("M 31 52 C 30 38, 38 32, 50 32 C 62 32, 70 38, 69 52 L 64 46 L 36 46 Z", hair)
    a.part(circ(50, 55, 17), skin, shadow="M 30 36 L 70 36 L 70 44 C 60 47, 40 47, 30 44 Z")
    a.shape("M 33.4 49 C 36 40, 44 37, 50 37 C 56 37, 64 40, 66.6 49 C 60 44.6, 54 43.6, 50 45 C 46 43.6, 40 44.6, 33.4 49 Z", hair)
    cheeks(a, 61, 11.4)
    arc(a, 43.4, 55)
    arc(a, 56.6, 55)
    a.shape("M 48.6 59.4 C 49.4 57.6, 50.6 57.6, 51.4 59.4 Z", "#A86E46", line=ink(skin), w=1.0)
    smile = "M 43.6 62.4 C 47 64, 53 64, 56.4 62.4 C 55.6 68.6, 44.4 68.6, 43.6 62.4 Z"
    a.part(smile, MOUTH, line="#2A1014", w=1.3)
    a.shadow(smile, ell(50, 68, 4.4, 2.8), "#E56A78")
    # the crown of leaves, a flower at its side
    for d in (
        "M 50 38 C 42 32, 38 22, 42 12 C 50 18, 54 28, 50 38 Z",
        "M 48 39 C 38 38, 28 32, 26 22 C 36 22, 46 30, 48 39 Z",
        "M 52 39 C 62 38, 72 32, 74 22 C 64 22, 54 30, 52 39 Z",
    ):
        a.shape(d, leaf)
    a.line("M 50 37 C 46.6 30, 45 22, 43.6 15", "#2F7334", 1.0)
    a.line("M 47.6 38 C 41 35, 33 29, 29 24", "#2F7334", 1.0)
    a.line("M 52.4 38 C 59 35, 67 29, 71 24", "#2F7334", 1.0)
    for k in range(5):
        import math
        t = k * 2 * math.pi / 5
        a.shape(circ(62 + math.cos(t) * 2.6, 39 + math.sin(t) * 2.6, 2.2), WHITE, line="#B7A98E", w=1.0)
    a.fill(circ(62, 39, 1.6), GOLD)
    # her parrot
    a.shape("M 74 86 C 70 80, 70 70, 75 66 C 80 63, 86 66, 86 72 C 86 78, 82 84, 78 88 Z", "#E0443C")
    a.shape("M 76 74 C 80 72, 84 76, 82 84 C 79 84, 76 80, 76 74 Z", "#2F7FD0")
    a.shape("M 85 69 L 90 71 L 85.6 74 Z", GOLD)
    a.fill(circ(81.6, 69, 1.3), EYE)
    a.shape("M 76 88 L 74 96 L 79 96 L 80 88 Z", GOLD)
    return a.svg()


def warper():
    """The warper: a long face, a sly side glance under one raised brow, a curly
    moustache, a wide hat with a plume, a spiral of magic over his hand."""
    a = Flat()
    skin, coat, hat = "#F2D2B8", "#D35A9C", "#C2488A"
    shoulders(a, coat)
    a.shape("M 43 78 L 50 90 L 57 78 C 54 76, 46 76, 43 78 Z", WHITE)
    a.part(ell(50, 54, 13.4, 19), skin, shadow="M 30 30 L 70 30 L 70 42 C 60 44.6, 40 44.6, 30 42 Z")
    lidded(a, 44.6, 52.6, 2.4, look=1.2)
    lidded(a, 55.4, 52.6, 2.4, look=1.2)
    a.line("M 40.6 46.4 Q 44 43, 47.6 45.4", "#4A2A3A", 2.2)
    bar(a, 52.6, 47.6, 59.6, 47.6, "#4A2A3A", 2.2)
    a.shape("M 48.4 58 C 49 55, 51 55, 51.6 58 C 50.6 59, 49.4 59, 48.4 58 Z", "#DDA88C", line=ink(skin), w=1.0)
    # the moustache, curling up at its ends, and a smirk
    a.line("M 50 61 C 46 60, 43 61.4, 41.6 59.4 C 40.6 58, 42 56.6, 43 57.8", "#4A2A3A", 1.6)
    a.line("M 50 61 C 54 60, 57 61.4, 58.4 59.4 C 59.4 58, 58 56.6, 57 57.8", "#4A2A3A", 1.6)
    a.line("M 46 65.4 C 49 66.4, 52 66, 54.6 64.4", MOUTH, 1.4)
    # the hat, wide, a white plume curling off it
    a.shape("M 56 30 C 64 22, 76 20, 84 26 C 78 26, 72 28, 68 32 C 74 30, 80 32, 82 36 C 74 34, 66 34, 60 36 Z", WHITE, line="#B0A8B8")
    a.part("M 36 38 C 36 26, 42 20, 50 20 C 58 20, 64 26, 64 38 Z", hat, shadow="M 56 16 L 70 16 L 70 40 L 58 40 C 60 32, 59 24, 56 16 Z")
    a.shape("M 37.4 33 C 45 31.6, 55 31.6, 62.6 33 L 63.6 38 C 55 36.6, 45 36.6, 36.4 38 Z", "#7A2A5A")
    a.shape(ell(50, 39.6, 31, 5.6), hat)
    # the spiral over his hand
    a.line("M 80 66 C 80 63, 84 63, 84 66 C 84 70, 77 70, 77 65 C 77 59, 87 59, 87 66 C 87 73, 74 73, 74 64", "#8E58D6", 2.2)
    a.fill(circ(80.5, 66, 1.2), "#E0C8FF")
    hand(a, 80.6, 80, skin)
    return a.svg()


def overseer():
    """The overseer: a broad, stern face, heavy brows, a grey beard, a navy tricorn
    trimmed in gold with a cockade, a medal, a spyglass."""
    a = Flat()
    skin, coat, navy, beard = "#6E4630", "#E7B023", "#2B4C7E", "#C9C6C0"
    shoulders(a, coat)
    a.shape("M 36 80 L 50 98 L 64 80 C 58 78, 42 78, 36 80 Z", navy)
    a.shape("M 46 86 L 54 86 L 54 92 L 46 92 Z", "#C23A3A")
    a.shape(circ(50, 94.6, 3.2), GOLD)
    # the spyglass, held across him
    a.shape("M 10 98 L 26 70 L 31 73 L 16 101 Z", "#C99A3E")
    a.shape("M 24.4 68.6 L 28.6 61 L 34.4 64.4 L 30.2 72 Z", "#9C7414")
    a.part(ell(50, 56, 20, 17), skin, shadow="M 26 34 L 74 34 L 74 46 C 62 48.6, 38 48.6, 26 46 Z")
    ears(a, 57, 20, skin, 3.6)
    dots(a, 54, gap=7.4, rx=2, ry=2.2)
    bar(a, 38, 47.6, 46.6, 50.4, "#8A8780", 3.2)
    bar(a, 62, 47.6, 53.4, 50.4, "#8A8780", 3.2)
    a.shape("M 47.6 60 C 48.4 56.4, 51.6 56.4, 52.4 60 C 51 61, 49 61, 47.6 60 Z", "#5A3624", line=ink(skin), w=1.0)
    # the beard round his jaw, the moustache over a set mouth
    a.part("M 31 58 C 31 70, 40 76, 50 76 C 60 76, 69 70, 69 58 C 66 64, 62 67, 58 66 C 54 64, 46 64, 42 66 C 38 67, 34 64, 31 58 Z", beard,
           shadow="M 28 70 L 72 70 L 72 80 L 28 80 Z")
    a.shape("M 50 62 C 46 60.4, 41 61, 39 64 C 43 66, 47 65.4, 50 64 C 53 65.4, 57 66, 61 64 C 59 61, 54 60.4, 50 62 Z", beard)
    # the tricorn
    tri = "M 22 42 C 28 38, 34 26, 50 24 C 66 26, 72 38, 78 42 C 70 46, 60 41, 50 44 C 40 41, 30 46, 22 42 Z"
    a.part(tri, navy, shadow="M 20 36 C 40 34, 60 34, 80 36 L 80 50 L 20 50 Z")
    a.line("M 22 42 C 30 46, 40 41, 50 44 C 60 41, 70 46, 78 42", GOLD, 1.8)
    a.shape(circ(50, 36, 4), WHITE, line="#B7A98E", w=1.0)
    a.fill(circ(50, 36, 1.8), GOLD)
    return a.svg()


def gambler():
    """The gambler: a heart of a face under a black bob, a sly side look, red lips and
    a beauty mark, a tilted tricorn, the ace of hearts."""
    a = Flat()
    skin, coat, hair, hat = "#F4D0B4", "#22A094", "#22202A", "#1F8A80"
    shoulders(a, coat)
    a.shape("M 42 79 L 50 86 L 58 79 C 54 77, 46 77, 42 79 Z", WHITE)
    a.shape("M 45 84 L 50 86.6 L 55 84 L 55 89 L 50 86.6 L 45 89 Z", "#D63A4A")
    # her bob, behind her face
    a.shape("M 30 52 C 28 36, 38 30, 50 30 C 62 30, 72 36, 70 52 L 71 72 C 66 74, 62 72, 61 68 L 39 68 C 38 72, 34 74, 29 72 Z", hair)
    face = "M 34 50 C 34 42, 41 38, 50 38 C 59 38, 66 42, 66 50 C 66 60, 58 70, 50 73 C 42 70, 34 60, 34 50 Z"
    a.part(face, skin, shadow="M 30 36 L 70 36 L 70 46.6 L 30 46.6 Z")
    # the blunt fringe
    a.shape("M 33 48 C 33 38, 40 34, 50 34 C 60 34, 67 38, 67 48 Z", hair)
    lidded(a, 44.2, 54, 2.4, look=-1.2)
    lidded(a, 55.8, 54, 2.4, look=-1.2)
    a.line("M 41 53.6 L 39.4 52", EYE, 1.2)
    a.line("M 52.6 53.6 L 51 52", EYE, 1.2)
    a.line("M 48.6 58 C 49.6 59.6, 50.8 59.6, 51.4 58.2", ink(skin), 1.1)
    a.shape("M 45.4 63.4 C 47.6 62.4, 50 63, 50.6 63.4 C 51.6 62.6, 54 62.2, 55.6 62.4 C 54.6 65.4, 47 66, 45.4 63.4 Z", "#D63A4A")
    a.fill(circ(57.6, 61.2, 0.8), "#3A2228")
    # the tricorn, tilted
    a.parts.append('<g transform="rotate(-12 50 30)">')
    a.part("M 30 34 C 34 31, 38 22, 50 21 C 62 22, 66 31, 70 34 C 64 37, 56 33.4, 50 35.4 C 44 33.4, 36 37, 30 34 Z", hat,
           shadow="M 28 30 L 72 30 L 72 40 L 28 40 Z")
    a.line("M 30 34 C 36 37, 44 33.4, 50 35.4 C 56 33.4, 64 37, 70 34", GOLD, 1.5)
    a.parts.append("</g>")
    # the ace of hearts
    a.parts.append('<g transform="rotate(14 80 70)">')
    a.shape(rrect(72, 58, 88, 80, 2), WHITE, line="#8A8478")
    a.fill("M 80 74 C 74 70, 75 64.6, 78 64.6 C 79 64.6, 79.8 65.4, 80 66.4 C 80.2 65.4, 81 64.6, 82 64.6 C 85 64.6, 86 70, 80 74 Z", "#D63A4A")
    a.parts.append("</g>")
    hand(a, 78, 82, skin)
    return a.svg()


def cannoneer():
    """The cannoneer: a big square head in a steel helmet, a squint and a grin under a
    huge ginger handlebar moustache, soot on his cheek, a cannonball on his shoulder."""
    a = Flat()
    skin, shirt, steel, tache = "#D99C70", "#93633A", "#9AA2AE", "#D8742E"
    shoulders(a, shirt)
    a.shape("M 30 84 L 66 104 L 72 104 L 36 82 Z", "#5A3A22")
    a.part(rrect(31, 36, 69, 73, 10), skin, shadow="M 28 32 L 72 32 L 72 45 C 60 47.6, 40 47.6, 28 45 Z")
    ears(a, 57, 19.4, skin, 3.8)
    a.fill(ell(60, 62, 5, 3.4), "#5A4E4A", 0.35)
    arc(a, 43, 53.4, 3, up=False, width=2)
    arc(a, 57, 53.4, 3, up=False, width=2)
    bar(a, 38.6, 48.4, 46.6, 49, "#7A4A2A", 2.6)
    bar(a, 53.4, 49, 61.4, 48.4, "#7A4A2A", 2.6)
    grin = "M 42 65 C 46 66.4, 54 66.4, 58 65 C 57.4 71, 42.6 71, 42 65 Z"
    a.part(grin, MOUTH, line="#2A1014", w=1.3)
    a.shadow(grin, "M 38 62 L 62 62 L 62 67 C 54 68, 46 68, 38 67 Z", WHITE)
    # the handlebar
    a.shape("M 50 61 C 44 58, 36 60, 31 56 C 30 61, 34 65, 39 65 C 44 65, 47 63.6, 50 63 C 53 63.6, 56 65, 61 65 C 66 65, 70 61, 69 56 C 64 60, 56 58, 50 61 Z", tache)
    a.shape(circ(50, 58.4, 4.6), "#C27A52")
    # the helmet
    helm = "M 30 44 C 30 30, 38 24, 50 24 C 62 24, 70 30, 70 44 Z"
    a.part(helm, steel, shadow="M 56 20 L 74 20 L 74 46 L 58 46 C 61 38, 60 28, 56 20 Z")
    a.line("M 50 24 L 50 44", ink(steel), 1.2)
    a.shape("M 24 45 C 34 41, 66 41, 76 45 C 72 48, 28 48, 24 45 Z", steel)
    # the cannonball
    a.shape(circ(78, 76, 9), "#2E3038")
    a.fill(circ(75, 72.6, 2.4), "#6A6E7A")
    hand(a, 72, 86, skin)
    return a.svg()


PORTRAITS = [
    ("mage", mage), ("trapper", trapper), ("fire_starter", fire_starter), ("naturalist", naturalist),
    ("warper", warper), ("overseer", overseer), ("gambler", gambler), ("cannoneer", cannoneer),
]


def sprites():
    return [(name, draw()) for name, draw in PORTRAITS]
