#!/usr/bin/env python3
"""Contact sheet of Trapisque's sticker art (StickerArt.lua): cards, tokens, hazards, mascots.

Usage: python3 tools/preview/stickers.py stickers.json out.png
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from render import Layer, Canvas, draw_ops, hex_rgba, font, LINE  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

BG = "#1F1438"
PANEL = "#2B1D4D"
CAT = {"trap": "#FF4F5E", "assist": "#8BE04E", "neutral": "#9A6BFF", "potion": "#FF9A3C"}
GROUPS = [
    ("Traps", "trap", ["spike", "grog", "fire", "ice", "snare", "mudslide", "banana", "wall"]),
    ("Assist", "assist", ["speed_boost", "bounce_pad", "moonwalk", "clover", "juice", "shield", "bridge", "key", "boots"]),
    ("Neutral", "neutral", ["teleporter", "spore_warper", "conveyor", "trampoline", "coin"]),
    ("Potions", "potion", ["speed_potion", "phoenix_potion", "xray_potion", "telepathy_potion", "time_potion", "jeopardy_potion"]),
]
OUTLINE = 0.045


def sticker(img, ops, x, y, size, bg=None, outline=OUTLINE):
    m = int(size * 0.12)
    box = int(size + 2 * m)
    layer = Layer(box, box, ss=3)
    cv = Canvas(layer, m, m, size, {"ink": hex_rgba(LINE), "line": hex_rgba(LINE), "bg": hex_rgba(bg or BG)})
    draw_ops(cv, ops, outline=outline)
    img.alpha_composite(layer.final(), (int(x - m), int(y - m)))


def card_tile(img, d, ops, x, y, w, color):
    h = int(w * 1.25)
    # card: outline, colour band, art panel
    d.rounded_rectangle([x - 4, y - 4, x + w + 4, y + h + 4], radius=16, fill=hex_rgba(LINE))
    d.rounded_rectangle([x, y, x + w, y + h], radius=13, fill=hex_rgba(color))
    d.rounded_rectangle([x + 8, y + 8, x + w - 8, y + h - 34], radius=10, fill=hex_rgba("#FFF4E2"))
    sticker(img, ops, x + 18, y + 16, w - 36, bg="#FFF4E2")


def main():
    data = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    W = 1900
    img = Image.new("RGBA", (W, 2700), hex_rgba(BG))
    d = ImageDraw.Draw(img)
    d.text((24, 16), "Trapisque sticker art", font=font("chunky", 40), fill=hex_rgba("#FFF4E2"), stroke_width=3, stroke_fill=hex_rgba(LINE))
    y = 80
    cw = 150
    for title, cat, names in GROUPS:
        d = ImageDraw.Draw(img)
        d.text((24, y), title, font=font("chunky", 28), fill=hex_rgba(CAT[cat]), stroke_width=2, stroke_fill=hex_rgba(LINE))
        y += 44
        for i, name in enumerate(names):
            x = 24 + i * (cw + 24)
            card_tile(img, ImageDraw.Draw(img), data["cards"][name], x, y, cw, CAT[cat])
            d = ImageDraw.Draw(img)
            d.text((x + cw / 2, y + cw * 1.25 - 18), name.replace("_", " "), font=font("body", 16), fill=hex_rgba(LINE), anchor="mm")
        y += int(cw * 1.25) + 30
    # tokens / hazards / misc
    d = ImageDraw.Draw(img)
    d.text((24, y), "Board", font=font("chunky", 28), fill=hex_rgba("#FFD23F"), stroke_width=2, stroke_fill=hex_rgba(LINE))
    y += 44
    x = 24
    tok_col = {"trap": "#FF4F5E", "assist": "#8BE04E", "neutral": "#9A6BFF", "potion": "#FF9A3C"}
    for kind, ops in data["tokens"].items():
        d = ImageDraw.Draw(img)
        s = 110
        d.ellipse([x - 4, y - 4, x + s + 4, y + s + 4], fill=hex_rgba(LINE))
        d.ellipse([x, y, x + s, y + s], fill=hex_rgba(tok_col[kind]))
        sticker(img, ops, x + 20, y + 20, s - 40, bg=tok_col[kind], outline=0.06)
        x += s + 30
    for name in ("river", "gate", "slime"):
        sticker(img, data["hazards"][name], x, y, 110)
        x += 140
    for name in ("chest", "flag", "snowflake", "flame", "bolt", "zzz", "star"):
        sticker(img, data["misc"][name], x, y + 10, 90)
        x += 112
    y += 150
    # mascots
    d = ImageDraw.Draw(img)
    d.text((24, y), "The cast (default face, then every mood)", font=font("chunky", 28), fill=hex_rgba("#45C3FF"), stroke_width=2, stroke_fill=hex_rgba(LINE))
    y += 50
    moods = ["default", "idle", "happy", "shock", "sad", "dizzy", "smug", "angry"]
    order = ["mage", "trapper", "fire_starter", "naturalist", "warper", "overseer"]
    for cid in order:
        sets = data["mascots"][cid]
        x = 24
        sticker(img, sets["default"], x, y, 170)
        d = ImageDraw.Draw(img)
        d.text((x + 85, y + 182), cid.replace("_", " "), font=font("chunky", 20), fill=hex_rgba("#FFF4E2"), anchor="mm", stroke_width=2, stroke_fill=hex_rgba(LINE))
        x += 200
        for m in moods[1:]:
            sticker(img, sets[m], x, y + 50, 100)
            d = ImageDraw.Draw(img)
            d.text((x + 50, y + 160), m, font=font("body", 15), fill=hex_rgba("#CBBDF0"), anchor="mm")
            x += 118
        y += 210

    img = img.crop((0, 0, W, min(y + 10, img.size[1])))
    img.convert("RGB").save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main()
