#!/usr/bin/env python3
"""Preview of the carved wooden cards, fronts and backs (mirrors client/UI/Cards.lua).

Every card is drawn on its own supersampled layer with the same geometry as the
game: flat wood, a carved frame, a painted band, a burned-in symbol and a paper
name strip. UIStrokes sit outside their frame, as they do in Roblox.

Usage: python3 tools/preview/cards.py cards.json out.png
"""
import json
import os
import sys
import textwrap

sys.path.insert(0, os.path.dirname(__file__))
from render import Layer, Canvas, draw_ops, hex_rgba, font  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

CAT = {"trap": "#C2513B", "assist": "#5E9A3C", "neutral": "#7A61A8", "potion": "#D98C1F", "natural": "#3F8C7E"}
CAT_NAME = {"trap": "TRAP", "assist": "ASSIST", "neutral": "NEUTRAL", "potion": "POTION", "natural": "NATURAL"}
CHAR = {"mage": "#5876D6", "trapper": "#A86B39", "fire_starter": "#E2622B", "naturalist": "#4E9A47", "warper": "#8B57CC", "overseer": "#CDA42A"}
POTION_ACC = {"speed_potion": "#4FA3FF", "phoenix_potion": "#FF7B2E", "time_potion": "#B98CFF", "telepathy_potion": "#FF5FA2", "jeopardy_potion": "#5BD18B"}
PARCH = "#F3E4C1"
PARCH_EDGE = "#A97C45"
INK = "#4A3020"
TEXT_DARK = "#3A2414"
INK_FAINT = "#A88B66"
BRASS = "#E3B04B"
BRASS_LIGHT = "#FFE39A"


def rgb(h):
    return hex_rgba(h)[:3]


def shade(h, amt):
    r, g, b = rgb(h)
    if amt >= 0:
        return "#%02X%02X%02X" % (int(r + (255 - r) * amt), int(g + (255 - g) * amt), int(b + (255 - b) * amt))
    a = -amt
    return "#%02X%02X%02X" % (int(r * (1 - a)), int(g * (1 - a)), int(b * (1 - a)))


class Card:
    """One card on its own supersampled layer. Coordinates are card pixels."""

    MARGIN = 6

    def __init__(self, w, aspect, ss=3):
        self.w, self.h = w, w / aspect
        self.aspect = aspect
        m = self.MARGIN
        self.layer = Layer(int(self.w + 2 * m), int(self.h + 2 * m), ss=ss)
        self.ss = ss

    def X(self, v):
        return (v + self.MARGIN) * self.ss

    def draw(self):
        return ImageDraw.Draw(self.layer.img)

    def rrect(self, x0, y0, x1, y1, radius, fill, alpha=255):
        img = self.layer.blank()
        ImageDraw.Draw(img).rounded_rectangle([self.X(x0), self.X(y0), self.X(x1), self.X(y1)], radius=radius * self.ss, fill=hex_rgba(fill, alpha))
        self.layer.paste_shape(img)

    def framed(self, x0, y0, x1, y1, radius, fill, stroke=None, stroke_w=0.0, stroke_alpha=255):
        """A rounded frame with a UIStroke-style border drawn outside its bounds."""
        if stroke and stroke_w > 0:
            self.rrect(x0 - stroke_w, y0 - stroke_w, x1 + stroke_w, y1 + stroke_w, radius + stroke_w, stroke, stroke_alpha)
        if fill:
            self.rrect(x0, y0, x1, y1, radius, fill)

    def outline(self, x0, y0, x1, y1, radius, color, width, alpha=255):
        """Border only (UIStroke on a transparent frame): a ring just outside the bounds."""
        img = self.layer.blank()
        ImageDraw.Draw(img).rounded_rectangle([self.X(x0 - width), self.X(y0 - width), self.X(x1 + width), self.X(y1 + width)],
                                              radius=(radius + width) * self.ss, outline=hex_rgba(color, alpha),
                                              width=max(1, int(round(width * self.ss))))
        self.layer.paste_shape(img)

    def ops(self, ops, x, y, size, colors):
        cv = Canvas(self.layer, x + self.MARGIN, y + self.MARGIN, size, colors)
        draw_ops(cv, ops)

    def text(self, txt, kind, box, color, max_size, align="center", valign="center", wrap=False, min_size=6, dy=0.0):
        """TextScaled-style fitting: the biggest size (up to max_size) that fits the box."""
        x0, y0, x1, y1 = box
        bw, bh = (x1 - x0) * self.ss, (y1 - y0) * self.ss
        d = self.draw()
        size = max_size * self.ss
        while True:
            f = font(kind, size)
            if wrap:
                avg = d.textbbox((0, 0), "abcdefghijklmnopqrstuvwxyz", font=f)
                cpl = max(4, int(bw / ((avg[2] - avg[0]) / 26)))
                lines = textwrap.wrap(txt, cpl) or [""]
            else:
                lines = [txt]
            line_h = size * 1.18
            widest = max(d.textbbox((0, 0), ln, font=f)[2] for ln in lines)
            if (widest <= bw and line_h * len(lines) <= bh * 1.02) or size <= min_size * self.ss:
                break
            size -= max(1, self.ss // 2)
        total = line_h * len(lines)
        ty = self.X(y0) + (bh - total) / 2 if valign == "center" else self.X(y0)
        for ln in lines:
            bb = d.textbbox((0, 0), ln, font=f)
            tw = bb[2] - bb[0]
            if align == "center":
                tx = self.X(x0) + (bw - tw) / 2 - bb[0]
            else:
                tx = self.X(x0) - bb[0]
            asc, desc = f.getmetrics()
            d.text((tx, ty + (line_h - (asc + desc)) / 2 + dy * self.ss), ln, font=f, fill=hex_rgba(color))
            ty += line_h

    def paste(self, img, x, y):
        out = self.layer.final()
        img.alpha_composite(out, (int(x - self.MARGIN), int(y - self.MARGIN)))


class CardPainter:
    def __init__(self, data):
        self.icons = data["icons"]
        self.style = data["style"]
        self.items = {i["id"]: i for i in data["items"]}
        self.chars = {c["id"]: c for c in data["characters"]}

    # The wooden slab (Cards.lua slab)
    def slab(self, card, kind, darker=0.0):
        S = self.style
        w, h = card.w, card.h
        top, bottom = S["wood"][kind]
        top, bottom = shade(top, -darker), shade(bottom, -darker)
        card.framed(0, 0, w, h, S["corner"] * w, top, shade(bottom, -0.5), 0.012 * w)
        grain = shade(bottom, -0.25)
        cv = Canvas(card.layer, card.MARGIN, card.MARGIN, w, {"ink": hex_rgba(grain, int(255 * 0.32))})
        for pts in S["grain"]:
            cv.taper([[p[0], p[1] / S["aspect"]] for p in pts], 0.012, 0.006, "ink", steps=3)
        f = S["frameInset"] * w
        fw = w - 2 * f
        card.outline(f, f, w - f, h - f, S["corner"] * 0.7 * fw, shade(bottom, -0.35), 0.012 * fw, alpha=int(255 * 0.6))
        return top

    def band(self, card, color, label):
        B = self.style["band"]
        w, h = card.w, card.h
        x0, y0 = B["inset"] * w, B["y"] * h
        x1, y1 = w - B["inset"] * w, y0 + B["h"] * h
        bh = y1 - y0
        card.framed(x0, y0, x1, y1, 0.25 * bh, color, shade(color, -0.45), 0.06 * bh)
        bw = x1 - x0
        box = (x0 + bw * 0.1, y0 + bh * 0.17, x1 - bw * 0.1, y1 - bh * 0.17)
        off = 2 * w / 120
        card.text(label, "chunky", box, shade(color, -0.55), 40, dy=off)
        card.text(label, "chunky", box, "#FFF8EA", 40)

    def plate(self, card, name):
        P = self.style["plate"]
        w, h = card.w, card.h
        x0, y0 = P["x"] * w, P["y"] * h
        x1, y1 = x0 + P["w"] * w, y0 + P["h"] * h
        ph = y1 - y0
        card.framed(x0, y0, x1, y1, 0.2 * ph, PARCH, PARCH_EDGE, 0.04 * ph)
        pw = x1 - x0
        card.text(name, "display", (x0 + pw * 0.04, y0 + ph * 0.11, x1 - pw * 0.04, y1 - ph * 0.11), INK,
                  self.style["text"]["plate"] * w, min_size=8)

    def item_front(self, img, x, y, w, item_id):
        it = self.items[item_id]
        S = self.style
        card = Card(w, S["aspect"])
        wood = self.slab(card, it["category"])
        I = S["icon"]
        size = I["size"] * w
        burn = shade(wood, -0.62)
        acc = POTION_ACC.get(item_id, burn)
        colors = {"ink": hex_rgba(burn), "bg": hex_rgba(wood), "acc": hex_rgba(acc), "acc2": hex_rgba(acc), "hi": hex_rgba(wood)}
        card.ops(self.icons[item_id], I["cx"] * w - size / 2, I["cy"] * card.h - size / 2, size, colors)
        self.band(card, CAT[it["category"]], CAT_NAME[it["category"]])
        self.plate(card, it["name"])
        card.paste(img, x, y)

    def char_front(self, img, x, y, w, cid):
        c = self.chars[cid]
        S = self.style
        col = CHAR[cid]
        card = Card(w, S["aspect"])
        self.slab(card, "character")
        d = 0.62 * w
        cx, cy = w / 2, S["icon"]["cy"] * card.h
        sw = 0.08 * d
        card.framed(cx - d / 2, cy - d / 2, cx + d / 2, cy + d / 2, d / 2, col, BRASS, sw)
        g = 0.64 * d
        colors = {"ink": hex_rgba("#FFFFFF"), "bg": hex_rgba(col), "acc": hex_rgba(BRASS_LIGHT), "acc2": hex_rgba(BRASS_LIGHT), "hi": hex_rgba(col)}
        card.ops(self.icons[cid], cx - g / 2, cy - g / 2, g, colors)
        self.band(card, col, c["name"].upper())
        ab = c.get("ability")
        self.plate(card, ab["name"] if ab else "Nature's Path")
        card.paste(img, x, y)

    # Parchment back (Cards.lua backFace)
    def back(self, img, x, y, w, kind, title, tag, tag_color, sections, footer):
        S = self.style
        card = Card(w, S["aspect"])
        h = card.h
        self.slab(card, kind, darker=0.15)
        i = 0.07 * w
        px0, py0, px1, py1 = i, i, w - i, h - i
        pw, ph = px1 - px0, py1 - py0
        card.framed(px0, py0, px1, py1, 0.06 * pw, PARCH, PARCH_EDGE, 0.012 * pw)
        pad = 6 * w / 180
        lx0, ly0, lx1, ly1 = px0 + pad, py0 + pad, px1 - pad, py1 - pad
        lw, lh = lx1 - lx0, ly1 - ly0
        gap = 0.012 * lh
        T = S["text"]
        yy = ly0
        card.text(title, "display", (lx0, yy, lx1, yy + 0.11 * lh), INK, T["title"] * w, min_size=8)
        yy += 0.11 * lh + gap
        card.text(tag, "chunky", (lx0, yy, lx1, yy + 0.05 * lh), tag_color, T["tag"] * w)
        yy += 0.05 * lh + gap
        card.rrect(lx0 + lw * 0.05, yy, lx1 - lw * 0.05, yy + 2 * w / 180, 1, INK_FAINT, alpha=int(255 * 0.7))
        yy += 2 * w / 180 + gap
        sx0, sx1 = lx0 + lw * 0.03, lx1 - lw * 0.03
        for head, body, frac in sections:
            if head:
                card.text(head, "chunky", (sx0, yy, sx1, yy + 0.05 * lh), tag_color, T["header"] * w, align="left")
                yy += 0.05 * lh + gap
            card.text(body, "body", (sx0, yy, sx1, yy + frac * lh), TEXT_DARK, T["body"] * w, align="left", valign="top",
                      wrap=True, min_size=7)
            yy += frac * lh + gap
        if footer:
            fy1 = py0 + 0.97 * ph
            fy0 = fy1 - 0.08 * ph
            fx0, fx1 = px0 + 0.04 * pw, px1 - 0.04 * pw
            card.rrect(fx0, fy0, fx1, fy1, 0.4 * (fy1 - fy0), shade(tag_color, 0.75))
            fw_, fh_ = fx1 - fx0, fy1 - fy0
            card.text(footer, "body", (fx0 + fw_ * 0.03, fy0 + fh_ * 0.1, fx1 - fw_ * 0.03, fy1 - fh_ * 0.1), shade(tag_color, -0.45),
                      T["footer"] * w)
        card.paste(img, x, y)

    def item_back(self, img, x, y, w, item_id):
        it = self.items[item_id]
        cat = it["category"]
        footer = self.style["useText"].get(it["use"], "")
        if it.get("price"):
            footer = "%d coin%s at the Potion Seller" % (it["price"], "" if it["price"] == 1 else "s")
        tag = CAT_NAME[cat] + (" CARD" if cat != "potion" else "")
        self.back(img, x, y, w, cat, it["name"], tag, CAT[cat], [("", it["text"], 0.52)], footer)

    def char_back(self, img, x, y, w, cid):
        c = self.chars[cid]
        ab = c.get("ability")
        sections = [("PASSIVE", c["passive"], 0.25 if ab else 0.6)]
        if ab:
            recharge = {"cycles": "Recharges after cycles.", "rounds": "Recharges after rounds.", "once": "Once per game.",
                        "perTurn": "Every turn."}.get(ab.get("recharge"), "")
            sections.append(("ABILITY: " + ab["name"].upper(), ab["text"] + " " + recharge, 0.3))
        self.back(img, x, y, w, "character", c["name"], c["tagline"], CHAR[cid], sections, None)


def main():
    data = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    p = CardPainter(data)
    cw = 180
    ch = cw / data["style"]["aspect"]
    gap = 26
    items = ["spike", "fire", "grog", "shield", "speed_boost", "teleporter", "spore_warper", "phoenix_potion", "river_trap"]
    W = int(gap + len(items) * (cw + gap))
    H = int(90 + 3 * (ch + 60) + 40)
    img = Image.new("RGBA", (W, H), hex_rgba("#2A1C13"))
    d = ImageDraw.Draw(img)
    for i in range(0, H, 90):
        d.line([(0, i), (W, i)], fill=hex_rgba("#221710"), width=3)
    d.text((gap, 20), "Wooden cards: front, back (tap a card to flip it) and character cards", font=font("display", 32), fill=hex_rgba("#FFE39A"))
    y = 90
    for k, item in enumerate(items):
        p.item_front(img, gap + k * (cw + gap), y, cw, item)
    y += ch + 60
    for k, item in enumerate(items):
        p.item_back(img, gap + k * (cw + gap), y, cw, item)
    y += ch + 60
    chars = ["mage", "trapper", "fire_starter", "naturalist", "warper", "overseer"]
    for k, cid in enumerate(chars):
        p.char_front(img, gap + k * (cw + gap), y, cw, cid)
    for k, cid in enumerate(["mage", "overseer", "naturalist"]):
        p.char_back(img, gap + (6 + k) * (cw + gap), y, cw, cid)
    img.convert("RGB").save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main()
