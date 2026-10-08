#!/usr/bin/env python3
"""Render mid-game previews of each Trapisque board (developer preview tool).

Mirrors the drawing in src/client/UI/Match/BoardView.lua.
Usage: python3 tools/preview/board.py board.json outdir
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from render import Layer, Canvas, draw_ops, hex_rgba, font  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

THEME = {
    "water": {"paper": "#F2E2BD", "wash": "#93C6C4", "washA": 0.55, "ink": "#3C6E8F", "acc": "#E6D3A3", "acc2": "#C2513B", "rock": "#8FA7A8"},
    "dungeon": {"paper": "#EBDDBE", "wash": "#A39B8E", "washA": 0.5, "ink": "#5A4A3A", "acc": "#CDBFA6", "acc2": "#E0732C"},
    "swamp": {"paper": "#EEE4BC", "wash": "#9DB271", "washA": 0.55, "ink": "#4E6B34", "acc": "#B9C98B", "acc2": "#9C4A2E"},
}
INK = "#6B4A2E"
WOOD_SIDE = "#7A4D27"
WOOD_TOP = "#CB955C"
WOOD_IN = "#DBAA72"
SEAT = ["#E35D5D", "#4E8FDB", "#5DB866", "#EDBB36", "#A56CDB", "#F0883A"]
CAT = {"trap": "#C2513B", "assist": "#5E9A3C", "neutral": "#7A61A8", "potion": "#D98C1F"}
TOKEN_ICON = {"trap": "token_trap", "assist": "token_assist", "neutral": "token_neutral", "potion": "token_potion"}
NATURAL = {
    "river": ("#6FA8CF", "#8DBFE0", "river_trap"),
    "gate": ("#79818A", "#959DA6", "lock"),
    "slime": ("#7DB843", "#97CE57", "slime_trap"),
}
ITEM_CAT = {
    "spike": "trap", "fire": "trap", "ice": "trap", "mudslide": "trap", "mud": "trap", "wall": "trap", "snare": "trap", "grog": "trap",
    "teleporter": "neutral", "spore_warper": "neutral", "conveyor": "neutral", "shifting_sands": "neutral",
}
CHAR_COLOR = {"mage": "#5876D6", "trapper": "#A86B39", "fire_starter": "#E2622B", "naturalist": "#4E9A47", "warper": "#8B57CC", "overseer": "#CDA42A"}


def hexagon(cx, cy, r):
    return [(cx + r * math.cos(math.radians(60 * i + 30)), cy + r * math.sin(math.radians(60 * i + 30))) for i in range(6)]


def lighten(h, amt):
    r, g, b, a = hex_rgba(h)
    return "#%02X%02X%02X" % (int(r + (255 - r) * amt), int(g + (255 - g) * amt), int(b + (255 - b) * amt))


def darken(h, amt):
    r, g, b, a = hex_rgba(h)
    return "#%02X%02X%02X" % (int(r * (1 - amt)), int(g * (1 - amt)), int(b * (1 - amt)))


class Scene:
    def __init__(self, data, scene, width=1500, pad=46):
        self.icons = data["icons"]
        self.decor = data["decor"]
        self.L = scene["layout"]
        self.snap = scene["snapshot"]
        self.k = (width - 2 * pad) / self.L["w"]
        self.pad = pad
        self.W = width
        self.H = int(self.L["h"] * self.k + 2 * pad)
        self.ss = 3
        self.img = Image.new("RGBA", (self.W * self.ss, self.H * self.ss), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.theme = THEME[self.L["theme"]]

    def X(self, x):
        return (self.pad + (x - self.L["x0"]) * self.k) * self.ss

    def Y(self, y):
        return (self.pad + (y - self.L["y0"]) * self.k) * self.ss

    def U(self, u):
        return u * self.k * self.ss

    def poly(self, pts, fill, alpha=1.0):
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon(pts, fill=hex_rgba(fill, int(255 * alpha)))
        self.img = Image.alpha_composite(self.img, layer)
        self.d = ImageDraw.Draw(self.img)

    def draw_ops_at(self, ops, cx, cy, size, colors, rot=0, flip=False):
        # small private layer, pasted at the right spot
        px = size * self.k
        box = int(px * 1.6) + 4
        layer = Layer(box, box, ss=self.ss)
        cv = Canvas(layer, (box - px) / 2, (box - px) / 2, px, colors)
        wrapped = [{"__args": ["group"], "ops": ops, "rot": rot, "fx": flip}]
        draw_ops(cv, wrapped)
        tile = layer.img
        x = int(self.X(cx) - tile.width / 2)
        y = int(self.Y(cy) - tile.height / 2)
        self.img.alpha_composite(tile, (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))
        self.d = ImageDraw.Draw(self.img)

    # ------------------------------------------------------------------ layers
    def table(self):
        bg = Image.new("RGBA", self.img.size, hex_rgba("#2A1C13"))
        d = ImageDraw.Draw(bg)
        for i in range(0, bg.height, int(90 * self.ss)):
            d.line([(0, i), (bg.width, i)], fill=hex_rgba("#221710"), width=3 * self.ss)
        self.img = Image.alpha_composite(bg, self.img)
        self.d = ImageDraw.Draw(self.img)

    def parchment(self):
        L, T = self.L, self.theme
        x0, y0 = self.X(L["x0"]), self.Y(L["y0"])
        x1, y1 = self.X(L["x0"] + L["w"]), self.Y(L["y0"] + L["h"])
        # shadow
        sh = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([x0, y0 + 10 * self.ss, x1, y1 + 10 * self.ss], radius=self.U(0.35), fill=(0, 0, 0, 120))
        sh = sh.filter(ImageFilter.GaussianBlur(12 * self.ss))
        self.img = Image.alpha_composite(self.img, sh)
        paper = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        pd = ImageDraw.Draw(paper)
        pd.rounded_rectangle([x0, y0, x1, y1], radius=self.U(0.35), fill=hex_rgba(T["paper"]))
        # wash (sea / stone / swamp) inside the frame
        inset = self.U(0.55)
        wash = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        ImageDraw.Draw(wash).rounded_rectangle([x0 + inset, y0 + inset, x1 - inset, y1 - inset], radius=self.U(0.3),
                                               fill=hex_rgba(T["wash"], int(255 * T["washA"])))
        # path halos: the route sits on pale "land"
        halo = Image.new("L", self.img.size, 0)
        hd = ImageDraw.Draw(halo)
        for t in L["tiles"]:
            r = self.U(1.22)
            hd.ellipse([self.X(t["x"]) - r, self.Y(t["y"]) - r, self.X(t["x"]) + r, self.Y(t["y"]) + r], fill=255)
        halo = halo.filter(ImageFilter.GaussianBlur(self.U(0.18)))
        wash_a = wash.getchannel("A")
        wash.putalpha(Image.composite(Image.new("L", wash.size, 0), wash_a, halo.point(lambda v: 255 if v > 128 else 0)))
        paper = Image.alpha_composite(paper, wash)
        # coast line around the halos
        edge = halo.point(lambda v: 255 if 110 < v < 150 else 0).filter(ImageFilter.MaxFilter(3))
        coast = Image.new("RGBA", self.img.size, hex_rgba(T["ink"], 0))
        coast.putalpha(edge.point(lambda v: int(v * 0.45)))
        paper = Image.alpha_composite(paper, coast)
        # vignette (burnt edges)
        vig = Image.new("L", self.img.size, 0)
        vd = ImageDraw.Draw(vig)
        vd.rounded_rectangle([x0 + self.U(0.9), y0 + self.U(0.9), x1 - self.U(0.9), y1 - self.U(0.9)], radius=self.U(1), fill=255)
        vig = vig.filter(ImageFilter.GaussianBlur(self.U(0.9)))
        burn = Image.new("RGBA", self.img.size, hex_rgba("#A97C45", 0))
        burn.putalpha(vig.point(lambda v: int((255 - v) * 0.5)))
        mask = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([x0, y0, x1, y1], radius=self.U(0.35), fill=255)
        burn.putalpha(Image.composite(burn.getchannel("A"), Image.new("L", self.img.size, 0), mask))
        paper = Image.alpha_composite(paper, burn)
        self.img = Image.alpha_composite(self.img, paper)
        self.d = ImageDraw.Draw(self.img)
        # neatline frame
        o = self.U(0.3)
        self.d.rounded_rectangle([x0 + o, y0 + o, x1 - o, y1 - o], radius=self.U(0.25), outline=hex_rgba(INK, 200), width=int(self.U(0.07)))
        o = self.U(0.45)
        self.d.rounded_rectangle([x0 + o, y0 + o, x1 - o, y1 - o], radius=self.U(0.2), outline=hex_rgba(INK, 140), width=max(1, int(self.U(0.025))))
        self.d.rounded_rectangle([x0, y0, x1, y1], radius=self.U(0.35), outline=hex_rgba("#6B4423", 220), width=int(self.U(0.06)))

    def doodles(self):
        T = self.theme
        colors = {"ink": hex_rgba(T["ink"], 175), "bg": hex_rgba(T["wash"]), "acc": hex_rgba(T["acc"], 230),
                  "acc2": hex_rgba(T["acc2"], 220), "hi": hex_rgba(T["paper"])}
        for dd in self.L["decor"]:
            ops = self.decor[dd["kind"]]
            cl = colors
            if dd["kind"] == "rocks" and "rock" in T:
                cl = dict(colors)
                cl["acc"] = hex_rgba(T["rock"], 235)
            self.draw_ops_at(ops, dd["x"], dd["y"], dd["size"], cl, rot=dd["rot"], flip=dd["flip"])
        c = self.L["compass"]
        colors = {"ink": hex_rgba(INK, 200), "bg": hex_rgba(T["paper"]), "acc2": hex_rgba("#B5372B", 230)}
        self.draw_ops_at(self.decor["compass_rose"], c["x"], c["y"], c["size"], colors)

    def title(self):
        t = self.L["title"]
        cx, cy, w, h = self.X(t["x"]), self.Y(t["y"]), self.U(t["w"]), self.U(t["h"])
        fold = h * 0.55
        # ribbon tails
        for sgn in (-1, 1):
            ex = cx + sgn * (w / 2 + fold * 0.4)
            pts = [(ex - sgn * fold, cy - h * 0.32), (ex + sgn * fold * 0.6, cy - h * 0.32), (ex + sgn * fold * 0.15, cy + h * 0.05),
                   (ex + sgn * fold * 0.6, cy + h * 0.42), (ex - sgn * fold, cy + h * 0.42)]
            self.poly(pts, "#C9A86A")
            self.d.line(pts + [pts[0]], fill=hex_rgba(INK, 200), width=int(self.U(0.04)))
        self.d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], radius=h * 0.18, fill=hex_rgba("#E8D2A2"),
                                 outline=hex_rgba(INK, 220), width=int(self.U(0.05)))
        f = font("display", h * 0.62)
        txt = self.L["name"]
        bb = self.d.textbbox((0, 0), txt, font=f)
        self.d.text((cx - (bb[2] - bb[0]) / 2 - bb[0], cy - (bb[3] - bb[1]) / 2 - bb[1]), txt, font=f, fill=hex_rgba(INK))

    def links(self):
        for ln in self.L["links"]:
            x1, y1, x2, y2 = ln["x1"], ln["y1"], ln["x2"], ln["y2"]
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            dx, dy = x2 - x1, y2 - y1
            d = math.hypot(dx, dy)
            ux, uy = dx / d, dy / d
            col = "#B5372B" if ln["shortcut"] else INK
            a = (mx - ux * 0.12, my - uy * 0.12)
            b = (mx + ux * 0.12, my + uy * 0.12)
            self.d.line([(self.X(a[0]), self.Y(a[1])), (self.X(b[0]), self.Y(b[1]))], fill=hex_rgba(col, 230), width=int(self.U(0.1)))

    def tiles(self):
        S = 0.86
        depth = 0.16
        natural = {n["tile"]: n["kind"] for n in self.snap["natural"]}
        for t in self.L["tiles"]:
            x, y = t["x"], t["y"]
            top, inner, icon, icon_col = WOOD_TOP, WOOD_IN, None, None
            kind = t["kind"]
            if kind == "start":
                top, inner, icon, icon_col = "#E4DCCB", "#F3EEE2", "flag", "#B5372B"
            elif kind == "treasure":
                top, inner = "#E9B53A", "#F7CF5E"
            elif kind == "shortcutGate":
                top, inner, icon, icon_col = "#7E858D", "#98A0A8", "gate_trap", "#3A3F45"
            elif t.get("branch"):
                top, inner = "#B7A48A", "#C9B79C"
            if t["id"] in natural:
                top, inner, icon = NATURAL[natural[t["id"]]]
                icon_col = "#FFFFFF"
            side = darken(top, 0.38)
            self.poly([(self.X(px), self.Y(py)) for px, py in hexagon(x, y + depth, S)], side)
            self.poly([(self.X(px), self.Y(py)) for px, py in hexagon(x, y, S)], top)
            self.poly([(self.X(px), self.Y(py)) for px, py in hexagon(x, y - 0.03, S * 0.8)], inner)
            if kind == "treasure":
                colors = {"ink": hex_rgba("#B5372B"), "bg": hex_rgba(inner)}
                self.draw_ops_at(self.icons["x_mark"], x, y, 1.05, colors)
            elif icon:
                colors = {"ink": hex_rgba(icon_col, 230), "bg": hex_rgba(inner)}
                self.draw_ops_at(self.icons[icon], x, y - 0.02, 0.85, colors)
            else:
                f = font("chunky", self.U(0.3))
                s = str(t["id"])
                bb = self.d.textbbox((0, 0), s, font=f)
                self.d.text((self.X(x) - (bb[2] - bb[0]) / 2 - bb[0], self.Y(y + 0.55) - (bb[3] - bb[1]) / 2 - bb[1]), s, font=f,
                            fill=hex_rgba("#8A5A2E", 170))

    def tokens(self):
        for tk in self.snap["tokens"]:
            t = self.L["tiles"][tk["tile"] - 1]
            x, y = t["x"], t["y"] - 0.14
            col = CAT[tk["kind"]]
            r = 0.4
            self.d.ellipse([self.X(x - r), self.Y(y - r + 0.08), self.X(x + r), self.Y(y + r + 0.08)], fill=(40, 20, 10, 90))
            self.d.ellipse([self.X(x - r), self.Y(y - r), self.X(x + r), self.Y(y + r)], fill=hex_rgba(col), outline=hex_rgba("#E3B04B"), width=int(self.U(0.07)))
            colors = {"ink": hex_rgba("#FFFFFF"), "bg": hex_rgba(col), "acc": hex_rgba("#FFE39A"), "hi": hex_rgba(col)}
            self.draw_ops_at(self.icons[TOKEN_ICON[tk["kind"]]], x, y, 0.5, colors)

    def placed(self):
        for p in self.snap["placed"]:
            t = self.L["tiles"][p["tile"] - 1]
            x, y = t["x"], t["y"] - 0.14
            s = 0.58
            self.d.rounded_rectangle([self.X(x - s / 2), self.Y(y - s / 2 + 0.06), self.X(x + s / 2), self.Y(y + s / 2 + 0.06)],
                                     radius=self.U(0.1), fill=(40, 20, 10, 110))
            self.d.rounded_rectangle([self.X(x - s / 2), self.Y(y - s / 2), self.X(x + s / 2), self.Y(y + s / 2)], radius=self.U(0.1),
                                     fill=hex_rgba("#B57D46"), outline=hex_rgba("#5C3818"), width=int(self.U(0.04)))
            cat = CAT.get(ITEM_CAT.get(p["item"], "trap"))
            self.d.rounded_rectangle([self.X(x - s / 2), self.Y(y - s / 2), self.X(x + s / 2), self.Y(y - s / 2 + 0.09)], radius=self.U(0.05),
                                     fill=hex_rgba(cat))
            hi = {"ink": hex_rgba("#F0CB98"), "bg": hex_rgba("#B57D46")}
            dk = {"ink": hex_rgba("#4E2E14"), "bg": hex_rgba("#B57D46"), "acc": hex_rgba("#4E2E14"), "hi": hex_rgba("#B57D46")}
            self.draw_ops_at(self.icons[p["item"]], x, y + 0.04 + 0.015, 0.44, hi)
            self.draw_ops_at(self.icons[p["item"]], x, y + 0.04, 0.44, dk)
            if p.get("owner"):
                oc = SEAT[(p["owner"] - 1) % 6]
                r = 0.1
                self.d.ellipse([self.X(x + s / 2 - r * 1.2 - r), self.Y(y - s / 2 - r * 0.2 - r), self.X(x + s / 2 - r * 1.2 + r),
                                self.Y(y - s / 2 - r * 0.2 + r)], fill=hex_rgba(oc), outline=hex_rgba("#FFFFFF"), width=int(self.U(0.025)))

    def pawns(self):
        groups = {}
        for p in self.snap["players"]:
            groups.setdefault(p["tile"], []).append(p)
        for tile, ps in groups.items():
            t = self.L["tiles"][tile - 1]
            n = len(ps)
            for i, p in enumerate(ps):
                ox, oy = 0, 0
                if n > 1:
                    a = math.radians(-90 + 360 * i / n)
                    ox, oy = math.cos(a) * 0.36, math.sin(a) * 0.32
                x, y = t["x"] + ox, t["y"] + oy - 0.3
                col = SEAT[(p["seat"] - 1) % 6]
                r = 0.38
                # shadow
                self.d.ellipse([self.X(x - r * 0.9), self.Y(y + 0.3 - 0.1), self.X(x + r * 0.9), self.Y(y + 0.3 + 0.12)], fill=(30, 15, 8, 110))
                if p["seat"] == self.snap["current"]:
                    rr = r + 0.13
                    self.d.ellipse([self.X(x - rr), self.Y(y - rr), self.X(x + rr), self.Y(y + rr)], outline=hex_rgba("#FFE39A"), width=int(self.U(0.07)))
                self.d.ellipse([self.X(x - r), self.Y(y - r + 0.1), self.X(x + r), self.Y(y + r + 0.1)], fill=hex_rgba(darken(col, 0.45)))
                self.d.ellipse([self.X(x - r), self.Y(y - r), self.X(x + r), self.Y(y + r)], fill=hex_rgba(darken(col, 0.2)))
                self.d.ellipse([self.X(x - r * 0.84), self.Y(y - r * 0.84), self.X(x + r * 0.84), self.Y(y + r * 0.84)], fill=hex_rgba(col))
                self.d.ellipse([self.X(x - r * 0.56), self.Y(y - r * 0.56), self.X(x + r * 0.56), self.Y(y + r * 0.56)],
                               outline=hex_rgba("#FFFFFF", 220), width=int(self.U(0.06)))
                self.d.ellipse([self.X(x - r * 0.62), self.Y(y - r * 0.78), self.X(x - r * 0.1), self.Y(y - r * 0.3)], fill=(255, 255, 255, 90))
                cc = CHAR_COLOR.get(p["character"], "#888888")
                br = 0.16
                bx, by = x + r * 0.7, y + r * 0.62
                self.d.ellipse([self.X(bx - br), self.Y(by - br), self.X(bx + br), self.Y(by + br)], fill=hex_rgba(cc), outline=hex_rgba("#FFFFFF"), width=int(self.U(0.03)))
                self.draw_ops_at(self.icons[p["character"]], bx, by, 0.22, {"ink": hex_rgba("#FFFFFF"), "bg": hex_rgba(cc), "hi": hex_rgba(cc)})

    def render(self, out):
        self.parchment()
        self.doodles()
        self.title()
        self.links()
        self.tiles()
        self.tokens()
        self.placed()
        self.pawns()
        self.table()
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
