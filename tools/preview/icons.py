#!/usr/bin/env python3
"""Contact sheet of the icon set as the game draws it now (developer preview tool).

IconData glyphs appear in two places in the sticker style:
  - on candy buttons (Widgets.button / iconButton): the glyph in the button's text
    colour with the line-coloured sticker outline (0.07 of the glyph)
  - in medallions (Icons.medallion): a coloured disc with the line stroke and a shine,
    showing the sticker art when the id has one (a card, a character's mascot, a misc
    sticker: Icons.stickerFor) and otherwise the white glyph

Usage: python3 tools/preview/icons.py board.json out.png
       (board.json from tests/dump_board.luau: IconData, StickerArt and the palette)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from screens import Stage, background, icon_button  # noqa: E402
from board import stage_art  # noqa: E402

GROUPS = [
    ("Interface", "wood", "panelHi", ["gem", "crown", "dice", "lock", "gear", "book", "bag", "hanger", "people", "play", "close", "back",
                                       "forward", "up", "down", "check", "plus", "minus", "star", "sparkles", "hourglass", "swap", "eye",
                                       "info", "chat", "smile", "bubble", "bolt", "level", "music", "speaker", "exit", "map", "heart",
                                       "skull", "compass", "flag", "chest", "x_mark", "coin", "clover"]),
    ("Board tokens and hazards", "purple", "grape", ["token_trap", "token_assist", "token_neutral", "token_potion", "river_trap",
                                                    "gate_trap", "slime_trap"]),
    ("Characters", "blue", "sky", ["mage", "trapper", "fire_starter", "naturalist", "warper", "overseer"]),
    ("Cards (their medallions show the card's sticker)", "red", "coral",
     ["spike", "fire", "ice", "mudslide", "wall", "snare", "grog", "speed_boost", "bounce_pad", "moonwalk", "bridge", "key", "boots",
      "shield", "teleporter", "spore_warper", "conveyor", "speed_potion", "phoenix_potion", "time_potion", "telepathy_potion",
      "jeopardy_potion"]),
]


def main():
    data = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    theme = data["theme"]
    C = theme["C"]
    art = stage_art(data)
    icons = art["icons"]
    cell_w, cell_h, cols, pad = 150, 110, 11, 20
    rows = sum(1 + (len([n for n in names if n in icons]) + cols - 1) // cols for _, _, _, names in GROUPS)
    W = pad * 2 + cols * cell_w
    H = 70 + rows * cell_h + 40
    st = Stage(W, H, ss=3, art=art, theme=theme)
    background(st)
    st.label(pad, 16, W - 2 * pad, 40, "Icons: on candy buttons, and in medallions (sticker art where there is some)", "chunky", 28,
             C["text"], outline=C["line"], outline_t=3)
    y = 70
    for title, style, color, names in GROUPS:
        st.label(pad, y, W - 2 * pad, 34, title, "chunky", 22, C["sun"], outline=C["line"], outline_t=2)
        y += 44
        names = [n for n in names if n in icons]
        for i, name in enumerate(names):
            col, row = i % cols, i // cols
            x = pad + col * cell_w
            yy = y + row * cell_h
            icon_button(st, x + 14, yy, 52, 54, name, style=style)
            st.medallion(name, x + 14 + 52 + 12 + 24, yy + 25, 48, C.get(color, color))
            st.label(x, yy + 62, cell_w - 6, 18, name, "heavy", 13, C["textSoft"], align="center", truncate=True)
        y += ((len(names) + cols - 1) // cols) * cell_h + 10
    img = st.img.crop((0, 0, st.img.width, int(y * st.ss))).resize((W, int(y)), resample=3)
    img.convert("RGB").save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main()
