#!/usr/bin/env python3
"""Draws R6 keyframe poses from build/poses.json as front / side / top views.

  lune run tools/dump-poses.luau > build/poses.json
  python3 tools/render_poses.py build/poses.json build/poses.png [group ...]

Right-side limbs are drawn in warmer colours than left-side ones so mirrored
mistakes jump out. The character faces -Z: the front view looks at its face,
the side view sees it facing right, the top view has its front at the top.
"""

import json
import sys

from PIL import Image, ImageDraw, ImageFont

CELL = 150  # pixels per view
SCALE = 16  # pixels per stud
COLORS = {
    "Torso": (70, 110, 200),
    "Head": (245, 205, 80),
    "Right Arm": (235, 90, 70),
    "Left Arm": (120, 190, 255),
    "Right Leg": (200, 70, 120),
    "Left Leg": (80, 160, 140),
    "Weapon": (255, 150, 30),
}


def corners(part):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part["cframe"]
    sx, sy, sz = part["size"]
    out = []
    for dx in (-0.5, 0.5):
        for dy in (-0.5, 0.5):
            for dz in (-0.5, 0.5):
                lx, ly, lz = sx * dx, sy * dy, sz * dz
                out.append(
                    (
                        x + r00 * lx + r01 * ly + r02 * lz,
                        y + r10 * lx + r11 * ly + r12 * lz,
                        z + r20 * lx + r21 * ly + r22 * lz,
                    )
                )
    return out


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


# view name -> (project point to (u, v, depth)); larger depth = closer to camera
VIEWS = {
    "front": lambda p: (-p[0], p[1], -p[2]),
    "side": lambda p: (-p[2], p[1], p[0]),
    "top": lambda p: (p[0], -p[2], p[1]),
}
CENTER = {"front": (0, 3), "side": (0, 3), "top": (0, 0)}


def draw_view(draw, parts, view, ox, oy):
    project = VIEWS[view]
    cu, cv = CENTER[view]
    shapes = []
    for part in parts:
        pts = [project(c) for c in corners(part)]
        depth = sum(p[2] for p in pts) / len(pts)
        poly = hull([(p[0], p[1]) for p in pts])
        shapes.append((depth, part["name"], poly))
    shapes.sort(key=lambda s: s[0])
    for _, name, poly in shapes:
        screen = [(ox + CELL / 2 + (u - cu) * SCALE, oy + CELL / 2 - (v - cv) * SCALE) for u, v in poly]
        draw.polygon(screen, fill=COLORS.get(name, (200, 200, 200)), outline=(15, 15, 20))


def main():
    frames = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    groups = sys.argv[3:]
    if groups:
        frames = [f for f in frames if f["group"] in groups]
    rows = []
    for f in frames:
        if not rows or rows[-1][0] != f["group"]:
            rows.append((f["group"], []))
        rows[-1][1].append(f)
    width = max(len(r[1]) for r in rows) * CELL * 3 + 20
    height = len(rows) * (CELL + 22) + 10
    img = Image.new("RGB", (width, height), (32, 34, 42))
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    y = 5
    for group, items in rows:
        draw.text((8, y), group, fill=(255, 255, 255), font=font)
        for i, f in enumerate(items):
            x = 10 + i * CELL * 3
            for j, view in enumerate(("front", "side", "top")):
                draw_view(draw, f["parts"], view, x + j * CELL, y + 18)
            draw.text((x + 4, y + 20), f["label"], fill=(200, 200, 200), font=font)
            draw.line([(x, y + 18), (x, y + 18 + CELL)], fill=(70, 70, 80))
        y += CELL + 22
    img.save(out)
    print(f"saved {out} ({img.width}x{img.height}), {len(frames)} poses")


if __name__ == "__main__":
    main()
