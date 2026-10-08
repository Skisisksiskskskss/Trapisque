#!/usr/bin/env python3
"""Preview of the carved wooden cards, fronts and backs (mirrors client/UI/Cards.lua).

Usage: python3 tools/preview/cards.py cards.json out.png
"""
import json
import os
import sys
import textwrap

sys.path.insert(0, os.path.dirname(__file__))
from render import Layer, Canvas, draw_ops, hex_rgba, font  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

CAT = {"trap": "#C2513B", "assist": "#5E9A3C", "neutral": "#7A61A8", "potion": "#D98C1F", "natural": "#3F8C7E"}
CAT_NAME = {"trap": "TRAP", "assist": "ASSIST", "neutral": "NEUTRAL", "potion": "POTION", "natural": "NATURAL"}
CAT_GLYPH = {"trap": "token_trap", "assist": "token_assist", "neutral": "token_neutral", "potion": "token_potion", "natural": "river_trap"}
CHAR = {"mage": "#5876D6", "trapper": "#A86B39", "fire_starter": "#E2622B", "naturalist": "#4E9A47", "warper": "#8B57CC", "overseer": "#CDA42A"}
POTION_ACC = {"speed_potion": "#4FA3FF", "phoenix_potion": "#FF7B2E", "time_potion": "#B98CFF", "telepathy_potion": "#FF5FA2", "jeopardy_potion": "#5BD18B"}
PARCH = "#F3E4C1"
INK = "#4A3020"


def rgb(h):
    return hex_rgba(h)[:3]


def shade(h, amt):
    r, g, b = rgb(h)
    if amt >= 0:
        return "#%02X%02X%02X" % (int(r + (255 - r) * amt), int(g + (255 - g) * amt), int(b + (255 - b) * amt))
    a = -amt
    return "#%02X%02X%02X" % (int(r * (1 - a)), int(g * (1 - a)), int(b * (1 - a)))


def vgrad(w, h, top, bot):
    img = Image.new("RGBA", (w, h))
    t, b = rgb(top), rgb(bot)
    d = ImageDraw.Draw(img)
    for y in range(h):
        f = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(t[i] + (b[i] - t[i]) * f) for i in range(3)) + (255,))
    return img


def text_fit(d, txt, kind, box_w, box_h, start):
    size = start
    f = font(kind, size)
    bb = d.textbbox((0, 0), txt, font=f)
    while (bb[2] - bb[0] > box_w or bb[3] - bb[1] > box_h) and size > 6:
        size -= 1
        f = font(kind, size)
        bb = d.textbbox((0, 0), txt, font=f)
    return f, bb


class CardPainter:
    def __init__(self, data):
        self.icons = data["icons"]
        self.style = data["style"]
        self.items = {i["id"]: i for i in data["items"]}
        self.chars = {c["id"]: c for c in data["characters"]}

    def body(self, img, x, y, w, h, tones, darker=0.0):
        S = self.style
        ss = 3
        W, H = int(w * ss), int(h * ss)
        lay = Image.new("RGBA", (W + 40 * ss, H + 40 * ss), (0, 0, 0, 0))
        o = 20 * ss
        rad = S["corner"] * W
        # shadow
        sh = Image.new("RGBA", lay.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([o + 4 * ss, o + 8 * ss, o + W + 4 * ss, o + H + 8 * ss], radius=rad, fill=(0, 0, 0, 130))
        lay = Image.alpha_composite(lay, sh.filter(ImageFilter.GaussianBlur(7 * ss)))
        top, bot = shade(tones[0], -darker), shade(tones[1], -darker)
        grad = vgrad(W, H, shade(top, 0.06), bot)
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], radius=rad, fill=255)
        lay.paste(grad, (o, o), mask)
        # grain
        sub = Layer(lay.width // ss, lay.height // ss, ss=ss)
        sub.img = lay
        grain_col = hex_rgba(shade(bot, -0.25), 80)
        cv = Canvas(sub, o / ss, o / ss, w, {"ink": grain_col})
        for pts in S["grain"]:
            cv.taper([[p[0], p[1] / S["aspect"]] for p in pts], 0.012, 0.006, "ink")
        k = S["knot"]
        cv.oring(k["cx"], k["cy"] / S["aspect"], k["w"], k["h"], 0.01, "ink")
        lay = sub.img
        d = ImageDraw.Draw(lay)
        # carved inner frame
        i = 0.045 * W
        d.rounded_rectangle([o + i, o + i, o + W - i, o + H - i], radius=rad * 0.7, outline=hex_rgba(shade(bot, -0.35), 150), width=max(2, int(0.012 * W)))
        i2 = i + 0.014 * W
        d.rounded_rectangle([o + i2, o + i2, o + W - i2, o + H - i2], radius=rad * 0.6, outline=hex_rgba(shade(top, 0.35), 80), width=max(1, int(0.006 * W)))
        d.rounded_rectangle([o, o, o + W - 1, o + H - 1], radius=rad, outline=hex_rgba(shade(bot, -0.5), 255), width=max(2, int(0.012 * W)))
        out = lay.resize((lay.width // ss, lay.height // ss), Image.LANCZOS)
        img.alpha_composite(out, (int(x - 20), int(y - 20)))

    def engraved(self, img, ops, cx, cy, size, wood, accent=None):
        box = int(size * 1.4)
        lay = Layer(box, box, ss=4)
        m = (box - size) / 2
        hi = {"ink": hex_rgba(shade(wood, 0.45)), "bg": hex_rgba(wood), "acc": hex_rgba(shade(wood, 0.45)), "acc2": hex_rgba(shade(wood, 0.45)), "hi": hex_rgba(wood)}
        dk_col = shade(wood, -0.62)
        dk = {"ink": hex_rgba(dk_col), "bg": hex_rgba(wood), "acc": hex_rgba(accent or dk_col), "acc2": hex_rgba(accent or dk_col), "hi": hex_rgba(shade(wood, 0.25))}
        draw_ops(Canvas(lay, m, m + size * 0.03, size, hi), ops)
        draw_ops(Canvas(lay, m, m, size, dk), ops)
        img.alpha_composite(lay.final(), (int(cx - box / 2), int(cy - box / 2)))

    def flat(self, img, ops, cx, cy, size, colors):
        box = int(size * 1.4)
        lay = Layer(box, box, ss=4)
        m = (box - size) / 2
        draw_ops(Canvas(lay, m, m, size, colors), ops)
        img.alpha_composite(lay.final(), (int(cx - box / 2), int(cy - box / 2)))

    def nails(self, img, x, y, w, h):
        d = ImageDraw.Draw(img)
        for nx, ny in self.style["nails"]:
            cx, cy = x + nx * w, y + ny * w / self.style["aspect"] * self.style["aspect"]
            cy = y + ny * h
            r = w * 0.035
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hex_rgba("#9E7425"))
            d.ellipse([cx - r * 0.75, cy - r * 0.8, cx + r * 0.6, cy + r * 0.55], fill=hex_rgba("#E3B04B"))
            d.ellipse([cx - r * 0.45, cy - r * 0.55, cx - r * 0.05, cy - r * 0.15], fill=hex_rgba("#FFE39A"))

    def band(self, img, x, y, w, h, color, label, glyph):
        S = self.style["band"]
        d = ImageDraw.Draw(img)
        bx0, by0 = x + S["inset"] * w, y + S["y"] * h
        bx1, by1 = x + w - S["inset"] * w, by0 + S["h"] * h
        d.rounded_rectangle([bx0, by0 + 2, bx1, by1 + 2], radius=w * 0.035, fill=hex_rgba(shade(color, -0.4)))
        d.rounded_rectangle([bx0, by0, bx1, by1], radius=w * 0.035, fill=hex_rgba(color))
        d.rounded_rectangle([bx0 + 3, by0 + 2, bx1 - 3, by0 + (by1 - by0) * 0.22], radius=w * 0.02, fill=hex_rgba("#FFFFFF", 30))
        f, bb = text_fit(d, label, "chunky", (bx1 - bx0) * 0.66, (by1 - by0) * 0.6, int(h * 0.072))
        tx = (bx0 + bx1) / 2 - (bb[2] - bb[0]) / 2 - bb[0]
        ty = (by0 + by1) / 2 - (bb[3] - bb[1]) / 2 - bb[1] + 1
        d.text((tx, ty + 2), label, font=f, fill=hex_rgba(shade(color, -0.5)))
        d.text((tx, ty), label, font=f, fill=hex_rgba("#FFF8EA"))

    def plate(self, img, x, y, w, h, name):
        P = self.style["plate"]
        d = ImageDraw.Draw(img)
        px0, py0 = x + P["x"] * w, y + P["y"] * h
        px1, py1 = px0 + P["w"] * w, py0 + P["h"] * h
        d.rounded_rectangle([px0 + 1, py0 + 3, px1 + 1, py1 + 3], radius=w * 0.03, fill=(40, 20, 8, 90))
        d.rounded_rectangle([px0, py0, px1, py1], radius=w * 0.03, fill=hex_rgba(PARCH), outline=hex_rgba("#A97C45"), width=max(1, int(w * 0.01)))
        f, bb = text_fit(d, name, "display", (px1 - px0) * 0.9, (py1 - py0) * 0.7, int(h * 0.09))
        d.text(((px0 + px1) / 2 - (bb[2] - bb[0]) / 2 - bb[0], (py0 + py1) / 2 - (bb[3] - bb[1]) / 2 - bb[1]), name, font=f, fill=hex_rgba(INK))

    def item_front(self, img, x, y, w, item_id):
        it = self.items[item_id]
        S = self.style
        h = w / S["aspect"]
        tones = S["wood"][it["category"]]
        self.body(img, x, y, w, h, tones)
        mid = shade(tones[0], 0.0)
        I = S["icon"]
        self.engraved(img, self.icons[item_id], x + I["cx"] * w, y + I["cy"] * h, I["size"] * w, mid, accent=POTION_ACC.get(item_id))
        self.band(img, x, y, w, h, CAT[it["category"]], CAT_NAME[it["category"]], CAT_GLYPH[it["category"]])
        self.nails(img, x, y, w, h)
        self.plate(img, x, y, w, h, it["name"])

    def item_back(self, img, x, y, w, item_id):
        it = self.items[item_id]
        S = self.style
        h = w / S["aspect"]
        tones = S["wood"][it["category"]]
        self.body(img, x, y, w, h, tones, darker=0.15)
        d = ImageDraw.Draw(img)
        i = 0.07 * w
        px0, py0, px1, py1 = x + i, y + i, x + w - i, y + h - i
        d.rounded_rectangle([px0, py0 + 2, px1, py1 + 2], radius=w * 0.05, fill=(30, 15, 5, 90))
        d.rounded_rectangle([px0, py0, px1, py1], radius=w * 0.05, fill=hex_rgba(PARCH), outline=hex_rgba("#A97C45"), width=2)
        pw = px1 - px0
        # title
        f, bb = text_fit(d, it["name"], "display", pw * 0.86, h * 0.09, int(h * 0.085))
        d.text(((px0 + px1) / 2 - (bb[2] - bb[0]) / 2 - bb[0], py0 + h * 0.035 - bb[1]), it["name"], font=f, fill=hex_rgba(INK))
        tag = CAT_NAME[it["category"]] + (" CARD" if it["category"] != "potion" else "")
        f2 = font("chunky", int(h * 0.04))
        bb = d.textbbox((0, 0), tag, font=f2)
        d.text(((px0 + px1) / 2 - (bb[2] - bb[0]) / 2 - bb[0], py0 + h * 0.135 - bb[1]), tag, font=f2, fill=hex_rgba(CAT[it["category"]]))
        ly = py0 + h * 0.2
        d.line([(px0 + pw * 0.12, ly), (px1 - pw * 0.12, ly)], fill=hex_rgba("#A88B66"), width=2)
        # description
        size = h * 0.05
        while True:
            fb = font("body", int(size))
            avg = d.textbbox((0, 0), "abcdefghij", font=fb)
            cpl = max(10, int(pw * 0.86 / ((avg[2] - avg[0]) / 10)))
            lines = textwrap.wrap(it["text"], cpl)
            if len(lines) * size * 1.24 <= h * 0.5 or size < 8:
                break
            size -= 0.5
        ty = ly + h * 0.03
        for ln in lines:
            d.text((px0 + pw * 0.07, ty), ln, font=fb, fill=hex_rgba("#3A2414"))
            ty += size * 1.24
        # usage footer
        use = self.style["useText"].get(it["use"], "")
        if it.get("price"):
            use = "%d coins at the Potion Seller" % it["price"]
        fu = font("body", int(h * 0.042))
        bb = d.textbbox((0, 0), use, font=fu)
        if bb[2] - bb[0] > pw * 0.9:
            fu = font("body", int(h * 0.042 * pw * 0.9 / (bb[2] - bb[0])))
            bb = d.textbbox((0, 0), use, font=fu)
        fy = py1 - h * 0.08
        d.rounded_rectangle([px0 + pw * 0.05, fy - h * 0.012, px1 - pw * 0.05, fy + h * 0.055], radius=8, fill=hex_rgba(shade(CAT[it["category"]], 0.75)))
        d.text(((px0 + px1) / 2 - (bb[2] - bb[0]) / 2 - bb[0], fy + h * 0.02 - (bb[3] - bb[1]) / 2 - bb[1]), use, font=fu, fill=hex_rgba(shade(CAT[it["category"]], -0.45)))

    def char_front(self, img, x, y, w, cid):
        c = self.chars[cid]
        S = self.style
        h = w / S["aspect"]
        col = CHAR[cid]
        self.body(img, x, y, w, h, S["wood"]["character"])
        d = ImageDraw.Draw(img)
        # big medallion portrait
        cx, cy, r = x + w / 2, y + h * 0.43, w * 0.33
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse([cx - r * 1.25, cy - r * 1.25, cx + r * 1.25, cy + r * 1.25], fill=hex_rgba(col, 120))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(12)))
        d = ImageDraw.Draw(img)
        d.ellipse([cx - r - 3, cy - r + 3, cx + r + 3, cy + r + 6], fill=(30, 15, 5, 110))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hex_rgba(col), outline=hex_rgba("#E3B04B"), width=max(3, int(w * 0.03)))
        d.ellipse([cx - r * 0.86, cy - r * 0.86, cx + r * 0.86, cy + r * 0.86], outline=hex_rgba(shade(col, 0.35), 160), width=2)
        d.chord([cx - r * 0.8, cy - r * 0.86, cx + r * 0.6, cy + r * 0.1], 180, 300, fill=hex_rgba("#FFFFFF", 40))
        self.flat(img, self.icons[cid], cx, cy, r * 1.25, {"ink": hex_rgba("#FFFFFF"), "bg": hex_rgba(col), "acc": hex_rgba("#FFFFFF"), "hi": hex_rgba(col)})
        self.band(img, x, y, w, h, col, c["name"].upper(), cid)
        self.nails(img, x, y, w, h)
        ab = c.get("ability")
        self.plate(img, x, y, w, h, ab["name"] if ab else "Nature's Path")

    def char_back(self, img, x, y, w, cid):
        c = self.chars[cid]
        S = self.style
        h = w / S["aspect"]
        col = CHAR[cid]
        self.body(img, x, y, w, h, S["wood"]["character"], darker=0.15)
        d = ImageDraw.Draw(img)
        i = 0.07 * w
        px0, py0, px1, py1 = x + i, y + i, x + w - i, y + h - i
        pw = px1 - px0
        d.rounded_rectangle([px0, py0, px1, py1], radius=w * 0.05, fill=hex_rgba(PARCH), outline=hex_rgba("#A97C45"), width=2)
        f, bb = text_fit(d, c["name"], "display", pw * 0.86, h * 0.09, int(h * 0.085))
        d.text(((px0 + px1) / 2 - (bb[2] - bb[0]) / 2 - bb[0], py0 + h * 0.03 - bb[1]), c["name"], font=f, fill=hex_rgba(INK))
        f2, bb = text_fit(d, c["tagline"], "body", pw * 0.92, h * 0.05, int(h * 0.04))
        d.text(((px0 + px1) / 2 - (bb[2] - bb[0]) / 2 - bb[0], py0 + h * 0.13 - bb[1]), c["tagline"], font=f2, fill=hex_rgba("#7B5B3E"))
        ab = c.get("ability")
        sections = [("PASSIVE", c["passive"])]
        if ab:
            sections.append(("ABILITY: " + ab["name"].upper(), ab["text"]))
        size = h * 0.046
        while True:
            fb = font("body", int(size))
            avg = d.textbbox((0, 0), "abcdefghij", font=fb)
            cpl = max(10, int(pw * 0.86 / ((avg[2] - avg[0]) / 10)))
            total = sum(len(textwrap.wrap(b, cpl)) for _, b in sections) * size * 1.2 + len(sections) * h * 0.085
            if total <= h * 0.68 or size < 8:
                break
            size -= 0.5
        fh = font("chunky", int(h * 0.042))
        ty = py0 + h * 0.2
        for head, body in sections:
            d.text((px0 + pw * 0.07, ty), head, font=fh, fill=hex_rgba(col))
            ty += h * 0.06
            for ln in textwrap.wrap(body, cpl):
                d.text((px0 + pw * 0.07, ty), ln, font=fb, fill=hex_rgba("#3A2414"))
                ty += size * 1.2
            ty += h * 0.025


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
    d.text((gap, 20), "Carved wooden cards: front, back (tap a card to flip it) and character cards", font=font("display", 32), fill=hex_rgba("#FFE39A"))
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
    p.char_back(img, gap + 6 * (cw + gap), y, cw, "mage")
    p.char_back(img, gap + 7 * (cw + gap), y, cw, "overseer")
    p.char_back(img, gap + 8 * (cw + gap), y, cw, "naturalist")
    img.convert("RGB").save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main()
