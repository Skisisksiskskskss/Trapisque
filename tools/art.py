#!/usr/bin/env python3
"""
Builds the game's image art: every illustration in art/ (hand-written SVG, plus the
playing pieces that art/pieces.py writes) is rendered to PNG and packed into a few
1024 x 1024 sheets, the files that get uploaded to Roblox once.

    python3 tools/art.py            # art/sheets/*.png (the files to upload), art/contact.png
                                    # (every sprite at a glance), src/client/UI/ArtAtlas.lua
                                    # (sprite -> sheet, rect, and each sheet's version),
                                    # src/client/UI/ArtAssets.lua (each sheet's uploaded
                                    # image id, kept), and src/client/UI/ArtData/<sheet>.lua
                                    # for every sheet whose upload isn't current (its
                                    # pixels, so the game can build it itself: see Art.lua)

Each SVG says its own pixel size with width= and height= (the viewBox is whatever was
easiest to draw in). A sprite's name is its group and file name: "props/palm",
"ground/tuft", "emblems/mage", "cards/spike", "kraken/arm_0", "pieces/paint_mage". Needs cairosvg, Pillow, numpy
and zstandard (pip install cairosvg pillow numpy zstandard).

Sprites are trimmed to what's drawn (the atlas keeps where that sits in the full
canvas, so the game still places it by the canvas) and packed skyline-style: the props
share the "scenery" sheets, the pieces theirs, the emblems, cards and the Kraken the
"icons" ones (so changing a prop only moves the scenery sheets).

Each sheet has a version: a hash of what's on it (every sprite's name, place and source).
An uploaded sheet is only used while its version is the current one, so after the art
changes, the sheets that changed have to be uploaded again (tools/upload_art.py); the
others keep their ids. The version comes from the sources, not the pixels, so drawing the
same art again on another machine doesn't make the uploads look out of date.
"""
import hashlib
import importlib.util
import io
import os
import sys

import artassets
import cairosvg
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")
OUT = os.path.join(ART, "sheets")
ATLAS = os.path.join(ROOT, "src", "client", "UI", "ArtAtlas.lua")
DATA = os.path.join(ROOT, "src", "client", "UI", "ArtData")
SHEET = 1024
PAD = 4  # transparent pixels around every sprite, so filtering never bleeds a neighbour in
# bump when the sheets' processing changes in a way an old upload shouldn't survive
PIPELINE = "2: alpha bled"
SOURCES = {}  # sprite name -> hash of what it was drawn from (its SVG, or its PNG file)
STRIP = 256  # rows per strip of a sheet's pixels in ArtData (each unpacks to 1 MB at most)

# the groups (a folder of SVGs or PNGs and/or a generator, art/<group>.py), and which share
# runs of sheets: the props, the ground's little things and the maps' pictures (art/maps:
# the map vote's, drawn by the game itself: tools/shots.sh thumbs) together; the pieces and what the
# board shows on its tiles (art/items.py: things on a tile; art/tiles.py: what a tile
# turns into, and what stands across the trail facing it); the characters' emblems and
# the cards' icons (art/emblems.py, art/cards.py) with the Kraken's frames (art/kraken.py)
GROUPS = ["props", "ground", "maps", "pieces", "items", "tiles", "emblems", "cards", "kraken"]
RUNS = [("scenery", ["props", "ground", "maps"]), ("pieces", ["pieces", "items", "tiles"]), ("icons", ["emblems", "cards", "kraken"])]


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
                elif f.endswith(".png"):
                    with open(os.path.join(folder, f), "rb") as fh:
                        SOURCES[f"{group}/{f[:-4]}"] = hashlib.sha1(fh.read()).hexdigest()
                    img = Image.open(os.path.join(folder, f)).convert("RGBA")
                    sprites.append((group, f"{group}/{f[:-4]}", (img, (0, 0), img.size)))
        items += generated(group)
        for name, svg in items:
            w, h = svg_size(svg)
            if not w or not h:
                sys.exit(f"{group}/{name}: the <svg> needs width= and height=")
            SOURCES[f"{group}/{name}"] = hashlib.sha1(svg.encode("utf-8")).hexdigest()
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


def bleed(img: Image.Image, steps: int = PAD) -> Image.Image:
    """Alpha bleeding: the see-through pixels round each sprite take the colour of the
    nearest drawn ones (and stay see-through), so when Roblox scales a sprite down its
    edges fade into its own colours, not into a dark fringe."""
    a = np.asarray(img).astype(np.float32)
    rgb, alpha = a[..., :3].copy(), a[..., 3]
    known = alpha > 0
    h, w = known.shape
    for _ in range(steps):
        kp = np.pad(known, 1).astype(np.float32)
        cp = np.pad(rgb * known[..., None], ((1, 1), (1, 1), (0, 0)))
        total = np.zeros_like(rgb)
        count = np.zeros((h, w), np.float32)
        for dy in (0, 1, 2):
            for dx in (0, 1, 2):
                if dy != 1 or dx != 1:
                    total += cp[dy:dy + h, dx:dx + w]
                    count += kp[dy:dy + h, dx:dx + w]
        grow = ~known & (count > 0)
        if not grow.any():
            break
        rgb[grow] = total[grow] / count[grow][:, None]
        known |= grow
    return Image.fromarray(np.dstack([np.clip(np.rint(rgb), 0, 255), alpha]).astype(np.uint8), "RGBA")


def version(rects) -> str:
    """A sheet's version: what's on it and where, and what each sprite was drawn from."""
    h = hashlib.sha1(f"pipeline {PIPELINE}\n".encode())
    for name, x, y, w, ht, ox, oy, ow, oh in sorted(rects):
        h.update(f"{name}:{x},{y},{w},{ht},{ox},{oy},{ow},{oh}:{SOURCES[name]}\n".encode())
    return h.hexdigest()[:12]


def write_atlas(sheets, versions):
    lines = [
        "--[[",
        "\tArtAtlas (generated by tools/art.py: don't edit)",
        "\tWhere every sprite sits in the uploaded sheets: sprites[name] = { sheet, x, y, w, h },",
        "\tand where that trimmed part sits in the sprite's whole canvas: ox, oy of ow x oh.",
        "\tversions[sheet]: what's on that sheet now (an upload of another version doesn't fit).",
        "]]",
        "",
        "return {",
        "\tsheets = { " + ", ".join(f'"{s[0]}"' for s in sheets) + " },",
        "\tversions = { " + ", ".join(f'{s[0]} = "{versions[s[0]]}"' for s in sheets) + " },",
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


def write_assets(sheets, known, versions):
    """ArtAssets.lua: one entry per sheet. Uploads are kept with the version they were of;
    a sheet not uploaded gets its current version, ready for its id. Returns which sheets
    have a current upload."""
    entries = []
    for name, _, _ in sheets:
        id_, ver = known.get(name, (0, None))
        if id_ <= 0:
            id_, ver = 0, versions[name]
        elif ver is None:
            ver = versions[name]
        entries.append((name, id_, ver))
    artassets.write(entries)
    current = artassets.current({n: (i, v) for n, i, v in entries}, versions)
    stale = [name for name, _, _ in sheets if name not in current]
    if stale:
        print("to upload (new, or changed since their upload): " + ", ".join(stale))
    return current


def write_data(sheets, current):
    """ArtData/<sheet>.lua for every sheet without a current upload: its pixels (as far
    down as anything is drawn), in strips of STRIP rows, each zstd-compressed and in
    base64, which Art turns into an EditableImage. Each strip is checked by unpacking it
    again."""
    import base64

    import zstandard

    os.makedirs(DATA, exist_ok=True)
    keep = set()
    for name, img, rects in sheets:
        if name in current:
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
    sheets = [(name, bleed(img), rects) for name, img, rects in pack(sprites)]
    versions = {name: version(rects) for name, _, rects in sheets}
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    for name, img, rects in sheets:
        img.save(os.path.join(OUT, name + ".png"), optimize=True)
        print(f"{name}.png: {len(rects)} sprites")
    contact(sprites).convert("RGB").save(os.path.join(ART, "contact.png"))
    write_atlas(sheets, versions)
    current = write_assets(sheets, artassets.read(), versions)
    write_data(sheets, current)
    print(f"{len(sprites)} sprites on {len(sheets)} sheets; atlas in {os.path.relpath(ATLAS, ROOT)}")


if __name__ == "__main__":
    main()
