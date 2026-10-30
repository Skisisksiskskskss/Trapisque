"""
The emblem style, shared by the characters' emblems (art/emblems.py) and the cards'
icons (art/cards.py): a round badge (an outer rim, a ring, a field) and a bold symbol on
it in flat colours, each part outlined thick in its ink, with a darker cut along its
lower right edge and a soft drop shadow on the field. Lit from the upper left like the
rest of the art. Every drawing is on a 100 x 100 canvas, the badge's middle at (50, 50).
"""
import math

INK = "#2A2830"
CREAM, CREAM_D = "#FFF6E6", "#E2CFAF"
GOLD, GOLD_L, GOLD_D = "#F5C14B", "#FFE08A", "#C98E1E"


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def _hex(c):
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    ca, cb = _rgb(a), _rgb(b)
    return _hex(tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3)))


def circ(cx, cy, r):
    return f"M {cx - r:.2f} {cy:.2f} A {r:.2f} {r:.2f} 0 1 0 {cx + r:.2f} {cy:.2f} A {r:.2f} {r:.2f} 0 1 0 {cx - r:.2f} {cy:.2f} Z"


def ell(cx, cy, rx, ry):
    return f"M {cx - rx:.2f} {cy:.2f} A {rx:.2f} {ry:.2f} 0 1 0 {cx + rx:.2f} {cy:.2f} A {rx:.2f} {ry:.2f} 0 1 0 {cx - rx:.2f} {cy:.2f} Z"


def poly(pts):
    return "M " + " L ".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


def rrect(x, y, w, h, r):
    """A rounded rectangle."""
    r = min(r, w / 2, h / 2)
    return (f"M {x + r:.2f} {y:.2f} L {x + w - r:.2f} {y:.2f} A {r:.2f} {r:.2f} 0 0 1 {x + w:.2f} {y + r:.2f} "
            f"L {x + w:.2f} {y + h - r:.2f} A {r:.2f} {r:.2f} 0 0 1 {x + w - r:.2f} {y + h:.2f} "
            f"L {x + r:.2f} {y + h:.2f} A {r:.2f} {r:.2f} 0 0 1 {x:.2f} {y + h - r:.2f} "
            f"L {x:.2f} {y + r:.2f} A {r:.2f} {r:.2f} 0 0 1 {x + r:.2f} {y:.2f} Z")


def star(cx, cy, r_out, r_in, points=5, turn=-90):
    pts = []
    for k in range(points * 2):
        a = math.radians(turn + k * 180 / points)
        r = r_out if k % 2 == 0 else r_in
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return poly(pts)


def smooth(pts, closed=False):
    """A smooth curve through points (Catmull-Rom as cubic Beziers)."""
    n = len(pts)
    if n < 2:
        return ""
    d = f"M {pts[0][0]:.2f} {pts[0][1]:.2f}"
    last = n if closed else n - 1
    for i in range(last):
        p0 = pts[(i - 1) % n] if (closed or i > 0) else pts[0]
        p1 = pts[i % n]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if (closed or i + 2 < n) else pts[-1]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C {c1[0]:.2f} {c1[1]:.2f}, {c2[0]:.2f} {c2[1]:.2f}, {p2[0]:.2f} {p2[1]:.2f}"
    return d + (" Z" if closed else "")


def rot(pts, deg, cx=50, cy=50):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


class Badge:
    """An SVG on the 100 x 100 canvas, drawn in the emblem style."""

    def __init__(self, px=192):
        self.px = px
        self.defs = []
        self.parts = []
        self.n = 0
        self.ow = 2.3  # the symbols' outline

    def _id(self, p):
        self.n += 1
        return f"{p}{self.n}"

    def add(self, s):
        self.parts.append(s)

    def linear(self, stops, x1=0.2, y1=0.0, x2=0.8, y2=1.0):
        gid = self._id("l")
        st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.defs.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
        return f"url(#{gid})"

    def radial(self, stops, cx=0.4, cy=0.35, r=0.75):
        gid = self._id("r")
        st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.defs.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">{st}</radialGradient>')
        return f"url(#{gid})"

    def clip(self, *ds):
        cid = self._id("c")
        self.defs.append(f'<clipPath id="{cid}">' + "".join(f'<path d="{d}"/>' for d in ds) + "</clipPath>")
        return f"url(#{cid})"

    def glow(self, cx, cy, rx, ry, color, a):
        gid = self._id("g")
        self.defs.append(
            f'<radialGradient id="{gid}"><stop offset="0" stop-color="{color}" stop-opacity="{a}"/>'
            f'<stop offset="0.5" stop-color="{color}" stop-opacity="{a * 0.5:.3f}"/>'
            f'<stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient>'
        )
        self.add(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="url(#{gid})"/>')

    def fill(self, d, color, opacity=1.0, transform=""):
        t = f' transform="{transform}"' if transform else ""
        op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
        self.add(f'<path d="{d}" fill="{color}"{op}{t}/>')

    def stroke(self, d, color, width, opacity=1.0, cap="round", transform=""):
        t = f' transform="{transform}"' if transform else ""
        op = f' stroke-opacity="{opacity}"' if opacity < 1 else ""
        self.add(f'<path d="{d}" fill="none" stroke="{color}"{op} stroke-width="{width:.2f}" '
                 f'stroke-linecap="{cap}" stroke-linejoin="round"{t}/>')

    # -- the symbol ------------------------------------------------------------

    def shadow(self, ds, dx=1.0, dy=2.4, a=0.26):
        """The symbol's soft shadow on the field."""
        for d in ds:
            self.fill(d, "#000000", a, f"translate({dx} {dy})")

    def part(self, d, main, shade=None, ink=INK, cut=(1.5, 2.0), hi=0.0, ow=None):
        """One filled part of a symbol: its outline, its colour, a darker cut along its
        lower right edge (`cut`: how far the colour is pushed up and left), a light edge
        along the upper left (`hi`: its opacity)."""
        w = self.ow if ow is None else ow
        self.add(f'<path d="{d}" fill="{ink}" stroke="{ink}" stroke-width="{2 * w:.2f}" stroke-linejoin="round"/>')
        if shade is None:
            self.fill(d, main)
        else:
            c = self.clip(d)
            self.add(f'<g clip-path="{c}"><path d="{d}" fill="{shade}"/>'
                     f'<path d="{d}" fill="{main}" transform="translate({-cut[0]} {-cut[1]})"/></g>')
        if hi > 0:
            c = self.clip(d)
            self.add(f'<g clip-path="{c}"><path d="{d}" fill="none" stroke="#FFFFFF" stroke-opacity="{hi}" '
                     f'stroke-width="2.4" transform="translate(1.2 1.6)"/></g>')

    def lines(self, items, main, shade=None, ink=INK, ow=None):
        """A symbol made of thick strokes ([(d, width)]): outlined as one shape, a darker
        edge along each stroke's lower right."""
        w = self.ow if ow is None else ow
        for d, width in items:
            self.stroke(d, ink, width + 2 * w)
        if shade:
            for d, width in items:
                self.stroke(d, shade, width, transform="translate(0.7 1.0)")
        for d, width in items:
            self.stroke(d, main, width, transform="translate(-0.35 -0.5)" if shade else "")

    # -- the badge ---------------------------------------------------------------

    def badge(self, ring, field, field_dark=None, rim=None, ink=None, frame="round", gem=None):
        """The badge under the symbol: its rim, its ring and its field.
        frame: "round", "wisp" (a wavy, ghostly edge) or "rays" (a gold sunburst edge)."""
        rim = rim or mix(ring, INK, 0.45)
        ink = ink or mix(ring, INK, 0.75)
        field_dark = field_dark or mix(field, INK, 0.3)
        # its shadow
        self.glow(50, 54, 49, 47, "#000000", 0.32)
        if frame == "rays":
            pts = []
            for k in range(48):
                a = math.radians(-90 + k * 7.5)
                r = 48.6 if k % 2 == 0 else 44.6
                pts.append((50 + math.cos(a) * r, 50 + math.sin(a) * r))
            outer = poly(pts)
            self.add(f'<path d="{outer}" fill="{self.linear([(0, GOLD_L, 1), (0.5, GOLD, 1), (1, GOLD_D, 1)])}" '
                     f'stroke="{mix(GOLD_D, INK, 0.5)}" stroke-width="1.6" stroke-linejoin="round"/>')
            self.add(f'<path d="{circ(50, 50, 42.6)}" fill="{rim}" stroke="{mix(GOLD_D, INK, 0.5)}" stroke-width="1.2"/>')
        elif frame == "wisp":
            pts = []
            for k in range(72):
                a = math.radians(-90 + k * 5)
                r = 46.6 + 1.7 * math.sin(k * math.pi / 3) + 0.6 * math.sin(k * 0.9)
                pts.append((50 + math.cos(a) * r, 50 + math.sin(a) * r))
            outer = smooth(pts, closed=True)
            self.glow(50, 50, 52, 52, ring, 0.35)
            self.add(f'<path d="{outer}" fill="{rim}" stroke="{ink}" stroke-width="1.4"/>')
        else:
            self.add(f'<path d="{circ(50, 50, 47.4)}" fill="{rim}" stroke="{ink}" stroke-width="1.4"/>')
        r_ring = 42.6 if frame == "rays" else 44.2
        if frame != "rays":
            self.add(f'<path d="{circ(50, 50, r_ring)}" fill="{self.linear([(0, mix(ring, "#FFFFFF", 0.35), 1), (0.5, ring, 1), (1, mix(ring, INK, 0.3), 1)])}"/>')
            # a glint along the ring's upper left
            self.stroke(f"M {50 - r_ring * 0.94:.2f} {50 - r_ring * 0.34:.2f} A {r_ring - 1.6} {r_ring - 1.6} 0 0 1 {50 - r_ring * 0.2:.2f} {50 - r_ring * 0.96:.2f}",
                        "#FFFFFF", 1.6, 0.45)
        r_field = 37.4
        self.add(f'<path d="{circ(50, 50, r_field)}" fill="{self.radial([(0, mix(field, "#FFFFFF", 0.14), 1), (0.65, field, 1), (1, field_dark, 1)], 0.38, 0.32, 0.8)}" '
                 f'stroke="{mix(rim, INK, 0.35)}" stroke-width="1.3"/>')
        # the field's sheen, top left
        self.add(f'<path d="{ell(43, 30, 22, 11)}" fill="#FFFFFF" fill-opacity="0.07" transform="rotate(-24 43 30)"/>')
        if gem:
            self.add(f'<path d="{poly([(50, 0.6), (55.2, 5.2), (50, 10.8), (44.8, 5.2)])}" fill="{self.linear([(0, mix(gem, "#FFFFFF", 0.5), 1), (1, mix(gem, INK, 0.3), 1)])}" '
                     f'stroke="{mix(GOLD_D, INK, 0.5)}" stroke-width="1.2" stroke-linejoin="round"/>')

    def svg(self):
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.px}" height="{self.px}" viewBox="0 0 100 100">'
            + "<defs>" + "".join(self.defs) + "</defs>" + "".join(self.parts) + "</svg>"
        )
