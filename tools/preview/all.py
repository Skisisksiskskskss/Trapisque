#!/usr/bin/env python3
"""Regenerates every preview in docs/previews (developer preview tool).

Runs the dumps (tests/dump_*.luau, bundled by tools/bundle.py after
tests/preview_skins.luau, then run with the Luau CLI) into a work folder, then every
renderer:

  01-icons.png               icons.py      IconData on candy buttons and in medallions
  02..04-board-<map>.png     board.py      each map mid-game
  05-collectibles.png        cosmetics.py  every cosmetic, on tiles like the Locker's
  06-cards.png               cards.py      every card front and back, and the characters
  07-match-<device>.png      hud.py        the match screen (PC, phone sideways, upright)
  08-lobby-<device>.png      lobby.py      the lobby (+ the Top tab on an upright phone)
  09-treasure-chests.png     pages.py      the chests page
  10-stickers.png            stickers.py   the sticker art and the cast
  11 / 12 / 13               moments.py    hovering a card, placing it, the slam (GIF)
  14 / 15 / 16               pages.py      characters, daily quests, results
  17-loading-<device>.png    pages.py      the loading splash

Usage: python3 tools/preview/all.py [outdir (docs/previews)] [workdir (a temp folder)]
Env:   LUAU = the Luau CLI (default: "luau" on PATH); TRAPISQUE_FONTS = the fonts folder
       (Luckiest Guy and Nunito from Google Fonts; default tools/preview/fonts).
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

DUMPS = {
    # name: (entries bundled in order)
    "board": ["tests/preview_skins.luau", "tests/dump_board.luau"],
    "screens": ["tests/preview_skins.luau", "tests/dump_screens.luau"],
    "cards": ["tests/preview_skins.luau", "tests/dump_cards.luau"],
    "stickers": ["tests/dump_stickers.luau"],
    "cosmetics": ["tests/dump_cosmetics.luau"],
}


def run(args, **kw):
    print("+", " ".join(args), flush=True)
    subprocess.run(args, check=True, cwd=ROOT, **kw)


def main():
    outdir = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "previews")
    work = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else tempfile.mkdtemp(prefix="trapisque-previews-")
    os.makedirs(outdir, exist_ok=True)
    os.makedirs(work, exist_ok=True)
    luau = os.environ.get("LUAU", "luau")
    py = sys.executable
    for name, entries in DUMPS.items():
        bundle = os.path.join(work, name + ".luau")
        run([py, os.path.join(ROOT, "tools", "bundle.py"), bundle] + [os.path.join(ROOT, e) for e in entries])
        with open(os.path.join(work, name + ".json"), "w") as f:
            run([luau, bundle], stdout=f)
    J = lambda n: os.path.join(work, n + ".json")  # noqa: E731
    O = lambda n: os.path.join(outdir, n)  # noqa: E731
    P = lambda s: os.path.join(HERE, s)  # noqa: E731
    run([py, P("icons.py"), J("board"), O("01-icons.png")])
    run([py, P("board.py"), J("board"), outdir])
    run([py, P("cosmetics.py"), J("cosmetics"), O("05-collectibles.png")])
    run([py, P("cards.py"), J("cards"), O("06-cards.png")])
    run([py, P("hud.py"), work, outdir])
    run([py, P("lobby.py"), work, outdir])
    run([py, P("pages.py"), work, outdir])
    run([py, P("stickers.py"), J("stickers"), O("10-stickers.png")])
    run([py, P("moments.py"), work, outdir])
    print("previews in", outdir)


if __name__ == "__main__":
    main()
