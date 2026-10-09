#!/usr/bin/env python3
"""Render a contact sheet of every icon in IconData (developer preview tool).

Usage: python3 tools/preview/icons.py icons.json out.png
(icons.json comes from tests/dump_icons.luau via the test bundler)
"""
import json
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from render import Layer, Canvas, draw_ops, hex_rgba, font  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

PARCH = "#F3E4C1"
WOOD = "#B57D46"
INK = "#4A3020"
BRASS = "#E3B04B"
BRASS_LIGHT = "#FFE39A"


def burn(h):
    """Util.shade(wood, -0.62): the burned-in colour on wood."""
    r, g, b, _ = hex_rgba(h)
    return "#%02X%02X%02X" % (int(r * 0.38), int(g * 0.38), int(b * 0.38))

GROUPS = [
    ("Trap cards", ["spike", "fire", "ice", "mudslide", "mud", "wall", "snare", "grog"]),
    ("Assist cards", ["regeneration", "bounce_pad", "speed_boost", "bridge", "key", "boots", "shield", "moonwalk"]),
    ("Neutral cards", ["teleporter", "spore_warper", "conveyor", "shifting_sands", "coin"]),
    ("Potions", ["speed_potion", "phoenix_potion", "time_potion", "telepathy_potion", "jeopardy_potion"]),
    ("Natural traps", ["river_trap", "gate_trap", "slime_trap"]),
    ("Board tokens", ["token_trap", "token_assist", "token_neutral", "token_potion", "flag", "chest", "x_mark", "compass"]),
    ("Characters", ["mage", "trapper", "fire_starter", "naturalist", "warper", "overseer"]),
    ("Interface", ["gem", "crown", "dice", "lock", "gear", "book", "bag", "hanger", "people", "play", "close",
                   "back", "check", "plus", "star", "sparkles", "eye", "info", "chat", "smile", "clover", "bubble",
                   "bolt", "level", "music", "speaker", "exit", "map"]),
]

POTION_COLORS = {
    "speed_potion": "#4FA3FF",
    "phoenix_potion": "#FF7B2E",
    "time_potion": "#B98CFF",
    "telepathy_potion": "#FF5FA2",
    "jeopardy_potion": "#5BD18B",
    "token_potion": "#F5B342",
}

CATEGORY = {
    "trap": "#C2513B", "assist": "#5E9A3C", "neutral": "#7A61A8", "potion": "#D98C1F", "natural": "#3F8C7E",
}
CAT_OF = {}
for n in GROUPS[0][1]:
    CAT_OF[n] = "trap"
for n in GROUPS[1][1]:
    CAT_OF[n] = "assist"
for n in GROUPS[2][1]:
    CAT_OF[n] = "neutral"
for n in GROUPS[3][1]:
    CAT_OF[n] = "potion"
for n in GROUPS[4][1]:
    CAT_OF[n] = "natural"


def draw_icon(img, icons, name, x, y, size, style):
    # draw on a small private layer, then paste (fast)
    m = int(size * 0.15)
    box = int(size + 2 * m)
    layer = Layer(box, box, ss=4)
    if style == "ink":
        colors = {"ink": hex_rgba(INK), "bg": hex_rgba(PARCH), "acc": hex_rgba(INK), "hi": hex_rgba(PARCH)}
        draw_ops(Canvas(layer, m, m, size, colors), icons[name])
    elif style == "engrave":
        # Icons.engraved: one flat burned-in layer
        ink = burn(WOOD)
        acc_c = POTION_COLORS.get(name, ink)
        dk = {"ink": hex_rgba(ink), "bg": hex_rgba(WOOD), "acc": hex_rgba(acc_c), "acc2": hex_rgba(acc_c), "hi": hex_rgba(WOOD)}
        draw_ops(Canvas(layer, m, m, size, dk), icons[name])
    else:  # Icons.medallion: flat disc, brass rim outside it, white glyph at 0.64 of the disc
        cat = CATEGORY.get(CAT_OF.get(name, ""), "#8A6A48")
        cv = Canvas(layer, m, m, size, {"ink": hex_rgba(BRASS)})
        cv.circle(0.5, 0.5, 1.0, BRASS)  # disc d plus a rim of 0.08 d each side = 1.16 d
        cv.circle(0.5, 0.5, 1.0 / 1.16, cat)
        g = size / 1.16 * 0.64
        colors = {"ink": hex_rgba("#FFFFFF"), "bg": hex_rgba(cat), "acc": hex_rgba(BRASS_LIGHT), "acc2": hex_rgba(BRASS_LIGHT), "hi": hex_rgba(cat)}
        draw_ops(Canvas(layer, m + (size - g) / 2, m + (size - g) / 2, g, colors), icons[name])
    img.alpha_composite(layer.final(), (int(x - m), int(y - m)))


def main():
    icons = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    cell, pad = 104, 14
    cols = 10
    rows = 0
    for _, names in GROUPS:
        rows += 1 + (len(names) + cols - 1) // cols
    W = cols * (cell * 3 + pad) + pad
    H = rows * (cell + 26) + 60
    img = Image.new("RGBA", (W, H), hex_rgba("#2A1C13"))
    d = ImageDraw.Draw(img)
    d.text((pad, 14), "Trapisque icon set  -  ink on parchment / burned into wood / token medallion", font=font("display", 28), fill=hex_rgba("#FFE39A"))
    y = 60
    for title, names in GROUPS:
        d = ImageDraw.Draw(img)
        d.text((pad, y + 4), title, font=font("chunky", 22), fill=hex_rgba("#E3B04B"))
        y += cell // 2 + 4
        for i, name in enumerate(names):
            if name not in icons:
                continue
            col = i % cols
            if i and col == 0:
                y += cell + 26
            x = pad + col * (cell * 3 + pad)
            d = ImageDraw.Draw(img)
            d.rounded_rectangle([x, y, x + cell - 4, y + cell - 4], radius=10, fill=hex_rgba(PARCH))
            d.rounded_rectangle([x + cell, y, x + 2 * cell - 4, y + cell - 4], radius=10, fill=hex_rgba(WOOD))
            draw_icon(img, icons, name, x + 12, y + 12, cell - 28, "ink")
            draw_icon(img, icons, name, x + cell + 12, y + 12, cell - 28, "engrave")
            draw_icon(img, icons, name, x + 2 * cell + 8, y + 8, cell - 20, "medallion")
            d = ImageDraw.Draw(img)
            d.text((x + 4, y + cell - 2), name, font=font("body", 15), fill=hex_rgba("#F3E4C1"))
        y += cell + 30
    img = img.crop((0, 0, W, y + 10))
    img.convert("RGB").save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main()
