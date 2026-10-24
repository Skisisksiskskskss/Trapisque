"""
The dice skins (Shared/Meta/Cosmetics, category "dice"), drawn like the rest of the art:
lit from the upper left, outlined in a dark shade of each part's own colour, a soft
shadow under them. tools/art.py calls sprites().

A die is two sprites. "dice/<skin>" is the die without its pips on a 100 x 100 canvas:
its face (the top, seen from above: x 8 to 92, y 4.2 to 88.2) over the side facing you,
which shows as a band below it, and its shadow; the same layout as the code-drawn die it
replaces (CosmeticArt.die), so the pips go in the same places. "dice/<skin>_pip" is one
pip, a dimple in the face filling its canvas, which the game puts on the face for each
spot of the value it shows (PawnPatterns.pips): so one die face serves all six numbers.

Each skin's colours are its look in Cosmetics.lua (face, face2, pip, edge); `material`
is how its surface is drawn.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from badge import poly, rrect, smooth, star  # noqa: E402
from props import INK, Art, circ, ell, mix  # noqa: E402

PX = 128  # the die's canvas, pixels
PIP_PX = 40  # a pip's canvas
UNITS = 1.1  # sets the outline: the die's line about as thick as the pieces'

# the face and the side under it (CosmeticArt.die: face 0.84 at y 0.462, side 0.924 at y 0.538)
FACE = (8.0, 4.2, 84.0, 84.0, 17.5)  # x, y, w, h, corner radius
SIDE = (3.8, 7.6, 92.4, 91.0, 20.5)

# skin: face, face2, pip, edge, material (the colours match Cosmetics.lua)
SKINS = {
    "ivory": ("#FFFDF5", "#EDE6D3", "#22223B", "#C9BFA5", "ivory"),
    "charcoal": ("#3D405B", "#22223B", "#F4F1DE", "#121420", "matte"),
    "sky": ("#A2D2FF", "#74B3F0", "#FFFFFF", "#4D8BD1", "gloss"),
    "peach": ("#FFD6BA", "#FFB38A", "#7F3C1D", "#E08E5F", "matte"),
    "ruby": ("#E5383B", "#A4161A", "#FFFFFF", "#660708", "gem"),
    "jade": ("#52B788", "#2D6A4F", "#F1FAEE", "#1B4332", "jade"),
    "bone": ("#EDE0D4", "#B08968", "#3E2723", "#7F5539", "bone"),
    "neon": ("#0B0B12", "#1A1A2E", "#39FF14", "#39FF14", "neon"),
    "frost": ("#E0FBFC", "#98C1D9", "#3D5A80", "#FFFFFF", "frost"),
    "gold": ("#FFE066", "#D4A017", "#5C3D00", "#FFF3B0", "metal"),
    "doubloon": ("#F5B700", "#C98F00", "#1C1A24", "#FFE7A3", "doubloon"),
    "cosmic": ("#240046", "#7B2CBF", "#FFFFFF", "#E0AAFF", "cosmic"),
}


def face_path(inset=0.0):
    x, y, w, h, r = FACE
    return rrect(x + inset, y + inset, w - 2 * inset, h - 2 * inset, max(1.0, r - inset))


def side_path():
    x, y, w, h, r = SIDE
    return rrect(x, y, w, h, r)


def linear(a, stops, x1=0.15, y1=0.0, x2=0.85, y2=1.0):
    gid = a._id("dl")
    st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    a.defs.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
    return f"url(#{gid})"


def radial(a, stops, cx=0.35, cy=0.3, r=0.8):
    gid = a._id("dr")
    st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    a.defs.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">{st}</radialGradient>')
    return f"url(#{gid})"


def paint(a, d, fill, stroke=None, width=None, opacity=1.0):
    st = f' stroke="{stroke}" stroke-width="{width or a.ow:.2f}" stroke-linejoin="round"' if stroke else ""
    op = f' fill-opacity="{opacity}"' if opacity < 1 else ""
    a.parts.append(f'<path d="{d}" fill="{fill}"{op}{st}/>')


def die(skin):
    face, face2, pip, edge, material = SKINS[skin]
    rng = random.Random(skin)
    a = Art(PX, UNITS)
    line = mix(face2, INK, 0.62)
    if material == "neon":
        line = mix(edge, INK, 0.45)
    # its shadow on the table, and for the neon die its glow
    a.shadow(52, 96.5, 46, 6, 0.34)
    if material == "neon":
        a.glow(50, 52, 58, 58, edge, 0.32)
    # the side facing you: lit along its top, darker toward the table
    side_top = mix(face2, "#000000", 0.12)
    side_bottom = mix(face2, "#000000", 0.42)
    if material in ("gem", "frost"):
        side_bottom = mix(face2, "#000000", 0.3)
    paint(a, side_path(), linear(a, [(0, side_top, 1), (0.55, mix(face2, "#000000", 0.25), 1), (1, side_bottom, 1)], 0.5, 0.0, 0.5, 1.0),
          line, a.ow)
    # a soft sheen along the side's left (the light comes from the upper left)
    a.group(clip=side_path())
    a.fill(rrect(5.5, 60, 20, 37, 9), "#FFFFFF", 0.1)
    a.end()
    # the face
    if material == "metal" or material == "doubloon":
        fill = linear(a, [(0, mix(face, "#FFFFFF", 0.55), 1), (0.28, face, 1), (0.52, face2, 1), (0.7, mix(face, "#FFFFFF", 0.25), 1), (1, face2, 1)])
    elif material == "cosmic":
        fill = linear(a, [(0, face2, 1), (0.55, mix(face, face2, 0.4), 1), (1, face, 1)], 0.0, 0.0, 1.0, 1.0)
    elif material == "neon":
        fill = linear(a, [(0, face2, 1), (1, face, 1)])
    else:
        fill = linear(a, [(0, mix(face, "#FFFFFF", 0.35), 1), (0.5, face, 1), (1, face2, 1)])
    paint(a, face_path(), fill, line, a.ow)
    a.group(clip=face_path())
    surface(a, material, face, face2, edge, rng)
    a.end()
    # the bevel: a light lip round the face's upper left, a shade round its lower right
    x, y, w, h, r = FACE
    a.line(f"M {x + 3} {y + h - r} L {x + 3} {y + r} A {r - 3} {r - 3} 0 0 1 {x + r} {y + 3} L {x + w - r} {y + 3}",
           "#FFFFFF", 2.4, 0.5 if material not in ("neon", "cosmic", "matte") else 0.22)
    a.line(f"M {x + w - 3} {y + r} L {x + w - 3} {y + h - r} A {r - 3} {r - 3} 0 0 1 {x + w - r} {y + h - 3} L {x + r} {y + h - 3}",
           "#000000", 2.2, 0.12 if material != "neon" else 0.0)
    # the gloss on the face's upper left
    gloss = {"matte": 0.16, "ivory": 0.3, "bone": 0.18, "neon": 0.1, "metal": 0.45, "doubloon": 0.35, "cosmic": 0.16}.get(material, 0.4)
    a.group(clip=face_path())
    a.parts.append(f'<ellipse cx="33" cy="22" rx="24" ry="12" transform="rotate(-24 33 22)" fill="#FFFFFF" fill-opacity="{gloss}"/>')
    a.end()
    if material == "neon":
        # the glowing rim
        a.line(face_path(2.4), edge, 2.2, 0.95)
        a.line(face_path(2.4), "#FFFFFF", 0.8, 0.6)
    if material in ("metal", "doubloon", "gem", "frost"):
        # a glint on the corner
        a.fill(star(19, 15, 6.5, 1.6, 4, -90), "#FFFFFF", 0.95)
    return a.svg()


def surface(a, material, face, face2, edge, rng):
    """What the face is made of, drawn inside it (clipped to it)."""
    x, y, w, h, _ = FACE
    if material == "ivory":
        # faint grain across it
        for k in range(5):
            yy = y + 14 + k * 16 + rng.uniform(-3, 3)
            a.line(smooth([(x - 2, yy), (x + 30, yy + rng.uniform(-3, 3)), (x + 60, yy + rng.uniform(-3, 3)), (x + w + 2, yy + rng.uniform(-2, 2))]),
                   mix(face2, "#B9A98A", 0.5), 1.1, 0.35)
    elif material == "bone":
        for _ in range(26):
            cx, cy = rng.uniform(x + 4, x + w - 4), rng.uniform(y + 4, y + h - 4)
            a.fill(circ(cx, cy, rng.uniform(0.6, 1.5)), mix(face2, "#3E2723", 0.4), rng.uniform(0.25, 0.5))
        a.line(smooth([(x + w - 12, y - 2), (x + w - 20, y + 14), (x + w - 16, y + 24), (x + w - 26, y + 36)]), mix(face2, INK, 0.4), 1.1, 0.55)
        a.line(smooth([(x - 2, y + h - 22), (x + 10, y + h - 26), (x + 16, y + h - 18)]), mix(face2, INK, 0.4), 1.0, 0.5)
    elif material == "jade":
        for k in range(4):
            y0 = y + 6 + k * 22 + rng.uniform(-4, 4)
            pts = [(x - 4, y0)]
            for j in range(1, 5):
                pts.append((x + j * w / 4, y0 + rng.uniform(-9, 9)))
            col = mix(face, "#FFFFFF", 0.45) if k % 2 == 0 else mix(face2, "#000000", 0.25)
            a.line(smooth(pts), col, rng.uniform(1.4, 2.6), 0.42)
    elif material == "gem":
        # facets: the light breaking up inside it
        cx, cy = x + w / 2, y + h / 2
        a.fill(poly([(x, y), (cx, cy - 8), (x + w, y)]), "#FFFFFF", 0.12)
        a.fill(poly([(x, y), (cx - 8, cy), (x, y + h)]), "#FFFFFF", 0.07)
        a.fill(poly([(x + w, y + h), (cx + 8, cy), (x + w, y)]), "#000000", 0.12)
        a.fill(poly([(x + w, y + h), (cx, cy + 8), (x, y + h)]), "#000000", 0.18)
        a.parts.append(f'<rect x="{cx - 20}" y="{cy - 20}" width="40" height="40" rx="8" fill="{radial(a, [(0, mix(face, "#FFFFFF", 0.5), 0.55), (1, face, 0)], 0.5, 0.5, 0.6)}"/>')
    elif material == "neon":
        # a faint grid, like a screen
        for k in range(1, 6):
            a.line(f"M {x + k * w / 6} {y} L {x + k * w / 6} {y + h}", edge, 0.6, 0.08)
            a.line(f"M {x} {y + k * h / 6} L {x + w} {y + k * h / 6}", edge, 0.6, 0.08)
    elif material == "frost":
        # frost creeping in from the corners
        for (cx, cy, turn) in ((x + 4, y + h - 4, -45), (x + w - 4, y + 6, 135), (x + w - 6, y + h - 6, -135)):
            for k in range(3):
                ang = math.radians(turn + (k - 1) * 28)
                length = rng.uniform(14, 22)
                ex, ey = cx + math.cos(ang) * length, cy + math.sin(ang) * length
                a.line(f"M {cx:.1f} {cy:.1f} L {ex:.1f} {ey:.1f}", "#FFFFFF", 1.3, 0.75)
                for t in (0.45, 0.75):
                    bx, by = cx + (ex - cx) * t, cy + (ey - cy) * t
                    for side in (-1, 1):
                        b = ang + side * math.radians(42)
                        a.line(f"M {bx:.1f} {by:.1f} L {bx + math.cos(b) * 5:.1f} {by + math.sin(b) * 5:.1f}", "#FFFFFF", 1.0, 0.65)
        a.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{radial(a, [(0, "#FFFFFF", 0.35), (1, "#FFFFFF", 0)], 0.3, 0.25, 0.7)}"/>')
    elif material == "metal":
        # brushed bands
        for k in range(7):
            yy = y + 6 + k * 12
            a.line(f"M {x} {yy + 4} L {x + w} {yy - 4}", "#FFFFFF" if k % 2 else mix(face2, "#000000", 0.2), 1.0, 0.18)
    elif material == "doubloon":
        # stamped like a coin: a beaded ring inside the edge
        n = 28
        for k in range(n):
            t = k / n
            # walk the rounded square's inset outline
            px_, py_ = square_point(t, 6.5)
            a.fill(circ(px_, py_, 1.35), mix(face2, "#5C3D00", 0.35), 0.75)
            a.fill(circ(px_ - 0.35, py_ - 0.4, 0.6), "#FFF3B0", 0.7)
    elif material == "cosmic":
        # nebula clouds and stars
        for cx, cy, rx, ry, col, op in ((34, 62, 30, 20, "#FF5FA2", 0.35), (66, 30, 26, 18, "#4FC3FF", 0.3), (58, 66, 20, 14, "#E0AAFF", 0.3)):
            a.parts.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{radial(a, [(0, col, op), (1, col, 0)], 0.5, 0.5, 0.5)}"/>')
        for _ in range(16):
            cx, cy = rng.uniform(x + 5, x + w - 5), rng.uniform(y + 5, y + h - 5)
            a.fill(circ(cx, cy, rng.uniform(0.5, 1.2)), "#FFFFFF", rng.uniform(0.55, 0.95))
        for cx, cy, r in ((x + 14, y + 66, 4.5), (x + 70, y + 14, 3.5)):
            a.fill(star(cx, cy, r, r * 0.25, 4, -90), "#FFFFFF", 0.9)
    elif material == "gloss":
        a.parts.append(f'<rect x="{x}" y="{y + h * 0.55}" width="{w}" height="{h * 0.45}" fill="{linear(a, [(0, "#FFFFFF", 0), (1, "#FFFFFF", 0.14)], 0.5, 0, 0.5, 1)}"/>')


def square_point(t, inset):
    """A point `t` (0 to 1) of the way round the face's outline, `inset` inside it."""
    x, y, w, h, _ = FACE
    x0, y0, x1, y1 = x + inset, y + inset, x + w - inset, y + h - inset
    per = 2 * (x1 - x0) + 2 * (y1 - y0)
    d = t * per
    for (ax, ay, bx, by) in ((x0, y0, x1, y0), (x1, y0, x1, y1), (x1, y1, x0, y1), (x0, y1, x0, y0)):
        seg = abs(bx - ax) + abs(by - ay)
        if d <= seg:
            k = d / seg
            return ax + (bx - ax) * k, ay + (by - ay) * k
        d -= seg
    return x0, y0


def pip(skin):
    """A pip: a dimple in the face, painted. Lit from the upper left, so its upper left
    inside is in shade and its lower right inside catches the light."""
    face, face2, color, edge, material = SKINS[skin]
    a = Art(PIP_PX, 1.0)
    r = 44
    if material == "neon":
        a.glow(50, 50, 50, 50, color, 0.55)
        paint(a, circ(50, 50, r * 0.86), radial(a, [(0, "#FFFFFF", 1), (0.45, color, 1), (1, mix(color, "#000000", 0.2), 1)], 0.5, 0.5, 0.6))
        return a.svg()
    if material == "cosmic":
        a.glow(50, 50, 50, 50, "#E0AAFF", 0.5)
    dark = mix(color, "#000000", 0.45)
    light = mix(color, "#FFFFFF", 0.4) if color.upper() not in ("#FFFFFF",) else "#FFFFFF"
    base = color if color.upper() != "#FFFFFF" else "#F2F0F8"
    # the lip round it, catching the light on its lower right
    paint(a, circ(50, 50, r), linear(a, [(0, mix(face2, "#000000", 0.35), 1), (1, mix(face, "#FFFFFF", 0.6), 1)], 0.2, 0.15, 0.8, 0.9))
    # the dimple: shaded toward the upper left
    paint(a, circ(50, 50, r - 5), radial(a, [(0, light, 1), (0.55, base, 1), (1, dark, 1)], 0.62, 0.66, 0.72))
    return a.svg()


def sprites():
    out = []
    for skin in SKINS:
        out.append((skin, die(skin)))
        out.append((skin + "_pip", pip(skin)))
    return out
