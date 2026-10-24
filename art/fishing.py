"""
The fishing spot in the board's corner (FishingRod), drawn like the rest of the art.
tools/art.py calls sprites(). Each on a 100 x 100 canvas:

    fishing/water    the round pool the bobber floats in (the button's face)
    fishing/bobber   a red and white float, its middle on the canvas's middle
    fishing/ripple   a ring spreading on the water (the game grows and fades it)
    fishing/splash   the water jumping when a fish bites
    fishing/rod      a rod and reel, shown while the line is out of the water
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from badge import smooth, star  # noqa: E402
from props import INK, Art, circ, ell, mix  # noqa: E402

PX = 128


def art():
    return Art(PX, 1.2)


def lin(a, stops, x1=0.2, y1=0.0, x2=0.8, y2=1.0):
    gid = a._id("gl")
    st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    a.defs.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
    return f"url(#{gid})"


def rad(a, stops, cx=0.4, cy=0.35, r=0.75):
    gid = a._id("gr")
    st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    a.defs.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">{st}</radialGradient>')
    return f"url(#{gid})"


def paint(a, d, fill, stroke=None, width=None, opacity=1.0, transform=""):
    st = f' stroke="{stroke}" stroke-width="{width or a.ow:.2f}" stroke-linejoin="round" stroke-linecap="round"' if stroke else ""
    op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
    t = f' transform="{transform}"' if transform else ""
    a.parts.append(f'<path d="{d}" fill="{fill}"{op}{st}{t}/>')


def water():
    """A round pool seen from above: deep in the middle, light at the rim, a few swells."""
    a = art()
    deep, shallow, rim = "#1F6F9A", "#5FC1E0", "#2A4A5E"
    paint(a, circ(50, 50, 48), rad(a, [(0, shallow, 1), (0.55, "#3C9CC6", 1), (1, deep, 1)], 0.42, 0.38, 0.7), rim, 2.4)
    a.group(clip=circ(50, 50, 47))
    for k, (y, op) in enumerate(((28, 0.35), (46, 0.28), (64, 0.3), (80, 0.22))):
        x0 = 14 + (k % 2) * 8
        a.line(f"M {x0} {y} C {x0 + 8} {y - 4}, {x0 + 16} {y - 4}, {x0 + 24} {y} C {x0 + 32} {y + 4}, {x0 + 40} {y + 4}, {x0 + 48} {y}",
               "#FFFFFF", 2.0, op)
    a.parts.append(f'<ellipse cx="34" cy="26" rx="20" ry="9" transform="rotate(-25 34 26)" fill="#FFFFFF" fill-opacity="0.2"/>')
    a.end()
    a.line("M 8 50 A 42 42 0 0 1 50 8", "#FFFFFF", 2.4, 0.35)
    return a.svg()


def bobber():
    a = art()
    red, red_d = "#E5383B", "#A4161A"
    # its reflection and the ring where it sits in the water
    a.parts.append(f'<ellipse cx="50" cy="66" rx="24" ry="7" fill="#FFFFFF" fill-opacity="0.35"/>')
    # the stick on top
    a.line("M 50 30 L 50 12", mix(red_d, INK, 0.5), 5)
    a.line("M 50 30 L 50 12", "#F3EAD3", 3)
    paint(a, circ(50, 11, 3.4), red, mix(red_d, INK, 0.5), 1.4)
    # the float: red over white
    ball = circ(50, 50, 20)
    paint(a, ball, "#FFFFFF", mix(red_d, INK, 0.5), 2.6)
    a.group(clip=ball)
    paint(a, "M 20 20 L 80 20 L 80 50 C 70 54, 30 54, 20 50 Z", lin(a, [(0, mix(red, "#FFFFFF", 0.3), 1), (1, red, 1)]))
    paint(a, "M 20 54 C 30 58, 70 58, 80 54 L 80 80 L 20 80 Z", lin(a, [(0, "#FFFFFF", 1), (1, "#C9D3DA", 1)]))
    a.line("M 22 51 C 32 56, 68 56, 78 51", mix(red_d, INK, 0.4), 2.2, 0.9)
    a.end()
    a.parts.append(f'<ellipse cx="42" cy="40" rx="7" ry="4" transform="rotate(-30 42 40)" fill="#FFFFFF" fill-opacity="0.6"/>')
    return a.svg()


def ripple():
    a = art()
    a.parts.append('<ellipse cx="50" cy="50" rx="44" ry="20" fill="none" stroke="#FFFFFF" stroke-opacity="0.85" stroke-width="4"/>')
    a.parts.append('<ellipse cx="50" cy="51" rx="44" ry="20" fill="none" stroke="#1F6F9A" stroke-opacity="0.35" stroke-width="2" transform="translate(0 2)"/>')
    return a.svg()


def splash():
    a = art()
    foam, light = "#FFFFFF", "#BFE7FF"
    line = "#3C9CC6"
    a.parts.append(f'<ellipse cx="50" cy="74" rx="34" ry="10" fill="{light}" fill-opacity="0.8" stroke="{line}" stroke-width="2"/>')
    # a crown of water jumping up
    pts = [(18, 74), (22, 52), (30, 64), (36, 34), (44, 60), (50, 24), (56, 60), (64, 34), (70, 64), (78, 52), (82, 74)]
    d = smooth(pts) + " Z"
    paint(a, d, lin(a, [(0, foam, 1), (1, light, 1)], 0.5, 0, 0.5, 1), line, 2)
    for (x, y, r) in ((26, 30, 3.6), (50, 12, 4), (74, 28, 3.2), (14, 50, 2.6), (86, 48, 2.8)):
        paint(a, circ(x, y, r), foam, line, 1.4)
    return a.svg()


def rod():
    a = art()
    cane, cane_d = "#D9B66B", "#8A6A30"
    # the line from the tip, down to a hook
    a.line("M 82 14 C 84 40, 80 62, 76 74", "#F4F7FB", 1.6, 0.95)
    paint(a, "M 76 74 C 76 82, 66 84, 66 76", "none", "#8A93A6", 2.4)
    # the rod, from the handle at the bottom left to the tip
    a.line("M 16 88 L 82 14", mix(cane_d, INK, 0.4), 8)
    a.line("M 16 88 L 82 14", cane, 5.2)
    for t in (0.35, 0.55, 0.75):
        x, y = 16 + 66 * t, 88 - 74 * t
        a.line(f"M {x - 3:.1f} {y - 2.6:.1f} L {x + 3:.1f} {y + 2.6:.1f}", cane_d, 2.2)
    # the cork grip and the reel
    a.line("M 14 90 L 30 72", mix("#8A5A30", INK, 0.4), 11)
    a.line("M 14 90 L 30 72", "#C88A50", 8)
    paint(a, circ(38, 70, 9), lin(a, [(0, "#E6E9EE", 1), (1, "#8A909C", 1)]), "#4A5060", 1.8)
    paint(a, circ(38, 70, 3.4), "#4A5060")
    a.line("M 38 70 L 46 76", "#4A5060", 2.4)
    return a.svg()


def sprites():
    return [("water", water()), ("bobber", bobber()), ("ripple", ripple()), ("splash", splash()), ("rod", rod())]
