"""
What a piece wears when something's happened to it (BoardView's status marks), drawn
like the rest of the art. tools/art.py calls sprites(). Each on a 100 x 100 canvas:

    marks/flame        Burning: a flame dancing over the piece
    marks/ice          Frozen: a see-through block of ice round the piece
    marks/poster       Wanted: the poster nailed up beside it (the game writes WANTED and
    marks/poster_gold  the price on it); gold for the Most Wanted
    marks/zzz          Snared: it sits out its next turn
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from badge import smooth  # noqa: E402
from props import INK, Art, circ, ell, mix  # noqa: E402

PX = 128


def lin(a, stops, x1=0.2, y1=0.0, x2=0.8, y2=1.0):
    gid = a._id("ml")
    st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    a.defs.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
    return f"url(#{gid})"


def rad(a, stops, cx=0.5, cy=0.7, r=0.7):
    gid = a._id("mr")
    st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    a.defs.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">{st}</radialGradient>')
    return f"url(#{gid})"


def paint(a, d, fill, stroke=None, width=None, opacity=1.0):
    st = f' stroke="{stroke}" stroke-width="{width or a.ow:.2f}" stroke-linejoin="round" stroke-linecap="round"' if stroke else ""
    op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
    a.parts.append(f'<path d="{d}" fill="{fill}"{op}{st}/>')


def flame():
    a = Art(PX, 1.3)
    a.glow(50, 70, 40, 30, "#FFB000", 0.45)
    outer = "M 50 94 C 26 94, 18 74, 26 58 C 30 66, 36 68, 36 60 C 36 44, 44 30, 56 10 C 58 28, 70 34, 74 52 C 78 46, 78 40, 76 34 C 88 50, 86 94, 50 94 Z"
    paint(a, outer, rad(a, [(0, "#FFE45C", 1), (0.55, "#FF9F1C", 1), (1, "#E5383B", 1)], 0.5, 0.8, 0.85), mix("#B83A12", INK, 0.3), a.ow)
    inner = "M 50 92 C 38 92, 34 80, 40 70 C 42 76, 46 76, 46 70 C 46 60, 50 52, 56 44 C 58 56, 66 62, 64 76 C 62 88, 58 92, 50 92 Z"
    paint(a, inner, rad(a, [(0, "#FFFFFF", 1), (0.5, "#FFF3A0", 1), (1, "#FFC93C", 1)], 0.5, 0.8, 0.8))
    return a.svg()


def ice():
    a = Art(PX, 1.3)
    line = "#3F8FC0"
    # the block: its top seen a little from above, and its front
    top = "M 12 26 L 30 12 L 88 12 L 88 18 L 70 32 L 12 32 Z"
    front = "M 12 30 L 70 30 L 70 92 L 12 92 Z"
    side = "M 70 30 L 88 14 L 88 76 L 70 92 Z"
    paint(a, side, lin(a, [(0, "#9AD8F5", 0.55), (1, "#5FB0DE", 0.55)]), line, a.ow * 0.8)
    paint(a, front, lin(a, [(0, "#E8F8FF", 0.5), (0.6, "#BFE7FF", 0.42), (1, "#8CCBEB", 0.5)]), line, a.ow * 0.8)
    paint(a, "M 12 30 L 30 14 L 88 14 L 70 30 Z", lin(a, [(0, "#FFFFFF", 0.75), (1, "#CFEFFF", 0.65)]), line, a.ow * 0.8)
    # glints and cracks
    a.line("M 18 40 L 18 70", "#FFFFFF", 3.2, 0.7)
    a.line("M 24 38 L 24 50", "#FFFFFF", 2.2, 0.55)
    a.line("M 56 44 L 50 56 L 58 62 L 52 76", "#FFFFFF", 1.4, 0.8)
    a.line("M 76 34 L 76 70", "#FFFFFF", 1.8, 0.5)
    return a.svg()


def poster(gold=False):
    a = Art(PX, 1.3)
    paper, paper_d = ("#FFE08A", "#C98E1E") if gold else ("#F1DDB4", "#B8945E")
    edge = mix(paper_d, INK, 0.45)
    a.shadow(54, 94, 34, 4, 0.25)
    # the sheet, a little ragged at the edges
    pts = [(14, 10), (34, 8), (52, 11), (72, 8), (86, 10), (88, 30), (85, 52), (88, 74), (86, 92), (64, 90), (46, 93), (26, 90), (12, 92), (15, 70), (12, 48), (15, 28)]
    d = smooth(pts, closed=True)
    paint(a, d, lin(a, [(0, mix(paper, "#FFFFFF", 0.3), 1), (0.6, paper, 1), (1, mix(paper, paper_d, 0.5), 1)]), edge, a.ow)
    a.group(clip=d)
    # stains and the creases of being folded
    a.parts.append(f'<path d="{ell(72, 78, 14, 9)}" fill="{paper_d}" fill-opacity="0.18"/>')
    a.line("M 12 50 L 88 48", paper_d, 1.0, 0.35)
    a.line("M 50 8 L 49 94", paper_d, 1.0, 0.25)
    a.end()
    # a skull in the middle (the words go above and below it)
    skull = "M 38 50 C 38 38, 62 38, 62 50 C 62 56, 58 58, 57 62 L 43 62 C 42 58, 38 56, 38 50 Z"
    paint(a, skull, mix(paper_d, INK, 0.55))
    paint(a, circ(44.5, 50, 3.6), paper)
    paint(a, circ(55.5, 50, 3.6), paper)
    a.line("M 40 66 L 60 70 M 60 66 L 40 70", mix(paper_d, INK, 0.55), 3.2)
    # nails at its top corners
    for x in (22, 78):
        paint(a, circ(x, 16, 3.2), "#8A909C", "#3A3F4A", 1.0)
        a.fill(circ(x - 1, 15, 1.1), "#FFFFFF", 0.8)
    return a.svg()


def zzz():
    a = Art(PX, 1.3)
    col, line = "#BFD8FF", "#3E5F9A"
    for (x, y, s) in ((18, 82, 0.7), (40, 58, 0.9), (64, 30, 1.15)):
        w, h = 20 * s, 20 * s
        d = f"M {x} {y - h} L {x + w} {y - h} L {x + w} {y - h + 5 * s} L {x + 7 * s} {y - 5 * s} L {x + w} {y - 5 * s} L {x + w} {y} L {x} {y} L {x} {y - 5 * s} L {x + w - 7 * s} {y - h + 5 * s} L {x} {y - h + 5 * s} Z"
        paint(a, d, lin(a, [(0, "#FFFFFF", 1), (1, col, 1)]), line, a.ow * 0.9)
    return a.svg()


def sprites():
    return [("flame", flame()), ("ice", ice()), ("poster", poster()), ("poster_gold", poster(gold=True)), ("zzz", zzz())]
