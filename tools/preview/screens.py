#!/usr/bin/env python3
"""Full-screen mockups of the match screen, the lobby and the Treasure Chests page.

Lays the screens out with the same sizes and positions as the Lua UI at the 1280x720
virtual resolution (MatchScreen, HandBar, PlayersPanel, LobbyScreen, PlayPanel,
PartyPanel, Chests) and draws them with the same preview primitives as the other
sheets, so the layout and style can be judged without opening Roblox.

Usage: python3 tools/preview/screens.py <dir with icons/board/cosmetics/cards .json> <outdir>
"""
import json
import math
import os
import random
import sys
import textwrap

sys.path.insert(0, os.path.dirname(__file__))
from render import Layer, Canvas, draw_ops, hex_rgba, font  # noqa: E402
from cosmetics import draw_pawn  # noqa: E402
from cards import CardPainter  # noqa: E402
import board as boardmod  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

S = 2  # supersampling of the 1280x720 virtual stage

TABLE, PLANK, TABLE_LIGHT = "#2A1C13", "#221710", "#3A281B"
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
    "wood": {"face": WOOD, "dark": WOOD_DARK, "stroke": WOOD_DEEP, "text": "#4E2E14", "engraved": True},
    "brass": {"face": BRASS, "dark": BRASS_DARK, "stroke": "#6E4F12", "text": "#4A3008", "engraved": True},
    "red": {"face": "#C2513B", "dark": "#8A3122", "stroke": "#5A1D12", "text": WHITE, "outline": "#5A1D12"},
    "green": {"face": "#5E9A3C", "dark": "#3D6B24", "stroke": "#284616", "text": WHITE, "outline": "#284616"},
    "blue": {"face": "#4C80B8", "dark": "#33597F", "stroke": "#1F3A55", "text": WHITE, "outline": "#1F3A55"},
    "purple": {"face": "#7A61A8", "dark": "#554279", "stroke": "#362A4E", "text": WHITE, "outline": "#362A4E"},
    "parchment": {"face": PARCH, "dark": PARCH_DARK, "stroke": PARCH_EDGE, "text": INK, "engraved": True},
}


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
        x = cx - w / 2
        self.frame(x, top, w, h, 8, PARCH_MID, INK, 2, salpha=0.9)
        self.outline(x + 5, top + 5, w - 10, h - 10, 5, INK, 1, 0.55)
        self.text(x + 8, top + 4, w - 16, h - 8, text, "display", 28, INK, align="center", scaled=True)

    def panel(self, x, y, w, h, style="parchment", title=None, title_w=280, pad=18, shadow=True):
        if shadow:
            self.rect(x, y + 6, w, h, 14, "#000000", 0.4)
        if style == "parchment":
            self.frame(x, y, w, h, 14, PARCH, BURN, 3)
            self.outline(x + 7, y + 7, w - 14, h - 14, 8, INK_FAINT, 1.5, 0.7)
        else:
            fill = WOOD_DARK if style == "board" else WOOD
            self.frame(x, y, w, h, 14, fill, WOOD_DEEP, 3)
            rnd = random.Random(int(x * 7 + y))
            for i in range(6):
                yy = y + ((i + 0.5) / 6 + (rnd.random() - 0.5) * 0.06) * h
                ww = (0.75 + rnd.random() * 0.2) * w
                self.rect(x + (w - ww) / 2, yy, ww, 2, 1, WOOD_DEEP, 0.25)
        if title:
            self.cartouche(x + w / 2, y + 14, title_w, title)
        top = pad + (54 if title else 0)
        return (x + pad, y + top, w - 2 * pad, h - top - pad)

    def progress(self, x, y, w, h, value, color):
        self.frame(x, y, w, h, h / 2, WOOD_DEEP, WOOD_DEEP, 2)
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
            self.frame(bx, y, bw, h, 8, BRASS if on else PARCH, BRASS_DARK if on else PARCH_EDGE, 2)
            self.text(bx + 4, y, bw - 8, h, label, "chunky", size, INK if on else INK_SOFT, align="center", scaled=True)

    def dim(self, alpha=0.55):
        self.rect(0, 0, self.w, self.h, 0, DIM, alpha)

    def save(self, path, out_w=1920):
        out = self.img.resize((out_w, int(out_w * self.h / self.w)), Image.LANCZOS)
        out.convert("RGB").save(path)
        print("wrote", path, out.size)


# ------------------------------------------------------------------------- match
class QuietScene(boardmod.Scene):
    """The board renderer without its own table background."""

    def table(self):
        pass


def match_screen(data, out):
    sc = Screen(data)
    sc.table()
    top, GAP, SIDE_W, TOP_H, HAND_H = 56, 10, 270, 40, 150
    W, H = sc.w, sc.h
    left_w = W - (SIDE_W + 3 * GAP)

    # board (BoardView fits the world into the area * 0.98)
    bx, by, bw, bh = GAP, top + TOP_H + 6, left_w, H - (top + TOP_H + 6 + HAND_H + 2 * GAP)
    scene_data = json.loads(json.dumps(data["board"]))
    scene = scene_data["scenes"][0]
    scene["snapshot"]["current"] = 1
    L = scene["layout"]
    k = min(bw / L["w"], bh / L["h"]) * 0.98
    world_w = L["w"] * k
    pad = 6
    bs = QuietScene(scene_data, scene, width=int((world_w + 2 * pad) * S), pad=pad * S)
    bimg = bs.render("/tmp/claude-0/build/prev/_board_tmp.png")
    bimg = bimg.convert("RGBA")
    px = int((bx + bw / 2) * S - bimg.width / 2)
    py = int((by + bh / 2) * S - bimg.height / 2)
    # the board image has a dark table fill outside the paper; mask it to the paper's shape
    mask = Image.new("L", bimg.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([pad * S - 6 * S, pad * S - 6 * S, bimg.width - pad * S + 6 * S, bimg.height - pad * S + 14 * S],
                                           radius=int(0.35 * k * S) + 8, fill=255)
    sc.img.paste(bimg, (px, py), mask)

    # top bar
    sc.frame(GAP, top, 400, TOP_H, 10, PARCH, BURN, 2)
    sc.text(GAP + 12, top, 110, TOP_H, "Round 3", "chunky", 20, INK)
    sc.text(GAP + 122, top, 400 - 132, TOP_H, "Chaos  ·  Quick  ·  First to 2", "heavy", 15, INK_SOFT)
    bxr = GAP + left_w
    for icon, style in [("gear", "wood"), ("smile", "brass"), ("plus", "parchment"), ("minus", "parchment")]:
        bxr -= 42
        sc.button(bxr, top, 42, 40, icon=icon, style=style, depth=4, icon_scale=0.66)
        bxr -= 8

    # event log (bottom-left of the board area)
    lines = [
        ([("Pip", SEAT[1]), (" rolled a 4", PARCH)]),
        ([("Nib", SEAT[2]), (" hit ", PARCH), ("your", SEAT[0]), (" Spike!", PARCH)]),
        ([("Nib", SEAT[2]), (" was spiked!", "#E8A39E")]),
    ]
    ly = by + bh - 10
    for parts in reversed(lines):
        full = "".join(t for t, _ in parts)
        tw = sc.text_width(full, "heavy", 15)
        ly -= 26
        sc.rect(GAP + 10, ly, tw + 16, 23, 8, DIM, 0.65)
        cx = GAP + 18
        for t, col in parts:
            w = sc.text_width(t, "heavy", 15)
            sc.text(cx, ly, w + 2, 23, t, "heavy", 15, col)
            cx += w
        ly -= 3

    # players column
    sx = W - GAP - SIDE_W
    cx, cy, cw, ch = sc.panel(sx, top, SIDE_W, H - top - GAP, pad=10)
    players = [
        (1, "Rowan", "mage", "pawn_classic", 1, 2, 3, True),
        (2, "Bot Pip", "trapper", "pawn_ocean", 0, 1, 4, False),
        (3, "Bot Nib", "fire_starter", "pawn_bee", 1, 0, 2, False),
        (4, "Bot Rusty", "warper", "pawn_galaxy", 0, 3, 5, False),
    ]
    names = {"mage": "Mage", "trapper": "Trapper", "fire_starter": "Fire Starter", "warper": "Warper"}
    yy = cy
    CARD_H = 88
    statuses = {3: [("fire", "#E2622B")], 4: [("time_potion", "#8E6CEF")]}
    for seat, name, char, skin, treasures, coins, cards_n, current in players:
        bg = "#FFF6D6" if current else "#FBF3DD"
        if current:
            sc.outline(cx, yy, cw, CARD_H, 12, BRASS, 4)
        sc.frame(cx, yy, cw, CARD_H, 12, bg, PARCH_EDGE, 2)
        sc.pawn(skin, cx + 10 + 25, yy + 6 + 25, 50, SEAT[seat - 1])
        sc.text(cx + 70, yy + 6, cw - 78, 20, name + ("  (you)" if seat == 1 else ""), "heavy", 17, TEXT_DARK)
        sc.medallion(char, cx + 70 + 8, yy + 29 + 8, 16, CHAR[char])
        sc.text(cx + 92, yy + 29, cw - 100, 16, names[char] + ("" if seat == 1 else "  ·  BOT"), "body", 13, CHAR[char])
        target = 2
        pip = min(18, (92 - (target - 1) * 7) // target)
        for i in range(target):
            filled = i < treasures
            sc.frame(cx + 70 + i * (pip + 7), yy + 54 + (20 - pip) / 2, pip, pip, pip / 2, GOLD if filled else PARCH_DARK,
                     BRASS_DARK, 2)
        rx = cx + cw - 8 - 72
        sc.icon("coin", rx, yy + 53 + 3, 16, BRASS_DARK, PARCH)
        sc.text(rx + 17, yy + 53, 18, 22, str(coins), "chunky", 16, TEXT_DARK)
        sc.icon("book", rx + 38, yy + 53 + 3, 16, WOOD_DARK, PARCH)
        sc.text(rx + 38 + 17, yy + 53, 18, 22, str(cards_n), "chunky", 16, TEXT_DARK)
        for j, (icon, col) in enumerate(statuses.get(seat, [])):
            sc.medallion(icon, cx + 6 + 30 + j * 22, yy + 60 + 8, 16, col)
        if current:
            sc.progress(cx + 12, yy + CARD_H - 8, cw - 24, 4, 0.7, BRASS)
        yy += CARD_H + 8

    # hand bar
    hx, hy = GAP, H - GAP - HAND_H
    ccx, ccy, ccw, cch = sc.panel(hx, hy, left_w, HAND_H, style="board", pad=10)
    # character
    sc.medallion("mage", ccx + 4 + 42, ccy + cch / 2, 84, CHAR["mage"])
    sc.text(ccx + 100, ccy + 8, 110, 26, "Mage", "chunky", 22, PARCH)
    sc.button(ccx + 100, ccy + 38, 214 - 106, 44, text="HEX", style="blue", size=20)
    for i in range(2):
        sc.frame(ccx + 100 + 33 + i * 17, ccy + 88 + 1, 12, 12, 6, BRASS, BRASS_DARK, 1.5)
    sc.text(ccx + 100, ccy + 106, 108, 16, "Charged!", "heavy", 13, WOOD_PALE, align="center", scaled=True)
    # actions
    ax = ccx + ccw - 176
    sc.button(ax, ccy + 4, 176, 70, text="ROLL", icon="dice", style="brass", depth=7, size=32)
    sc.text(ax, ccy + 82, 176, 40, "Your turn: roll or play a card", "heavy", 15, WOOD_PALE, align="center", wrap=True)
    # cards
    hand = ["spike", "speed_boost", "shield", "teleporter", "phoenix_potion"]
    armed = {"speed_boost"}
    area_x, area_w = ccx + 214 + 10, ccw - (214 + 176 + 20)
    n = len(hand)
    cwid = min(86, (area_w - (n - 1) * 8) / n, (cch - 18) * 0.72)
    chei = cwid / 0.72
    start = area_x + (area_w - (n * cwid + (n - 1) * 8)) / 2
    painter = CardPainter(data["cards"])
    for i, item in enumerate(hand):
        x = start + i * (cwid + 8)
        y = ccy + (cch - chei) / 2 - (14 if item in armed else 0)
        if item in armed:
            sc.outline(x, y, cwid, chei, cwid * 0.09, BRASS_LIGHT, 4)
        layer = Image.new("RGBA", (int((cwid + 20) * S), int((chei + 20) * S)), (0, 0, 0, 0))
        painter.item_front(layer, 10 * S, 10 * S, cwid * S, item)
        sc.img.alpha_composite(layer, (int((x - 10) * S), int((y - 10) * S)))

    sc.save(out)


# ------------------------------------------------------------------------- lobby
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


def lobby_base(data, searching=True):
    sc = Screen(data)
    sc.table()
    top = 56
    W, H = sc.w, sc.h
    sc.text(28, top - 6, 420, 70, "Trapisque", "display", 60, PARCH, outline=INK, ow=3)
    # profile chip
    px, py, pw, ph = W - 24 - 400, top, 400, 74
    sc.frame(px, py, pw, ph, 14, PARCH, BURN, 3)
    sc.pawn("pawn_ocean", px + 10 + 25, py + 12 + 25, 50, SEAT[1])
    sc.text(px + 70, py + 9, pw - 220, 20, "Rowan", "heavy", 18, TEXT_DARK)
    title = next(i for i in data["cosmetics"]["items"] if i["id"] == "title_hopper")["look"]
    tw = sc.text_width(title["text"], "heavy", 12)
    sc.rect(px + 70, py + 32, tw + 16, 18, 6, "#4E2E14")
    sc.text(px + 78, py + 32, tw + 2, 18, title["text"], "heavy", 12, title["color"])
    sc.text(px + 70, py + 53, 40, 16, "LV 7", "chunky", 14, "#3C6E8F")
    sc.progress(px + 114, py + 57, pw - 264, 8, 0.6, INFO)
    sc.medallion("gem", px + pw - 16 - 12, py + ph / 2, 24, NEUTRAL)
    gw = sc.text_width("1,240", "chunky", 24)
    sc.text(px + pw - 16 - 24 - 6 - gw, py + ph / 2 - 14, gw + 2, 28, "1,240", "chunky", 24, INK)

    bx, by, bw, bh = 24, top + 96, W - 48, H - (top + 96 + 112)
    lw = bw * 0.55 - 12
    rw = bw * 0.45 - 12
    # play panel
    cx, cy, cw, ch = sc.panel(bx, by, lw, bh, title="Play", title_w=200)
    grid_h = ch - 128
    tw_, th_ = (cw - 12) / 2, (grid_h - 12) / 2
    modes = [
        ("chaos", "Chaos Trapisque", "2-6 players", "Free-for-all. First to 5 treasures wins.", "bolt"),
        ("assist", "Assist Trapisque", "4 players", "2 vs 2. A team wins when both teammates have 5 treasures.", "people"),
        ("factions", "Factions", "6 players", "Three teams of 2. Both teammates need 5 treasures.", "people"),
        ("ww4", "World War Four", "6 players", "3 vs 3. Every teammate needs 4 treasures.", "people"),
    ]
    for i, (mid, name, count, blurb, icon) in enumerate(modes):
        tx = cx + (i % 2) * (tw_ + 12)
        ty = cy + (i // 2) * (th_ + 12)
        on = mid == "chaos"
        sc.frame(tx, ty, tw_, th_, 12, "#FFF1C4" if on else PARCH_MID, BRASS_DARK if on else PARCH_EDGE, 3 if on else 2)
        sc.icon(icon, tx + 12, ty + 12, 34, INK, PARCH_MID)
        sc.text(tx + 54, ty + 10, tw_ - 66, 24, name, "chunky", 20, INK, scaled=True)
        sc.text(tx + 54, ty + 34, tw_ - 66, 16, count, "heavy", 13, INK_SOFT)
        sc.text(tx + 12, ty + 58, tw_ - 24, th_ - 64, blurb, "body", 15, TEXT_DARK, wrap=True, valign="top")
    by2 = cy + ch - 116
    if searching:
        sc.button(cx, by2, cw, 58, text="CANCEL SEARCH", icon="close", style="red", depth=6, size=26)
        sc.icon("compass", cx + 6, by2 + 68 + 7, 34, INK, PARCH)
        sc.text(cx + 48, by2 + 68, cw - 50, 48, "Finding a Chaos match  0:23  ·  3 searching", "heavy", 18, TEXT_DARK)
    else:
        sc.button(cx, by2, cw, 58, text="FIND A MATCH", icon="play", style="green", depth=6, size=26)
        sc.button(cx, by2 + 68, cw / 2 - 6, 48, text="PRACTICE", icon="dice", style="wood", size=19)
        sc.button(cx + cw / 2 + 6, by2 + 68, cw / 2 - 6, 48, text="PRIVATE MATCH", icon="people", style="blue", size=19)

    # party panel
    rx = bx + bw - rw
    cx, cy, cw, ch = sc.panel(rx, by, rw, bh, title="Party", title_w=200)
    sc.frame(cx, cy, cw, 64, 10, PARCH_MID, PARCH_EDGE, 2)
    sc.text(cx + 12, cy + 6, cw * 0.55, 18, "PARTY CODE", "heavy", 13, INK_SOFT)
    sc.text(cx + 12, cy + 24, cw * 0.55, 34, "K7QX4M", "chunky", 30, INK)
    sc.choice(cx + cw * 0.58, cy + 13, cw * 0.42 - 10, 38, [("Code", "code"), ("Invite only", "invite")], "code", size=15)
    members = [("Rowan", "pawn_ocean", True), ("Mika", "pawn_mint", False), ("Jojo", "pawn_lava", False)]
    my = cy + 74 + 2
    for i, (name, skin, leader) in enumerate(members):
        mw = cw - 10 - 4
        mx = cx + 2
        sc.frame(mx, my, mw, 44, 10, "#FFF1C4" if i == 0 else "#FBF3DD", PARCH_EDGE, 1.5)
        sc.pawn(skin, mx + 6 + 18, my + 4 + 18, 36, SEAT[i])
        nx = mx + 50
        if leader:
            sc.icon("crown", mx + 50, my + 11, 22, BRASS_DARK, PARCH)
            nx = mx + 78
        sc.text(nx, my, mw - (nx - mx) - 100, 44, name + ("  (you)" if i == 0 else ""), "heavy", 17, TEXT_DARK)
        if i > 0:
            sc.button(mx + mw - 6 - 82, my + 5, 38, 34, icon="crown", style="brass", depth=4, icon_scale=0.66)
            sc.button(mx + mw - 6 - 38, my + 5, 38, 34, icon="close", style="red", depth=4, icon_scale=0.66)
        my += 50
    sc.text(cx, my + 4, cw, 20, "3 more can join", "body", 14, INK_FAINT, align="center")
    sc.button(cx, cy + ch - 48, cw * 0.62 - 6, 48, text="INVITE", icon="plus", style="blue", size=18)
    sc.button(cx + cw * 0.62 + 6, cy + ch - 48, cw * 0.38 - 6, 48, text="LEAVE", icon="exit", style="red", size=18)

    # nav
    nav = [("FREE CHEST!", "chest", "green"), ("LOCKER", "hanger", "wood"), ("SHOP", "bag", "wood"), ("HOW TO PLAY", "book", "wood"),
           ("SETTINGS", "gear", "wood")]
    nw = bw * 0.2 - 12
    total = 5 * nw + 4 * 14
    nx = bx + (bw - total) / 2
    for text, icon, style in nav:
        sc.button(nx, H - 22 - 66, nw, 66, text=text, icon=icon, style=style, size=19)
        nx += nw + 14
    return sc


def lobby_screen(data, out):
    sc = lobby_base(data, searching=True)
    sc.save(out)


def chests_screen(data, out):
    sc = lobby_base(data, searching=False)
    sc.dim(0.55)
    W, H = sc.w, sc.h
    mw, mh = 900, 580
    mx, my = W / 2 - mw / 2, H * 0.52 - mh / 2
    cx, cy, cw, ch = sc.panel(mx, my, mw, mh, title="Treasure Chests", title_w=320)
    sc.button(mx + mw - 14 - 40, my + 14, 40, 42, icon="close", style="red", depth=4, icon_scale=0.66)
    sc.medallion("gem", cx + 18, cy + 20, 36, NEUTRAL)
    sc.text(cx + 44, cy, 200, 40, "1,240", "chunky", 28, INK)
    sc.text(cx + 250, cy, cw - 250, 40, "Gems come from playing matches. Duplicates turn back into Gems.", "heavy", 15, INK_SOFT,
            align="right")
    chests = data["cosmetics"]["chests"]
    pity = ["Epic or better within 7 chests", "Legendary or better within 14 chests"]
    card_w = cw / 2 - 10
    for i, chest in enumerate(chests):
        x = cx + i * (card_w + 20)
        y = cy + 50
        hh = ch - 50
        sc.frame(x, y, card_w, hh, 14, PARCH_MID, PARCH_EDGE, 2)
        chest_art(sc, chest["look"], x + card_w / 2 - 85, y + 6, 170)
        sc.text(x, y + 176, card_w, 30, chest["name"], "chunky", 26, INK, align="center")
        blurb = ["Everything can drop. Great for starting a collection.", "No commons. Much better shot at Legendary and Mythic."][i]
        sc.text(x + 15, y + 206, card_w - 30, 38, blurb, "heavy", 15, INK_SOFT, align="center", wrap=True)
        sc.text(x + 15, y + 246, card_w - 30, 18, pity[i], "heavy", 14, NEUTRAL, align="center")
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
                sc.text(ex + 12, ey, ew - 12 + 2, 16, label, "heavy", 12, INK_SOFT)
                ex += ew + 12
        bw = (card_w - 30) / 2 - 6
        by = y + hh - 50 - 52
        if i == 0:
            sc.button(x + 15, by, bw, 52, text="OPEN FREE", icon="chest", style="green", size=20)
        else:
            sc.button(x + 15, by, bw, 52, text=str(chest["price"]), icon="gem", style="brass", size=20)
        sc.button(x + 15 + bw + 12, by, bw, 52, text="x10  " + format(chest["price"] * 9, ","), icon="gem", style="purple", size=18)
        sc.button(x + card_w / 2 - 70, y + hh - 8 - 36, 140, 36, text="SEE ODDS", style="parchment", size=15)
    sc.save(out)


def main():
    src, outdir = sys.argv[1], sys.argv[2]
    data = {}
    for name in ("icons", "board", "cosmetics", "cards"):
        data[name] = json.load(open(os.path.join(src, name + ".json")))
    data["icons"] = data["icons"]
    data["looks"] = {i["id"]: i["look"] for i in data["cosmetics"]["items"]}
    data["patterns"] = data["cosmetics"]["patterns"]
    match_screen(data, os.path.join(outdir, "07-match-screen.png"))
    lobby_screen(data, os.path.join(outdir, "08-lobby.png"))
    chests_screen(data, os.path.join(outdir, "09-treasure-chests.png"))


if __name__ == "__main__":
    main()
