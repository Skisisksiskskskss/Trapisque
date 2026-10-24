"""
The trails' particles (Shared/Meta/Cosmetics, category "trail": the little things that
spill out behind a piece as it hops), drawn like the rest of the art: lit from the upper
left, outlined in a dark shade of each part's own colour, glossy where it's shiny.
tools/art.py calls sprites().

Each sprite is one particle on a 100 x 100 canvas, centred on (50, 50): "trails/<kind>_<n>",
where <kind> is the trail's look.kind and n counts its variants (CosmeticArt.trailBurst
picks among them). Paw prints lie flat on the ground, so they're drawn squashed like the
board.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from badge import poly, smooth, star  # noqa: E402
from props import INK, Art, circ, ell, mix  # noqa: E402

PX = 64
UNITS = 1.15


def art():
    return Art(PX, UNITS)


def radial(a, stops, cx=0.38, cy=0.32, r=0.75):
    gid = a._id("tr")
    st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    a.defs.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">{st}</radialGradient>')
    return f"url(#{gid})"


def paint(a, d, fill, stroke=None, width=None, opacity=1.0, transform=""):
    st = f' stroke="{stroke}" stroke-width="{width or a.ow:.2f}" stroke-linejoin="round" stroke-linecap="round"' if stroke else ""
    op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
    t = f' transform="{transform}"' if transform else ""
    a.parts.append(f'<path d="{d}" fill="{fill}"{op}{st}{t}/>')


def gloss(a, cx, cy, rx, ry, turn=-30, op=0.55):
    a.parts.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({turn} {cx} {cy})" fill="#FFFFFF" fill-opacity="{op}"/>')


def blob(cx, cy, r, lobes, wobble, phase=0.0, ry=None, n=36):
    ry = ry or r
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        w = 1 + wobble * math.sin(lobes * t + phase)
        pts.append((cx + math.cos(t) * r * w, cy + math.sin(t) * ry * w))
    return smooth(pts, closed=True)


# ---------------------------------------------------------------------------
# the trails that were drawn in code
# ---------------------------------------------------------------------------


def puff(variant):
    """Dust: a soft little cloud of a few round lobes, lit from the upper left."""
    a = art()
    base = "#E6DACA"
    lobes = [(36, 58, 20), (56, 50, 24), (70, 62, 16), (48, 66, 18)] if variant == 1 else [(38, 54, 22), (60, 56, 20), (50, 42, 18)]
    outline = mix(base, "#8A7A62", 0.55)
    for cx, cy, r in lobes:
        a.parts.append(f'<path d="{circ(cx, cy, r + 1.2)}" fill="{outline}" fill-opacity="0.55"/>')
    for cx, cy, r in lobes:
        a.parts.append(f'<path d="{circ(cx, cy, r)}" fill="{radial(a, [(0, "#FFFFFF", 1), (0.6, base, 1), (1, mix(base, "#8A7A62", 0.35), 1)], 0.35, 0.3, 0.8)}"/>')
    return a.svg()


def bubble():
    a = art()
    rim = "#9BE7FF"
    paint(a, circ(50, 50, 38), radial(a, [(0, "#FFFFFF", 0.05), (0.7, rim, 0.22), (1, rim, 0.75)], 0.45, 0.42, 0.62),
          mix(rim, "#2B7A99", 0.45), 2.4)
    gloss(a, 37, 34, 12, 6, -35, 0.85)
    a.fill(circ(64, 66, 4), "#FFFFFF", 0.5)
    return a.svg()


def leaf(color):
    a = art()
    d = "M 20 72 C 22 46, 44 24, 80 20 C 78 52, 58 76, 20 72 Z"
    a.shape(d, color, light=0.35, dark=0.3)
    a.line("M 24 70 C 40 56, 56 40, 74 26", mix(color, INK, 0.45), 2.2, 0.8)
    for t, side in ((0.35, 1), (0.55, -1), (0.72, 1)):
        x, y = 24 + (74 - 24) * t, 70 + (26 - 70) * t
        a.line(f"M {x:.1f} {y:.1f} l {8 * side:.1f} {6 * side:.1f}" if side > 0 else f"M {x:.1f} {y:.1f} l {-6:.1f} {-8:.1f}",
               mix(color, INK, 0.45), 1.4, 0.6)
    a.line("M 20 72 L 12 80", mix(color, INK, 0.5), 2.6)
    return a.svg()


def sparkle(color, small=False):
    a = art()
    a.glow(50, 50, 46, 46, color, 0.55)
    r = 30 if small else 42
    paint(a, star(50, 50, r, r * 0.22, 4, -90), radial(a, [(0, "#FFFFFF", 1), (0.6, color, 1), (1, mix(color, "#E0A000", 0.4), 1)], 0.5, 0.5, 0.6),
          mix(color, "#B07A00", 0.5), 1.6)
    paint(a, star(50, 50, r * 0.45, r * 0.12, 4, -45), "#FFFFFF", None, None, 0.8)
    return a.svg()


def ember(core, hot):
    a = art()
    a.glow(50, 50, 48, 48, core, 0.6)
    paint(a, blob(50, 50, 22, 5, 0.12, 0.7), radial(a, [(0, "#FFF6C2", 1), (0.45, hot, 1), (1, core, 1)], 0.42, 0.4, 0.7),
          mix(core, "#7A2200", 0.4), 1.8)
    return a.svg()


def heart(color):
    a = art()
    d = "M 50 82 C 18 62, 12 42, 22 30 C 32 18, 46 22, 50 34 C 54 22, 68 18, 78 30 C 88 42, 82 62, 50 82 Z"
    a.shape(d, color, light=0.35, dark=0.32)
    gloss(a, 34, 36, 9, 5, -40, 0.7)
    return a.svg()


def star_(color):
    a = art()
    d = star(50, 52, 42, 19, 5, -90)
    a.shape(d, color, light=0.4, dark=0.3, outline=mix(color, "#8A5A00", 0.55) if color != "#FFFFFF" else "#9AA4B8")
    paint(a, star(46, 48, 18, 8, 5, -90), "#FFFFFF", None, None, 0.45)
    return a.svg()


def rainbow_arc():
    a = art()
    bands = ["#FF5E5E", "#FFB13B", "#FFE45C", "#5EE07A", "#4FC3FF", "#8E7CFF"]
    for k, col in enumerate(bands):
        r = 38 - k * 4.2
        a.line(f"M {50 - r} 66 A {r} {r} 0 0 1 {50 + r} 66", col, 4.6)
    a.line("M 12 66 A 38 38 0 0 1 88 66", mix("#FF5E5E", INK, 0.4), 1.2, 0.6)
    for cx in (16, 84):
        a.shape(blob(cx, 70, 14, 4, 0.14, cx * 0.1, 9), "#FFFFFF", light=0.1, dark=0.12, outline="#9AA4B8")
    return a.svg()


def prism():
    """A sparkle with the rainbow round it."""
    a = art()
    a.glow(50, 50, 46, 46, "#FFFFFF", 0.45)
    cols = ["#FF5E5E", "#FFB13B", "#FFE45C", "#5EE07A", "#4FC3FF", "#8E7CFF"]
    for k, col in enumerate(cols):
        ang = math.radians(-90 + k * 60 + 30)
        paint(a, circ(50 + math.cos(ang) * 30, 50 + math.sin(ang) * 30, 7), col, mix(col, INK, 0.4), 1.4)
    paint(a, star(50, 50, 30, 7, 4, -90), radial(a, [(0, "#FFFFFF", 1), (1, "#FFF6C2", 1)], 0.5, 0.5, 0.6), "#B8A060", 1.4)
    return a.svg()


# ---------------------------------------------------------------------------
# new trails
# ---------------------------------------------------------------------------


def coin(edge=False):
    """A gold doubloon: face on, or turned on its edge as it flips."""
    a = art()
    gold, gold_d = "#F5C14B", "#B8841C"
    if edge:
        a.shape(ell(50, 50, 14, 38), gold_d, light=0.3, dark=0.3, outline=mix(gold_d, INK, 0.5))
        a.shape(ell(46, 50, 12, 36), gold, light=0.4, dark=0.3, outline=mix(gold_d, INK, 0.45))
        a.line("M 44 22 C 40 36, 40 64, 44 78", "#FFF3B0", 2.4, 0.7)
        return a.svg()
    a.shape(circ(50, 50, 40), gold_d, light=0.25, dark=0.3, outline=mix(gold_d, INK, 0.5))
    a.shape(circ(48, 48, 36), gold, light=0.45, dark=0.25, outline=mix(gold_d, INK, 0.35))
    a.line(circ(48, 48, 28), mix(gold_d, "#7A5200", 0.3), 1.6, 0.6)
    # a skull stamped in the middle
    paint(a, "M 37 46 C 37 34, 59 34, 59 46 C 59 52, 55 54, 54 58 L 42 58 C 41 54, 37 52, 37 46 Z", mix(gold_d, "#7A5200", 0.2))
    paint(a, circ(43, 47, 3.4), gold)
    paint(a, circ(53, 47, 3.4), gold)
    paint(a, "M 36 64 L 60 70 M 60 64 L 36 70", "none", mix(gold_d, "#7A5200", 0.2), 3)
    gloss(a, 34, 30, 10, 5, -35, 0.6)
    return a.svg()


def shell(kind):
    a = art()
    if kind == 1:
        # a scallop: ribs fanning out from its hinge
        pink, pink_d = "#F7A8B8", "#C96A80"
        d = "M 50 82 L 30 74 C 14 62, 12 36, 30 22 C 40 14, 60 14, 70 22 C 88 36, 86 62, 70 74 Z"
        a.shape(d, pink, light=0.4, dark=0.25, outline=mix(pink_d, INK, 0.4))
        for k in range(-3, 4):
            x = 50 + k * 9
            a.line(f"M 50 80 Q {50 + k * 4} 52, {x} {20 + abs(k) * 2.4}", pink_d, 1.8, 0.6)
        a.shape("M 40 82 L 60 82 L 56 90 L 44 90 Z", pink, outline=mix(pink_d, INK, 0.4))
        gloss(a, 38, 30, 9, 4, -30, 0.5)
    else:
        # a spiral shell
        cream, cream_d = "#F3E2C3", "#B99566"
        d = "M 22 70 C 16 50, 30 22, 56 20 C 80 18, 88 42, 76 58 C 66 72, 44 80, 22 70 Z"
        a.shape(d, cream, light=0.35, dark=0.3, outline=mix(cream_d, INK, 0.4))
        a.line("M 58 46 C 58 40, 66 40, 66 46 C 66 54, 54 56, 50 48 C 46 38, 58 30, 66 32 C 76 34, 80 46, 74 56", cream_d, 2.6, 0.85)
        a.line("M 30 66 C 40 62, 50 62, 60 64", cream_d, 1.8, 0.5)
        gloss(a, 40, 34, 10, 5, -30, 0.5)
    return a.svg()


def feather(color, tip):
    a = art()
    d = "M 50 88 C 30 70, 24 40, 46 12 C 52 6, 58 8, 60 16 C 76 44, 70 72, 50 88 Z"
    a.shape(d, color, light=0.35, dark=0.3)
    a.group(clip=d)
    a.fill("M 30 10 L 80 10 L 80 30 L 30 30 Z", tip, 0.9)
    for k in range(6):
        y = 28 + k * 9
        a.line(f"M 52 {y + 6} L 36 {y - 2}", mix(color, INK, 0.35), 1.2, 0.45)
        a.line(f"M 52 {y + 6} L 66 {y - 2}", mix(color, INK, 0.35), 1.2, 0.45)
    a.end()
    a.line("M 52 94 C 52 70, 52 40, 52 18", mix(color, "#FFFFFF", 0.55), 2.4, 0.95)
    return a.svg()


def snowflake(big=True):
    a = art()
    ice, ice_d = "#DDF3FF", "#5FA8D3"
    a.glow(50, 50, 44, 44, "#BFE7FF", 0.45)
    arms = 6
    r = 40 if big else 30
    for k in range(arms):
        ang = math.radians(-90 + k * 60)
        ex, ey = 50 + math.cos(ang) * r, 50 + math.sin(ang) * r
        a.line(f"M 50 50 L {ex:.1f} {ey:.1f}", ice_d, 8.4)
    for k in range(arms):
        ang = math.radians(-90 + k * 60)
        ex, ey = 50 + math.cos(ang) * r, 50 + math.sin(ang) * r
        a.line(f"M 50 50 L {ex:.1f} {ey:.1f}", ice, 5.0)
        if big:
            for t in (0.55,):
                bx, by = 50 + math.cos(ang) * r * t, 50 + math.sin(ang) * r * t
                for side in (-1, 1):
                    b = ang + side * math.radians(48)
                    a.line(f"M {bx:.1f} {by:.1f} L {bx + math.cos(b) * 12:.1f} {by + math.sin(b) * 12:.1f}", ice_d, 6.4)
                    a.line(f"M {bx:.1f} {by:.1f} L {bx + math.cos(b) * 12:.1f} {by + math.sin(b) * 12:.1f}", ice, 3.4)
    paint(a, circ(50, 50, 7), ice, ice_d, 2.2)
    return a.svg()


def blossom(petal_only=False):
    a = art()
    pink, pink_d = "#FFC2D6", "#E07A9C"
    if petal_only:
        d = "M 50 84 C 26 68, 26 36, 40 22 C 44 30, 50 32, 50 32 C 50 32, 56 30, 60 22 C 74 36, 74 68, 50 84 Z"
        a.shape(d, pink, light=0.35, dark=0.25, outline=mix(pink_d, INK, 0.35))
        a.line("M 50 80 L 50 44", pink_d, 1.6, 0.5)
        return a.svg()
    for k in range(5):
        ang = -90 + k * 72
        a.parts.append(f'<g transform="rotate({ang + 90} 50 50)">')
        a.shape("M 50 50 C 36 40, 36 18, 44 12 C 47 16, 50 17, 50 17 C 50 17, 53 16, 56 12 C 64 18, 64 40, 50 50 Z",
                pink, light=0.35, dark=0.2, outline=mix(pink_d, INK, 0.35))
        a.end()
    paint(a, circ(50, 50, 9), "#FFE08A", mix("#C98E1E", INK, 0.3), 1.6)
    for k in range(5):
        ang = math.radians(-90 + k * 72 + 36)
        a.fill(circ(50 + math.cos(ang) * 6, 50 + math.sin(ang) * 6, 1.6), "#C98E1E")
    return a.svg()


def firefly():
    a = art()
    a.glow(50, 52, 48, 48, "#E8FF7A", 0.75)
    paint(a, circ(50, 56, 14), radial(a, [(0, "#FFFFFF", 1), (0.5, "#F4FF9C", 1), (1, "#C8E83A", 1)], 0.5, 0.45, 0.6))
    # its little dark body and wings above the glow
    a.parts.append(f'<path d="{ell(41, 36, 8, 5)}" fill="#FFFFFF" fill-opacity="0.6" transform="rotate(-25 41 36)"/>')
    a.parts.append(f'<path d="{ell(59, 36, 8, 5)}" fill="#FFFFFF" fill-opacity="0.6" transform="rotate(25 59 36)"/>')
    paint(a, ell(50, 40, 5, 8), "#3A3326", mix("#3A3326", INK, 0.5), 1.2)
    return a.svg()


def note(double=False):
    a = art()
    ink, ink_d = "#3B3552", "#1C1830"
    if double:
        for cx in (32, 68):
            paint(a, ell(cx, 74, 12, 9), ink, ink_d, 2.2, transform=f"rotate(-20 {cx} 74)")
        a.line("M 42 72 L 42 22 L 78 14 L 78 64", ink_d, 6.6)
        a.line("M 42 72 L 42 22 L 78 14 L 78 64", ink, 3.8)
        a.line("M 42 30 L 78 22", ink, 7)
        gloss(a, 28, 70, 4, 2.4, -20, 0.55)
        gloss(a, 64, 70, 4, 2.4, -20, 0.55)
        return a.svg()
    paint(a, ell(38, 74, 14, 10), ink, ink_d, 2.2, transform="rotate(-20 38 74)")
    a.line("M 50 70 L 50 14", ink_d, 6.6)
    a.line("M 50 70 L 50 14", ink, 3.8)
    a.line("M 50 16 C 66 20, 70 34, 64 46", ink_d, 6.4)
    a.line("M 50 16 C 66 20, 70 34, 64 46", ink, 3.6)
    gloss(a, 33, 70, 5, 2.6, -20, 0.55)
    return a.svg()


def wisp(ghost=True):
    a = art()
    if ghost:
        body, body_d = "#F4F7FB", "#9AA8BF"
        a.glow(50, 52, 46, 46, "#CFE6FF", 0.45)
        d = "M 26 82 C 26 40, 34 18, 50 18 C 66 18, 74 40, 74 82 C 68 76, 64 86, 58 80 C 54 86, 46 86, 42 80 C 36 86, 32 76, 26 82 Z"
        a.shape(d, body, light=0.2, dark=0.18, outline=body_d)
        a.fill(ell(43, 46, 4, 5.5), "#2E3448")
        a.fill(ell(57, 46, 4, 5.5), "#2E3448")
        a.fill(ell(50, 58, 4, 3), "#2E3448", 0.8)
        return a.svg()
    a.glow(50, 56, 46, 46, "#7FD8FF", 0.55)
    d = "M 50 88 C 30 86, 24 64, 36 48 C 40 56, 46 56, 44 44 C 42 30, 52 18, 58 12 C 58 28, 74 40, 72 62 C 70 80, 62 88, 50 88 Z"
    paint(a, d, radial(a, [(0, "#FFFFFF", 1), (0.5, "#A6E8FF", 1), (1, "#3FA7E0", 1)], 0.5, 0.7, 0.65), "#2C7FB8", 2)
    return a.svg()


GEMS = {1: ("#E23A4E", "#8E1426"), 2: ("#3C7FE8", "#173E8E"), 3: ("#2FBF71", "#126B3C")}


def gem(kind):
    """A cut jewel seen from above: a table and facets round it."""
    color, dark = GEMS[kind]
    a = art()
    a.glow(50, 50, 46, 46, color, 0.3)
    outer = [(50 + math.cos(math.radians(-90 + k * 45)) * 40, 50 + math.sin(math.radians(-90 + k * 45)) * 40) for k in range(8)]
    inner = [(50 + math.cos(math.radians(-90 + k * 45)) * 20, 50 + math.sin(math.radians(-90 + k * 45)) * 20) for k in range(8)]
    paint(a, poly(outer), color, mix(dark, INK, 0.4), 2.4)
    for k in range(8):
        o1, o2, i1, i2 = outer[k], outer[(k + 1) % 8], inner[k], inner[(k + 1) % 8]
        # facets toward the light are lighter
        mid = math.cos(math.radians(-90 + k * 45 + 22.5) - math.radians(-135))
        col = mix(color, "#FFFFFF", 0.4) if mid > 0.3 else (mix(color, dark, 0.6) if mid < -0.3 else color)
        paint(a, poly([o1, o2, i2, i1]), col, mix(dark, INK, 0.2), 0.8)
    paint(a, poly(inner), mix(color, "#FFFFFF", 0.2), mix(dark, INK, 0.2), 0.8)
    paint(a, star(36, 34, 8, 2, 4, -90), "#FFFFFF", None, None, 0.95)
    return a.svg()


def ink(splat=True):
    a = art()
    col, col_d = "#3A2E5C", "#1C1530"
    if splat:
        a.shape(blob(50, 52, 28, 7, 0.22, 0.4), col, light=0.25, dark=0.3, outline=col_d)
        for (x, y, r) in ((20, 28, 5), (82, 34, 4), (78, 78, 6), (22, 80, 3.5)):
            a.shape(circ(x, y, r), col, outline=col_d)
        gloss(a, 40, 42, 8, 4, -30, 0.4)
        return a.svg()
    d = "M 50 16 C 58 34, 72 48, 72 62 C 72 76, 62 86, 50 86 C 38 86, 28 76, 28 62 C 28 48, 42 34, 50 16 Z"
    a.shape(d, col, light=0.25, dark=0.3, outline=col_d)
    gloss(a, 40, 58, 5, 9, -10, 0.45)
    return a.svg()


def bolt(burst=False):
    a = art()
    yel, yel_d = "#FFE14D", "#C98E1E"
    a.glow(50, 50, 48, 48, "#FFF3A0", 0.55)
    if burst:
        paint(a, star(50, 50, 40, 14, 8, -90), yel, mix(yel_d, INK, 0.35), 2)
        paint(a, star(50, 50, 18, 7, 8, -67.5), "#FFFFFF", None, None, 0.9)
        return a.svg()
    d = "M 58 8 L 26 54 L 46 54 L 36 92 L 76 40 L 54 40 L 66 8 Z"
    a.shape(d, yel, light=0.45, dark=0.25, outline=mix(yel_d, INK, 0.35))
    a.line("M 56 14 L 34 48", "#FFFFFF", 2.6, 0.75)
    return a.svg()


CONFETTI = {1: "#FF5E7A", 2: "#4FC3FF", 3: "#FFD23F"}


def confetti(kind):
    a = art()
    col = CONFETTI[kind]
    if kind == 1:
        # a curled strip
        a.line("M 22 70 C 30 40, 46 76, 54 46 C 60 24, 74 44, 80 28", mix(col, INK, 0.45), 11)
        a.line("M 22 70 C 30 40, 46 76, 54 46 C 60 24, 74 44, 80 28", col, 7.2)
    elif kind == 2:
        a.shape("M 26 34 L 66 22 L 76 62 L 36 74 Z", col, light=0.4, dark=0.3)
    else:
        a.shape("M 20 52 L 76 30 L 82 44 L 26 66 Z", col, light=0.45, dark=0.3)
    return a.svg()


def paw():
    """A paw print on the ground (squashed like the board)."""
    a = art()
    col = "#6B4A32"
    a.group(transform="translate(0 14) scale(1 0.72)")
    a.shape("M 50 86 C 30 86, 26 66, 36 58 C 44 52, 56 52, 64 58 C 74 66, 70 86, 50 86 Z", col, light=0.2, dark=0.2)
    for (x, y, r) in ((26, 46, 9), (40, 30, 9.5), (60, 30, 9.5), (74, 46, 9)):
        a.shape(ell(x, y, r * 0.85, r), col, light=0.2, dark=0.2)
    a.end()
    return a.svg()


FISHY = {1: ("#FF9F43", "#FFFFFF"), 2: ("#4FA3FF", "#E8F4FF")}


def fishy(kind):
    """A little fish for the Fish School."""
    body, belly = FISHY[kind]
    a = art()
    a.shape("M 70 50 L 92 32 C 90 44, 90 56, 92 68 Z", mix(body, INK, 0.15), outline=mix(body, INK, 0.55))
    d = "M 12 50 C 20 30, 50 26, 72 50 C 50 74, 20 70, 12 50 Z"
    a.shape(d, body, light=0.35, dark=0.3)
    a.group(clip=d)
    a.fill("M 10 54 C 30 64, 52 64, 74 52 L 74 80 L 10 80 Z", belly, 0.55)
    a.end()
    a.shape("M 40 34 C 46 24, 56 26, 58 36 Z", mix(body, INK, 0.15), outline=mix(body, INK, 0.55))
    a.fill(circ(26, 46, 4.6), "#FFFFFF")
    a.fill(circ(25, 46, 2.6), INK)
    gloss(a, 34, 40, 8, 3.4, -15, 0.5)
    return a.svg()


def sprites():
    return [
        ("puff_1", puff(1)),
        ("puff_2", puff(2)),
        ("bubble_1", bubble()),
        ("leaf_1", leaf("#80B918")),
        ("leaf_2", leaf("#F48C06")),
        ("sparkle_1", sparkle("#FFF3B0")),
        ("sparkle_2", sparkle("#FFFFFF", small=True)),
        ("ember_1", ember("#FF7B00", "#FFB000")),
        ("ember_2", ember("#FFB000", "#FFE45C")),
        ("heart_1", heart("#FF4D6D")),
        ("heart_2", heart("#FF8FAB")),
        ("star_1", star_("#FFE066")),
        ("star_2", star_("#FFFFFF")),
        ("rainbow_1", rainbow_arc()),
        ("rainbow_2", prism()),
        ("coin_1", coin()),
        ("coin_2", coin(edge=True)),
        ("shell_1", shell(1)),
        ("shell_2", shell(2)),
        ("feather_1", feather("#E5383B", "#2F7FD0")),
        ("feather_2", feather("#2F7FD0", "#7FE0A0")),
        ("feather_3", feather("#FFC93C", "#3E9F5B")),
        ("snow_1", snowflake()),
        ("snow_2", snowflake(big=False)),
        ("blossom_1", blossom()),
        ("blossom_2", blossom(petal_only=True)),
        ("firefly_1", firefly()),
        ("note_1", note()),
        ("note_2", note(double=True)),
        ("wisp_1", wisp()),
        ("wisp_2", wisp(ghost=False)),
        ("gem_1", gem(1)),
        ("gem_2", gem(2)),
        ("gem_3", gem(3)),
        ("ink_1", ink()),
        ("ink_2", ink(splat=False)),
        ("bolt_1", bolt()),
        ("bolt_2", bolt(burst=True)),
        ("confetti_1", confetti(1)),
        ("confetti_2", confetti(2)),
        ("confetti_3", confetti(3)),
        ("paw_1", paw()),
        ("fishy_1", fishy(1)),
        ("fishy_2", fishy(2)),
    ]
