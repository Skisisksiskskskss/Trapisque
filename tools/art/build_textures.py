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



# ---------------------------------------------------------------- vanilla-style grain (owner playtest 2)
SOFTEN = 0.4
CONTRAST = 0.72


def grain(seed: int, w: int = W, h: int = H, clumps: float = 0.55, cells: int = 4, fine: int = 8,
          jitter: float = 0.35, soft: bool = True) -> list[list[float]]:
    """Vanilla's texture grain (owner playtest 2, D-026): small clumps (a coarse tileable noise) under
    per-pixel jitter, so neighbouring pixels differ but shades still gather into 2-4 px blotches, as on
    vanilla stone, dirt and grass. Seamless: every term wraps at the texture's edge."""
    coarse = tile_noise(w, h, cells, cells, seed, ((1.0, 1),))
    mid = tile_noise(w, h, fine, fine, seed + 1, ((1.0, 1),))
    rnd = random.Random(seed * 31 + 7)
    if soft:
        # Owner playtest 3: pixel-level noise read as harsh grain, and block-sized clumps repeat from
        # block to block; most of the weight goes to the 2 px blotches between them.
        jitter *= SOFTEN
        clumps *= 0.6
    rest = 1.0 - clumps - jitter
    return [[clumps * coarse[y][x] + rest * mid[y][x] + jitter * rnd.random() for x in range(w)] for y in range(h)]


def by_rank(values: list[list[float]], shares: list[float], soft: bool = True) -> list[list[int]]:
    """Assigns each pixel a band 0..len(shares)-1 by its rank, so each band covers its share of the
    texture whatever the noise's spread (a bell of shares keeps most pixels mid-tone)."""
    flat = sorted(v for row in values for v in row)
    total = sum(shares)
    cuts, acc = [], 0.0
    for sh in shares[:-1]:
        acc += sh / total
        cuts.append(flat[min(len(flat) - 1, int(acc * len(flat)))])
    bands = [[sum(v >= c for c in cuts) for v in row] for row in values]
    if not soft:
        return bands
    # Owner playtest 3: draw the bands closer together (fewer extreme shades), as vanilla's low-contrast
    # stone and dirt, so the blocks sit quietly beside vanilla's.
    mid = (len(shares) - 1) / 2
    return [[int(round(mid + (b - mid) * CONTRAST)) for b in row] for row in bands]


def paint(ramp: str, bands: list[list[int]], offset: int, w: int = W, h: int = H) -> Image.Image:
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = rgba(ramp, bands[y][x] + offset)
    return im


def lit(values: list[list[float]], x: int, y: int) -> float:
    """How much a pixel faces the light (top-left): its value against its lower-right neighbour's."""
    h, w = len(values), len(values[0])
    return values[y][x] - values[(y + 1) % h][(x + 1) % w]

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
    """Rose-mauve stone (owner playtest 2): vanilla stone's grain in seven close shades, gathered into
    small blotches, with a couple of dark pits and pale flecks as granite has. No strata: bands across
    a block lined up into stripes across a wall."""
    v = grain(seed, clumps=0.38, cells=4, fine=8, jitter=0.42)
    im = paint("hymnstone", by_rank(v, [0.04, 0.12, 0.22, 0.26, 0.22, 0.10, 0.04]), 1)
    for x, y in scatter(seed * 13 + 1, 2, 7.0):
        put(im, [(x, y)], rgba("hymnstone", 2))  # quiet pits and flecks (owner playtest 3)
    for x, y in scatter(seed * 17 + 3, 2, 6.0):
        put(im, [(x, y)], rgba("hymnstone", 6))
    return im


def hymnstone_bricks() -> Image.Image:
    """Hymnstone bricks, as vanilla stone bricks: two courses of offset bricks of the stone's grain,
    each brick a shade of its own, lit on its top and left edges, shaded on its bottom and right,
    with dark mortar between."""
    v = grain(11, clumps=0.4, cells=4, fine=8, jitter=0.4)
    bands_ = by_rank(v, [0.15, 0.3, 0.35, 0.2])
    im = Image.new("RGBA", (W, H))
    px = im.load()
    rnd = random.Random(11)
    courses = ((0, 6, (11,)), (8, 14, (3,)))
    for y0, y1, joints in courses:
        starts = sorted([0] + [j + 1 for j in joints])
        ends = sorted([j - 1 for j in joints] + [W - 1])
        for sx, ex in zip(starts, ends):
            base = 3 + rnd.choice((0, 0, 1))
            for y in range(y0, y1 + 1):
                for x in range(sx, ex + 1):
                    i = base + bands_[y][x] - 1
                    if y == y0 or x == sx:
                        i += 1
                    if y == y1 or x == ex:
                        i -= 1
                    px[x, y] = rgba("hymnstone", max(1, min(8, i)))
        for jx in joints:
            for y in range(y0, y1 + 1):
                px[jx, y] = rgba("hymnstone", 1 if (y + jx) % 3 else 0)
    for y in (7, 15):
        for x in range(W):
            px[x, y] = rgba("hymnstone", 1 if (x * 7 + y) % 5 else 0)
    return im


# ---------------------------------------------------------------- healthy sculk

def healthy_sculk_top(seed: int = 21) -> Image.Image:
    """The teaser's pink-coral grass top (owner playtest 2): vanilla grass's fine speckle in seven
    shades, mostly single pixels and pairs, with a faint drift of lighter and darker patches; the
    blockstates add random rotations as vanilla grass does."""
    v = grain(seed, clumps=0.35, cells=4, fine=8, jitter=0.45)
    return paint("healthy_sculk", by_rank(v, [0.05, 0.12, 0.2, 0.25, 0.2, 0.12, 0.06]), 1)


def healthy_sculk_side() -> Image.Image:
    """Grass over soil, as vanilla's grass block side: the pink top hangs 2 to 4 pixels over the
    maroon soil, its edge broken into short drips, with a pixel of shadow under it."""
    im = sift_soil(seed=5)
    top = healthy_sculk_top(seed=23)
    tp, ip = top.load(), im.load()
    rnd = random.Random(5)
    depth = [3, 3, 2, 4, 3, 3, 4, 2, 3, 5, 3, 2, 3, 4, 3, 3]
    for x in range(W):
        d = depth[x]
        for y in range(d):
            ip[x, y] = tp[x, (y + 5) % H]
        if rnd.random() < 0.7:
            ip[x, d] = rgba("soil", 0)
    return im


def sift_soil(seed: int = 7) -> Image.Image:
    """Sift soil, the earth under the grass (owner playtest 2): vanilla dirt's grain in maroon, six
    shades in small clumps, with two or three pale pebbles shadowed below."""
    v = grain(seed, clumps=0.4, cells=4, fine=8, jitter=0.45)
    im = paint("soil", by_rank(v, [0.06, 0.16, 0.28, 0.28, 0.16, 0.06]), 1)
    for x, y in scatter(seed * 3 + 1, 3, 6.5):
        put(im, [(x, y)], rgba("soil", 7))
        put(im, [(x, y + 1)], rgba("soil", 1))
    return im


def tuft(height_px: int, blades: int, seed: int) -> Image.Image:
    """A tuft of the teaser's pink grass on a 16 × height_px canvas: thin blades, one or two pixels
    wide, of different heights and leans, each shaded dark at the root to light at the tip with a few
    pixels of its own grain, as vanilla's short grass is drawn."""
    rnd = random.Random(seed)
    im = Image.new("RGBA", (W, height_px), (0, 0, 0, 0))
    px = im.load()
    order = sorted(range(blades), key=lambda b: rnd.random())
    for b in order:
        x0 = 2.0 + rnd.random() * 12
        length = height_px * (0.45 + 0.55 * rnd.random())
        lean = (x0 - 8) / 8 * (0.1 + 0.2 * rnd.random()) + (rnd.random() - 0.5) * 0.15
        wide = rnd.random() < 0.45
        for t in range(int(length)):
            y = height_px - 1 - t
            frac = t / length
            x = x0 + lean * t
            i = 1 + int(frac * 6.5)
            i += rnd.choice((-1, 0, 0, 0, 1))
            xs = [int(round(x))] + ([int(round(x)) + 1] if wide and frac < 0.6 else [])
            for k, xx in enumerate(xs):
                if 0 <= xx < W:
                    px[xx, y] = rgba("healthy_sculk", max(0, min(7, i - k)))
    return im


def plant(kind: str) -> Image.Image:
    """Short grass (one block) or the two halves of tall grass (owner rework, after the teaser)."""
    if kind == "short":
        return tuft(16, 10, 11)
    tall = tuft(32, 15, 13)
    return tall.crop((0, 16, 16, 32)) if kind == "tall_bottom" else tall.crop((0, 0, 16, 16))

# ---------------------------------------------------------------- songwood
FLUTE_HOLE = [  # 2×3 hole: lip (L) on the lit top-left, bore (b), shaded rim (l)
    "Lb",
    "Lb",
    "lb",
]


FLUTE_SPOTS = {1: ((4, 3), (11, 11)), 2: ((2, 9), (12, 2))}


def songwood_log(variant: int = 1) -> Image.Image:
    """The teasers' dark trunks (owner playtest 2): vanilla bark, long broken vertical furrows (the
    darkest shades) between ridges lit on their left edge, in charcoal-teal. Variant 2 keeps one small
    flute hole, songwood's mark (the wind whistles through it, items.md)."""
    seed = 31 + variant * 100
    ridge = tile_noise(W, H, 8, 2, seed, ((1.0, 1), (0.5, 2)))
    rnd = random.Random(variant)
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            v = 0.7 * ridge[y][x] + 0.3 * rnd.random()
            if v < 0.3:
                i = 1
            elif v < 0.42:
                i = 2
            else:
                i = 3 + (1 if v > 0.6 else 0) + (1 if v > 0.78 else 0)
                if ridge[y][(x - 1) % W] < 0.35:
                    i += 1  # the lit lip of a furrow
            px[x, y] = rgba("songwood_bark", min(7, i))
    if variant == 2:
        c = {"L": rgba("flute", 0), "l": rgba("songwood_bark", 5), "b": rgba("songwood_bark", 0)}
        for dy, row in enumerate(FLUTE_HOLE):
            for dx, ch in enumerate(row):
                put(im, [(9 + dx, 6 + dy)], c[ch])
    return im


def songwood_log_top() -> Image.Image:
    """The cut end: growth rings in the planks' tones that wobble a little, as vanilla log ends do, a
    bark rim, and the hollow core (songwood's branches are flutes)."""
    wob = tile_noise(W, H, 4, 4, 77, ((1.0, 1),))
    rnd = random.Random(77)
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            d = max(abs(x - 7.5), abs(y - 7.5)) * 0.7 + math.hypot(x - 7.5, y - 7.5) * 0.3
            if max(abs(x - 7.5), abs(y - 7.5)) > 6.5:
                px[x, y] = rgba("songwood_bark", rnd.choice((2, 3, 3, 4)))
                continue
            r = d + (wob[y][x] - 0.5) * 1.2
            ring = int(r) % 3
            px[x, y] = rgba("songwood_planks", (2, 3, 4)[ring] + (1 if rnd.random() < 0.15 else 0))
    put(im, [(7, 7), (8, 7), (7, 8), (8, 8)], rgba("songwood_bark", 0))
    put(im, [(6, 7), (7, 6), (8, 6), (6, 8)], rgba("flute", 0))
    put(im, [(9, 7), (9, 8), (7, 9), (8, 9)], rgba("songwood_planks", 1))
    return im


def songwood_planks() -> Image.Image:
    """Teal-grey planks, as vanilla's: four boards four pixels tall, each with long grain streaks of
    its own shade, a dark seam under it and offset end joints."""
    grain_ = tile_noise(W, H, 2, 8, 41, ((1.0, 1), (0.5, 2)))
    rnd = random.Random(41)
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for b, jx in enumerate((5, 12, 2, 9)):
        y0 = b * 4
        base = 3 + rnd.choice((0, 0, 1))
        for y in range(y0, y0 + 3):
            for x in range(W):
                g = grain_[y][x]
                i = base + (1 if g > 0.68 else 0) - (1 if g < 0.3 else 0)
                if y == y0 and rnd.random() < 0.5:
                    i += 1
                px[x, y] = rgba("songwood_planks", max(1, min(5, i)))
        for x in range(W):
            px[x, y0 + 3] = rgba("songwood_planks", 1 if (x + b) % 4 else 0)
        for y in range(y0, y0 + 3):
            px[jx, y] = rgba("songwood_planks", 1)
    return im


def songwood_leaves(seed: int = 63) -> Image.Image:
    """The teasers' pale canopy, drawn as vanilla draws leaves (owner playtest 3: the clump version
    read as cobble, and darker than the drapes): a fine per-pixel grain in the ramp's pale end, small
    leaf dabs lit on the upper left with a shade below, and scattered gaps where the sky shows
    through. The same pale shades as the drapes, so canopy and strands read as one tree."""
    rnd = random.Random(seed)
    v = grain(seed, clumps=0.35, cells=4, fine=8, jitter=0.55)
    bands = by_rank(v, [0.06, 0.18, 0.32, 0.28, 0.16])
    im = paint("songwood_leaves", bands, 3)
    px = im.load()
    for x, y in scatter(seed * 5 + 3, 22, 2.6):  # leaf dabs
        px[x % W, y % H] = rgba("songwood_leaves", 7)
        px[(x + 1) % W, y % H] = rgba("songwood_leaves", 6)
        px[(x + 1) % W, (y + 1) % H] = rgba("songwood_leaves", 3)
    # Fewer, evenly spread gaps (owner playtest 4): pixel noise over the canopy's dark inside read as
    # black speckle on these pale leaves. Single pixels and pairs, spaced apart as vanilla's leaf gaps.
    gaps = set()
    for k, (x, y) in enumerate(scatter(seed * 3 + 11, 14, 3.4)):
        gaps.add((x % W, y % H))
        if k % 2 == 0:
            gaps.add(((x + 1) % W, y % H))
    for y in range(H):
        for x in range(W):
            if (x, y) in gaps:
                # A gap keeps a deep leaf colour under zero alpha, as vanilla's leaves do (mipmaps and
                # Fast graphics read it).
                px[x, y] = rgba("songwood_leaves", 2, 0)
            elif rnd.random() < 0.04:
                px[x, y] = rgba("songwood_leaves", 2)  # a deep shadow pixel now and then, as vanilla's
    return im


def songwood_drapes(tip: bool) -> Image.Image:
    """Pale strands hanging under the canopy ("towering tree-like growths covered in pale-blue
    vines", the Meadow's canon), as vanilla's hanging moss and vines are drawn: strands that start
    where they like and wander, with small leaf nubs, darker where they cross; the tip frays out."""
    rnd = random.Random(71 if tip else 73)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    starts = sorted(rnd.sample(range(1, 15), 8))
    for x0 in starts:
        x = x0
        length = H if not tip else rnd.randint(4, 14)
        for y in range(length):
            if 0 <= x < W:
                shade = 4 + rnd.choice((-1, 0, 0, 1, 1, 2))
                if px[x, y][3]:
                    shade = 2  # where strands cross
                if tip and y > length - 3:
                    shade -= 1
                px[x, y] = rgba("songwood_leaves", max(3, min(7, shade)))
                if rnd.random() < 0.2:
                    nx = x + rnd.choice((-1, 1))
                    if 0 <= nx < W and not px[nx, y][3]:
                        px[nx, y] = rgba("songwood_leaves", rnd.choice((3, 5, 6)))
            if rnd.random() < 0.3:
                x += rnd.choice((-1, 1))
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


# ---------------------------------------------------------------- flora II (block_flora_ii.md, WP-064)
def _blank() -> Image.Image:
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def _set(im: Image.Image, x: int, y: int, colour) -> None:
    if 0 <= x < W and 0 <= y < H:
        im.load()[x, y] = colour


def _ribbons(seed: int, count: int, length: tuple[float, float], curl: float, underside: bool, stems: bool = False) -> Image.Image:
    """Wrack ribbons lying flat, seen from above: each runs out from near the centre with a wobble,
    olive at the root and ochre at the tip; an open frond shows its sea-green underside along one edge."""
    rnd = random.Random(seed)
    im = _blank()
    base = rnd.random() * math.tau
    for i in range(count):
        a = base + i * math.tau / count + rnd.uniform(-0.35, 0.35)
        n = rnd.uniform(*length)
        phase = rnd.random() * math.tau
        steps = int(n * 3)
        for k in range(steps + 1):
            t = k / steps
            r = 0.8 + t * n
            ang = a + curl * math.sin(phase + t * 3.0) * t
            x, y = 7.5 + r * math.cos(ang), 7.5 + r * math.sin(ang)
            shade = 1 + int(t * 6.99) if not stems else 4 + int(t * 2.99)
            _set(im, int(round(x)), int(round(y)), rgba("tidewrack", min(7, shade)))
            if not stems:
                nx, ny = -math.sin(ang), math.cos(ang)
                edge = rgba("tidewrack_underside", min(2, int(t * 2.99))) if underside else rgba("tidewrack", max(0, shade - 2))
                _set(im, int(round(x + nx)), int(round(y + ny)), edge)
    return im


def tidewrack(state: str) -> Image.Image:
    if state == "open":
        return _ribbons(311, 7, (4.5, 7.0), 0.5, underside=True)
    if state == "closed":
        return _ribbons(312, 6, (1.8, 3.2), 2.4, underside=False)
    return _ribbons(313, 7, (2.5, 4.5), 0.3, underside=False, stems=True)


def tidewrack_knot() -> Image.Image:
    """The closed knot seen from the side: a low lump of curled ribbon, 3 px high."""
    rows = [
        "......3434......",
        "....24543532....",
        "...1232121232...",
    ]
    im = _blank()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                _set(im, x, 13 + y, rgba("tidewrack", int(ch)))
    return im


def _petals(count: int, length: float, width: float, ramp: str, shades, seed: int, offset: float = 0.0,
            outline_only: bool = False, outline_ramp: str | None = None) -> Image.Image:
    """Pointed petals radiating flat from the centre, seen from above: darker at the base, lighter toward
    the tip, the edge one shade lighter (light from the top-left)."""
    im = _blank()
    rnd = random.Random(seed)
    for y in range(H):
        for x in range(W):
            dx, dy = x + 0.5 - 8.0, y + 0.5 - 8.0
            r = math.hypot(dx, dy)
            if r > length + 0.5 or r < 0.01:
                continue
            ang = math.atan2(dy, dx) - offset
            sector = math.tau / count
            rel = (ang + sector / 2) % sector - sector / 2
            half = width * (1 - (r / (length + 0.5)) ** 1.6) * (0.55 + 0.45 * min(1.0, r / 2.0))
            dist = abs(rel) * r
            if dist > half:
                continue
            edge = dist > half - 0.9 or r > length - 0.4
            t = r / length
            if outline_only:
                if edge:
                    _set(im, x, y, rgba(outline_ramp or ramp, shades[-1]))
                continue
            i = shades[min(len(shades) - 1, int(t * len(shades)))]
            if edge:
                i = min(len(RAMPS[ramp]) - 1, i + 1)
            if rnd.random() < 0.08:
                i = max(0, i - 1)
            _set(im, x, y, rgba(ramp, i))
    return im


def _centre(im: Image.Image, ramp: str, shades) -> None:
    for (x, y), i in zip([(7, 7), (8, 7), (7, 8), (8, 8)], shades):
        _set(im, x, y, rgba(ramp, i))


def endure_bloom(state: str) -> Image.Image:
    if state == "closed":
        im = _petals(6, 5.2, 2.2, "endure_leaf", [1, 2, 2, 3], 401)
        _centre(im, "endure_leaf", [0, 1, 1, 0])
        return im
    if state == "picked":
        im = _petals(8, 3.6, 1.2, "endure_leaf", [1, 2, 3], 402, offset=math.pi / 8)
        _centre(im, "endure_leaf", [0, 0, 1, 0])
        return im
    im = _petals(8, 3.4, 1.4, "endure_leaf", [1, 2, 3], 403, offset=math.pi / 8)
    star = _petals(8, 7.3, 2.0, "endure_petal", [1, 2, 3, 4, 5], 404)
    im.alpha_composite(star)
    _centre(im, "endure_petal", [6, 5, 5, 6])
    return im


def endure_bloom_emissive() -> Image.Image:
    """Only the centre and the petal edges glow: a thin cool outline of the star."""
    im = _petals(8, 7.3, 2.0, "endure_petal", [5], 404, outline_only=True)
    _centre(im, "endure_petal", [6, 6, 6, 6])
    return im


def glowcap() -> Image.Image:
    """Three small flat-topped caps on short stems, ankle-high: shelves, never a dome."""
    im = _blank()
    caps = [(5, 9, 5, 11), (1, 11, 4, 13), (10, 12, 5, 14)]  # x, top y, width, stem bottom start
    for x0, top, w, _ in caps:
        stem_x = x0 + w // 2
        for y in range(top + 2, 16):
            _set(im, stem_x, y, rgba("glowcap_stem", 1 if y % 2 else 2))
        for x in range(x0, x0 + w):
            _set(im, x, top, rgba("glowcap", 4 if x == x0 else 3 if x < x0 + w - 1 else 2))
            _set(im, x, top + 1, rgba("glowcap_stem", 0 if x in (x0, x0 + w - 1) else 1))
        _set(im, x0 + 1, top, rgba("glowcap", 4))
    return im


def chime_bell_flower(ringing: bool = False) -> Image.Image:
    """An arched stem with three bells hanging mouth-down from its curve, at staggered heights; each
    bell narrow at the top and open at the mouth, the dark inside showing. Ringing, they swing."""
    im = _blank()
    arch = [(3, y) for y in range(15, 5, -1)] + [(4, 5), (5, 4), (6, 4), (7, 4), (8, 4), (9, 4), (10, 4), (11, 4), (12, 5), (13, 5)]
    for i, (x, y) in enumerate(arch):
        _set(im, x, y, rgba("chime_stem", 2 if i % 3 else 3))
    for x, y in [(2, 13), (1, 12), (4, 11), (5, 10)]:  # two leaves low on the stem
        _set(im, x, y, rgba("chime_stem", 3 if y < 12 else 2))
    swing = 1 if ringing else 0
    for cx, top in [(6, 7), (10, 6), (13, 8)]:
        for y in range(5, top):
            _set(im, cx, y, rgba("chime_stem", 1))
        x = cx + swing
        _set(im, x, top, rgba("chime_bell", 3))
        for dx, i in [(-1, 4), (0, 3), (1, 2)]:
            _set(im, x + dx, top + 1, rgba("chime_bell", i))
        for dx, i in [(-1, 3), (0, 1), (1, 1)]:
            _set(im, x + dx, top + 2, rgba("chime_bell", i))
        _set(im, x - 1, top + 3, rgba("chime_bell", 2))
        _set(im, x, top + 3, rgba("chime_stem", 0))
        _set(im, x + 1, top + 3, rgba("chime_bell", 0))
    return im


def lumen_bloom() -> Image.Image:
    """Three broad glassy petals splayed flat, seen from above: separate ovals around a white core,
    pale at the rim (glass catching the light), deeper blue toward the middle."""
    im = _blank()
    for k in range(3):
        a = -math.pi / 2 + k * math.tau / 3
        cx, cy = 8.0 + 4.0 * math.cos(a), 8.0 + 4.0 * math.sin(a)
        for y in range(H):
            for x in range(W):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                along = dx * math.cos(a) + dy * math.sin(a)
                across = -dx * math.sin(a) + dy * math.cos(a)
                d = (along / 3.6) ** 2 + (across / 2.4) ** 2
                if d <= 1.0:
                    _set(im, x, y, rgba("lumen", 4 if d > 0.62 else 3 if d > 0.3 else 2))
    _centre(im, "lumen", [5, 5, 4, 5])
    return im


def lumen_bloom_core() -> Image.Image:
    """The bloom from the side: a low bright core, the petal edges rising either side."""
    rows = [
        "......4554......",
        ".23..345543..32.",
        "..2334444443322.",
    ]
    im = _blank()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                _set(im, x, 13 + y, rgba("lumen", int(ch)))
    return im


def _rows(im: Image.Image, x0: int, y0: int, rows: list[str], key: dict) -> None:
    """Paints a character map at (x0, y0): each character names a (ramp, shade) in key; '.' is clear."""
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                ramp, shade = key[ch]
                _set(im, x0 + x, y0 + y, rgba(ramp, shade))


_LANTERN_KEY = {
    "d": ("hymnstone", 1), "m": ("hymnstone", 3), "l": ("hymnstone", 5), "h": ("hymnstone", 7),
    "1": ("lumen", 1), "2": ("lumen", 2), "3": ("lumen", 3), "4": ("lumen", 4), "5": ("lumen", 5),
}


def lumen_lantern() -> Image.Image:
    """The lumen lantern in vanilla's lantern layout (template_lantern UVs): a hymnstone frame and cap
    around pale glass, a bloom-white flame at its heart. Few shades, no grain: it should read at a glance."""
    im = _blank()
    _rows(im, 1, 0, ["mllm", "dmmd"], _LANTERN_KEY)              # cap sides
    _rows(im, 0, 2, ["dmllmd",                                     # body sides
                     "m2332m",
                     "l3453l",
                     "l3553l",
                     "m2443m",
                     "m1221m",
                     "dmmmmd"], _LANTERN_KEY)
    _rows(im, 0, 9, ["dmmmmd",                                     # body top and bottom, cap top inside
                     "mlhhlm",
                     "mhllhm",
                     "mhllhm",
                     "mlhhlm",
                     "dmmmmd"], _LANTERN_KEY)
    _rows(im, 11, 1, ["mlm", "d.d"], _LANTERN_KEY)                 # handle
    _rows(im, 11, 10, ["mlm", "d.d"], _LANTERN_KEY)
    return im


def lumen_lantern_item() -> Image.Image:
    """The lantern as an item: the handle, the cap, the glowing glass, as vanilla's lantern icon stands."""
    im = _blank()
    _rows(im, 5, 1, ["..mlm.",
                     "..d.d.",
                     ".mllm.",
                     ".dmmd.",
                     "dmllmd",
                     "m2332m",
                     "l3453l",
                     "l3553l",
                     "l3453l",
                     "m2443m",
                     "m1221m",
                     "dmmmmd"], _LANTERN_KEY)
    return im


def ichor_lily() -> Image.Image:
    """The ichor lily's pad (D-029), drawn as vanilla's lily pad: a round leaf with a notch cut to its
    centre and veins running out from it, darker at the rim, a few soft blotches, no hard grain."""
    im = _blank()
    rnd = random.Random(17)
    shade = grain(17, clumps=0.4, cells=4, fine=8, jitter=0.2)
    notch = math.radians(-60)
    for y in range(H):
        for x in range(W):
            dx, dy = x + 0.5 - 8.0, y + 0.5 - 8.0
            d = math.hypot(dx, dy)
            if d > 7.6:
                continue
            a = math.atan2(dy, dx)
            if d > 1.2 and abs((a - notch + math.pi) % math.tau - math.pi) < 0.22:
                continue  # the notch
            i = 3 + (1 if shade[y][x] > 0.55 else 0) - (1 if d > 6.4 else 0)
            vein = min(abs((a * 5 / math.pi + 0.5) % 1.0 - 0.5), 0.5)  # ten veins from the centre
            if vein < 0.08 and 1.5 < d < 6.6:
                i = 2
            if d > 7.0:
                i = 1
            if rnd.random() < 0.03:
                i = max(1, i - 1)
            _set(im, x, y, rgba("ichor_lily", i))
    return im


def ichor_lily_bud() -> Image.Image:
    """The bud standing on the pad, seen from the side (a cross model): a closed lilac flower on a short
    teal stem, pale at its tip where it glows."""
    rows = [
        "......4.....",
        ".....343....",
        ".....232....",
        "....12321...",
        "....01210...",
        ".....s0s....",
        "......s.....",
    ]
    im = _blank()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "s":
                _set(im, 2 + x, 9 + y, rgba("ichor_lily", 3))
            elif ch != ".":
                _set(im, 2 + x, 9 + y, rgba("ichor_lily_bud", int(ch)))
    return im


def ichor_lily_item() -> Image.Image:
    """The lily as an item: the pad with the bud on it."""
    im = ichor_lily()
    bud = ichor_lily_bud()
    for y in range(9, 16):
        for x in range(W):
            p = bud.getpixel((x, y))
            if p[3]:
                _set(im, x, y - 6, p)
    return im


def glimmer() -> Image.Image:
    """A glimmer (D-029), drawn as vanilla's firefly: a tiny bright point, here lilac-white."""
    im = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    im.putpixel((0, 0), rgba("ichor_lily_bud", 4))
    return im


def tidewrack_frond() -> Image.Image:
    """One frond, as an item: a wavy ribbon, olive to ochre, its sea-green underside along one edge."""
    im = _blank()
    for k in range(40):
        t = k / 39
        x = 2 + t * 11
        y = 13 - t * 11 + 1.2 * math.sin(t * 7.0)
        _set(im, int(round(x)), int(round(y)), rgba("tidewrack", 2 + int(t * 5.99)))
        _set(im, int(round(x)) + 1, int(round(y)), rgba("tidewrack_underside", min(2, int(t * 2.99))))
    return im


def endure_petal_item() -> Image.Image:
    """One petal, as an item: a pointed oval, periwinkle at the base to pale blue at the tip."""
    im = _blank()
    for y in range(H):
        for x in range(W):
            u = (x - 2) / 12.0
            v = (y - 13) / -12.0
            along = (u + v) / 2
            across = (u - v)
            if not 0 <= along <= 1:
                continue
            half = 0.34 * math.sin(math.pi * along) ** 0.8
            if abs(across) > half:
                continue
            i = 1 + int(along * 4.99)
            if abs(across) > half - 0.09:
                i = min(6, i + 1)
            _set(im, x, y, rgba("endure_petal", i))
    return im



# ---------------------------------------------------------------- tide basin
def tide_sand(seed: int = 61) -> Image.Image:
    """Fine grey-violet silt, as vanilla sand: a soft grain in five close shades with scattered darker
    and lighter single grains (no ripple marks: they lined up from block to block)."""
    v = grain(seed, clumps=0.3, cells=4, fine=8, jitter=0.5)
    im = paint("tide_sand", by_rank(v, [0.08, 0.22, 0.4, 0.22, 0.08]), 1)
    for x, y in scatter(seed * 7 + 1, 5, 4.0):
        put(im, [(x, y)], rgba("tide_sand", 0))
    for x, y in scatter(seed * 7 + 2, 4, 4.0):
        put(im, [(x, y)], rgba("tide_sand", 6))
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
# Ten tileable waves for ichor's shimmer: whole-number frequencies in many directions, so the field
# tiles exactly yet has no lattice; each drifts at its own whole-number speed, so the loop closes.
_ICHOR_WAVES = [(1, 0), (0, 1), (1, 1), (1, -1), (2, 1), (1, -2), (2, -1), (1, 2), (3, 1), (1, 3)]
_ICHOR_RND = random.Random(214)
_ICHOR_PHASES = [(_ICHOR_RND.random(), _ICHOR_RND.choice([-2, -1, 1, 2]), 1.0 / (1 + 0.5 * (abs(a) + abs(b))))
                 for a, b in _ICHOR_WAVES]


# The ichor film (owner playtest 5): the colour bands must move. Vertex colours are fixed when a chunk
# is meshed, so the moving colour lives in an animated texture instead: an 8 x 8-block seamless tile
# that still ichor maps by world position (thesift.client.IchorSheen), so the pattern spans many blocks.
ICHOR_FILM_TILE = 8
ICHOR_FILM_FRAMES = 32
_FILM_WALK = [2, 3, 4, 5, 4, 3, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 0, 1]


def ichor_film() -> Image.Image:
    """The soap-film colours of still ichor, animated. Two swirled layers drift across the tile in
    different directions (one tile per loop each, so the loop and the tile both stay seamless) and
    interfere, so the bands wander and change shape rather than slide; a rare pale glint rides on them.
    Drawn in the ichor ramp's film stops only, as pixel-art bands."""
    size = 16 * ICHOR_FILM_TILE
    tau2 = 2 * math.pi
    im = Image.new("RGBA", (size, size * ICHOR_FILM_FRAMES))
    px = im.load()
    for f in range(ICHOR_FILM_FRAMES):
        t = tau2 * f / ICHOR_FILM_FRAMES
        for y in range(size):
            Z = tau2 * (y + 0.5) / size
            for x in range(size):
                X = tau2 * (x + 0.5) / size
                a = X - t + 1.1 * math.sin(Z + t + 1.3) + 0.4 * math.sin(2 * Z - X + t)
                b = Z + t + 1.1 * math.sin(X - t + 0.7) + 0.4 * math.sin(2 * X + Z - 2 * t + 2.0)
                p = 1.6 * (0.5 + 0.28 * math.sin(a + b) + 0.22 * math.sin(2 * a - b + 1.7))
                s = (p - math.floor(p)) * len(_FILM_WALK)
                colour = rgba("ichor", _FILM_WALK[int(s) % len(_FILM_WALK)], 214)
                if math.sin(3 * a + 2 * b - t) * math.sin(2 * a - 3 * b + 2 * t) > 0.92:
                    colour = rgba("ichor_sheen", 6, 214)
                px[x, f * size + y] = colour
    return im


def ichor_frame(w: int, h: int, t: float, flow: bool) -> Image.Image:
    """Ichor (owner playtest 2, D-026): a faint, pale shimmer, as vanilla's water texture is grey.
    The colour is laid on as it is drawn (thesift.client.IchorSheen), which lays a soap bubble's bands across
    the whole pond, so this texture must not draw a pattern of its own that repeats block to block:
    ten soft waves interfere into a smooth field drawn in only three close shades, with a rare
    highlight where the field peaks. Alpha 214, a little less see-through than water."""
    tau = 2 * math.pi
    vals = []
    for y in range(h):
        for x in range(w):
            u, v = x / w, y / h
            if flow:
                v -= t
            vals.append(sum(amp * math.sin(tau * (a * u + b * v + phase + speed * t))
                            for (a, b), (phase, speed, amp) in zip(_ICHOR_WAVES, _ICHOR_PHASES)))
    lo, hi = min(vals), max(vals)
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            n = (vals[y * w + x] - lo) / (hi - lo)
            shade = 6 if n > 0.93 else 5 if n > 0.72 else 4 if n > 0.35 else 3
            px[x, y] = rgba("ichor_sheen", shade, 214)
    return im


def ichor_overlay() -> Image.Image:
    """The face of ichor seen through glass or leaves, as vanilla's water overlay: the body, fainter."""
    im = ichor_frame(16, 16, 0.0, flow=False)
    px = im.load()
    for y in range(16):
        for x in range(16):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 150)
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
def box_faces(u: int, v: int, w: int, h: int, d: int) -> dict[str, tuple[int, int, int, int]]:
    """The UV rectangles (x, y, width, height) of a model box at texOffs(u, v), vanilla's layout."""
    return {
        "top": (u + d, v, w, d), "bottom": (u + d + w, v, w, d),
        "right": (u, v + d, d, h), "front": (u + d, v + d, w, h),
        "left": (u + d + w, v + d, d, h), "back": (u + 2 * d + w, v + d, w, h),
    }


def blub_texture() -> Image.Image:
    """64 x 32, laid out for BlubModel, drawn as vanilla draws its mobs (owner playtest 3, D-029: "drawn
    more like vanilla, less cell shaded"): every face a soft gradient, lit at the top and shaded toward
    the ground, with low-contrast fur clumps; round dark eyes with a catch-light, a small mouth always
    there, a touch of blush; paler inner ears, darker feet, a fluffy pale tail."""
    im = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    px = im.load()
    fur = [rgba("blub_fur", i) for i in range(10)]
    clumps = grain(131, w=64, h=32, clumps=0.5, cells=8, fine=16, jitter=0.25)
    dither = random.Random(137)

    def paint_face(rect, top_shade, bottom_shade):
        x0, y0, w, h = rect
        for y in range(y0, y0 + h):
            k = (y - y0) / max(1, h - 1)
            base = top_shade + (bottom_shade - top_shade) * k
            for x in range(x0, x0 + w):
                v = clumps[y][x]
                # Fur clumps and a little dither break the gradient's rows, as on vanilla's mobs.
                i = base + (0.8 if v > 0.66 else -0.8 if v < 0.32 else 0.0) + (dither.random() - 0.5) * 0.7
                px[x, y] = fur[max(0, min(9, int(round(i))))]

    body = box_faces(0, 0, 9, 7, 8)
    paint_face(body["top"], 8, 7)
    paint_face(body["bottom"], 2, 2)
    for face in ("right", "front", "left", "back"):
        paint_face(body[face], 6.8, 3.6)
    for u in (36, 42):  # ears: lit at the tip, a pale inner face
        ear = box_faces(u, 0, 2, 5, 1)
        for face, rect in ear.items():
            paint_face(rect, 8, 4)
        x0, y0, w, h = ear["front"]
        for y in range(y0 + 1, y0 + h - 1):
            px[x0, y] = fur[9]
            px[x0 + 1, y] = fur[8]
    for face, rect in box_faces(48, 0, 2, 1, 2).items():  # feet
        paint_face(rect, 3, 1)
    for face, rect in box_faces(36, 8, 2, 2, 1).items():  # tail tuft
        paint_face(rect, 9, 7)
    fx, fy, fw, fh = body["front"]
    # Eyes: 2 x 2, dark violet, a catch-light at the upper outer corner.
    for ex, light_x in ((fx + 1, fx + 1), (fx + 6, fx + 7)):
        for dx in (0, 1):
            put(im, [(ex + dx, fy + 3)], rgba("blub_eye", 0))
            put(im, [(ex + dx, fy + 4)], rgba("blub_eye", 1 if dx == (1 if ex == fx + 1 else 0) else 0))
        put(im, [(light_x, fy + 3)], rgba("blub_eye", 2))
    # A small mouth between and below the eyes, always there; cheeks just outside it.
    put(im, [(fx + 3, fy + 5), (fx + 5, fy + 5)], rgba("blub_mouth", 1))
    put(im, [(fx + 4, fy + 5)], rgba("blub_mouth", 0))
    put(im, [(fx + 1, fy + 5), (fx + 7, fy + 5)], rgba("blub_blush", 0))
    return im


def blub_glow_texture() -> Image.Image:
    """The belly glow in Endure (emissive), on the body's bottom face."""
    im = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    px = im.load()
    body = box_faces(0, 0, 9, 7, 8)
    x0, y0, w, h = body["bottom"]
    for y in range(y0 + 1, y0 + h - 1):
        for x in range(x0 + 1, x0 + w - 1):
            px[x, y] = rgba("membrane", 4 if (x + y) % 3 else 5)
    return im  # the belly only: a lit strip on the front read as a mouth that came out at night (D-029)


# The Nester (D-034: redrawn after Dungeons II's render): a big boxy head split at the mouth, teal above
# and tan below, navy eyes at its front corners, two feathery antennae; a thin neck on four long legs
# with tan feet. Model boxes (NesterModel): head 10x5x10 at (0, 0), jaw 10x5x10 at (0, 15), neck 5x9x4
# at (40, 0), leg 3x10x3 at (0, 30), antenna plane 0x8x5 at (16, 30).
_NESTER_HEAD, _NESTER_JAW = (0, 0, 10, 5, 10), (0, 15, 10, 5, 10)
_NESTER_NECK, _NESTER_LEG, _NESTER_ANTENNA = (40, 0, 5, 9, 4), (0, 30, 3, 10, 3), (16, 30, 0, 8, 5)


def nester_texture(soul: bool = False) -> Image.Image:
    """64 x 64 for NesterModel. Drawn as vanilla's mobs are: each face a shade lit on top and darker
    below, with small clumps. `soul`: the enduring Nester, pale glowing cyan as Dungeons II's soul
    corrupted Nester."""
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    px = im.load()
    hide_ramp = "nester_soul" if soul else "nester"
    hide = [rgba(hide_ramp, i) for i in range(6)]
    jaw = [rgba("nester_soul", i) for i in (2, 3, 3, 4, 5)] if soul else [rgba("nester_jaw", i) for i in range(5)]
    mouth = [rgba("nester_mouth", i) for i in range(4)]
    clumps = grain(211, w=64, h=64, clumps=0.5, cells=16, fine=32, jitter=0.25)
    dither = random.Random(213)

    def face(rect, top, bottom, ramp):
        x0, y0, w, h = rect
        for y in range(y0, y0 + h):
            k = (y - y0) / max(1, h - 1)
            base = top + (bottom - top) * k
            for x in range(x0, x0 + w):
                v = clumps[y][x]
                i = base + (0.7 if v > 0.68 else -0.7 if v < 0.3 else 0.0) + (dither.random() - 0.5) * 0.5
                px[x, y] = ramp[max(0, min(len(ramp) - 1, int(round(i))))]

    def box(spec, ramp, top, bottom, skip=()):
        for name, rect in box_faces(*spec).items():
            if rect[2] > 0 and rect[3] > 0 and name not in skip:
                if name == "top":
                    face(rect, top + 0.4, top + 0.2, ramp)
                elif name == "bottom":
                    face(rect, bottom - 0.3, bottom - 0.3, ramp)
                else:
                    face(rect, top, bottom, ramp)

    def mouth_face(rect, teeth_edge):
        """The inside of the mouth: dark at the back, warm toward the lips, a row of teeth on three edges."""
        x0, y0, w, h = rect
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                depth = (y - y0) / max(1, h - 1) if teeth_edge == "bottom" else 1 - (y - y0) / max(1, h - 1)
                px[x, y] = mouth[min(3, int(depth * 3.2))] if 0 < x - x0 < w - 1 else mouth[1]
        tooth = rgba("nester_tooth", 1)
        shade = rgba("nester_tooth", 0)
        lip = y0 + h - 1 if teeth_edge == "bottom" else y0
        for x in range(x0 + 1, x0 + w - 1, 2):
            px[x, lip] = tooth
            px[x + 1 if x + 1 < x0 + w - 1 else x, lip] = shade if x + 1 < x0 + w - 1 else tooth
        for y in range(y0 + 1, y0 + h - 1, 2):
            px[x0, y] = tooth
            px[x0 + w - 1, y] = tooth

    box(_NESTER_HEAD, hide, 4.3, 2.8, skip=("bottom",))
    mouth_face(box_faces(*_NESTER_HEAD)["bottom"], "bottom")
    box(_NESTER_JAW, jaw, 3.4, 1.6, skip=("top",))
    mouth_face(box_faces(*_NESTER_JAW)["top"], "top")
    box(_NESTER_NECK, hide, 3.4, 2.4)
    box(_NESTER_LEG, hide, 3.0, 1.8)
    for name, (x0, y0, w, h) in box_faces(*_NESTER_LEG).items():  # tan feet
        if name in ("front", "back", "left", "right"):
            for y in (y0 + h - 2, y0 + h - 1):
                for x in range(x0, x0 + w):
                    px[x, y] = jaw[3 if y == y0 + h - 2 else 2]
        elif name == "bottom":
            for y in range(y0, y0 + h):
                for x in range(x0, x0 + w):
                    px[x, y] = jaw[1]
    # Eyes at the head's front corners, just above the mouth: navy, a white glint, wrapping the corner.
    heads = box_faces(*_NESTER_HEAD)
    fx, fy, fw, fh = heads["front"]
    rx, ry, rw, rh = heads["right"]
    lx, ly, lw, lh = heads["left"]
    navy, dark, glint = rgba("nester_eye", 0), rgba("nester_eye", 1), rgba("nester_eye", 2)
    for y in (fy + fh - 3, fy + fh - 2):
        put(im, [(fx, y), (fx + 1, y), (fx + fw - 1, y), (fx + fw - 2, y)], navy)
        put(im, [(rx + rw - 1, y), (lx, y)], dark)
    put(im, [(fx + 1, fy + fh - 3), (fx + fw - 2, fy + fh - 3)], glint)
    # Antennae: a stalk up the middle with barbs swept up and out, as a fern's (transparent around).
    for name in ("left", "right"):
        x0, y0, w, h = box_faces(*_NESTER_ANTENNA)[name]
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                px[x, y] = (0, 0, 0, 0)
        mid = x0 + w // 2
        for y in range(y0, y0 + h):
            px[mid, y] = hide[3 if y < y0 + h - 2 else 2]
        for i, y in enumerate(range(y0 + 1, y0 + h - 2, 2)):
            px[mid - 1, y] = hide[4]
            px[mid + 1, y] = hide[4]
            if i % 2 == 0:
                px[mid - 2, y - 1] = hide[5]
                px[mid + 2, y - 1] = hide[5]
    return im


def nester_glow_texture() -> Image.Image:
    """The enduring (soul) Nester's glow: its eyes and the stalks of its antennae."""
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    heads = box_faces(*_NESTER_HEAD)
    fx, fy, fw, fh = heads["front"]
    for y in (fy + fh - 3, fy + fh - 2):
        put(im, [(fx, y), (fx + 1, y), (fx + fw - 1, y), (fx + fw - 2, y)], rgba("nester_soul", 5))
    for name in ("left", "right"):
        x0, y0, w, h = box_faces(*_NESTER_ANTENNA)[name]
        for y in range(y0, y0 + h - 2):
            put(im, [(x0 + w // 2, y)], rgba("nester_soul", 4))
    return im


def nester_spawn_egg() -> Image.Image:
    """The Nester's spawn egg: the head's teal over the jaw's tan, a navy eye on each side."""
    rows = [
        "................",
        "......3443......",
        ".....344543.....",
        "....34455443....",
        "....34444443....",
        "...e3444444e3...",
        "...e2333333e2...",
        "...ttttttttttt..",
        "...tTTTtTTTTTt..",
        "...jjjjjjjjjjj..",
        "....jjjjjjjjj...",
        "....jjjJjjjjj...",
        ".....JjjjjjJ....",
        "......JJJJJ.....",
        "................",
        "................",
    ]
    c = {str(i): rgba("nester", i) for i in range(6)}
    c.update({"e": rgba("nester_eye", 0), "t": rgba("nester_tooth", 1), "T": rgba("nester_mouth", 1),
              "j": rgba("nester_jaw", 3), "J": rgba("nester_jaw", 1)})
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                put(im, [(x, y)], c[ch])
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


# ---------------------------------------------------------------- the hymnstone family II (owner: hymnstone works as stone)
def _cells(seed: int, count: int, spacing: float):
    """Voronoi cells on the wrapped tile: per pixel, (its nearest point's index, the gap to the second
    nearest point, and its offset from its own point)."""
    pts = scatter(seed, count, spacing)
    out = []
    for y in range(H):
        row = []
        for x in range(W):
            ds = sorted((((x - px_ + W / 2) % W - W / 2) ** 2 + ((y - py_ + H / 2) % H - H / 2) ** 2, i,
                         (x - px_ + W / 2) % W - W / 2, (y - py_ + H / 2) % H - H / 2) for i, (px_, py_) in enumerate(pts))
            row.append((ds[0][1], math.sqrt(ds[1][0]) - math.sqrt(ds[0][0]), ds[0][2], ds[0][3]))
        out.append(row)
    return out


def cobbled_hymnstone() -> Image.Image:
    """Cobbled hymnstone, as vanilla cobblestone: rounded stones of the stone's grain, each its own shade,
    lit toward the top-left and shaded toward the bottom-right, packed with dark gaps."""
    cells = _cells(41, 6, 5.6)
    v = grain(41, clumps=0.3, cells=4, fine=8, jitter=0.4)
    rnd = random.Random(41)
    base = [rnd.choice((3, 4, 4, 5)) for _ in range(9)]
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            i, gap, dx, dy = cells[y][x]
            if gap < 0.75:
                px[x, y] = rgba("hymnstone", 1 if (x * 3 + y) % 4 else 0)
                continue
            shade = base[i] + (1 if dx + dy < -1.5 else -1 if dx + dy > 2.0 else 0)
            shade += 1 if v[y][x] > 0.62 else -1 if v[y][x] < 0.38 else 0
            if gap < 1.6:
                shade -= 1  # a stone's rim falls away into the gap
            px[x, y] = rgba("hymnstone", max(1, min(7, shade)))
    return im


def smooth_hymnstone() -> Image.Image:
    """Smooth hymnstone, as vanilla smooth stone: a face ground flat, two close shades in slow clouds,
    inside a one-pixel frame a shade darker."""
    v = tile_noise(W, H, 4, 4, 51)
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            edge = x in (0, W - 1) or y in (0, H - 1)
            px[x, y] = rgba("hymnstone", 4 if edge else 6 if v[y][x] > 0.56 else 5)
    return im


def polished_hymnstone() -> Image.Image:
    """Polished hymnstone, as vanilla polished andesite: the grain smoothed into broad soft blotches,
    framed by a bevel lit on its top and left edges and shaded on its bottom and right."""
    v = tile_noise(W, H, 3, 3, 57, ((1.0, 1), (0.5, 2)))
    b = by_rank(v, [0.25, 0.45, 0.30], soft=False)
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            shade = 4 + b[y][x]
            if x == W - 1 or y == H - 1:
                shade = 3
            elif x == 0 or y == 0:
                shade = 7
            px[x, y] = rgba("hymnstone", shade)
    return im


def cracked_hymnstone_bricks() -> Image.Image:
    """The bricks, fired until they crack: a few dark cracks wandering down across them, each with a lit
    lip on its right, and a chipped corner."""
    im = hymnstone_bricks()
    px = im.load()
    rnd = random.Random(71)
    crack = set()
    for x, y, steps, drift in ((2, 1, 7, 1), (12, 9, 6, -1)):
        for _ in range(steps):
            crack.add((x % W, y % H))
            if rnd.random() < 0.5:
                x += drift
            else:
                y += 1
    for x, y in crack:
        px[x, y] = rgba("hymnstone", 0)
        if ((x + 1) % W, y) not in crack:
            px[(x + 1) % W, y] = rgba("hymnstone", 6)
    for x, y in ((14, 8), (15, 8), (15, 9)):
        px[x, y] = rgba("hymnstone", 1)
    return im


def chiseled_hymnstone_bricks() -> Image.Image:
    """Chiseled hymnstone bricks: a bevelled panel carved with a ring (a bell's mouth, seen head-on) and
    two arcs of sound either side of it; carved lines are dark with a lit lower lip."""
    v = grain(83, clumps=0.4, cells=4, fine=8, jitter=0.4)
    b = by_rank(v, [0.3, 0.4, 0.3])
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            shade = 4 + b[y][x]
            if x in (0, W - 1) or y in (0, H - 1):
                shade = 1
            elif x == 1 or y == 1:
                shade = 7
            elif x == W - 2 or y == H - 2:
                shade = 2
            px[x, y] = rgba("hymnstone", max(1, min(7, shade)))
    cx = cy = 7.5
    carved = set()
    for y in range(3, H - 3):
        for x in range(3, W - 3):
            d = math.hypot(x - cx, y - cy)
            if abs(d - 2.6) < 0.55 or abs(d - 5.0) < 0.5 and abs(x - cx) > abs(y - cy) * 1.4:
                carved.add((x, y))
    for x, y in carved:
        px[x, y] = rgba("hymnstone", 1)
        if (x, y + 1) not in carved:
            px[x, y + 1] = rgba("hymnstone", 6)
    for x, y in ((7, 7), (8, 7)):
        px[x, y] = rgba("hymnstone", 7)
    for x, y in ((7, 8), (8, 8)):
        px[x, y] = rgba("hymnstone", 3)
    return im


# ---------------------------------------------------------------- ores (survival_sift.md §2)
# Cluster shapes: a = the ore's darkest shade .. d = its lightest (clamped to the ramp); vanilla's ore
# colours, so each reads as its ore, in clusters drawn anew on hymnstone.
_ORE_SHAPES = {
    "coal": ([".bb.", "bccb", "abbc", ".aa."], ["bc.", "abb", ".a."], [".cb", "bba", "a.."]),
    "copper": ([".cd.", "bcde", ".abf"], ["cd.", "bce", ".a."], [".dc", "bca", ".a."]),
    "iron": ([".cd", "bcc", "ab."], ["dc.", "cbb", ".a."], [".d.", "cbc", ".a."]),
    "gold": ([".dc", "cdb", "ab."], ["dc.", "bcb", ".a."], [".d.", "dcb", ".ba"]),
    "redstone": ([".d.", "dcb", ".ba"], ["c.c", ".b."], ["dc", "ba"], [".c", "b."]),
    "lapis": ([".dc.", "cdcb", ".bba"], ["dc", "cb", ".a"], [".d.", "cba"]),
    "diamond": ([".d.", "dcd", "bcb", ".a."], [".dc", "dcb", ".a."], ["cd", "ba"]),
    "emerald": ([".d.", "dcd", "bcb", ".a."], [".c.", "cdb", ".a."]),
}
_ORE_COUNTS = {"coal": 5, "copper": 5, "iron": 5, "gold": 4, "redstone": 6, "lapis": 5, "diamond": 4, "emerald": 3}


def _cluster(im: Image.Image, x0: int, y0: int, shape: list[str], ramp: str, lift: int = 0) -> set:
    px = im.load()
    n = len(RAMPS[ramp])
    hit = set()
    for dy, row in enumerate(shape):
        for dx, ch in enumerate(row):
            if ch != ".":
                p = ((x0 + dx) % W, (y0 + dy) % H)
                px[p] = rgba(ramp, min(n - 1, "abcdef".index(ch) + lift))
                hit.add(p)
    for x, y in hit:  # a dark seat below and right of the cluster, as vanilla's ores have
        q = ((x + 1) % W, (y + 1) % H)
        if q not in hit:
            px[q] = rgba("hymnstone", 2)
    return hit


def hymnstone_ore(kind: str) -> Image.Image:
    im = hymnstone_pattern()
    shapes = _ORE_SHAPES[kind]
    for i, (x, y) in enumerate(scatter(sum(map(ord, kind)), _ORE_COUNTS[kind], 5.5)):
        _cluster(im, x, y, shapes[i % len(shapes)], "ore_" + kind)
    return im


def echo_ore_frames(n: int = 16) -> list[Image.Image]:
    """Echo ore (an invention, survival_sift.md §2): long shards of echo in the stone, each pulsing in
    turn, as a sound does when it comes back."""
    shards = (["..c", ".cb", "ca."], ["c.", "cb", ".a"], [".c", "cb", "ba"], ["cc", ".b"])
    spots = scatter(301, 5, 5.0)
    frames = []
    for f in range(n):
        im = hymnstone_pattern()
        for i, (x, y) in enumerate(spots):
            pulse = 0.5 + 0.5 * math.cos(2 * math.pi * (f / n - i / len(spots)))
            _cluster(im, x, y, shards[i % len(shards)], "echo", lift=1 if pulse > 0.66 else 0)
            if pulse > 0.85:
                put(im, [(x + len(shards[i % len(shards)][0]) - 1, y)], rgba("echo", 4))
        frames.append(im)
    return frames


# ---------------------------------------------------------------- food (survival_sift.md §1)
def tide_roots(stage: int) -> Image.Image:
    """Tide roots in vanilla's crop layout: teal blades rising with each stage; at the last, the lilac
    shoulders of the roots show at the soil."""
    im = _blank()
    tops = (13, 10, 7, 4)[stage]
    for i, x in enumerate((2, 6, 9, 13)):
        top = tops + (i % 2) * (1 if stage else 0)
        if stage == 0 and i % 2:
            continue
        lean = (-1, 1, -1, 1)[i]
        for y in range(15, top - 1, -1):
            sx = x + (lean if y < top + (15 - top) // 2 else 0)
            _set(im, sx, y, rgba("tidewrack_underside", 0 if y > 12 else 1))
            if stage >= 1 and (y + i) % 3 == 0 and y < 14:
                _set(im, sx + lean, y, rgba("tidewrack_underside", 2))
        _set(im, x + (lean if stage else 0), top, rgba("tidewrack_underside", 2))
    if stage == 3:
        for x in (2, 6, 9, 13):
            _set(im, x - 1, 15, rgba("tide_root", 2))
            _set(im, x, 15, rgba("tide_root", 3))
            _set(im, x + 1, 15, rgba("tide_root", 1))
            _set(im, x, 14, rgba("tide_root", 4))
    return im


_ROOT_ROWS = [
    "................",
    "...........g.G..",
    "..........gG.H..",
    "...........GgG..",
    ".........ddHg...",
    "........dedc....",
    ".......dedcb....",
    "......dedcba....",
    ".....dedcba.....",
    "....cddcba......",
    "...cdccba.......",
    "...ccbaa........",
    "..cbaa..........",
    "..ba............",
    ".a..............",
    "................",
]


def tide_root_item(baked: bool = False) -> Image.Image:
    """The tide root, lying corner to corner as vanilla's carrot does: a lilac root banded by the rings
    it grew, teal blades at its crown. Baked, it browns, loses its blades and splits along a ring."""
    im = _blank()
    ramp = "tide_root_baked" if baked else "tide_root"
    key = {"a": (ramp, 0), "b": (ramp, 1), "c": (ramp, 2), "d": (ramp, 3), "e": (ramp, 4),
           "g": ("tidewrack_underside", 0), "G": ("tidewrack_underside", 1), "H": ("tidewrack_underside", 2)}
    rows = [r.translate(str.maketrans("gGH", "...")) if baked else r for r in _ROOT_ROWS]
    _rows(im, 0, 0, rows, key)
    for x, y in ((6, 9), (7, 8), (8, 7)) if not baked else ():
        _set(im, x, y, rgba(ramp, 1))  # a growth ring
    if baked:
        for x, y in ((6, 8), (7, 7), (9, 5)):
            _set(im, x, y, rgba(ramp, 0))
        _set(im, 10, 4, rgba(ramp, 2))
    return im


def songfruit() -> Image.Image:
    """Songfruit: a round indigo fruit on a songwood stalk with one leaf, lit from the top-left."""
    im = _blank()
    key = {"a": ("songfruit", 0), "b": ("songfruit", 1), "c": ("songfruit", 2), "d": ("songfruit", 3), "e": ("songfruit", 4),
           "k": ("songwood_bark", 5), "L": ("songwood_leaves", 4), "l": ("songwood_leaves", 2)}
    _rows(im, 0, 0, [
        "................",
        "................",
        ".......k.LL.....",
        ".......kLLl.....",
        "......kLl.......",
        ".....bbkbb......",
        "....bccccbb.....",
        "...bcedccbba....",
        "...bcdcccbba....",
        "...bccccbbba....",
        "...bbcccbbaa....",
        "....bbbbbaa.....",
        ".....aaaaa......",
        "................",
        "................",
        "................",
    ], key)
    return im


def glowcap_stew() -> Image.Image:
    """Glowcap stew, as vanilla's stews: a wooden bowl seen from a little above, full of pale-green broth
    with glowcap shelves floating in it."""
    im = _blank()
    key = {"v": ("bowl", 0), "w": ("bowl", 1), "x": ("bowl", 2), "r": ("bowl", 3),
           "s": ("glowcap", 1), "g": ("glowcap", 3), "G": ("glowcap", 4), "t": ("glowcap_stem", 1)}
    _rows(im, 0, 0, [
        "................",
        "................",
        "................",
        "................",
        "................",
        "....rrrrrrrr....",
        "..rrsGgssGgsrr..",
        ".rssgtsGgtssGsr.",
        ".rsGgssgtssgGsr.",
        ".xrssstssGgssrx.",
        ".xxrrrrrrrrrrxx.",
        "..wxxxxxxxxxxw..",
        "...vwwxxxxwwv...",
        "....vvwwwwvv....",
        "......vvvv......",
        "................",
    ], key)
    return im


def main() -> None:
    save(hymnstone_pattern(), "block/hymnstone.png")
    save(hymnstone_pattern(seed=4), "block/hymnstone_2.png")
    save(hymnstone_pattern(seed=9), "block/hymnstone_3.png")
    save(hymnstone_bricks(), "block/hymnstone_bricks.png")
    save(cobbled_hymnstone(), "block/cobbled_hymnstone.png")
    save(smooth_hymnstone(), "block/smooth_hymnstone.png")
    save(polished_hymnstone(), "block/polished_hymnstone.png")
    save(cracked_hymnstone_bricks(), "block/cracked_hymnstone_bricks.png")
    save(chiseled_hymnstone_bricks(), "block/chiseled_hymnstone_bricks.png")
    for kind in _ORE_SHAPES:
        save(hymnstone_ore(kind), f"block/hymnstone_{kind}_ore.png")
    save(strip(echo_ore_frames()), "block/echo_ore.png")
    save_mcmeta("block/echo_ore.png", '{\n  "animation": {\n    "frametime": 4,\n    "interpolate": true\n  }\n}\n')
    for stage in range(4):
        save(tide_roots(stage), f"block/tide_roots_stage{stage}.png")
    save(tide_root_item(), "item/tide_root.png")
    save(tide_root_item(baked=True), "item/baked_tide_root.png")
    save(songfruit(), "item/songfruit.png")
    save(glowcap_stew(), "item/glowcap_stew.png")
    save(healthy_sculk_top(), "block/healthy_sculk_top.png")
    save(healthy_sculk_top(seed=22), "block/healthy_sculk_top_2.png")
    save(healthy_sculk_top(seed=27), "block/healthy_sculk_top_3.png")
    save(healthy_sculk_side(), "block/healthy_sculk_side.png")
    save(plant("short"), "block/healthy_sculk_grass.png")
    save(plant("tall_bottom"), "block/tall_healthy_sculk_grass_bottom.png")
    save(plant("tall_top"), "block/tall_healthy_sculk_grass_top.png")
    save(songwood_log(), "block/songwood_log.png")
    save(songwood_log(variant=2), "block/songwood_log_2.png")
    save(songwood_log_top(), "block/songwood_log_top.png")
    save(songwood_planks(), "block/songwood_planks.png")
    save(songwood_leaves(), "block/songwood_leaves.png")
    save(songwood_leaves(seed=57), "block/songwood_leaves_2.png")
    save(songwood_sapling(), "block/songwood_sapling.png")
    save(songwood_drapes(tip=False), "block/songwood_drapes.png")
    save(songwood_drapes(tip=True), "block/songwood_drapes_tip.png")
    save(sift_soil(), "block/sift_soil.png")
    save(tide_sand(), "block/tide_sand.png")
    save(tide_sand(seed=62), "block/tide_sand_2.png")
    save(tide_sand(seed=67), "block/tide_sand_3.png")
    save(tide_vent_top(), "block/tide_vent_top.png")
    save(tide_vent_side(), "block/tide_vent_side.png")
    save(gatestone(top=False), "block/gatestone.png")
    save(gatestone(top=True), "block/gatestone_top.png")
    save(strip(membrane_frames()), "block/sift_membrane.png")
    save_mcmeta("block/sift_membrane.png", '{\n  "animation": {\n    "frametime": 2,\n    "interpolate": true\n  }\n}\n')
    # One turn of the sheen's colour cycle in 12 s (48 frames of 5 ticks), smoothed between frames.
    save(strip([ichor_frame(16, 16, f / 48, flow=False) for f in range(48)]), "block/ichor_still.png")
    save_mcmeta("block/ichor_still.png", '{\n  "animation": {\n    "frametime": 3,\n    "interpolate": true\n  }\n}\n')
    save(strip([ichor_frame(32, 32, f / 48, flow=True) for f in range(48)]), "block/ichor_flow.png")
    save(ichor_film(), "block/ichor_film.png")
    save_mcmeta("block/ichor_film.png", '{\n  "animation": {\n    "frametime": 5,\n    "interpolate": true\n  }\n}\n')
    save_mcmeta("block/ichor_flow.png", '{\n  "animation": {\n    "frametime": 2,\n    "interpolate": true\n  }\n}\n')
    save(ichor_overlay(), "block/ichor_overlay.png")
    save(ichor_bucket(), "item/ichor_bucket.png")
    save(tidewrack("open"), "block/tidewrack.png")
    save(tidewrack("closed"), "block/tidewrack_closed.png")
    save(tidewrack("picked"), "block/tidewrack_picked.png")
    save(tidewrack_knot(), "block/tidewrack_knot.png")
    save(endure_bloom("open"), "block/endure_bloom.png")
    save(endure_bloom_emissive(), "block/endure_bloom_emissive.png")
    save(endure_bloom("closed"), "block/endure_bloom_closed.png")
    save(endure_bloom("picked"), "block/endure_bloom_picked.png")
    save(glowcap(), "block/glowcap.png")
    save(chime_bell_flower(), "block/chime_bell_flower.png")
    save(chime_bell_flower(ringing=True), "block/chime_bell_flower_ringing.png")
    save(lumen_bloom(), "block/lumen_bloom.png")
    save(lumen_bloom_core(), "block/lumen_bloom_core.png")
    save(tidewrack_frond(), "item/tidewrack_frond.png")
    save(endure_petal_item(), "item/endure_petal.png")
    save(lumen_lantern(), "block/lumen_lantern.png")
    save(lumen_lantern_item(), "item/lumen_lantern.png")
    save(ichor_lily(), "block/ichor_lily.png")
    save(ichor_lily_bud(), "block/ichor_lily_bud.png")
    save(ichor_lily_item(), "item/ichor_lily.png")
    save(glimmer(), "particle/glimmer.png")
    save(glow_petal(), "particle/glow_petal.png")
    save(blub_texture(), "entity/blub/blub.png")
    save(blub_glow_texture(), "entity/blub/blub_glow.png")
    save(nester_texture(), "entity/nester/nester.png")
    save(nester_texture(soul=True), "entity/nester/nester_soul.png")
    save(nester_glow_texture(), "entity/nester/nester_glow.png")
    save(nester_spawn_egg(), "item/nester_spawn_egg.png")
    save(blub_spawn_egg(), "item/blub_spawn_egg.png")
    save(trill(), "particle/trill.png")
    print("textures written")


if __name__ == "__main__":
    main()
