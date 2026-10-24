"""
The Kraken of Kraken's Reach, as frames the board flips through (tools/art.py calls
sprites()). Its arm is a tube of shaded discs along a curve in 3D, seen from the
board's angle (the ground squashed by K, height straight up the screen), so it can
rear up, arch over and lie across the ground any way round.

    kraken/rise_<k>     k 0..2: the water bulging, then the arm breaking the surface
    kraken/arm_<k>      k 0..5: the arm swaying, its foot in the water (a loop)
    kraken/rear_l, _r   reared back to strike (leaning left, to strike right; and back)
    kraken/arc_<d>      d 0..7: arched over towards its mark, d x 45 degrees round on
                        the ground from the right (2: towards you, 6: away)
    kraken/hit_<d>      slammed down along the ground that way, the dust flying

Every arm frame shares one canvas (ARM: units, the arm's foot at the origin, where it
leaves the water), so the board swaps them in place.

The lair in the middle of the lagoon, lying flat (ground space, squashed by K) except
the head, which rises out of it:

    kraken/swirl_<k>    k 0..3: the white water streaming round and down (a loop; drawn
                        round, the board squashes it like the whirlpool under it)
    kraken/head_<look>  its head out of the water: ahead, left, right, blink, angry
    kraken/coil_<k>     k 0..1: an arm arching out of the water and back in
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from badge import mix, poly, smooth  # noqa: E402

K = 0.72  # BoardLayout.Style.squash
PXU = 44  # pixels a map unit (a tile radius)
ARM = (-4.6, 4.6, -6.8, 3.2)  # the arm frames' canvas: x0, x1, y0, y1 in units, foot at 0, 0

FLESH, FLESH_L, FLESH_D = "#B5485E", "#DA7488", "#7A2A3E"
BELLY, BELLY_D = "#E8A0A4", "#BF6F7A"
OUT = "#41131F"
SUCK, SUCK_RIM, SUCK_IN = "#FBE0DA", "#C5707A", "#E7A9A9"
FOAM = "#FFFFFF"
DUST, DUST_D = "#F4E6CC", "#C9AF86"


class Canvas:
    """An SVG over a box of map units (x0..x1, y0..y1), PXU pixels to the unit."""

    def __init__(self, box, px=PXU):
        self.x0, self.x1, self.y0, self.y1 = box
        self.px = px
        self.defs = []
        self.parts = []
        self.n = 0

    def p(self, x, y):
        return (x - self.x0) * 10, (y - self.y0) * 10

    def _id(self, k):
        self.n += 1
        return f"{k}{self.n}"

    def radial(self, stops, cx=0.36, cy=0.3, r=0.78):
        gid = self._id("r")
        st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.defs.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">{st}</radialGradient>')
        return f"url(#{gid})"

    def linear(self, stops, x1=0, y1=0, x2=0, y2=1):
        gid = self._id("l")
        st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.defs.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
        return f"url(#{gid})"

    def circle(self, x, y, r, fill, stroke=None, sw=0.0, opacity=1.0):
        cx, cy = self.p(x, y)
        s = f' stroke="{stroke}" stroke-width="{sw * 10:.2f}"' if stroke else ""
        o = f' fill-opacity="{opacity}"' if opacity < 1 else ""
        self.parts.append(f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{r * 10:.2f}" fill="{fill}"{o}{s}/>')

    def ellipse(self, x, y, rx, ry, fill, stroke=None, sw=0.0, opacity=1.0, angle=0.0):
        cx, cy = self.p(x, y)
        s = f' stroke="{stroke}" stroke-width="{sw * 10:.2f}"' if stroke else ""
        o = f' fill-opacity="{opacity}"' if opacity < 1 else ""
        t = f' transform="rotate({angle:.1f} {cx:.2f} {cy:.2f})"' if angle else ""
        self.parts.append(f'<ellipse cx="{cx:.2f}" cy="{cy:.2f}" rx="{rx * 10:.2f}" ry="{ry * 10:.2f}" fill="{fill}"{o}{s}{t}/>')

    def path(self, pts, fill=None, stroke=None, sw=0.0, opacity=1.0, closed=True, curve=True, cap="round"):
        q = [self.p(x, y) for x, y in pts]
        d = smooth(q, closed) if curve else ("M " + " L ".join(f"{x:.2f} {y:.2f}" for x, y in q) + (" Z" if closed else ""))
        f = fill or "none"
        s = f' stroke="{stroke}" stroke-width="{sw * 10:.2f}" stroke-linecap="{cap}" stroke-linejoin="round"' if stroke else ""
        o = f' opacity="{opacity}"' if opacity < 1 else ""
        self.parts.append(f'<path d="{d}" fill="{f}"{s}{o}/>')

    def arc(self, x, y, rx, ry, a0, a1, color, width, opacity=1.0):
        """Part of an ellipse's outline, from angle a0 to a1 (degrees, 0 = right, 90 = down)."""
        pts = []
        for k in range(25):
            a = math.radians(a0 + (a1 - a0) * k / 24)
            pts.append((x + math.cos(a) * rx, y + math.sin(a) * ry))
        self.path(pts, None, color, width, opacity, closed=False)

    def svg(self):
        w, h = (self.x1 - self.x0), (self.y1 - self.y0)
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{round(w * self.px)}" height="{round(h * self.px)}" '
                f'viewBox="0 0 {w * 10:.1f} {h * 10:.1f}"><defs>' + "".join(self.defs) + "</defs>" + "".join(self.parts) + "</svg>")


# ---------------------------------------------------------------------------
# the arm
# ---------------------------------------------------------------------------


def resample(pts, step):
    """Points every `step` along a polyline."""
    out = [pts[0]]
    carry = 0.0
    for i in range(1, len(pts)):
        ax, ay = pts[i - 1]
        bx, by = pts[i]
        seg = math.hypot(bx - ax, by - ay)
        t = step - carry
        while t <= seg:
            out.append((ax + (bx - ax) * t / seg, ay + (by - ay) * t / seg))
            t += step
        carry = seg - (t - step)
    if math.hypot(out[-1][0] - pts[-1][0], out[-1][1] - pts[-1][1]) > step * 0.3:
        out.append(pts[-1])
    return out


def radius(s):
    """How thick the arm is `s` (0..1) of the way from its foot to its tip."""
    return 0.62 * (1 - min(1.0, max(0.0, s))) ** 0.85 + 0.07


def draw_arm(c, pts3, belly3, depth=None, spots=True, rad=None):
    """The arm through 3D points [(x, y, z)] (ground x, y; height z) from foot to tip,
    as a run of shaded discs drawn far to near, outlines a step ahead of the fills so
    neighbours hide each other's seams. belly3(i) -> the 3D direction its suckers face."""
    # resample along the 3D curve
    flat = [(x, y * K - z) for x, y, z in pts3]
    n = len(pts3)
    lengths = [0.0]
    for i in range(1, n):
        lengths.append(lengths[-1] + math.dist(pts3[i], pts3[i - 1]))
    total = lengths[-1]
    discs = []  # (screen x, y, r, s, depth, i)
    step = 0.055
    t = 0.0
    j = 0
    while t <= total + 1e-9:
        while j < n - 2 and lengths[j + 1] < t:
            j += 1
        seg = max(1e-9, lengths[j + 1] - lengths[j])
        f = min(1.0, max(0.0, (t - lengths[j]) / seg))
        x = flat[j][0] + (flat[j + 1][0] - flat[j][0]) * f
        y = flat[j][1] + (flat[j + 1][1] - flat[j][1]) * f
        gy = pts3[j][1] + (pts3[j + 1][1] - pts3[j][1]) * f
        s = min(1.0, t / total)
        discs.append((x, y, (rad or radius)(s), s, gy, j))
        t += step
    order = list(range(len(discs)))
    if depth:
        order.sort(key=lambda k: depth(discs[k][5]))

    # each disc is shaded across the arm, from its back to its belly (so its neighbours
    # line up and the arm reads as one smooth limb): a darker rim along the back, a light
    # band, then the pale belly where the suckers are
    def belly_dir(k):
        x, y, r, s, _, j = discs[k]
        bx, by, bz = belly3(j)
        sx, sy = bx, by * K - bz
        m = math.hypot(sx, sy)
        if m < 1e-6:
            return 0.0, 1.0
        return sx / m, sy / m

    cache = {}

    def fill_for(k):
        nx, ny = belly_dir(k)
        key = (round(math.degrees(math.atan2(ny, nx)) / 6) * 6)
        if key not in cache:
            a = math.radians(key)
            ux, uy = math.cos(a), math.sin(a)
            cache[key] = c.linear([(0, FLESH_D, 1), (0.16, FLESH, 1), (0.36, FLESH_L, 1), (0.58, FLESH, 1), (0.8, BELLY, 1), (1, BELLY_D, 1)],
                                  0.5 - 0.5 * ux, 0.5 - 0.5 * uy, 0.5 + 0.5 * ux, 0.5 + 0.5 * uy)
        return cache[key]

    # outlines then fills, a chunk at a time (so no seam shows between neighbours), each
    # chunk's fills going back over the end of the chunk before (hiding its outlines
    # there); an arm crossing in front of itself still has its outline where it crosses
    ow = 0.075
    CH = 12
    for ci in range(0, len(order), CH):
        chunk = order[ci:ci + CH]
        for k in chunk:
            x, y, r, _, _, _ = discs[k]
            c.circle(x, y, r + ow, OUT)
        for k in order[max(0, ci - 4):ci] + chunk:
            x, y, r, _, _, _ = discs[k]
            c.circle(x, y, r, fill_for(k))
    # spots on its back, and the suckers along its belly, where nothing nearer covers them
    rank = {k: i for i, k in enumerate(order)}

    def covered(x, y, k, margin):
        for k2 in order[rank[k] + 1:]:
            x2, y2, r2 = discs[k2][0], discs[k2][1], discs[k2][2]
            # (its neighbours along the arm are the same surface, not in front of it)
            if abs(discs[k2][3] - discs[k][3]) * total < 2.6 * discs[k][2]:
                continue
            if math.hypot(x - x2, y - y2) < r2 - margin:
                return True
        return False

    acc = 0.0
    for idx in range(1, len(discs) - 2):
        x, y, r, s, _, j = discs[idx]
        acc += step
        if acc < max(0.24, r * 0.95) or s > 0.93:
            continue
        acc = 0.0
        bx, by, bz = belly3(j)
        # the belly direction, on screen
        sx, sy = bx, by * K - bz
        m = math.hypot(sx, sy)
        if m < 0.2:
            continue
        sx, sy = sx / m, sy / m
        # along the arm, on screen
        ax, ay = discs[idx + 1][0] - discs[idx - 1][0], discs[idx + 1][1] - discs[idx - 1][1]
        ang = math.degrees(math.atan2(ay, ax))
        cx, cy = x + sx * r * 0.6 * min(1.0, m), y + sy * r * 0.6 * min(1.0, m)
        if covered(cx, cy, idx, 0.05):
            continue
        rr = r * 0.4
        c.ellipse(cx, cy, rr, rr * (0.55 + 0.35 * min(1.0, m)), SUCK, SUCK_RIM, 0.045, angle=ang)
        c.ellipse(cx, cy, rr * 0.42, rr * 0.3, SUCK_IN, angle=ang)
    if spots:
        for idx in range(6, len(discs) - 8, 9):
            x, y, r, s, _, j = discs[idx]
            bx, by, bz = belly3(j)
            sx, sy = -bx, -(by * K - bz)
            m = math.hypot(sx, sy) or 1
            cx, cy = x + sx / m * r * 0.45, y + sy / m * r * 0.45
            if not covered(cx, cy, idx, 0.08):
                c.ellipse(cx, cy, r * 0.17, r * 0.12, FLESH_D, opacity=0.55)


def water_ring(c, r, front, bulge=0.0):
    """The foam where the arm leaves the water: the back half or the front half."""
    rx, ry = r * 1.75, r * 1.75 * K * 0.62
    if not front:
        c.ellipse(0, 0.04, rx * 1.35, ry * 1.35, "#0B2A44", opacity=0.35)
        c.arc(0, 0, rx, ry, 180, 360, FOAM, 0.16, 0.95)
        c.arc(0, 0, rx * 1.45, ry * 1.5, 200, 340, FOAM, 0.07, 0.6)
    else:
        c.arc(0, 0, rx, ry, 0, 180, FOAM, 0.2, 1.0)
        c.arc(0, 0, rx * 1.45, ry * 1.5, 20, 160, FOAM, 0.08, 0.7)
        for a, d in ((200, 1.15), (320, 1.2), (250, 1.05)):
            x, y = math.cos(math.radians(a)) * rx * d, math.sin(math.radians(a)) * ry * d - bulge
            c.circle(x, y - 0.25, 0.07, FOAM, opacity=0.85)


def side_arm(length, sway=0.0, lean=0.0, curl=2.35, frac=1.0, mirror=False):
    """An arm standing in the water, seen side on: its 3D points (it stays in the plane
    across the screen). frac: only its last part is out of the water (rising)."""
    segs = 70
    pts = []
    x = z = 0.0
    full = length / frac
    for i in range(segs + 1):
        s = (1 - frac) + frac * i / segs
        th = lean * s + 0.34 * sway * (1 - (1 - s) ** 2) - 0.5 * sway * s * s + curl * s ** 4
        if mirror:
            th = -th
        pts.append((x, 0.0, z))
        ds = full * frac / segs
        x += math.sin(th) * ds
        z += math.cos(th) * ds
    return pts


def arm_frame(pts, belly_side, rise=False):
    c = Canvas(ARM)
    r0 = radius(0) if not rise else 0.4
    water_ring(c, r0, False)
    # the belly faces the inside of its curl (round the screen's normal of the plane)
    def belly(j):
        a, b = pts[max(0, j - 1)], pts[min(len(pts) - 1, j + 1)]
        tx, tz = b[0] - a[0], b[2] - a[2]
        m = math.hypot(tx, tz) or 1
        return (belly_side * tz / m, 0.0, -belly_side * tx / m)
    draw_arm(c, pts, belly)
    water_ring(c, r0, True)
    return c.svg()


def rise_frame(k):
    if k == 0:
        c = Canvas(ARM)
        c.ellipse(0, 0.0, 1.4, 1.4 * K * 0.62, "#0B2A44", opacity=0.3)
        c.ellipse(0, -0.12, 1.0, 0.55, "#9FE0F2", opacity=0.45)
        c.arc(0, -0.12, 1.0, 0.55, 190, 350, FOAM, 0.08, 0.8)
        c.arc(0, 0, 1.3, 1.3 * K * 0.62, 0, 360, FOAM, 0.14, 0.9)
        c.arc(0, 0, 1.9, 1.9 * K * 0.62, 10, 170, FOAM, 0.07, 0.6)
        c.arc(0, 0, 1.9, 1.9 * K * 0.62, 190, 350, FOAM, 0.06, 0.5)
        for a in (210, 260, 300, 330):
            c.circle(math.cos(math.radians(a)) * 1.1, math.sin(math.radians(a)) * 0.6 - 0.5, 0.08, FOAM, opacity=0.9)
        return c.svg()
    frac = (0.32, 0.62)[k - 1]
    return arm_frame(side_arm(5.2 * frac, sway=0.4, frac=frac, curl=2.6), 1, rise=True)


def idle_frame(k):
    ph = 2 * math.pi * k / 6
    return arm_frame(side_arm(5.2, sway=math.sin(ph), curl=2.3 + 0.35 * math.cos(ph)), 1)


def rear_frame(left):
    pts = side_arm(5.6, sway=-0.9, lean=-0.62, curl=2.9, mirror=not left)
    return arm_frame(pts, 1 if left else -1)


def strike_points(k, arched):
    """The arm reaching from its foot towards direction k (x 45 degrees on the ground):
    arched high over it, or slammed down along the ground."""
    a = math.radians(k * 45)
    dx, dy = math.cos(a), math.sin(a)
    # (along the ground, height) control points, then a wiggle across
    if arched:
        ctrl = [(0, 0), (0.15, 1.1), (0.55, 2.4), (1.25, 3.1), (2.1, 2.9), (2.75, 2.2), (3.0, 1.5), (2.9, 1.05)]
    else:
        ctrl = [(0, 0), (0.3, 0.8), (0.8, 1.05), (1.3, 0.55), (1.7, 0.12), (2.3, 0.08), (2.9, 0.1), (3.45, 0.12), (3.85, 0.38)]
    curve = []
    pts = [(f, z) for f, z in ctrl]
    # a smooth curve through the control points
    sm = []
    for i in range(len(pts) - 1):
        p0 = pts[max(0, i - 1)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(len(pts) - 1, i + 2)]
        for t in [u / 12 for u in range(12)]:
            t2, t3 = t * t, t * t * t
            f = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            z = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            sm.append((f, max(0.0, z)))
    sm.append(pts[-1])
    for f, z in sm:
        # (an arch leans a little to one side, so it's never seen exactly end on; a slammed
        # arm wriggles where it lies)
        w = 0.55 * math.sin(math.pi * min(1.0, f / 3.0)) if arched else (0.32 * math.sin(math.pi * min(1.0, f / 3.9)) + 0.16 * math.sin(f * 2.3) * min(1.0, max(0.0, f - 1.4)))
        curve.append((dx * f - dy * w, dy * f + dx * w, z))
    return curve, (dx, dy)


def puff(c, dx, dy, spots, reach, front=False):
    """Dust clouds along either side of where the arm lands: soft, overlapping, light."""
    for f, side, sz in spots:
        gx, gy = dx * f - dy * side * reach, dy * f + dx * side * reach
        if front and gy < dy * f - 0.05:
            continue
        x, y = gx, gy * K - sz * 0.45
        c.circle(x, y + sz * 0.15, sz * 1.08, DUST_D, opacity=0.55)
        for ox, oy, k in ((-0.45, 0.1, 0.75), (0.45, 0.05, 0.8), (0.0, -0.3, 0.85), (0.0, 0.0, 1.0)):
            c.circle(x + ox * sz, y + oy * sz, sz * k, DUST, opacity=0.92)
        c.circle(x - sz * 0.25, y - sz * 0.3, sz * 0.32, "#FFFFFF", opacity=0.7)


def strike_frame(k, arched):
    pts, (dx, dy) = strike_points(k, arched)
    c = Canvas(ARM, 34 if arched else PXU)
    water_ring(c, radius(0), False)

    def belly(j):
        a, b = pts[max(0, j - 1)], pts[min(len(pts) - 1, j + 1)]
        tf = (b[0] - a[0]) * dx + (b[1] - a[1]) * dy
        tz = b[2] - a[2]
        m = math.hypot(tf, tz) or 1
        nf, nz = tz / m, -tf / m  # under the arm (towards the ground, or the inside of its arch)
        return (dx * nf, dy * nf, nz)

    if not arched:
        # its shadow where it lies, and the dust it throws up
        for f in (1.9, 2.4, 2.9, 3.4):
            c.ellipse(dx * f, dy * f * K, 0.62, 0.62 * K * 0.7, "#000000", opacity=0.16)
        puff(c, dx, dy, ((1.95, 1, 0.34), (2.35, -1, 0.3), (2.85, 1, 0.42), (3.1, -1, 0.36), (3.6, 1, 0.3), (3.75, -1, 0.26)), 0.66)
    draw_arm(c, pts, belly, depth=lambda j: pts[j][0] * dx + pts[j][1] * dy if dy > 0.01 else (-(pts[j][0] * dx + pts[j][1] * dy) if dy < -0.01 else 0.0))
    if not arched:
        puff(c, dx, dy, ((2.5, 1, 0.26), (2.7, -1, 0.3), (3.25, 1, 0.24), (3.35, -1, 0.26)), 0.82, front=True)
        # the jolt where it hits: short strokes flung out round it
        for f, side in ((2.2, 1), (2.9, -1), (3.5, 1), (2.6, -1)):
            gx, gy = dx * f - dy * side * 1.25, (dy * f + dx * side * 1.25) * K - 0.5
            ox, oy = -dy * side * 0.35, (dx * side * 0.35) * K - 0.2
            c.path([(gx, gy), (gx + ox, gy + oy)], None, "#FFFFFF", 0.09, 0.95, closed=False, curve=False)
    water_ring(c, radius(0), True)
    return c.svg()


# ---------------------------------------------------------------------------
# the lair
# ---------------------------------------------------------------------------

LAIR = (-3.4, 3.4, -3.4, 3.4)  # the whirlpool's frames, round (the board squashes them flat)


def swirl_frame(k):
    """The white water streaming round and down into the whirlpool, turned k x 18
    degrees (its five arms repeat every 72, so four frames loop; the board fades from
    one to the next)."""
    c = Canvas(LAIR, 30)
    turn = math.radians(k * 18)
    for arm in range(5):
        base = arm * 2 * math.pi / 5 + turn
        pts = []
        for i in range(40):
            t = i / 39
            ang = base + t * 4.2
            rad = 3.1 * (1 - t) ** 0.85 + 0.25
            pts.append((math.cos(ang) * rad, math.sin(ang) * rad))
        # thick and bright out at the rim, thin and faint as it goes down
        for a, b, w, o in ((0, 14, 0.2, 0.75), (10, 26, 0.13, 0.55), (22, 38, 0.07, 0.35)):
            c.path(pts[a:b], None, FOAM, w, o, closed=False)
        # a fleck riding each arm
        fx, fy = pts[6]
        c.ellipse(fx, fy, 0.16, 0.07, FOAM, opacity=0.8, angle=math.degrees(base + 1.0))
    return c.svg()


HEAD = (-2.2, 2.2, -3.6, 0.7)  # the head's canvas: its waterline at y = 0


def head_frame(look):
    c = Canvas(HEAD)
    # the dome of its head, rising out of the water
    dome = []
    for i in range(41):
        a = math.pi + math.pi * i / 40
        h = max(0.0, -math.sin(a))  # 0 at the water, 1 on top
        rx = 1.62 + 0.32 * math.sin(math.pi * min(1.0, h * 1.15)) ** 1.4
        x = math.cos(a) * rx
        y = math.sin(a) * 3.1
        dome.append((x, y + 0.18))
    dome = [(-1.7, 0.4)] + dome + [(1.7, 0.4)]
    c.path(dome, OUT, None, closed=True)
    body = [(x * 0.955, y * 0.975 + 0.02) for x, y in dome]
    c.path(body, c.radial([(0, FLESH_L, 1), (0.55, FLESH, 1), (1, FLESH_D, 1)], 0.36, 0.25, 0.85), None, closed=True)
    # spots
    for x, y, r in ((-0.85, -2.1, 0.22), (-0.35, -2.75, 0.16), (0.55, -2.35, 0.2), (1.0, -1.6, 0.15), (-1.15, -1.25, 0.14)):
        c.ellipse(x, y, r, r * 0.8, FLESH_D, opacity=0.5)
    c.path([(-0.55, -2.75), (-1.05, -2.3), (-1.32, -1.6)], None, "#FFFFFF", 0.16, 0.4, closed=False)
    # the eyes, low on its head, just above the water
    ex = 0.8
    ey = -0.85
    px = {"ahead": 0.0, "left": -0.2, "right": 0.2, "angry": 0.0, "blink": 0.0}[look]
    for side in (-1, 1):
        x = side * ex
        c.ellipse(x, ey, 0.62, 0.55, OUT)
        if look == "blink":
            c.ellipse(x, ey, 0.55, 0.48, FLESH_D)
            c.arc(x, ey - 0.02, 0.36, 0.14, 15, 165, OUT, 0.09)
            continue
        c.ellipse(x, ey, 0.55, 0.48, c.radial([(0, "#FFF2A8", 1), (0.7, "#F2C23A", 1), (1, "#C58E12", 1)], 0.4, 0.35, 0.8))
        c.ellipse(x + px, ey + 0.02, 0.1 if look != "angry" else 0.07, 0.34, "#1B1018")
        c.circle(x - 0.17, ey - 0.16, 0.08, "#FFFFFF", opacity=0.9)
        # its lids: heavy, and drawn down hard toward the middle when it's angry
        if look == "angry":
            lid = [(x + side * 0.62, ey - 0.62), (x - side * 0.6, ey - 0.12), (x - side * 0.55, ey - 0.55)]
        else:
            lid = [(x - 0.58, ey - 0.3), (x, ey - 0.58), (x + 0.58, ey - 0.3), (x + 0.5, ey - 0.62), (x - 0.5, ey - 0.62)]
        c.path(lid, FLESH_D, OUT, 0.07, closed=True, curve=look != "angry")
    # the water lapping round it
    c.ellipse(0, 0.38, 2.05, 0.42, "#0B2A44", opacity=0.35)
    c.arc(0, 0.3, 1.9, 0.38, 0, 180, FOAM, 0.16, 0.95)
    c.arc(0, 0.32, 2.12, 0.46, 15, 165, FOAM, 0.07, 0.6)
    return c.svg()


COIL = (-1.6, 1.6, -2.0, 0.5)


def coil_frame(k):
    """An arm arching out of the water and diving back in, its suckers along the inside."""
    c = Canvas(COIL)
    h = (1.45, 1.25)[k]
    lean = (0.0, 0.18)[k]
    pts3 = []
    for i in range(61):
        t = i / 60
        x = -1.05 + 2.1 * t
        z = h * math.sin(math.pi * t) ** 0.8 + lean * math.sin(2 * math.pi * t)
        pts3.append((x, 0.0, z))
    for x in (-1.05, 1.05):
        c.ellipse(x, 0.02, 0.62, 0.62 * K * 0.6, "#0B2A44", opacity=0.3)
        c.arc(x, 0, 0.55, 0.55 * K * 0.6, 180, 360, FOAM, 0.1, 0.9)

    def belly(j):
        a, b = pts3[max(0, j - 1)], pts3[min(len(pts3) - 1, j + 1)]
        tx, tz = b[0] - a[0], b[2] - a[2]
        m = math.hypot(tx, tz) or 1
        return (tz / m, 0.0, -tx / m)

    # (thickest in the middle of the arch, where it's nearest the body)
    draw_arm(c, pts3, belly, spots=False, rad=lambda s: 0.22 + 0.24 * math.sin(math.pi * s) ** 0.6)
    for x in (-1.05, 1.05):
        c.arc(x, 0, 0.55, 0.55 * K * 0.6, 0, 180, FOAM, 0.13, 1.0)
    return c.svg()


def sprites():
    out = []
    for k in range(3):
        out.append((f"rise_{k}", rise_frame(k)))
    for k in range(6):
        out.append((f"arm_{k}", idle_frame(k)))
    out.append(("rear_l", rear_frame(True)))
    out.append(("rear_r", rear_frame(False)))
    for k in range(8):
        out.append((f"arc_{k}", strike_frame(k, True)))
        out.append((f"hit_{k}", strike_frame(k, False)))
    for k in range(4):
        out.append((f"swirl_{k}", swirl_frame(k)))
    for look in ("ahead", "left", "right", "blink", "angry"):
        out.append((f"head_{look}", head_frame(look)))
    for k in range(2):
        out.append((f"coil_{k}", coil_frame(k)))
    return out
