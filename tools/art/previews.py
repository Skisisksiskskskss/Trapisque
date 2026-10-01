#!/usr/bin/env python3
"""Renders texture previews for review (WP-041): 3×3 tiles at 8×, under each Tide's light.

Usage: python3 tools/art/previews.py [out_dir]   (default: docs/previews)
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

from sift_art import TEX_ROOT

BLOCKS = ["hymnstone", "hymnstone_bricks", "healthy_sculk_top", "healthy_sculk_side", "songwood_log",
          "songwood_log_top", "songwood_planks", "songwood_leaves", "tide_sand", "tide_vent_top",
          "tide_vent_side", "gatestone", "gatestone_top", "sift_membrane", "ichor_still"]
CUTOUTS = ["healthy_sculk_grass", "tall_healthy_sculk_grass_bottom", "tall_healthy_sculk_grass_top",
           "songwood_sapling", "songwood_leaves"]
TIDES = {"thrive": (1.0, 1.0, 1.0), "flow": (0.95, 0.82, 0.72), "endure": (0.30, 0.30, 0.45)}
BG = (96, 110, 120, 255)


def first_frame(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    w = im.width
    return im.crop((0, 0, w, w)).resize((16, 16), Image.NEAREST) if im.height > w else im


def tiled(im: Image.Image, n: int = 3, scale: int = 8) -> Image.Image:
    t = Image.new("RGBA", (16 * n, 16 * n), BG)
    for i in range(n):
        for j in range(n):
            t.alpha_composite(im, (16 * i, 16 * j))
    return t.resize((16 * n * scale, 16 * n * scale), Image.NEAREST)


def tint(im: Image.Image, rgb) -> Image.Image:
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * rgb[0]), int(g * rgb[1]), int(b * rgb[2]), a)
    return out


def sheet(names, out: Path, tide=(1.0, 1.0, 1.0), cols=5) -> None:
    cell = 16 * 3 * 4 + 24
    rows = (len(names) + cols - 1) // cols
    s = Image.new("RGBA", (cols * cell, rows * cell), (30, 30, 34, 255))
    d = ImageDraw.Draw(s)
    for k, name in enumerate(names):
        im = tint(first_frame(TEX_ROOT / "block" / f"{name}.png"), tide)
        s.alpha_composite(tiled(im, 3, 4), ((k % cols) * cell, (k // cols) * cell))
        d.text(((k % cols) * cell + 2, (k // cols) * cell + 16 * 3 * 4 + 4), name, fill=(230, 230, 230, 255))
    s.save(out)


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "docs" / "previews"
    out.mkdir(parents=True, exist_ok=True)
    for tide, rgb in TIDES.items():
        sheet(BLOCKS, out / f"wp041_blocks_{tide}.png", rgb)
    sheet(CUTOUTS, out / "wp041_plants.png")
    for name in ("item/ichor_bucket", "particle/glow_petal", "particle/trill"):
        im = Image.open(TEX_ROOT / f"{name}.png").convert("RGBA")
        bg = Image.new("RGBA", im.size, BG)
        bg.alpha_composite(im)
        bg.resize((im.width * 16, im.height * 16), Image.NEAREST).save(out / f"wp041_{name.split('/')[1]}.png")
    print(f"previews in {out}")


if __name__ == "__main__":
    main()
