#!/usr/bin/env python3
"""Render quick PNG previews of the boards (developer tool, not game art)."""
import json, math, sys
from PIL import Image, ImageDraw

data = json.load(open(sys.argv[1]))
outdir = sys.argv[2]
COLORS = {"river": (60, 140, 230), "gate": (150, 110, 60), "slime": (120, 220, 60)}
for m in data:
    tiles = m["tiles"]
    S = 26
    xs = [t["x"] * S for t in tiles]; ys = [t["y"] * S for t in tiles]
    minx, miny = min(xs) - S * 2, min(ys) - S * 2
    W = int(max(xs) - minx + S * 2); H = int(max(ys) - miny + S * 2)
    img = Image.new("RGB", (W, H), (30, 40, 55))
    d = ImageDraw.Draw(img)
    byid = {t["id"]: t for t in tiles}
    def pos(t):
        return (t["x"] * S - minx, t["y"] * S - miny)
    for t in tiles:
        for k in ("next", "shortcut"):
            if t[k]:
                a, b = pos(t), pos(byid[t[k]])
                d.line([a, b], fill=(240, 200, 80) if k == "next" else (255, 90, 90), width=4)
    nat = {n["tile"]: n["kind"] for n in m["natural"]}
    toks = set(m["tokens"])
    for t in tiles:
        cx, cy = pos(t)
        pts = [(cx + S * 0.9 * math.cos(math.radians(60 * i + 30)), cy + S * 0.9 * math.sin(math.radians(60 * i + 30))) for i in range(6)]
        col = (200, 190, 160)
        if t["branch"]:
            col = (150, 130, 170)
        if t["kind"] == "start":
            col = (90, 200, 120)
        if t["kind"] == "treasure":
            col = (250, 210, 60)
        if t["id"] in nat:
            col = COLORS[nat[t["id"]]]
        d.polygon(pts, fill=col, outline=(20, 20, 20))
        if t["id"] in toks:
            d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(220, 60, 60))
        d.text((cx - 6, cy - 6), str(t["id"]), fill=(0, 0, 0))
    img.save(f"{outdir}/{m['id']}.png")
    print(m["id"], "main", m["count"], "total", m["total"], "routeLength", m["routeLength"], "tokens", len(m["tokens"]), "size", W, H)
