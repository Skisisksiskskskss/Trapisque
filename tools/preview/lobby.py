#!/usr/bin/env python3
"""The lobby at real device sizes (developer preview tool).

The arrangement comes from the game's Layout.lobby (dumped per device by
tests/dump_screens.luau) and each panel is drawn the way its Lua builds it:

  LobbyScreen       the title, the profile chip (avatar, name, title, level and XP,
                    Gems, trophies and rank; the slim chip in the top bar on phones held
                    sideways), the menu with the FREE CHEST and QUESTS badges, the
                    Play / Party / Top tabs on upright phones
  PlayPanel         your character strip (CharacterSelect.strip), this week's event as a
                    wide tile, the classic modes (2 x 2, or all five in a row when
                    compact; blurbs only on tiles tall enough), FIND A MATCH, PRACTICE
                    and PRIVATE MATCH
  PartyPanel        a party of three: the code, Code / Invite only, members with the
                    leader's tools, INVITE and LEAVE
  LeaderboardPanel  the Trophies board, medals for the top three, your row, the footer

Usage: python3 tools/preview/lobby.py <dir with board.json, cards.json, screens.json> <outdir>
Writes 08-lobby-<device>.png and 08-lobby-phone-portrait-top-players.png.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from screens import (WHITE, mix, button, icon_button, badge, progress, panel, choice, portrait)  # noqa: E402
from hud import load, new_stage, save, roblox_chrome  # noqa: E402


def R(r):
    return r["x"], r["y"], r["w"], r["h"]


def commas(n):
    return format(int(n), ",")


def title_plate(st, x, y, h, look, size=12):
    """CosmeticArt.title with a text size: the title on a small plate (C.engrave) that
    hugs it (8 px padding each side)."""
    C = st.C
    tw = st.text_size(look["text"], "heavy", size)
    st.rect(x, y, tw + 16, h, C["engrave"], corner=6)
    st.label(x + 8, y, tw, h, look["text"], "heavy", size, look["color"])


# ----------------------------------------------------------------------------- profile
def profile_full(st, r, prof):
    C = st.C
    x, y, w, h = R(r)
    st.rect(x, y, w, h, C["panel"], corner=14, stroke=(C["line"], 3))
    av = h - 20
    portrait(st, {"userId": prof["userId"]}, x + 10 + av / 2, y + h / 2, av, ring=C["sun"], ring_px=3)
    tx = av + 20
    st.label(x + tx, y + h / 2 - 27, w - (tx + 150), 20, prof["name"], "heavy", 18, C["text"], truncate=True)
    if prof.get("title"):
        title_plate(st, x + tx, y + h / 2 - 6, 18, prof["title"])
    else:
        st.label(x + tx, y + h / 2 - 6, w - (tx + 150), 18, "@" + prof["username"], "body", 13, C["textSoft"])
    st.label(x + tx, y + h / 2 + 13, 40, 16, "LV %d" % prof["level"], "chunky", 14, C["infoSoft"])
    progress(st, x + tx + 44, y + h / 2 + 17, w - (tx + 44 + 150), 8, prof["xp"] / max(1, prof["xpNext"]), C["info"])
    # Gems (right-aligned row of 130 x 26 at 32% of the height)
    gtext = commas(prof["gems"])
    gw = st.text_size(gtext, "chunky", 22)
    gy = y + 0.32 * h
    st.medallion("gem", x + w - 16 - 11, gy, 22, C["neutral"])
    st.label(x + w - 16 - 22 - 6 - gw, gy - 13, gw, 26, gtext, "chunky", 22, C["text"], align="right")
    # trophies and rank (140 x 22 at 74%)
    rank = prof["rank"]
    ttext = rank["name"] + "  " + commas(prof["trophies"])
    tw = st.text_size(ttext, "chunky", 16)
    ty = y + 0.74 * h
    st.medallion("crown", x + w - 16 - 10, ty, 20, rank["color"])
    st.label(x + w - 16 - 20 - 6 - tw, ty - 10, tw, 20, ttext, "chunky", 16, C["text"], align="right")


def profile_compact(st, r, prof):
    C = st.C
    x, y, w, h = R(r)
    st.rect(x, y, w, h, C["panel"], corner=h / 2, stroke=(C["line"], 2.5))
    av = h - 8
    portrait(st, {"userId": prof["userId"]}, x + 4 + av / 2, y + h / 2, av, ring=C["sun"], ring_px=2)
    tx = av + 12
    st.label(x + tx, y, w - (tx + 170), h, prof["name"], "heavy", 15, C["text"], truncate=True)
    st.label(x + w - 108 - 52, y + h / 2 - 10, 52, 20, "LV %d" % prof["level"], "chunky", 14, C["infoSoft"], align="right")
    gtext = commas(prof["gems"])
    gw = st.text_size(gtext, "chunky", 18)
    st.medallion("gem", x + w - 12 - 9, y + h / 2, 18, C["neutral"])
    st.label(x + w - 12 - 18 - 6 - gw, y + h / 2 - 11, gw, 22, gtext, "chunky", 18, C["text"], align="right")


# ----------------------------------------------------------------------------- play panel
def character_strip(st, x, y, w, h, scr, compact):
    """CharacterSelect.strip: mascot, name, mastery level and bar, CHANGE."""
    C = st.C
    T = st.theme
    prof = scr["profile"]
    cid = prof["character"]
    ms = scr["mastery"][cid]
    st.rect(x, y, w, h, C["panelRaised"], corner=12, stroke=(C["line"], 2.5))
    ps = h - 8
    st.medallion(cid, x + 6 + ps / 2, y + 4 + ps / 2, ps, T["Character"].get(cid, C["grape"]))
    bw = 84 if compact else 108
    bh = min(40, h - 14)
    button(st, x + w - 8 - bw, y + h / 2 - bh / 2, bw, bh, text="CHANGE", style="purple", text_size=13 if compact else 16,
           depth=3, corner=10)
    tx = ps + 14
    st.label(x + tx, y + (3 if compact else 6), w - (tx + bw + 16), 18 if compact else 24,
             scr["characters"][cid]["name"].upper(), "chunky", 16 if compact else 20, C["text"], outline=C["line"], outline_t=2)
    sub = "Mastery %d" % ms["level"] + ("  ·  %d / %d XP" % (ms["into"], ms["need"]) if ms.get("need") else "  ·  MAX")
    st.label(x + tx, y + (21 if compact else 30), w - (tx + bw + 16), 14, sub, "heavy", 11 if compact else 13, C["textSoft"])
    progress(st, x + tx, y + h - (10 if compact else 14), w - (tx + bw + 20), 6 if compact else 8,
             ms["into"] / max(1, ms["need"]) if ms.get("need") else 1, T["Character"].get(cid, C["sun"]))


def player_range(mode):
    if mode["minPlayers"] == mode["maxPlayers"]:
        return "%d players" % mode["maxPlayers"]
    return "%d-%d players" % (mode["minPlayers"], mode["maxPlayers"])


def event_tile(st, x, y, w, h, mode, event, selected):
    """PlayPanel:_eventTile: a stripe of the event's colour, a star medallion, the name
    and its twist."""
    C = st.C
    color = event["color"]
    st.rect(x, y, w, h, C["mine"] if selected else C["panelRaised"], corner=12,
            stroke=(C["sun"], 3.5) if selected else (C["line"], 2.5))
    st.rect(x, y, 10, h, color, corner=6)
    st.medallion("star", x + 20 + 20, y + h / 2, 40, color)
    st.label(x + 70, y + 8, w - 80, 22, "WEEKLY EVENT: " + event["name"].upper(), "chunky", 19, color, outline=C["line"],
             outline_t=2, truncate=True)
    st.label(x + 70, y + 32, w - 80, h - 36, event["blurb"] + "  ·  " + player_range(mode), "body", 14, C["text"], wrap=True,
             valign="top", scaled=True, max_size=14, min_size=9)


def mode_tile(st, x, y, w, h, mode, compact, selected, event=None):
    """PlayPanel:_modeTile (the blurb hides on tiles too short for it)."""
    C = st.C
    st.rect(x, y, w, h, C["mine"] if selected else C["panelRaised"], corner=12,
            stroke=(C["sun"], 3.5) if selected else (C["line"], 2.5))
    pad = 8 if compact else 12
    isz = 24 if compact else 34
    icon = "star" if mode["isEvent"] else ("people" if mode["isTeam"] else "bolt")
    st.medallion(icon, x + pad + isz / 2, y + pad + isz / 2, isz, C["pink"] if mode["isEvent"] else C["sun"])
    tx = pad + isz + 8
    name = (("Event" if compact else event["name"]) if event else (mode["short"] if compact else mode["name"]))
    st.label(x + tx, y + (8 if compact else 10), w - (tx + pad), 22 if compact else 24, name, "chunky", 17 if compact else 20,
             C["text"], scaled=True, max_size=17 if compact else 20, min_size=8)
    if compact:
        st.label(x + pad, y + 36, w - 2 * pad, 16, player_range(mode), "heavy", 12, C["textSoft"])
    else:
        st.label(x + tx, y + 34, w - (tx + pad), 16, player_range(mode), "heavy", 13, C["textSoft"])
    top = 56 if compact else 58
    if h >= top + pad + 30:
        blurb = event["blurb"] if event else mode["blurb"]
        st.label(x + pad, y + top, w - 2 * pad, h - (top + pad), blurb, "body", 13 if compact else 15, C["text"], wrap=True,
                 valign="top", scaled=compact, max_size=13, min_size=9)


def play_panel(st, r, scr, compact, titled=True):
    C = st.C
    x, y, w, h = R(r)
    cx, cy, cw, ch = panel(st, x, y, w, h, title="Play" if titled else None, title_w=200, pad=12 if compact else 18)
    find_h, small_h = (50, 42) if compact else (58, 48)
    buttons_h = find_h + 8 + small_h
    strip_h = 44 if compact else 62
    character_strip(st, cx, cy, cw, strip_h, scr, compact)
    top = strip_h + (8 if compact else 12)
    modes = scr["modes"]
    classic = [m for m in modes if not m["isEvent"]]
    event_mode = next((m for m in modes if m["isEvent"]), None)
    selected = "chaos"
    if event_mode and not compact:
        event_tile(st, cx, cy + top, cw, 66, event_mode, scr["event"], selected == event_mode["id"])
        top += 66 + 12
    gx, gy, gw, gh = cx, cy + top, cw, ch - (buttons_h + 12 + top)
    tiles = list(classic)
    if compact:
        if event_mode:
            tiles = [event_mode] + tiles  # LayoutOrder 0
        n = len(tiles)
        tw, th = gw / n - 12 * (n - 1) / n, gh
        for i, mode in enumerate(tiles):
            mode_tile(st, gx + i * (tw + 12), gy, tw, th, mode, True, mode["id"] == selected,
                      scr["event"] if mode["isEvent"] else None)
    else:
        tw, th = gw / 2 - 6, gh / 2 - 6
        for i, mode in enumerate(tiles):
            mode_tile(st, gx + (i % 2) * (tw + 12), gy + (i // 2) * (th + 12), tw, th, mode, False, mode["id"] == selected)
    by = cy + ch - buttons_h
    party = scr.get("party")
    leader = True
    button(st, cx, by, cw, find_h, text="FIND A MATCH", icon="play", style="green", text_size=22 if compact else 26, depth=6,
           enabled=leader)
    sy = by + buttons_h - small_h
    button(st, cx, sy, cw / 2 - 6, small_h, text="PRACTICE", icon="dice", style="wood", text_size=16 if compact else 19,
           enabled=party is None or len(party["members"]) <= 1)
    button(st, cx + cw / 2 + 6, sy, cw / 2 - 6, small_h, text="PRIVATE" if compact else "PRIVATE MATCH", icon="people",
           style="blue", text_size=16 if compact else 19, enabled=party is not None and leader)


# ----------------------------------------------------------------------------- party
PARTY = {
    "code": "K7QX4M",
    "privacy": "code",
    "max": 6,
    "members": [
        {"name": "Explorer", "username": "explorer_42", "me": True, "leader": True},
        {"name": "Mika", "username": "mika_plays"},
        {"name": "Jojo", "username": "jojo_rbx"},
    ],
}


def party_panel(st, r, compact, titled=True):
    C = st.C
    T = st.theme
    x, y, w, h = R(r)
    cx, cy, cw, ch = panel(st, x, y, w, h, title="Party" if titled else None, title_w=200, pad=12 if compact else 18)
    code_h, buttons_h = (54, 42) if compact else (64, 48)
    st.rect(cx, cy, cw, code_h, C["panelDeep"], corner=10, stroke=(C["panelEdge"], 2))
    st.label(cx + 12, cy + (4 if compact else 6), cw * 0.55, 16, "PARTY CODE", "heavy", 11 if compact else 13, C["textSoft"])
    st.label(cx + 12, cy + (20 if compact else 24), cw * 0.55, 30 if compact else 34, PARTY["code"], "chunky",
             26 if compact else 30, C["brassLight"])
    choice(st, cx + cw - 10 - (cw * 0.42 - 10), cy + code_h / 2 - 19, cw * 0.42 - 10, 38, [("Code", "code"), ("Invite only", "invite")],
           PARTY["privacy"], text_size=15)
    # members (a scrolling list between the code and the buttons; it clips)
    lx, ly, lw, lh = cx, cy + code_h + 8, cw, ch - (code_h + 8) - (buttons_h + 10)
    rh = 38 if compact else 44
    av = rh - 8
    with st.layer(clip=(lx, ly, lw, lh)):
        my = ly + 2
        rw = (lw - 4) - 10
        rx = lx + 2 + 5
        for i, m in enumerate(PARTY["members"]):
            mine = m.get("me")
            st.rect(rx, my, rw, rh, C["mine"] if mine else C["panelRaised"], corner=10,
                    stroke=(C["brassDark"] if mine else C["panelEdge"], 1.5))
            portrait(st, {"userId": 1000 + i}, rx + 5 + av / 2, my + rh / 2, av, ring=T["Seat"][i % 6], ring_px=2)
            nx = av + 14
            if m.get("leader"):
                st.icon("crown", rx + nx, my + (rh - 22) / 2, 22, {"ink": C["brass"], "bg": C["panel"], "acc": C["brass"],
                                                                  "acc2": C["brass"], "hi": C["panel"]})
                nx += 28
            st.label(rx + nx, my + (2 if compact else 4), rw - (nx + 100), 18, m["name"] + ("  (you)" if mine else ""), "heavy",
                     15 if compact else 16, C["text"], truncate=True)
            st.label(rx + nx, my + (20 if compact else 24), rw - (nx + 100), 15, "@" + m["username"], "body", 11 if compact else 12,
                     C["textSoft"], truncate=True)
            if not mine:
                bh = rh - 10
                icon_button(st, rx + rw - 6 - 38 - 6 - 38, my + 5, 38, bh, "crown", style="brass")
                icon_button(st, rx + rw - 6 - 38, my + 5, 38, bh, "close", style="red")
            my += rh + 6
        left = PARTY["max"] - len(PARTY["members"])
        st.label(lx + 2, my, lw - 4, 20, "%d more can join" % left, "body", 14, C["textFaint"], align="center")
    by = cy + ch - buttons_h
    button(st, cx, by, cw * 0.62 - 6, buttons_h, text="INVITE", icon="plus", style="blue", text_size=18)
    button(st, cx + cw - (cw * 0.38 - 6), by, cw * 0.38 - 6, buttons_h, text="LEAVE", icon="exit", style="red", text_size=18)


def scrollbar(st, x, y, w, h, canvas_h):
    """Widgets.scroll: an 8 px thumb (panelEdge, 0.2 transparent) along the right edge
    when the list is longer than its window (scrolled to the top here)."""
    if canvas_h <= h + 0.5:
        return
    th = h * h / canvas_h
    st.rect(x + w - 8, y, 8, th, st.C["panelEdge"], corner=0.5, alpha=0.8)


# ----------------------------------------------------------------------------- leaderboard
LEADERS = [("Marlo", "marlo_the_great", 1312), ("Juniper", "junibug", 1105), ("Pipsqueak", "pipsqueak77", 980),
           ("Rowan", "rowan_rbx", 874), ("Nib", "nibbles", 701), ("Explorer", "explorer_42", 604), ("Fennel", "fennelfox", 588),
           ("Quill", "quillpen", 553), ("Tamsin", "tamsin_t", 519), ("Odo", "odo_plays", 496)]
MEDALS = ["#E2B53C", "#B8C0C8", "#C98A4B"]


def leaderboard(st, r, titled=True):
    C = st.C
    x, y, w, h = R(r)
    cx, cy, cw, ch = panel(st, x, y, w, h, title="Top Players" if titled else None, title_w=220)
    choice(st, cx, cy, cw, 38, [("Trophies", "trophies"), ("Wins", "wins"), ("Treasures", "treasures"), ("Level", "level")],
           "trophies", text_size=16)
    lx, ly, lw, lh = cx, cy + 46, cw, ch - 46 - 40
    with st.layer(clip=(lx, ly, lw, lh)):
        ry = ly + 2
        rw = (lw - 4) - 10
        rx = lx + 2 + 5
        for i, (name, user, value) in enumerate(LEADERS):
            rank = i + 1
            mine = name == "Explorer"
            st.rect(rx, ry, rw, 46, C["mine"] if mine else C["panelRaised"], corner=10,
                    stroke=(C["brass"], 2) if mine else (C["panelEdge"], 1.5))
            medal = MEDALS[i] if i < 3 else None
            if medal:
                st.circle(rx + 6 + 14, ry + 23, 28, medal, stroke=(mix(medal, "#000000", 0.35), 2))
            st.label(rx + 6, ry + 9, 28, 28, str(rank), "chunky", 14 if rank >= 10 else 17,
                     C["textOnLight"] if medal else C["textSoft"], align="center")
            portrait(st, {"userId": 2000 + i}, rx + 40 + 17, ry + 23, 34, ring=C["brass"] if mine else C["panelEdge"], ring_px=2)
            nw = rw - (82 + 58 + 12)
            st.label(rx + 82, ry + 4, nw, 20, name + (" (you)" if mine else ""), "heavy", 15, C["text"], truncate=True)
            st.label(rx + 82, ry + 25, nw, 16, "@" + user, "body", 12, C["textSoft"], truncate=True)
            st.label(rx + rw - 10 - 58, ry + 10, 58, 26, commas(value), "chunky", 18, medal or C["text"], align="right")
            ry += 46 + 5
        scrollbar(st, lx, ly, lw, lh, 2 + len(LEADERS) * 46 + (len(LEADERS) - 1) * 5 + 2)
    st.label(cx, cy + ch - 32, cw, 32, "You're #6 with 604 trophies", "heavy", 15, C["textSoft"], align="center", wrap=True)


# ----------------------------------------------------------------------------- menu
NAV = [("chests", "CHESTS", "CHESTS", "chest", "brass"), ("quests", "QUESTS", "QUESTS", "star", "orange"),
       ("locker", "LOCKER", "LOCKER", "hanger", "wood"), ("shop", "SHOP", "SHOP", "bag", "wood"),
       ("leaders", "TOP PLAYERS", "TOP", "crown", "wood"), ("rules", "HOW TO PLAY", "RULES", "book", "wood"),
       ("settings", "SETTINGS", "SETTINGS", "gear", "wood")]


def nav(st, spec, with_leaders, prof):
    C = st.C
    x, y, w, h = R(spec["rect"])
    items = [n for n in NAV if n[0] != "leaders" or with_leaders]
    n = len(items)
    gap = 14 if spec["kind"] == "full" else 8
    bw = w / n - gap * (n - 1) / n
    free = prof.get("freeChests", 0)
    quests_left = sum(1 for q in prof["quests"] if not q["done"])
    for i, (nid, text, short, icon, style) in enumerate(items):
        bx = x + i * (bw + gap)
        if nid == "chests" and free > 0:
            style = "green"
            text = short = "FREE CHEST!"
        count = str(free) if (nid == "chests" and free > 0) else (str(quests_left) if (nid == "quests" and quests_left > 0) else None)
        if spec["kind"] == "icon":
            size = min(h - 18, math.floor(bw - 4))
            ix = bx + (bw - size) / 2
            icon_button(st, ix, y, size, size, icon, style=style)
            label = short if nid != "chests" else "CHESTS"
            st.label(bx, y + h - 14, bw, 14, label, "heavy", 11, C["text"], align="center", outline=C["bg"], outline_t=2)
            if count:
                badge(st, ix + size + 6, y - 8, count, C["bad"], height=22, text_size=14, anchor=(1, 0))
        else:
            ts = 19 if spec["kind"] == "full" else (13 if n >= 7 else 15)
            button(st, bx, y, bw, h, text=text if spec["kind"] == "full" else short, icon=icon, style=style, text_size=ts)
            if count:
                badge(st, bx + bw + 6, y - 8, count, C["bad"], height=22, text_size=14, anchor=(1, 0))


# ----------------------------------------------------------------------------- screen
def lobby_screen(data, scr, dev, out=None, tab="play"):
    m, L = dev["m"], dev["lobby"]
    st = new_stage(data, scr, m)
    C = st.C
    prof = scr["profile"]
    scr = dict(scr)
    scr["party"] = PARTY
    if L.get("title"):
        t = L["title"]
        st.label(t["x"], t["y"], t["w"], t["h"], "Trapisque", "display", math.floor(min(60, t["h"] * 0.86)), C["sun"],
                 align="center" if L["form"] == "tall" else "left", outline=C["bg"], outline_t=3 if t["h"] >= 60 else 2)
    if L["profile"]["kind"] == "compact":
        profile_compact(st, L["profile"]["rect"], prof)
    else:
        profile_full(st, L["profile"]["rect"], prof)
    if L.get("tabs"):
        tr = L["tabs"]
        choice(st, tr["x"], tr["y"], tr["w"], tr["h"], [("Play", "play"), ("Party", "party"), ("Top", "leaders")], tab, text_size=18)
        if tab == "play":
            play_panel(st, L["play"], scr, False, titled=False)
        elif tab == "party":
            party_panel(st, L["party"], False, titled=False)
        else:
            leaderboard(st, L["leaders"], titled=False)
    else:
        play_panel(st, L["play"], scr, L["compact"], titled=not L["compact"])
        party_panel(st, L["party"], L["compact"], titled=not L["compact"])
        if L.get("leaders"):
            leaderboard(st, L["leaders"])
    nav(st, L["nav"], L.get("leaders") is None, prof)
    roblox_chrome(st, m)
    if out:
        save(st, dev, out)
    return st


def main():
    src, outdir = sys.argv[1], sys.argv[2]
    data, scr = load(src)
    for dev in scr["devices"]:
        lobby_screen(data, scr, dev, os.path.join(outdir, "08-lobby-%s.png" % dev["file"]))
        if dev["lobby"].get("tabs"):
            lobby_screen(data, scr, dev, os.path.join(outdir, "08-lobby-%s-top-players.png" % dev["file"]), tab="leaders")


if __name__ == "__main__":
    main()
