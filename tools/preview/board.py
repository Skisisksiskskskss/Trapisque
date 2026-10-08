#!/usr/bin/env python3
"""Render mid-game previews of each Trapisque board (developer preview tool).

Mirrors the drawing in src/client/UI/Match/BoardView.lua: flat paper and wash, a
coastline of overlapping discs around the route, doodles placed by BoardLayout,
hex tiles with a wooden side, coin tokens, rimmed plaques and pawns.
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

THEME = {
    "water": {"paper": "#F2E2BD", "wash": "#93C6C4", "washA": 0.55, "ink": "#3C6E8F", "acc": "#E6D3A3", "acc2": "#C2513B"},
    "dungeon": {"paper": "#EBDDBE", "wash": "#A39B8E", "washA": 0.5, "ink": "#5A4A3A", "acc": "#A99E8A", "acc2": "#E0732C"},
    "swamp": {"paper": "#EEE4BC", "wash": "#9DB271", "washA": 0.55, "ink": "#4E6B34", "acc": "#93AA62", "acc2": "#9C4A2E"},
}
TILE_COLORS = {
    "normal": "#CB955C", "branch": "#B7A48A", "start": "#E4DCCB", "treasure": "#E9B53A",
    "shortcutGate": "#7E858D", "river": "#6FA8CF", "gate": "#79818A", "slime": "#7DB843",
}
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


def hexagon(cx, cy, r):
    return [(cx + r * math.cos(math.radians(60 * i + 30)), cy + r * math.sin(math.radians(60 * i + 30))) for i in range(6)]


class Scene:
    def __init__(self, data, scene, width=1500, pad=46):
        self.data = data
        self.icons = data["icons"]
        self.decor = data["decor"]
        self.L = scene["layout"]
        self.snap = scene["snapshot"]
        self.k = (width - 2 * pad) / self.L["w"]
        self.pad = pad
        self.W = width
        self.H = int(self.L["h"] * self.k + 2 * pad)
        self.ss = 3
        self.img = Image.new("RGBA", (self.W * self.ss, self.H * self.ss), hex_rgba("#2A1C13"))
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
            d.line([(0, y), (self.img.width, y)], fill=hex_rgba("#221710", 204), width=3 * self.ss)

    def paper(self):
        L, T = self.L, self.theme
        x0, y0 = self.X(L["x0"]), self.Y(L["y0"])
        x1, y1 = self.X(L["x0"] + L["w"]), self.Y(L["y0"] + L["h"])
        r = self.U(0.35)
        # hard drop shadow (Util.shadow), then the paper with its edge stroke
        off = self.px(8)
        self.patch(lambda dd: dd.rounded_rectangle([x0, y0 + off, x1, y1 + off], radius=r, fill=(0, 0, 0, 128)))
        self.framed((x0, y0, x1, y1), r, T["paper"], PAPER_EDGE, self.px(3))
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
                outline=hex_rgba(FRAME_INK, int(255 * (1 - t))), width=max(1, int(round(w)))))

    def land(self):
        T = self.theme
        coast = mix(T["ink"], T["wash"], 0.35)
        for color, r in ((coast, 1.29), (T["paper"], 1.22)):
            for t in self.L["tiles"]:
                cx, cy, rr = self.X(t["x"]), self.Y(t["y"]), self.U(r)
                self.d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=hex_rgba(color))

    def doodles(self):
        T = self.theme
        colors = {"ink": hex_rgba(mix(T["ink"], T["wash"], 0.22)), "bg": hex_rgba(self.sea), "acc": hex_rgba(T["acc"]),
                  "acc2": hex_rgba(T["acc2"]), "hi": hex_rgba(T["paper"])}
        for dd in self.L["decor"]:
            self.ops_at(self.decor[dd["kind"]], dd["x"], dd["y"], dd["size"], colors, rot=dd["rot"], flip=dd["flip"])
        c = self.L.get("compass")
        if c:
            cc = {"ink": hex_rgba(FRAME_INK), "bg": hex_rgba(self.sea), "acc": hex_rgba(FRAME_INK), "acc2": hex_rgba(INK_RED),
                  "hi": hex_rgba(self.sea)}
            self.ops_at(self.decor["compass_rose"], c["x"], c["y"], c["size"], cc)

    def title(self):
        # Widgets.ribbon: a paper cartouche with a double inked border
        t = self.L["title"]
        cx, cy, w, h = self.X(t["x"]), self.Y(t["y"]), self.U(t["w"]), self.U(t["h"])
        box = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
        self.framed(box, self.px(8), PARCH_MID, INK, self.px(2), stroke_alpha=int(255 * 0.9))
        i, wi = self.px(5), self.px(1)
        self.patch(lambda dd: dd.rounded_rectangle([box[0] + i - wi, box[1] + i - wi, box[2] - i + wi, box[3] - i + wi],
                                                   radius=self.px(5) + wi, outline=hex_rgba(INK, int(255 * 0.55)),
                                                   width=max(1, int(round(wi)))))
        size = min(h * 0.62, (h - self.px(8)) * 0.8)
        f = font("display", size)
        txt = self.L["name"]
        while self.d.textbbox((0, 0), txt, font=f)[2] > w - self.px(16) and size > 8:
            size -= 2
            f = font("display", size)
        bb = self.d.textbbox((0, 0), txt, font=f)
        self.d.text((cx - (bb[2] - bb[0]) / 2 - bb[0], cy - (bb[3] - bb[1]) / 2 - bb[1]), txt, font=f, fill=hex_rgba(INK))

    def links(self):
        for ln in self.L["links"]:
            mx, my = (ln["x1"] + ln["x2"]) / 2, (ln["y1"] + ln["y2"]) / 2
            ang = math.atan2(ln["y2"] - ln["y1"], ln["x2"] - ln["x1"])
            ux, uy = math.cos(ang), math.sin(ang)
            col = INK_RED if ln["shortcut"] else FRAME_INK
            half = 0.17 - 0.05
            a = (self.X(mx - ux * half), self.Y(my - uy * half))
            b = (self.X(mx + ux * half), self.Y(my + uy * half))
            th = self.U(0.1)
            self.d.line([a, b], fill=hex_rgba(col), width=int(th))
            for p in (a, b):
                self.d.ellipse([p[0] - th / 2, p[1] - th / 2, p[0] + th / 2, p[1] + th / 2], fill=hex_rgba(col))

    def tile_kind(self, t, natural):
        if t["kind"] != "normal":
            return t["kind"]
        if t["id"] in natural:
            return natural[t["id"]]
        if t.get("branch"):
            return "branch"
        return "normal"

    def belts(self):
        """BoardView:_setBelt: direction of the conveyor over each covered tile."""
        belt = {}
        for p in self.snap["placed"]:
            tiles = p.get("tiles")
            if p["item"] != "conveyor" or not tiles:
                continue
            for i, t in enumerate(tiles):
                a, b = (t, tiles[i + 1]) if i + 1 < len(tiles) else (tiles[i - 1] if i > 0 else t, t)
                ta, tb = self.L["tiles"][a - 1], self.L["tiles"][b - 1]
                ang = math.degrees(math.atan2(tb["y"] - ta["y"], tb["x"] - ta["x"]))
                belt[t] = ang + (180 if p.get("dir") == "back" else 0)
        return belt

    def tiles(self, cover):
        natural = {n["tile"]: n["kind"] for n in self.snap["natural"]}
        belt = self.belts()
        for t in self.L["tiles"]:
            x, y = t["x"], t["y"]
            kind = self.tile_kind(t, natural)
            top = TILE_COLORS.get(kind, TILE_COLORS["normal"])
            if kind == "normal" and t.get("branch"):
                top = TILE_COLORS["branch"]
            if t["id"] in belt:
                top = mix(top, CAT["neutral"], 0.3)
            self.d.polygon([(self.X(px), self.Y(py)) for px, py in hexagon(x, y + 0.16, 0.86)], fill=hex_rgba(shade(top, -0.38)))
            self.d.polygon([(self.X(px), self.Y(py)) for px, py in hexagon(x, y, 0.86)], fill=hex_rgba(top))
            icon, icol, size = None, None, 0.85
            if kind == "start":
                icon, icol = "flag", INK_RED
            elif kind == "treasure":
                icon, icol, size = "x_mark", INK_RED, 1.05
            elif kind == "shortcutGate":
                icon, icol = "gate_trap", "#3A3F45"
            elif kind in NATURAL_ICON:
                icon, icol = NATURAL_ICON[kind], "#FFFFFF"
            n = cover.get(t["id"], 0)
            if icon and n == 0:
                colors = {"ink": hex_rgba(icol), "bg": hex_rgba(top), "acc": hex_rgba(icol), "acc2": hex_rgba(icol), "hi": hex_rgba(top)}
                self.ops_at(self.icons[icon], x, y - 0.02, size, colors)
            if t["id"] in belt:
                self.ops_at(BELT_CHEVRON, x, y + 0.52, 0.4, {"ink": hex_rgba(CAT["neutral"])}, rot=belt[t["id"]])
            elif not icon and n < 3:
                f = font("chunky", self.U(0.3))
                s = str(t["id"])
                bb = self.d.textbbox((0, 0), s, font=f)
                self.patch(lambda dd, s=s, f=f, bb=bb: dd.text(
                    (self.X(x) - (bb[2] - bb[0]) / 2 - bb[0], self.Y(y + 0.55) - (bb[3] - bb[1]) / 2 - bb[1]), s, font=f,
                    fill=hex_rgba("#8A5A2E", int(255 * 0.7))))

    def medallion(self, icon, cx, cy, d, color):
        """Icons.medallion: disc of diameter d (world units), brass rim outside, white glyph."""
        rr = d / 2 * 1.16
        self.d.ellipse([self.X(cx - rr), self.Y(cy - rr), self.X(cx + rr), self.Y(cy + rr)], fill=hex_rgba(BRASS))
        r = d / 2
        self.d.ellipse([self.X(cx - r), self.Y(cy - r), self.X(cx + r), self.Y(cy + r)], fill=hex_rgba(color))
        colors = {"ink": hex_rgba("#FFFFFF"), "bg": hex_rgba(color), "acc": hex_rgba(BRASS_LIGHT), "acc2": hex_rgba(BRASS_LIGHT), "hi": hex_rgba(color)}
        self.ops_at(self.icons[icon], cx, cy, d * 0.64, colors)

    def tokens(self, cover):
        for tk in self.snap["tokens"]:
            t = self.L["tiles"][tk["tile"] - 1]
            s = 0.8  # holder size
            hx, hy = t["x"], t["y"] - 0.14
            # coin edge below, then the medallion
            er = s * 0.905 / 2
            ex, ey = hx, hy + (0.54 - 0.5) * s
            self.d.ellipse([self.X(ex - er), self.Y(ey - er), self.X(ex + er), self.Y(ey + er)], fill=hex_rgba(BRASS_DARK))
            self.medallion(TOKEN_ICON[tk["kind"]], hx, hy + (0.47 - 0.5) * s, 0.78 * s, CAT[tk["kind"]])

    def placed(self):
        for p in self.snap["placed"]:
            t = self.L["tiles"][p["tile"] - 1]
            s = 0.6
            cx, cy = t["x"], t["y"] - 0.14
            rim_px = self.px(3)
            rad = self.U(0.18 * s)
            x0, y0, x1, y1 = self.X(cx - s / 2), self.Y(cy - s / 2), self.X(cx + s / 2), self.Y(cy + s / 2)
            off = self.U(0.14 * s)
            self.framed((x0, y0 + off, x1, y1 + off), rad, WOOD_DEEP, WOOD_DEEP, rim_px)
            owner = p.get("owner") or 0
            rim = SEAT[(owner - 1) % 6] if owner > 0 else CAT["neutral" if p["item"] in NEUTRAL_ITEMS else "trap"]
            self.framed((x0, y0, x1, y1), rad, WOOD, rim, rim_px)
            burn = shade(WOOD, -0.62)
            colors = {"ink": hex_rgba(burn), "bg": hex_rgba(WOOD), "acc": hex_rgba(burn), "acc2": hex_rgba(burn), "hi": hex_rgba(WOOD)}
            self.ops_at(self.icons[p["item"]], cx, cy, s * 0.8, colors)

    def teleport_rings(self):
        # open ring behind each teleporter plaque (it spins in game)
        for p in self.snap["placed"]:
            if p["item"] != "teleporter":
                continue
            t = self.L["tiles"][p["tile"] - 1]
            cx, cy = t["x"], t["y"] - 0.14
            r = 0.6 * 1.6 / 2
            th = self.U(0.6 * 0.1)
            box = [self.X(cx - r), self.Y(cy - r), self.X(cx + r), self.Y(cy + r)]
            self.d.arc(box, start=-60, end=200, fill=hex_rgba(CAT["neutral"]), width=int(th))

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
                at = layout["at"][i]
                out.append((p, tile, at, layout["scale"]))
        return groups, out

    def pawns(self, placed_pawns):
        skins = self.data["skins"]
        order = sorted(placed_pawns, key=lambda e: (e[0]["seat"] == self.snap["current"], e[0]["seat"]))
        for p, tile, at, scale in order:
            t = self.L["tiles"][tile - 1]
            cx, cy = t["x"] + at[0], t["y"] + at[1]
            size = 0.86 * scale
            seat = SEAT[(p["seat"] - 1) % 6]
            if p["seat"] == self.snap["current"]:
                # TurnRing: 1.3 x the pawn, brass stroke outside it
                rr = size * 1.3 / 2
                w = self.px(3)
                self.d.ellipse([self.X(cx - rr) - w, self.Y(cy - rr) - w, self.X(cx + rr) + w, self.Y(cy + rr) + w],
                               outline=hex_rgba(BRASS_LIGHT), width=int(round(w)))
            skin = skins[(p["seat"] - 1) % len(skins)]
            item = {"look": self.data["looks"][skin]}
            side = int(round(self.U(size)))
            pawn = Image.new("RGBA", (side * 2, side * 2), (0, 0, 0, 0))
            draw_pawn(pawn, side / 2, side / 2, side, item, {"patterns": self.data["patterns"]}, seat=seat)
            self.img.alpha_composite(pawn, (int(self.X(cx) - side), int(self.Y(cy) - side)))

    def render(self, out):
        groups, placed_pawns = self.resting()
        cover = {tile: len(ps) for tile, ps in groups.items()}
        self.table()
        self.paper()
        self.land()
        self.doodles()
        self.title()
        self.links()
        self.tiles(cover)
        self.tokens(cover)
        self.teleport_rings()
        self.placed()
        self.pawns(placed_pawns)
        final = self.img.resize((self.W, self.H), Image.LANCZOS)
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
