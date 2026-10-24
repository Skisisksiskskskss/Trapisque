"""
The Treasure Chests players open with Gems (Shared/Meta/Gacha), drawn like the rest of
the art: lit from the upper left, outlined in a dark shade of each part's own colour, a
soft shadow under them. tools/art.py calls sprites().

Each chest is two sprites on the same 100 x 100 canvas, so drawn one over the other they
make the closed chest: "chests/<id>_base" (the box, its trim and lock) and
"chests/<id>_lid" (the domed lid), which the reveal sends flying. They sit where the
code-drawn chest they replace did (Chests.art: x 10 to 90, lid from y 26.5, box to y 88).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from badge import rrect, star  # noqa: E402
from props import INK, Art, circ, ell, mix  # noqa: E402

PX = 256

# id: body, trim, band, gem (Gacha.chests[i].look)
CHESTS = {
    "explorer": ("#8B5E34", "#D4A373", "#6F4518", "#4FA3FF"),
    "royal": ("#5A189A", "#FFD60A", "#3C096C", "#FF5FA2"),
}


def lin(a, stops, x1=0.2, y1=0.0, x2=0.8, y2=1.0):
    gid = a._id("cl")
    st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    a.defs.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
    return f"url(#{gid})"


def paint(a, d, fill, stroke=None, width=None, opacity=1.0):
    st = f' stroke="{stroke}" stroke-width="{width or a.ow:.2f}" stroke-linejoin="round" stroke-linecap="round"' if stroke else ""
    op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
    a.parts.append(f'<path d="{d}" fill="{fill}"{op}{st}/>')


def metal(a, trim):
    return lin(a, [(0, mix(trim, "#FFFFFF", 0.45), 1), (0.5, trim, 1), (1, mix(trim, INK, 0.3), 1)])


def base(chest):
    body, trim, band, gem = CHESTS[chest]
    a = Art(PX, 2.2)
    line = mix(band, INK, 0.55)
    a.shadow(50, 89, 44, 5, 0.32)
    box = rrect(10, 47, 80, 41, 4)
    paint(a, box, lin(a, [(0, mix(body, "#FFFFFF", 0.18), 1), (0.6, body, 1), (1, mix(body, INK, 0.3), 1)]), line, a.ow)
    a.group(clip=box)
    # planks
    for y in (60, 73):
        a.line(f"M 10 {y} L 90 {y}", mix(body, INK, 0.4), 1.4, 0.7)
        a.line(f"M 10 {y + 1.2} L 90 {y + 1.2}", mix(body, "#FFFFFF", 0.3), 0.8, 0.5)
    a.parts.append('<rect x="10" y="47" width="80" height="5" fill="#000000" fill-opacity="0.18"/>')
    a.end()
    # the metal corners and straps
    for x in (22, 78):
        paint(a, rrect(x - 4.5, 47, 9, 41, 1.5), metal(a, trim), mix(trim, INK, 0.55), a.ow * 0.8)
        for y in (52, 82):
            paint(a, circ(x, y, 1.4), mix(trim, INK, 0.45))
    paint(a, rrect(10, 84, 80, 4.5, 1.5), metal(a, trim), mix(trim, INK, 0.55), a.ow * 0.8)
    # the lock plate and its gem
    paint(a, rrect(41, 50, 18, 20, 3.5), metal(a, trim), mix(trim, INK, 0.55), a.ow * 0.9)
    paint(a, "M 50 60 C 47 60, 46 64, 48.5 66 L 47.5 70 L 52.5 70 L 51.5 66 C 54 64, 53 60, 50 60 Z", mix(trim, INK, 0.7))
    paint(a, circ(50, 55, 4.2), lin(a, [(0, mix(gem, "#FFFFFF", 0.55), 1), (1, mix(gem, INK, 0.2), 1)]), mix(gem, INK, 0.5), 1.2)
    a.fill(circ(48.6, 53.6, 1.2), "#FFFFFF", 0.9)
    return a.svg()


def lid(chest):
    body, trim, band, gem = CHESTS[chest]
    a = Art(PX, 2.2)
    line = mix(band, INK, 0.55)
    dome = "M 10 50 L 10 40 C 10 22, 30 26.5, 50 26.5 C 70 26.5, 90 22, 90 40 L 90 50 Z"
    paint(a, dome, lin(a, [(0, mix(body, "#FFFFFF", 0.3), 1), (0.6, body, 1), (1, mix(body, INK, 0.25), 1)]), line, a.ow)
    a.group(clip=dome)
    for x in (34, 66):
        a.line(f"M {x} 22 L {x} 50", mix(body, INK, 0.35), 1.2, 0.6)
    a.parts.append(f'<ellipse cx="36" cy="32" rx="22" ry="4.5" transform="rotate(-4 36 32)" fill="#FFFFFF" fill-opacity="0.22"/>')
    a.end()
    # the band along its rim and the metal straps over it
    paint(a, rrect(9, 45, 82, 6, 2), lin(a, [(0, mix(band, "#FFFFFF", 0.2), 1), (1, band, 1)]), line, a.ow * 0.8)
    for x in (22, 78):
        paint(a, f"M {x - 4.5} 50 L {x - 4.5} 28 C {x - 4.5} 25, {x + 4.5} 25, {x + 4.5} 28 L {x + 4.5} 50 Z", metal(a, trim), mix(trim, INK, 0.55), a.ow * 0.8)
    # the hasp hanging down from the middle
    paint(a, rrect(45, 42, 10, 10, 2.5), metal(a, trim), mix(trim, INK, 0.55), a.ow * 0.8)
    a.fill(star(29, 34, 3.4, 0.9, 4, -90), "#FFFFFF", 0.9)
    return a.svg()


def sprites():
    out = []
    for chest in CHESTS:
        out.append((chest + "_base", base(chest)))
        out.append((chest + "_lid", lid(chest)))
    return out
