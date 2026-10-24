"""
The catches from fishing between turns (Shared/Meta/Fishing): every fish in the log, the
old boot and the gold coin, drawn like the rest of the art (lit from the upper left,
outlined in a dark shade of each part's own colour, glossy where wet). tools/art.py
calls sprites().

"fish/<catch id>" is the catch on a 100 x 100 canvas, side on, head to the right (as the
fish log and the catch pop-up show them), roughly filling x 6 to 94; the game also draws
it in black, see-through, as the shadow under the bobber.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from badge import poly, smooth, star  # noqa: E402
from props import INK, Art, circ, ell, mix  # noqa: E402

PX = 144
UNITS = 1.35
CY = 52  # the fish's middle, down the canvas


def art():
    return Art(PX, UNITS)


def lin(a, stops, x1=0.5, y1=0.0, x2=0.5, y2=1.0):
    gid = a._id("fl")
    st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    a.defs.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
    return f"url(#{gid})"


def rad(a, stops, cx=0.38, cy=0.32, r=0.75):
    gid = a._id("fr")
    st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    a.defs.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">{st}</radialGradient>')
    return f"url(#{gid})"


def paint(a, d, fill, stroke=None, width=None, opacity=1.0, transform=""):
    st = f' stroke="{stroke}" stroke-width="{width or a.ow:.2f}" stroke-linejoin="round" stroke-linecap="round"' if stroke else ""
    op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
    t = f' transform="{transform}"' if transform else ""
    a.parts.append(f'<path d="{d}" fill="{fill}"{op}{st}{t}/>')


def gloss(a, cx, cy, rx, ry, turn=-12, op=0.5):
    a.parts.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({turn} {cx} {cy})" fill="#FFFFFF" fill-opacity="{op}"/>')


def outline_of(color):
    return mix(color, INK, 0.6)


# ---------------------------------------------------------------------------
# a fish, from its recipe
# ---------------------------------------------------------------------------


def body_path(x0, x1, h, nose=0.0, belly=1.0, back=1.0, tail_h=None):
    """The body's outline: the tail's joint at x0, the nose at x1, `h` half its height."""
    L = x1 - x0
    th = tail_h if tail_h is not None else h * 0.26
    return (f"M {x0:.1f} {CY - th:.1f} "
            f"C {x0 + L * 0.28:.1f} {CY - h * 1.08 * back:.1f}, {x1 - L * 0.26:.1f} {CY - h * 1.02 * back:.1f}, {x1:.1f} {CY + nose:.1f} "
            f"C {x1 - L * 0.16:.1f} {CY + h * 1.04 * belly:.1f}, {x0 + L * 0.36:.1f} {CY + h * 1.06 * belly:.1f}, {x0:.1f} {CY + th:.1f} Z")


def tail_path(x0, h, kind, size=1.0):
    th = h * 0.26
    s = size
    if kind == "fork":
        return (f"M {x0 + 3:.1f} {CY - th:.1f} C {x0 - 6 * s:.1f} {CY - th - 8 * s:.1f}, {x0 - 12 * s:.1f} {CY - h * 0.9 * s:.1f}, {x0 - 16 * s:.1f} {CY - h * 1.05 * s:.1f} "
                f"C {x0 - 10 * s:.1f} {CY - h * 0.3:.1f}, {x0 - 10 * s:.1f} {CY + h * 0.3:.1f}, {x0 - 16 * s:.1f} {CY + h * 1.05 * s:.1f} "
                f"C {x0 - 12 * s:.1f} {CY + h * 0.9 * s:.1f}, {x0 - 6 * s:.1f} {CY + th + 8 * s:.1f}, {x0 + 3:.1f} {CY + th:.1f} Z")
    if kind == "lunate":
        return (f"M {x0 + 3:.1f} {CY - th:.1f} C {x0 - 4:.1f} {CY - h:.1f}, {x0 - 12 * s:.1f} {CY - h * 1.5 * s:.1f}, {x0 - 18 * s:.1f} {CY - h * 1.6 * s:.1f} "
                f"C {x0 - 8 * s:.1f} {CY - h * 0.5:.1f}, {x0 - 8 * s:.1f} {CY + h * 0.5:.1f}, {x0 - 18 * s:.1f} {CY + h * 1.6 * s:.1f} "
                f"C {x0 - 12 * s:.1f} {CY + h * 1.5 * s:.1f}, {x0 - 4:.1f} {CY + h:.1f}, {x0 + 3:.1f} {CY + th:.1f} Z")
    if kind == "round":
        return (f"M {x0 + 3:.1f} {CY - th:.1f} C {x0 - 8 * s:.1f} {CY - h * 1.1 * s:.1f}, {x0 - 22 * s:.1f} {CY - h * 0.9 * s:.1f}, {x0 - 20 * s:.1f} {CY:.1f} "
                f"C {x0 - 22 * s:.1f} {CY + h * 0.9 * s:.1f}, {x0 - 8 * s:.1f} {CY + h * 1.1 * s:.1f}, {x0 + 3:.1f} {CY + th:.1f} Z")
    # fan: a broad spread tail with a straight edge
    return (f"M {x0 + 3:.1f} {CY - th:.1f} L {x0 - 15 * s:.1f} {CY - h * 0.95 * s:.1f} "
            f"C {x0 - 19 * s:.1f} {CY - h * 0.3:.1f}, {x0 - 19 * s:.1f} {CY + h * 0.3:.1f}, {x0 - 15 * s:.1f} {CY + h * 0.95 * s:.1f} "
            f"L {x0 + 3:.1f} {CY + th:.1f} Z")


def fin_rays(a, d, color, rays_from, rays_to, n=5, op=0.35):
    a.group(clip=d)
    for k in range(n):
        t = (k + 0.5) / n
        fx, fy = rays_from
        tx0, ty0, tx1, ty1 = rays_to
        tx, ty = tx0 + (tx1 - tx0) * t, ty0 + (ty1 - ty0) * t
        a.line(f"M {fx:.1f} {fy:.1f} L {tx:.1f} {ty:.1f}", color, 1.0, op)
    a.end()


def fish(spec):
    """A side-on fish from its recipe (see the catches below)."""
    a = art()
    x0, x1, h = spec["x0"], spec["x1"], spec["h"]
    body, back, belly, fin = spec["body"], spec.get("back", mix(spec["body"], INK, 0.25)), spec.get("belly", mix(spec["body"], "#FFFFFF", 0.55)), spec["fin"]
    line = outline_of(back)
    fin_line = outline_of(fin)
    L = x1 - x0
    rng = random.Random(spec.get("seed", 1))
    a.shadow((x0 + x1) / 2, CY + h + 10, L * 0.55, 4.5, 0.18)
    # the fins behind: the dorsal on its back, the anal fin under it, the tail
    dorsal = spec.get("dorsal", "soft")
    top = CY - h * 0.98
    if dorsal == "spiky":
        pts = [(x0 + L * 0.2, top + 3)]
        n = 6
        for k in range(n):
            xa = x0 + L * (0.22 + 0.5 * k / n)
            pts += [(xa + L * 0.03, top - h * 0.55 - (2 if k % 2 == 0 else 0)), (xa + L * 0.07, top - h * 0.12)]
        pts.append((x0 + L * 0.74, top + 4))
        dd = poly(pts)
        paint(a, dd, lin(a, [(0, mix(fin, "#FFFFFF", 0.3), 1), (1, fin, 1)]), fin_line, a.ow)
    elif dorsal == "tall":
        dd = (f"M {x0 + L * 0.25:.1f} {top + 4:.1f} C {x0 + L * 0.3:.1f} {top - h * 0.9:.1f}, {x0 + L * 0.42:.1f} {top - h * 1.3:.1f}, {x0 + L * 0.56:.1f} {top - h * 1.2:.1f} "
              f"C {x0 + L * 0.5:.1f} {top - h * 0.6:.1f}, {x0 + L * 0.6:.1f} {top:.1f}, {x0 + L * 0.66:.1f} {top + 4:.1f} Z")
        paint(a, dd, lin(a, [(0, mix(fin, "#FFFFFF", 0.25), 1), (1, fin, 1)]), fin_line, a.ow)
        fin_rays(a, dd, fin_line, (x0 + L * 0.45, top + 6), (x0 + L * 0.28, top - h * 0.6, x0 + L * 0.6, top - h * 0.9))
    elif dorsal == "long":
        dd = (f"M {x0 + L * 0.06:.1f} {top + 6:.1f} C {x0 + L * 0.2:.1f} {top - h * 0.5:.1f}, {x0 + L * 0.6:.1f} {top - h * 0.6:.1f}, {x0 + L * 0.8:.1f} {top + 4:.1f} Z")
        paint(a, dd, lin(a, [(0, mix(fin, "#FFFFFF", 0.25), 1), (1, fin, 1)]), fin_line, a.ow)
    elif dorsal == "soft":
        dd = (f"M {x0 + L * 0.3:.1f} {top + 3:.1f} C {x0 + L * 0.36:.1f} {top - h * 0.62:.1f}, {x0 + L * 0.58:.1f} {top - h * 0.62:.1f}, {x0 + L * 0.66:.1f} {top + 3:.1f} Z")
        paint(a, dd, lin(a, [(0, mix(fin, "#FFFFFF", 0.25), 1), (1, fin, 1)]), fin_line, a.ow)
        fin_rays(a, dd, fin_line, (x0 + L * 0.48, top + 6), (x0 + L * 0.34, top - h * 0.4, x0 + L * 0.64, top - h * 0.3), 4)
    bottom = CY + h * 0.96
    if spec.get("anal", True):
        ad = (f"M {x0 + L * 0.2:.1f} {bottom - 2:.1f} C {x0 + L * 0.22:.1f} {bottom + h * 0.42:.1f}, {x0 + L * 0.36:.1f} {bottom + h * 0.4:.1f}, {x0 + L * 0.42:.1f} {bottom - 2:.1f} Z")
        paint(a, ad, fin, fin_line, a.ow)
    tail = spec.get("tail", "fork")
    if tail:
        td = tail_path(x0, h, tail, spec.get("tail_size", 1.0))
        paint(a, td, lin(a, [(0, mix(fin, "#FFFFFF", 0.25), 1), (1, mix(fin, INK, 0.12), 1)], 0.3, 0.0, 0.7, 1.0), fin_line, a.ow)
        fin_rays(a, td, fin_line, (x0 + 2, CY), (x0 - 18, CY - h, x0 - 18, CY + h), 6, 0.3)
    # the body
    bd = body_path(x0, x1, h, spec.get("nose", 0.0), spec.get("belly_k", 1.0), spec.get("back_k", 1.0))
    paint(a, bd, lin(a, [(0, back, 1), (0.42, body, 1), (0.75, mix(body, belly, 0.6), 1), (1, belly, 1)]), line, a.ow)
    a.group(clip=bd)
    pattern(a, spec, x0, x1, h, rng)
    # the light along its back and the shade along its belly
    a.parts.append(f'<path d="{bd}" fill="none" stroke="#FFFFFF" stroke-opacity="0.28" stroke-width="3.2" transform="translate(1.2 2.0)"/>')
    a.parts.append(f'<path d="{bd}" fill="none" stroke="#000000" stroke-opacity="0.16" stroke-width="3.6" transform="translate(-1.2 -2.2)"/>')
    gloss(a, x0 + L * 0.55, CY - h * 0.55, L * 0.22, h * 0.16, -6, spec.get("gloss", 0.38))
    # its gill: a curve behind the head
    gx = x1 - L * spec.get("gill", 0.24)
    a.line(f"M {gx + 2:.1f} {CY - h * 0.62:.1f} C {gx - 4:.1f} {CY - h * 0.2:.1f}, {gx - 4:.1f} {CY + h * 0.3:.1f}, {gx + 2:.1f} {CY + h * 0.7:.1f}", mix(back, INK, 0.3), 1.6, 0.55)
    a.end()
    # the side fin, over the body
    if spec.get("pectoral", True):
        px_ = x1 - L * (spec.get("gill", 0.24) + 0.06)
        pd = (f"M {px_:.1f} {CY + h * 0.08:.1f} C {px_ - 8:.1f} {CY + h * 0.05:.1f}, {px_ - 14:.1f} {CY + h * 0.45:.1f}, {px_ - 12:.1f} {CY + h * 0.62:.1f} "
              f"C {px_ - 6:.1f} {CY + h * 0.56:.1f}, {px_ - 1:.1f} {CY + h * 0.36:.1f}, {px_:.1f} {CY + h * 0.08:.1f} Z")
        paint(a, pd, mix(fin, "#FFFFFF", 0.3), fin_line, a.ow * 0.8, 0.85)
        fin_rays(a, pd, fin_line, (px_, CY + h * 0.1), (px_ - 14, CY + h * 0.3, px_ - 10, CY + h * 0.66), 3, 0.4)
    # the mouth and the eye
    mouth(a, spec, x1, h, line)
    ex, ey, er = x1 - L * spec.get("eye_at", 0.12), CY - h * spec.get("eye_up", 0.22), spec.get("eye", 3.6)
    if spec.get("eye_ring", True):
        paint(a, circ(ex, ey, er + 1.6), mix(belly, "#FFFFFF", 0.4), line, a.ow * 0.6)
    paint(a, circ(ex, ey, er), spec.get("pupil", INK))
    paint(a, circ(ex - er * 0.35, ey - er * 0.4, er * 0.36), "#FFFFFF")
    for extra in spec.get("extras", []):
        extra(a, spec)
    return a.svg()


def pattern(a, spec, x0, x1, h, rng):
    """Markings on the body (drawn clipped to it)."""
    L = x1 - x0
    kind = spec.get("pattern")
    col = spec.get("mark", mix(spec["body"], INK, 0.35))
    if kind == "bands":
        # a clownfish's white bands, edged in black
        for t, w in ((0.82, 7), (0.52, 8), (0.18, 6)):
            x = x0 + L * t
            paint(a, f"M {x - w / 2:.1f} 0 C {x - w:.1f} 40, {x - w:.1f} 64, {x - w / 2:.1f} 100 L {x + w / 2:.1f} 100 C {x:.1f} 64, {x:.1f} 40, {x + w / 2:.1f} 0 Z",
                  "#FFFFFF", INK, 1.8)
    elif kind == "wavy":
        for k in range(6):
            x = x0 + L * (0.12 + k * 0.12)
            a.line(f"M {x:.1f} {CY - h * 1.1:.1f} C {x + 4:.1f} {CY - h * 0.7:.1f}, {x - 4:.1f} {CY - h * 0.4:.1f}, {x + 2:.1f} {CY - h * 0.1:.1f}", col, 2.2, 0.8)
    elif kind == "stripes":
        for k in range(5):
            x = x0 + L * (0.16 + k * 0.14)
            a.line(f"M {x:.1f} {CY - h * 1.1:.1f} L {x - 3:.1f} {CY + h * 0.5:.1f}", col, 3.2, 0.45)
    elif kind == "spots":
        for _ in range(spec.get("spots", 14)):
            x, y = rng.uniform(x0 + 4, x1 - L * 0.2), rng.uniform(CY - h * 0.9, CY + h * 0.6)
            a.fill(circ(x, y, rng.uniform(1.2, 2.4)), col, 0.7)
    elif kind == "lanterns":
        for k in range(6):
            x = x0 + L * (0.14 + k * 0.12)
            y = CY + h * 0.45
            a.glow(x, y, 4.5, 4.5, "#FFE66B", 0.9)
            a.fill(circ(x, y, 1.6), "#FFF6C2")
    elif kind == "ribs":
        for k in range(6):
            x = x0 + L * (0.14 + k * 0.1)
            a.line(f"M {x:.1f} {CY - h * 0.7:.1f} C {x - 3:.1f} {CY - h * 0.2:.1f}, {x - 3:.1f} {CY + h * 0.2:.1f}, {x:.1f} {CY + h * 0.7:.1f}", col, 1.6, 0.6)
        a.line(f"M {x0:.1f} {CY:.1f} L {x1 - L * 0.24:.1f} {CY:.1f}", col, 1.8, 0.6)
    elif kind == "rivets":
        # a tin fish: plates riveted together
        for k in range(1, 4):
            x = x0 + L * (0.18 + k * 0.17)
            a.line(f"M {x:.1f} {CY - h * 1.1:.1f} L {x:.1f} {CY + h * 1.1:.1f}", col, 1.4, 0.6)
            for y in (CY - h * 0.55, CY, CY + h * 0.55):
                a.fill(circ(x - 2.6, y, 1.3), mix(spec["body"], "#FFFFFF", 0.5))
                a.fill(circ(x - 2.4, y + 0.4, 0.8), col, 0.7)
    elif kind == "scales":
        for row in range(3):
            for k in range(7):
                x = x0 + L * (0.12 + k * 0.095) + (row % 2) * L * 0.045
                y = CY - h * 0.45 + row * h * 0.42
                a.line(f"M {x - 3:.1f} {y - 3:.1f} A 4 4 0 0 0 {x - 3:.1f} {y + 3:.1f}", col, 1.1, 0.45)
    elif kind == "speckle":
        for _ in range(26):
            x, y = rng.uniform(x0 + 3, x1 - 6), rng.uniform(CY - h, CY + h * 0.3)
            a.fill(circ(x, y, rng.uniform(0.6, 1.3)), col, 0.55)
    elif kind == "glow":
        a.parts.append(f'<rect x="0" y="0" width="100" height="100" fill="{rad(a, [(0, "#FFFFFF", 0.55), (1, "#FFFFFF", 0)], 0.55, 0.45, 0.5)}"/>')


def mouth(a, spec, x1, h, line):
    kind = spec.get("mouth", "small")
    nose = spec.get("nose", 0.0)
    y = CY + nose + h * 0.12
    if kind == "small":
        a.line(f"M {x1 - 1:.1f} {y:.1f} L {x1 - 6:.1f} {y + 1.4:.1f}", line, 1.4, 0.9)
    elif kind == "big":
        paint(a, f"M {x1 + 1:.1f} {y - 3:.1f} L {x1 - 12:.1f} {y + 2:.1f} L {x1 - 1:.1f} {y + 6:.1f} Z", mix(spec["body"], INK, 0.65), line, 1.2)
    elif kind == "teeth":
        paint(a, f"M {x1 + 1:.1f} {y - 2:.1f} L {x1 - 11:.1f} {y + 3:.1f} L {x1:.1f} {y + 7:.1f} Z", "#3A1E22", line, 1.2)
        for k in range(3):
            tx = x1 - 2 - k * 3.2
            a.fill(f"M {tx - 1.3:.1f} {y - 1 + k * 0.9:.1f} L {tx:.1f} {y + 2.4 + k * 0.9:.1f} L {tx + 1.3:.1f} {y - 0.6 + k * 0.9:.1f} Z", "#FFFFFF")


# extras ---------------------------------------------------------------------


def bill(length, color):
    def draw(a, spec):
        x1 = spec["x1"]
        d = f"M {x1 - 3:.1f} {CY - 2.6:.1f} L {x1 + length:.1f} {CY - 0.6:.1f} L {x1 - 3:.1f} {CY + 2.2:.1f} Z"
        paint(a, d, lin(a, [(0, mix(color, "#FFFFFF", 0.35), 1), (1, color, 1)]), outline_of(color), a.ow * 0.8)
    return draw


def whiskers(a, spec):
    x1 = spec["x1"]
    col = mix(spec["body"], INK, 0.55)
    for dy, ex, ey in ((1, 12, 10), (3, 8, 16), (-1, 14, 2)):
        a.line(f"M {x1 - 4:.1f} {CY + dy:.1f} C {x1 + 2:.1f} {CY + dy + 2:.1f}, {x1 + ex - 4:.1f} {CY + ey - 2:.1f}, {x1 + ex - 8:.1f} {CY + ey + 4:.1f}", col, 1.5)


def lure(a, spec):
    x1, h = spec["x1"], spec["h"]
    sx, sy = x1 - 10, CY - h * 0.9
    a.line(f"M {sx:.1f} {sy:.1f} C {sx + 4:.1f} {sy - 16:.1f}, {x1 + 10:.1f} {sy - 18:.1f}, {x1 + 12:.1f} {sy - 6:.1f}", mix(spec["body"], INK, 0.3), 2.2)
    a.glow(x1 + 12, sy - 4, 9, 9, "#FFE66B", 0.95)
    paint(a, circ(x1 + 12, sy - 4, 3.6), "#FFF2A8", "#C9A12A", 1.0)


def sparkles(a, spec):
    for x, y, r in ((24, 30, 5), (78, 26, 4), (64, 80, 3.5)):
        paint(a, star(x, y, r, r * 0.25, 4, -90), "#FFFFFF", None, None, 0.95)


def crest(color):
    def draw(a, spec):
        x0, x1, h = spec["x0"], spec["x1"], spec["h"]
        top = CY - h * 0.95
        pts = [(x1 - 10, top + 2)]
        k = 0
        x = x1 - 10
        while x > x0 + 8:
            pts.append((x - 2, top - 7 - (3 if k % 3 == 0 else 0)))
            x -= 6
            pts.append((x, top + 1))
            k += 1
        dd = smooth(pts)
        a.line(dd, mix(color, INK, 0.4), 4.6)
        a.line(dd, color, 2.8)
    return draw


# ---------------------------------------------------------------------------
# the catches that aren't plain fish
# ---------------------------------------------------------------------------


def squid(body, fin, octopus=False):
    a = art()
    line = outline_of(body)
    a.shadow(50, 92, 28, 4, 0.18)
    rng = random.Random(body)
    # arms behind, curling
    n = 8 if octopus else 6
    for k in range(n):
        t = k / (n - 1)
        x = 30 + t * 40
        bend = (t - 0.5) * 24
        curl = 5 if k % 2 else -5
        d = f"M {x:.1f} 56 C {x + bend * 0.2:.1f} 70, {x + bend * 0.7 + curl:.1f} 80, {x + bend:.1f} 90"
        a.line(d, line, 7.6 if octopus else 5.6)
        a.line(d, body, 5.0 if octopus else 3.4)
        if octopus:
            for s in (0.35, 0.6, 0.85):
                sx, sy = x + bend * s * 0.9, 56 + 34 * s
                a.fill(circ(sx + 1.6, sy, 1.1), fin, 0.9)
    if octopus:
        head = "M 50 14 C 72 14, 78 34, 72 48 C 68 58, 60 62, 50 62 C 40 62, 32 58, 28 48 C 22 34, 28 14, 50 14 Z"
    else:
        # a squid's mantle: long, with fins at its tip
        paint(a, "M 50 6 L 64 22 L 50 26 Z", fin, outline_of(fin), a.ow * 0.9)
        paint(a, "M 50 6 L 36 22 L 50 26 Z", fin, outline_of(fin), a.ow * 0.9)
        head = "M 50 8 C 62 18, 66 40, 62 58 C 58 62, 42 62, 38 58 C 34 40, 38 18, 50 8 Z"
    paint(a, head, lin(a, [(0, mix(body, "#FFFFFF", 0.3), 1), (0.6, body, 1), (1, mix(body, INK, 0.2), 1)], 0.2, 0.0, 0.8, 1.0), line, a.ow)
    a.group(clip=head)
    for _ in range(10):
        a.fill(circ(rng.uniform(32, 68), rng.uniform(16, 56), rng.uniform(1.2, 2.4)), mix(body, INK, 0.25), 0.4)
    a.end()
    gloss(a, 42, 26, 6, 10, -20, 0.45)
    for x in (43, 57):
        paint(a, circ(x, 48, 4.8), "#FFFFFF", line, a.ow * 0.6)
        paint(a, circ(x + 0.6, 49, 2.6), INK)
    return a.svg()


def crab(body, claw, legs=None, gems=False, gears=False):
    a = art()
    line = outline_of(body)
    legs = legs or body
    a.shadow(50, 84, 40, 5, 0.2)
    # legs: three a side, bent at the knee
    for side in (-1, 1):
        for k in range(3):
            hip = (50 + side * (14 + k * 5), 62)
            knee = (50 + side * (27 + k * 6), 56 - k * 2)
            foot = (50 + side * (31 + k * 6), 78 + k * 2)
            d = f"M {hip[0]:.1f} {hip[1]:.1f} L {knee[0]:.1f} {knee[1]:.1f} L {foot[0]:.1f} {foot[1]:.1f}"
            a.line(d, outline_of(legs), 6.4)
            a.line(d, legs, 4.0)
    # arms up to the pincers: each pincer two jaws, open at the tips
    for side in (-1, 1):
        ax = 50 + side * 18
        elbow = (50 + side * 30, 44)
        a.line(f"M {ax:.1f} 52 L {elbow[0]:.1f} {elbow[1]:.1f} L {50 + side * 33:.1f} 34", outline_of(body), 7)
        a.line(f"M {ax:.1f} 52 L {elbow[0]:.1f} {elbow[1]:.1f} L {50 + side * 33:.1f} 34", body, 4.4)
        cx, cy = 50 + side * 34, 28
        for (rx, ry, turn, dx, dy) in ((10, 6, -40, 2, -4), (7.5, 4.2, 18, 5, 3)):
            ex, ey = cx + side * dx, cy + dy
            paint(a, ell(ex, ey, rx, ry), lin(a, [(0, mix(claw, "#FFFFFF", 0.35), 1), (1, claw, 1)], 0.2, 0, 0.8, 1), outline_of(claw), a.ow,
                  transform=f"rotate({turn * side} {ex:.1f} {ey:.1f})")
    shell = "M 22 58 C 22 40, 36 34, 50 34 C 64 34, 78 40, 78 58 C 78 68, 64 72, 50 72 C 36 72, 22 68, 22 58 Z"
    paint(a, shell, lin(a, [(0, mix(body, "#FFFFFF", 0.35), 1), (0.6, body, 1), (1, mix(body, INK, 0.25), 1)], 0.2, 0.0, 0.8, 1.0), line, a.ow)
    a.group(clip=shell)
    if gems:
        # obsidian: lava glowing through cracks
        for d in ("M 30 50 L 40 56 L 36 64", "M 60 40 L 56 50 L 66 56 L 64 66", "M 46 38 L 50 46"):
            a.line(d, "#FF7A1A", 2.4, 0.95)
            a.line(d, "#FFD25A", 1.0, 0.95)
    if gears:
        for (gx, gy, gr) in ((40, 54, 8), (60, 50, 6)):
            paint(a, star(gx, gy, gr, gr * 0.78, 10, 0), mix(body, INK, 0.2), None, None, 0.6)
            paint(a, circ(gx, gy, gr * 0.35), mix(body, "#FFFFFF", 0.4))
    a.end()
    gloss(a, 40, 42, 10, 4, -10, 0.5)
    for x in (44, 56):
        a.line(f"M {x:.1f} 38 L {x:.1f} 30", line, 2)
        paint(a, circ(x, 29, 3.2), "#FFFFFF", line, a.ow * 0.6)
        paint(a, circ(x + 0.5, 29.5, 1.8), INK)
    return a.svg()


def eel(body, fin, spots=False, glow=False, ribbon=False, crest_color=None):
    a = art()
    line = outline_of(body)
    pts = [(8, 64), (22, 52), (36, 60), (50, 48), (64, 54), (78, 46), (88, 46)]
    d = smooth(pts)
    if glow:
        a.line(d, "#FFB347", 20, 0.25)
    width = 13 if not ribbon else 10
    a.line(d, line, width + 3.4)
    if crest_color:
        crest_pts = [(x, y - width * 0.55) for x, y in pts[1:-1]]
        cd = smooth(crest_pts)
        a.line(cd, mix(crest_color, INK, 0.4), 7)
        a.line(cd, crest_color, 4.6)
        a.line(d, line, width + 3.4)
    a.line(d, body, width)
    a.line(d, mix(body, "#FFFFFF", 0.4), width * 0.36, 0.55)
    if spots:
        rng = random.Random(body)
        for x, y in pts[1:-1]:
            for _ in range(3):
                a.fill(circ(x + rng.uniform(-5, 5), y + rng.uniform(-2.5, 2.5), rng.uniform(0.9, 1.6)), mix(body, "#E8E070", 0.5), 0.9)
    # the head
    head = "M 78 44 C 82 34, 94 34, 96 44 C 97 52, 90 56, 80 53 Z"
    paint(a, head, lin(a, [(0, mix(body, "#FFFFFF", 0.3), 1), (1, body, 1)]), line, a.ow)
    paint(a, circ(88, 42, 3.2), "#FFFFFF", line, a.ow * 0.5)
    paint(a, circ(88.8, 42.6, 1.8), INK)
    a.line("M 95 48 L 85 50", line, 1.6)
    if glow:
        for x, y in pts[1:-1]:
            a.glow(x, y, 6, 6, "#FFE08A", 0.5)
    return a.svg()


def narwhal():
    a = art()
    body, belly = "#B9C6CC", "#E6EEF2"
    line = outline_of("#7E8794")
    a.shadow(50, 80, 40, 4, 0.18)
    # the tusk, a long spiral
    paint(a, "M 82 44 L 96 31 L 84 48 Z", "#F3EAD3", "#B8A47A", 1.2)
    for k in range(4):
        t = 0.2 + k * 0.2
        x, y = 82 + 14 * t, 44 - 13 * t
        a.line(f"M {x - 1:.1f} {y + 2:.1f} L {x + 2:.1f} {y - 1:.1f}", "#B8A47A", 1.0)
    # the tail flukes
    paint(a, "M 16 52 C 10 44, 4 40, 2 40 C 6 46, 6 52, 4 58 C 8 58, 12 56, 16 54 Z", "#7E8794", line, a.ow)
    d = "M 14 54 C 20 38, 46 32, 70 34 C 86 36, 92 46, 88 56 C 84 66, 60 70, 40 66 C 28 64, 18 60, 14 54 Z"
    paint(a, d, lin(a, [(0, mix(body, INK, 0.12), 1), (0.6, body, 1), (1, belly, 1)]), line, a.ow)
    a.group(clip=d)
    rng = random.Random(7)
    for _ in range(20):
        a.fill(circ(rng.uniform(16, 80), rng.uniform(36, 52), rng.uniform(1, 2.2)), "#7E8794", 0.5)
    a.end()
    gloss(a, 56, 40, 14, 3.2, -4, 0.45)
    paint(a, "M 56 58 C 52 66, 46 70, 44 70 C 46 64, 48 60, 50 58 Z", "#7E8794", line, a.ow)
    paint(a, circ(78, 48, 2.4), INK)
    a.line("M 86 56 C 82 58, 78 58, 74 57", line, 1.4)
    return a.svg()


def boot():
    a = art()
    leather, leather_d = "#7A4A1F", "#4A2A10"
    line = outline_of(leather)
    a.shadow(52, 88, 34, 4, 0.2)
    d = "M 30 16 L 56 16 L 58 56 C 72 56, 86 62, 88 74 L 88 84 L 26 84 L 26 60 C 26 44, 28 28, 30 16 Z"
    paint(a, d, lin(a, [(0, mix(leather, "#FFFFFF", 0.2), 1), (0.6, leather, 1), (1, leather_d, 1)], 0.2, 0, 0.8, 1), line, a.ow)
    paint(a, "M 24 80 L 90 80 L 90 88 L 24 88 Z", "#3A2A1E", line, a.ow)
    a.line("M 28 24 L 56 24", leather_d, 2.6, 0.8)
    for y in (32, 40, 48):
        a.line(f"M 34 {y} L 52 {y + 2}", "#D8C29A", 1.6, 0.85)
    # a hole in the toe and seaweed hanging off it
    paint(a, ell(74, 70, 5, 3.6), "#2A1A10")
    a.line("M 56 16 C 64 24, 58 34, 66 42", "#4C8A3E", 3.4, 0.95)
    a.line("M 56 16 C 64 24, 58 34, 66 42", "#7DB35A", 1.4, 0.9)
    paint(a, circ(78, 30, 5), "#8FD3EE", "#4E8FAE", 1.0, 0.85)
    paint(a, circ(84, 20, 3), "#8FD3EE", "#4E8FAE", 1.0, 0.85)
    gloss(a, 38, 26, 5, 8, -8, 0.3)
    return a.svg()


def coin():
    a = art()
    gold, gold_d = "#F5C14B", "#B8841C"
    a.shadow(52, 90, 30, 4, 0.2)
    paint(a, circ(50, 50, 38), lin(a, [(0, gold_d, 1), (1, mix(gold_d, INK, 0.3), 1)]), outline_of(gold_d), a.ow)
    paint(a, circ(48, 48, 34), lin(a, [(0, "#FFF3B0", 1), (0.4, gold, 1), (1, gold_d, 1)], 0.2, 0, 0.8, 1), outline_of(gold_d), a.ow * 0.7)
    a.line(circ(48, 48, 27), mix(gold_d, "#7A5200", 0.3), 1.6, 0.6)
    paint(a, star(48, 48, 16, 7, 5, -90), mix(gold_d, "#7A5200", 0.15))
    paint(a, star(47, 47, 14, 6, 5, -90), "#FFE08A")
    paint(a, star(34, 28, 6, 1.5, 4, -90), "#FFFFFF", None, None, 0.95)
    return a.svg()


# ---------------------------------------------------------------------------
# the log
# ---------------------------------------------------------------------------


def catches():
    return {
        # anywhere
        "sardine": fish(dict(x0=20, x1=92, h=11, body="#9FB8C9", back="#4F6E86", belly="#EEF4F8", fin="#8DA6B8", pattern="spots", mark="#3E5A70", spots=7, tail="fork", dorsal="soft", gloss=0.55)),
        "golden": fish(dict(x0=28, x1=88, h=22, body="#F2C23A", back="#D49A12", belly="#FFF1B0", fin="#FFD66B", tail="round", tail_size=1.3, dorsal="soft", pattern="scales", mark="#B88A12", gloss=0.6, extras=[sparkles])),
        "boot": boot(),
        "coin": coin(),
        # Blissful Tricks
        "snapper": fish(dict(x0=24, x1=90, h=20, body="#D64545", back="#A83434", belly="#F8B4A8", fin="#E06A5A", tail="fork", dorsal="spiky", mouth="big", nose=2, pattern="scales", mark="#A83434")),
        "clownfish": fish(dict(x0=26, x1=86, h=18, body="#EE8A2E", back="#D06A18", belly="#FFC07A", fin="#EE8A2E", pattern="bands", tail="round", dorsal="soft", eye=3.8)),
        "puffer": puffer(),
        "swordfish": fish(dict(x0=24, x1=76, h=13, body="#2F4C6E", back="#22384F", belly="#C9D8E6", fin="#3A5C82", tail="lunate", dorsal="tall", extras=[bill(19, "#22384F")], gloss=0.45)),
        # Junction Dungeon
        "mackerel": fish(dict(x0=20, x1=92, h=12, body="#4F86A8", back="#2F5C78", belly="#E8F0F4", fin="#5E8DA8", pattern="wavy", mark="#1E3A4E", tail="fork", dorsal="soft")),
        "squid": squid("#D35A9C", "#A43F77"),
        "eel": eel("#5E7A3A", "#3F5426", spots=True),
        # Slimy Snares
        "catfish": fish(dict(x0=22, x1=88, h=15, body="#7D6B52", back="#5A4C3A", belly="#C9B99A", fin="#6E5E48", tail="round", dorsal="soft", mouth="big", nose=3, pattern="speckle", mark="#4A3C2A", extras=[whiskers], eye=2.8)),
        "piranha": fish(dict(x0=28, x1=86, h=20, body="#8E9AA6", back="#5E6A78", belly="#D64545", fin="#B85A50", tail="fork", dorsal="soft", mouth="teeth", nose=4, pattern="speckle", mark="#5E6A78", eye=3.4)),
        "gar": fish(dict(x0=16, x1=80, h=9, body="#6E7F4E", back="#4C5A34", belly="#D8D8B0", fin="#5E6E40", tail="round", dorsal="long", pattern="spots", mark="#3A4426", spots=16, extras=[bill(16, "#4C5A34")])),
        # Haunted Hollow
        "bonefish": fish(dict(x0=20, x1=90, h=13, body="#D8D4C8", back="#A9A396", belly="#F4F2EC", fin="#C8C2B4", pattern="ribs", mark="#8A8476", tail="fork", dorsal="soft")),
        "angler": fish(dict(x0=24, x1=76, h=23, body="#3B3A48", back="#26252F", belly="#5A5868", fin="#4A4858", tail="round", dorsal=None, mouth="teeth", nose=6, extras=[lure], eye=3.2, eye_ring=False, pupil="#FFE66B", gloss=0.25)),
        "ghostfish": ghostfish(),
        # Mount Kaboom
        "tilapia": fish(dict(x0=24, x1=88, h=18, body="#9AA38C", back="#6F7864", belly="#E2E6D8", fin="#8A9478", pattern="stripes", mark="#5A6250", tail="fan", dorsal="spiky")),
        "crab": crab("#3A3440", "#F2541B", legs="#2A2430", gems=True),
        "ember": eel("#F2541B", "#B83A12", glow=True),
        # Frostbite Floes
        "cod": fish(dict(x0=20, x1=90, h=14, body="#9FB4C2", back="#6F8797", belly="#EEF4F6", fin="#8EA3B0", pattern="speckle", mark="#5A6E7C", tail="fan", dorsal="soft", extras=[barbel])),
        "snowcrab": crab("#E07A4F", "#E8956A", legs="#E07A4F"),
        "narwhal": narwhal(),
        # Kraken's Reach
        "lanternfish": fish(dict(x0=24, x1=86, h=13, body="#2F4C6E", back="#1C2E44", belly="#5A7FA6", fin="#3A5C82", pattern="lanterns", tail="fork", dorsal="soft", eye=4.6, pupil="#1C2E44", gloss=0.3)),
        "octopus": squid("#B5485E", "#F6D2D2", octopus=True),
        "oarfish": eel("#C9D3DA", "#D64545", ribbon=True, crest_color="#E05050"),
        # Clockwork Cove
        "bass": fish(dict(x0=22, x1=88, h=17, body="#6E8B6A", back="#4C6A49", belly="#DDE8D2", fin="#5E7A5A", tail="fan", dorsal="spiky", mouth="big", nose=3, pattern="speckle", mark="#3A5238")),
        "brasscrab": crab("#E7B023", "#F2C23A", legs="#B88A12", gears=True),
        "tinfish": fish(dict(x0=24, x1=86, h=17, body="#B8BDC7", back="#8A909C", belly="#E6E9EE", fin="#E7B023", pattern="rivets", mark="#6A707C", tail="fan", dorsal="soft", gloss=0.6, extras=[windkey])),
    }


def puffer():
    a = art()
    body, fin = "#E7B023", "#B88A12"
    line = outline_of(fin)
    a.shadow(52, 88, 30, 4, 0.18)
    paint(a, tail_path(24, 12, "round", 0.8), fin, line, a.ow)
    d = circ(54, 52, 32)
    # spikes all round
    for k in range(18):
        ang = math.radians(k * 20 + 10)
        bx, by = 54 + math.cos(ang) * 30, 52 + math.sin(ang) * 30
        tx, ty = 54 + math.cos(ang) * 39, 52 + math.sin(ang) * 39
        paint(a, poly([(bx + math.sin(ang) * 3, by - math.cos(ang) * 3), (tx, ty), (bx - math.sin(ang) * 3, by + math.cos(ang) * 3)]), "#FFF1B0", line, a.ow * 0.6)
    paint(a, d, rad(a, [(0, "#FFF1B0", 1), (0.55, body, 1), (1, mix(body, INK, 0.2), 1)], 0.4, 0.35, 0.75), line, a.ow)
    a.group(clip=d)
    a.fill("M 20 66 C 40 80, 70 80, 90 64 L 90 90 L 20 90 Z", "#FFF6D8", 0.75)
    rng = random.Random(3)
    for _ in range(12):
        a.fill(circ(rng.uniform(32, 80), rng.uniform(28, 56), rng.uniform(1.4, 2.4)), "#8A6A10", 0.55)
    a.end()
    gloss(a, 44, 34, 10, 5, -20, 0.5)
    paint(a, circ(74, 44, 5), "#FFFFFF", line, a.ow * 0.6)
    paint(a, circ(75, 45, 2.8), INK)
    paint(a, ell(84, 56, 3.6, 2.4), "#B85A30", line, 1.0)
    paint(a, "M 56 60 C 50 62, 46 70, 48 74 C 54 72, 58 66, 56 60 Z", fin, line, a.ow * 0.9)
    return a.svg()


def ghostfish():
    spec = dict(x0=24, x1=86, h=16, body="#E9EEF0", back="#C9D6DC", belly="#FFFFFF", fin="#CFE0E8", tail="round", tail_size=1.2, dorsal="tall", pattern="glow", gloss=0.6, eye=3.8, pupil="#3E6E86")
    svg = fish(spec)
    # see-through: the whole fish a little faint, with a cold glow behind it
    head, rest = svg.split("<defs>", 1)
    defs, body = rest.split("</defs>", 1)
    glow = ('<radialGradient id="ghostglow"><stop offset="0" stop-color="#BFE7FF" stop-opacity="0.65"/>'
            '<stop offset="1" stop-color="#BFE7FF" stop-opacity="0"/></radialGradient>')
    return (head + "<defs>" + defs + glow + "</defs>" + '<ellipse cx="54" cy="52" rx="46" ry="32" fill="url(#ghostglow)"/>'
            + f'<g opacity="0.82">{body.replace("</svg>", "")}</g></svg>')


def barbel(a, spec):
    x1, h = spec["x1"], spec["h"]
    a.line(f"M {x1 - 8:.1f} {CY + h * 0.55:.1f} C {x1 - 8:.1f} {CY + h * 0.9:.1f}, {x1 - 10:.1f} {CY + h * 1.1:.1f}, {x1 - 12:.1f} {CY + h * 1.2:.1f}", mix(spec["body"], INK, 0.45), 1.4)


def windkey(a, spec):
    x0, x1, h = spec["x0"], spec["x1"], spec["h"]
    kx, ky = (x0 + x1) / 2 - 4, CY - h * 0.95
    a.line(f"M {kx:.1f} {ky + 4:.1f} L {kx:.1f} {ky - 8:.1f}", "#8A6A10", 3.2)
    for dx in (-6, 6):
        paint(a, ell(kx + dx, ky - 12, 6, 4.4), "#F2C23A", "#8A6A10", 1.2)
    paint(a, circ(kx, ky - 11, 2.2), "#8A6A10")


def sprites():
    return list(catches().items())
