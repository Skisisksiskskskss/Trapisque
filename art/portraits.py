"""
The eight pirates as portraits, head and shoulders, for the round portraits (cards, the
player chips, the results, character select). tools/art.py calls sprites().

Each one is drawn as its own person rather than one face in eight hats: their own head
(long, round, square...), nose, eyes, brows and mouth, the face they pull, how they hold
themselves and what they carry. Heads are turned three-quarters (drawn facing left; some
are mirrored to face right). Shading is cel-style, flat colour and one hard-edged
shadow per part, away from the light (upper left), with a thicker line round the
outside of a shape than inside it.

On a 100 x 100 canvas (rendered at 224 px): the face near (47, 48), shoulders running
off the bottom edge, so a circle cropping the canvas keeps the face and the hat.
"""

import math

INK = "#2A2228"


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def _hex(c):
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    ca, cb = _rgb(a), _rgb(b)
    return _hex(tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3)))


def shade(c, t=0.3):
    """The colour in shadow: darker and a touch warmer."""
    return mix(mix(c, "#5A1E3A", 0.18), "#000000", t * 0.75)


def light(c, t=0.3):
    return mix(c, "#FFFBF0", t)


def ink(c, t=0.62):
    """The line colour for a part: a dark shade of its own colour."""
    return mix(c, INK, t)


def circ(cx, cy, r):
    return f"M {cx - r} {cy} A {r} {r} 0 1 0 {cx + r} {cy} A {r} {r} 0 1 0 {cx - r} {cy} Z"


def ell(cx, cy, rx, ry, rot=0):
    if rot:
        return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})"'
    return f"M {cx - rx} {cy} A {rx} {ry} 0 1 0 {cx + rx} {cy} A {rx} {ry} 0 1 0 {cx - rx} {cy} Z"


def bez(p0, p1, p2, p3, n=12):
    pts = []
    for k in range(n + 1):
        t = k / n
        u = 1 - t
        pts.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                    u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
    return pts


def taper(pts, w0, w1, wm=None):
    """A stroke as a filled shape, `w0` wide at its start and `w1` at its end (`wm` in the
    middle, if given): brows, moustaches, lashes, creases."""
    left, right = [], []
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1
        t = i / (n - 1)
        if wm is None:
            w = w0 + (w1 - w0) * t
        else:
            w = (w0 + (wm - w0) * t * 2) if t < 0.5 else (wm + (w1 - wm) * (t - 0.5) * 2)
        nx, ny = -dy / L * w / 2, dx / L * w / 2
        left.append((x + nx, y + ny))
        right.append((x - nx, y - ny))
    pts2 = left + right[::-1]
    return "M " + " L ".join(f"{x:.2f} {y:.2f}" for x, y in pts2) + " Z"


class Art:
    OUT = 1.15  # line round the outside of a shape
    IN = 0.7  # lines inside

    def __init__(self, skin=None):
        self.defs = []
        self.parts = []
        self.n = 0
        self.skin = skin  # its shadows are gentler than other parts'

    def _id(self, p):
        self.n += 1
        return f"{p}{self.n}"

    def shape(self, d, color, line=None, w=None, opacity=1.0):
        line = line or ink(color)
        w = self.OUT if w is None else w
        op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
        stroke = f' stroke="{line}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"' if w > 0 else ""
        self.parts.append(f'<path d="{d}" fill="{color}"{op}{stroke}/>')

    def fill(self, d, color, opacity=1.0):
        op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
        self.parts.append(f'<path d="{d}" fill="{color}"{op}/>')

    def line(self, d, color, w=None, opacity=1.0):
        w = self.IN if w is None else w
        op = f' stroke-opacity="{opacity}"' if opacity < 1 else ""
        self.parts.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}"{op} stroke-linecap="round" stroke-linejoin="round"/>')

    def part(self, d, color, shadow=None, hi=None, line=None, w=None, shadow_color=None, hi_color=None, hi_opacity=0.55):
        """A shape in flat colour, its shadow (and highlight) cut to its outline."""
        self.shape(d, color, line, 0)
        if shadow or hi:
            self.clip(d)
            if shadow:
                self.fill(shadow, shadow_color or shade(color, 0.12 if color == self.skin else 0.3))
            if hi:
                self.fill(hi, hi_color or light(color, 0.45), hi_opacity)
            self.end()
        line = line or ink(color)
        w = self.OUT if w is None else w
        self.parts.append(f'<path d="{d}" fill="none" stroke="{line}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"/>')

    def clip(self, d):
        cid = self._id("c")
        self.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
        self.parts.append(f'<g clip-path="url(#{cid})">')

    def group(self, transform):
        self.parts.append(f'<g transform="{transform}">')

    def end(self):
        self.parts.append("</g>")

    def glow(self, cx, cy, r, color, a):
        gid = self._id("s")
        self.defs.append(
            f'<radialGradient id="{gid}"><stop offset="0" stop-color="{color}" stop-opacity="{a}"/>'
            f'<stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient>'
        )
        self.parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#{gid})"/>')

    def svg(self, mirror=False):
        body = "".join(self.parts)
        if mirror:
            body = f'<g transform="translate(100 0) scale(-1 1)">{body}</g>'
        return (
            '<svg xmlns="http://www.w3.org/2000/svg" width="224" height="224" viewBox="0 0 100 100">'
            + "<defs>" + "".join(self.defs) + "</defs>" + body + "</svg>"
        )


# ---------------------------------------------------------------------------
# features (a head facing left: its front, nose and far eye toward x = 35)
# ---------------------------------------------------------------------------

WHITE = "#FBF6EC"


def eye(a, cx, cy, w, h, iris, skin, kind="open", look=-0.35, lid=0.0, lash=None, far=False):
    """An eye: the white, the iris looking `look` of the way left (toward the front), the
    lids. kind: open, half (lidded), squint, happy (shut, smiling), wink."""
    line = mix(skin, INK, 0.78)
    lash = lash or line
    if kind in ("happy", "wink"):
        pts = bez((cx - w, cy + 0.4), (cx - w * 0.5, cy - h * 0.9), (cx + w * 0.5, cy - h * 0.9), (cx + w, cy + 0.4), 10)
        a.fill(taper(pts, 0.5, 0.6, 1.3), lash)
        return
    if kind == "squint":
        h *= 0.55
    top = cy - h
    bot = cy + h * 0.8
    white = (f"M {cx - w} {cy} C {cx - w * 0.6} {top}, {cx + w * 0.55} {top - h * 0.1}, {cx + w} {cy - h * 0.15} "
             f"C {cx + w * 0.6} {bot}, {cx - w * 0.6} {bot}, {cx - w} {cy} Z")
    a.fill(white, WHITE)
    a.clip(white)
    r = h * 0.95
    ix, iy = cx + w * look, cy + 0.1
    a.fill(circ(ix, iy, r), iris)
    a.fill(circ(ix, iy, r * 0.5), "#1A1418")
    a.fill(circ(ix - r * 0.35, iy - r * 0.4, r * 0.28), "#FFFFFF", 0.95)
    # the upper lid's shadow on the eye
    a.fill(f"M {cx - w - 1} {cy - h * 1.6} L {cx + w + 1} {cy - h * 1.6} L {cx + w + 1} {cy - h * 0.35} "
           f"C {cx + w * 0.4} {cy - h * 0.75}, {cx - w * 0.4} {cy - h * 0.75}, {cx - w - 1} {cy - h * 0.1} Z", "#3A2830", 0.18)
    if kind == "half" or lid > 0:
        k = 0.45 if kind == "half" else lid
        y = top + (bot - top) * k
        a.fill(f"M {cx - w - 1} {top - 2} L {cx + w + 1} {top - 2} L {cx + w + 1} {y - 0.3} C {cx + w * 0.3} {y + 0.4}, {cx - w * 0.3} {y + 0.4}, {cx - w - 1} {y} Z", skin)
        a.end()
        a.line(f"M {cx - w} {y - 0.1} C {cx - w * 0.3} {y + 0.5}, {cx + w * 0.3} {y + 0.5}, {cx + w} {y - 0.4}", lash, 1.0)
    else:
        a.end()
        pts = bez((cx - w - 0.2, cy + 0.2), (cx - w * 0.6, top - 0.2), (cx + w * 0.55, top - h * 0.3), (cx + w + 0.3, cy - h * 0.15), 10)
        a.fill(taper(pts, 0.6, 0.9, 1.25), lash)
    a.line(f"M {cx - w * 0.7} {bot - 0.2} C {cx - w * 0.2} {bot + 0.4}, {cx + w * 0.4} {bot + 0.3}, {cx + w * 0.8} {bot - 0.6}", line, 0.45, 0.6)


def brow(a, x0, y0, x1, y1, lift, color, w0=1.4, w1=1.0, wm=2.0):
    """A brow from its inner end (x0, y0) to its outer end, arched by `lift`."""
    pts = bez((x0, y0), (x0 + (x1 - x0) * 0.3, y0 - lift), (x0 + (x1 - x0) * 0.7, y1 - lift), (x1, y1), 10)
    a.fill(taper(pts, w0, w1, wm), color)


def ear(a, cx, cy, s, skin, line):
    d = (f"M {cx - 1.6 * s} {cy - 4.2 * s} C {cx + 1.6 * s} {cy - 6.6 * s}, {cx + 4.6 * s} {cy - 3 * s}, {cx + 3.6 * s} {cy + 1 * s} "
         f"C {cx + 3 * s} {cy + 4 * s}, {cx + 0.6 * s} {cy + 5.2 * s}, {cx - 1.2 * s} {cy + 4.2 * s} Z")
    a.part(d, skin, shadow=f"M {cx - 3} {cy - 8} L {cx + 1.2 * s} {cy - 2 * s} C {cx + 1.6 * s} {cy + 1 * s}, {cx + 1 * s} {cy + 2.6 * s}, {cx - 0.4 * s} {cy + 3 * s} L {cx - 3} {cy + 8} Z",
           line=line, w=0.9)
    a.line(f"M {cx + 0.2 * s} {cy - 2.4 * s} C {cx + 2.4 * s} {cy - 2.6 * s}, {cx + 2.6 * s} {cy + 0.4 * s}, {cx + 1 * s} {cy + 1.4 * s}", line, 0.6, 0.8)


def neck(a, x0, x1, top, skin, line):
    d = f"M {x0} {top} L {x0 - 0.6} {top + 14} L {x1 + 1} {top + 14} L {x1} {top - 2} Z"
    a.part(d, skin, shadow=f"M {x0 - 2} {top - 2} L {x1 + 2} {top - 4} L {x1 + 2} {top + 5.5} C {x1 - 4} {top + 7}, {x0 + 2} {top + 6}, {x0 - 2} {top + 4.5} Z", line=line)


# ---------------------------------------------------------------------------
# the eight
# ---------------------------------------------------------------------------

GOLD = "#E9B83C"
CREAM = "#F6EEDC"
NAVY = "#2B4C7E"


def mage():
    """The frost sorcerer: old, long-faced and hook-nosed, bushy white brows over eyes
    narrowed behind round spectacles, a beard down to his belt, a tall crumpled hat hung
    with icicles; the crystal on his staff throws a cold light."""
    skin, line = "#F1C7A3", "#7A4A3C"
    a = Art(skin)
    blue, blue_d = "#2F7FD0", "#1E5A9E"
    white = "#F2EEE6"
    frost, frost_l = "#BFE3F5", "#EAF7FD"
    a.glow(78, 52, 20, "#BFE6FF", 0.65)
    # robe: shoulders turned, the near one bigger
    robe = "M 8 104 C 9 88, 20 78, 34 74 L 62 72 C 78 76, 90 86, 92 104 Z"
    a.part(robe, blue, shadow="M 58 70 C 74 76, 88 86, 92 104 L 100 104 L 100 60 Z M 8 104 C 10 96, 14 90, 20 86 C 18 92, 18 98, 19 104 Z")
    a.fill("M 30 76 C 36 86, 40 96, 42 104 L 46 104 C 44 94, 40 84, 34 75 Z", blue_d, 0.5)
    neck(a, 46, 57, 62, skin, line)
    # the head: long, a narrow jaw
    head = ("M 38 33 C 39 25, 46 20, 54 20 C 63 20, 69 27, 69 37 C 69 45, 67 51, 64 56 C 62 61, 58 65, 53 68 "
            "C 49.5 70, 45.5 70.5, 43 69.5 C 40.5 68, 39 65, 38.5 61 C 38 58, 37 56, 36 54 C 35 51.5, 34.6 48.5, 35 45.5 C 35.5 41.5, 37 37.5, 38 33 Z")
    ear(a, 64, 50, 1.0, skin, line)
    a.part(head, skin, shadow="M 56 22 C 60 30, 62 40, 59 50 C 57 58, 54 64, 51 70 L 75 75 L 75 20 Z", line=line)
    # wrinkles at the eye
    a.line("M 57 44.5 L 59.5 43.6 M 57.4 47 L 60 47.4", line, 0.5, 0.7)
    # the eyes, narrowed, behind round spectacles
    eye(a, 40.5, 45.8, 2.8, 2.2, "#5E8FB8", skin, "half", look=-0.45)
    eye(a, 51.6, 45.8, 3.6, 2.6, "#5E8FB8", skin, "half", look=-0.45)
    rim = "#8A6A3A"
    a.parts.append(f'<ellipse cx="40.6" cy="46" rx="3.8" ry="4" fill="#FFFFFF" fill-opacity="0.15" stroke="{rim}" stroke-width="0.8"/>')
    a.parts.append(f'<ellipse cx="51.6" cy="46" rx="5" ry="4.6" fill="#FFFFFF" fill-opacity="0.15" stroke="{rim}" stroke-width="0.8"/>')
    a.line("M 44.4 45.6 C 45 44.6, 46 44.4, 46.6 45", rim, 0.8)
    a.line("M 56.6 45.2 L 63 47", rim, 0.7)
    # brows like snowdrifts, the near one raised
    brow(a, 43.5, 41.2, 33.5, 41.8, 1.6, white, 1.8, 1.0, 3.0)
    brow(a, 48.5, 40.6, 58.5, 39.2, 2.6, white, 2.0, 1.2, 3.2)
    a.line("M 34 42.2 L 31.8 43.4 M 58.6 39.4 L 61 39.6", white, 1.0)
    # a long hooked nose, red at the tip with the cold
    nose = "M 46.6 45 C 46 49, 44 53, 39.5 56.5 C 37.5 58, 37.6 60, 40 60.4 C 41.6 60.6, 42.8 59.8, 44 59.6 C 45.8 59.6, 47 58.6, 47.2 57.2"
    a.part(nose + " C 47.6 53, 47.6 49, 46.6 45 Z", skin, shadow="M 45 46 C 46 50, 46 54, 44.5 58.6 L 50 58 L 50 45 Z", line=line, w=0.9)
    a.fill("M 39 57.4 C 38.2 58.6, 38.6 60, 40.4 60.2 C 41.6 60.2, 42.6 59.6, 42.6 58.4 C 41.6 57.2, 40 56.8, 39 57.4 Z", "#E88A80", 0.75)
    # the beard: long, forked, over the robe; the moustache hiding his mouth
    beard = ("M 37.5 58 C 37 66, 39.5 74, 42 80 C 43.5 85, 43 91, 41 97 C 45 95, 47.5 91, 48.5 87 C 50 91, 53 94.5, 57 96 "
             "C 55 91, 54.5 86, 55.6 81 C 58.6 74, 61 66, 60.6 57 C 57 62.5, 53 65, 49 65 C 44 65, 40 62, 37.5 58 Z")
    a.part(beard, white, shadow="M 52 64 C 56 72, 56 82, 56 96 L 64 96 L 64 56 Z", line=mix(white, INK, 0.45))
    a.line("M 44.5 70 C 45 76, 46.5 82, 48 87 M 51 68 C 51.5 74, 51.5 80, 50.5 86", mix(white, INK, 0.3), 0.6, 0.8)
    mous = "M 48.5 59 C 45 58.4, 40.5 60, 37.6 62.6 C 36.4 63.8, 37.2 65, 38.6 64.4 C 41.6 62.8, 45 62.2, 48.5 62.4 C 52 62.2, 55.5 62.8, 58 64 C 59.4 64.6, 60 63.2, 58.8 62.2 C 56 60, 52 58.6, 48.5 59 Z"
    a.part(mous, white, shadow="M 48 61.2 L 60 61.6 L 60 66 L 48 66 Z", line=mix(white, INK, 0.45), w=0.9)
    # the hat: a tall cone crumpling over backwards, a frosty band, a brim hung with icicles
    hat = "M 37 33 C 39 24, 43 14, 49 7 C 53 3, 60 1.5, 66 4 C 71 6, 73 10, 71 13.5 C 68.5 11, 64.5 10.6, 62 12.6 C 59.4 14.8, 60.4 24, 66 33 Z"
    a.part(hat, blue, shadow="M 56 6 C 60 4, 66 3.6, 70 6 C 66 9, 61.5 9.6, 60 13 C 58.6 20, 60.6 27, 64 34 L 74 34 L 74 2 Z", hi="M 41 30 C 43 22, 46 14, 50 9 C 47 16, 45 24, 44 31 Z")
    a.line("M 45 22 C 48 23, 52 23, 56 22", blue_d, 0.6, 0.7)
    band = "M 36 30 C 42 32.4, 58 32.4, 66 30 L 66.6 34.6 C 58 37, 42 37, 35.4 34.6 Z"
    a.part(band, frost, shadow="M 56 30 L 70 28 L 70 38 L 56 38 Z", line="#6FA6C6", w=0.8)
    a.line("M 45 31.6 L 45 36 M 43 32.6 L 47 35 M 43 35 L 47 32.6", "#FFFFFF", 0.6)
    brim = "M 18 40 C 19 35, 33 32.4, 50 32.6 C 66 32.8, 82 34.6, 83 39 C 84 42.6, 68 44.6, 50 44.4 C 33 44.2, 17 43.4, 18 40 Z"
    a.part(brim, blue, shadow="M 18 40 C 30 43, 46 44, 60 43.4 C 70 43, 78 41.6, 83 39 C 84 42.6, 68 44.6, 50 44.4 C 33 44.2, 17 43.4, 18 40 Z", hi="M 22 38 C 30 35, 42 34, 52 34.2 C 40 35, 30 36.4, 24 39 Z")
    for x, h in ((24, 4.6), (27.6, 7), (31, 3.8), (71, 5.4), (74.6, 3.6), (78, 4.6)):
        a.part(f"M {x - 1.5} 42.6 L {x + 1.5} 42.9 L {x} {42.9 + h} Z", frost, hi=f"M {x - 1.5} 42.6 L {x - 0.2} 42.8 L {x - 0.2} {42.9 + h * 0.8} Z", line="#6FA6C6", w=0.5, hi_color=frost_l, hi_opacity=0.9)
    # the staff, and the ice crystal on it
    a.part("M 80 104 L 77.4 66 L 81 65.6 L 84 104 Z", "#8A6440", shadow="M 80 66 L 84 66 L 86 104 L 81.6 104 Z", w=0.9)
    crystal = "M 79 40 L 84.6 48 L 83.4 64 L 76.6 64.4 L 74 49 Z"
    a.part(crystal, frost, shadow="M 79 40 L 84.6 48 L 83.4 64 L 80 64 L 79.6 47 Z", hi="M 79 40 L 74 49 L 76.6 64.4 L 77.6 64 L 77 49 Z", line="#5F96B8", w=0.9, hi_color=frost_l, hi_opacity=0.9)
    a.line("M 79.6 47 L 79 40 M 79.6 47 L 77 49", "#FFFFFF", 0.5, 0.8)
    return a.svg()


def trapper():
    """The bounty hunter: a broad freckled face, a sharp squint and a lopsided smirk, a
    coonskin cap with its ringed tail, a ginger plait over one shoulder and a coil of
    rope over the other. Faces right."""
    skin, line = "#ECB48C", "#8A4A34"
    a = Art(skin)
    hair, hair_d = "#C2582C", "#8A3A1A"
    fur, fur_d, fur_l = "#8E8272", "#4E453C", "#BDB2A2"
    coat = "#E8842C"
    # hair behind the head
    a.part("M 36 40 C 35 30, 42 24, 52 24 C 62 24, 70 30, 70 42 C 70 52, 69 60, 67 66 L 41 66 C 38 58, 36 50, 36 40 Z", hair_d, line=ink(hair_d))
    jacket = "M 6 104 C 8 88, 18 79, 33 75 L 63 73 C 79 77, 90 87, 93 104 Z"
    a.part(jacket, coat, shadow="M 60 72 C 76 77, 89 87, 93 104 L 100 104 L 100 62 Z M 6 104 C 8 96, 12 90, 18 86 C 16 92, 16 98, 17 104 Z")
    a.fill("M 34 77 L 44 100 L 48 100 L 38 76 Z", shade(coat, 0.2), 0.7)
    neck(a, 45, 57, 62, skin, line)
    # a fur collar
    collar = ("M 30 78 C 34 72.6, 42 72, 50 75.4 C 58 72.4, 66 72.8, 70 77.6 C 69 80.6, 66 81.4, 63.4 80.4 C 61.4 83, 57.4 83, 55.4 81 "
              "C 53.4 83.2, 48.6 83.2, 46.6 81 C 44.6 83, 40.6 83, 38.6 80.4 C 35.8 81.4, 31.6 81, 30 78 Z")
    a.part(collar, fur_l, shadow="M 56 74 C 62 72.6, 68 74, 70 77.6 C 69 80.6, 66 81.4, 63.4 80.4 C 61.4 83, 57.4 83, 55.4 81 Z")
    # a broad face, round cheeks, a strong chin
    head = ("M 37 36 C 38 28, 45 23.5, 53 23.5 C 62 23.5, 68 29, 68.6 38 C 69 45, 68 51, 65.6 56.4 C 63 61.6, 58.6 65.6, 53.4 67.6 "
            "C 49.6 69, 45 69, 42.4 67.6 C 39.6 66, 38.4 63, 38 60 C 37.6 58, 36.6 56.4, 35.6 54.4 C 34.4 52, 34 49, 34.6 46 C 35.2 42.4, 36 39.4, 37 36 Z")
    ear(a, 64.4, 50, 1.0, skin, line)
    a.part(head, skin, shadow="M 57 24 C 61 32, 63 42, 60.4 51 C 58.4 58, 55 63.6, 51 69 L 75 72 L 75 22 Z", line=line)
    # freckles across her nose and cheeks
    for x, y in ((38.6, 52), (41, 53.2), (37.8, 54.4), (49.6, 52.6), (52.4, 53.6), (50.4, 55), (54.6, 52.2), (43.6, 51.6)):
        a.fill(circ(x, y, 0.5), "#B8683E", 0.75)
    # a hard squint, one brow down
    eye(a, 40.4, 46.6, 2.7, 2.3, "#5A7A3A", skin, "open", look=-0.55, lid=0.42)
    eye(a, 51.6, 46.4, 3.6, 2.6, "#5A7A3A", skin, "open", look=-0.5, lid=0.36)
    brow(a, 44, 42.6, 35, 41.2, 0.6, hair_d, 1.6, 0.9, 2.2)
    brow(a, 47.6, 42.2, 57.6, 40.4, 1.6, hair_d, 1.6, 0.9, 2.2)
    # a short straight nose
    a.part("M 45.6 47 C 45 50.6, 43 53.4, 40.6 55.4 C 39.8 56.4, 40.6 57.4, 42.4 57.2 C 43.8 57.2, 45.2 56.8, 46.4 56.2 C 47 54, 46.8 50.6, 45.6 47 Z", skin,
           shadow="M 44.6 48 C 45.6 51, 45.8 54, 45 56.8 L 50 56 L 50 47 Z", line=line, w=0.9)
    # a lopsided smirk
    a.line("M 39 61.4 C 42 62.6, 46 62.6, 50 61 C 51.6 60.4, 52.6 59.4, 53.2 58.4", mix(skin, "#6E2A22", 0.55), 1.1)
    a.line("M 52.4 57.4 C 53.6 58, 54 59, 53.8 60", line, 0.5, 0.7)
    # her fringe, and the plait over her near shoulder
    a.part("M 35.4 46 C 35 36, 40.6 30, 49 30.4 C 57.6 30.8, 63.6 35, 66 42 C 60.6 38.6, 54 38.8, 48 41.4 C 43.4 43.4, 38.6 44.6, 35.4 46 Z", hair,
           shadow="M 54 31 C 60 33, 64 37, 66 42 C 62 39.6, 58 39, 54 39.6 Z", hi="M 38.6 40 C 41 35, 45 32.6, 50 32.4 C 45 34, 41.4 37, 39.6 41 Z")
    for k in range(7):
        t = (k + 0.5) / 7
        x, y = 64 + 6 * t, 60 + 36 * t
        wdt = 5.6 * (1 - 0.3 * t)
        tilt = 28 if k % 2 == 0 else -28
        a.group(f"translate({x:.2f} {y:.2f}) rotate({tilt})")
        a.part(ell(0, 0, wdt * 0.6, 3.2), hair if k % 2 == 0 else mix(hair, hair_d, 0.35), shadow=f"M 0 -4 L 5 -4 L 5 4 L 0 4 Z", w=0.8)
        a.end()
    a.part("M 66.4 94 C 68 95, 70.6 95.4, 72.4 94.4 L 72 97.6 C 70 98.4, 67.6 98, 66 97 Z", "#3E6E3A", w=0.7)
    # the coonskin cap: a dome of grey fur, the ringed tail hanging behind
    tail = "M 66 38 C 71 43, 74 50, 75 58 C 75.6 62, 75 65, 73 67 C 70.8 66, 69.6 63.4, 69.4 60 C 69 54, 67 48, 63.4 43.6 Z"
    a.part(tail, fur_l, line=ink(fur_d, 0.3))
    a.clip(tail)
    for y0 in (46, 52.6, 59.2):
        a.fill(f"M 60 {y0 - 1} L 80 {y0 + 1.4} L 80 {y0 + 4.6} L 60 {y0 + 2.2} Z", fur_d, 0.9)
    a.fill("M 60 64 L 80 66 L 80 72 L 60 72 Z", fur_d)
    a.end()
    cap = ("M 33.6 42 C 32.4 36.6, 33.4 31.4, 36 28 C 35.6 26, 37.2 24.4, 38.8 25 C 41 21.6, 45 19.6, 48.4 20.6 C 50.4 18.6, 55.6 18.6, 57.6 20.6 "
           "C 60.6 19.8, 64.6 21.8, 66.4 25.4 C 68 25, 69.4 26.6, 68.8 28.6 C 70.6 31.6, 71.4 36.6, 70.4 41.6 C 62 38.8, 42 39, 33.6 42 Z")
    a.part(cap, fur, shadow="M 56 20 C 62 21, 66 24, 68.8 28.6 C 70.6 31.6, 71.4 36.6, 70.4 41.6 C 66 40.2, 62 39.6, 58 39.4 C 60 33, 60 26, 56 20 Z",
           hi="M 37 34 C 37.6 29, 41 24.6, 46 23 C 42.6 26, 40.6 30, 40 34.6 Z")
    a.line("M 43 25.6 C 42.4 29, 42.4 32.6, 43.6 36 M 51.6 22.6 C 51.2 27, 51.2 31, 51.6 35.4", fur_d, 0.6, 0.55)
    # a coil of rope over her far shoulder
    rope, rope_d = "#C9A26B", "#7A5A30"
    a.parts.append(f'<ellipse cx="21" cy="88" rx="10" ry="7" fill="none" stroke="{ink(rope)}" stroke-width="4"/>')
    a.parts.append(f'<ellipse cx="21" cy="88" rx="10" ry="7" fill="none" stroke="{rope}" stroke-width="2.4"/>')
    for k in range(12):
        t = k / 12 * 2 * math.pi
        x, y = 21 + 10 * math.cos(t), 88 + 7 * math.sin(t)
        a.line(f"M {x - 0.7:.2f} {y - 1:.2f} L {x + 0.7:.2f} {y + 1:.2f}", rope_d, 0.5, 0.8)
    return a.svg(mirror=True)


def fire_starter():
    """The fire starter: a lean face split by a wide wicked grin, one eye screwed shut, a
    gold hoop, a red bandana knotted at the side with its ends flying, and the match he's
    just struck, held up by his cheek."""
    skin, line = "#A8693F", "#4E2A18"
    a = Art(skin)
    red, red_d = "#D8463E", "#9E2A26"
    beard = "#1E1818"
    a.glow(76, 46, 18, "#FFB347", 0.55)
    shirt = "M 8 104 C 10 88, 20 79, 34 75.6 L 62 73.6 C 78 77, 89 86, 92 104 Z"
    a.part(shirt, red, shadow="M 58 72 C 75 77, 88 86, 92 104 L 100 104 L 100 62 Z M 8 104 C 10 96, 14 90, 20 86 C 18 92, 18 98, 19 104 Z")
    a.part("M 40 76 L 49 94 L 58 75 C 54 77.6, 44 78, 40 76 Z", "#3A3440", w=0.9)
    neck(a, 45.6, 56.6, 62, skin, line)
    head = ("M 38 35 C 39 27, 45 22.6, 53 22.6 C 61.6 22.6, 67.6 28.6, 67.8 37.6 C 68 45, 66.8 51, 64.4 56.4 C 62 61.6, 58 65.6, 53 68 "
            "C 49 69.8, 44.6 69.8, 42.2 68.4 C 39.6 67, 38.4 64, 38.2 60.6 C 38 58.4, 37 56.6, 36 54.6 C 34.8 52.2, 34.4 49, 35 46 C 35.6 42.6, 37 39, 38 35 Z")
    ear(a, 63.6, 50, 1.0, skin, line)
    a.parts.append(f'<circle cx="63" cy="57.6" r="2.4" fill="none" stroke="{ink(GOLD, 0.3)}" stroke-width="1.3"/>')
    a.parts.append(f'<circle cx="63" cy="57.6" r="2.4" fill="none" stroke="{GOLD}" stroke-width="0.7"/>')
    a.part(head, skin, shadow="M 56 23 C 60 31, 62 41, 59.6 50 C 57.6 57.6, 54.6 63.6, 51 70 L 75 72 L 75 22 Z", line=line)
    # sideburns and a pointed chin beard
    a.fill("M 58.6 44 C 59.4 50, 59.6 54.6, 58.6 58.4 L 62.6 55.6 C 63.6 51.6, 63.4 47.6, 62.4 44 Z", beard)
    a.part("M 40 64.4 C 41 69, 43.6 73.4, 46 75 C 47.6 72.6, 49.6 70, 52 68.4 C 48.4 69, 43.6 67.6, 40 64.4 Z", beard, w=0.8)
    # one eye wide, the other screwed shut; brows like flames
    eye(a, 40.6, 46.4, 2.8, 2.5, "#4A2A18", skin, "open", look=-0.4)
    eye(a, 51.6, 46.6, 3.6, 2.8, "#4A2A18", skin, "wink")
    a.line("M 55.6 47.6 L 57.6 48.6 M 55.4 49.2 L 57.2 50.6", line, 0.5, 0.8)
    brow(a, 44.4, 42.2, 35.4, 39.2, 1.0, beard, 1.6, 0.6, 2.3)
    brow(a, 47.6, 43.6, 57.6, 41.6, -0.6, beard, 1.6, 0.6, 2.3)
    # a short broad nose
    a.part("M 45.8 46.6 C 45.4 50.4, 43.4 52.6, 41.2 54.2 C 39.6 55.4, 40 57.4, 42.2 57.4 C 43.6 57.4, 44.4 56.6, 45.6 56.8 C 47.2 57, 48 56, 47.6 54.6 C 47.2 52, 46.6 49.4, 45.8 46.6 Z", skin,
           shadow="M 45 47.6 C 46.4 51, 47 53.6, 46.4 56.6 L 51 56 L 51 47 Z", line=line, w=0.9)
    # the grin: wide, toothy, pulled up on one side
    mouth = "M 38.2 59.4 C 41 63.6, 47 65.4, 52.4 62.6 C 54 61.6, 55 60, 55.4 58.4 C 52 60, 46 60.6, 38.2 59.4 Z"
    a.part(mouth, "#5A1E1E", line=ink(skin, 0.75), w=0.9)
    a.clip(mouth)
    a.fill("M 38 59 C 44 60.6, 50 60.4, 56 58 L 56 61 C 50 62.6, 44 62.4, 38 61 Z", "#FFF6E6")
    a.line("M 42.6 59.8 L 42.8 61.8 M 46.6 60.2 L 46.6 62.2 M 50.4 59.8 L 50.2 61.8", "#C9B8A8", 0.4)
    a.end()
    a.line("M 55.4 58 C 56.4 58.6, 57 59.6, 57 60.8 M 37.6 58.6 C 36.8 59.4, 36.6 60.4, 37 61.4", line, 0.55, 0.8)
    # the bandana: over the top of his head, knotted at the back, its ends flying
    a.part("M 65 43 L 75 46 L 72 51.6 Z", red, shadow="M 70 45 L 75 46 L 72 51.6 Z")
    a.part("M 65.4 41 L 77 38.6 L 74.4 44.6 Z", red, shadow="M 71 40 L 77 38.6 L 74.4 44.6 Z")
    band = "M 35.4 40 C 34.6 29, 42 22.4, 52 22.6 C 62 22.8, 69.4 29, 68.6 41.6 C 60 38, 44 37.4, 35.4 40 Z"
    a.part(band, red, shadow="M 56 23 C 63 25, 68.8 31, 68.6 41.6 C 64 40, 60 39.2, 56 38.8 C 58.6 33, 58.6 27, 56 23 Z", hi="M 38 36 C 39 30, 43 25.6, 49 24.6 C 44.6 27, 41.6 31, 40.6 36.6 Z")
    a.part(circ(66.6, 41.6, 3.2), red, shadow="M 66 38 L 71 38 L 71 46 L 66 46 Z")
    for x, y in ((43, 30.4), (50, 28), (57, 30), (46.6, 34.4), (54, 34)):
        a.fill(f"M {x} {y - 1.4} C {x + 1} {y - 0.4}, {x + 1} {y + 0.8}, {x} {y + 1.2} C {x - 1} {y + 0.8}, {x - 1} {y - 0.4}, {x} {y - 1.4} Z", "#FFC75A", 0.9)
    # the match, struck, held up by his cheek
    a.part("M 74.6 66 L 79.4 46 L 81.4 46.4 L 76.8 66.4 Z", "#E6C79A", shadow="M 80.4 46 L 81.4 46.4 L 76.8 66.4 L 75.8 66.2 Z", w=0.7)
    a.part("M 79.2 44 C 78.2 42, 78.8 40.2, 80.6 40 C 82.4 40, 83 42, 82 44.2 C 81.6 45.4, 80 45.4, 79.2 44 Z", "#8A2A1E", w=0.6)
    flame = "M 80.6 26 C 84 31, 87.6 34.6, 87 39.4 C 86.6 42.6, 84 44.4, 80.8 44.4 C 77.6 44.4, 75 42.6, 75 39.6 C 75 36.6, 77 34.6, 78.2 32 C 78.6 33.8, 79.4 34.8, 80.4 35.4 C 79.6 32.4, 79.6 29, 80.6 26 Z"
    a.part(flame, "#F28A24", hi="M 80.8 34 C 82.8 36.6, 84.4 38.6, 84 40.8 C 83.6 42.4, 82.4 43.2, 80.8 43.2 C 79.2 43.2, 78 42.2, 78 40.6 C 78 38.8, 79.6 37.6, 80.2 36.2 Z",
           line="#B8501A", w=0.8, hi_color="#FFD860", hi_opacity=1)
    # fingers round the match
    a.part("M 70.6 70 C 70 66, 72 63.4, 75 63.4 C 78 63.4, 80 65.6, 79.6 69 C 79.2 72, 76.6 74, 74 74 C 72 74, 70.8 72.4, 70.6 70 Z", skin,
           shadow="M 76 63 C 79 64, 80.4 66.6, 79.6 69 C 79.2 72, 76.6 74, 74 74 L 80 76 L 82 63 Z", line=line, w=0.9)
    a.line("M 72 67.4 C 74 66.4, 76.6 66.4, 78.6 67.6 M 71.6 70.6 C 73.6 69.8, 76 69.8, 78.2 70.8", line, 0.5, 0.8)
    return a.svg()


def naturalist():
    """The naturalist: a round, open face, smiling with her eyes shut, two plaits, a hat
    of three big leaves with a flower tucked in, and her parrot on her shoulder.
    Faces right."""
    skin, line = "#C68A5A", "#5E3420"
    a = Art(skin)
    hair, hair_d = "#4A2C18", "#2E1A0E"
    green, green_d = "#3E9F5B", "#2A7442"
    leaf, leaf_d = "#5DB54A", "#3A8A33"
    # plaits, behind
    for x0, x1 in ((36, 33), (64, 67)):
        for k in range(7):
            t = (k + 0.5) / 7
            x, y = x0 + (x1 - x0) * t, 54 + 32 * t
            wdt = 5 * (1 - 0.25 * t)
            a.group(f"translate({x:.2f} {y:.2f}) rotate({28 if k % 2 == 0 else -28})")
            a.part(ell(0, 0, wdt * 0.62, 3), hair if k % 2 == 0 else hair_d, w=0.7)
            a.end()
    smock = "M 7 104 C 9 88, 19 79, 34 75.4 L 63 73.6 C 79 77, 90 86, 93 104 Z"
    a.part(smock, green, shadow="M 59 72 C 76 77, 89 86, 93 104 L 100 104 L 100 62 Z M 7 104 C 9 96, 13 90, 19 86 C 17 92, 17 98, 18 104 Z")
    a.part("M 37 76.4 C 42 82.4, 56 82.4, 62 75.6 C 57 78.6, 43 79, 37 76.4 Z", "#8C6B3E", w=0.8)
    neck(a, 45.6, 56.4, 62, skin, line)
    # a round face, full cheeks, a soft chin
    head = ("M 37 37 C 38 28.6, 45 23.6, 53 23.6 C 61.6 23.6, 68 29.6, 68 38.6 C 68 46, 66.6 52.6, 63.6 57.6 C 60.6 62.6, 56 66.6, 51 68.2 "
            "C 47 69.4, 43 68.8, 40.8 67 C 38.6 65.2, 37.8 62.4, 37.6 59.6 C 37.4 57.6, 36.4 56, 35.4 54 C 34.2 51.6, 34 48.6, 34.6 45.6 C 35.2 42.4, 36 40, 37 37 Z")
    ear(a, 63.6, 50.4, 0.95, skin, line)
    a.part(head, skin, shadow="M 57 25 C 61 33, 62.6 42, 60.4 51 C 58.4 58.6, 55 64, 50 69.6 L 75 72 L 75 22 Z", line=line)
    # rosy cheeks, eyes shut with smiling
    a.fill(circ(38.6, 55.4, 2.4), "#E07A5A", 0.35)
    a.fill(circ(53.6, 55.4, 3), "#E07A5A", 0.35)
    eye(a, 40.8, 48, 2.6, 2.4, "#4A2A18", skin, "happy")
    eye(a, 51.8, 48, 3.4, 2.8, "#4A2A18", skin, "happy")
    brow(a, 44, 42.4, 36, 42, 1.4, hair, 1.4, 0.8, 1.8)
    brow(a, 48, 42.2, 57, 41.6, 1.8, hair, 1.4, 0.8, 1.8)
    # a small round nose
    a.part("M 45.4 48.6 C 44.6 51.4, 42.4 52.8, 41.6 54.6 C 41 56.2, 42.4 57.4, 44.2 57 C 45.4 56.8, 46.4 57, 47.2 56.2 C 47.8 54.6, 46.8 51.8, 45.4 48.6 Z", skin,
           shadow="M 45 49.6 C 46.6 52, 47.4 54.4, 47 56.6 L 51 56 L 51 48 Z", line=line, w=0.9)
    # a wide open smile
    mouth = "M 39.6 60 C 42 64.6, 49 65.6, 53.6 60.6 C 49.4 61.6, 44 61.6, 39.6 60 Z"
    a.part(mouth, "#6E2626", line=ink(skin, 0.75), w=0.9)
    a.clip(mouth)
    a.fill("M 39 59.6 C 44 61, 49.6 61, 54 60 L 54 62 C 49.6 63, 44 63, 39 61.8 Z", "#FFF6E6")
    a.fill("M 42.6 64 C 45 65.6, 48.6 65.6, 51 63.6 C 48.6 63, 45 63, 42.6 64 Z", "#D8605A")
    a.end()
    # hair parted over her brow
    a.part("M 35.6 47 C 35 36, 41 30, 50 30 C 59 30, 65.6 35.6, 66.4 45 C 61.6 38.6, 55.4 37.6, 50.6 39.6 C 46 37.6, 39.6 39.4, 35.6 47 Z", hair,
           shadow="M 56 31 C 62 33.6, 65.6 38.6, 66.4 45 C 63 41, 60 39, 56 38.6 Z", hi="M 39 41 C 41 35.6, 44.6 33, 49 32.4 C 44.6 34.6, 41.6 37.6, 40.4 41.6 Z")
    # a hat of three big leaves, a flower tucked in
    for d, c, sh in (
        ("M 47 35 C 38 32, 27 25, 24 14 C 35 13.6, 45 21, 49.6 33 Z", leaf, "M 47 35 C 40 31, 32 25, 28 17 C 33 21, 40 27, 49.6 33 Z"),
        ("M 54 35 C 63 32, 74 25, 77 14 C 66 13.6, 56 21, 51.4 33 Z", leaf_d, "M 54 35 C 61 31, 69 25, 73 17 C 68 21, 61 27, 51.4 33 Z"),
        ("M 50.6 35 C 43.6 27, 42.6 15, 50.6 5 C 58.6 15, 57.6 27, 50.6 35 Z", "#7CC85A", "M 50.6 35 C 54 27, 55.4 17, 50.6 5 C 57.6 15, 57.6 27, 50.6 35 Z"),
    ):
        a.part(d, c, shadow=sh, line=ink(leaf_d, 0.45))
    a.line("M 48.6 33 C 41 28, 33 22, 27 15.6 M 52.6 33 C 60 28, 68 22, 74 15.6 M 50.6 33 L 50.6 8", ink(leaf_d, 0.3), 0.6, 0.8)
    for k in range(5):
        ang = -math.pi / 2 + k * 2 * math.pi / 5
        x, y = 40 + math.cos(ang) * 2.4, 33 + math.sin(ang) * 2.4
        a.part(circ(x, y, 1.9), "#FFF4E0", line="#C9A27A", w=0.5)
    a.part(circ(40, 33, 1.3), "#F2B33D", w=0.5)
    # her parrot, standing on her shoulder
    p_red = "#E0412E"
    a.part("M 74.6 72 C 75.6 80, 76.6 88, 76.6 97 L 81 97 C 81 88, 80.4 80, 79 72 Z", "#2E7FC9", shadow="M 78 72 L 82 72 L 82 97 L 79 97 Z")
    body = "M 70 72 C 67 67, 68 60, 72.6 57.4 C 76.6 55.4, 81.4 57.4, 82 62.6 C 82.6 67.4, 80 72.4, 77.6 76 C 75.6 76.6, 72 75.6, 70 72 Z"
    a.part(body, p_red, shadow="M 77 56 C 81 58, 82.6 62, 82 66 C 81 71, 79 74, 77.6 76 L 86 77 L 86 55 Z", hi="M 70.4 63 C 70.6 60, 72 58.4, 74.4 57.6 C 72.6 59.4, 71.6 61.4, 71.4 64 Z")
    a.part("M 73.6 63 C 76.6 65, 79.6 69, 80.4 74 C 78 74.6, 75.6 73.6, 74 71 C 73 68.6, 72.8 65.6, 73.6 63 Z", "#2E7FC9", shadow="M 77 66 L 81 66 L 81 75 L 77 75 Z", w=0.8)
    a.fill("M 74.2 70.6 C 75.6 72.6, 77.4 73.8, 79.6 74 L 80.4 74 C 78 74.6, 75.6 73.6, 74.2 70.6 Z", "#F2C02E")
    a.fill(circ(72.8, 60.6, 2), WHITE)
    a.fill(circ(72.5, 60.6, 0.95), "#1A1418")
    a.part("M 69.6 60 C 66.6 59.6, 64.6 62, 65 65 C 65.2 66.6, 66.2 67.8, 67.2 68 C 67 66.6, 67.4 65.4, 68.4 64.8 C 69.4 64.4, 70.2 64.6, 70.8 65.2 C 71 63.4, 70.8 61.4, 69.6 60 Z",
           "#F2E2C4", shadow="M 64 65 L 72 65 L 72 69 L 64 69 Z", line="#5A4A34", w=0.7)
    for x in (73, 76):
        a.line(f"M {x} 75.6 L {x - 0.6} 77.6 M {x} 75.6 L {x + 0.8} 77.6", "#6A6070", 0.7)
    return a.svg(mirror=True)


def warper():
    """The warper: long and thin-faced, a pointed chin, one brow cocked over a heavy-lidded
    look, a pencil moustache, a broad pink hat with a white plume, and a little swirl of
    warp turning over his raised fingers."""
    skin, line = "#F0C29A", "#7A4A34"
    a = Art(skin)
    pink, pink_d = "#D35A9C", "#9E3A72"
    hair = "#5A3A22"
    a.glow(78, 70, 15, "#E8A8FF", 0.5)
    coat = "M 10 104 C 11 89, 21 80, 35 76.4 L 61 74.6 C 77 78, 88 87, 90 104 Z"
    a.part(coat, pink, shadow="M 57 73 C 74 78, 87 87, 90 104 L 100 104 L 100 62 Z M 10 104 C 12 96, 16 90, 22 86 C 20 92, 20 98, 21 104 Z")
    a.part("M 42 76 L 49.6 91 L 57 75.4 C 54 77.6, 45 78, 42 76 Z", CREAM, w=0.8)
    a.part("M 46 80.4 C 47 78.6, 52.6 78.6, 53.6 80.4 L 51.6 84.4 L 48 84.4 Z", CREAM, w=0.7)
    neck(a, 46.4, 56.4, 63, skin, line)
    # a long narrow face, high cheekbones, a pointed chin
    head = ("M 39 33 C 40 25, 46 20.4, 53.6 20.4 C 62 20.4, 67.6 26.4, 67.6 35.6 C 67.6 43, 66 49.6, 63 55.6 C 60 61.6, 55.6 67, 50.6 70.4 "
            "C 47.6 72.4, 44.6 72.6, 43 71.4 C 41 69.8, 40.4 67, 40 64 C 39.6 61, 38.4 58.6, 37.4 56.4 C 36.2 53.6, 35.8 50, 36.4 46.6 C 37 42.4, 38 37.6, 39 33 Z")
    ear(a, 63, 48.6, 0.95, skin, line)
    a.part(head, skin, shadow="M 56 21 C 60 29, 61.6 39, 59.4 48 C 57.4 56, 54 63, 49.6 71.6 L 74 74 L 74 20 Z", line=line)
    a.line("M 56.6 52 C 55.6 55, 54.6 57, 53 58.6", line, 0.5, 0.6)
    # heavy-lidded, knowing; one brow cocked
    eye(a, 41.6, 46.2, 2.6, 2.2, "#6A4A8A", skin, "open", look=-0.45, lid=0.34)
    eye(a, 52, 46, 3.4, 2.5, "#6A4A8A", skin, "open", look=-0.45, lid=0.3)
    brow(a, 44.6, 42.4, 36.6, 42.6, 0.6, hair, 1.2, 0.6, 1.6)
    brow(a, 48.4, 41.4, 57.6, 37.6, 3.4, hair, 1.2, 0.6, 1.7)
    # a long straight nose
    a.part("M 46.6 45 C 46 50, 44.4 54, 40.8 57.6 C 39.6 58.8, 40.4 60.2, 42.4 60 C 44 59.8, 45.4 59.6, 46.8 59.2 C 47.6 55, 47.6 50, 46.6 45 Z", skin,
           shadow="M 45.6 46 C 46.8 50, 47 55, 46.6 59.6 L 51 59 L 51 45 Z", line=line, w=0.9)
    # a pencil moustache curled at the ends, and a thin smile under it
    a.fill(taper(bez((47, 61.6), (44.4, 60.6), (41.4, 61), (39.6, 62.6), 10), 1.2, 0.4, 1.0), hair)
    a.fill(taper(bez((47.4, 61.6), (50.4, 60.8), (53.6, 61.2), (55, 62.8), 10), 1.2, 0.4, 1.0), hair)
    a.line("M 39.6 62.6 C 39 62, 39.2 61.2, 40 61 M 55 62.8 C 55.8 62.2, 55.8 61.4, 55 61", hair, 0.6)
    a.line("M 42 64.4 C 45 65.2, 49 64.8, 52 63 C 53 62.4, 53.8 61.6, 54.2 60.8", mix(skin, "#6E2A22", 0.5), 0.9)
    a.line("M 53.6 60 C 54.6 60.4, 55 61.2, 54.8 62", line, 0.45, 0.7)
    # the hat: a broad brim tipped down over one eye, a tall crown, a plume curling back
    plume = "M 55 25 C 63 16, 76 13, 88 18 C 83 18.6, 79 20, 76 22.4 C 81 22, 85.6 23.6, 88 26.6 C 81 25, 74 25.4, 68 27.4 C 72 28, 75 29.6, 76.6 31.6 C 69.6 29.6, 62 29.6, 57 31 Z"
    a.part(plume, "#FFFFFF", shadow="M 57 31 C 64 29, 72 29, 76.6 31.6 C 74 30.6, 70 30.2, 66 30.4 C 70 28, 76 26.4, 84 26 L 88 30 L 56 33 Z", line="#B8A8C0", w=0.8)
    crown = "M 36.4 37 C 36 26, 41.4 18.6, 50.6 18.6 C 59.6 18.6, 65 25.6, 64.6 36.6 Z"
    a.part(crown, pink, shadow="M 55 19 C 61 21, 65 27, 64.6 36.6 L 57 36.6 C 58.6 30, 58 24, 55 19 Z", hi="M 40 33 C 40 26, 43 21.6, 48 20.4 C 44 23, 42 27.6, 42 33.6 Z")
    a.part("M 35.6 33.4 C 44 35.6, 57 35.6, 65.4 33.4 L 65.4 37 C 57 39.2, 44 39.2, 35.6 37 Z", "#5A2A44", w=0.8)
    brim = "M 16 41 C 15 36, 32 33.4, 50 33.4 C 67 33.4, 84 35.4, 85 40 C 85.6 44, 68 44.6, 50 44.4 C 34 44.2, 17 45, 16 41 Z"
    a.part(brim, pink, shadow="M 16 41 C 30 44, 48 44.4, 64 43.4 C 74 42.6, 81 41.6, 85 40 C 85.6 44, 68 44.6, 50 44.4 C 34 44.2, 17 45, 16 41 Z", hi="M 20 39.4 C 28 36.6, 40 35.4, 52 35.4 C 40 36.6, 29 38, 22 40.4 Z")
    # his raised hand, and the warp turning over his fingers
    a.part("M 70 82 C 69 76, 71.6 72, 75.6 72 C 79.6 72, 82 75.4, 81.4 79.6 C 80.8 84, 77.6 86.4, 74.4 86.4 C 71.6 86.4, 70.4 84.6, 70 82 Z", skin,
           shadow="M 77 72 C 80.6 73, 82 76, 81.4 79.6 C 80.8 84, 77.6 86.4, 74.4 86.4 L 84 88 L 84 72 Z", line=line, w=0.9)
    a.line("M 71.2 77.6 C 73.6 76.6, 76.6 76.6, 79.6 77.8 M 70.8 80.6 C 73.4 79.8, 76.4 79.8, 79.4 81", line, 0.5, 0.8)
    for k, (r, op) in enumerate(((7.6, 0.95), (5.4, 0.9), (3.2, 0.85))):
        a0 = k * 1.4
        pts = [(77 + math.cos(a0 + t * 4.6) * r * (1 - 0.25 * t), 62 + math.sin(a0 + t * 4.6) * r * 0.55 * (1 - 0.25 * t)) for t in [i / 14 for i in range(15)]]
        a.fill(taper(pts, 0.4, 0.4, 1.6), "#B66AE0", op)
    a.fill(circ(77, 62, 1.2), "#F4D8FF")
    return a.svg()


def overseer():
    """The harbour master: a broad, heavy face, a stern brow, a close grey beard, a navy
    tricorn trimmed in gold, gold coat with navy facings and a medal; his brass spyglass
    under his arm. Faces right."""
    skin, line = "#7A4E2D", "#3A2010"
    a = Art(skin)
    gold, gold_d = "#E7B023", "#A87A10"
    grey = "#D8D2C8"
    coat = "M 4 104 C 6 87, 17 77.6, 32 74 L 66 72 C 82 76, 93 86, 96 104 Z"
    a.part(coat, gold, shadow="M 62 71 C 80 76, 92 86, 96 104 L 100 104 L 100 60 Z M 4 104 C 6 96, 10 90, 16 85 C 14 92, 14 98, 15 104 Z")
    for d in ("M 37 76 C 39 84, 41 93, 42 104 L 33 104 C 32 94, 32 85, 33 77.4 Z", "M 61 75 C 59 83, 57 92, 56.4 104 L 65.4 104 C 66 94, 66 85, 65 76 Z"):
        a.part(d, NAVY, shadow="M 56 74 L 61 74 L 58 104 L 54 104 Z")
    a.part(circ(48, 88, 3.4), GOLD, hi="M 45 86 C 46 84.6, 48 84.2, 49.4 84.8 C 47.6 85.4, 46.4 86.6, 46 88.4 Z")
    a.part("M 46 80 L 50 80 L 49.4 84.8 L 46.6 84.8 Z", "#C23A3A", w=0.7)
    neck(a, 44.6, 58, 62, skin, line)
    # a broad square face, heavy jaw
    head = ("M 36.6 36 C 37.6 27.6, 45 22.6, 53.6 22.6 C 62.6 22.6, 69.4 28.6, 69.6 38 C 69.8 46, 68.6 53, 66 58.6 C 63.4 64, 58.6 67.6, 53 69.2 "
            "C 48.4 70.4, 43.6 70.2, 41.2 68.4 C 38.8 66.6, 37.8 63.6, 37.4 60.4 C 37 57.8, 35.8 55.8, 34.8 53.6 C 33.8 51, 33.6 48, 34.2 45 C 34.8 42, 35.6 39, 36.6 36 Z")
    ear(a, 65, 50, 1.05, skin, line)
    a.part(head, skin, shadow="M 57.6 24 C 62 32, 63.6 42, 61.4 51 C 59.4 58.6, 56 64.6, 51.6 70.6 L 77 72 L 77 22 Z", line=line)
    # a close grey beard along the jaw and round the mouth
    beard = ("M 35 52.6 C 35.4 60.6, 39.6 67.6, 46 70.6 C 51 72.6, 57.6 71.6, 62 67.6 C 65.4 64.4, 67 60, 67.2 55 C 64.6 59.4, 60.6 61.4, 57.6 61.4 "
             "C 55.6 63.6, 52 64.6, 48.6 64.4 C 45 64.2, 41.6 63, 39.6 61 C 37.4 59.6, 35.8 56.4, 35 52.6 Z")
    a.part(beard, grey, shadow="M 56 60 C 60 61, 64 59, 67.2 55 C 67 60, 65.4 64.4, 62 67.6 C 58 71, 54 72, 50 72 Z", line=mix(grey, INK, 0.45))
    a.part("M 48.4 58.6 C 45.4 58, 41.6 59, 39.4 60.8 C 38.6 61.6, 39 62.6, 40 62.4 C 42.6 61.6, 45.6 61.4, 48.4 61.6 C 51.6 61.4, 54.6 61.6, 57 62.4 C 58 62.6, 58.6 61.6, 57.6 60.8 C 55.4 59, 51.6 58, 48.4 58.6 Z",
           grey, shadow="M 48 60.6 L 58 61 L 58 64 L 48 64 Z", line=mix(grey, INK, 0.45), w=0.8)
    a.line("M 43.6 64.6 C 46 65.4, 49.6 65.4, 52.6 64.4", "#3A2010", 1.1)
    # deep-set eyes under a stern brow
    eye(a, 40.4, 47, 2.6, 2.2, "#4A3020", skin, "open", look=-0.5, lid=0.3)
    eye(a, 52, 47, 3.4, 2.5, "#4A3020", skin, "open", look=-0.5, lid=0.3)
    brow(a, 44.6, 41.8, 35, 42.4, -0.6, grey, 2.2, 1.2, 2.8)
    brow(a, 47.6, 41.6, 58.4, 42.2, -0.4, grey, 2.2, 1.2, 2.8)
    a.line("M 45.6 42.6 L 46.2 44.6", line, 0.6, 0.8)
    # a broad nose
    a.part("M 45.8 46.6 C 45.4 50.6, 43.4 52.8, 40.8 54.6 C 39 55.8, 39.6 58.2, 42 58.2 C 43.6 58.2, 44.8 57.4, 46 57.6 C 48 57.8, 49.2 56.6, 48.6 54.8 C 48 52, 46.8 49.4, 45.8 46.6 Z", skin,
           shadow="M 45 47.6 C 47 51, 48.4 53.6, 47.8 57.6 L 52 57 L 52 47 Z", line=line, w=0.9)
    # the tricorn: navy, its brim turned up, trimmed in gold
    a.part("M 37.4 33 C 39 21, 61 20, 64.4 32 Z", NAVY, shadow="M 55 21.6 C 60.6 23.6, 63.4 27.6, 64.4 32 L 57 32 Z")
    tri = "M 22 41 C 26 30.6, 38 26.6, 50 29.6 C 62 26.6, 74 30.6, 78.6 41.4 C 68 37, 58.6 37.6, 50.6 42.6 C 42.6 37.6, 33 37, 22 41 Z"
    a.part(tri, NAVY, shadow="M 50.6 42.6 C 58.6 37.6, 68 37, 78.6 41.4 C 75 34, 68 30, 60 29 C 62 33, 60 38, 50.6 42.6 Z", hi="M 25 38 C 29 32, 37 29.4, 46 30 C 38 31.6, 31 34.6, 27 39 Z")
    a.line("M 22.6 40.4 C 33 36.6, 42.6 37.2, 50.6 41.8 C 58.6 37.2, 68 36.6, 78 40.8", GOLD, 1.2)
    a.part(circ(50.6, 34, 2.2), "#F6EEDC", line="#8A8070", w=0.6)
    # the spyglass, tucked under his arm
    a.part("M 74 104 L 80 76 L 85.6 77.2 L 80.6 104 Z", "#C9A227", shadow="M 83 76.6 L 85.6 77.2 L 80.6 104 L 78 104 Z", hi="M 76 100 L 81 78 L 82 78.2 L 77.4 100 Z")
    a.part("M 79.4 78 L 81.4 66.6 L 86.4 67.6 L 85.4 78.8 Z", "#A87A00", shadow="M 84 67.2 L 86.4 67.6 L 85.4 78.8 L 83 78.4 Z")
    a.part("M 78.6 78.6 L 86.6 80.2 L 86.2 82.6 L 78.2 81 Z", "#8A6A10", w=0.7)
    return a.svg(mirror=True)


def gambler():
    """The gambler: a heart-shaped face, a sly sideways look from half-closed eyes, one
    corner of her mouth up, a beauty mark, a glossy bob, a small teal tricorn cocked over
    one eye, and a card held up between two fingers."""
    skin, line = "#F0C8A0", "#7A4A34"
    a = Art(skin)
    hair, hair_l = "#2E1E16", "#5A3E2E"
    teal, teal_d = "#22A094", "#156A62"
    # her bob, behind
    a.part("M 34 44 C 33 32, 41 25, 52 25 C 63 25, 70 32, 70 44 C 70 52, 70 58, 68 63 C 66 66, 62 66.6, 60 64.6 L 40 64.6 C 37 62, 34.6 56, 34 44 Z", hair, line=ink(hair, 0.4))
    coat = "M 10 104 C 11 89, 21 80, 35 76.4 L 61 74.6 C 77 78, 88 87, 90 104 Z"
    a.part(coat, teal, shadow="M 57 73 C 74 78, 87 87, 90 104 L 100 104 L 100 62 Z M 10 104 C 12 96, 16 90, 22 86 C 20 92, 20 98, 21 104 Z")
    a.part("M 41 76.6 L 49.4 88 L 58 76 C 54 78.6, 45 79, 41 76.6 Z", CREAM, w=0.8)
    a.part("M 44.4 79.4 C 46.4 76.8, 48.6 77.8, 49.6 80 C 50.8 77.8, 53 76.8, 55 79.4 C 53 82, 50.8 82, 49.6 80 C 48.4 82, 46.4 82, 44.4 79.4 Z", "#D8463E", w=0.6)
    neck(a, 46, 56, 62.6, skin, line)
    # a heart-shaped face: wide at the cheekbones, a small pointed chin
    head = ("M 37.6 36 C 38.6 28, 45 23.4, 53 23.4 C 61.6 23.4, 67.4 29.4, 67.4 38 C 67.4 45, 66 51, 62.8 56.6 C 59.6 62, 55 66.6, 50 69 "
            "C 47 70.4, 44.4 70.4, 42.8 69 C 41.2 67.6, 40.4 65, 40 62.4 C 39.6 60, 38.4 58, 37.2 56 C 35.8 53.4, 35.2 50, 35.8 46.6 C 36.4 42.6, 37 39.6, 37.6 36 Z")
    a.part(head, skin, shadow="M 56.6 24 C 60.6 32, 62 42, 59.6 50.6 C 57.6 58, 54 63.6, 49.4 69.6 L 74 72 L 74 22 Z", line=line)
    a.fill(circ(53.4, 55.4, 2.8), "#E8826A", 0.3)
    # half-closed eyes, looking sideways; long lashes
    eye(a, 41.2, 47, 2.6, 2.4, "#3E8A5A", skin, "half", look=-0.7)
    eye(a, 51.8, 46.8, 3.6, 2.7, "#3E8A5A", skin, "half", look=-0.7)
    a.line("M 55.4 45.6 L 57.4 44.6 M 55.6 46.6 L 57.8 46.4", "#2A1A1A", 0.6)
    brow(a, 44.6, 42.2, 36.6, 41.6, 1.6, hair, 1.0, 0.5, 1.4)
    brow(a, 48.2, 41.6, 57.6, 40.4, 2.2, hair, 1.0, 0.5, 1.4)
    # a small straight nose
    a.part("M 46 47.4 C 45.6 51, 43.8 53.6, 41.8 55.2 C 40.8 56.2, 41.6 57.4, 43.2 57.2 C 44.4 57, 45.6 56.8, 46.6 56.2 C 47 53.6, 46.8 50.6, 46 47.4 Z", skin,
           shadow="M 45.2 48.4 C 46.4 51, 46.8 53.6, 46.4 56.6 L 50 56 L 50 47 Z", line=line, w=0.9)
    # one corner of her mouth up; a beauty mark
    a.part("M 41.4 61.6 C 44.6 62.8, 48.4 62.4, 51.6 60 C 50.4 62.6, 47.4 64.2, 44.6 63.8 C 43 63.6, 42 62.8, 41.4 61.6 Z", "#C8504A", line=ink("#C8504A", 0.5), w=0.6)
    a.line("M 41 61.4 C 44.6 62.4, 48.6 62, 52 59.4", mix(skin, "#5A1E1E", 0.6), 0.8)
    a.fill(circ(54.6, 59.4, 0.65), "#3A2018")
    # the glossy bob framing her face
    a.part("M 35 46 C 34.6 33.6, 42 27.6, 51 27.6 C 60 27.6, 67.6 33.6, 67.2 46 C 63.4 39.6, 58 38, 54 39 C 50.6 37.6, 45 37.6, 42 40 C 39.6 40.4, 36.6 42.6, 35 46 Z", hair,
           hi="M 40 37 C 42.6 32.6, 46.6 30.2, 51.6 30 C 47 32, 44 34.6, 42 38.6 Z", hi_color=hair_l, hi_opacity=0.9)
    a.part("M 35.2 44 C 33.6 51, 33.6 58, 36.2 62.6 C 37.6 64.6, 40.6 64.6, 41.4 62.6 C 39.6 58, 38.6 51, 39.2 45 Z", hair, hi_color=hair_l)
    a.part("M 67 44 C 68.6 51, 68.6 58, 66 62.6 C 64.6 64.6, 61.6 64.6, 60.6 62.6 C 62.6 58, 63.6 51, 63 45 Z", hair, hi_color=hair_l)
    # a small teal tricorn, cocked over one eye
    a.group("rotate(-12 52 30)")
    a.part("M 38 29 C 39.6 17, 62 16, 64.6 26.6 Z", teal, shadow="M 56 17.6 C 61 19.6, 64 23, 64.6 26.6 L 58 27 Z")
    tri = "M 27 34.6 C 31.6 25, 42 21.6, 51.6 24.2 C 61 21.6, 70 24.4, 74.6 32.2 C 65.6 29.6, 57.6 30, 51.4 34.8 C 44.6 30.6, 35 30.6, 27 34.6 Z"
    a.part(tri, teal, shadow="M 51.4 34.8 C 57.6 30, 65.6 29.6, 74.6 32.2 C 71 27, 65 24, 59 23.6 C 60.6 27.6, 58.6 31, 51.4 34.8 Z", hi="M 30 32 C 34 27, 41 24.6, 48 25.2 C 41 26.6, 35 29, 31.6 33 Z")
    a.line("M 27.6 34 C 35 31, 44.6 30.8, 51.4 34 C 57.6 30.2, 65.6 29.8, 74 31.8", GOLD, 0.9)
    a.end()
    # a card held up between two fingers
    a.group("rotate(-14 79 66)")
    a.part("M 72 54 L 85 54 L 85 72 L 72 72 Z", CREAM, shadow="M 81 54 L 85 54 L 85 72 L 81 72 Z", line="#8A7A60", w=0.8)
    a.fill("M 78.4 60 C 76.6 57.6, 73.8 59.4, 75.6 62 L 78.4 65.4 L 81.2 62 C 83 59.4, 80.2 57.6, 78.4 60 Z", "#D8463E")
    a.fill("M 73.4 55.4 L 75.6 55.4 L 75.6 56.6 L 73.4 56.6 Z", "#D8463E")
    a.end()
    a.part("M 70.6 76 C 70 71.6, 72.4 68.6, 75.6 68.6 C 78.8 68.6, 80.8 71.4, 80.2 74.8 C 79.6 78.4, 77 80.4, 74.4 80.4 C 72.2 80.4, 70.8 78.6, 70.6 76 Z", skin,
           shadow="M 77 68.6 C 80 69.6, 80.8 72, 80.2 74.8 C 79.6 78.4, 77 80.4, 74.4 80.4 L 82 82 L 82 68 Z", line=line, w=0.9)
    a.line("M 71.6 72.6 C 73.6 71.6, 76.4 71.6, 78.8 72.8", line, 0.5, 0.8)
    return a.svg()


def cannoneer():
    """The cannoneer: a big square head on a bull neck, a broad grin under a huge ginger
    handlebar moustache, a squint, soot on his cheek, a dented steel helmet, a bandolier,
    and a cannonball on his shoulder. Faces right."""
    skin, line = "#D99C76", "#6E3A26"
    a = Art(skin)
    ginger, ginger_d = "#C0562A", "#86361A"
    brown = "#93633A"
    steel, steel_d = "#8C94A3", "#5E6676"
    coat = "M 2 104 C 4 86, 16 76.6, 31 73 L 67 71 C 84 75, 95 86, 98 104 Z"
    a.part(coat, brown, shadow="M 63 70 C 82 75, 94 86, 98 104 L 100 104 L 100 60 Z M 2 104 C 4 96, 8 90, 14 85 C 12 92, 12 98, 13 104 Z")
    a.part("M 24 82 L 30 78 L 70 104 L 60 104 Z", "#3A2A1E", w=0.8)
    for k in range(4):
        x, y = 34 + k * 7.6, 84 + k * 5
        a.part(f"M {x} {y - 2.4} L {x + 3} {y - 0.6} L {x + 2} {y + 2.6} L {x - 1} {y + 1} Z", GOLD, w=0.5)
    neck(a, 43.6, 59.6, 61, skin, line)
    # a big square head
    head = ("M 35.6 36 C 36.6 27, 44.6 22, 53.6 22 C 63 22, 70 28, 70.4 38 C 70.6 46, 69.6 53, 67.4 58.6 C 65 64.6, 60 68.6, 54 70.4 "
            "C 49 71.8, 43.6 71.6, 40.6 69.6 C 38 67.6, 37 64.6, 36.6 61.4 C 36.2 58.6, 35 56.4, 34 54 C 33 51.4, 32.8 48, 33.4 45 C 34 42, 34.8 39, 35.6 36 Z")
    ear(a, 65.6, 49.6, 1.1, skin, line)
    a.part(head, skin, shadow="M 58 23 C 62.6 31, 64.4 41, 62.4 50.6 C 60.4 58.6, 57 64.6, 52.6 71.6 L 78 73 L 78 22 Z", line=line)
    # soot smudged across his cheek
    a.fill("M 52 52.6 C 55 51, 59 51.6, 60 54 C 58 55.6, 54.6 55.6, 52 52.6 Z M 36 55 C 37 54, 39 54.4, 39.6 55.4 C 38.6 56.2, 37 56.2, 36 55 Z", "#3A3438", 0.45)
    # a squint and a grin
    eye(a, 39.8, 47.4, 2.7, 2.4, "#4A6A8A", skin, "squint", look=-0.4)
    eye(a, 51.6, 47.2, 3.6, 2.8, "#4A6A8A", skin, "squint", look=-0.4)
    a.line("M 55.6 49 L 57.8 50 M 55.8 50.6 L 57.6 52", line, 0.5, 0.8)
    brow(a, 44, 42.6, 34.6, 42, 1.2, ginger_d, 2.4, 1.4, 3.0)
    brow(a, 47.6, 42.4, 58, 41.6, 1.6, ginger_d, 2.4, 1.4, 3.0)
    # a big round nose
    a.part("M 45.6 47.4 C 45.4 50.6, 43.6 52.4, 41 54 C 37.6 56, 38.6 60, 42.4 59.8 C 44 59.6, 45.2 58.6, 46.6 58.8 C 49.2 59, 50.6 57.2, 49.6 54.8 C 48.6 52.4, 46.6 50.4, 45.6 47.4 Z", skin,
           shadow="M 45.6 48.6 C 47.6 51.4, 49.6 53.6, 49.4 57.6 C 48.6 58.6, 47.4 59, 46.6 58.8 L 53 59 L 53 47 Z", line=line, w=0.9)
    # the grin
    mouth = "M 39.4 63.4 C 42.6 67.6, 50 68.4, 55 63.6 C 50 64.6, 44.4 64.6, 39.4 63.4 Z"
    a.part(mouth, "#5A1E1E", line=ink(skin, 0.75), w=0.9)
    a.clip(mouth)
    a.fill("M 39 63 C 44.6 64.4, 50 64.4, 55.4 63.2 L 55.4 65 C 50 66.2, 44.6 66.2, 39 65 Z", "#FFF6E6")
    a.end()
    # the handlebar moustache: thick under his nose, the ends swept up and curled
    for side in (-1, 1):
        cx = 45.4
        p0 = (cx, 60.6)
        p3 = (cx + side * (12.6 if side > 0 else 9.4), 56.4)
        pts = bez(p0, (cx + side * 4, 62.6), (p3[0] - side * 2, 62), p3, 14)
        a.fill(taper(pts, 3.6, 1.0, 3.6), ginger)
        a.fill(taper(pts[6:], 1.2, 0.3, 1.0), mix(ginger, "#FFE0B0", 0.35), 0.6)
        tip = p3
        a.line(f"M {tip[0]} {tip[1]} C {tip[0] + side * 1.6} {tip[1] - 1.6}, {tip[0] + side * 0.4} {tip[1] - 3.6}, {tip[0] - side * 1.2} {tip[1] - 2.6}", ginger, 1.2)
    a.line("M 45.4 59.6 C 44 60.6, 43 61.4, 42.4 62.4 M 45.4 59.6 C 46.8 60.6, 48 61.4, 48.8 62.4", ginger_d, 0.5, 0.8)
    # the helmet: dented, its brim tipped back
    helm = "M 33.6 38.6 C 33 25.6, 41.6 18.6, 51.6 18.6 C 61.6 18.6, 70 25.6, 69.6 38.6 Z"
    a.part(helm, steel, shadow="M 57 19.6 C 64 22, 69.8 28.6, 69.6 38.6 L 60 38.6 C 62 32, 61 25, 57 19.6 Z", hi="M 38 34 C 38.6 27, 42.6 22.4, 48 21 C 44 24.4, 41.6 28.6, 41.2 34 Z", hi_color="#E4E8EE", hi_opacity=0.8)
    a.fill("M 44 27 C 46 25.6, 48.6 25.8, 49.6 27.6 C 47.6 28.6, 45.6 28.6, 44 27 Z", steel_d, 0.8)
    brim = "M 24 40.4 C 24 36.6, 37 35.4, 51.6 35.4 C 66 35.4, 79 36.6, 79 40.4 C 79 43.4, 66 44.6, 51.6 44.6 C 37 44.6, 24 43.4, 24 40.4 Z"
    a.part(brim, steel_d, shadow="M 24 40.4 C 36 43.6, 56 44.4, 79 40.4 C 79 43.4, 66 44.6, 51.6 44.6 C 37 44.6, 24 43.4, 24 40.4 Z", hi="M 28 39 C 36 37, 46 36.4, 56 36.6 C 46 37.4, 36 38.4, 29.6 40 Z", hi_color="#C4CAD4", hi_opacity=0.7)
    # the cannonball on his shoulder, steadied by his hand
    a.part(circ(22, 70, 10.6), "#3C3C46", shadow="M 22 59 C 30 61, 33.6 68, 32.4 74 C 31 79, 27 81, 22 80.6 L 36 84 L 36 58 Z",
           hi="M 15 66 C 16 62, 19.6 60.6, 22.6 61 C 19.4 62.6, 17.6 65, 17.4 68 Z", hi_color="#9AA0B0", hi_opacity=0.7)
    a.part("M 26 81 C 25 77, 27.6 74, 31 74.2 C 34.4 74.4, 36 77.4, 35.4 80.6 C 34.8 84, 32 86, 29.4 85.6 C 27.4 85.4, 26.2 83.6, 26 81 Z", skin,
           shadow="M 32 74.2 C 35 75, 36 77.6, 35.4 80.6 C 34.8 84, 32 86, 29.4 85.6 L 38 87 L 38 74 Z", line=line, w=0.9)
    return a.svg(mirror=True)


PORTRAITS = [
    ("mage", mage), ("trapper", trapper), ("fire_starter", fire_starter), ("naturalist", naturalist),
    ("warper", warper), ("overseer", overseer), ("gambler", gambler), ("cannoneer", cannoneer),
]


def sprites():
    return [(name, draw()) for name, draw in PORTRAITS]
