"""
The playing pieces: one shape for every player, like a set of chess pieces, with the
character's emblem on top, in the character's colour, in every finish (the cosmetic
players collect). tools/art.py calls sprites() and renders what it returns.

Drawn on a 128 x 160 canvas, lit from the upper left; the piece stands on the bottom
middle. Each finish is a recipe for the same parts (base, body, collar, emblem).

The plinths are the stands mastery earns (BaseArt): a low disc in the character's
colour (gold at mastery 10), on a 128 x 48 canvas the piece's canvas width, its top
the piece stands on.
"""

import math
import random

# the characters' colours (Theme.Character) and their emblems
CHARACTERS = {
    "mage": "#2F7FD0",
    "trapper": "#EE8A2E",
    "fire_starter": "#D64545",
    "naturalist": "#3E9F5B",
    "warper": "#D35A9C",
    "overseer": "#E7B023",
    "gambler": "#22A094",
    "cannoneer": "#93633A",
}

INK = "#2A2830"
GOLD = ("#F9E08B", "#E2B53D", "#A8781C")  # light, mid, dark


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def _hex(c):
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    ca, cb = _rgb(a), _rgb(b)
    return _hex(tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3)))


# ---------------------------------------------------------------------------
# the shape (shared by every piece)
# ---------------------------------------------------------------------------

# (its foot is the front half of an ellipse seen from the same angle as the base's top)
BODY = "M 27 139 C 31 119, 46 105, 50 93 C 52 87, 52.5 83, 52.5 79 L 75.5 79 C 75.5 83, 76 87, 78 93 C 82 105, 97 119, 101 139 A 37 9 0 0 1 27 139 Z"
BASE_SIDE = "M 19 140 L 19 146 A 45 11 0 0 0 109 146 L 109 140 Z"
BASE_TOP = (64, 140, 45, 11)  # an ellipse: cx, cy, rx, ry
COLLAR_TOP = (64, 78, 21, 5.5)
COLLAR_SIDE = "M 43 78 L 43 81 A 21 5.5 0 0 0 85 81 L 85 78 Z"

# the emblems: paths in the same canvas, sitting on the collar (y about 76)
EMBLEMS = {
    "mage": {
        "parts": [
            # the hat's cone, its tip flopping to the right, then the brim in front
            ("body", "M 44 73 C 49 58, 55 40, 59 24 C 61 15, 70 11, 78 15 C 72 18, 68 23, 68 31 C 69 45, 76 60, 84 73 Z"),
            ("body", "M 36 75 C 36 70, 50 67, 64 67 C 78 67, 92 70, 92 75 C 92 80, 78 82, 64 82 C 50 82, 36 80, 36 75 Z"),
        ],
        "decal": [("light", "M 62 44 L 64.2 48.6 L 69.2 49.3 L 65.6 52.8 L 66.5 57.8 L 62 55.4 L 57.5 57.8 L 58.4 52.8 L 54.8 49.3 L 59.8 48.6 Z")],
    },
    "trapper": {
        "parts": [
            # a sprung bear trap from the front: two jaws open to the sky round a plate
            ("body", "M 35 28 L 43 28 C 43 50, 52 67, 64 67 C 76 67, 85 50, 85 28 L 93 28 C 93 56, 81 76, 64 76 C 47 76, 35 56, 35 28 Z"),
            ("dark", "M 53 70 A 11 3.6 0 1 1 75 70 A 11 3.6 0 1 1 53 70 Z"),
        ],
        "decal": [
            ("teeth", "M 43 33 L 50 36 L 43.4 40 Z M 44.2 45 L 51.4 46.4 L 45.8 51.4 Z M 47.8 56 L 54.6 55.6 L 50.8 61.6 Z"
             " M 85 33 L 78 36 L 84.6 40 Z M 83.8 45 L 76.6 46.4 L 82.2 51.4 Z M 80.2 56 L 73.4 55.6 L 77.2 61.6 Z"),
        ],
    },
    "fire_starter": {
        "parts": [
            ("body", "M 63 13 C 71 26, 86 35, 85 54 C 84 67, 75 76, 64 76 C 53 76, 43 68, 43 55 C 43 45, 49 39, 53 31 C 54 39, 57 43, 61 44 C 59 34, 59 24, 63 13 Z"),
        ],
        "decal": [("light", "M 64 40 C 69 48, 75 54, 74 62 C 73 69, 69 72, 64 72 C 58 72, 54 68, 54 62 C 54 56, 58 54, 60 49 C 61 53, 62 55, 64 55 C 63 50, 62 45, 64 40 Z")],
    },
    "naturalist": {
        "parts": [
            ("body", "M 61.5 77 L 61.5 56 C 61.5 52, 66.5 52, 66.5 56 L 66.5 77 Z"),
            ("body", "M 63 58 C 54 47, 40 45, 32 52 C 40 62, 54 65, 63 58 Z"),
            ("body", "M 65 55 C 66 38, 79 24, 97 22 C 96 39, 84 54, 65 55 Z"),
        ],
        "decal": [("vein", "M 60 57 C 52 54, 44 52, 37 52 M 67 52 C 74 44, 82 36, 92 27")],
    },
    "warper": {
        "parts": [("body", "M 64 26 A 24 24 0 1 1 63.9 26 Z")],
        # a spiral groove from the middle out
        "decal": [("groove", "M 64 50 a 3 3 0 1 1 6 0 a 6 6 0 1 1 -12 0 a 9 9 0 1 1 18 0 a 12 12 0 1 1 -24 0 a 15 15 0 0 1 15 -15")],
    },
    "overseer": {
        "parts": [
            # a spyglass resting on the collar, pointing up to the right
            ("body", "M 46.5 73.5 L 54.5 64.5 L 61.5 70.5 L 53.5 79.5 Z"),
            ("body", "M 53 63 L 64 50.5 L 73.5 58.8 L 62.5 71.3 Z"),
            ("body", "M 62 49 L 75.5 33.5 L 88.5 44.9 L 75 60.4 Z"),
            ("body", "M 73.5 31.5 L 77 27.5 L 92 40.7 L 88.5 44.7 Z"),
        ],
        "decal": [("band", "M 63.2 50.2 L 73.7 59.4 M 54 64 L 62 71")],
    },
    "gambler": {
        "parts": [
            ("top", "M 64 22 L 87 34 L 64 46 L 41 34 Z"),
            ("left", "M 41 34 L 64 46 L 64 74 L 41 62 Z"),
            ("right", "M 87 34 L 64 46 L 64 74 L 87 62 Z"),
        ],
        "pips": [(64, 34, 3.6), (48, 46, 3.0), (57, 62, 3.0), (71, 50, 3.0), (75.5, 56, 3.0), (80, 62, 3.0)],
    },
    "cannoneer": {
        "parts": [
            ("body", "M 64 30 A 24 24 0 1 1 63.9 30 Z"),
            ("dark", "M 69 25 L 79 28.5 L 76.5 36 L 66.5 32.5 Z"),
        ],
        "fuse": "M 77 28 C 81 20, 88 19, 90 13",
        "spark": (91, 12),
    },
}


# ---------------------------------------------------------------------------
# finishes
# ---------------------------------------------------------------------------


def palette(color, finish):
    """light / mid / dark fills and the outline for one finish."""
    c = color
    if finish == "paint":
        return mix(c, "#FFFFFF", 0.38), c, mix(c, "#000000", 0.34), mix(c, INK, 0.62)
    if finish == "oak":
        wood = mix(c, "#A8743F", 0.42)
        return mix(wood, "#FFF3DC", 0.3), wood, mix(wood, "#2B1A0E", 0.38), mix(wood, INK, 0.62)
    if finish == "clay":
        clay = mix(c, "#C8B6A2", 0.32)
        return mix(clay, "#FFFFFF", 0.22), clay, mix(clay, "#3A2A20", 0.28), mix(clay, INK, 0.55)
    if finish == "pearl":
        p = mix(c, "#FFFFFF", 0.42)
        return mix(p, "#FFFFFF", 0.55), p, mix(p, c, 0.55), mix(c, INK, 0.5)
    if finish == "marble":
        m = mix(c, "#FFFFFF", 0.62)
        return mix(m, "#FFFFFF", 0.6), m, mix(m, c, 0.45), mix(c, INK, 0.55)
    if finish == "glass":
        return mix(c, "#FFFFFF", 0.55), c, mix(c, "#000000", 0.3), mix(c, INK, 0.55)
    if finish == "porcelain":
        return "#FFFFFF", mix(c, "#FFFFFF", 0.9), mix(c, "#FFFFFF", 0.72), mix(c, INK, 0.45)
    if finish == "metallic":
        return mix(c, "#FFFFFF", 0.55), c, mix(c, "#000000", 0.55), mix(c, INK, 0.7)
    if finish == "obsidian":
        o = mix(c, "#141218", 0.78)
        return mix(o, c, 0.45), o, mix(o, "#000000", 0.45), mix(o, "#000000", 0.4)
    if finish == "gold":
        return GOLD[0], GOLD[1], GOLD[2], "#6E4B10"
    if finish == "crystal":
        k = mix(c, "#FFFFFF", 0.35)
        return mix(k, "#FFFFFF", 0.6), k, mix(c, "#000000", 0.15), mix(c, INK, 0.5)
    if finish == "glow":
        b = mix(c, "#2B2422", 0.82)
        return mix(b, "#6E625C", 0.4), b, mix(b, "#000000", 0.4), "#141012"
    if finish == "royal":
        v = mix(c, "#2A1638", 0.25)
        return mix(v, "#FFFFFF", 0.22), v, mix(v, "#000000", 0.45), mix(v, INK, 0.6)
    if finish == "admiralty":
        return mix(c, "#FFFFFF", 0.34), c, mix(c, "#0E1A2C", 0.45), mix(c, INK, 0.65)
    raise ValueError(finish)


FINISHES = [
    "paint", "oak", "clay", "pearl", "marble", "glass", "porcelain",
    "metallic", "obsidian", "gold", "crystal", "glow", "royal", "admiralty",
]

GLOSS = {"paint": 0.42, "oak": 0.14, "clay": 0.0, "pearl": 0.5, "marble": 0.4, "glass": 0.7,
         "porcelain": 0.55, "metallic": 0.65, "obsidian": 0.55, "gold": 0.6, "crystal": 0.65,
         "glow": 0.18, "royal": 0.22, "admiralty": 0.48}


class Svg:
    def __init__(self, w=128, h=160):
        self.w, self.h = w, h
        self.defs = []
        self.body = []
        self.n = 0

    def gid(self, prefix):
        self.n += 1
        return f"{prefix}{self.n}"

    def linear(self, stops, x1=0, y1=0, x2=1, y2=0, units="objectBoundingBox"):
        gid = self.gid("g")
        s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.defs.append(f'<linearGradient id="{gid}" gradientUnits="{units}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>')
        return f"url(#{gid})"

    def radial(self, stops, cx=0.5, cy=0.5, r=0.5, fx=None, fy=None):
        gid = self.gid("r")
        s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        f = f' fx="{fx}" fy="{fy}"' if fx is not None else ""
        self.defs.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}"{f}>{s}</radialGradient>')
        return f"url(#{gid})"

    def clip(self, *paths):
        cid = self.gid("c")
        self.defs.append(f'<clipPath id="{cid}">' + "".join(f'<path d="{d}"/>' for d in paths) + "</clipPath>")
        return f"url(#{cid})"

    def add(self, s):
        self.body.append(s)

    def text(self):
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}">'
            + "<defs>" + "".join(self.defs) + "</defs>" + "".join(self.body) + "</svg>"
        )


def ellipse_path(cx, cy, rx, ry):
    return f"M {cx - rx} {cy} A {rx} {ry} 0 1 0 {cx + rx} {cy} A {rx} {ry} 0 1 0 {cx - rx} {cy} Z"


def texture(svg, finish, color, area, light, mid, dark):
    """The finish's surface detail inside `area` (a path): grain, veins, flakes..."""
    clip = svg.clip(area)
    out = []
    if finish == "oak":
        for i, y in enumerate(range(84, 146, 7)):
            wob = 3 if i % 2 else -3
            out.append(f'<path d="M 10 {y} C 40 {y + wob}, 70 {y - wob}, 118 {y + wob}" fill="none" stroke="{dark}" stroke-opacity="0.28" stroke-width="1.3"/>')
        out.append(f'<path d="M 70 98 C 74 104, 74 112, 70 118" fill="none" stroke="{dark}" stroke-opacity="0.35" stroke-width="1.5"/>')
    elif finish == "clay":
        rnd = random.Random(7)
        for _ in range(60):
            x, y = rnd.uniform(10, 118), rnd.uniform(10, 150)
            out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rnd.uniform(0.5, 1.1):.2f}" fill="{dark}" fill-opacity="0.25"/>')
    elif finish == "marble":
        vein = mix(color, INK, 0.25)
        for d in ("M 30 150 C 44 128, 40 112, 58 96 C 66 88, 62 72, 74 58",
                  "M 96 150 C 88 132, 98 118, 84 104 C 76 96, 84 84, 78 70",
                  "M 50 120 C 58 118, 64 122, 72 116"):
            out.append(f'<path d="{d}" fill="none" stroke="{vein}" stroke-opacity="0.5" stroke-width="1.2"/>')
    elif finish == "porcelain":
        out.append(f'<path d="M 10 124 L 118 124 L 118 129 L 10 129 Z" fill="{color}" fill-opacity="0.9"/>')
        for x in range(36, 100, 9):
            out.append(f'<circle cx="{x}" cy="114" r="1.8" fill="{color}" fill-opacity="0.85"/>')
        out.append(f'<path d="M 10 99 L 118 99 L 118 101.5 L 10 101.5 Z" fill="{color}" fill-opacity="0.85"/>')
    elif finish == "metallic":
        rnd = random.Random(11)
        for _ in range(70):
            x, y = rnd.uniform(10, 118), rnd.uniform(10, 150)
            out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="0.7" fill="#FFFFFF" fill-opacity="{rnd.uniform(0.15, 0.5):.2f}"/>')
    elif finish == "crystal":
        for d, a in (("M 64 79 L 52 139 L 27 139 Z", 0.18), ("M 64 79 L 76 139 L 101 139 Z", -0.22),
                     ("M 64 79 L 52 139 L 76 139 Z", 0.08)):
            col = "#FFFFFF" if a > 0 else "#000000"
            out.append(f'<path d="{d}" fill="{col}" fill-opacity="{abs(a)}"/>')
    elif finish == "glow":
        hot = mix(color, "#FFFFFF", 0.35)
        for d in ("M 40 140 L 46 124 L 42 112 L 52 98", "M 88 140 L 82 128 L 88 116 L 78 100 L 80 88",
                  "M 60 140 L 64 130 L 60 120"):
            out.append(f'<path d="{d}" fill="none" stroke="{hot}" stroke-opacity="0.35" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>')
            out.append(f'<path d="{d}" fill="none" stroke="{hot}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>')
    elif finish == "royal":
        out.append(f'<path d="M 10 132 L 118 132 L 118 136 L 10 136 Z" fill="{GOLD[1]}"/>')
    elif finish == "admiralty":
        for y in (118, 124):
            out.append(f'<path d="M 10 {y} L 118 {y} L 118 {y + 2.4} L 10 {y + 2.4} Z" fill="{GOLD[1]}"/>')
    if out:
        svg.add(f'<g clip-path="{clip}">' + "".join(out) + "</g>")


def shaded(svg, d, light, mid, dark, outline, opacity=1.0, horizontal=True):
    fill = svg.linear([(0, light, opacity), (0.42, mid, opacity), (1, dark, opacity)], 0, 0, 1, 0.15) if horizontal else svg.linear(
        [(0, light, opacity), (0.5, mid, opacity), (1, dark, opacity)], 0, 0, 0, 1)
    svg.add(f'<path d="{d}" fill="{fill}" stroke="{outline}" stroke-width="2.2" stroke-linejoin="round"/>')


def piece(character, finish):
    color = CHARACTERS[character]
    light, mid, dark, outline = palette(color, finish)
    glass = finish == "glass"
    alpha = 0.5 if glass else 1.0
    svg = Svg()

    # the base: its rim, then its top
    shaded(svg, BASE_SIDE, mix(mid, dark, 0.35), dark, mix(dark, "#000000", 0.3), outline, alpha)
    top = ellipse_path(*BASE_TOP)
    svg.add(f'<path d="{top}" fill="{svg.radial([(0, light, alpha), (0.6, mid, alpha), (1, dark, alpha)], 0.42, 0.3, 0.75)}" stroke="{outline}" stroke-width="2.2"/>')

    # the body, its texture, its shine
    shaded(svg, BODY, light, mid, dark, outline, alpha)
    texture(svg, finish, color, BODY, light, mid, dark)
    gloss = GLOSS[finish]
    if gloss > 0:
        svg.add(f'<path d="M 38 134 C 40 120, 50 108, 55 96 C 56 92, 56.5 88, 56.5 84" fill="none" stroke="#FFFFFF" stroke-opacity="{gloss}" stroke-width="4" stroke-linecap="round"/>')
    if finish == "obsidian":
        svg.add(f'<path d="{BODY}" fill="none" stroke="{mix(color, "#FFFFFF", 0.2)}" stroke-opacity="0.55" stroke-width="1.6"/>')
    if glass:
        # the light caught inside the glass: a bright right edge and a second glint
        svg.add('<path d="M 92 136 C 88 122, 78 108, 74 96" fill="none" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="2.2" stroke-linecap="round"/>')
        svg.add('<path d="M 46 128 C 48 122, 51 117, 54 112" fill="none" stroke="#FFFFFF" stroke-opacity="0.8" stroke-width="2.4" stroke-linecap="round"/>')

    # the collar
    shaded(svg, COLLAR_SIDE, mid, dark, mix(dark, "#000000", 0.3), outline, alpha)
    trim = GOLD if finish in ("royal", "admiralty", "gold") else None
    ctop = ellipse_path(*COLLAR_TOP)
    if trim:
        svg.add(f'<path d="{ctop}" fill="{svg.linear([(0, trim[0], 1), (1, trim[2], 1)])}" stroke="#6E4B10" stroke-width="2"/>')
    else:
        svg.add(f'<path d="{ctop}" fill="{svg.radial([(0, light, alpha), (1, mid, alpha)], 0.4, 0.3, 0.8)}" stroke="{outline}" stroke-width="2"/>')

    # the emblem (enamelled in the player's colour on a gold piece)
    e = EMBLEMS[character]
    el, em, ed, eo = (palette(color, "paint") if finish == "gold" else (light, mid, dark, outline))
    for kind, d in e["parts"]:
        if kind == "top":
            svg.add(f'<path d="{d}" fill="{el}" fill-opacity="{alpha}" stroke="{eo}" stroke-width="2.2" stroke-linejoin="round"/>')
        elif kind == "left":
            svg.add(f'<path d="{d}" fill="{em}" fill-opacity="{alpha}" stroke="{eo}" stroke-width="2.2" stroke-linejoin="round"/>')
        elif kind == "right":
            svg.add(f'<path d="{d}" fill="{ed}" fill-opacity="{alpha}" stroke="{eo}" stroke-width="2.2" stroke-linejoin="round"/>')
        elif kind == "dark":
            svg.add(f'<path d="{d}" fill="{mix(ed, "#000000", 0.25)}" stroke="{eo}" stroke-width="2" stroke-linejoin="round"/>')
        else:
            fill = svg.linear([(0, el, alpha), (0.45, em, alpha), (1, ed, alpha)], 0, 0, 1, 0.25)
            svg.add(f'<path d="{d}" fill="{fill}" stroke="{eo}" stroke-width="2.2" stroke-linejoin="round"/>')
    for kind, d in e.get("decal", []):
        if kind == "light":
            svg.add(f'<path d="{d}" fill="{mix(el, "#FFFFFF", 0.5)}" fill-opacity="0.9"/>')
        elif kind == "teeth":
            svg.add(f'<path d="{d}" fill="{mix(el, "#FFFFFF", 0.65)}" stroke="{eo}" stroke-width="1.2" stroke-linejoin="round"/>')
        elif kind == "vein":
            svg.add(f'<path d="{d}" fill="none" stroke="{eo}" stroke-opacity="0.7" stroke-width="1.4" stroke-linecap="round"/>')
        elif kind == "groove":
            svg.add(f'<path d="{d}" fill="none" stroke="{mix(el, "#FFFFFF", 0.55)}" stroke-opacity="0.95" stroke-width="2.6" stroke-linecap="round"/>')
        elif kind == "band":
            svg.add(f'<path d="{d}" fill="none" stroke="{GOLD[1] if finish != "gold" else eo}" stroke-width="2.4" stroke-linecap="round"/>')
    for x, y, r in e.get("pips", []):
        svg.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#FFF9EF" stroke="{eo}" stroke-width="0.8"/>')
    if "fuse" in e:
        svg.add(f'<path d="{e["fuse"]}" fill="none" stroke="#5A4632" stroke-width="2.6" stroke-linecap="round"/>')
        sx, sy = e["spark"]
        pts = [(sx + rr * math.cos(math.pi * i / 4), sy + rr * math.sin(math.pi * i / 4)) for i, rr in enumerate([6.5, 2.6] * 4)]
        star = " ".join(f"{'M' if i == 0 else 'L'} {x:.1f} {y:.1f}" for i, (x, y) in enumerate(pts)) + " Z"
        svg.add(f'<path d="{star}" fill="#FFC23D" stroke="#C26B12" stroke-width="1.2" stroke-linejoin="round"/>')
    # a soft shine on the emblem's upper left (only where the emblem is)
    if gloss > 0.3:
        clip = svg.clip(*(d for kind, d in e["parts"] if kind != "dark"))
        svg.add(f'<g clip-path="{clip}"><ellipse cx="55" cy="40" rx="5" ry="9" transform="rotate(25 55 40)" fill="#FFFFFF" fill-opacity="{gloss * 0.45:.2f}"/></g>')
    return svg.text()


def plinth(character, gold=False):
    """The stand mastery earns, in the character's colour (or gold)."""
    if gold:
        light, mid, dark, outline = GOLD[0], GOLD[1], GOLD[2], "#6E4B10"
    else:
        light, mid, dark, outline = palette(CHARACTERS[character], "paint")
    svg = Svg(128, 48)
    shaded(svg, "M 5 18 L 5 28 A 59 13 0 0 0 123 28 L 123 18 Z", mix(mid, dark, 0.35), dark, mix(dark, "#000000", 0.3), outline)
    top = ellipse_path(64, 18, 59, 13)
    svg.add(f'<path d="{top}" fill="{svg.radial([(0, light, 1), (0.6, mid, 1), (1, dark, 1)], 0.42, 0.3, 0.75)}" stroke="{outline}" stroke-width="2.2"/>')
    # the ring the piece stands in
    svg.add(f'<path d="{ellipse_path(64, 18.5, 47, 10)}" fill="none" stroke="{dark}" stroke-opacity="0.45" stroke-width="1.6"/>')
    return svg.text()


def sprites():
    out = []
    for finish in FINISHES:
        for character in CHARACTERS:
            out.append((f"{finish}_{character}", piece(character, finish)))
    for character in CHARACTERS:
        out.append((f"plinth_{character}", plinth(character)))
    out.append(("plinth_gold", plinth("mage", gold=True)))
    return out
