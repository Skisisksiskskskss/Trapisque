#!/usr/bin/env python3
"""The lobby's pages and the results screen, at PC size (developer preview tool).

Each is a Widgets.modal sized and scaled exactly as the game does it (Layout.modal on
the PC stage) and filled the way its Lua module builds it:

  Lobby/CharacterSelect.lua  CharacterSelect.open: a card per character (Cards.character),
                             mastery level and bar, the next mastery title, PICK / PICKED
  Lobby/Quests.lua           Quests.open: three daily quests with progress, Gems and SWAP,
                             the bonus chest line, the 7-day login streak
  Match/Results.lua          Results.show: standings (bonks, gotchas, treasures, WINNER),
                             then character mastery, daily quests and trophies, the Gems
                             and XP earned and the LOBBY button (over the match as it ends)
  Lobby/Chests.lua           Chests.open: the purse, both chests with their art, odds
                             strip, pity line, the free chest waiting, x10, SEE ODDS
  first/Loading.client.lua   the splash while the game streams in (physical pixels, no
                             stage scale): the dotted table, the tilted title, two dice

Usage: python3 tools/preview/pages.py <dir with board.json, cards.json, screens.json> <outdir>
Writes 09-treasure-chests.png, 14-characters-pc.png, 15-quests-pc.png, 16-results-pc.png and
17-loading-<device>.png.
"""
import copy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from screens import (WHITE, mix, button, badge, progress, modal_frame, room, portrait)  # noqa: E402
from hud import load, save, match_screen  # noqa: E402
from lobby import lobby_screen, commas  # noqa: E402
from cards import CardPainter  # noqa: E402

PLACE = ["1st", "2nd", "3rd", "4th", "5th", "6th"]


def pc(scr):
    return next(d for d in scr["devices"] if d["file"] == "pc")


# ----------------------------------------------------------------------------- characters
def character_select(data, scr, out):
    dev = pc(scr)
    m = dev["m"]
    st = lobby_screen(data, scr, dev)
    C, T = st.C, st.theme
    room_w, _, narrow = room(m)
    cols = 2 if narrow else 3
    cell_w = 158 if narrow else 196
    card_w = 104 if narrow else 128
    aspect = data["cards"]["style"]["aspect"]
    cell_h = math.floor(card_w / aspect) + 104
    chars = list(scr["characters"])
    order = ["mage", "trapper", "fire_starter", "naturalist", "warper", "overseer"]
    chars = [c for c in order if c in chars]
    rows = math.ceil(len(chars) / cols)
    w = min(room_w, cols * (cell_w + 12) + 60)
    h = 120 + rows * (cell_h + 12)
    (cx, cy, cw, ch), ox, oy, scale, bw, bh = modal_frame(st, m, w, h, title="Characters", title_w=280)
    painter = CardPainter(data["cards"])
    picked = scr["profile"]["character"]
    with st.at(ox, oy, scale):
        st.label(cx, cy, cw, 34 if narrow else 22, "Pick who you play as. The more you play someone, the higher their mastery.",
                 "heavy", 13 if narrow else 15, C["textSoft"], align="center", wrap=True)
        gy = cy + (40 if narrow else 30)
        grid_w = cols * cell_w + (cols - 1) * 12
        gx = cx + (cw - grid_w) / 2
        for i, cid in enumerate(chars):
            x = gx + (i % cols) * (cell_w + 12)
            y = gy + (i // cols) * (cell_h + 12)
            on = cid == picked
            st.rect(x, y, cell_w, cell_h, C["panelRaised"], corner=14, stroke=(C["sun"], 4) if on else (C["line"], 2.5))
            painter.char_front(st, x + cell_w / 2 - card_w / 2, y + 8, card_w, cid)
            ms = scr["mastery"][cid]
            yy = y + 8 + math.floor(card_w / aspect) + 6
            st.label(x + 6, yy, cell_w - 12, 18, "MASTERY %d" % ms["level"], "chunky", 15, C["text"], align="center",
                     outline=C["line"], outline_t=2)
            progress(st, x + 12, yy + 22, cell_w - 24, 10, ms["into"] / max(1, ms["need"]) if ms.get("need") else 1,
                     T["Character"].get(cid, C["grape"]))
            name = scr["characters"][cid]["name"]
            text = ("%s %s title at level %d" % (name, ms["titleName"], ms["titleAt"])) if ms.get("titleAt") else "Max mastery!"
            st.label(x + 6, yy + 36, cell_w - 12, 14, text, "heavy", 11, C["textFaint"], align="center", truncate=True)
            button(st, x + 10, y + cell_h - 8 - 36, cell_w - 20, 36, text="PICKED" if on else "PICK", style="green" if on else "brass",
                   text_size=16, depth=4)
    save(st, dev, out)


# ----------------------------------------------------------------------------- quests
def quests_page(data, scr, out):
    dev = pc(scr)
    m = dev["m"]
    st = lobby_screen(data, scr, dev)
    C = st.C
    prof = scr["profile"]
    room_w, _, narrow = room(m)
    width = min(620, room_w)
    (cx, cy, cw, ch), ox, oy, scale, bw, bh = modal_frame(st, m, width, 610 if narrow else 570, title="Daily Quests", title_w=300)
    quests = prof["quests"]
    can_swap = not prof.get("questRerolled")
    left = 86400 - (scr["now"] % 86400)
    hh, mm = left // 3600, (left % 3600) // 60
    until = ("%dh %02dm" % (hh, mm)) if hh > 0 else ("%dm" % mm)
    with st.at(ox, oy, scale):
        st.label(cx, cy, cw, 20, "New quests in " + until + ("  ·  you can SWAP one quest a day" if can_swap else ""), "heavy",
                 13 if narrow else 15, C["textSoft"], align="center")
        y = cy + 28
        for q in quests:
            done = q["done"]
            st.rect(cx, y, cw, 64, C["mine"] if done else C["panelRaised"], corner=12, stroke=(C["sun"] if done else C["line"], 2.5))
            st.medallion("check" if done else "star", cx + 10 + 20, y + 32, 40, C["lime"] if done else C["sun"])
            right = 190 if (can_swap and not done) else 110
            st.label(cx + 60, y + 8, cw - (60 + right), 22, q["text"], "heavy", 16, C["text"], truncate=True)
            progress(st, cx + 60, y + 38, cw - (60 + right + 50), 12, q["progress"] / max(1, q["goal"]), C["lime"] if done else C["sun"])
            st.label(cx + cw - (right - 2) - 46, y + 34, 46, 18, "%d/%d" % (q["progress"], q["goal"]), "chunky", 14, C["textSoft"],
                     align="right")
            # the reward, right-aligned in a 92 x 36 row
            rx = cx + cw - 10
            if done:
                badge(st, rx, y + 32, "DONE!", C["lime"], height=26, text_size=15, anchor=(1, 0.5))
            else:
                gtext = "+%d" % q["gems"]
                st.label(rx - 52, y + 32 - 15, 52, 30, gtext, "chunky", 20, C["text"])
                st.medallion("gem", rx - 52 - 4 - 13, y + 32, 26, C["neutral"])
            if can_swap and not done:
                button(st, cx + cw - 110 - 70, y + 32 - 17, 70, 34, text="SWAP", style="purple", text_size=14, depth=3, corner=10)
            y += 64 + 8
        all_done = len(quests) > 0 and all(q["done"] for q in quests)
        by = cy + 28 + 3 * 64 + 2 * 8 + 10
        st.rect(cx, by, cw, 44, C["mine"] if all_done else C["panelDeep"], corner=10, stroke=(C["sun"] if all_done else C["line"], 2))
        st.medallion("chest", cx + 8 + 16, by + 22, 32, C["orange"])
        text = ("All done today! Your free Explorer Chest is waiting in CHESTS." if prof.get("questBonus")
                else "Finish all three for a free Explorer Chest!")
        st.label(cx + 48, by, cw - 56, 44, text, "heavy", 13 if narrow else 15, C["sun"] if all_done else C["text"], wrap=True)
        top = cy + 28 + 3 * 64 + 2 * 8 + 10 + 44 + 16
        count = prof["streak"]["count"]
        st.label(cx, top, cw, 22, "LOGIN STREAK: %d %s" % (count, "DAY" if count == 1 else "DAYS"), "chunky", 18, C["text"],
                 align="center", outline=C["line"], outline_t=2)
        gems = scr["streakGems"]
        days = len(gems)
        today = ((count - 1) % days) + 1 if count > 0 else 0
        boxw = cw / days - 6 * (days - 1) / days
        ry = top + 28
        for i in range(1, days + 1):
            got = i <= today
            is_today = i == today
            x = cx + (i - 1) * (boxw + 6)
            st.rect(x, ry, boxw, 72, C["sun"] if got else (C["panelHi"] if i == today + 1 else C["panelRaised"]), corner=10,
                    stroke=(WHITE, 3) if is_today else (C["line"], 2))
            st.label(x, ry + 4, boxw, 16, "DAY %d" % i, "chunky", 12, C["textOnLight"] if got else C["textSoft"], align="center")
            chest = i == scr["streakChestDay"]
            st.medallion("chest" if chest else "gem", x + boxw / 2, ry + 0.52 * 72, 26, C["orange"] if chest else C["neutral"])
            st.label(x, ry + 72 - 3 - 16, boxw, 16, "+%d" % gems[i - 1], "chunky", 13, C["textOnLight"] if got else C["text"],
                     align="center")
        st.label(cx, top + 106, cw, 18, "Come back tomorrow to keep it going. Miss a day and it starts over.", "body", 13,
                 C["textFaint"], align="center")
    save(st, dev, out)


# ----------------------------------------------------------------------------- results
def game_over(scr):
    """The match the moment it ends (what's behind the results): my last move banked my
    third treasure, which sends my pawn home to the Start; the board and chips show no
    current player (setCurrent(nil)), every mascot pulls its end face (happy / sad),
    and the tray keeps my last roll with the chosen die and "Game over!"."""
    s = copy.deepcopy(scr)
    snap = s["snapshot"]
    rows = {r["seat"]: r for r in s["results"]["results"]}
    snap["current"] = None
    for p in snap["players"]:
        p["treasures"] = rows[p["seat"]]["treasures"]
        if p["seat"] == 1:
            p["tile"] = 1
            p["power"] = p["powerCap"]
    s["turn"] = dict(s["turn"], dice=[6, 3], power=[3, 6], clock=None, hover=None)
    you = '<font color="#%s">You</font>' % mix(s["theme"]["Seat"][0], "#FFFFFF", 0.25)[1:]
    C = s["theme"]["C"]
    feed = [{"text": you + " found a treasure! (3 / 3)", "color": C["sun"], "icon": "chest", "iconColor": C["sun"]},
            {"text": you + " move 6", "icon": "dice", "iconColor": C["sun"]}] + s["feed"]
    moods = {r["seat"]: ("happy" if r["won"] else "sad") for r in s["results"]["results"]}
    state = {"preview": None, "moods": moods, "chosen": 0, "hint": "Game over!", "my_turn": False, "mine": True, "feed": feed}
    return s, state


def results_page(data, scr, out):
    dev = pc(scr)
    m = dev["m"]
    over, state = game_over(scr)
    st, mt = match_screen(data, over, dev, state=state)
    C, T = st.C, st.theme
    res = scr["results"]
    rows = {r["seat"]: r for r in res["results"]}
    me = rows[1]
    won = me["won"]
    title = "Victory!" if won else ("Practice Over" if res["kind"] == "practice" else "Game Over")
    sx, sy, sw, sh = m["safe"]["l"] + 16, m["safe"]["t"] + 16, m["vw"] - m["safe"]["l"] - m["safe"]["r"] - 32, 0
    width = min(760, sw)
    narrow = width < 600
    seats = len(res["results"])
    reward = res.get("reward")
    cards_h = (3 * 46 + 12 if narrow else 104) if reward else 0
    height = (260 if narrow else 190) + seats * 58 + cards_h
    (cx, cy, cw, ch), ox, oy, scale, bw, bh = modal_frame(st, m, width, height, title=title, title_w=min(300, width - 60),
                                                         no_close=True)
    winners = [r["name"] for r in res["results"] if r["won"]]
    reason = ", ".join(winners) + " found every treasure!"
    with st.at(ox, oy, scale):
        st.label(cx, cy, cw, 40 if narrow else 26, reason, "heavy", 15 if narrow else 18, C["textSoft"], align="center", wrap=True)
        ly = cy + (46 if narrow else 34)
        for i, seat in enumerate(res["ranking"]):
            r = rows[seat]
            results_row(st, cx, ly + i * 58, cw, i + 1, r, seat == 1, narrow)
        if reward:
            progress_cards(st, scr, cx, ly + seats * 58 + 8, cw, cards_h - 8, reward, narrow, res)
        # rewards beside the LOBBY button
        by = cy + ch - (112 if narrow else 56)
        bhh = 112 if narrow else 56
        qg = (reward.get("quests") or {}).get("gems", 0)
        mg = (reward.get("mastery") or {}).get("gems", 0)
        chips = [("gem", C["neutral"], "+%d" % (reward["gems"] + qg + mg)), ("level", C["info"], "+%d XP" % reward["xp"])]
        if reward.get("levelsGained", 0) > 0:
            chips.append(("star", C["sun"], "Level %d!" % reward["level"]))
        x = cx
        for icon, col, text in chips:
            st.medallion(icon, x + 17, by + bhh / 2, 34, col)
            tw = st.text_size(text, "chunky", 22)
            st.label(x + 34 + 6, by + bhh / 2 - 17, tw, 34, text, "chunky", 22, C["text"])
            x += 34 + 6 + tw + 10
        button(st, cx + cw - 210, by + bhh / 2 - 26, 210, 52, text="LOBBY (%d)" % res["resultsTime"], icon="back", style="green",
               text_size=22)
    save(st, dev, out)


def results_row(st, x, y, w, place, r, mine, narrow):
    C, T = st.C, st.theme
    seat_color = T["Seat"][(r["seat"] - 1) % 6]
    st.rect(x, y, w, 52, C["mine"] if mine else C["panelRaised"], corner=10, stroke=(C["sun"] if r["won"] else C["line"], 2.5))
    st.label(x, y, 52, 52, PLACE[place - 1], "chunky", 22, C["brass"] if r["won"] else C["textSoft"], align="center")
    portrait(st, {"userId": r.get("userId"), "character": r.get("character"), "isBot": r.get("isBot")}, x + 52 + 21, y + 26, 42,
             ring=seat_color, ring_px=3)
    right = 84 if narrow else 360
    st.label(x + 102, y + 5, w - (102 + right), 22, r["name"] + ("  (you)" if mine else ""), "heavy", 16 if narrow else 18, C["text"],
             truncate=True)
    cname = st.theme.get("_charNames", {}).get(r.get("character"), "")
    sub = (("@" + r["username"] + "  ·  ") if (r.get("username") and not r.get("isBot")) else "") + cname
    st.label(x + 102, y + 28, w - (102 + right), 18, sub, "body", 12 if narrow else 14, C["textSoft"], truncate=True)
    # treasures, right-aligned in a 110 x 30 row ending 96 px from the right
    tw = 26 + 6 + 46
    tx = x + w - (8 if narrow else 96) - tw
    st.medallion("chest", tx + 13, y + 26, 26, C["sun"])
    st.label(tx + 32, y + 26 - 15, 46, 30, "x%d" % r["treasures"], "chunky", 22, C["text"])
    stats = r.get("stats") or {}
    if not narrow and (stats.get("bonks", 0) + stats.get("gotchas", 0)) > 0:
        boxes = [(icon, col, n) for icon, col, n in (("star", C["sun"], stats.get("bonks", 0)), ("token_trap", C["coral"], stats.get("gotchas", 0)))
                 if n > 0]
        total = len(boxes) * 48 + (len(boxes) - 1) * 6
        bx = x + w - 212 - total
        for icon, col, n in boxes:
            st.medallion(icon, bx + 12, y + 26 - 13 + 1 + 12, 24, col)
            st.label(bx + 26, y + 26 - 13, 24, 26, "x%d" % n, "chunky", 16, C["text"])
            bx += 48 + 6
    if r["won"] and not narrow:
        badge(st, x + w - 10, y + 26, "WINNER", C["sun"], height=26, text_size=15, text_color=C["textOnLight"], stroke=C["line"],
              anchor=(1, 0.5))


def progress_cards(st, scr, x, y, w, h, reward, narrow, res):
    """Results: character mastery, daily quests that moved, trophies."""
    C, T = st.C, st.theme
    n = 3
    cwid = w / 3 - 6 if not narrow else w
    chh = 42 if narrow else h
    xs = [x + (w - (3 * cwid + 2 * 8)) / 2 + i * (cwid + 8) for i in range(n)]

    def card(i):
        cx = xs[i] if not narrow else x
        cy = y if not narrow else y + i * (42 + 8)
        st.rect(cx, cy, cwid, chh, C["panelRaised"], corner=10, stroke=(C["line"], 2.5))
        return cx, cy

    ps = 34 if narrow else 44
    ms = reward.get("mastery")
    if ms:
        fx, fy = card(0)
        cid = ms["character"]
        st.medallion(cid, fx + 6 + ps / 2, fy + (4 if narrow else 8) + ps / 2, ps, T["Character"].get(cid, C["grape"]))
        up = ms.get("levelsGained", 0) > 0
        name = scr["characters"][cid]["name"]
        st.label(fx + ps + 12, fy + (2 if narrow else 8), cwid - (ps + 16), 20, "%s Lv %d" % (name, ms["level"]) + ("  LEVEL UP!" if up else ""),
                 "chunky", 15 if narrow else 17, C["sun"] if up else C["text"], truncate=True)
        frac = ms["into"] / max(1, ms["need"]) if ms.get("need") else 1
        progress(st, fx + ps + 12, fy + (26 if narrow else 34), cwid - (ps + 70), 12, frac, T["Character"].get(cid, C["sky"]))
        st.label(fx + cwid - 8 - 52, fy + (22 if narrow else 30), 52, 18, "+%d" % ms["xp"], "chunky", 15, C["textSoft"], align="right")
        if not narrow:
            extra = []
            if ms.get("gems", 0) > 0:
                extra.append("+%d Gems" % ms["gems"])
            for _ in ms.get("titles") or []:
                extra.append("New title!")
            st.label(fx + ps + 12, fy + 54, cwid - (ps + 16), 16, "  ·  ".join(extra) if extra else "Character mastery", "heavy", 13,
                     C["sun"] if extra else C["textFaint"])
    q = reward.get("quests") or {}
    fx, fy = card(1)
    st.medallion("star", fx + 6 + ps / 2, fy + (4 if narrow else 8) + ps / 2, ps, C["sun"])
    tx = 46 if narrow else 56
    lines = []
    for c in q.get("changed") or []:
        lines.append(("DONE! " if c["done"] else "") + c["text"] + "  %d/%d" % (c["progress"], c["goal"]) + (("  +%d" % c["gems"]) if c["done"] else ""))
    if not lines:
        lines.append("No quest progress this time")
    if q.get("chest"):
        lines.insert(0, "ALL QUESTS DONE: free Explorer Chest!")
    st.label(fx + tx, fy + (2 if narrow else 8), cwid - (tx + 6), 18, "DAILY QUESTS", "chunky", 13 if narrow else 15, C["text"])
    st.label(fx + tx, fy + (20 if narrow else 28), cwid - (tx + 6), chh - (22 if narrow else 30), ("  ·  " if narrow else "\n").join(lines),
             "heavy", 11 if narrow else 12, C["sun"] if q.get("gems", 0) > 0 else C["textSoft"], wrap=True, valign="top", truncate=True)
    tr = reward.get("trophies")
    fx, fy = card(2)
    ranks = scr["ranks"]
    rank = None
    if tr:
        for rr in ranks:
            if tr["total"] >= rr["min"]:
                rank = rr
    st.medallion("crown", fx + 6 + ps / 2, fy + (4 if narrow else 8) + ps / 2, ps, rank["color"] if rank else C["steel"])
    if tr:
        d = tr.get("delta", 0)
        head = ("+" if d >= 0 else "") + "%d TROPHIES" % d
        sub = "%d  ·  %s" % (tr["total"], rank["name"] if rank else "") + ("  RANK UP!" if tr.get("rankUp") else "")
    else:
        head = "TROPHIES"
        sub = "Team and event games aren't ranked" if res["kind"] == "public" else "Only Quick Play counts"
    hc = C["sun"] if tr and tr.get("delta", 0) > 0 else (C["badSoft"] if tr and tr.get("delta", 0) < 0 else C["text"])
    st.label(fx + tx, fy + (2 if narrow else 8), cwid - (tx + 6), 20, head, "chunky", 14 if narrow else 17, hc)
    st.label(fx + tx, fy + (22 if narrow else 32), cwid - (tx + 6), chh - (22 if narrow else 32), sub, "heavy", 11 if narrow else 13,
             C["sun"] if tr and tr.get("rankUp") else C["textSoft"], wrap=True, valign="top")


# ----------------------------------------------------------------------------- chests
RARITY_ORDER = ["common", "rare", "epic", "legendary", "mythic"]


def chest_art(st, look, x, y, size):
    """Chests.art: the base (body, trim bands, lock plate, gem) and the lid (rounded top,
    trim bands, the band along its rim), all flat Shapes."""
    P = lambda v: v * size  # noqa: E731

    def r(cx, cy, w, h, col, rr=0.0):
        st.rect(x + P(cx - w / 2), y + P(cy - h / 2), P(w), P(h), col, corner=rr)
    r(0.5, 0.6825, 0.8, 0.395, look["body"])
    r(0.27, 0.6825, 0.09, 0.395, look["trim"])
    r(0.73, 0.6825, 0.09, 0.395, look["trim"])
    r(0.5, 0.58, 0.17, 0.15, look["trim"], 0.2)
    st.circle(x + P(0.5), y + P(0.58), P(0.075), look["gem"])
    r(0.5, 0.375, 0.8, 0.22, look["body"], 0.4)
    r(0.5, 0.43, 0.8, 0.11, look["body"])
    r(0.27, 0.375, 0.09, 0.22, look["trim"])
    r(0.73, 0.375, 0.09, 0.22, look["trim"])
    r(0.5, 0.4675, 0.8, 0.035, look["band"])


def pct(v):
    if abs(v - math.floor(v + 0.5)) < 0.05:
        return "%d%%" % math.floor(v + 0.5)
    return "%.1f%%" % v


def odds_strip(st, scr, chest, x, y, w):
    """Chests oddsStrip: coloured segments (min 6 px, 3 px apart), then a legend whose
    entries wrap whole, each line centred."""
    C = st.C
    rar = {r["id"]: r for r in scr["rarities"]}
    odds = chest["odds"]
    sx = x
    entries = []
    for rid in RARITY_ORDER:
        v = odds.get(rid, 0)
        if v > 0:
            seg = max(6, v / 100 * w - 3)
            st.rect(sx, y, seg, 12, rar[rid]["color"], corner=0.5)
            sx += seg + 3
            label = "%s %s" % (rar[rid]["name"], pct(v))
            entries.append((rar[rid]["color"], label, 8 + 4 + st.text_size(label, "heavy", 12)))
    lines, cur = [], []
    for e in entries:
        if cur and sum(c[2] for c in cur) + 12 * len(cur) + e[2] > w:
            lines.append(cur)
            cur = []
        cur.append(e)
    lines.append(cur)
    for li, line in enumerate(lines):
        lw = sum(c[2] for c in line) + 12 * (len(line) - 1)
        ex = x + (w - lw) / 2
        ey = y + 18 + li * 16
        for col, label, ew in line:
            st.circle(ex + 4, ey + 8, 8, col)
            st.label(ex + 12, ey, ew - 12, 16, label, "heavy", 12, C["textSoft"])
            ex += ew + 12


def chests_page(data, scr, out):
    dev = pc(scr)
    m = dev["m"]
    st = lobby_screen(data, scr, dev)
    C = st.C
    room_w, room_h, narrow = room(m)
    w, h = (room_w, min(720, room_h)) if narrow else (900, 580)
    (cx, cy, cw, ch), ox, oy, scale, bw, bh = modal_frame(st, m, w, h, title="Treasure Chests", title_w=min(320, room_w - 60))
    prof = scr["profile"]
    with st.at(ox, oy, scale):
        st.medallion("gem", cx + 18, cy + 2 + 18, 36, C["neutral"])
        st.label(cx + 44, cy, 200, 40, commas(prof["gems"]), "chunky", 28, C["text"])
        nx = 250 if not narrow else 150
        st.label(cx + nx, cy, cw - nx, 40, "Gems come from playing matches. Duplicates turn back into Gems.", "heavy", 12 if narrow else 15,
                 C["textSoft"], align="right", wrap=narrow)
        n = len(scr["chests"])
        card_w = cw / 2 - 10
        total = n * card_w + (n - 1) * 20
        for i, chest in enumerate(scr["chests"]):
            x = cx + (cw - total) / 2 + i * (card_w + 20)
            y = cy + 50
            hh = ch - 50
            st.rect(x, y, card_w, hh, C["panelRaised"], corner=14, stroke=(C["panelEdge"], 2))
            chest_art(st, chest["look"], x + card_w / 2 - 85, y + 6, 170)
            st.label(x, y + 176, card_w, 30, chest["name"], "chunky", 26, C["text"], align="center")
            st.label(x + 15, y + 206, card_w - 30, 38, chest["blurb"], "heavy", 15, C["textSoft"], align="center", wrap=True)
            st.label(x + 15, y + 246, card_w - 30, 18, chest["pity"], "heavy", 14, "#B9A4E6", align="center")
            odds_strip(st, scr, chest, x + 20, y + 278, card_w - 40)
            bw2 = (card_w - 30) / 2 - 6
            by = y + hh - 50 - 52
            free = prof.get("freeChests", 0) if chest["id"] == "explorer" else 0
            if free > 0:
                button(st, x + 15, by, bw2, 52, text="OPEN FREE", icon="chest", style="green", text_size=20)
            else:
                button(st, x + 15, by, bw2, 52, text=str(chest["price"]), icon="gem", style="brass", text_size=20)
            button(st, x + 15 + bw2 + 12, by, bw2, 52, text="x10  " + commas(chest["tenPrice"]), icon="gem", style="purple",
                   text_size=18)
            button(st, x + card_w / 2 - 70, y + hh - 8 - 36, 140, 36, text="SEE ODDS", style="parchment", text_size=15)
    save(st, dev, out)


# ----------------------------------------------------------------------------- loading
LOADING_PIPS = [[(0.5, 0.5)], [(0.28, 0.28), (0.72, 0.72)], [(0.28, 0.28), (0.5, 0.5), (0.72, 0.72)],
                [(0.28, 0.28), (0.72, 0.28), (0.28, 0.72), (0.72, 0.72)],
                [(0.28, 0.28), (0.72, 0.28), (0.5, 0.5), (0.28, 0.72), (0.72, 0.72)],
                [(0.28, 0.25), (0.72, 0.25), (0.28, 0.5), (0.72, 0.5), (0.28, 0.75), (0.72, 0.75)]]


def loading_screen(scr, dev, out):
    """first/Loading.client.lua: everything in scale of the real screen (it runs before
    the game's UI and its stage scale exist), with its colours copied from Theme."""
    from screens import Stage, background
    W, H = dev["w"], dev["h"]
    ss = 2 if W >= 1000 else 4
    st = Stage(W, H, ss=ss, theme=scr["theme"])
    C = st.C
    background(st)  # the same table and dots as Root.buildBackground
    # the title: TextScaled (Roblox caps it at 100), sun with a 5 px outline, tilted -3
    tw, th = 0.6 * W, 0.15 * H
    st.label(W / 2 - tw / 2, 0.34 * H - th / 2, tw, th, "TRAPISQUE", "chunky", 100, C["sun"], align="center", scaled=True,
             max_size=100, min_size=1, outline=C["line"], outline_t=5, rot=-3)
    d = 0.1 * H
    for x, face in ((0.44, 5), (0.56, 2)):
        cx, cy = x * W, 0.56 * H
        st.rect(cx - d / 2, cy - d / 2, d, d, C["cream"], corner=0.22, stroke=(C["line"], 4))
        for px, py in LOADING_PIPS[face - 1]:
            st.circle(cx - d / 2 + px * d, cy - d / 2 + py * d, 0.18 * d, C["line"])
    sw, sh = 0.5 * W, 0.04 * H
    st.label(W / 2 - sw / 2, 0.68 * H, sw, sh, "Setting up the board...", "regular", 100, C["textSoft"], align="center",
             scaled=True, max_size=100, min_size=1)
    img = st.img.resize((W * (2 if W < 1000 else 1), H * (2 if W < 1000 else 1)), resample=3)
    img.convert("RGB").save(out)
    print("wrote", out, img.size)


def main():
    src, outdir = sys.argv[1], sys.argv[2]
    data, scr = load(src)
    for dev in scr["devices"]:
        if dev["file"] in ("pc", "phone-portrait"):
            loading_screen(scr, dev, os.path.join(outdir, "17-loading-%s.png" % dev["file"]))
    scr["theme"]["_charNames"] = {k: v["name"] for k, v in scr["characters"].items()}
    chests_page(data, scr, os.path.join(outdir, "09-treasure-chests.png"))
    character_select(data, scr, os.path.join(outdir, "14-characters-pc.png"))
    quests_page(data, scr, os.path.join(outdir, "15-quests-pc.png"))
    results_page(data, scr, os.path.join(outdir, "16-results-pc.png"))


if __name__ == "__main__":
    main()
