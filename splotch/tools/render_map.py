#!/usr/bin/env python3
"""Renders a top-down and a side preview of the map from build/map.json.

  lune run tools/dump-map.luau > build/map.json
  python3 tools/render_map.py build/map.json build/map-preview.png
"""

import json
import sys

from PIL import Image, ImageDraw, ImageFont

SCALE = 3  # pixels per stud
PAD = 30


def corners(part):
    px, py, pz = part["position"]
    sx, sy, sz = part["size"]
    r, u, look = part["right"], part["up"], part["look"]
    back = [-c for c in look]
    pts = []
    for dx in (-0.5, 0.5):
        for dy in (-0.5, 0.5):
            for dz in (-0.5, 0.5):
                pts.append(
                    (
                        px + r[0] * sx * dx + u[0] * sy * dy + back[0] * sz * dz,
                        py + r[1] * sx * dx + u[1] * sy * dy + back[1] * sz * dz,
                        pz + r[2] * sx * dx + u[2] * sy * dy + back[2] * sz * dz,
                    )
                )
    return pts


def hull(points):
    points = sorted(set(points))
    if len(points) <= 2:
        return points

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def shade(color, height):
    k = max(0.55, min(1.15, 0.8 + height / 120))
    return tuple(int(max(0, min(255, c * 255 * k))) for c in color)


def main():
    parts = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    solid = [p for p in parts if p["group"] == "map"]
    zones = [p for p in parts if p["group"] == "zones"]

    xs = [c[0] for p in parts for c in corners(p)]
    zs = [c[2] for p in parts for c in corners(p)]
    ys = [c[1] for p in parts for c in corners(p)]
    minx, maxx, minz, maxz = min(xs), max(xs), min(zs), max(zs)
    miny, maxy = min(ys), max(ys)

    top_w = int((maxx - minx) * SCALE) + PAD * 2
    top_h = int((maxz - minz) * SCALE) + PAD * 2
    side_h = int((maxy - miny) * SCALE) + PAD * 2
    img = Image.new("RGB", (top_w, top_h + side_h), (24, 26, 34))
    draw = ImageDraw.Draw(img, "RGBA")
    font = ImageFont.load_default()

    def top(x, z):
        return (PAD + (x - minx) * SCALE, PAD + (z - minz) * SCALE)

    def side(x, y):
        return (PAD + (x - minx) * SCALE, top_h + PAD + (maxy - y) * SCALE)

    # Top view: lowest tops first so taller things draw over.
    for p in sorted(solid, key=lambda p: max(c[1] for c in corners(p))):
        pts = corners(p)
        poly = hull([(c[0], c[2]) for c in pts])
        height = max(c[1] for c in pts)
        alpha = int(255 * (1 - p["transparency"])) if p["transparency"] < 1 else 0
        if alpha == 0:
            continue
        draw.polygon([top(x, z) for x, z in poly], fill=shade(p["color"], height) + (alpha,), outline=(20, 20, 20, 255))
    for p in zones:
        poly = hull([(c[0], c[2]) for c in corners(p)])
        colour = {"SafeZone": (80, 255, 120), "Shelter": (90, 170, 255), "Hazard": (255, 60, 60)}
        tag = p["tags"][0] if p["tags"] else ""
        draw.polygon([top(x, z) for x, z in poly], outline=colour.get(tag, (255, 255, 255)) + (255,))
    for p in solid:
        if p["name"].startswith(("Tower", "Stage", "Hut", "Pavilion", "Pad", "Sky", "Wall")) and not p["name"].endswith(
            ("Left", "Right", "Back")
        ):
            x, _, z = p["position"]
            draw.text(top(x, z), p["name"], fill=(255, 255, 255, 230), font=font, anchor="mm")
    draw.text((PAD, 8), "TOP VIEW (north = up)   green: safe zone   blue: shelters   red: hazard", fill=(230, 230, 230), font=font)

    # Side view (looking north), sorted far to near.
    for p in sorted(solid, key=lambda p: -p["position"][2]):
        if p["transparency"] >= 1:
            continue
        poly = hull([(c[0], c[1]) for c in corners(p)])
        draw.polygon([side(x, y) for x, y in poly], fill=shade(p["color"], p["position"][2] / 3) + (230,), outline=(20, 20, 20, 255))
    draw.text((PAD, top_h + 8), "SIDE VIEW (from the south)", fill=(230, 230, 230), font=font)

    img.save(out)
    print(f"saved {out} ({img.width}x{img.height})")


if __name__ == "__main__":
    main()
