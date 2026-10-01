"""Shared helpers for The Sift's texture generators (WP-041).

The palette lives in docs/DESIGN/palette.md; this module parses it so the generators and the
checker share one source of truth. Textures are authored as character grids: each character
maps to one ramp entry (or '.' for a fully transparent pixel).
"""
from __future__ import annotations

import math
import re
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
PALETTE_MD = REPO / "docs" / "DESIGN" / "palette.md"
TEX_ROOT = REPO / "src" / "main" / "resources" / "assets" / "thesift" / "textures"

_HEX = re.compile(r"#([0-9a-fA-F]{6})")


def _rows_after(heading: str, text: str) -> list[str]:
    """Table rows (lines starting with '|') of the section that starts with `heading`."""
    out, inside = [], False
    for line in text.splitlines():
        if line.startswith("## "):
            inside = line.strip() == heading
            continue
        if inside and line.startswith("|") and not set(line) <= set("|-: "):
            out.append(line)
    return out[1:]  # drop the header row


def load_ramps(path: Path = PALETTE_MD) -> dict[str, list[tuple[int, int, int]]]:
    ramps: dict[str, list[tuple[int, int, int]]] = {}
    for row in _rows_after("## Ramps", path.read_text()):
        cells = [c.strip() for c in row.strip("|").split("|")]
        name = cells[0].strip("` ")
        ramps[name] = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in _HEX.findall(cells[1])]
    return ramps


def load_texture_rules(path: Path = PALETTE_MD) -> dict[str, list[str]]:
    rules: dict[str, list[str]] = {}
    for row in _rows_after("## Texture → allowed ramps", path.read_text()):
        cells = [c.strip() for c in row.strip("|").split("|")]
        rules[cells[0].strip("` ")] = [r.strip() for r in cells[1].split(",")]
    return rules


RAMPS = load_ramps()


def key(*specs: tuple[str, str], alpha: int = 255) -> dict[str, tuple[int, int, int, int]]:
    """key(("0123456", "hymnstone"), ("abc", "flute")) -> {char: RGBA}. '.' is transparent."""
    k: dict[str, tuple[int, int, int, int]] = {".": (0, 0, 0, 0)}
    for chars, ramp in specs:
        cols = RAMPS[ramp]
        assert len(chars) <= len(cols), (ramp, chars)
        for ch, c in zip(chars, cols):
            assert ch not in k, f"duplicate key char {ch!r}"
            k[ch] = (*c, alpha)
    return k


def grid(rows: list[str] | str, k: dict[str, tuple[int, int, int, int]]) -> Image.Image:
    if isinstance(rows, str):
        rows = [r.strip() for r in rows.strip().splitlines() if r.strip()]
    h, w = len(rows), len(rows[0])
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        assert len(row) == w, f"row {y} has {len(row)} px, expected {w}: {row!r}"
        for x, ch in enumerate(row):
            px[x, y] = k[ch]
    return im


def rows_of(text: str) -> list[str]:
    return [r.strip() for r in text.strip().splitlines() if r.strip()]


def overlay(base_rows: list[str], top_rows: list[str], clear: str = " ") -> list[str]:
    """Characters in top_rows replace base_rows except where top has `clear`."""
    out = []
    for b, t in zip(base_rows, top_rows + [""] * (len(base_rows) - len(top_rows))):
        t = t.ljust(len(b), clear)
        out.append("".join(bc if tc == clear else tc for bc, tc in zip(b, t)))
    return out


def quantize(v: float, n: int) -> int:
    """Map v in [-1, 1] to 0..n-1 in equal bands."""
    v = max(-1.0, min(0.999999, v))
    return int((v + 1) / 2 * n)


def wave(x: float, period: float, phase: float = 0.0) -> float:
    return math.sin(2 * math.pi * (x / period + phase))


def save(im: Image.Image, rel: str) -> Path:
    out = TEX_ROOT / rel
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out, optimize=True)
    return out


def save_mcmeta(rel: str, text: str) -> Path:
    out = TEX_ROOT / (rel + ".mcmeta")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text)
    return out


def strip(frames: list[Image.Image]) -> Image.Image:
    w, h = frames[0].size
    im = Image.new("RGBA", (w, h * len(frames)), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.paste(f, (0, i * h))
    return im
