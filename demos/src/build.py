#!/usr/bin/env python3
"""Inline the shared kit and each game's sources into single-file HTML games.

Usage: python3 demos/src/build.py [game ...] [--artifacts DIR]

For each game folder in demos/src (other than kit/ and test/), reads page.html
and replaces {{KIT_CSS}}, {{GAME_CSS}}, {{KIT_JS}}, {{LOGIC_JS}} and {{UI_JS}}.
Writes demos/<game>/index.html (a full standalone page) and, with --artifacts,
DIR/<game>.html (the same page without the document skeleton, for publishing
as a claude.ai artifact)."""
import pathlib
import sys

SRC = pathlib.Path(__file__).resolve().parent
DEMOS = SRC.parent


def read(path):
    return path.read_text(encoding="utf-8") if path.exists() else ""


def build(game, artifacts_dir=None):
    gdir = SRC / game
    page = read(gdir / "page.html")
    if not page:
        raise SystemExit(f"{game}: missing page.html")
    parts = {
        "KIT_CSS": read(SRC / "kit" / "kit.css"),
        "KIT_JS": read(SRC / "kit" / "kit.js"),
        "GAME_CSS": read(gdir / "game.css"),
        "LOGIC_JS": read(gdir / "logic.js"),
        "UI_JS": read(gdir / "ui.js"),
    }
    for key, val in parts.items():
        page = page.replace("{{" + key + "}}", val)
    if "{{" in page and "}}" in page.split("{{", 1)[1]:
        leftover = page.split("{{", 1)[1].split("}}", 1)[0]
        if leftover.isupper():
            raise SystemExit(f"{game}: unreplaced placeholder {{{{{leftover}}}}}")
    head, body = page.split("<!--BODY-->", 1)
    standalone = (
        "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n"
        + head.strip() + "\n</head>\n<body>\n" + body.strip() + "\n</body>\n</html>\n"
    )
    out = DEMOS / game / "index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(standalone, encoding="utf-8")
    if artifacts_dir:
        ad = pathlib.Path(artifacts_dir)
        ad.mkdir(parents=True, exist_ok=True)
        (ad / f"{game}.html").write_text(head.rstrip() + "\n" + body.lstrip(), encoding="utf-8")
    print(f"built {game}: {len(standalone):,} bytes")


def main(argv):
    artifacts = None
    if "--artifacts" in argv:
        i = argv.index("--artifacts")
        artifacts = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    games = argv or sorted(p.name for p in SRC.iterdir() if p.is_dir() and p.name not in ("kit", "test") and (p / "page.html").exists())
    for g in games:
        build(g, artifacts)


if __name__ == "__main__":
    main(sys.argv[1:])
