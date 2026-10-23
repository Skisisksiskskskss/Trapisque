#!/usr/bin/env python3
"""
Builds the game's image art: every illustration in art/ (hand-written SVG, plus the
playing pieces that art/pieces.py writes) is rendered to PNG and packed into a few
1024 x 1024 sheets, the files that get uploaded to Roblox once.

    python3 tools/art.py            # art/sheets/*.png (the files to upload), art/contact.png
                                    # (every sprite at a glance), src/client/UI/ArtAtlas.lua
                                    # (sprite -> sheet, rect), the sheet list in ArtAssets.lua,
                                    # and src/client/UI/ArtData/<sheet>.lua for every sheet
                                    # not uploaded yet (its pixels, so the game can build it
                                    # itself: see Art.lua)

Each SVG says its own pixel size with width= and height= (the viewBox is whatever was
easiest to draw in). A sprite's name is its group and file name: "props/palm",
"ground/tuft", "portraits/mage", "pieces/paint_mage". Needs cairosvg, Pillow and zstandard
(pip install cairosvg pillow zstandard).

Sprites are trimmed to what's drawn (the atlas keeps where that sits in the full
canvas, so the game still places it by the canvas) and packed skyline-style: the props
and portraits share the "scenery" sheets, the pieces have their own (so changing a prop
only moves the scenery sheets).
"""
import importlib.util
import io
import os
import sys

import cairosvg
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")
OUT = os.path.join(ART, "sheets")
ATLAS = os.path.join(ROOT, "src", "client", "UI", "ArtAtlas.lua")
ASSETS = os.path.join(ROOT, "src", "client", "UI", "ArtAssets.lua")
DATA = os.path.join(ROOT, "src", "client", "UI", "ArtData")
SHEET = 1024
PAD = 4  # transparent pixels around every sprite, so filtering never bleeds a neighbour in
STRIP = 256  # rows per strip of a sheet's pixels in ArtData (each unpacks to 1 MB at most)

# the groups (a folder of SVGs and/or a generator, art/<group>.py), and which share runs of
# sheets: the props, the ground's little things and the portraits together, the pieces
# and what the board shows on its tiles (art/items.py: things on a tile; art/tiles.py:
# what a tile turns into, and what stands across the trail facing it)
GROUPS = ["props", "ground", "portraits", "pieces", "items", "tiles"]
RUNS = [("scenery", ["props", "ground", "portraits"]), ("pieces", ["pieces", "items", "tiles"])]


def svg_size(svg: str):
    import re

    def attr(name):
        m = re.search(r'<svg[^>]*\s' + name + r'="([0-9.]+)"', svg)
        return int(float(m.group(1))) if m else None

    return attr("width"), attr("height")


def render(svg: str, w: int, h: int) -> Image.Image:
    png = cairosvg.svg2png(bytestring=svg.encode("utf-8"), output_width=w, output_height=h)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def generated(group: str):
    path = os.path.join(ART, group + ".py")
    if not os.path.exists(path):
        return []
    spec = importlib.util.spec_from_file_location("art_" + group, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.sprites()  # [(name, svg)]


def collect():
    sprites = []  # (name, image)
    for group in GROUPS:
        folder = os.path.join(ART, group)
        items = []
        if os.path.isdir(folder):
            for f in sorted(os.listdir(folder)):
                if f.endswith(".svg"):
                    with open(os.path.join(folder, f), encoding="utf-8") as fh:
                        items.append((f[:-4], fh.read()))
        items += generated(group)
        for name, svg in items:
            w, h = svg_size(svg)
            if not w or not h:
                sys.exit(f"{group}/{name}: the <svg> needs width= and height=")
            sprites.append((group, f"{group}/{name}", trim(render(svg, w, h))))
    return sprites


def trim(img):
    """(the drawn part, its offset in the canvas, the canvas size)"""
    box = img.getchannel("A").point(lambda a: 255 if a > 0 else 0).getbbox() or (0, 0, 1, 1)
    return img.crop(box), (box[0], box[1]), img.size


def place(skyline, w, h):
    """Bottom-left skyline packing: where a w x h box goes lowest (x, y), or None."""
    best = None
    for i in range(len(skyline)):
        x = skyline[i][0]
        if x + w > SHEET:
            break
        # the box rests on the highest segment it spans
        y, span, j = 0, 0, i
        while span < w:
            y = max(y, skyline[j][1])
            span += skyline[j][2]
            j += 1
        if y + h <= SHEET and (best is None or (y, x) < (best[1], best[0])):
            best = (x, y, i)
    return best


def settle(skyline, x, y, w, h, i):
    skyline.insert(i, [x, y + h, w])
    # trim the segments the box now covers
    j = i + 1
    while j < len(skyline) and skyline[j][0] < x + w:
        seg = skyline[j]
        cut = x + w - seg[0]
        if cut >= seg[2]:
            skyline.pop(j)
        else:
            seg[0] += cut
            seg[2] -= cut
            break
    # merge neighbours at the same height
    k = 0
    while k < len(skyline) - 1:
        if skyline[k][1] == skyline[k + 1][1]:
            skyline[k][2] += skyline[k + 1][2]
            skyline.pop(k + 1)
        else:
            k += 1


def pack(sprites):
    """Skyline packing (tallest first), each run of groups on its own sheets."""
    sheets = []  # [(sheet name, image, [(sprite, x, y, w, h, ox, oy, ow, oh)])]
    for run, groups in RUNS:
        mine = [s for s in sprites if s[0] in groups]
        mine.sort(key=lambda s: (-s[2][0].height, -s[2][0].width, s[1]))
        count = 0
        while mine:
            count += 1
            sheet = (f"{run}_{count}", Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0)), [])
            skyline = [[0, 0, SHEET]]
            left = []
            for item in mine:
                _, name, (img, (ox, oy), (ow, oh)) = item
                w, h = img.width + 2 * PAD, img.height + 2 * PAD
                if w > SHEET or h > SHEET:
                    sys.exit(f"{name} is bigger than a sheet")
                spot = place(skyline, w, h)
                if spot is None:
                    left.append(item)
                    continue
                x, y, i = spot
                settle(skyline, x, y, w, h, i)
                sheet[1].alpha_composite(img, (x + PAD, y + PAD))
                sheet[2].append((name, x + PAD, y + PAD, img.width, img.height, ox, oy, ow, oh))
            sheets.append(sheet)
            mine = left
    return sheets


def write_atlas(sheets):
    lines = [
        "--[[",
        "\tArtAtlas (generated by tools/art.py: don't edit)",
        "\tWhere every sprite sits in the uploaded sheets: sprites[name] = { sheet, x, y, w, h },",
        "\tand where that trimmed part sits in the sprite's whole canvas: ox, oy of ow x oh.",
        "]]",
        "",
        "return {",
        "\tsheets = { " + ", ".join(f'"{s[0]}"' for s in sheets) + " },",
        "\tsprites = {",
    ]
    for sheet, _, rects in sheets:
        for name, x, y, w, h, ox, oy, ow, oh in sorted(rects):
            lines.append(
                f'\t\t["{name}"] = {{ sheet = "{sheet}", x = {x}, y = {y}, w = {w}, h = {h}, ox = {ox}, oy = {oy}, ow = {ow}, oh = {oh} }},'
            )
    lines += ["\t},", "}", ""]
    with open(ATLAS, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


def uploaded():
    """The image ids already filled in ArtAssets.lua: { sheet: id }."""
    import re

    known = {}
    if os.path.exists(ASSETS):
        with open(ASSETS, encoding="utf-8") as fh:
            for m in re.finditer(r"^\t([a-z0-9_]+) = (\d+),", fh.read(), re.M):
                known[m.group(1)] = int(m.group(2))
    return known


def write_assets(sheets, known):
    """ArtAssets.lua: one line per sheet; ids already filled in are kept."""
    lines = [
        "--[[",
        "\tArtAssets",
        "\tThe Roblox image ids of the art sheets (art/sheets/*.png, uploaded with Studio's",
        "\tAsset Manager > Bulk Import). 0 = not uploaded: the game builds that sheet itself",
        "\tfrom ArtData (Art.lua). Re-run tools/art.py after changing the art, then upload",
        "\tthe sheets again: their contents move, so their old ids no longer fit.",
        "]]",
        "",
        "return {",
    ]
    for name, _, _ in sheets:
        lines.append(f"\t{name} = {known.get(name, 0)},")
    lines += ["}", ""]
    with open(ASSETS, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


def write_data(sheets, known):
    """ArtData/<sheet>.lua for every sheet without an image id: its pixels (as far down as
    anything is drawn), in strips of STRIP rows, each zstd-compressed and in base64, which
    Art turns into an EditableImage. Each strip is checked by unpacking it again."""
    import base64

    import zstandard

    os.makedirs(DATA, exist_ok=True)
    keep = set()
    for name, img, rects in sheets:
        if known.get(name, 0) > 0:
            continue
        height = min(SHEET, max(y + h + PAD for _, _, y, _, h, *_ in rects))
        lines = [
            f"-- The {name} sheet's pixels (generated by tools/art.py: don't edit): {SHEET} x {height},",
            f"-- RGBA rows in strips of {STRIP}, each zstd-compressed and in base64. Art builds the",
            "-- sheet from them when it has no uploaded image id.",
            "return {",
            f"\twidth = {SHEET},",
            f"\theight = {height},",
            f"\tstrip = {STRIP},",
            "\tstrips = {",
        ]
        total = 0
        for top in range(0, height, STRIP):
            pixels = img.crop((0, top, SHEET, min(height, top + STRIP))).tobytes()
            packed = base64.b64encode(zstandard.ZstdCompressor(level=19).compress(pixels)).decode("ascii")
            if zstandard.ZstdDecompressor().decompress(base64.b64decode(packed)) != pixels:
                sys.exit(f"{name}: the strip at row {top} doesn't unpack to the sheet")
            total += len(packed)
            lines.append("\t\t{")
            for i in range(0, len(packed), 4000):
                lines.append(f'\t\t\t"{packed[i:i + 4000]}",')
            lines.append("\t\t},")
        lines += ["\t},", "}", ""]
        with open(os.path.join(DATA, name + ".lua"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines))
        keep.add(name + ".lua")
        print(f"ArtData/{name}.lua: {total // 1024} KB")
    for f in os.listdir(DATA):
        if f.endswith(".lua") and f not in keep:
            os.remove(os.path.join(DATA, f))


def contact(sprites):
    """Every sprite on a grey card, for looking the whole set over."""
    cell = 180
    cols = 8
    rows = (len(sprites) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (214, 208, 196, 255))
    d = ImageDraw.Draw(sheet)
    for i, (_, name, (img, _, _)) in enumerate(sprites):
        cx, cy = (i % cols) * cell, (i // cols) * cell
        k = min((cell - 30) / img.width, (cell - 30) / img.height)
        small = img.resize((max(1, int(img.width * k)), max(1, int(img.height * k))), Image.LANCZOS)
        sheet.alpha_composite(small, (cx + (cell - small.width) // 2, cy + 4))
        d.text((cx + 6, cy + cell - 18), name.split("/", 1)[1][:24], fill=(60, 56, 52, 255))
    return sheet


def main():
    sprites = collect()
    sheets = pack(sprites)
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    for name, img, rects in sheets:
        img.save(os.path.join(OUT, name + ".png"), optimize=True)
        print(f"{name}.png: {len(rects)} sprites")
    contact(sprites).convert("RGB").save(os.path.join(ART, "contact.png"))
    write_atlas(sheets)
    known = uploaded()
    write_assets(sheets, known)
    write_data(sheets, known)
    print(f"{len(sprites)} sprites on {len(sheets)} sheets; atlas in {os.path.relpath(ATLAS, ROOT)}")


if __name__ == "__main__":
    main()
