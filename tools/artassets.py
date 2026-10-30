"""
The art sheets' uploads: src/client/UI/ArtAssets.lua (each sheet's Roblox image id, and
the version of the sheet that was uploaded) and the sheets' current versions in
src/client/UI/ArtAtlas.lua. Shared by tools/art.py and tools/upload_art.py.
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = os.path.join(ROOT, "src", "client", "UI", "ArtAtlas.lua")
ASSETS = os.path.join(ROOT, "src", "client", "UI", "ArtAssets.lua")
DATA = os.path.join(ROOT, "src", "client", "UI", "ArtData")
SHEETS = os.path.join(ROOT, "art", "sheets")


def read():
    """What ArtAssets.lua says was uploaded: { sheet: (image id, version) }. An id written
    in by hand without a version (sheet = 123,) has version None: taken as current."""
    known = {}
    if os.path.exists(ASSETS):
        with open(ASSETS, encoding="utf-8") as fh:
            text = fh.read()
        for m in re.finditer(r'^\t([a-z0-9_]+) = \{ id = (\d+), version = "([0-9a-f]*)" \},', text, re.M):
            known[m.group(1)] = (int(m.group(2)), m.group(3))
        for m in re.finditer(r"^\t([a-z0-9_]+) = (\d+),", text, re.M):
            known.setdefault(m.group(1), (int(m.group(2)), None))
    return known


def write(entries):
    """ArtAssets.lua from [(sheet, id, version)], in that order."""
    lines = [
        "--[[",
        "\tArtAssets",
        "\tThe Roblox image id each art sheet (art/sheets/<sheet>.png) was uploaded as, and the",
        "\tversion of the sheet it was (ArtAtlas.versions). An upload is used only while its",
        "\tversion is the sheet's current one: after the art changes, the sheets that changed",
        "\tneed uploading again (their sprites moved). id = 0: not uploaded, so the game builds",
        "\tthat sheet itself from ArtData (Art.lua).",
        "",
        "\tTo fill an id in: upload the sheet (tools/upload_art.py, or the import button of",
        "\tStudio's Asset Manager) and put its image id where this says id = 0, leaving the",
        "\tversion as it is (tools/upload_art.py sheet=id does that for an id uploaded by hand).",
        "]]",
        "",
        "return {",
    ]
    for name, id_, ver in entries:
        lines.append(f'\t{name} = {{ id = {id_}, version = "{ver}" }},')
    lines += ["}", ""]
    with open(ASSETS, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


def versions():
    """The sheets' current versions, from ArtAtlas.lua: { sheet: version }, in sheet order."""
    with open(ATLAS, encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"^\tversions = \{ (.*) \},$", text, re.M)
    if not m:
        raise SystemExit("ArtAtlas.lua has no sheet versions: run tools/art.py first")
    return dict(re.findall(r'([a-z0-9_]+) = "([0-9a-f]+)"', m.group(1)))


def current(known, vers):
    """The sheets whose upload is of their current version."""
    out = set()
    for name, ver in vers.items():
        id_, up = known.get(name, (0, None))
        if id_ > 0 and (up is None or up == ver):
            out.add(name)
    return out
