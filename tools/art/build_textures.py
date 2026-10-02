#!/usr/bin/env python3
"""Generates every Sift texture (WP-041). Deterministic: `python3 tools/art/build_textures.py`.

Original art only (hard rule 9.1): every pixel comes from the shapes and seeded patterns below,
drawn with colours from docs/DESIGN/palette.md. Assets are All Rights Reserved (D-003).
"""
from __future__ import annotations

import math
import random

from PIL import Image

from sift_art import RAMPS, save, save_mcmeta, strip

W = H = 16


# ---------------------------------------------------------------- helpers
def rgba(ramp: str, i: int, a: int = 255) -> tuple[int, int, int, int]:
    return (*RAMPS[ramp][i], a)


def tile_noise(w: int, h: int, cx: int, cy: int, seed: int, octaves=((1.0, 1),)) -> list[list[float]]:
    """Tileable value noise in [0, 1]: cx×cy random lattice per octave, smooth-interpolated with wrap."""
    out = [[0.0] * w for _ in range(h)]
    total = 0.0
    for amp, mul in octaves:
        rnd = random.Random(seed * 7919 + mul)
        gx, gy = cx * mul, cy * mul
        lattice = [[rnd.random() for _ in range(gx)] for _ in range(gy)]
        for y in range(h):
            fy = y / h * gy
            y0 = int(fy) % gy
            y1 = (y0 + 1) % gy
            ty = fy - int(fy)
            ty = ty * ty * (3 - 2 * ty)
            for x in range(w):
                fx = x / w * gx
                x0 = int(fx) % gx
                x1 = (x0 + 1) % gx
                tx = fx - int(fx)
                tx = tx * tx * (3 - 2 * tx)
                a = lattice[y0][x0] * (1 - tx) + lattice[y0][x1] * tx
                b = lattice[y1][x0] * (1 - tx) + lattice[y1][x1] * tx
                out[y][x] += amp * (a * (1 - ty) + b * ty)
        total += amp
    return [[v / total for v in row] for row in out]


def noise_fn(cx: int, cy: int, seed: int, w: int = W, h: int = H):
    """A continuous tileable value-noise function over a w×h period (for animation by scrolling)."""
    rnd = random.Random(seed)
    lat = [[rnd.random() for _ in range(cx)] for _ in range(cy)]

    def f(x: float, y: float) -> float:
        fx, fy = (x / w * cx) % cx, (y / h * cy) % cy
        x0, y0 = int(fx), int(fy)
        x1, y1 = (x0 + 1) % cx, (y0 + 1) % cy
        tx, ty = fx - x0, fy - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = lat[y0][x0] * (1 - tx) + lat[y0][x1] * tx
        b = lat[y1][x0] * (1 - tx) + lat[y1][x1] * tx
        return a * (1 - ty) + b * ty
    return f


def bands(values: list[list[float]], thresholds: list[float], colours: list) -> Image.Image:
    """Quantizes values into len(thresholds)+1 bands, using value-rank thresholds (fractions)."""
    flat = sorted(v for row in values for v in row)
    cuts = [flat[min(len(flat) - 1, int(t * len(flat)))] for t in thresholds]
    h, w = len(values), len(values[0])
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            i = sum(values[y][x] >= c for c in cuts)
            px[x, y] = colours[i]
    return im


def put(im: Image.Image, pts, colour) -> None:
    px = im.load()
    w, h = im.size
    for x, y in pts:
        px[x % w, y % h] = colour


# ---------------------------------------------------------------- hymnstone family
def scatter(seed: int, count: int, spacing: float, w: int = W, h: int = H) -> list[tuple[int, int]]:
    """Up to `count` points at least `spacing` apart on the wrapped w×h torus (seeded dart throwing)."""
    rnd = random.Random(seed)
    pts: list[tuple[int, int]] = []
    for _ in range(count * 40):
        if len(pts) == count:
            break
        x, y = rnd.randrange(w), rnd.randrange(h)
        if all(min(abs(x - px), w - abs(x - px)) ** 2 + min(abs(y - py), h - abs(y - py)) ** 2 >= spacing ** 2 for px, py in pts):
            pts.append((x, y))
    return pts


def hymnstone_pattern(seed: int = 3) -> Image.Image:
    # Soft strata: noise stretched sideways plus fine grain, in four close tones. No lines or other
    # shapes the eye could follow from block to block (the lesson of vanilla stone).
    n = tile_noise(W, H, 3, 8, seed, ((1.0, 1), (0.5, 2), (0.3, 4)))
    im = bands(n, [0.1, 0.5, 0.88], [rgba("hymnstone", 2), rgba("hymnstone", 3), rgba("hymnstone", 4), rgba("hymnstone", 5)])
    # A few tiny pores: one dark pixel with a lit pixel above it.
    for x, y in scatter(seed * 13 + 1, 4, 5.0):
        put(im, [(x, y)], rgba("hymnstone", 1))
        put(im, [(x, y - 1)], rgba("hymnstone", 4))
    return im


def hymnstone_bricks() -> Image.Image:
    n = tile_noise(W, H, 3, 3, 11)
    base = bands(n, [0.3, 0.85], [rgba("hymnstone", 2), rgba("hymnstone", 3), rgba("hymnstone", 4)])
    px = base.load()
    mortar = rgba("hymnstone", 1)
    hi, lo = rgba("hymnstone", 5), rgba("hymnstone", 2)
    # Two courses, 7 px of brick + 1 px mortar; joints offset between courses.
    for y in (7, 15):
        for x in range(W):
            px[x, y] = mortar
    for (y0, y1, joints) in ((0, 6, (11,)), (8, 14, (3,))):
        for jx in joints:
            for y in range(y0, y1 + 1):
                px[jx, y] = mortar
        # Bevel: highlight on each brick's top row and left column, shadow on bottom row and right column.
        starts = sorted([0] + [j + 1 for j in joints])
        ends = sorted([j - 1 for j in joints] + [W - 1])
        for sx, ex in zip(starts, ends):
            for x in range(sx, ex + 1):
                px[x, y0] = hi
                px[x, y1] = lo
            for y in range(y0, y1 + 1):
                px[sx, y] = hi if y < y1 else lo
                px[ex, y] = lo
    return base


# ---------------------------------------------------------------- healthy sculk
PETALS = [  # small petal clusters, all lit from the top-left: crown (P), petal (p), shade (s)
    ["Pp", "ps"],
    [".P", "Pp", "s."],
    ["PP.", "pps"],
    ["P.", "pP", ".s"],
]


def healthy_sculk_top(seed: int = 21) -> Image.Image:
    # A carpet of tiny petals: fine low-contrast noise, then small scattered clusters in varied
    # shapes. Blockstates add random rotations on top of the variants, as vanilla grass does.
    n = tile_noise(W, H, 8, 8, seed, ((1.0, 1), (0.35, 2)))
    im = bands(n, [0.25], [rgba("healthy_sculk", 3), rgba("healthy_sculk", 4)])
    colours = {"P": rgba("healthy_sculk", 6), "p": rgba("healthy_sculk", 5), "s": rgba("healthy_sculk", 2)}
    rnd = random.Random(seed)
    for (ox, oy) in scatter(seed * 7 + 3, 8, 4.5):
        shape = PETALS[rnd.randrange(len(PETALS))]
        for dy, row in enumerate(shape):
            for dx, ch in enumerate(row):
                if ch != ".":
                    put(im, [(ox + dx, oy + dy)], colours[ch])
    return im


def healthy_sculk_side() -> Image.Image:
    im = hymnstone_pattern(seed=5)
    top = healthy_sculk_top()
    tp, ip = top.load(), im.load()
    # Petal fringe: 3 px everywhere, hanging to 4–5 px in a few tufts, with a dark under-edge.
    depth = [3, 4, 3, 3, 5, 4, 3, 3, 4, 3, 3, 5, 4, 3, 3, 4]
    for x in range(W):
        for y in range(depth[x]):
            ip[x, y] = tp[x, (y + 3) % H]
        ip[x, depth[x]] = rgba("healthy_sculk", 0)
    return im


GRASS_SHORT = """
................
................
................
.....6..........
.....66.....6...
.....5......66..
..6..4......5...
..66.4..6...4...
..5..43.5..34...
..4...4.4..4....
..43..4.43.4..6.
...4..34.4.4..66
...43..4.4.43.5.
....4..44.443.4.
....43.34.433.4.
....33.33.333.3.
"""

GRASS_TALL_TOP = """
................
......6.........
......66....6...
......5.....66..
..6...4.....5...
..66..4.....4...
..5...4..6..4...
..4...4..66.4...
..4..4...5..4...
..4..4...4..4...
...4.4...4.4....
...4.4...4.4....
...4.4..4..4....
...4..4.4..4....
....4.4.4.4.....
....4.4.4.4.....
"""

GRASS_TALL_BOTTOM = """
....4.4.4.4.....
...4..4.4..4....
...4..4.4..4....
...43.4..43.4...
..4.3.4...4..4..
..4.3.43..4.43..
..4..43.3.4.4.3.
..43.4..3.43..3.
...3.4..3.4..3..
...3.43.334..3..
...33.3.33.4.3..
....3.3..3.433..
....33.3.33.33..
....33.33.333...
....23.32.232...
....22.22.222...
"""


def plant(text: str) -> Image.Image:
    c = {str(i): rgba("healthy_sculk", i) for i in range(7)}
    rows = [r for r in text.strip().splitlines()]
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == W, (y, row)
        for x, ch in enumerate(row):
            if ch != ".":
                put(im, [(x, y)], c[ch])
    return im


# ---------------------------------------------------------------- songwood
FLUTE_HOLE = [  # 2×3 hole: lip (L) on the lit top-left, bore (b), shaded rim (l)
    "Lb",
    "Lb",
    "lb",
]


FLUTE_SPOTS = {1: ((4, 3), (11, 11)), 2: ((2, 9), (12, 2))}


def songwood_log(variant: int = 1) -> Image.Image:
    # Bark: vertical furrows (noise stretched vertically); two flute holes, placed per variant.
    n = tile_noise(W, H, 8, 2, 31 + variant * 100, ((1.0, 1), (0.3, 2)))
    im = bands(n, [0.22, 0.6, 0.88], [rgba("songwood_bark", 1), rgba("songwood_bark", 2), rgba("songwood_bark", 3), rgba("songwood_bark", 4)])
    c = {"L": rgba("flute", 0), "l": rgba("songwood_bark", 5), "b": rgba("songwood_bark", 0)}
    for (ox, oy) in FLUTE_SPOTS[variant]:
        for dy, row in enumerate(FLUTE_HOLE):
            for dx, ch in enumerate(row):
                if ch != ".":
                    put(im, [(ox + dx, oy + dy)], c[ch])
    return im


def songwood_log_top() -> Image.Image:
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            d = max(abs(x - 7.5), abs(y - 7.5))
            if d > 6.5:
                px[x, y] = rgba("songwood_bark", 2 if (x + y) % 3 else 3)
            else:
                ring = int(d) % 3
                px[x, y] = rgba("songwood_planks", (2, 3, 4)[ring])
    # The hollow core: songwood's branches are flutes.
    put(im, [(7, 7), (8, 7), (7, 8), (8, 8)], rgba("songwood_bark", 0))
    put(im, [(6, 7), (7, 6), (8, 6), (6, 8)], rgba("flute", 0))
    put(im, [(9, 7), (9, 8), (7, 9), (8, 9)], rgba("songwood_planks", 1))
    return im


def songwood_planks() -> Image.Image:
    n = tile_noise(W, H, 2, 8, 41)
    im = bands(n, [0.55], [rgba("songwood_planks", 3), rgba("songwood_planks", 4)])
    px = im.load()
    # Four boards, 4 px tall: a dark seam at each board's bottom, a light edge at its top, offset end joints.
    for b, jx in enumerate((5, 12, 2, 9)):
        y0 = b * 4
        for x in range(W):
            px[x, y0 + 3] = rgba("songwood_planks", 1)
        for y in range(y0 + 1, y0 + 3):
            px[jx, y] = rgba("songwood_planks", 2)
        # A short grain mark in each board.
        gx = (jx + 5) % W
        for x in range(gx, gx + 3):
            px[x % W, y0 + 1] = rgba("songwood_planks", 2)
    return im


def songwood_leaves(seed: int = 51) -> Image.Image:
    # Fine-grained so the gaps scatter as single pixels and pairs, like vanilla leaves, instead of
    # forming blobs that line up from block to block.
    n = tile_noise(W, H, 6, 6, seed, ((1.0, 1), (0.75, 2)))
    im = bands(n, [0.2, 0.42, 0.75, 0.93],
               [(0, 0, 0, 0), rgba("songwood_leaves", 1), rgba("songwood_leaves", 2), rgba("songwood_leaves", 3), rgba("songwood_leaves", 4)])
    px = im.load()
    # Pale-blue edges where a leaf meets a gap below (shade side).
    for y in range(H):
        for x in range(W):
            if px[x, y][3] and px[x, (y + 1) % H][3] == 0:
                px[x, y] = rgba("songwood_leaves", 0)
    return im


def songwood_sapling() -> Image.Image:
    rows = [
        "................",
        "......44........",
        ".....4443..43...",
        "....443332443...",
        ".....4321.432...",
        "......21..21....",
        ".......b.b......",
        "........bb..433.",
        ".......Bb..4432.",
        ".344...bB.b.21..",
        ".4432..bbb......",
        "..21....bB......",
        "........bb......",
        "........Bb......",
        "........bb......",
        "........bb......",
    ]
    c = {"4": rgba("songwood_leaves", 4), "3": rgba("songwood_leaves", 3), "2": rgba("songwood_leaves", 1),
         "1": rgba("songwood_leaves", 0), "b": rgba("songwood_bark", 2), "B": rgba("flute", 1)}
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                put(im, [(x, y)], c[ch])
    return im


# ---------------------------------------------------------------- tide basin
def tide_sand(seed: int = 61) -> Image.Image:
    # Fine silt in three close tones, with short broken ripple marks (crest over trough) scattered
    # per variant rather than lines running across every block.
    n = tile_noise(W, H, 5, 5, seed, ((1.0, 1), (0.6, 2)))
    im = bands(n, [0.15, 0.7], [rgba("tide_sand", 2), rgba("tide_sand", 3), rgba("tide_sand", 4)])
    rnd = random.Random(seed)
    for (x0, y0) in scatter(seed * 5 + 2, 6, 5.0):
        ln = rnd.randint(3, 6)
        phase = rnd.random() * 6.28
        for i in range(ln):
            y = y0 + round(math.sin(i / 2.5 + phase) * 0.6)
            put(im, [(x0 + i, y)], rgba("tide_sand", 1 if 0 < i < ln - 1 else 2))
            put(im, [(x0 + i, y - 1)], rgba("tide_sand", 5))
    return im


def tide_vent_top() -> Image.Image:
    im = hymnstone_pattern(seed=71)
    px = im.load()
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - 7.5, y - 7.5)
            if d < 3.2:
                px[x, y] = rgba("ichor", 1 if d < 2.2 else 2)
            elif d < 4.3:
                px[x, y] = rgba("hymnstone", 1)
            elif d < 5.2:
                px[x, y] = rgba("hymnstone", 5) if (x + y) < 15 else rgba("hymnstone", 2)
    put(im, [(6, 6), (9, 8)], rgba("ichor", 4))
    put(im, [(7, 9)], rgba("ichor", 5))
    return im


def tide_vent_side() -> Image.Image:
    im = hymnstone_pattern(seed=73)
    # Ichor stains running down from the vent's lip.
    for x, ln in ((5, 6), (6, 9), (9, 4), (10, 7)):
        for y in range(ln):
            put(im, [(x, y)], rgba("ichor", 1 if y < ln - 1 else 2))
    put(im, [(x, 0) for x in range(W)], rgba("hymnstone", 5))
    return im


# ---------------------------------------------------------------- gate
def gatestone(top: bool) -> Image.Image:
    n = tile_noise(W, H, 3, 3, 81 if top else 83)
    im = bands(n, [0.4, 0.85], [rgba("gatestone", 0), rgba("gatestone", 1), rgba("gatestone", 2)])
    px = im.load()
    # Hymnstone rim (light top-left, dark bottom-right).
    for i in range(W):
        px[i, 0] = rgba("hymnstone", 3)
        px[0, i] = rgba("hymnstone", 3)
        px[i, H - 1] = rgba("hymnstone", 1)
        px[W - 1, i] = rgba("hymnstone", 1)
    groove, fill, glint = rgba("glyph", 0), rgba("glyph", 1), rgba("glyph", 2)
    if top:
        # A ring of five inlaid notches: the gate listens.
        for k in range(5):
            a = k / 5 * 2 * math.pi - math.pi / 2
            x, y = round(7.5 + 4.2 * math.cos(a)), round(7.5 + 4.2 * math.sin(a))
            put(im, [(x, y)], fill)
            put(im, [(x + 1, y)], groove)
        put(im, [(7, 7), (8, 8)], glint)
    else:
        # Two inlaid staff lines and a single note between them.
        for y in (5, 10):
            for x in range(2, 14):
                px[x, y] = fill
                px[x, y + 1] = groove
        put(im, [(7, 7), (8, 7), (7, 8), (8, 8)], fill)
        put(im, [(9, 3), (9, 4), (9, 5), (9, 6), (9, 7)], fill)
        put(im, [(7, 7)], glint)
    return im


MEM_A = noise_fn(4, 4, 101)
MEM_B = noise_fn(3, 5, 103)
MEM_C = noise_fn(6, 6, 107)


def membrane_frames(n: int = 32) -> list[Image.Image]:
    # A calm cyan sheet: two soft tones that drift, crossed by thin bright ribbons (the contour of a
    # second drifting field), so it shimmers without tiling into a pattern.
    frames = []
    for f in range(n):
        im = Image.new("RGBA", (W, H))
        px = im.load()
        s = f / n * W  # scroll one full period over the loop
        for y in range(H):
            for x in range(W):
                body = 0.6 * MEM_A(x + s, y) + 0.4 * MEM_B(x, y - s)
                i = 2 if body < 0.5 else 3
                rib = MEM_C(x - s, y + s)
                if abs(rib - 0.5) < 0.05:
                    i = 4
                if abs(rib - 0.5) < 0.018:
                    i = 5
                px[x, y] = rgba("membrane", i, 184 + i * 8)
        frames.append(im)
    return frames


# ---------------------------------------------------------------- ichor
def ichor_frame(w: int, h: int, t: float, flow: bool) -> Image.Image:
    """The Sift's water (D-024): clear turquoise like the teaser's pools, translucent like vanilla
    water. A soft two-tone body with lighter wave crests and a rare glint; low contrast, because every
    block shows the same frame."""
    body = noise_fn(3, 3, 111, w, h)
    crest = noise_fn(5, 4, 113, w, h)
    glint = noise_fn(7, 7, 117, w, h)
    im = Image.new("RGBA", (w, h))
    px = im.load()
    s = t * w
    for y in range(h):
        for x in range(w):
            if flow:
                b, c, g = body(x, y - s), crest(x, y - 2 * s), glint(x, y - 2 * s)
            else:
                b, c, g = body(x + s, y), crest(x - s, y + s), glint(x + s, y - s)
            colour = rgba("ichor", 2, 168) if b < 0.45 else rgba("ichor", 3, 168)
            if abs(c - 0.5) < 0.045:
                colour = rgba("ichor", 4, 188)
            if g > 0.93:
                colour = rgba("ichor", 5, 200)
            px[x, y] = colour
    return im


def ichor_overlay() -> Image.Image:
    """The face of ichor seen through glass or leaves, as vanilla's water overlay: the body, fainter."""
    im = ichor_frame(16, 16, 0.0, flow=False)
    px = im.load()
    for y in range(16):
        for x in range(16):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, a - 48)
    return im


def ichor_bucket() -> Image.Image:
    rows = [
        "................",
        "................",
        "....5555555.....",
        "...5.......5....",
        "..5.........5...",
        "..4tTtvVvtTt4...",
        "..43tvvVvvt34...",
        "..4433333332....",
        "...433333322....",
        "...44333332.....",
        "....4333322.....",
        "....4433322.....",
        ".....433322.....",
        ".....222221.....",
        "................",
        "................",
    ]
    c = {"5": rgba("pail", 4), "4": rgba("pail", 4), "3": rgba("pail", 3), "2": rgba("pail", 2), "1": rgba("pail", 1),
         "t": rgba("ichor", 3), "T": rgba("ichor", 4), "v": rgba("ichor", 2), "V": rgba("ichor", 5)}
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                put(im, [(x, y)], c[ch])
    return im


# ---------------------------------------------------------------- blub
def blub_texture() -> Image.Image:
    """32 x 32 entity texture laid out for BlubModel: body box (7x6x7) at (0,0), ears at (0,13) and
    (6,13), feet at (12,13), tail at (20,13). Light from the top-left; a pale belly; two dark eyes
    with a catch-light, set high on the front face (the face is the body's front)."""
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    px = im.load()
    fur = [rgba("blub", i) for i in range(6)]
    n = tile_noise(32, 32, 8, 8, 131, ((1.0, 1), (0.5, 2)))

    def fill(x0, y0, w, h, base, light_top=True):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                i = base + (1 if n[y][x] > 0.72 else 0) - (1 if n[y][x] < 0.18 else 0)
                if light_top and y == y0:
                    i += 1
                px[x, y] = fur[max(0, min(5, i))]

    # Body box: top (7..14, 0..7), bottom (14..21, 0..7); sides row y 7..13: right, front, left, back.
    fill(7, 0, 7, 7, 4, light_top=False)     # top: lit
    fill(14, 0, 7, 7, 1, light_top=False)    # bottom: shaded
    fill(0, 7, 7, 6, 3)                      # right side (+x faces away from light)
    fill(7, 7, 7, 6, 3)                      # front: the face
    fill(14, 7, 7, 6, 2)                     # left side
    fill(21, 7, 7, 6, 2)                     # back
    # Face: eyes (1 x 2) at columns 1 and 5, a catch-light on top; a pale belly patch below.
    for ex in (8, 12):
        px[ex, 8] = rgba("particle", 3)
        px[ex, 9] = rgba("songwood_bark", 0)
    for x in range(9, 12):
        for y in range(10, 13):
            px[x, y] = fur[5] if y < 12 else fur[4]
    px[10, 9] = fur[2]  # a tiny mouth between the eyes
    # Ears (2 x 4 x 1): front faces lighter with a pale inner stripe.
    for ox in (0, 6):
        fill(ox, 13, 6, 5, 3)
        for y in range(14, 18):
            px[ox + 1, y] = fur[5]
    # Feet and tail: a shade darker.
    fill(12, 13, 8, 3, 2)
    fill(20, 13, 6, 3, 4)
    return im


def blub_glow_texture() -> Image.Image:
    """The emissive belly layer (mob_blub.md, Endure lantern): the same layout as blub.png, transparent
    except the belly patch on the front face (x 9..11, y 10..12) and a faint rim beside it."""
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    px = im.load()
    for x in range(9, 12):
        for y in range(10, 13):
            px[x, y] = rgba("membrane", 5 if (x == 10 and y == 11) else 4)
    for y in range(10, 13):  # a soft rim on each side of the belly
        px[8, y] = rgba("membrane", 4, 90)
        px[12, y] = rgba("membrane", 4, 90)
    return im


def blub_spawn_egg() -> Image.Image:
    rows = [
        "................",
        "......3443......",
        ".....344543.....",
        "....33445543....",
        "....33344443....",
        "...2333344443...",
        "...23e3333e43...",
        "...2333333333...",
        "...22335553332..",
        "...22335553332..",
        "....223335332...",
        "....22233332....",
        ".....222222.....",
        "......1111......",
        "................",
        "................",
    ]
    c = {str(i): rgba("blub", i) for i in range(6)}
    c["e"] = rgba("songwood_bark", 0)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                put(im, [(x, y)], c[ch])
    return im


# ---------------------------------------------------------------- particles
def glow_petal() -> Image.Image:
    rows = ["........", "...pp...", "..pPPp..", "..pPgp..", "...Pp...", "....p...", "........", "........"]
    c = {"p": rgba("healthy_sculk", 5), "P": rgba("healthy_sculk", 6), "g": rgba("particle", 3)}
    im = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                put(im, [(x, y)], c[ch])
    return im


def trill() -> Image.Image:
    rows = ["........", "........", "...a....", "..aba...", "...a....", "........", "........", "........"]
    c = {"a": rgba("particle", 1), "b": rgba("particle", 3)}
    im = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                put(im, [(x, y)], c[ch])
    return im


def main() -> None:
    save(hymnstone_pattern(), "block/hymnstone.png")
    save(hymnstone_pattern(seed=4), "block/hymnstone_2.png")
    save(hymnstone_pattern(seed=9), "block/hymnstone_3.png")
    save(hymnstone_bricks(), "block/hymnstone_bricks.png")
    save(healthy_sculk_top(), "block/healthy_sculk_top.png")
    save(healthy_sculk_top(seed=22), "block/healthy_sculk_top_2.png")
    save(healthy_sculk_top(seed=27), "block/healthy_sculk_top_3.png")
    save(healthy_sculk_side(), "block/healthy_sculk_side.png")
    save(plant(GRASS_SHORT), "block/healthy_sculk_grass.png")
    save(plant(GRASS_TALL_BOTTOM), "block/tall_healthy_sculk_grass_bottom.png")
    save(plant(GRASS_TALL_TOP), "block/tall_healthy_sculk_grass_top.png")
    save(songwood_log(), "block/songwood_log.png")
    save(songwood_log(variant=2), "block/songwood_log_2.png")
    save(songwood_log_top(), "block/songwood_log_top.png")
    save(songwood_planks(), "block/songwood_planks.png")
    save(songwood_leaves(), "block/songwood_leaves.png")
    save(songwood_leaves(seed=57), "block/songwood_leaves_2.png")
    save(songwood_sapling(), "block/songwood_sapling.png")
    save(tide_sand(), "block/tide_sand.png")
    save(tide_sand(seed=62), "block/tide_sand_2.png")
    save(tide_sand(seed=67), "block/tide_sand_3.png")
    save(tide_vent_top(), "block/tide_vent_top.png")
    save(tide_vent_side(), "block/tide_vent_side.png")
    save(gatestone(top=False), "block/gatestone.png")
    save(gatestone(top=True), "block/gatestone_top.png")
    save(strip(membrane_frames()), "block/sift_membrane.png")
    save_mcmeta("block/sift_membrane.png", '{\n  "animation": {\n    "frametime": 2,\n    "interpolate": true\n  }\n}\n')
    save(strip([ichor_frame(16, 16, f / 32, flow=False) for f in range(32)]), "block/ichor_still.png")
    save_mcmeta("block/ichor_still.png", '{\n  "animation": {\n    "frametime": 3\n  }\n}\n')
    save(strip([ichor_frame(32, 32, f / 32, flow=True) for f in range(32)]), "block/ichor_flow.png")
    save_mcmeta("block/ichor_flow.png", '{\n  "animation": {\n    "frametime": 2\n  }\n}\n')
    save(ichor_overlay(), "block/ichor_overlay.png")
    save(ichor_bucket(), "item/ichor_bucket.png")
    save(glow_petal(), "particle/glow_petal.png")
    save(blub_texture(), "entity/blub/blub.png")
    save(blub_glow_texture(), "entity/blub/blub_glow.png")
    save(blub_spawn_egg(), "item/blub_spawn_egg.png")
    save(trill(), "particle/trill.png")
    print("textures written")


if __name__ == "__main__":
    main()
