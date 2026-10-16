#!/usr/bin/env python3
"""The sticker cards, fronts and backs, drawn the way client/UI/Cards.lua builds them
(developer preview tool).

Front: a candy slab in the card's category colour (a darker lip under the face, both
with the line outline, CardStyle.outline of the width), the category name along the
top, the art (StickerArt) in a cream window with a soft spotlight of the card's colour,
and the name in outlined lettering along the bottom. Back: the same slab with cream
paper on it: the name, a tag line, a divider, the rules and a pill saying how it's
played. Character cards show their mascot and ability. Text sizes are fractions of
the card's width and step down only when a line doesn't fit (Cards.lua cardText).

Usage: python3 tools/preview/cards.py cards.json out.png
       (cards.json from tests/dump_cards.luau, bundled after tests/preview_skins.luau)
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from screens import Stage, WHITE, BLACK, mix, background, get_font  # noqa: E402

# Cards.lua CATEGORY_LABEL
CATEGORY_LABEL = {"trap": "TRAP", "assist": "ASSIST", "neutral": "BOARD PIECE", "potion": "POTION", "coin": "COIN"}


class CardPainter:
    def __init__(self, data):
        self.data = data
        self.S = data["style"]
        self.items = {i["id"]: i for i in data["items"]}
        self.chars = {c["id"]: c for c in data["characters"]}
        self.theme = data["theme"]
        self.C = data["theme"]["C"]

    # Cards.lua cardText: floor(width * frac), down a pixel at a time until it fits
    def fit_text(self, st, text, kind, w, frac, minsize, box_w, box_h, wrap=False):
        size = max(minsize, math.floor(w * frac))
        while size > minsize:
            if not wrap:
                if st.text_size(text, kind, size) <= box_w + 0.01 and size <= box_h + 0.01:
                    break
            else:
                lines = self.wrap_count(st, text, kind, size, box_w)
                if lines * size <= box_h + 0.01:
                    break
            size -= 1
        return size

    def wrap_count(self, st, text, kind, size, box_w):
        """How many lines the label wraps `text` into (the Stage's own wrapping)."""
        f = get_font(kind, st.L(size))
        return len(st._wrap([(text, WHITE)], f, st.L(box_w), f.getlength(" ")))

    def slab(self, st, x, y, w, h, color):
        """The lip (darker, full height) and the face (1 - lip tall), both outlined."""
        S, C = self.S, self.C
        ol = S["outline"] * w
        st.rect(x, y, w, h, mix(color, BLACK, 0.4), corner=S["corner"], stroke=(C["line"], ol))
        fh = h * (1 - S["lip"])
        st.rect(x, y, w, fh, color, corner=S["corner"], stroke=(C["line"], ol))
        return fh

    def front(self, st, x, y, w, color, tag, art, name):
        S, C = self.S, self.C
        h = w / S["aspect"]
        fh = self.slab(st, x, y, w, h, color)
        # category tag along the top
        T = S["tag"]
        bw, bh = 0.86 * w, T["h"] * fh
        size = self.fit_text(st, tag, "chunky", w, S["text"]["tag"], 6, bw, bh)
        st.label(x + w / 2 - bw / 2, y + T["y"] * fh - bh / 2, bw, bh, tag, "chunky", size, WHITE, align="center",
                 outline=C["line"], outline_t=max(1, w * 0.014))
        # the cream window, its spotlight, the art
        W = S["window"]
        wx, wy, ww, wh = x + W["x"] * w, y + W["y"] * fh, W["w"] * w, W["h"] * fh
        st.rect(wx, wy, ww, wh, C["cream"], corner=W["corner"], stroke=(C["line"], 0.025 * min(ww, wh)))
        st.circle(wx + ww / 2, wy + wh / 2, 0.86 * ww, color, alpha=0.2)
        if art:
            I = S["icon"]
            st.sticker(art, x + I["cx"] * w, y + I["cy"] * fh, I["size"] * w, outline=0.045)
        # the name
        N = S["name"]
        bw, bh = 0.9 * w, N["h"] * fh
        text = name.upper()
        size = self.fit_text(st, text, "chunky", w, S["text"]["name"], 8, bw, bh)
        st.label(x + w / 2 - bw / 2, y + N["y"] * fh - bh / 2, bw, bh, text, "chunky", size, WHITE, align="center",
                 outline=C["line"], outline_t=max(1, w * 0.02))

    def back(self, st, x, y, w, color, title, tag, sections, footer):
        """Cards.lua backFace: cream paper with the rules, a list (6 px padding, 1.2%
        gaps) of title, tag, divider and sections, and the footer pill."""
        S, C = self.S, self.C
        T = S["text"]
        h = w / S["aspect"]
        fh = self.slab(st, x, y, w, h, color)
        pw, ph = 0.86 * w, (1 - 0.14 * S["aspect"]) * fh
        px, py = x + w / 2 - pw / 2, y + fh / 2 - ph / 2
        st.rect(px, py, pw, ph, C["cream"], corner=0.07, stroke=(C["line"], 0.02 * min(pw, ph)))
        lx, ly, lw, lh = px + 6, py + 6, pw - 12, ph - 12
        gap = 0.012 * lh
        dark = mix(color, BLACK, 0.25)
        yy = ly
        # title
        bh = 0.11 * lh
        t = title.upper()
        size = self.fit_text(st, t, "chunky", w, T["title"], 8, lw, bh)
        st.label(lx, yy, lw, bh, t, "chunky", size, C["line"], align="center")
        yy += bh + gap
        # tag
        bh = 0.055 * lh
        size = self.fit_text(st, tag, "chunky", w, T["header"], 6, lw, bh)
        st.label(lx, yy, lw, bh, tag, "chunky", size, dark, align="center")
        yy += bh + gap
        # divider
        st.rect(lx + 0.05 * lw, yy, 0.9 * lw, 2, color, corner=1, alpha=0.8)
        yy += 2 + gap
        n = len(sections)
        for head, body, frac in sections:
            sw = 0.94 * lw
            sx = lx + (lw - sw) / 2
            if head:
                bh = 0.055 * lh
                size = self.fit_text(st, head, "chunky", w, T["header"], 6, sw, bh)
                st.label(sx, yy, sw, bh, head, "chunky", size, dark, align="left")
                yy += bh + gap
            fr = frac if frac is not None else (0.27 if n > 1 else 0.52)
            bh = fr * lh
            size = self.fit_text(st, body, "heavy", w, T["body"], 7, sw, bh, wrap=True)
            st.label(sx, yy, sw, bh, body, "heavy", size, C["line"], align="left", valign="top", wrap=True)
            yy += bh + gap
        if footer:
            fw, fhh = 0.94 * pw, 0.09 * ph
            fx, fy = px + pw / 2 - fw / 2, py + 0.97 * ph - fhh
            st.rect(fx, fy, fw, fhh, color, corner=0.5, stroke=(C["line"], 0.04 * min(fw, fhh)))
            bw, bhh = 0.94 * fw, 0.8 * fhh
            size = self.fit_text(st, footer, "heavy", w, T["footer"], 6, bw, bhh)
            st.label(fx + fw / 2 - bw / 2, fy + fhh / 2 - bhh / 2, bw, bhh, footer, "heavy", size, WHITE, align="center",
                     outline=C["line"], outline_t=max(1, w * 0.01))

    # ---- Cards.item / Cards.character ----------------------------------------------
    def item_front(self, st, x, y, w, item_id):
        it = self.items[item_id]
        color = self.theme["Category"].get(it["category"], self.C["panelHi"])
        self.front(st, x, y, w, color, CATEGORY_LABEL.get(it["category"], ""), self.data["art"].get(item_id), it["name"])

    def item_back(self, st, x, y, w, item_id):
        it = self.items[item_id]
        cat = it["category"]
        color = self.theme["Category"].get(cat, self.C["panelHi"])
        tag = CATEGORY_LABEL.get(cat, "") + (" · HIDDEN" if cat == "trap" and it["hidden"] else "")
        self.back(st, x, y, w, color, it["name"], tag, [("", it["text"], None)], it["how"])

    def char_front(self, st, x, y, w, cid):
        c = self.chars[cid]
        color = self.theme["Character"].get(cid, self.C["panelHi"])
        ab = c.get("ability")
        self.front(st, x, y, w, color, ab["name"].upper() if ab else "", self.data["mascots"][cid], c["name"])

    def char_back(self, st, x, y, w, cid):
        c = self.chars[cid]
        color = self.theme["Character"].get(cid, self.C["panelHi"])
        sections = [((c.get("passiveName") or "Passive").upper(), c["passive"], 0.24)]
        ab = c.get("ability")
        if ab:
            sections.append(("%s · %d POWER" % (ab["name"].upper(), ab["cost"]), ab["text"], 0.27))
        self.back(st, x, y, w, color, c["name"], c["tagline"], sections, None)


def main():
    data = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    p = CardPainter(data)
    C = p.C
    cw = 160
    ch = cw / data["style"]["aspect"]
    gap = 22
    groups = [
        ("Traps", "trap", [i["id"] for i in data["items"] if i["category"] == "trap"]),
        ("Assist", "assist", [i["id"] for i in data["items"] if i["category"] == "assist"]),
        ("Board pieces and the coin", "neutral", [i["id"] for i in data["items"] if i["category"] in ("neutral", "coin")]),
        ("Potions (from the Potion Seller)", "potion", [i["id"] for i in data["items"] if i["category"] == "potion"]),
    ]
    cols = max(len(g[2]) for g in groups)
    cols = max(cols, 6)
    W = int(gap + cols * (cw + gap))
    head = 46
    H = int(70 + (len(groups) + 1) * (head + 2 * (ch + 26)) + 20)
    st = Stage(W, H, ss=3, art={"icons": {}}, theme=data["theme"])
    background(st)
    st.label(gap, 14, W - 2 * gap, 40, "Sticker cards: fronts, and the backs you see when you flip them", "chunky", 30,
             C["text"], outline=C["line"], outline_t=3)
    y = 70
    for title, cat, ids in groups + [("Characters", "char", list(p.chars))]:
        color = data["theme"]["Category"].get(cat, C["sun"])
        st.label(gap, y, W - 2 * gap, head - 8, title, "chunky", 26, color, outline=C["line"], outline_t=2.5)
        y += head
        for k, cid in enumerate(ids):
            x = gap + k * (cw + gap)
            if cat == "char":
                p.char_front(st, x, y, cw, cid)
                p.char_back(st, x, y + ch + 26, cw, cid)
            else:
                p.item_front(st, x, y, cw, cid)
                p.item_back(st, x, y + ch + 26, cw, cid)
        y += 2 * (ch + 26)
    img = st.img.crop((0, 0, st.img.width, int(y * st.ss))).resize((W, int(y)), resample=3)
    img.convert("RGB").save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main()
