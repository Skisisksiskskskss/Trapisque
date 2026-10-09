#!/usr/bin/env python3
"""Drawing helpers for the full-screen previews (tools/preview/hud.py draws the screens).

Screen draws widgets at a stage resolution the way Widgets builds them (buttons, panels,
title cartouches, toggles, progress bars, badges); draw_chests draws the Treasure Chests
page (Chests.lua) on top of a screen.
"""
import os
import random
import sys
import textwrap

sys.path.insert(0, os.path.dirname(__file__))
from render import Layer, Canvas, draw_ops, hex_rgba, font  # noqa: E402
from cosmetics import draw_pawn  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

S = 2  # supersampling of the 1280x720 virtual stage

TABLE, PLANK, TABLE_LIGHT = "#1A130E", "#120D0A", "#241A13"
# the dark UI (Theme.C): surfaces from deepest to highest, then text on them
BG, PANEL, PANEL_DEEP, PANEL_RAISED, PANEL_HI = "#140F0B", "#2A2119", "#1C1612", "#372B21", "#46372A"
PANEL_EDGE, PANEL_LINE, MINE = "#5C4736", "#3E3026", "#3A2F1B"
TEXT, TEXT_SOFT, TEXT_FAINT, TEXT_ON_LIGHT = "#F3E8D2", "#C9B89C", "#8F7F69", "#3A2414"
INFO_SOFT, GOOD_SOFT = "#8DBDEB", "#8CD07A"
PARCH, PARCH_MID, PARCH_DARK, PARCH_EDGE, BURN = "#F3E4C1", "#E8D2A2", "#D2B27A", "#A97C45", "#6B4423"
INK, INK_SOFT, INK_FAINT, INK_RED = "#4A3020", "#7B5B3E", "#A88B66", "#B5372B"
WOOD, WOOD_PALE, WOOD_DARK, WOOD_DEEP = "#B57D46", "#E6C18F", "#80522A", "#5C3818"
BRASS, BRASS_LIGHT, BRASS_DARK, GOLD = "#E3B04B", "#FFE39A", "#9E7425", "#FFC93C"
GOOD, INFO, WHITE, TEXT_DARK, TEXT_LIGHT, DIM = "#5BB36A", "#4C8DC9", "#FFFFFF", "#3A2414", "#FFF5DE", "#0B0704"
NEUTRAL = "#7A61A8"
SEAT = ["#E35D5D", "#4E8FDB", "#5DB866", "#EDBB36", "#A56CDB", "#F0883A"]
CHAR = {"mage": "#5876D6", "trapper": "#A86B39", "fire_starter": "#E2622B", "naturalist": "#4E9A47", "warper": "#8B57CC", "overseer": "#CDA42A"}
CAT = {"trap": "#C2513B", "assist": "#5E9A3C", "neutral": "#7A61A8", "potion": "#D98C1F"}

# Widgets.ButtonStyles
STYLES = {
    "wood": {"face": "#6A4A31", "dark": "#3F2B1B", "stroke": "#1E140C", "text": TEXT, "outline": "#2A1C11"},
    "brass": {"face": BRASS, "dark": BRASS_DARK, "stroke": "#5E430F", "text": "#3F2906", "engraved": True},
    "red": {"face": "#B9493A", "dark": "#7D2D21", "stroke": "#4A170E", "text": WHITE, "outline": "#4A170E"},
    "green": {"face": "#4F9135", "dark": "#33621F", "stroke": "#1F3D12", "text": WHITE, "outline": "#1F3D12"},
    "blue": {"face": "#4577AD", "dark": "#2D5277", "stroke": "#18314A", "text": WHITE, "outline": "#18314A"},
    "purple": {"face": "#715AA0", "dark": "#4C3A6E", "stroke": "#2C2142", "text": WHITE, "outline": "#2C2142"},
    "panel": {"face": PANEL_RAISED, "dark": PANEL_DEEP, "stroke": "#120D0A", "text": TEXT, "outline": "#120D0A"},
    "dark": {"face": "#2C231B", "dark": "#15100C", "stroke": "#0A0705", "text": TEXT, "outline": "#0A0705"},
}
STYLES["parchment"] = STYLES["panel"]


def mix(a, b, t):
    ca, cb = hex_rgba(a), hex_rgba(b)
    return "#%02X%02X%02X" % tuple(int(round(ca[i] + (cb[i] - ca[i]) * t)) for i in range(3))


def shade(h, amt):
    return mix(h, "#FFFFFF", amt) if amt >= 0 else mix(h, "#000000", -amt)


class Screen:
    def __init__(self, data, w=1280, h=720):
        self.data = data
        self.icons = data["icons"]
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * S, h * S), hex_rgba(TABLE))

    @property
    def d(self):
        return ImageDraw.Draw(self.img)

    def B(self, x, y, w, h, grow=0.0):
        return [(x - grow) * S, (y - grow) * S, (x + w + grow) * S, (y + h + grow) * S]

    def _overlay(self, fn):
        lay = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        fn(ImageDraw.Draw(lay))
        self.img = Image.alpha_composite(self.img, lay)

    # ---------------------------------------------------------------- shapes
    def rect(self, x, y, w, h, r, color, alpha=1.0):
        if alpha >= 1:
            self.d.rounded_rectangle(self.B(x, y, w, h), radius=r * S, fill=hex_rgba(color))
        else:
            self._overlay(lambda d: d.rounded_rectangle(self.B(x, y, w, h), radius=r * S, fill=hex_rgba(color, int(255 * alpha))))

    def outline(self, x, y, w, h, r, color, th, alpha=1.0):
        """UIStroke on a frame: a ring just outside its bounds."""
        box = self.B(x, y, w, h, grow=th)
        self._overlay(lambda d: d.rounded_rectangle(box, radius=(r + th) * S, outline=hex_rgba(color, int(255 * alpha)),
                                                    width=max(1, int(round(th * S)))))

    def frame(self, x, y, w, h, r, fill=None, stroke=None, sw=0.0, salpha=1.0, falpha=1.0):
        if stroke and sw > 0 and salpha >= 1 and (fill is None or falpha >= 1):
            self.rect(x - sw, y - sw, w + 2 * sw, h + 2 * sw, r + sw, stroke)
            if fill:
                self.rect(x, y, w, h, r, fill)
            return
        if fill:
            self.rect(x, y, w, h, r, fill, falpha)
        if stroke and sw > 0:
            self.outline(x, y, w, h, r, stroke, sw, salpha)

    def circle(self, cx, cy, d, color):
        self.d.ellipse([(cx - d / 2) * S, (cy - d / 2) * S, (cx + d / 2) * S, (cy + d / 2) * S], fill=hex_rgba(color))

    # ---------------------------------------------------------------- text
    def text(self, x, y, w, h, txt, kind="body", size=16, color=INK, align="left", valign="center", outline=None, ow=0,
             wrap=False, scaled=False, alpha=1.0):
        d = self.d
        size_px = size * S
        while True:
            f = font(kind, size_px)
            if wrap:
                avg = d.textbbox((0, 0), "abcdefghijklmnopqrstuvwxyz", font=f)
                cpl = max(4, int(w * S / ((avg[2] - avg[0]) / 26)))
                lines = textwrap.wrap(txt, cpl) or [""]
            else:
                lines = [txt]
            lh = size_px * 1.2
            widest = max(d.textbbox((0, 0), ln, font=f)[2] for ln in lines)
            if not scaled or (widest <= w * S and lh * len(lines) <= h * S) or size_px <= 8:
                break
            size_px -= 1
        if not wrap and not scaled:
            # TextTruncate-ish
            while lines[0] and d.textbbox((0, 0), lines[0], font=f)[2] > w * S and len(lines[0]) > 3:
                lines[0] = lines[0][:-2].rstrip() + "…"
        total = lh * len(lines)
        if valign == "center":
            ty = y * S + (h * S - total) / 2
        elif valign == "bottom":
            ty = y * S + h * S - total
        else:
            ty = y * S
        asc, desc = f.getmetrics()
        fill = hex_rgba(color, int(255 * alpha))
        for ln in lines:
            bb = d.textbbox((0, 0), ln, font=f)
            tw = bb[2] - bb[0]
            if align == "center":
                tx = x * S + (w * S - tw) / 2 - bb[0]
            elif align == "right":
                tx = x * S + w * S - tw - bb[0]
            else:
                tx = x * S - bb[0]
            yy = ty + (lh - (asc + desc)) / 2
            if outline:
                d.text((tx, yy), ln, font=f, fill=fill, stroke_width=int(ow * S), stroke_fill=hex_rgba(outline))
            else:
                d.text((tx, yy), ln, font=f, fill=fill)
            ty += lh

    def text_width(self, txt, kind, size):
        f = font(kind, size * S)
        bb = self.d.textbbox((0, 0), txt, font=f)
        return (bb[2] - bb[0]) / S

    # ---------------------------------------------------------------- art
    def ops(self, ops, x, y, size, colors):
        px = int(size * S)
        lay = Layer(px + 8, px + 8, ss=3)
        draw_ops(Canvas(lay, 4, 4, px, colors), ops)
        self.img.alpha_composite(lay.final(), (int(x * S) - 4, int(y * S) - 4))

    def icon(self, name, x, y, size, ink, bg, acc=None):
        a = acc or ink
        colors = {"ink": hex_rgba(ink), "bg": hex_rgba(bg), "acc": hex_rgba(a), "acc2": hex_rgba(a), "hi": hex_rgba(bg)}
        self.ops(self.icons[name], x, y, size, colors)

    def medallion(self, name, cx, cy, d, color):
        """Icons.medallion: disc, brass rim (0.08 d) outside, white glyph at 0.64 d."""
        self.circle(cx, cy, d * 1.16, BRASS)
        self.circle(cx, cy, d, color)
        g = d * 0.64
        self.icon(name, cx - g / 2, cy - g / 2, g, WHITE, color, BRASS_LIGHT)

    def pawn(self, look_id, cx, cy, size, seat):
        looks = self.data["looks"]
        item = {"look": looks.get(look_id) or looks["pawn_classic"]}
        side = int(size * S)
        tmp = Image.new("RGBA", (side * 2, side * 2), (0, 0, 0, 0))
        draw_pawn(tmp, side / 2, side / 2, side, item, {"patterns": self.data["patterns"]}, seat=seat)
        self.img.alpha_composite(tmp, (int(cx * S - side), int(cy * S - side)))

    # ---------------------------------------------------------------- widgets
    def table(self):
        d = self.d
        for i in range(15):
            yy = i / 14 * self.h * S
            d.line([(0, yy), (self.w * S, yy)], fill=hex_rgba(PLANK, 204), width=3 * S)
        rnd = random.Random(7)
        for i in range(22):
            yy = ((i + 0.5) / 22 + (rnd.random() - 0.5) * 0.06) * self.h
            ww = (0.75 + rnd.random() * 0.2) * self.w
            x0 = (self.w - ww) / 2 + (rnd.random() - 0.5) * 0.1 * self.w
            self._overlay(lambda dd, x0=x0, yy=yy, ww=ww: dd.rounded_rectangle([x0 * S, yy * S, (x0 + ww) * S, (yy + 2) * S], radius=S,
                                                                             fill=hex_rgba(TABLE_LIGHT, 64)))

    def button(self, x, y, w, h, text=None, icon=None, style="wood", depth=5, size=22, corner=12, enabled=True, icon_scale=0.62):
        st = STYLES[style]
        a = 1.0 if enabled else 0.65
        self.frame(x, y + depth, w, h - depth, corner, st["dark"], st["stroke"], 2, falpha=a, salpha=a)
        self.frame(x, y, w, h - depth, corner, st["face"], st["stroke"], 2, falpha=a, salpha=a)
        fh = h - depth
        isz = fh * icon_scale if icon else 0
        tw = self.text_width(text, "chunky", size) if text else 0
        gap = 8 if (icon and text) else 0
        total = isz + gap + tw
        cx = x + (w - total) / 2
        if icon:
            ink = shade(st["face"], -0.62) if st.get("engraved") else st["text"]
            self.icon(icon, cx, y + (fh - isz) / 2, isz, ink, st["face"])
        if text:
            self.text(cx + isz + gap, y, tw + 4, fh, text, "chunky", size, st["text"], outline=st.get("outline"),
                      ow=2 if st.get("outline") else 0, alpha=1.0 if enabled else 0.6)

    def cartouche(self, cx, top, w, text, h=44):
        """Widgets.ribbon: a dark plaque, a double brass border, gold display lettering."""
        x = cx - w / 2
        self.frame(x, top, w, h, 8, PANEL_DEEP, BRASS_DARK, 2, salpha=0.95)
        self.outline(x + 5, top + 5, w - 10, h - 10, 5, BRASS, 1, 0.45)
        self.text(x + 8, top + 4, w - 16, h - 8, text, "display", 28, BRASS_LIGHT, align="center", scaled=True)

    def panel(self, x, y, w, h, style="walnut", title=None, title_w=280, pad=18, shadow=True):
        if shadow:
            self.rect(x, y + 6, w, h, 14, "#000000", 0.5)
        if style in ("walnut", "parchment"):
            # dark walnut with a brass inlay line just inside the edge
            self.frame(x, y, w, h, 14, PANEL, "#0E0A07", 3)
            self.outline(x + 7, y + 7, w - 14, h - 14, 8, BRASS_DARK, 1.5, 0.55)
        else:
            fill = "#3A2618" if style == "board" else "#4E3320"
            self.frame(x, y, w, h, 14, fill, "#1A110A", 3)
            rnd = random.Random(int(x * 7 + y))
            for i in range(6):
                yy = y + ((i + 0.5) / 6 + (rnd.random() - 0.5) * 0.06) * h
                ww = (0.75 + rnd.random() * 0.2) * w
                self.rect(x + (w - ww) / 2, yy, ww, 2, 1, "#24170D", 0.25)
        if title:
            self.cartouche(x + w / 2, y + 14, title_w, title)
        top = pad + (54 if title else 0)
        return (x + pad, y + top, w - 2 * pad, h - top - pad)

    def progress(self, x, y, w, h, value, color):
        self.frame(x, y, w, h, h / 2, PANEL_DEEP, "#0E0A07", 2)
        if value > 0:
            self.rect(x, y, max(h, w * value), h, h / 2, color)

    def badge(self, x, y, text, color, h=24, size=16, text_color=WHITE, stroke=None, anchor_right=False):
        tw = self.text_width(text, "chunky", size)
        w = tw + 16
        if anchor_right:
            x -= w
        self.frame(x, y, w, h, h / 2, color, stroke or shade(color, -0.4), 2)
        self.text(x, y, w, h, text, "chunky", size, text_color, align="center")
        return w

    def choice(self, x, y, w, h, options, value, size=17):
        n = len(options)
        bw = (w - 6 * (n - 1)) / n
        for i, (label, v) in enumerate(options):
            on = v == value
            bx = x + i * (bw + 6)
            self.frame(bx, y, bw, h, 8, BRASS if on else PANEL_RAISED, BRASS_DARK if on else PANEL_EDGE, 2)
            self.text(bx + 4, y, bw - 8, h, label, "chunky", size, TEXT_ON_LIGHT if on else TEXT_SOFT, align="center", scaled=True)

    def dim(self, alpha=0.55):
        self.rect(0, 0, self.w, self.h, 0, DIM, alpha)

    def save(self, path, out_w=1920):
        out = self.img.resize((out_w, int(out_w * self.h / self.w)), Image.LANCZOS)
        out.convert("RGB").save(path)
        print("wrote", path, out.size)


# ------------------------------------------------------------------------- chests
def chest_art(sc, look, x, y, size):
    """Chests.art: base (body, trim bands, lock) and lid (top, bands, rim)."""
    body, trim, band, gem = look["body"], look["trim"], look["band"], look["gem"]
    P = lambda v: v * size  # noqa: E731
    def r(cx, cy, w, h, col, rr=0.0):
        sc.rect(x + P(cx - w / 2), y + P(cy - h / 2), P(w), P(h), rr * min(P(w), P(h)), col)
    r(0.5, 0.6825, 0.8, 0.395, body)
    r(0.27, 0.6825, 0.09, 0.395, trim)
    r(0.73, 0.6825, 0.09, 0.395, trim)
    r(0.5, 0.58, 0.17, 0.15, trim, 0.2)
    sc.circle(x + P(0.5), y + P(0.58), P(0.075), gem)
    r(0.5, 0.375, 0.8, 0.22, body, 0.4)
    r(0.5, 0.43, 0.8, 0.11, body)
    r(0.27, 0.375, 0.09, 0.22, trim)
    r(0.73, 0.375, 0.09, 0.22, trim)
    r(0.5, 0.4675, 0.8, 0.035, band)


def draw_chests(sc, data):
    """The Treasure Chests page over whatever `sc` shows (the lobby)."""
    sc.dim(0.55)
    W, H = sc.w, sc.h
    mw, mh = 900, 580
    mx, my = W / 2 - mw / 2, H * 0.52 - mh / 2
    cx, cy, cw, ch = sc.panel(mx, my, mw, mh, title="Treasure Chests", title_w=320)
    sc.button(mx + mw - 14 - 40, my + 14, 40, 42, icon="close", style="red", depth=4, icon_scale=0.66)
    sc.medallion("gem", cx + 18, cy + 20, 36, NEUTRAL)
    sc.text(cx + 44, cy, 200, 40, "1,240", "chunky", 28, TEXT)
    sc.text(cx + 250, cy, cw - 250, 40, "Gems come from playing matches. Duplicates turn back into Gems.", "heavy", 15, TEXT_SOFT,
            align="right")
    chests = data["cosmetics"]["chests"]
    pity = ["Epic or better within 7 chests", "Legendary or better within 14 chests"]
    card_w = cw / 2 - 10
    for i, chest in enumerate(chests):
        x = cx + i * (card_w + 20)
        y = cy + 50
        hh = ch - 50
        sc.frame(x, y, card_w, hh, 14, PANEL_RAISED, PANEL_EDGE, 2)
        chest_art(sc, chest["look"], x + card_w / 2 - 85, y + 6, 170)
        sc.text(x, y + 176, card_w, 30, chest["name"], "chunky", 26, TEXT, align="center")
        blurb = ["Everything can drop. Great for starting a collection.", "No commons. Much better shot at Legendary and Mythic."][i]
        sc.text(x + 15, y + 206, card_w - 30, 38, blurb, "heavy", 15, TEXT_SOFT, align="center", wrap=True)
        sc.text(x + 15, y + 246, card_w - 30, 18, pity[i], "heavy", 14, "#B9A4E6", align="center")
        odds = chest["odds"]
        order = ["common", "rare", "epic", "legendary", "mythic"]
        colors = {r["id"]: r["color"] for r in data["cosmetics"]["rarities"]}
        names = {r["id"]: r["name"] for r in data["cosmetics"]["rarities"]}
        sx, sw = x + 20, card_w - 40
        entries = []
        for rr in order:
            v = odds.get(rr, 0)
            if v > 0:
                segw = max(6, v / 100 * sw - 3)
                sc.rect(sx, y + 278, segw, 12, 6, colors[rr])
                sx += segw + 3
                label = "%s %s%%" % (names[rr], ("%d" % round(v)) if abs(v - round(v)) < 0.05 else ("%.1f" % v))
                entries.append((colors[rr], label, 8 + 4 + sc.text_width(label, "heavy", 12)))
        # UIListLayout with Wraps: whole entries flow onto the next line, each line centred
        lines, cur = [], []
        for e in entries:
            if cur and sum(c[2] for c in cur) + 12 * len(cur) + e[2] > sw:
                lines.append(cur)
                cur = []
            cur.append(e)
        lines.append(cur)
        for li, line in enumerate(lines):
            lw = sum(c[2] for c in line) + 12 * (len(line) - 1)
            ex = x + 20 + (sw - lw) / 2
            ey = y + 278 + 18 + li * 16
            for col, label, ew in line:
                sc.circle(ex + 4, ey + 8, 8, col)
                sc.text(ex + 12, ey, ew - 12 + 2, 16, label, "heavy", 12, TEXT_SOFT)
                ex += ew + 12
        bw = (card_w - 30) / 2 - 6
        by = y + hh - 50 - 52
        if i == 0:
            sc.button(x + 15, by, bw, 52, text="OPEN FREE", icon="chest", style="green", size=20)
        else:
            sc.button(x + 15, by, bw, 52, text=str(chest["price"]), icon="gem", style="brass", size=20)
        sc.button(x + 15 + bw + 12, by, bw, 52, text="x10  " + format(chest["price"] * 9, ","), icon="gem", style="purple", size=18)
        sc.button(x + card_w / 2 - 70, y + hh - 8 - 36, 140, 36, text="SEE ODDS", style="parchment", size=15)
