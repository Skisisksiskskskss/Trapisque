#!/usr/bin/env python3
"""Top-down render of build/paint.json (see tools/dump-paint.luau)."""

import json
import sys

from PIL import Image, ImageDraw

SCALE = 14
COLORS = {1: (255, 128, 32), 2: (140, 70, 255)}


def main():
    data = json.load(open(sys.argv[1]))
    width, depth = data["floor"]["size"]
    img = Image.new("RGB", (int(width * SCALE) + 40, int(depth * SCALE) + 40), (30, 32, 40))
    draw = ImageDraw.Draw(img)

    def px(x, z):
        return (20 + (x + width / 2) * SCALE, 20 + (z + depth / 2) * SCALE)

    draw.rectangle([px(-width / 2, -depth / 2), px(width / 2, depth / 2)], fill=(186, 182, 174))
    for cell in sorted(data["cells"], key=lambda c: c["y"]):
        color = COLORS[cell["color"]]
        if cell["round"]:
            radius = cell["size"][1] / 2
            draw.ellipse([px(cell["x"] - radius, cell["z"] - radius), px(cell["x"] + radius, cell["z"] + radius)], fill=color)
        else:
            sx, _, sz = cell["size"]
            draw.rectangle([px(cell["x"] - sx / 2, cell["z"] - sz / 2), px(cell["x"] + sx / 2, cell["z"] + sz / 2)], fill=color)
    img.save(sys.argv[2])
    print("saved", sys.argv[2], len(data["cells"]), "cells")


if __name__ == "__main__":
    main()
