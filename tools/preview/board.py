#!/usr/bin/env python3
"""Board previews: each map mid-game, drawn the way client/UI/Match/BoardView.lua builds
it (developer preview tool).

Everything is drawn in BoardView's world pixels (U = 46 per hex unit) through the
Stage transform, so the same code draws the standalone board sheets and the board under
the match HUD (where BoardView's camera fits the tiles into Layout.match's focus rect):

  paper with the line stroke, the sea / stone / swamp wash and two neatlines; a
  coastline of discs around the route; doodles and the compass (DecorData); the map's
  title on a tilted sun ribbon; dashed links; then the tiles, lower ones over upper
  ones: a darker side, the line-coloured rim and the top (tinted by what's on it), with
  whatever the tile holds as a sticker (BoardView:_paintTile): a token on its category
  disc, a hazard, a board piece on its owner's colour (the "plaque"), the conveyor's
  steel band with two sun chevrons, a hidden trap the viewer may see (see-through, rimmed
  in its owner's colour), embers, the start flag / treasure chest / gate. Then the pawns:
  the pawn cosmetic in the seat colour with the character mascot standing on it, the
  status marks (ice block, flames, zzz) and the turn ring; then the path preview
  (BoardView:showPath) and, in screen space, the name tag and the path's badges.

The colours are read from BoardView.lua itself (THEMES / TILE_COLORS / TOP), so the
previews follow the game if they change.

Usage: python3 tools/preview/board.py board.json outdir
       (board.json from tests/dump_board.luau, bundled after tests/preview_skins.luau)
Writes 02-board-blissful-tricks.png, 03-board-junction-dungeon.png and
04-board-slimy-snares.png (numbered in map order) into outdir.
"""
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from screens import Stage, WHITE, mix, shade, background, badge, badge_width  # noqa: E402
from cosmetics import draw_pawn  # noqa: E402
from PIL import Image  # noqa: E402

UNIT = 46  # BoardView U: world pixels per hex unit
HERE = os.path.dirname(os.path.abspath(__file__))
BOARDVIEW = os.path.join(HERE, "..", "..", "src", "client", "UI", "Match", "BoardView.lua")

# BoardView.lua's constants (used if the file can't be read; normally parsed from it)
THEMES = {
    "water": {"paper": "#1A1F4A", "wash": "#1F3D7A", "washA": 0.9, "land": "#2D2D66", "ink": "#6FA8FF", "acc": "#2C4C8A", "acc2": "#FF6FB8"},
    "dungeon": {"paper": "#1F1636", "wash": "#2E2350", "washA": 0.9, "land": "#3A2E62", "ink": "#A98BEA", "acc": "#4C3780", "acc2": "#FF9A3C"},
    "swamp": {"paper": "#17222E", "wash": "#1D3F3A", "washA": 0.9, "land": "#2A3A46", "ink": "#7FE0A8", "acc": "#2E5A4A", "acc2": "#A6E83A"},
}
TILE_COLORS = {"normal": "#FFF4E2", "branch": "#DCCFF7", "start": "#9BE8FF", "treasure": "#FFD23F", "shortcutGate": "#C9D3E6"}
TOP = {"river": "#7FD3FF", "gate": "#C9D3E6", "slime": "#C8F07A", "wall": "#F2CC94", "teleporter": "#C9B0FF",
       "spore_warper": "#B9EE8A", "conveyor": "#AEB8CF", "trampoline": "#FFB3DA", "embers": "#FFC58A"}
TILE_NUMBER = "#B4A3D8"
BELT = "#8792AD"


def _load_constants():
    """THEMES, TILE_COLORS, TOP and TILE_NUMBER straight from BoardView.lua."""
    global TILE_NUMBER
    try:
        src = open(BOARDVIEW, encoding="utf-8").read()
    except OSError:
        return
    hx = r'hex\("([0-9A-Fa-f]{6})"\)'
    m = re.search(r"local THEMES = \{(.*?)\n\}", src, re.S)
    if m:
        for name, body in re.findall(r"(\w+) = \{(.*?)\}", m.group(1)):
            t = {k: "#" + v.upper() for k, v in re.findall(r"(\w+) = " + hx, body)}
            a = re.search(r"washA = ([\d.]+)", body)
            if a:
                t["washA"] = float(a.group(1))
            if len(t) >= 7:
                THEMES[name] = t
    for table, out in (("TILE_COLORS", TILE_COLORS), ("TOP", TOP)):
        m = re.search(r"local " + table + r" = \{(.*?)\n\}", src, re.S)
        if m:
            for k, v in re.findall(r"(\w+) = " + hx, m.group(1)):
                out[k] = "#" + v.upper()
    m = re.search(r"local TILE_NUMBER = " + hx, src)
    if m:
        TILE_NUMBER = "#" + m.group(1).upper()


_load_constants()


def hexagon(cx, cy, r, flat=False):
    """BoardView's hexagon (three rotated frames): pointy-top, or flat-top when the
    board is turned for an upright phone."""
    base = 0 if flat else 30
    return [(cx + r * math.cos(math.radians(60 * i + base)), cy + r * math.sin(math.radians(60 * i + base))) for i in range(6)]


class BoardScene:
    """One board: its layout (BoardLayout.build), what's on it and the art to draw it."""

    def __init__(self, data, scene):
        self.data = data
        self.L = scene["layout"]
        self.view = scene["view"]
        self.style = data["style"]
        self.slots = data["slots"]
        self.art = data["art"]
        self.theme = THEMES.get(self.L["theme"], THEMES["water"])
        self.flat = bool(self.L.get("rotated"))
        L = self.L
        self.worldW, self.worldH = L["w"] * UNIT, L["h"] * UNIT
        self.pos = {t["id"]: ((t["x"] - L["x0"]) * UNIT, (t["y"] - L["y0"]) * UNIT) for t in L["tiles"]}
        tb = L["tileBounds"]
        self.tileBox = ((tb["x0"] - L["x0"]) * UNIT, (tb["y0"] - L["y0"]) * UNIT, (tb["x1"] - L["x0"]) * UNIT, (tb["y1"] - L["y0"]) * UNIT)
        v = self.view
        self.tokens = {t["tile"]: t["kind"] for t in v.get("tokens", [])}
        self.natural = {n["tile"]: n["kind"] for n in v.get("natural", [])}
        self.placed = {e["tile"]: e for e in v.get("placed", [])}
        self.traps = {}
        for t in v.get("traps", []):
            self.traps.setdefault(t["tile"], []).append(t)
        self.embers = {e["tile"]: e.get("owner", 0) for e in v.get("embers", [])}
        # the conveyor's belt over its tiles (BoardView:_setBelt)
        self.belt = {}
        for e in v.get("placed", []):
            if e["item"] == "conveyor" and e.get("tiles"):
                tiles = e["tiles"]
                for i, t in enumerate(tiles):
                    a, b = t, tiles[i + 1] if i + 1 < len(tiles) else None
                    if b is None:
                        a, b = tiles[i - 1] if i > 0 else t, t
                    pa, pb = self.pos[a], self.pos[b]
                    ang = math.degrees(math.atan2(pb[1] - pa[1], pb[0] - pa[0])) + (180 if e.get("dir") == "back" else 0)
                    self.belt[t] = ang
        # pawns resting on each tile (BoardView:_restPosition)
        self.cover = {}
        for p in v.get("players", []):
            self.cover[p["tile"]] = self.cover.get(p["tile"], 0) + 1

    # ---- helpers ----------------------------------------------------------------
    def seat_color(self, seat):
        seats = self.data["theme"]["Seat"]
        return seats[(seat - 1) % len(seats)]

    def rest(self, seat):
        """BoardView:_restPosition: the pawn's world position and its share scale."""
        players = self.view["players"]
        me = next(p for p in players if p["seat"] == seat)
        here = sorted(p["seat"] for p in players if p["tile"] == me["tile"])
        layout = self.slots[min(len(here), len(self.slots)) - 1]
        slot = layout["at"][here.index(seat)]
        x, y = self.pos[me["tile"]]
        return x + slot[0] * UNIT, y + slot[1] * UNIT, layout["scale"]

    # ---- static layers ------------------------------------------------------------
    def paper(self, st):
        C, T = st.C, self.theme
        W, H = self.worldW, self.worldH
        st.rect(0, 0, W, H, T["paper"], corner=0.35 * UNIT, stroke=(C["line"], 5))
        inset = 0.55 * UNIT
        st.rect(inset, inset, W - 2 * inset, H - 2 * inset, T["wash"], corner=0.3 * UNIT, alpha=T["washA"])
        for i, (o, th, t) in enumerate(((0.3, 3, 0.25), (0.45, 1.5, 0.45)), start=1):
            o *= UNIT
            st.rect(o, o, W - 2 * o, H - 2 * o, None, corner=(0.25 - i * 0.03) * UNIT, stroke=(T["ink"], th, 1 - (t + 0.3)))

    def land(self, st):
        T = self.theme
        coast = mix(T["ink"], T["wash"], 0.25)
        R = self.style["coast"]
        for color, r in ((coast, R), (T["land"], R - 0.07)):
            for t in self.L["tiles"]:
                x, y = self.pos[t["id"]]
                st.circle(x, y, 2 * r * UNIT, color)

    def decor(self, st):
        C, T = st.C, self.theme
        L = self.L
        bg = mix(T["paper"], T["wash"], T["washA"])
        colors = {"ink": mix(T["ink"], T["wash"], 0.22), "bg": bg, "acc": T["acc"], "acc2": T["acc2"], "hi": T["land"]}
        for d in L["decor"]:
            size = d["size"] * UNIT
            cx, cy = (d["x"] - L["x0"]) * UNIT, (d["y"] - L["y0"]) * UNIT
            st.ops(self.art["decor"][d["kind"]], cx - size / 2, cy - size / 2, size, colors, rot=d["rot"], flip=d["flip"])
        cp = L.get("compass")
        if cp:
            size = cp["size"] * UNIT
            cx, cy = (cp["x"] - L["x0"]) * UNIT, (cp["y"] - L["y0"]) * UNIT
            st.ops(self.art["decor"]["compass_rose"], cx - size / 2, cy - size / 2, size,
                   {"ink": T["ink"], "bg": bg, "acc2": C["inkRed"], "acc": T["ink"], "hi": bg})
        # the title on a sun ribbon (Widgets.ribbon at the layout's title spot)
        t = L["title"]
        w, h = t["w"] * UNIT, t["h"] * UNIT
        cx, cy = (t["x"] - L["x0"]) * UNIT, (t["y"] - L["y0"]) * UNIT
        from screens import ribbon
        ribbon(st, cx, cy - h / 2, w, L["name"], height=h, max_text=math.floor(h * 0.62))

    def links(self, st):
        C, T = st.C, self.theme
        for ln in self.L["links"]:
            a, b = self.pos[ln["from"]], self.pos[ln["to"]]
            mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
            w, h = 0.32 * UNIT, 0.12 * UNIT
            if ln["shortcut"]:
                st.rect(mx - w / 2, my - h / 2, w, h, C["inkRed"], corner=0.5, rot=ang)
            else:
                st.rect(mx - w / 2, my - h / 2, w, h, T["ink"], corner=0.5, alpha=0.75, rot=ang)

    # ---- tiles --------------------------------------------------------------------
    def plaque(self, st, item, owner, cx, cy, size):
        """BoardView plaque: a board piece's sticker on a disc in its owner's colour."""
        C = st.C
        color = self.seat_color(owner) if owner and owner > 0 else C["panelRaised"]
        st.circle(cx, cy, size, color, stroke=(C["line"], 0.07 * UNIT))
        art = st.sticker_for(item)
        if art:
            st.sticker(art, cx, cy, 0.86 * size, outline=0.05)

    def trap_mark(self, st, trap, cx, cy, size):
        """BoardView trapMark: a CanvasGroup 1.2 x the disc (GroupTransparency 0.25 unless
        the trap is public): a dark disc rimmed in the owner's colour, the trap's art.
        A CanvasGroup clips to its own bounds."""
        C = st.C
        owner = trap.get("owner") or 0
        color = self.seat_color(owner) if owner > 0 else C["coral"]
        g = size * 1.2
        with st.layer(alpha=1.0 if trap.get("public") else 0.75, clip=(cx - g / 2, cy - g / 2, g, g)):
            st.circle(cx, cy, size, C["panelDeep"], stroke=(color, 0.08 * UNIT))
            art = st.sticker_for(trap["item"])
            if art:
                st.sticker(art, cx, cy, 0.84 * size, outline=0.05)

    def tile(self, st, t):
        """BoardView:_buildTiles + _paintTile for one tile."""
        C, S = st.C, self.style
        tid, kind = t["id"], t["kind"]
        x, y = self.pos[tid]
        natural = self.natural.get(tid)
        belt = self.belt.get(tid)
        entry = self.placed.get(tid)
        token = self.tokens.get(tid)
        traps = self.traps.get(tid)
        ember = tid in self.embers
        top = TILE_COLORS.get(kind) or (TILE_COLORS["branch"] if t.get("branch") else TILE_COLORS["normal"])
        skin = natural
        if not skin and belt is not None:
            skin = "conveyor"
        elif not skin and entry and entry["item"] != "conveyor":
            skin = entry["item"]
        if skin and skin in TOP:
            top = TOP[skin]
        elif ember:
            top = TOP["embers"]
        r = S["tileScale"] * UNIT
        st.poly(hexagon(x, y + S["tileDepth"] * UNIT, r + 0.05 * UNIT, self.flat), shade(top, -0.45))
        st.poly(hexagon(x, y, r + 0.05 * UNIT, self.flat), C["line"])
        st.poly(hexagon(x, y, r, self.flat), top)
        busy = False
        if belt is not None:
            # a steel band with chevrons pointing the way the belt carries you
            s = 1.6 * UNIT
            bw, bh = 0.82 * s, 0.36 * s
            st.rect(x - bw / 2, y - bh / 2, bw, bh, BELT, corner=0.2, stroke=(C["line"], 0.04 * min(bw, bh)), rot=belt)
            st.ops([{"__args": ["chevron", 0.38, 0.5, 0.2, 0.07], "dir": 90, "c": C["sun"]},
                    {"__args": ["chevron", 0.62, 0.5, 0.2, 0.07], "dir": 90, "c": C["sun"]}],
                   x - s / 2, y - s / 2, s, {"ink": C["sun"]}, rot=belt)
            busy = True
        if natural:
            art = self.art["hazards"].get(natural)
            if art:
                st.sticker(art, x, y, 1.2 * UNIT, outline=0.06)
                busy = True
        elif entry:
            self.plaque(st, entry["item"], entry.get("owner"), x, y, 0.86 * UNIT)
            busy = True
        busy_center = natural is not None or entry is not None
        if not busy_center and token:
            # tokens: a bold coloured disc with its symbol
            d = 0.9 * UNIT
            color = self.data["theme"]["Category"].get(token, C["panelRaised"])
            st.circle(x, y, d, color, stroke=(C["line"], 0.07 * UNIT))
            st.rect(x - 0.31 * d, y - 0.5 * d + 0.08 * d, 0.62 * d, 0.28 * d, WHITE, corner=0.5, alpha=0.25)
            art = self.art["tokens"].get(token)
            if art:
                st.sticker(art, x, y, 0.78 * d, outline=0.06)
            busy = True
        elif not busy_center and kind in ("start", "treasure", "shortcutGate"):
            art = {"start": self.art["misc"]["flag"], "treasure": self.art["misc"]["chest"],
                   "shortcutGate": self.art["hazards"]["gate"]}[kind]
            st.sticker(art, x, y, (1.25 if kind == "treasure" else 1.0) * UNIT, outline=0.06)
            busy = True
        if traps:
            # a token on the same tile keeps the middle; the trap tucks into the corner
            small = busy_center or token is not None
            if small:
                self.trap_mark(st, traps[0], x + 0.42 * UNIT, y - 0.36 * UNIT, 0.48 * UNIT)
            else:
                self.trap_mark(st, traps[0], x, y, 0.8 * UNIT)
            busy = True
        if ember:
            st.sticker(self.art["misc"]["flame"], x - 0.42 * UNIT, y - 0.3 * UNIT, 0.62 * UNIT, outline=0.08)
        if not busy and self.cover.get(tid, 0) == 0:
            st.label(x - UNIT / 2, y + 0.5 * UNIT - 0.2 * UNIT, UNIT, 0.4 * UNIT, str(tid), "chunky", math.floor(0.3 * UNIT),
                     TILE_NUMBER, align="center")

    def tiles(self, st):
        for t in sorted(self.L["tiles"], key=lambda q: q["y"]):
            self.tile(st, t)

    # ---- pawns --------------------------------------------------------------------
    def pawn(self, st, p, current=False, mood=None):
        """BoardView:addPawn / _drawMascot / _statusMarks for one player."""
        C = st.C
        x, y, share = self.rest(p["seat"])
        size = self.style["pawn"] * UNIT * share
        x0, y0 = x - size / 2, y - size / 2
        seat = self.seat_color(p["seat"])
        st.circle(x0 + 0.5 * size, y0 + 0.62 * size, 0.96 * size, C["shadow"], alpha=0.55)
        if current:
            d = 1.2 * size
            st.circle(x0 + 0.5 * size, y0 + 0.47 * size, d, None, stroke=(C["sun"], 4 * share))
        looks = self.data["looks"]
        item = {"look": looks.get(p.get("pawn") or "pawn_classic") or looks["pawn_classic"]}
        side = st.L(size)
        tmp = Image.new("RGBA", (int(side * 2) + 4, int(side * 2) + 4), (0, 0, 0, 0))
        draw_pawn(tmp, side / 2, side / 2, side, item, {"patterns": self.data["patterns"]}, seat=seat)
        st.blit(tmp, st.X(x0) - side / 2, st.Y(y0) - side / 2)
        mascots = self.art["mascotMoods"].get(p.get("character") or "mage", {})
        ops = mascots.get(mood or "default") or mascots.get("default")
        st.sticker(ops, x0 + 0.5 * size, y0 + 0.4 * size, 0.9 * size, outline=0.05)
        if (p.get("burning") or 0) > 0:
            s = 0.56 * size
            st.sticker(self.art["misc"]["flame"], x0 + 0.5 * size, y0 + 0.12 * size - s / 2, s, outline=0.08)
        if (p.get("frozen") or 0) > 0:
            s = 0.86 * size
            bx, by = x0 + 0.5 * size - s / 2, y0 + 0.42 * size - s / 2
            st.rect(bx, by, s, s, "#BFEFFF", corner=0.22, alpha=0.55, stroke=("#45C3FF", 0.06 * UNIT * share))
            st.sticker(self.art["misc"]["snowflake"], bx + 0.86 * s, by + 0.12 * s, 0.42 * s, outline=0.08)
        if (p.get("skip") or 0) > 0:
            st.sticker(self.art["misc"]["zzz"], x0 + 0.88 * size, y0 + 0.08 * size, 0.5 * size, outline=0.08)

    def pawns(self, st, moods=None):
        current = self.view.get("current")
        order = sorted(self.view["players"], key=lambda p: (p["seat"] == current, p["seat"]))
        for p in order:
            self.pawn(st, p, current=p["seat"] == current, mood=(moods or {}).get(p["seat"]))

    # ---- the path preview (BoardView:showPath) -------------------------------------
    def path(self, st, path, character, color=None):
        C = st.C
        color = color or C["sun"]
        for tile in path[:-1]:
            x, y = self.pos[tile]
            st.circle(x, y, 0.32 * UNIT, color, stroke=(C["line"], 0.05 * UNIT))
        lx, ly = self.pos[path[-1]]
        st.circle(lx, ly, 1.5 * UNIT, color, alpha=0.3, stroke=(color, 0.09 * UNIT))
        if character:
            size = self.style["pawn"] * UNIT
            gx, gy = lx, ly - 0.2 * UNIT
            with st.layer(alpha=0.6, clip=(gx - size / 2, gy - size / 2, size, size)):
                st.sticker(self.art["mascotMoods"][character]["happy"], gx, gy, 0.9 * size, outline=0.05)

    def render(self, st, path=None, moods=None):
        self.paper(st)
        self.land(st)
        self.decor(st)
        self.links(st)
        self.tiles(st)
        self.pawns(st, moods)
        if path:
            self.path(st, path["path"], path.get("character"))


def name_tag(st, x, y, text, color):
    """BoardView:_ensureTag: a pill over the current pawn (anchor bottom-centre)."""
    C = st.C
    tw = st.text_size(text, "heavy", 15)
    w, h = tw + 20, 24
    st.rect(x - w / 2, y - h, w, h, C["panel"], corner=0.5, stroke=(color, 2))
    st.label(x - w / 2 + 10, y - h, tw, h, text, "heavy", 15, WHITE)


def path_tags(st, x, y, badges):
    """BoardView:showPath badges: a 260 x 26 row anchored at its bottom centre, badges
    (24 high, text 14) centred with a 4 px gap, bottoms aligned."""
    C = st.C
    widths = [badge_width(st, b["text"], 14) for b in badges]
    total = sum(widths) + 4 * (len(widths) - 1)
    bx = x - total / 2
    for b, w in zip(badges, widths):
        badge(st, bx, y - 24, b["text"], C.get(b["color"], b["color"]) if not b["color"].startswith("#") else b["color"],
              height=24, text_size=14)
        bx += w + 4
    return (x - 130, y - 26, 260, 26), total


def stage_art(data):
    """What Icons.stickerFor / Icons.make look in: card art, mascots, misc, IconData."""
    a = data["art"]
    return {"cards": a["cards"], "mascots": a["mascots"], "misc": a["misc"], "icons": a["icons"]}


def board_sheet(data, scene, out, width=1500):
    """The whole map, as a sheet."""
    bs = BoardScene(data, scene)
    pad = 40
    k = (width - 2 * pad) / bs.worldW
    H = int(bs.worldH * k + 2 * pad)
    st = Stage(width, H, ss=3, art=stage_art(data), theme=data["theme"])
    background(st)
    with st.at(pad, pad, k):
        bs.render(st)
    img = st.img.resize((width, H), resample=3)
    img.convert("RGB").save(out)
    print("wrote", out, img.size)


def main():
    data = json.load(open(sys.argv[1]))
    outdir = sys.argv[2]
    for i, sc in enumerate(data["scenes"]):
        slug = re.sub(r"[^a-z0-9]+", "-", sc["layout"]["name"].lower()).strip("-")
        board_sheet(data, sc, os.path.join(outdir, "%02d-board-%s.png" % (i + 2, slug)))


if __name__ == "__main__":
    main()
