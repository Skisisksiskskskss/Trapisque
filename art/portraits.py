"""
The eight pirates as portraits: head and shoulders, for the round portraits (cards,
the player chips, the results, character select). Same style as the pieces and the
props: smooth shapes lit from the upper left, thin outlines in a darker shade of each
part's own colour. tools/art.py calls sprites().

On a 100 x 100 canvas (rendered at 256 px): the head's middle near (50, 48), the
shoulders running off the bottom edge, so a circle cropping the canvas keeps the face
and the hat. Each pirate is a recipe: skin, hair, what's on their head and chin, their
coat, and the face they usually pull.
"""

import math

INK = "#2A2830"


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def _hex(c):
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    ca, cb = _rgb(a), _rgb(b)
    return _hex(tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3)))


def ell(cx, cy, rx, ry):
    return f"M {cx - rx} {cy} A {rx} {ry} 0 1 0 {cx + rx} {cy} A {rx} {ry} 0 1 0 {cx - rx} {cy} Z"


class Art:
    OW = 0.9  # outline width

    def __init__(self):
        self.defs = []
        self.parts = []
        self.n = 0

    def _id(self, p):
        self.n += 1
        return f"{p}{self.n}"

    def grad(self, base, light=0.25, dark=0.25, x1=0.2, y1=0.0, x2=0.8, y2=1.0):
        gid = self._id("g")
        self.defs.append(
            f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
            f'<stop offset="0" stop-color="{mix(base, "#FFFFFF", light)}"/>'
            f'<stop offset="0.55" stop-color="{base}"/>'
            f'<stop offset="1" stop-color="{mix(base, "#000000", dark)}"/></linearGradient>'
        )
        return f"url(#{gid})"

    def shape(self, d, base, light=0.25, dark=0.25, outline=None, width=None, flat=False, **g):
        fill = base if flat else self.grad(base, light, dark, **g)
        line = outline or mix(base, INK, 0.58)
        w = self.OW if width is None else width
        self.parts.append(f'<path d="{d}" fill="{fill}" stroke="{line}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"/>')

    def fill(self, d, color, opacity=1.0):
        self.parts.append(f'<path d="{d}" fill="{color}" fill-opacity="{opacity}"/>')

    def line(self, d, color, width, opacity=1.0):
        self.parts.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-opacity="{opacity}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>')

    def clip_start(self, d):
        cid = self._id("c")
        self.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
        self.parts.append(f'<g clip-path="url(#{cid})">')

    def end(self):
        self.parts.append("</g>")

    def svg(self):
        return (
            '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 100 100">'
            + "<defs>" + "".join(self.defs) + "</defs>" + "".join(self.parts) + "</svg>"
        )


# the shared figure: a head (each pirate's own width, and how pointed their chin is),
# the neck, the coat's shoulders (drawn 3.5 higher than their recipes' coordinates)
def head(w=33, chin=11.5):
    l, r = 50 - w / 2, 50 + w / 2
    return (f"M {l} 47 C {l} 35.5, {l + 7} 29.5, 50 29.5 C {r - 7} 29.5, {r} 35.5, {r} 47 "
            f"C {r} 57.5, {50 + chin} 66.5, 50 67.5 C {50 - chin} 66.5, {l} 57.5, {l} 47 Z")


NECK = "M 43.5 62 L 43.5 74 C 47 76, 53 76, 56.5 74 L 56.5 62 Z"
COAT = "M 12 100 C 13 87, 24 79, 39 76.5 C 43 79.5, 57 79.5, 61 76.5 C 76 79, 87 87, 88 100 L 88 104 L 12 104 Z"
EYE_L, EYE_R = (43.5, 48.5), (56.5, 48.5)


def figure(a, p):
    """Coat, neck, ears, head and face for pirate recipe `p` (hair and hats come after)."""
    skin = p["skin"]
    skin_d = mix(skin, "#5A2E1A", 0.28)
    line = mix(skin, INK, 0.55)
    w, chin = p.get("head", (33, 11.5))
    hd = head(w, chin)
    # the neck, then the coat and what's on it
    a.shape(NECK, skin_d, 0.1, 0.15, outline=line)
    a.parts.append('<g transform="translate(0 -3.5)">')
    a.shape(COAT, p["coat"], 0.22, 0.3)
    for kind, d, color in p.get("coat_detail", []):
        if kind == "shape":
            a.shape(d, color, 0.2, 0.25)
        else:
            a.line(d, color, 2.2)
    for kind, d, color in p.get("collar", []):
        a.shape(d, color, 0.2, 0.25)
    a.end()
    # the head
    l, r = 50 - w / 2, 50 + w / 2
    a.shape(f"M {l + 1.5} 45.5 C {l - 3} 44, {l - 4} 52.5, {l + 1} 54.5 Z", skin, 0.1, 0.2, outline=line)
    a.shape(f"M {r - 1.5} 45.5 C {r + 3} 44, {r + 4} 52.5, {r - 1} 54.5 Z", skin_d, 0.1, 0.2, outline=line)
    a.shape(hd, skin, 0.22, 0.18, outline=line)
    # a little shade down the far side of the face
    a.clip_start(hd)
    a.fill(f"M {r - 6.5} 30 C {r + 3.5} 40, {r + 3.5} 58, {r - 8.5} 70 L {r + 6} 70 L {r + 6} 30 Z", skin_d, 0.32)
    a.end()
    face(a, p, skin, skin_d, line)


def face(a, p, skin, skin_d, line):
    mood = p.get("mood", "idle")
    brow = p.get("brow", p.get("hair", "#3A2418"))
    eye = "#2A2224"
    # brows
    lift = {"cheeky": (0, -1.6), "sly": (0, -1.9), "smug": (0.4, 0.4), "happy": (-0.8, -0.8)}.get(mood, (0, 0))
    for (x, y), dy, flip in ((EYE_L, lift[0], 1), (EYE_R, lift[1], -1)):
        a.line(f"M {x - 3.6 * flip} {y - 4.6 + dy + 0.6} C {x - 1.5 * flip} {y - 6 + dy}, {x + 1.5 * flip} {y - 6 + dy}, {x + 3.4 * flip} {y - 5 + dy}", brow, 1.7)
    # eyes: dark ovals with a glint; smug ones half shut, a cheeky one winks
    for i, (x, y) in enumerate((EYE_L, EYE_R)):
        if mood == "cheeky" and i == 0:
            a.line(f"M {x - 2.4} {y + 0.2} C {x - 1} {y + 1.6}, {x + 1} {y + 1.6}, {x + 2.4} {y + 0.2}", eye, 1.2)
            continue
        a.fill(ell(x, y, 2.1, 2.9), eye)
        a.fill(ell(x - 0.7, y - 1.1, 0.7, 0.8), "#FFFFFF", 0.9)
        if mood == "smug":
            a.fill(f"M {x - 2.6} {y - 3.3} L {x + 2.6} {y - 3.3} L {x + 2.6} {y - 0.2} C {x + 1} {y + 0.4}, {x - 1} {y + 0.4}, {x - 2.6} {y - 0.2} Z", skin)
            a.line(f"M {x - 2.4} {y - 0.2} C {x - 1} {y + 0.5}, {x + 1} {y + 0.5}, {x + 2.4} {y - 0.2}", line, 0.8)
    # lines at the corners of older eyes
    if p.get("wrinkles"):
        a.line(f"M {EYE_L[0] - 4.2} {EYE_L[1] + 0.6} L {EYE_L[0] - 5.6} {EYE_L[1] + 1.6} M {EYE_R[0] + 4.2} {EYE_R[1] + 0.6} L {EYE_R[0] + 5.6} {EYE_R[1] + 1.6}", line, 0.6, 0.7)
    # the nose: a soft round one, as big (sx, sy) as theirs is
    sx, sy = p.get("nose", (1, 1))
    a.parts.append(f'<g transform="translate(50.5 52) scale({sx} {sy}) translate(-50.5 -52)">')
    a.shape("M 47.5 51 C 46 55.5, 47 58.5, 50.5 58.5 C 54 58.5, 55.5 56, 53.5 51.5 C 52 53.2, 49 53, 47.5 51 Z", p.get("nose_color", mix(skin, skin_d, 0.3)), 0.15, 0.15, outline=line, width=0.7 / max(sx, sy))
    a.end()
    if p.get("freckles"):
        for x, y in ((42.5, 54.6), (44.6, 55.8), (41.4, 56.6), (57.5, 54.6), (55.4, 55.8), (58.6, 56.6)):
            a.fill(ell(x, y, 0.45, 0.45), mix(skin_d, "#7A3A1A", 0.35), 0.8)
    if p.get("hide_mouth"):
        return
    lip = mix(skin_d, "#6E2A22", 0.45)
    if mood == "happy":
        a.shape("M 44.5 61 C 47 66.5, 54 66.5, 56.5 61 C 52.5 62, 48.5 62, 44.5 61 Z", "#5A2626", 0.0, 0.1, outline=lip, width=0.8, flat=True)
        a.fill("M 47.2 63.8 C 49 65.4, 52 65.4, 53.8 63.8 C 52 63, 49 63, 47.2 63.8 Z", "#C8645A")
    elif mood in ("cheeky", "smug", "sly"):
        a.line("M 45 61.8 C 48 62.8, 52.5 62.4, 56.2 59.6", lip, 1.2)
    else:
        a.line("M 46 61.5 C 48.5 62.8, 52 62.8, 54.5 61.5", lip, 1.2)


def braid(a, x0, y0, x1, y1, color, n=6, width=4.4):
    """A plait from (x0, y0) to (x1, y1): strands leaning left and right in turn."""
    dark = mix(color, "#000000", 0.25)
    for k in range(n):
        t = (k + 0.5) / n
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        w = width * (1 - 0.35 * t)
        tilt = 28 if k % 2 == 0 else -28
        a.parts.append(f'<g transform="translate({x:.2f} {y:.2f}) rotate({tilt})">')
        a.shape(ell(0, 0, w * 0.62, (abs(y1 - y0) / n) * 0.95), color if k % 2 == 0 else mix(color, dark, 0.35), 0.2, 0.25)
        a.end()


# ---------------------------------------------------------------------------
# the eight
# ---------------------------------------------------------------------------

GOLD = "#E2B53D"
CREAM = "#F6EEDC"
NAVY = "#2B4C7E"


def mage():
    """The crew's frost sorcerer: a crumpled hat hung with icicles, round spectacles,
    brows like snowdrifts, a nose red with cold and a forked white beard; an ice crystal
    on his staff."""
    a = Art()
    blue = "#2F7FD0"
    white, white_d = "#F4F1EA", "#C9C3B8"
    frost, frost_d = "#D8ECF7", "#8DB8D2"
    # the glow of the crystal behind his shoulder
    gid = a._id("s")
    a.defs.append(f'<radialGradient id="{gid}"><stop offset="0" stop-color="#BFE6FF" stop-opacity="0.7"/><stop offset="1" stop-color="#BFE6FF" stop-opacity="0"/></radialGradient>')
    a.parts.append(f'<ellipse cx="77" cy="58" rx="13" ry="13" fill="url(#{gid})"/>')
    p = {
        "skin": "#F2C9A0", "coat": blue, "brow": white, "mood": "idle", "hide_mouth": True,
        "head": (31, 9.5), "nose": (1.12, 1.08), "nose_color": "#EAA08C", "wrinkles": True,
        "collar": [("shape", "M 33 77 C 38 73, 44 74.5, 50 76.5 C 56 74.5, 62 73, 67 77 C 66 80, 62 81, 59 80 C 56 82, 53 82, 50 80.5 C 47 82, 44 82, 41 80 C 38 81, 34 80, 33 77 Z", white)],
    }
    figure(a, p)
    # round spectacles
    for x, y in (EYE_L, EYE_R):
        a.parts.append(f'<circle cx="{x}" cy="{y}" r="4.3" fill="#FFFFFF" fill-opacity="0.18" stroke="#8A7A5A" stroke-width="0.8"/>')
    a.line("M 47.8 48 C 49 47, 51 47, 52.2 48", "#8A7A5A", 0.8)
    # a forked beard, and a moustache curling over his mouth
    a.shape("M 37 55 C 38 64, 42 70.5, 45.5 74 C 46.5 77, 46 80, 44.5 82.5 C 47.5 81.5, 49.5 79, 50 76.5 C 50.5 79, 52.5 81.5, 55.5 82.5 "
            "C 54 80, 53.5 77, 54.5 74 C 58 70.5, 62 64, 63 55 C 60 61.5, 55.5 63.6, 50 63.6 C 44.5 63.6, 40 61.5, 37 55 Z", white, 0.1, 0.2, outline=mix(white_d, INK, 0.35))
    a.line("M 46 66 C 46.5 70, 47.5 74, 48 77 M 54 66 C 53.5 70, 52.5 74, 52 77", white_d, 0.6, 0.8)
    a.shape("M 50 58.6 C 47 57.4, 43 58, 40.5 60 C 39 61.2, 39.6 62.8, 41 62.2 C 43 61.2, 46.5 61, 50 61.4 "
            "C 53.5 61, 57 61.2, 59 62.2 C 60.4 62.8, 61 61.2, 59.5 60 C 57 58, 53 57.4, 50 58.6 Z", white, 0.1, 0.2, outline=mix(white_d, INK, 0.35))
    # a tall soft hat, crumpled over to the right, a frosty band and a snowflake pin
    a.shape("M 36 36 C 39 26, 44 15, 51 8 C 55 4, 62 3, 66 7 C 69 10, 69 15, 66 17 C 65 13.5, 62 12, 59.5 13.5 C 57 15, 58.5 26, 64 36 Z", blue, 0.3, 0.3)
    a.line("M 44 21 C 47 22.5, 51 22.5, 55 21", mix(blue, "#000000", 0.3), 0.7, 0.6)
    a.shape("M 35.5 32.5 C 41 34.5, 59 34.5, 64.5 32.5 L 65 36.5 C 59 38.5, 41 38.5, 35 36.5 Z", frost, 0.2, 0.15, outline=frost_d)
    a.line("M 45 33 L 45 38 M 42.8 34.2 L 47.2 36.8 M 42.8 36.8 L 47.2 34.2", "#FFFFFF", 0.7)
    a.shape("M 20 40 C 22 35.5, 36 33, 50 33 C 64 33, 79 34, 81 38.5 C 82 42, 66 44.5, 50 44.5 C 34 44.5, 19 43.5, 20 40 Z", blue, 0.25, 0.3)
    # icicles hanging off the brim
    for x, h in ((25.5, 4.5), (29, 6.5), (32.4, 3.6), (73, 5), (76.2, 3.4)):
        a.shape(f"M {x - 1.4} 42.6 L {x + 1.4} 42.8 L {x} {42.8 + h} Z", frost, 0.3, 0.1, outline=frost_d, width=0.5)
    # the staff, an ice crystal on top
    a.shape("M 79.5 100 L 77 70 L 80 69.6 L 83 100 Z", "#8A6440", 0.2, 0.25)
    a.shape("M 77.5 47 L 82 54 L 80.5 68 L 75.5 68 L 73.5 54 Z", frost, 0.45, 0.2, outline=frost_d)
    a.fill("M 77.5 47 L 78 68 L 75.5 68 L 73.5 54 Z", "#FFFFFF", 0.45)
    return a.svg()


def trapper():
    """The crew's bounty hunter: a coonskin cap with its ringed tail, freckles, a thick
    plait over one shoulder, a fur collar and a coil of rope on the other."""
    a = Art()
    hair, hair_d = "#B5522A", "#7E3416"
    fur, fur_d, fur_l = "#8E8070", "#4A4038", "#B8AC9C"
    # the rest of her hair, behind
    a.shape("M 31 47 C 30 34, 38.5 27, 50 27 C 61.5 27, 70 34, 69 47 C 69 55, 68 61, 66 66 L 34 66 C 32 61, 31 55, 31 47 Z", hair_d, 0.15, 0.25)
    p = {
        "skin": "#E8B48A", "coat": "#EE8A2E", "hair": hair, "brow": hair_d, "mood": "sly",
        "head": (32, 10.5), "nose": (0.92, 0.9), "freckles": True,
        "collar": [("shape", "M 31 77.5 C 34 73.5, 42 73, 50 76 C 58 73, 66 73.5, 69 77.5 C 68 80.5, 65 81, 62.5 80 C 60.5 82.5, 56.5 82.5, 54.5 80.5 "
                    "C 52.5 82.5, 47.5 82.5, 45.5 80.5 C 43.5 82.5, 39.5 82.5, 37.5 80 C 35 81, 32 80.5, 31 77.5 Z", fur_l)],
    }
    figure(a, p)
    # a coil of rope over her shoulder
    rope = "#C9A26B"
    a.parts.append(f'<ellipse cx="24" cy="89" rx="9.5" ry="6.5" fill="none" stroke="{mix(rope, INK, 0.5)}" stroke-width="3.6"/>')
    a.parts.append(f'<ellipse cx="24" cy="89" rx="9.5" ry="6.5" fill="none" stroke="{rope}" stroke-width="2.2"/>')
    for k in range(10):
        t = k / 10 * 2 * math.pi
        x, y = 24 + 9.5 * math.cos(t), 89 + 6.5 * math.sin(t)
        a.line(f"M {x - 0.6:.2f} {y - 0.9:.2f} L {x + 0.6:.2f} {y + 0.9:.2f}", mix(rope, INK, 0.45), 0.5, 0.8)
    # her fringe, swept to one side, and the plait over her other shoulder
    a.shape("M 34 46 C 33.5 36, 40 30, 49 30.5 C 57 31, 63 34, 65.5 40 C 60 37.5, 53 37.6, 47 40 C 43 41.6, 37.5 43, 34 46 Z", hair, 0.2, 0.25)
    a.shape("M 64 50 C 66.5 54, 67 59, 65.5 63 L 61.5 62 C 63 58, 63 54, 61.5 50.5 Z", hair, 0.15, 0.25)
    braid(a, 64.5, 62, 69.5, 95, hair, n=7, width=5.2)
    # the coonskin cap: a soft dome of grey fur, its ringed tail hanging down behind her
    tail = "M 34 41 C 30 46, 27.5 53, 27 60 C 26.8 63.5, 27.5 66, 29.5 67.5 C 31.5 66.5, 32.5 64, 32.6 60.5 C 32.8 54, 34.5 48, 37.5 43.5 Z"
    a.shape(tail, fur_l, 0.2, 0.2, outline=mix(fur_d, INK, 0.3))
    a.clip_start(tail)
    for y0 in (47.5, 54, 60.5):
        a.fill(f"M 20 {y0} L 40 {y0 - 2} L 40 {y0 + 1.6} L 20 {y0 + 3.6} Z", fur_d, 0.9)
    a.fill("M 20 65.5 L 40 63.5 L 40 70 L 20 70 Z", fur_d)
    a.end()
    a.shape("M 32 42 C 31 37, 32 32, 34 29 C 33.5 27, 35 25.5, 36.5 26 C 38.5 22.5, 42.5 20.5, 45.5 21.5 C 47.5 19.5, 52.5 19.5, 54.5 21.5 "
            "C 57.5 20.5, 61.5 22.5, 63.5 26 C 65 25.5, 66.5 27, 66 29 C 68 32, 69 37, 68 42 C 60 39.5, 40 39.5, 32 42 Z", fur, 0.28, 0.28)
    a.line("M 41 26 C 40.5 29, 40.5 32, 41.5 35 M 50 23 C 49.5 27, 49.5 31, 50 35 M 59 26 C 59.5 29, 59.5 32, 58.5 35", fur_d, 0.7, 0.55)
    return a.svg()


def fire_starter():
    a = Art()
    red = "#D64545"
    p = {"skin": "#A86B45", "coat": red, "hair": "#1E1A1A", "mood": "cheeky", "head": (35, 13), "nose": (1.15, 1.0),
         "coat_detail": [("shape", "M 40 77 L 50 92 L 60 77 C 56 79.5, 44 79.5, 40 77 Z", "#3A3A44")]}
    figure(a, p)
    # a black chin beard and sideburns
    a.shape("M 42.5 62.5 C 43.5 70.5, 56.5 70.5, 57.5 62.5 C 54.5 66, 45.5 66, 42.5 62.5 Z", "#1E1A1A", 0.15, 0.1)
    a.fill("M 34 47 C 34 52, 35 55, 36.5 57 L 37.5 47 Z M 66 47 C 66 52, 65 55, 63.5 57 L 62.5 47 Z", "#1E1A1A")
    # a gold hoop in his ear
    a.parts.append(f'<circle cx="32.6" cy="56" r="2.2" fill="none" stroke="{GOLD}" stroke-width="1"/>')
    # a bandana knotted at the side, its ends flying
    a.shape("M 26 43 L 21 47 L 25.5 50 Z", red, 0.2, 0.3)
    a.shape("M 27 42 L 20 41 L 23.5 46 Z", red, 0.2, 0.3)
    a.shape("M 33 42.5 C 32.5 30, 40.5 24.5, 50 24.5 C 59.5 24.5, 67.5 30, 67 42.5 C 60 39.5, 40 39.5, 33 42.5 Z", red, 0.3, 0.3)
    a.shape(ell(30.5, 42.5, 3.4, 2.8), red, 0.2, 0.3)
    for x, y in ((42, 30.5), (50, 28.5), (58, 30.5), (46, 35.5), (54, 35.5)):
        a.fill(ell(x, y, 1.2, 1.2), "#F6EEDC", 0.9)
    # his torch, held up by his shoulder
    a.shape("M 80 100 L 77.5 74 L 81.5 73.5 L 84 100 Z", "#9C6B3A", 0.2, 0.25)
    a.shape("M 79 54 C 84 61, 88 64, 87 70 C 86.5 73.5, 83.5 75, 79.5 75 C 75.5 75, 72.5 73.5, 72.5 70 C 72.5 66.5, 75 64, 76.5 61 C 77 63, 78 64, 79 64.5 C 78.4 61, 78.4 57.5, 79 54 Z", "#F08A24", 0.35, 0.1)
    a.fill("M 79.5 64 C 81.5 67, 83.5 69, 83 71.5 C 82.5 73, 81 74, 79.5 74 C 77.8 74, 76.4 73, 76.4 71.3 C 76.4 69.5, 78 68.5, 78.8 67 C 79.2 68, 79.6 68.4, 80.1 68.6 C 79.6 67.2, 79.4 65.6, 79.5 64 Z", "#FFD35C")
    return a.svg()


def naturalist():
    a = Art()
    hair = "#4A2E1A"
    # two plaits hanging down by her shoulders
    braid(a, 34, 52, 32, 88, hair, n=7, width=5)
    braid(a, 66, 52, 68, 88, hair, n=7, width=5)
    p = {"skin": "#C68A5A", "coat": "#3E9F5B", "hair": hair, "mood": "happy",
         "collar": [("shape", "M 38 77 C 43 82, 57 82, 62 77 C 57 79.5, 43 79.5, 38 77 Z", "#8C6B3E")]}
    figure(a, p)
    a.shape("M 34 46 C 33.5 34, 41 28.5, 50 28.5 C 59 28.5, 66.5 34, 66 46 C 61 39, 55 37.5, 50 39 C 45 37.5, 39 39, 34 46 Z", hair, 0.2, 0.25)
    # three big leaves for a hat
    leaf, leaf_d = "#5DB54A", "#3E8A33"
    a.shape("M 47 33 C 38 30, 28 24, 25 14 C 35 14, 45 21, 49 31 Z", leaf, 0.25, 0.25)
    a.shape("M 53 33 C 62 30, 72 24, 75 14 C 65 14, 55 21, 51 31 Z", leaf, 0.2, 0.3)
    a.shape("M 50 33 C 43 25, 42 13, 50 4 C 58 13, 57 25, 50 33 Z", "#7CC85A", 0.25, 0.25)
    a.line("M 48 31 C 40 26, 32 21, 27 15.5 M 52 31 C 60 26, 68 21, 73 15.5 M 50 31 L 50 7", leaf_d, 0.8, 0.8)
    return a.svg()


def warper():
    a = Art()
    pink = "#D35A9C"
    p = {"skin": "#F0C29A", "coat": pink, "hair": "#5A3A22", "mood": "smug", "head": (31, 9), "nose": (0.85, 1.2),
         "collar": [("shape", "M 42 76 L 50 90 L 58 76 C 55 78.5, 45 78.5, 42 76 Z", CREAM),
                    ("shape", "M 46 81 C 47 79, 53 79, 54 81 L 52 85 L 48 85 Z", CREAM)]}
    figure(a, p)
    # a thin moustache with curled ends
    a.shape("M 50 59.4 C 47 58, 43.5 58.5, 42 60.5 C 41.5 61.5, 42.4 62, 43.2 61 C 45 59.8, 47.6 60.2, 50 60.6 C 52.4 60.2, 55 59.8, 56.8 61 C 57.6 62, 58.5 61.5, 58 60.5 C 56.5 58.5, 53 58, 50 59.4 Z", "#5A3A22", 0.15, 0.1)
    # a wide hat, a white plume curling off it
    a.shape("M 55 26 C 66 18, 80 18, 88 26 C 82 25, 77 26, 73 29 C 78 29, 82 31, 84 34 C 76 31, 66 31, 58 33 Z", "#FFFFFF", 0.0, 0.18, outline="#B8B0B8")
    a.shape("M 35 37 C 35 25, 41 19, 50 19 C 59 19, 65 25, 65 37 Z", pink, 0.25, 0.3)
    a.shape("M 31 35.6 C 40 37.6, 60 37.6, 69 35.6 L 69 38.4 C 60 40.4, 40 40.4, 31 38.4 Z", "#5A2A44", 0.1, 0.1)
    a.shape("M 18 39 C 18 34, 34 32.5, 50 32.5 C 66 32.5, 82 34, 82 39 C 82 43.5, 66 44.5, 50 44.5 C 34 44.5, 18 43.5, 18 39 Z", pink, 0.2, 0.3)
    # his pocket watch on its chain
    a.line("M 62 86 C 66 90, 70 90, 74 87", GOLD, 0.8)
    a.shape(ell(76.5, 88, 4, 4), GOLD, 0.35, 0.3)
    a.fill(ell(76.5, 88, 2.6, 2.6), CREAM)
    a.line("M 76.5 88 L 76.5 86.2 M 76.5 88 L 77.8 88.6", INK, 0.5)
    return a.svg()


def overseer():
    a = Art()
    gold = "#E7B023"
    grey = "#D8D2C8"
    p = {"skin": "#7A4E2D", "coat": gold, "brow": grey, "mood": "idle", "head": (35, 13.5), "nose": (1.1, 1.05),
         "coat_detail": [("shape", "M 39 76.5 C 41 84, 43 92, 44 100 L 36 100 C 35 92, 35 84, 36 77.5 Z", NAVY),
                         ("shape", "M 61 76.5 C 59 84, 57 92, 56 100 L 64 100 C 65 92, 65 84, 64 77.5 Z", NAVY)]}
    figure(a, p)
    # a short grey beard along his jaw
    a.shape("M 33 50 C 33.5 60, 40 68.5, 50 69.2 C 60 68.5, 66.5 60, 67 50 C 63.5 57, 58.5 60.5, 56 60.8 C 55 63.5, 45 63.5, 44 60.8 C 41.5 60.5, 36.5 57, 33 50 Z", grey, 0.15, 0.2)
    a.line("M 46 61.6 C 48.5 62.4, 51.5 62.4, 54 61.6", "#5A3A2A", 1.1)
    # a navy tricorn, trimmed in gold
    a.shape("M 37 34 C 39 23, 61 23, 63 34 Z", NAVY, 0.25, 0.3)
    a.shape("M 24 41 C 28 31.5, 39 27.5, 50 30 C 61 27.5, 72 31.5, 76 41 C 66 37, 57 37.5, 50 42 C 43 37.5, 34 37, 24 41 Z", NAVY, 0.25, 0.3)
    a.line("M 24.6 40.4 C 34 37, 43 37.6, 50 41.4 C 57 37.6, 66 37, 75.4 40.4", GOLD, 1.1)
    # his brass spyglass, tucked under his arm
    a.shape("M 70 100 L 76 72 L 81 73 L 76 100 Z", "#C9A227", 0.35, 0.3)
    a.shape("M 75.6 74 L 77.4 64 L 81.4 64.8 L 80.4 74.8 Z", "#A87A00", 0.3, 0.3)
    return a.svg()


def gambler():
    a = Art()
    hair = "#3A2418"
    teal = "#22A094"
    # her bob, behind
    a.shape("M 31 47 C 30 34, 38.5 27, 50 27 C 61.5 27, 70 34, 69 47 C 69 54, 69 59, 67 63 L 33 63 C 31 59, 31 54, 31 47 Z", hair, 0.15, 0.3)
    p = {"skin": "#F0C8A0", "coat": teal, "hair": hair, "mood": "smug", "head": (31.5, 9.5), "nose": (0.85, 0.85),
         "collar": [("shape", "M 41 76.5 L 50 87 L 59 76.5 C 55 79, 45 79, 41 76.5 Z", CREAM),
                    ("shape", "M 44 79 C 46 76.5, 48.5 77.5, 50 79.6 C 51.5 77.5, 54 76.5, 56 79 C 54 81.5, 51.5 81.6, 50 79.6 C 48.5 81.6, 46 81.5, 44 79 Z", "#E2574C")]}
    figure(a, p)
    # the fringe and the sides of her bob
    a.shape("M 33.5 46 C 33 34, 41 28.5, 50 28.5 C 59 28.5, 67 34, 66.5 46 C 63 40, 58 38.5, 54 39.5 C 51 38, 46 38, 43 40 C 40 39.5, 36 41.5, 33.5 46 Z", hair, 0.2, 0.25)
    a.shape("M 34 44 C 32.5 51, 32.5 58, 35 62.5 C 36.5 64.5, 39.5 64.5, 40.5 62.5 C 38.5 58, 37.5 51, 38 45 Z", hair, 0.15, 0.25)
    a.shape("M 66 44 C 67.5 51, 67.5 58, 65 62.5 C 63.5 64.5, 60.5 64.5, 59.5 62.5 C 61.5 58, 62.5 51, 62 45 Z", hair, 0.15, 0.25)
    # a small teal tricorn, cocked to one side
    a.shape("M 36 29 C 37.5 18, 61 17, 63.5 26.5 Z", teal, 0.25, 0.3)
    a.shape("M 26 34.5 C 30.5 25, 41 21.5, 51 24.2 C 60 21.5, 69 24, 73.5 32 C 64.5 29.5, 56.5 30, 50.5 34.6 C 43.5 30.6, 34 30.6, 26 34.5 Z", teal, 0.25, 0.3)
    a.line("M 26.6 34 C 34 31, 43.5 30.8, 50.5 34 C 56.5 30.2, 64.5 29.8, 73 31.6", GOLD, 0.9)
    # her lucky die, held up
    a.shape("M 71 82 L 82 79 L 85 90 L 74 93 Z", CREAM, 0.1, 0.2)
    for x, y in ((74.6, 84.2), (78, 86.2), (81.4, 88.2)):
        a.fill(ell(x, y, 1, 1), INK)
    return a.svg()


def cannoneer():
    a = Art()
    ginger = "#C0562A"
    p = {"skin": "#D9A07A", "coat": "#93633A", "brow": ginger, "mood": "happy", "head": (36, 14), "nose": (1.25, 1.1),
         "coat_detail": [("line", "M 30 82 L 62 100", "#2A2018")]}
    figure(a, p)
    # a handlebar moustache: thick under his nose, its ends twirled up
    for flip in (1, -1):
        a.parts.append(f'<g transform="translate(50 0) scale({flip} 1) translate(-50 0)">')
        a.shape("M 50 57.2 C 46.5 56, 42 56.8, 39.4 56.6 C 37.8 56.4, 37.4 54.8, 38.6 54 C 36.6 53.4, 35 55.4, 35.8 57.2 "
                "C 37 59.8, 41.5 60.6, 45.5 60.2 C 47.5 60, 49 59.8, 50 60.4 Z", ginger, 0.25, 0.2)
        a.end()
    # a steel helmet with a brim
    steel = "#8C94A3"
    a.shape("M 33 39 C 32.5 26.5, 40.5 20.5, 50 20.5 C 59.5 20.5, 67.5 26.5, 67 39 Z", steel, 0.35, 0.3)
    a.shape("M 25 40 C 25 36.5, 37 35.5, 50 35.5 C 63 35.5, 75 36.5, 75 40 C 75 43, 63 44, 50 44 C 37 44, 25 43, 25 40 Z", "#6E7686", 0.3, 0.3)
    a.line("M 50 21.5 L 50 35", "#B8BECA", 1.1, 0.8)
    return a.svg()


PORTRAITS = [
    ("mage", mage), ("trapper", trapper), ("fire_starter", fire_starter), ("naturalist", naturalist),
    ("warper", warper), ("overseer", overseer), ("gambler", gambler), ("cannoneer", cannoneer),
]


def sprites():
    return [(name, draw()) for name, draw in PORTRAITS]
