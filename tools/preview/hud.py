#!/usr/bin/env python3
"""The match screen at real device sizes (developer preview tool).

Every rect comes from the game's own Layout module (tests/dump_screens.luau dumps
Layout.match for each device) and each piece is drawn the way its Lua component builds
it, number for number:

  BoardView    the map under everything, fitted into Layout's focus rect by the
               camera's fit (board.py), the path preview of the hovered die, the
               "You" tag and the path's tags
  PlayerChips  full (PC) / band (phone sideways) / stack (phone upright) chips: panel
               with the line stroke, a sun rim for whose turn it is, avatar with the
               seat ring, name, treasures, coins and cards, the Power bar, statuses
               with their turns left, the draining turn timer
  HandView     the sticker cards (cards.py), shrunk to fit, key hints on PC, AUTO on
               cards that work by themselves; the hand clips like its ScrollingFrame
  ActionDock   the dice tray (caption, two dice with their +POWER tags, Q/W key hints,
               the footer line, the clock badge) and the Power panel (mascot medallion,
               name, "Power 5 / 7", the segmented bar, the ability button)
  Feed         rows on the panel colour with the line stroke, rich-text names
  MatchScreen  the round plate and the icon buttons in Roblox's top bar
Roblox's own top-bar buttons and the phone's notch / home bar are drawn in so you can
see the HUD keeps clear of them. Real avatar headshots load from Roblox in game; here a
human player gets a stand-in.

Usage: python3 tools/preview/hud.py <dir with board.json, cards.json, screens.json> <outdir>
Writes 07-match-<device>.png.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from screens import (Stage, WHITE, mix, shade, background, button, icon_button, badge, badge_width, progress,  # noqa: E402
                     portrait, rich_runs, get_font)
from board import BoardScene, UNIT, name_tag, path_tags, stage_art  # noqa: E402
from cards import CardPainter  # noqa: E402
from cosmetics import draw_die  # noqa: E402
from PIL import Image  # noqa: E402

DIE_KEYS = ["Q", "W", "E"]
ABILITY_STYLE = {"mage": "blue", "trapper": "orange", "fire_starter": "red", "naturalist": "green", "warper": "purple",
                 "overseer": "brass"}
# PlayerChips STATUS: (key, icon, colour, shows its turns)
STATUS = [("frozen", "snowflake", "#45C3FF", True), ("burning", "flame", "#FF9A3C", True), ("skip", "zzz", "#6B3FD6", True),
          ("anchor", "time_potion", "#9A6BFF", False)]


def R(r):
    return r["x"], r["y"], r["w"], r["h"]


class Match:
    def __init__(self, data, scr, dev):
        self.data, self.scr, self.dev = data, scr, dev
        self.m, self.L = dev["m"], dev["match"]
        self.theme = scr["theme"]
        self.C = self.theme["C"]
        self.snap = scr["snapshot"]
        self.touch = bool(self.m["touch"])
        self.form = self.L["form"]
        self.my_seat = 1
        self.players = {p["seat"]: p for p in self.snap["players"]}
        self.seats = {s["seat"]: s for s in scr["seats"]}
        self.target = scr["mode"]["target"]

    def seat_color(self, seat):
        return self.theme["Seat"][(seat - 1) % 6]

    # ------------------------------------------------------------------ board
    def board(self, st, state=None):
        """BoardView: the camera fits the tile box into the focus rect (zoom 1)."""
        state = state or {}
        tall = self.form == "tall"
        layout = self.scr["boards"]["tall" if tall else "wide"]
        view = {
            "tokens": self.snap["tokens"], "natural": self.snap["natural"], "placed": self.snap["placed"],
            "traps": self.snap.get("traps", []), "embers": self.snap.get("embers", []),
            "players": [dict(p, pawn=self.seats[p["seat"]].get("pawn")) for p in self.snap["players"]],
            "current": self.snap.get("current"),
        }
        bdata = dict(self.data["board"])
        bdata["theme"] = self.theme
        bs = BoardScene(bdata, {"layout": layout, "view": view})
        f = self.L["focus"]
        x0, y0, x1, y1 = bs.tileBox
        s = min(f["w"] / (x1 - x0), f["h"] / (y1 - y0))
        camx, camy = (x0 + x1) / 2, (y0 + y1) / 2
        ox, oy = f["x"] + f["w"] / 2 - camx * s, f["y"] + f["h"] / 2 - camy * s
        pv = state.get("preview", self.scr["preview"])
        with st.at(ox, oy, s):
            bs.render(st, path={"path": pv["path"], "character": pv["character"]} if pv else None, moods=state.get("moods"))

        def to_stage(wx, wy):
            return ox + wx * s, oy + wy * s
        # the name tag over the current pawn (screen space; none once the game is over)
        cur = self.snap.get("current")
        if cur:
            px, py, share = bs.rest(cur)
            tx, ty = to_stage(px, py - bs.style["pawn"] * UNIT * 0.62 * share)
            name_tag(st, tx, ty - 4, "You" if cur == self.my_seat else self.players[cur]["name"], self.seat_color(cur))
        # what happens where the hovered die lands, over the landing tile
        if pv:
            lx, ly = bs.pos[pv["tile"]]
            bx, by = to_stage(lx, ly - 0.95 * UNIT)
            path_tags(st, bx, by, pv["tags"])
        return bs, to_stage

    # ------------------------------------------------------------------ chips
    def chips(self, st):
        spec = self.L["players"]
        chip = spec["chip"]
        w, h, kind = chip["w"], chip["h"], chip["kind"]
        r = spec["rect"]
        C = self.C
        T = self.theme
        cur = self.snap.get("current")
        clock = self.scr["turn"].get("clock")
        for i, seat in enumerate(sorted(self.players)):
            p, info = self.players[seat], self.seats[seat]
            x = r["x"] + (i * (w + spec["gap"]) if spec["dir"] == "x" else 0)
            y = r["y"] + (i * (h + spec["gap"]) if spec["dir"] == "y" else 0)
            color = self.seat_color(seat)
            on = seat == cur
            st.rect(x, y, w, h, C["panelHi"] if on else C["panel"], corner=min(12, h * 0.3), alpha=0.94,
                    stroke=(C["sun"], 3.5) if on else (C["line"], 2.5))
            char = self.scr["characters"].get(info.get("character") or "", {})
            active = []
            for key, icon, col, count in STATUS:
                v = p.get(key)
                if v is True or (isinstance(v, (int, float)) and not isinstance(v, bool) and v > 0):
                    active.append((icon, col, count, v if isinstance(v, (int, float)) and not isinstance(v, bool) else 0))
            cap = max(1, p.get("powerCap") or 1)
            k = max(0.0, min(1.0, (p.get("power") or 0) / cap))
            pcol = C["sun"] if k >= 1 else T["Character"].get(info.get("character") or "", C["sky"])

            def power_bar(px, py, pw, ph):
                st.rect(x + px, y + py, max(4, pw), ph, C["panelDeep"], corner=0.5)
                if k > 0:
                    st.rect(x + px, y + py, max(4, pw) * k, ph, pcol, corner=0.5)

            def pips(px, py, size, gap):
                for n in range(self.target):
                    filled = n < (p.get("treasures") or 0)
                    st.circle(x + px + n * (size + gap) + size / 2, y + py + size / 2, size, C["sun"] if filled else C["panelDeep"],
                              stroke=(C["line"], 2 if size >= 10 else 1.5))

            if kind == "full":
                av = h - 16
                portrait(st, info, x + 8 + av / 2, y + h / 2, av, ring=color, ring_px=3)
                tx = 8 + av + 10
                name = info["name"] + (" (you)" if seat == self.my_seat else "")
                st.label(x + tx, y + 5, w - tx - 8, 18, name, "heavy", 16, C["text"], truncate=True)
                if h >= 56:
                    if info.get("isBot"):
                        sub = "Bot · " + char.get("name", "")
                    elif info.get("username") and info["username"] != info["name"]:
                        sub = "@" + info["username"] + " · " + char.get("name", "")
                    else:
                        sub = char.get("name", "")
                    st.label(x + tx, y + 23, w - tx - 8, 14, sub, "body", 12,
                             shade(T["Character"].get(info.get("character"), C["textSoft"]), 0.35), truncate=True)
                row_y = h - 20
                pips(tx, row_y + 2, 14, 4)
                if h >= 56:
                    power_bar(tx, 40, w - tx - 10, 6)
                # counters (coins, cards): right-aligned in an 80 x 18 row
                cw = 14 + 20
                cx = w - 8 - (2 * cw + 4)
                for icon, col, val in (("coin", C["sun"], p.get("coins", 0)), ("book", C["sky"], p.get("handCount", 0))):
                    st.medallion(icon, x + cx + 7, y + row_y + 1 + 1 + 7, 14, col)
                    st.label(x + cx + 16, y + row_y + 1, 20, 16, str(val), "chunky", 14, WHITE)
                    cx += cw + 4
                # statuses, right of the name line (a 110 x 16 row, right-aligned)
                widths = [16 + (12 if (cnt and n > 0) else 0) for _, _, cnt, n in active]
                sx = w - 8 - (sum(widths) + 3 * max(0, len(widths) - 1))
                for (icon, col, cnt, n), ww in zip(active, widths):
                    st.medallion(icon, x + sx + 8, y + 5 + 8, 16, col)
                    if cnt and n > 0:
                        st.label(x + sx + 16, y + 5, 12, 16, str(int(n)), "chunky", 13, C["text"], outline=C["line"], outline_t=2)
                    sx += ww + 3
            elif kind == "band":
                av = h - 6
                portrait(st, info, x + 3 + av / 2, y + h / 2, av, ring=color, ring_px=2)
                tx = 3 + av + 5
                st.label(x + tx, y + 3, w - tx - 4, 13, info["name"], "heavy", 11, C["text"], truncate=True)
                ps = max(6, min(11, math.floor((w - tx - 6 - (self.target - 1) * 3) / self.target)))
                pips(tx, h - ps - 8, ps, 3)
                power_bar(tx, h - 6, w - tx - 5, 3)
                if active:
                    sz = math.floor(av * 0.42)
                    st.medallion(active[0][0], x + 3 + av * 0.86, y + h / 2 - av / 2 + av * 0.14, sz, active[0][1])
            else:  # stack
                av = min(h - 30, w - 12)
                portrait(st, info, x + w / 2, y + 4 + av / 2, av, ring=color, ring_px=2)
                st.label(x + 3, y + 4 + av + 1, w - 6, 13, info["name"], "heavy", 11, C["text"], align="center", truncate=True)
                ps = max(6, min(10, math.floor((w - 10 - (self.target - 1) * 3) / self.target)))
                pw = self.target * ps + (self.target - 1) * 3
                pips((w - pw) / 2, h - ps - 8, ps, 3)
                power_bar(6, h - 6, w - 12, 3)
                if active:
                    sz = math.floor(av * 0.42)
                    st.medallion(active[0][0], x + w / 2 - av / 2 + av * 0.86, y + 4 + av * 0.14, sz, active[0][1])
            if on and clock is not None:
                # the draining turn timer (Widgets.progress, 3 px tall, at the chip's foot)
                left = clock / self.scr["turn"]["deadline"]
                progress(st, x + 8, y + h - 4, w - 16, 3, left, C["bad"] if left < 0.25 else C["sun"])

    # ------------------------------------------------------------------ hand
    def hand(self, st, painter, items, spent=False, hovered=None, held=None):
        spec = self.L["hand"]
        r = spec["rect"]
        col = spec.get("dir") == "y"
        n = len(items)
        gap = spec.get("gap", 6)
        w0, h0 = spec["card"]["w"], spec["card"]["h"]
        aspect = self.data["cards"]["style"]["aspect"]
        if col:
            fit = (r["h"] - 8 - (n - 1) * gap) / n
            ch = max(h0 * 0.7, min(h0, fit))
            cw = ch * aspect
        else:
            fit = (r["w"] - 12 - (n - 1) * gap) / n
            cw = max(w0 * 0.7, min(w0, fit))
            ch = cw / aspect
        C = self.C
        rects = []
        with st.layer(clip=(r["x"], r["y"], r["w"], r["h"])):
            for i, item in enumerate(items):
                if col:
                    x = r["x"] + (4 + r["w"] - 14) / 2 - cw / 2
                    y = r["y"] + 4 + i * (ch + gap)
                else:
                    total = n * cw + (n - 1) * gap
                    x = r["x"] + (6 + r["w"] - 6) / 2 - total / 2 + i * (cw + gap)
                    y = r["y"] + (8 + r["h"]) / 2 - ch / 2
                rects.append((x, y, cw, ch))
                if held == i:
                    # HandView:setHeld: the card is out over the board; its spot waits empty
                    st.rect(x + 0.04 * cw, y + 0.03 * ch, 0.92 * cw, 0.94 * ch, C["panelDeep"], corner=0.1, alpha=0.55,
                            stroke=(C["sun"], 2, 0.65))
                    continue
                if hovered == i:
                    if col:
                        x += 8
                    else:
                        y -= 8
                painter.item_front(st, x, y, cw, item)
                info = self.scr["items"][item]
                passive = info["use"] == "passive"
                if spent and not passive:
                    st.rect(x, y, cw, ch, C["bgDeep"], corner=0.1, alpha=0.6)
                if passive:
                    badge(st, x + cw / 2, y + 2, "AUTO", C["mint"], height=16, text_size=11, anchor=(0.5, 0.5))
                if not self.touch and i < 9:
                    bx, by = x + 0.12 * cw - 9, y + 0.06 * ch - 9
                    st.rect(bx, by, 18, 18, C["panelDeep"], corner=5, stroke=(C["line"], 2))
                    st.label(bx, by, 18, 18, str(i + 1), "chunky", 12, C["sun"], align="center")
        return rects

    # ------------------------------------------------------------------ action dock
    @staticmethod
    def slab(st, x, y, w, h, color, corner):
        """ActionDock slab: a hard shadow 5 px down, the surface with the 3 px line."""
        st.rect(x, y + 5, w, h, st.C["shadow"], corner=corner)
        st.rect(x, y, w, h, color, corner=corner, stroke=(st.C["line"], 3))

    def power_bar(self, st, x, y, w, h, power, cap, character):
        C = self.C
        st.rect(x, y, w, h, C["panelDeep"], corner=0.5, stroke=(C["line"], 2.5 if h >= 12 else 2))
        full = cap > 0 and power >= cap
        k = max(0.0, min(1.0, power / cap)) if cap > 0 else 0
        if k > 0:
            fw = w * k
            st.rect(x, y, fw, h, C["sun"] if full else self.theme["Character"].get(character, C["sky"]), corner=0.5)
            st.rect(x + 3, y + 2, fw - 6, 0.3 * h, WHITE, corner=0.5, alpha=0.35)
        if 1 < cap <= 10:
            for i in range(1, cap):
                st.rect(x + i / cap * w - 1, y + 2, 2, h - 4, C["line"], alpha=0.75)

    def power_panel(self, st, character, power, cap, my_turn=True):
        r = self.L["ability"]
        x, y, w, h = R(r)
        C = self.C
        info = self.scr["characters"][character]
        ab = info.get("ability")
        color = self.theme["Character"].get(character, C["grape"])
        full = cap > 0 and power >= cap
        style = ABILITY_STYLE.get(character, "wood")
        usable = full and my_turn  # the button works on my turn once the bar is full
        if self.form == "wide":
            self.slab(st, x, y, w, h, C["panel"], 16)
            ps = min(70, h - 50)
            st.medallion(character, x + 10 + ps / 2, y + 10 + ps / 2, ps, color)
            tx = ps + 20
            st.label(x + tx, y + 10, w - tx - 10, 22, info["name"].upper(), "chunky", 19, C["text"], outline=C["line"], outline_t=2)
            text = "" if not ab else ("POWER FULL!" if full else "Power %d / %d" % (power, cap))
            st.label(x + tx, y + 32, w - tx - 10, 16, text, "heavy", 13, C["sun"] if full else C["textSoft"])
            self.power_bar(st, x + tx, y + 52, w - tx - 12, 18, power, cap, character)
            if ab:
                button(st, x + 10, y + h - 50, w - 20, 42, text=ab["name"].upper(), style=style, text_size=19, depth=4,
                       enabled=usable)
        elif self.form == "short":
            ps = min(38, h - 34)
            st.medallion(character, x + ps / 2, y + ps / 2, ps, color)
            self.power_bar(st, x + ps + 6, y + math.floor((ps - 14) / 2), w - ps - 6, 14, power, cap, character)
            if ab:
                button(st, x, y + ps + 4, w, max(30, h - ps - 4), text=ab["name"].upper(), style=style, text_size=15, depth=4,
                       enabled=usable)
        else:
            if ab:
                text = ab["name"].upper() + ("!" if full else " %d/%d" % (power, cap))
                button(st, x, y, w, h - 10, text=text, style=style, text_size=14, depth=4, enabled=usable)
            self.power_bar(st, x + 4, y + h - 9, w - 8, 9, power, cap, character)

    def dice_tray(self, st, dice, hover, power, clock, chosen=None, hint=None, mine=True):
        r = self.L["roll"]
        x, y, w, h = R(r)
        C = self.C
        wide = self.form == "wide"
        self.slab(st, x, y, w, h, C["panel"], 16)
        caption_h = 20 if wide else 0
        foot_h = 30 if wide else (26 if self.form == "short" else 0)
        can_pick = mine and chosen is None and hint is None
        if caption_h:
            st.label(x + 8, y + 6, w - 16, caption_h, "PICK A DIE" if mine else "", "chunky", 15, C["sun"] if mine else C["textSoft"],
                     align="center", outline=C["line"], outline_t=2, truncate=True)
        ax, ay, aw, ah = x + 6, y + 6 + caption_h, w - 12, h - (12 + caption_h + foot_h)
        n = len(dice)
        gap = 12 if wide else 8
        size = math.floor(min(ah - 4, (aw - (n - 1) * gap) / n, 84))
        total = n * size + (n - 1) * gap
        looks = self.data["board"]["looks"]
        die_look = {"look": looks[self.data["board"]["defaults"]["dice"]]}
        pips = {"pips": self.data["board"]["pips"]}
        for i, v in enumerate(dice):
            dx = ax + (aw - total) / 2 + i * (size + gap)
            dy = ay + (ah - size) / 2
            on = hover == i and can_pick
            if on:
                dy -= 6
                ring = 1.16 * size
                st.rect(dx + size / 2 - ring / 2, dy + size / 2 - ring / 2, ring, ring, C["sun"], corner=0.3, alpha=0.85)
            side = st.L(size)
            tmp = Image.new("RGBA", (int(side * 1.6) + 4, int(side * 1.6) + 4), (0, 0, 0, 0))
            draw_die(tmp, side * 0.3, side * 0.3, side, die_look, pips, value=v)
            st.blit(tmp, st.X(dx) - side * 0.3, st.Y(dy) - side * 0.3)
            if chosen is not None and chosen != i:
                # a die that wasn't chosen dims
                st.rect(dx + 0.02 * size, dy + 0.02 * size, 0.96 * size, 0.96 * size, C["panel"], corner=0.24, alpha=0.65)
            pw = power[i] if i < len(power) else 0
            if pw > 0 and can_pick:
                th = max(16, math.floor(size * 0.28))
                ts = max(11, math.floor(size * 0.2))
                badge(st, dx + size / 2, dy + size - 2, "+%d POWER" % pw, C["sun"], height=th, text_size=ts, anchor=(0.5, 0.5))
            if not self.touch and wide and can_pick:
                st.label(dx - 2, dy - 6, 16, 14, DIE_KEYS[i], "chunky", 11, C["textFaint"], align="center")
        if foot_h:
            if not can_pick:
                text = hint or ""
            elif self.touch:
                text = "Tap it again to go!" if hover is not None else "Tap a die to see where it goes"
            else:
                text = "Hover to see where it goes, click to go"
            st.label(x + 6, y + h - 6 - foot_h, w - 12, foot_h, text, "heavy", 13 if wide else 11, C["textSoft"],
                     align="center", wrap=True)
        if clock is not None:
            bw, bh = (58, 24) if wide else (48, 20)
            bx, by = x + w - 4 - bw, y + 2 - bh / 2
            st.rect(bx, by, bw, bh, C["bad"] if clock <= 10 else C["panelDeep"], corner=0.5, stroke=(C["line"], 2))
            st.label(bx, by, bw, bh, "%d:%02d" % (clock // 60, clock % 60), "chunky", 16 if wide else 14, C["text"],
                     align="center")

    # ------------------------------------------------------------------ feed
    def feed(self, st, lines):
        spec = self.L["feed"]
        r = spec["rect"]
        C = self.C
        size = 13 if r["w"] < 340 else 15
        max_label = max(120, r["w"] - 40)
        iw = size + 2
        y = r["y"]
        align = spec.get("align", "right")
        for ln in lines[:spec.get("lines", 4)]:
            runs = rich_runs(ln["text"], ln.get("color") or C["text"])
            f = get_font("heavy", st.L(size))
            wrapped = st._wrap(runs, f, st.L(max_label), f.getlength(" "))
            text_w = max(lw for _, lw in wrapped) / st.L(1)
            text_h = len(wrapped) * size
            lw = min(text_w, max_label)
            row_w = 8 + iw + 6 + lw + 10
            inner_h = max(iw, text_h)
            row_h = 3 + inner_h + 3
            if align == "left":
                x = r["x"]
            elif align == "center":
                x = r["x"] + (r["w"] - row_w) / 2
            else:
                x = r["x"] + r["w"] - row_w
            st.rect(x, y, row_w, row_h, C["panel"], corner=8, alpha=0.94, stroke=(C["line"], 2))
            st.medallion(ln["icon"], x + 8 + iw / 2, y + 3 + inner_h / 2, iw, ln.get("iconColor") or C["sun"])
            st.label(x + 8 + iw + 6, y + 3 + (inner_h - text_h) / 2, lw + 1, text_h, ln["text"], "heavy", size,
                     ln.get("color") or C["text"], wrap=True, rich=True, valign="top")
            y += row_h + 4

    # ------------------------------------------------------------------ top bar
    def top(self, st):
        C = self.C
        L = self.L
        info = L.get("info")
        if info:
            x, y, w, h = R(info)
            st.rect(x, y, w, h, C["panel"], corner=min(10, h / 2), stroke=(C["line"], 2.5))
            size = max(11, min(16, math.floor(h * 0.5)))
            mode = self.scr["mode"]
            rnd = self.snap["round"]
            if w >= 300:
                text = "Round %d  ·  %s  ·  %s  ·  First to %d" % (rnd, mode["short"], mode["length"], mode["target"])
            elif w >= 160:
                text = "Round %d  ·  First to %d" % (rnd, mode["target"])
            else:
                text = "Round %d" % rnd
            st.label(x + 8, y, w - 16, h, text, "heavy", size, C["text"], truncate=True)
        b = L["buttons"]
        items = [("people", "dark"), ("map", "dark"), ("smile", "brass"), ("gear", "dark")][4 - b["count"]:]
        x = b["rect"]["x"] + b["rect"]["w"]
        for icon, style in reversed(items):
            x -= b["size"]
            icon_button(st, x, b["rect"]["y"] + (b["rect"]["h"] - b["size"]) / 2, b["size"], b["size"], icon, style=style)
            x -= b["gap"]


def roblox_chrome(st, m):
    """Roblox's own top-bar buttons (menu and chat) and the phone's notch / home bar."""
    tb, safe = m["topbar"], m["safe"]
    h = tb["y1"] - tb["y0"]
    size = min(44 / m["scale"], h - 8)
    y = tb["y0"] + (h - size) / 2
    x = max(tb["l"] - 2 * size - 18, safe["l"] + 8)
    for i in range(2):
        bx = x + i * (size + 10)
        st.rect(bx, y, size, size, "#000000", corner=size * 0.28, alpha=0.45)
        if i == 0:
            st.rect(bx + size * 0.3, y + size * 0.3, size * 0.4, size * 0.4, WHITE, corner=2)
            st.rect(bx + size * 0.42, y + size * 0.42, size * 0.16, size * 0.16, "#3A3A3A", corner=1)
        else:
            st.rect(bx + size * 0.26, y + size * 0.3, size * 0.48, size * 0.32, WHITE, corner=size * 0.08)
            st.poly([(bx + size * 0.36, y + size * 0.6), (bx + size * 0.48, y + size * 0.6), (bx + size * 0.34, y + size * 0.74)], WHITE)
    vw, vh = m["vw"], m["vh"]
    if safe["l"] > 0:
        st.rect(0, 0, safe["l"] * 0.62, vh, "#000000", alpha=0.92)
        st.rect(0, vh / 2 - vh * 0.2, safe["l"] * 0.8, vh * 0.4, "#000000", corner=safe["l"] * 0.3)
    if safe["r"] > 0:
        st.rect(vw - safe["r"] * 0.62, 0, safe["r"] * 0.62, vh, "#000000", alpha=0.92)
    if safe["t"] > 0:
        st.rect(vw / 2 - vw * 0.16, 6, vw * 0.32, safe["t"] * 0.62, "#000000", corner=safe["t"] * 0.3)
    if safe["b"] > 0:
        st.rect(vw / 2 - vw * 0.17, vh - safe["b"] * 0.55, vw * 0.34, 5, WHITE, corner=2.5, alpha=0.85)


def new_stage(data, scr, m, ss=3):
    st = Stage(m["vw"], m["vh"], ss=ss, art=stage_art(data["board"]), theme=scr["theme"])
    background(st)
    return st


def save(st, dev, path):
    out_w = dev["w"] * (2 if dev["w"] < 1000 else 1)
    out_h = int(round(out_w * st.h / st.w))
    img = st.img.resize((out_w, out_h), resample=Image.LANCZOS)
    img.convert("RGB").save(path)
    print("wrote", path, img.size)


def match_screen(data, scr, dev, out=None, state=None):
    """The match HUD. `state` changes the moment shown (the defaults are my turn with the
    first die hovered): preview (None = no path), moods, chosen die, hint, my_turn."""
    state = state or {}
    mt = Match(data, scr, dev)
    st = new_stage(data, scr, mt.m)
    mt.board(st, state)
    painter = CardPainter(data["cards"])
    mt.chips(st)
    mt.hand(st, painter, mt.snap["hand"])
    me = mt.players[mt.my_seat]
    my_turn = state.get("my_turn", True)
    mt.power_panel(st, me["character"], me["power"], me["powerCap"], my_turn=my_turn)
    turn = scr["turn"]
    hover = turn.get("hover")
    mt.dice_tray(st, turn["dice"], hover - 1 if hover else None, turn["power"], turn.get("clock"),
                 chosen=state.get("chosen"), hint=state.get("hint"), mine=mt.snap.get("current") == mt.my_seat or state.get("mine", False))
    mt.feed(st, state.get("feed", scr["feed"]))
    mt.top(st)
    roblox_chrome(st, mt.m)
    if out:
        save(st, dev, out)
    return st, mt


def load(src):
    data = {}
    for name in ("board", "cards"):
        data[name] = json.load(open(os.path.join(src, name + ".json")))
    scr = json.load(open(os.path.join(src, "screens.json")))
    return data, scr


def main():
    src, outdir = sys.argv[1], sys.argv[2]
    data, scr = load(src)
    for dev in scr["devices"]:
        match_screen(data, scr, dev, os.path.join(outdir, "07-match-%s.png" % dev["file"]))


if __name__ == "__main__":
    main()
