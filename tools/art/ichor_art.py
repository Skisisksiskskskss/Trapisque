"""Ichor's textures (owner playtest 6, D-037). Needs numpy; build_textures.py calls it.

Ichor's surface is one big seamless picture, as Dungeons II's pools are (MCD2_Pool_of_ichor): an oil
slick's marbled colours, turquoise and sea-green first, then blue, violet, magenta and pink, with a
touch of green and gold where the swirl runs to its ends, slowly swirling under scattered white
glitter. thesift.client.IchorSheen maps the field tile onto the world by position, so one tile spans
16 x 16 blocks and every block shows its own part of it; everything here is periodic in space and in
time, so the tile meets itself without a seam and the loop closes. Drawn in the `ichor_marble` and
`ichor_glint` ramps only, as pixel art: quantised bands, no blur.
"""
from __future__ import annotations

import math
import random

import numpy as np
from PIL import Image

from sift_art import RAMPS

FIELD_TILE = 16  # blocks one field tile spans (thesift.client.IchorSheen.FIELD_TILE)
FIELD_FRAMES = 32  # 6 ticks each, interpolated: a 9.6-second loop
FALL_TILE = 4  # blocks one fall tile spans (IchorSheen.FALL_TILE)
FALL_FRAMES = 64  # a pixel a frame: the tile falls through itself once a loop
ALPHA = 225  # a little less see-through than water (179)
TAU = 2 * math.pi

# The water bucket's liquid: the pixels of the opening that vanilla's water_bucket fills (rows 2-5).
BUCKET_LIQUID = [(x, 2) for x in range(5, 11)] + [(x, y) for y in (3, 4) for x in range(3, 13)] + [(x, 5) for x in range(5, 11)]


class _Noise:
    """Gradient noise on a px x py lattice over the unit square: it tiles exactly, so all built on it does."""

    def __init__(self, px: int, py: int, seed: int):
        rnd = random.Random(seed)
        ang = np.array([[rnd.random() * TAU for _ in range(px)] for _ in range(py)])
        self.gx, self.gy, self.px, self.py = np.cos(ang), np.sin(ang), px, py

    def __call__(self, u: np.ndarray, v: np.ndarray) -> np.ndarray:
        x, y = u * self.px, v * self.py
        xi, yi = np.floor(x), np.floor(y)
        xf, yf = x - xi, y - yi
        x0, y0 = xi.astype(int) % self.px, yi.astype(int) % self.py
        x1, y1 = (x0 + 1) % self.px, (y0 + 1) % self.py

        def dot(ix, iy, dx, dy):
            return self.gx[iy, ix] * dx + self.gy[iy, ix] * dy

        fu = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
        fv = yf * yf * yf * (yf * (yf * 6 - 15) + 10)
        a = dot(x0, y0, xf, yf) + fu * (dot(x1, y0, xf - 1, yf) - dot(x0, y0, xf, yf))
        b = dot(x0, y1, xf, yf - 1) + fu * (dot(x1, y1, xf - 1, yf - 1) - dot(x0, y1, xf, yf - 1))
        return a + fv * (b - a)


class _Fbm:
    """Octaves of tiling noise, each twice as fine and half as strong."""

    def __init__(self, px: int, py: int, octaves: int, seed: int):
        self.layers = [(0.5 ** o, _Noise(px << o, py << o, seed * 31 + o)) for o in range(octaves)]

    def __call__(self, u: np.ndarray, v: np.ndarray) -> np.ndarray:
        return sum(a * n(u, v) for a, n in self.layers)


def _ranks(values: np.ndarray) -> np.ndarray:
    """Each value's place among all of them, 0 to 1, so a ramp's entries share the area evenly."""
    flat = np.sort(values, axis=None)
    return np.searchsorted(flat, values) / flat.size


def _grid(n: int) -> tuple[np.ndarray, np.ndarray]:
    y, x = np.mgrid[0:n, 0:n]
    return (x + 0.5) / n, (y + 0.5) / n


_FIELD: np.ndarray | None = None


def field_positions() -> np.ndarray:
    """Where each pixel of each frame lies along the marble ramp, 0 to 1 (frames x 256 x 256).

    A field warped twice by others (marbling), whose warps circle once or twice a loop (the swirl);
    ranked so each ramp entry covers as much as the next; then a slow wave sloshes the colours back
    and forth along the ramp, its phase wandering over the tile, so the bands drift and breathe."""
    global _FIELD
    if _FIELD is None:
        u, v = _grid(16 * FIELD_TILE)
        q1, q2 = _Fbm(2, 2, 4, 7), _Fbm(2, 2, 4, 8)
        r1, r2 = _Fbm(3, 3, 3, 9), _Fbm(3, 3, 3, 10)
        g = _Fbm(3, 3, 4, 11)
        slow = _Fbm(1, 1, 2, 12)(u, v)
        frames = []
        for f in range(FIELD_FRAMES):
            t = f / FIELD_FRAMES

            def orbit(r: float, turns: int, phase: float) -> tuple[float, float]:
                return r * math.cos(TAU * (turns * t + phase)), r * math.sin(TAU * (turns * t + phase))

            (a1, b1), (a2, b2) = orbit(0.014, 1, 0.0), orbit(0.014, -1, 0.3)
            (a3, b3), (a4, b4) = orbit(0.006, 1, 0.6), orbit(0.005, 2, 0.1)
            wu = u + 0.30 * q1(u + a1, v + b1)
            wv = v + 0.30 * q2(u + 0.37 + a2, v + 0.71 + b2)
            ra = r1(wu + 0.13 + a3, wv + b3)
            rb = r2(wu + 0.61 + a4, wv + 0.29 + b4)
            frames.append(g(u + 0.20 * ra, v + 0.20 * rb))
        pos = _ranks(np.stack(frames))
        # The slosh fades out toward the ramp's ends, so it never piles the rare ends' colours up there.
        taper = np.minimum(1.0, 8.0 * pos * (1.0 - pos))
        for f in range(FIELD_FRAMES):
            t = f / FIELD_FRAMES
            pos[f] += taper[f] * (0.035 * np.sin(TAU * (t + slow)) + 0.018 * np.sin(TAU * (2 * t + 2 * slow + 0.3)))
        _FIELD = np.clip(pos, 0.0, 0.9999)
    return _FIELD


# How much of the surface each marble entry covers: turquoise and its neighbours most (canon's pools
# are mostly turquoise), blue, violet, purple and magenta a fair share, the lime and gold ends little.
MARBLE_SHARE = [0.08, 0.3, 0.6, 1.4, 1.6, 1.8, 2.0, 2.0, 1.8, 1.6, 1.4, 1.2, 1.1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
                1.1, 1.2, 1.1, 1.0, 0.4, 0.15, 0.06]


def _paint(pos: np.ndarray, alpha: int = ALPHA) -> np.ndarray:
    ramp = np.array(RAMPS["ichor_marble"])
    assert len(MARBLE_SHARE) == len(ramp)
    bounds = np.cumsum(MARBLE_SHARE) / sum(MARBLE_SHARE)
    rgb = ramp[np.minimum(np.searchsorted(bounds, pos, side="right"), len(ramp) - 1)]
    return np.concatenate([rgb, np.full(pos.shape + (1,), alpha)], -1).astype(np.uint8)


def _glints(im: np.ndarray, frame: int, frames: int, per_block: float, seed: int, star_chance: float = 0.15) -> None:
    """Glitter: single pixels that twinkle for three frames (pale, white, pale), a few as little stars."""
    glint = RAMPS["ichor_glint"]
    n = im.shape[0]
    rnd = random.Random(seed)
    for _ in range(int(per_block * (n // 16) ** 2 * frames / 3)):
        x, y, born, star = rnd.randrange(n), rnd.randrange(n), rnd.randrange(frames), rnd.random() < star_chance
        age = (frame - born) % frames
        if age > 2:
            continue
        pale = glint[1 + (x + y) % 2]
        im[y, x] = (*(glint[0] if age == 1 else pale), 255)
        if star and age == 1:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                im[(y + dy) % n, (x + dx) % n] = (*pale, 245)


def ichor_field() -> Image.Image:
    """Still ichor's surface: the field, 256 x 256 (16 x 16 blocks) a frame, with glitter."""
    pos = field_positions()
    n = pos.shape[1]
    sheet = np.zeros((n * FIELD_FRAMES, n, 4), np.uint8)
    for f in range(FIELD_FRAMES):
        im = _paint(pos[f])
        _glints(im, f, FIELD_FRAMES, 0.5, 26)
        sheet[f * n:(f + 1) * n] = im
    return Image.fromarray(sheet, "RGBA")


def ichor_fall() -> Image.Image:
    """Falling and flowing ichor's sides: the same colours drawn out into long wavering ribbons, with
    glints stretched into streaks; each frame is the last moved down a pixel, so it pours."""
    n = 16 * FALL_TILE
    u, v = _grid(n)
    wobble = _Fbm(2, 1, 2, 21)(u, v)
    ribbons = _Fbm(6, 1, 3, 22)(u + 0.08 * wobble, v) + 0.6 * _Fbm(1, 1, 2, 23)(u, v)
    im = _paint(np.clip(_ranks(ribbons), 0.0, 0.9999))
    glint = RAMPS["ichor_glint"]
    rnd = random.Random(27)
    for _ in range(FALL_TILE * FALL_TILE):
        x, y = rnd.randrange(n), rnd.randrange(n)
        im[y, x] = (*glint[0], 255)
        im[(y + 1) % n, x] = (*glint[1 + x % 2], 245)
    return Image.fromarray(np.concatenate([np.roll(im, f, axis=0) for f in range(FALL_FRAMES)]), "RGBA")


def ichor_bucket_liquid() -> Image.Image:
    """The bucket's ichor, drawn over vanilla's own bucket (the item model's first layer): a window of
    the field at a quarter scale, moving as the pools do, 16 frames, with one twinkling glint."""
    pos = field_positions()
    glint = RAMPS["ichor_glint"]
    sheet = np.zeros((16 * 16, 16, 4), np.uint8)
    for k in range(16):
        f = 2 * k
        for x, y in BUCKET_LIQUID:
            sheet[k * 16 + y, x] = _paint(pos[f, 96 + 4 * y, 40 + 4 * x], 255)
        if k in (5, 6, 7):
            sheet[k * 16 + 3, 9] = (*(glint[0] if k == 6 else glint[1]), 255)
    return Image.fromarray(sheet, "RGBA")
