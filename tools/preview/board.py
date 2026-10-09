#!/usr/bin/env python3
"""Render mid-game previews of each Trapisque board (developer preview tool).

Mirrors the drawing in src/client/UI/Match/BoardView.lua: flat paper and wash, a
coastline of overlapping discs around the route, doodles placed by BoardLayout, hex
tiles with a dark rim and a wooden side, tiles reskinned by whatever is on them (the
skin ops are recorded from the game's own TileSkins code), round card plaques, bold
token inlays and big pawns showing each player's avatar (bots show their character).
UIStrokes are drawn outside their frame, as Roblox does.

Usage: python3 tools/preview/board.py board.json outdir
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from render import Layer, Canvas, draw_ops, hex_rgba, font  # noqa: E402
from cosmetics import draw_pawn  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

UNIT = 46  # world pixels per hex unit in the game (BoardView U)

THEME = {  # BoardView THEMES: the maps at night
    "water": {"paper": "#29251F", "wash": "#163A44", "washA": 0.88, "land": "#3B352B", "ink": "#8DB6B1", "acc": "#2F4C4C", "acc2": "#C2513B"},
    "dungeon": {"paper": "#28251F", "wash": "#3A3630", "washA": 0.85, "land": "#48423A", "ink": "#B4A993", "acc": "#57514A", "acc2": "#E0732C"},
    "swamp": {"paper": "#26251D", "wash": "#2C3F25", "washA": 0.88, "land": "#3B392B", "ink": "#A7BC85", "acc": "#465C33", "acc2": "#9C4A2E"},
}
TILE_COLORS = {"normal": "#E9BE84", "branch": "#CDBB9C", "start": "#F4EFE3", "treasure": "#F7C948", "shortcutGate": "#8F969E"}
RIM = "#4A2C14"
TILE_R = 0.88  # BoardLayout.Style.tileScale
TILE_DEPTH = 0.16
PAWN = 1.3
CHAR = {"mage": "#5876D6", "trapper": "#A86B39", "fire_starter": "#E2622B", "naturalist": "#4E9A47", "warper": "#8B57CC", "overseer": "#CDA42A"}
NATURAL_ICON = {"river": "river_trap", "gate": "lock", "slime": "slime_trap"}
TOKEN_ICON = {"trap": "token_trap", "assist": "token_assist", "neutral": "token_neutral", "potion": "token_potion"}
SEAT = ["#E35D5D", "#4E8FDB", "#5DB866", "#EDBB36", "#A56CDB", "#F0883A"]
CAT = {"trap": "#C2513B", "assist": "#5E9A3C", "neutral": "#7A61A8", "potion": "#D98C1F"}
NEUTRAL_ITEMS = {"teleporter", "spore_warper", "conveyor", "shifting_sands"}
BELT_CHEVRON = [{"__args": ["chevron", 0.3, 0.5, 0.6, 0.2], "dir": 90}, {"__args": ["chevron", 0.66, 0.5, 0.6, 0.2], "dir": 90}]
FRAME_INK = "#6B4A2E"
PAPER_EDGE = "#6B4423"
INK = "#4A3020"
INK_RED = "#B5372B"
WOOD = "#B57D46"
WOOD_DEEP = "#5C3818"
BRASS = "#E3B04B"
BRASS_DARK = "#9E7425"
BRASS_LIGHT = "#FFE39A"
PARCH_MID = "#E8D2A2"


def rgb(h):
    return hex_rgba(h)[:3]


def to_hex(c):
    return "#%02X%02X%02X" % tuple(int(round(v)) for v in c[:3])


def mix(a, b, t):
    """Util.mix: a lerped towards b by t."""
    ca, cb = rgb(a), rgb(b)
    return to_hex(tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3)))


def shade(h, amt):
    return mix(h, "#FFFFFF", amt) if amt >= 0 else mix(h, "#000000", -amt)


def hexagon(cx, cy, r, flat=False):
    """Pointy-top hexagon of circumradius r (flat-topped on rotated boards)."""
    base = 0 if flat else 30
    return [(cx + r * math.cos(math.radians(60 * i + base)), cy + r * math.sin(math.radians(60 * i + base))) for i in range(6)]


class Scene:
    def __init__(self, data, scene, width=1500, pad=46):
        self.data = data
        self.icons = data["icons"]
        self.decor = data["decor"]
        self.L = scene["layout"]
        self.snap = scene["snapshot"]
        self.skins = scene.get("skins") or {}
        self.k = (width - 2 * pad) / self.L["w"]
        self.pad = pad
        self.W = width
        self.H = int(self.L["h"] * self.k + 2 * pad)
        self.ss = 3
        self.img = Image.new("RGBA", (self.W * self.ss, self.H * self.ss), hex_rgba("#1A130E"))
        self.theme = THEME[self.L["theme"]]
        T = self.theme
        self.sea = mix(T["paper"], T["wash"], T["washA"])  # wash over paper

    # coordinates: world units -> supersampled pixels
    def X(self, x):
        return (self.pad + (x - self.L["x0"]) * self.k) * self.ss

    def Y(self, y):
        return (self.pad + (y - self.L["y0"]) * self.k) * self.ss

    def U(self, u):
        return u * self.k * self.ss

    def px(self, p):
        """Game pixels (U = 46) -> supersampled pixels."""
        return p / UNIT * self.k * self.ss

    @property
    def d(self):
        return ImageDraw.Draw(self.img)

    def patch(self, draw_fn, alpha_fill=True):
        """Draw translucent shapes on a blank layer, then composite."""
        lay = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        draw_fn(ImageDraw.Draw(lay))
        self.img = Image.alpha_composite(self.img, lay)

    def framed(self, box, radius, fill, stroke=None, stroke_px=0.0, stroke_alpha=255):
        """Rounded frame with a UIStroke outside its bounds (sizes in supersampled px)."""
        x0, y0, x1, y1 = box
        if stroke and stroke_px > 0:
            w = stroke_px
            if stroke_alpha >= 255:
                self.d.rounded_rectangle([x0 - w, y0 - w, x1 + w, y1 + w], radius=radius + w, fill=hex_rgba(stroke))
            else:
                self.patch(lambda dd: dd.rounded_rectangle([x0 - w, y0 - w, x1 + w, y1 + w], radius=radius + w,
                                                           outline=hex_rgba(stroke, stroke_alpha), width=max(1, int(round(w)))))
        if fill:
            self.d.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=hex_rgba(fill))

    def ops_at(self, ops, cx, cy, size, colors, rot=0, flip=False):
        """Draw icon ops in a square of `size` world units centred at (cx, cy)."""
        side = size * self.k
        box = int(side * 1.6) + 4
        layer = Layer(box, box, ss=self.ss)
        cv = Canvas(layer, (box - side) / 2, (box - side) / 2, side, colors)
        draw_ops(cv, [{"__args": ["group"], "ops": ops, "rot": rot, "fx": flip}])
        tile = layer.img
        x = int(self.X(cx) - tile.width / 2)
        y = int(self.Y(cy) - tile.height / 2)
        self.img.alpha_composite(tile, (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))

    # ------------------------------------------------------------------ layers
    def table(self):
        d = self.d
        step = self.img.height / 14
        for i in range(15):
            y = i * step
            d.line([(0, y), (self.img.width, y)], fill=hex_rgba("#120D0A", 204), width=3 * self.ss)

    def paper(self):
        L, T = self.L, self.theme
        x0, y0 = self.X(L["x0"]), self.Y(L["y0"])
        x1, y1 = self.X(L["x0"] + L["w"]), self.Y(L["y0"] + L["h"])
        r = self.U(0.35)
        # hard drop shadow (Util.shadow), then the paper with its edge stroke
        off = self.px(8)
        self.patch(lambda dd: dd.rounded_rectangle([x0, y0 + off, x1, y1 + off], radius=r, fill=(0, 0, 0, 128)))
        self.framed((x0, y0, x1, y1), r, T["paper"], BRASS_DARK, self.px(3))
        # sea / stone / swamp wash
        i = self.U(0.55)
        self.d.rounded_rectangle([x0 + i, y0 + i, x1 - i, y1 - i], radius=self.U(0.3), fill=hex_rgba(self.sea))
        # double neatline frame
        for n, (inset, th, t) in enumerate([(0.3, 3, 0.25), (0.45, 1.5, 0.45)], start=1):
            o = self.U(inset)
            w = self.px(th)
            rad = self.U(0.25 - n * 0.03)
            self.patch(lambda dd, o=o, w=w, rad=rad, t=t: dd.rounded_rectangle(
                [x0 + o - w, y0 + o - w, x1 - o + w, y1 - o + w], radius=rad + w,
                outline=hex_rgba(T["ink"], int(255 * (1 - t - 0.3))), width=max(1, int(round(w)))))

    def land(self):
        T = self.theme
        coast = mix(T["ink"], T["wash"], 0.25)
        for color, r in ((coast, 1.29), (T["land"], 1.22)):
            for t in self.L["tiles"]:
                cx, cy, rr = self.X(t["x"]), self.Y(t["y"]), self.U(r)
                self.d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=hex_rgba(color))

    def doodles(self):
        T = self.theme
        colors = {"ink": hex_rgba(mix(T["ink"], T["wash"], 0.22)), "bg": hex_rgba(self.sea), "acc": hex_rgba(T["acc"]),
                  "acc2": hex_rgba(T["acc2"]), "hi": hex_rgba(T["land"])}
        for dd in self.L["decor"]:
            self.ops_at(self.decor[dd["kind"]], dd["x"], dd["y"], dd["size"], colors, rot=dd["rot"], flip=dd["flip"])
        c = self.L.get("compass")
        if c:
            cc = {"ink": hex_rgba(T["ink"]), "bg": hex_rgba(self.sea), "acc": hex_rgba(T["ink"]), "acc2": hex_rgba(INK_RED),
                  "hi": hex_rgba(self.sea)}
            self.ops_at(self.decor["compass_rose"], c["x"], c["y"], c["size"], cc)

    def title(self):
        # Widgets.ribbon: a dark plaque with a double brass border and gold lettering
        t = self.L["title"]
        cx, cy, w, h = self.X(t["x"]), self.Y(t["y"]), self.U(t["w"]), self.U(t["h"])
        box = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
        self.framed(box, self.px(8), "#1C1612", BRASS_DARK, self.px(2), stroke_alpha=int(255 * 0.95))
        i, wi = self.px(5), self.px(1)
        self.patch(lambda dd: dd.rounded_rectangle([box[0] + i - wi, box[1] + i - wi, box[2] - i + wi, box[3] - i + wi],
                                                   radius=self.px(5) + wi, outline=hex_rgba(BRASS, int(255 * 0.45)),
                                                   width=max(1, int(round(wi)))))
        size = min(h * 0.62, (h - self.px(8)) * 0.8)
        f = font("display", size)
        txt = self.L["name"]
        while self.d.textbbox((0, 0), txt, font=f)[2] > w - self.px(16) and size > 8:
            size -= 2
            f = font("display", size)
        bb = self.d.textbbox((0, 0), txt, font=f)
        self.d.text((cx - (bb[2] - bb[0]) / 2 - bb[0], cy - (bb[3] - bb[1]) / 2 - bb[1]), txt, font=f, fill=hex_rgba(BRASS_LIGHT))

    def links(self):
        """Dashes between neighbouring tiles (0.32 x 0.12 units, red for shortcuts)."""
        for ln in self.L["links"]:
            mx, my = (ln["x1"] + ln["x2"]) / 2, (ln["y1"] + ln["y2"]) / 2
            ang = math.atan2(ln["y2"] - ln["y1"], ln["x2"] - ln["x1"])
            ux, uy = math.cos(ang), math.sin(ang)
            col = INK_RED if ln["shortcut"] else mix(self.theme["ink"], self.theme["land"], 0.25)
            half = (0.32 - 0.12) / 2
            a = (self.X(mx - ux * half), self.Y(my - uy * half))
            b = (self.X(mx + ux * half), self.Y(my + uy * half))
            th = self.U(0.12)
            self.d.line([a, b], fill=hex_rgba(col), width=int(th))
            for p in (a, b):
                self.d.ellipse([p[0] - th / 2, p[1] - th / 2, p[0] + th / 2, p[1] + th / 2], fill=hex_rgba(col))

    def poly(self, pts, color):
        self.d.polygon([(self.X(px), self.Y(py)) for px, py in pts], fill=hex_rgba(color))

    def disc(self, cx, cy, d, color, stroke=None, stroke_w=0.0):
        """A circle of diameter d (units) with a UIStroke of stroke_w units outside it."""
        if stroke and stroke_w > 0:
            r = d / 2 + stroke_w
            self.d.ellipse([self.X(cx - r), self.Y(cy - r), self.X(cx + r), self.Y(cy + r)], fill=hex_rgba(stroke))
        r = d / 2
        self.d.ellipse([self.X(cx - r), self.Y(cy - r), self.X(cx + r), self.Y(cy + r)], fill=hex_rgba(color))

    def icon(self, name, cx, cy, size, ink, bg, acc=None):
        a = acc or ink
        colors = {"ink": hex_rgba(ink), "bg": hex_rgba(bg), "acc": hex_rgba(a), "acc2": hex_rgba(a), "hi": hex_rgba(bg)}
        self.ops_at(self.icons[name], cx, cy, size, colors)

    def medallion(self, icon, cx, cy, d, color):
        """Icons.medallion: disc of diameter d (units), brass rim outside, white glyph."""
        self.disc(cx, cy, d, color, BRASS, d * 0.08)
        self.icon(icon, cx, cy, d * 0.64, "#FFFFFF", color, BRASS_LIGHT)

    def tiles(self, cover):
        """BoardView:_buildTiles + _paintTile: side, rim and top hexes, then whatever the
        tile shows (skin, card plaque, natural icon, token inlay or start/treasure mark)."""
        flat = bool(self.L.get("rotated"))
        placed = {p["tile"]: p for p in self.snap["placed"]}
        natural = {n["tile"]: n["kind"] for n in self.snap["natural"]}
        tokens = {t["tile"]: t["kind"] for t in self.snap["tokens"]}
        for t in sorted(self.L["tiles"], key=lambda q: q["y"]):
            tid, x, y, kind = t["id"], t["x"], t["y"], t["kind"]
            top = TILE_COLORS.get(kind) or (TILE_COLORS["branch"] if t.get("branch") else TILE_COLORS["normal"])
            skin = self.skins.get(str(tid))
            if skin and skin.get("top"):
                top = skin["top"]
            self.poly(hexagon(x, y + TILE_DEPTH, TILE_R + 0.05, flat), shade(top, -0.5))
            self.poly(hexagon(x, y, TILE_R + 0.05, flat), RIM)
            self.poly(hexagon(x, y, TILE_R, flat), top)
            busy = False
            if skin:
                self.ops_at(skin["ops"], x, y, 2.0, {"ink": hex_rgba(INK)})
                busy = True
            entry = placed.get(tid)
            if entry:
                # a little card rimmed in its owner's colour
                owner = entry.get("owner") or 0
                rim = SEAT[(owner - 1) % 6] if owner > 0 else "#7B5B3E"
                w, h, sw = 0.6, 0.8, 0.07
                self.d.rounded_rectangle([self.X(x - w / 2 - sw), self.Y(y - h / 2 - sw), self.X(x + w / 2 + sw), self.Y(y + h / 2 + sw)],
                                         radius=self.U(0.12 + sw), fill=hex_rgba(rim))
                self.d.rounded_rectangle([self.X(x - w / 2), self.Y(y - h / 2), self.X(x + w / 2), self.Y(y + h / 2)],
                                         radius=self.U(0.12), fill=hex_rgba("#2A1C13"))
                self.icon(entry["item"], x, y, 0.48, "#FFFFFF", "#2A1C13")
                busy = True
            elif tid in natural and natural[tid] in NATURAL_ICON:
                self.icon(NATURAL_ICON[natural[tid]], x, y, 0.72, "#FFFFFF", top)
                busy = True
            elif tid in tokens:
                # a coloured hexagon set into the tile
                col = CAT.get(tokens[tid], "#7B5B3E")
                self.poly(hexagon(x, y, 0.66, flat), "#FFFFFF")
                self.poly(hexagon(x, y, 0.58, flat), col)
                self.icon(TOKEN_ICON.get(tokens[tid], "info"), x, y, 0.66, "#FFFFFF", col)
                busy = True
            elif kind in ("start", "treasure", "shortcutGate"):
                icon, col, size = "flag", INK_RED, 0.86
                if kind == "treasure":
                    icon, size = "x_mark", 1.05
                elif kind == "shortcutGate":
                    icon, col = "gate_trap", "#3A3F45"
                self.icon(icon, x, y, size, col, top)
                busy = True
            if not busy and cover.get(tid, 0) == 0:
                f = font("chunky", self.U(0.3))
                txt = str(tid)
                bb = self.d.textbbox((0, 0), txt, font=f)
                self.d.text((self.X(x) - (bb[2] - bb[0]) / 2 - bb[0], self.Y(y + 0.5) - (bb[3] - bb[1]) / 2 - bb[1]), txt,
                            font=f, fill=hex_rgba("#9A6A3C"))

    def resting(self):
        """Pawns per tile and their slot (BoardLayout.PawnSlots)."""
        groups = {}
        for p in self.snap["players"]:
            groups.setdefault(p["tile"], []).append(p)
        out = []
        for tile, ps in groups.items():
            ps.sort(key=lambda q: q["seat"])
            layout = self.data["slots"][min(len(ps), len(self.data["slots"])) - 1]
            for i, p in enumerate(ps):
                out.append((p, tile, layout["at"][i], layout["scale"]))
        return groups, out

    def avatar(self, p, cx, cy, d, seat_col):
        """Avatars.portrait: a headshot on a soft backing (here a stand-in face, since the
        real ones come from Roblox), or the character's medallion for bots."""
        if p.get("isBot"):
            self.medallion(p.get("character") or "info", cx, cy, d, CHAR.get(p.get("character"), "#7B5B3E"))
        else:
            self.disc(cx, cy, d, shade(seat_col, 0.45))
            # stand-in headshot: a plain round head with two eyes and a smile
            self.disc(cx, cy + d * 0.08, d * 0.62, "#F5CD30")
            for ex in (-0.11, 0.11):
                self.disc(cx + ex * d, cy + d * 0.02, d * 0.07, "#2B2B2B")
            r = d * 0.16
            box = [self.X(cx - r), self.Y(cy + d * 0.1 - r * 0.6), self.X(cx + r), self.Y(cy + d * 0.1 + r * 1.0)]
            self.d.arc(box, start=20, end=160, fill=hex_rgba("#2B2B2B"), width=max(1, int(self.U(d * 0.035))))
        r = d / 2
        w = max(1, int(round(self.px(2))))
        self.d.ellipse([self.X(cx - r) - w, self.Y(cy - r) - w, self.X(cx + r) + w, self.Y(cy + r) + w],
                       outline=hex_rgba("#FFFFFF"), width=w)

    def pawns(self, placed_pawns):
        """BoardView:addPawn: shadow, the pawn chip, the player's face in the middle, and
        a brass ring around whoever's turn it is."""
        skins = self.data["skins"]
        current = self.snap.get("current")
        order = sorted(placed_pawns, key=lambda e: (e[0]["seat"] == current, e[0]["seat"]))
        for p, tile, at, scale in order:
            t = self.L["tiles"][tile - 1]
            size = PAWN * scale
            cx, cy = t["x"] + at[0], t["y"] + at[1]
            seat = SEAT[(p["seat"] - 1) % 6]
            sr = size * 0.94 / 2
            sx, sy = cx + size * 0.04, cy + size * 0.1
            self.patch(lambda dd, sx=sx, sy=sy, sr=sr: dd.ellipse([self.X(sx - sr), self.Y(sy - sr), self.X(sx + sr), self.Y(sy + sr)],
                                                              fill=(26, 18, 12, 115)))
            if p["seat"] == current:
                rr = size * 1.2 / 2
                w = self.px(4)
                ry = cy - size * 0.03
                self.d.ellipse([self.X(cx - rr) - w, self.Y(ry - rr) - w, self.X(cx + rr) + w, self.Y(ry + rr) + w],
                               outline=hex_rgba(BRASS_LIGHT), width=int(round(w)))
            skin = skins[(p["seat"] - 1) % len(skins)]
            item = {"look": self.data["looks"][skin]}
            side = int(round(self.U(size)))
            pawn = Image.new("RGBA", (side * 2, side * 2), (0, 0, 0, 0))
            draw_pawn(pawn, side / 2, side / 2, side, item, {"patterns": self.data["patterns"]}, seat=seat)
            self.img.alpha_composite(pawn, (int(self.X(cx) - side), int(self.Y(cy) - side)))
            self.avatar(p, cx, cy - size * 0.03, size * 0.5, seat)
            if p.get("burning"):
                self.icon("fire", cx, cy - size * 0.52, size * 0.5, "#FF7B2E", "#FFD166", "#FFD166")
            if p.get("frozen"):
                self.medallion("ice", cx + size * 0.36, cy - size * 0.34, size * 0.34, "#5DADE2")

    def render(self, out=None):
        groups, placed_pawns = self.resting()
        cover = {tile: len(ps) for tile, ps in groups.items()}
        self.table()
        self.paper()
        self.land()
        self.doodles()
        self.title()
        self.links()
        self.tiles(cover)
        self.pawns(placed_pawns)
        final = self.img.resize((self.W, self.H), Image.LANCZOS)
        if out:
            final.convert("RGB").save(out)
        return final


def main():
    data = json.load(open(sys.argv[1]))
    outdir = sys.argv[2]
    for sc in data["scenes"]:
        name = sc["layout"]["map"]
        img = Scene(data, sc).render(os.path.join(outdir, "board_%s.png" % name))
        print("wrote", name, img.size)


if __name__ == "__main__":
    main()
