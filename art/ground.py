"""
The ground's own small art (tools/art.py calls sprites()): the soft spot the board uses
for the shallows, patches of lighter and darker ground and shadows, and the little
things lying about that keep the land and the sea from being one flat colour: grass
tufts, pebbles, shells, flowers, fallen leaves, swells on the sea; and the worn
stone faces of the tiles (round stones and square slabs).

Drawn like the props (lit from the upper left, outlines in a darker shade of the part's
own colour), on 100 x 100 canvases. Most are in greys, so the board tints each map's
own colour into them (ImageColor3); the shells and flowers keep their colours. And the
plain white shapes the board stretches into ellipses and tile tops (disc, rsq, ring).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props import INK, Art, circ, ell, mix  # noqa: E402

GREY, GREY_L, GREY_D = "#DADADA", "#F4F4F4", "#B4B4B4"


def soft():
    """A round spot fading out to its edge: shallows, soft patches, shadows, glow."""
    stops = ((0, 1), (0.3, 0.96), (0.55, 0.62), (0.8, 0.2), (1, 0))
    grad = "".join(f'<stop offset="{o}" stop-color="#FFFFFF" stop-opacity="{a}"/>' for o, a in stops)
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 100 100">'
        f'<defs><radialGradient id="s">{grad}</radialGradient></defs>'
        '<circle cx="50" cy="50" r="50" fill="url(#s)"/></svg>'
    )


def _shape(d, px=256):
    """A plain white shape filling its canvas: the board stretches and tints it (an
    ellipse from the disc, a tile's top from the rounded square)."""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 100 100">'
        f'<path d="{d}" fill="#FFFFFF"/></svg>'
    )


def disc():
    return _shape(circ(50, 50, 50))


def rsq():
    """A square with rounded corners (22% of its side), like a slab tile's top."""
    return _shape("M 22 0 L 78 0 C 90 0, 100 10, 100 22 L 100 78 C 100 90, 90 100, 78 100 L 22 100 C 10 100, 0 90, 0 78 L 0 22 C 0 10, 10 0, 22 0 Z", 128)


def ring():
    """A circle's rim, for an owner's mark round something on a tile."""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 100 100">'
        '<circle cx="50" cy="50" r="46.5" fill="none" stroke="#FFFFFF" stroke-width="6.5"/></svg>'
    )


def _blade(x0, x1, tx, ty, bend, base=80):
    """A blade of grass from the ground at x0..x1 to its tip, bowed by `bend`."""
    mx = (x0 + x1) / 2
    return (
        f"M {x0} {base} C {x0 + bend * 0.4} {base - (base - ty) * 0.5}, {tx - bend * 0.3} {ty + (base - ty) * 0.35}, {tx} {ty} "
        f"C {tx - bend * 0.15} {ty + (base - ty) * 0.4}, {mx + bend * 0.5} {base - (base - ty) * 0.45}, {x1} {base} Z"
    )


def tuft():
    a = Art(96, 0.6)
    a.shadow(50, 81, 22, 4, 0.22)
    for x0, x1, tx, ty, bend, tone in (
        (40, 46, 20, 50, -10, GREY_D), (55, 61, 82, 48, 10, GREY_D),
        (43, 50, 33, 32, -6, GREY), (51, 58, 70, 34, 6, GREY), (46, 54, 51, 20, 2, GREY_L),
    ):
        a.shape(_blade(x0, x1, tx, ty, bend), tone, 0.25, 0.25, outline=mix(tone, INK, 0.4))
    return a.svg()


def pebbles():
    a = Art(96, 0.55)
    for cx, cy, rx, ry in ((40, 70, 17, 11), (64, 76, 11, 7.5), (26, 82, 8, 5.5)):
        a.shadow(cx + 2, cy + ry * 0.75, rx * 1.05, ry * 0.45, 0.25)
        a.shape(ell(cx, cy, rx, ry), GREY, 0.35, 0.35, outline=mix(GREY, INK, 0.45))
        a.fill(ell(cx - rx * 0.28, cy - ry * 0.4, rx * 0.45, ry * 0.28), GREY_L, 0.8)
    return a.svg()


def shell():
    """A scallop shell and a starfish on the sand."""
    a = Art(96, 0.6)
    cream, pink = "#F6E3CC", "#E9A07E"
    a.shadow(38, 74, 18, 4, 0.2)
    fan = "M 38 76 C 26 76, 20 66, 22 56 C 24 46, 32 40, 38 40 C 44 40, 52 46, 54 56 C 56 66, 50 76, 38 76 Z"
    a.shape(fan, cream, 0.3, 0.25, outline="#B9805E")
    for x in (28, 33, 38, 43, 48):
        a.line(f"M 38 74 L {x} 44", pink, a.ow * 0.8, 0.7)
    a.shape("M 32 75 L 44 75 L 41 81 L 35 81 Z", cream, 0.2, 0.2, outline="#B9805E")
    # the starfish
    import math
    orange = "#F08A4B"
    pts = []
    for k in range(10):
        ang = -math.pi / 2 + k * math.pi / 5
        r = 15 if k % 2 == 0 else 6.5
        pts.append(f"{70 + math.cos(ang) * r:.1f} {68 + math.sin(ang) * r:.1f}")
    a.shadow(71, 80, 13, 3, 0.2)
    a.shape("M " + " L ".join(pts) + " Z", orange, 0.3, 0.3)
    for cx, cy in ((70, 62), (75, 67), (66, 67), (70, 71)):
        a.fill(circ(cx, cy, 1.1), "#FFD2A8", 0.9)
    return a.svg()


def flowers():
    """Three little flowers in a clump of leaves."""
    a = Art(96, 0.55)
    leaf, leaf_d = "#5FA548", "#3E7A33"
    a.shadow(50, 80, 26, 4, 0.2)
    for d in ("M 50 80 C 40 78, 30 72, 26 64 C 36 66, 44 72, 50 80 Z", "M 50 80 C 60 78, 70 72, 74 64 C 64 66, 56 72, 50 80 Z"):
        a.shape(d, leaf, 0.3, 0.25, outline=leaf_d)
    for cx, cy, r in ((36, 58, 9), (58, 50, 10), (66, 70, 7.5)):
        petal = "#FFF6E8"
        for k in range(5):
            import math
            ang = -math.pi / 2 + k * 2 * math.pi / 5
            a.shape(circ(cx + math.cos(ang) * r * 0.62, cy + math.sin(ang) * r * 0.62, r * 0.48), petal, 0.15, 0.2, outline="#C9B9A2")
        a.shape(circ(cx, cy, r * 0.36), "#F2B33D", 0.3, 0.3)
    return a.svg()


def leaves():
    """Fallen leaves."""
    a = Art(96, 0.6)
    for cx, cy, rot, s in ((36, 62, -30, 1.0), (62, 56, 25, 0.9), (52, 76, 70, 0.8)):
        a.group(f"translate({cx} {cy}) rotate({rot}) scale({s})")
        a.shadow(2, 4, 16, 6, 0.18)
        a.shape("M -16 0 C -10 -9, 6 -10, 16 0 C 6 10, -10 9, -16 0 Z", GREY, 0.3, 0.3, outline=mix(GREY, INK, 0.45))
        a.line("M -15 0 L 14 0 M -4 0 L 2 -6 M -4 0 L 2 6 M 5 0 L 10 -4 M 5 0 L 10 4", GREY_D, a.ow * 0.6, 0.8)
        a.end()
    return a.svg()


def wave():
    """A long low swell on open water (white: the board tints it to the sea)."""
    a = Art(96, 0.9)
    a.line("M 8 58 C 22 49, 36 49, 50 56 C 64 63, 78 63, 92 54", "#FFFFFF", a.ow * 2.2)
    return a.svg()


def _speckles(a, seed, n, x0, y0, x1, y1, inside):
    """Little pits and flecks in a stone's face (a fixed pattern per seed)."""
    import random

    rnd = random.Random(seed)
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        if inside(x, y):
            r = rnd.uniform(0.7, 1.8)
            a.fill(circ(x, y, r), "#BFBFBF" if rnd.random() < 0.6 else "#FFFFFF", rnd.uniform(0.25, 0.55))


def _stone_face(round_):
    """A tile's top as worn stone, in light greys (the board tints it the tile's colour)."""
    a = Art(160, 1.6)
    if round_:
        outline = circ(50, 50, 50)
        inside = lambda x, y: (x - 50) ** 2 + (y - 50) ** 2 < 44 ** 2
    else:
        outline = "M 22 0 L 78 0 C 90 0, 100 10, 100 22 L 100 78 C 100 90, 90 100, 78 100 L 22 100 C 10 100, 0 90, 0 78 L 0 22 C 0 10, 10 0, 22 0 Z"
        inside = lambda x, y: 6 < x < 94 and 6 < y < 94
    a.fill(outline, "#F1F1F1")
    a.group(clip=outline)
    # weathered patches, a worn hollow and a hairline crack
    for d, c, o in (
        ("M 18 30 C 26 20, 44 18, 52 26 C 58 32, 50 42, 38 42 C 26 42, 12 40, 18 30 Z", "#DCDCDC", 0.35),
        ("M 58 62 C 66 54, 84 56, 86 66 C 88 76, 76 84, 66 80 C 58 77, 52 70, 58 62 Z", "#D6D6D6", 0.3),
        ("M 30 70 C 34 64, 44 64, 46 70 C 47 75, 40 78, 35 77 C 30 76, 28 73, 30 70 Z", "#E2E2E2", 0.4),
        ("M 62 18 C 70 14, 80 18, 82 26 C 76 28, 66 28, 62 18 Z", "#FFFFFF", 0.5),
    ):
        a.fill(d, c, o)
    a.line("M 64 34 L 70 42 L 69 50 L 76 56", "#C4C4C4", 1.0, 0.6)
    _speckles(a, 7 if round_ else 11, 30, 4, 4, 96, 96, inside)
    a.end()
    return a.svg()


def stone():
    return _stone_face(True)


def slab():
    return _stone_face(False)


SPRITES = [
    ("soft", soft), ("tuft", tuft), ("pebbles", pebbles), ("shell", shell), ("flowers", flowers),
    ("leaves", leaves), ("wave", wave), ("stone", stone), ("slab", slab),
    ("disc", disc), ("rsq", rsq), ("ring", ring),
]


def sprites():
    return [(name, draw()) for name, draw in SPRITES]
