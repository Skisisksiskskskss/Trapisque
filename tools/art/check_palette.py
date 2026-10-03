#!/usr/bin/env python3
"""Fails if any Sift texture uses a colour outside the ramps palette.md allows for it (WP-041).

Usage: python3 tools/art/check_palette.py
"""
from __future__ import annotations

import sys

from PIL import Image

from sift_art import RAMPS, TEX_ROOT, load_texture_rules


def main() -> int:
    rules = load_texture_rules()
    errors = []
    found = {p.relative_to(TEX_ROOT).as_posix() for p in TEX_ROOT.rglob("*.png")}
    for rel in sorted(found - rules.keys()):
        errors.append(f"{rel}: no palette rule in palette.md")
    for rel, ramps in sorted(rules.items()):
        path = TEX_ROOT / rel
        if not path.exists():
            errors.append(f"{rel}: missing texture")
            continue
        allowed = {c for r in ramps for c in RAMPS[r.strip("` ")]}
        im = Image.open(path).convert("RGBA")
        bad = {px[:3] for px in im.get_flattened_data() if px[3] and px[:3] not in allowed} \
            if hasattr(im, "get_flattened_data") else {px[:3] for px in im.getdata() if px[3] and px[:3] not in allowed}
        used = {px[:3] for px in (im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()) if px[3]}
        if bad:
            errors.append(f"{rel}: {len(bad)} colour(s) outside {ramps}: {sorted(bad)[:4]}")
        print(f"{rel}: {len(used)} colours")
    for e in errors:
        print("ERROR", e)
    print(f"{len(rules)} textures checked, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
