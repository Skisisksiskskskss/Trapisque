#!/usr/bin/env python3
"""Reading and playing a card, on the PC match screen (developer preview tool).

Built on the match screen from hud.py (same Layout rects, board and HUD), with what the
Lua draws at those moments:

  11-card-hover-pc.png  hovering a card in your hand (HandView raises it 8 px) and
                        CardTip:show: the card big above it and its rules beside it (the
                        name with its medallion and category badge, what it does, how
                        it's played, what a click does right now). CardTip is a
                        CanvasGroup, so it clips what crosses its edges.
  12-placing-pc.png     dragging the card onto the board (MatchScreen:_placeFlow): the
                        tiles the rules allow glow in the card's colour
                        (BoardView:highlight), the tile under the card shows what it will
                        look like (BoardView:previewTile), the card rides beside the
                        pointer shrunk to 0.66 (Overlays.heldCard), its spot in the hand
                        waits empty (HandView:setHeld), the hint strip says what to do.
  13-placing-slam.gif   letting go, cropped around the tile: the glow clears, the card is
                        lifted a touch and slapped down (held:drop), Effects.place's ring
                        and dust go out as the board jolts, then the server's answer
                        turns the preview into the real (see-through) trap.

Usage: python3 tools/preview/moments.py <dir with board.json, cards.json, screens.json> <outdir>
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from screens import WHITE, button, badge, get_font  # noqa: E402
from hud import Match, load, new_stage, save, roblox_chrome  # noqa: E402
from board import BoardScene, UNIT, hexagon, TOP, TILE_COLORS, name_tag  # noqa: E402
from cards import CardPainter, CATEGORY_LABEL  # noqa: E402

GAP = 10
INFO_W = 264
TIP_LABEL = dict(CATEGORY_LABEL, natural="HAZARD")


def cursor(st, x, y):
    """A mouse pointer, so it's clear where the player is pointing."""
    pts = [(0, 0), (0, 17), (4.5, 13), (8, 20), (11, 18.5), (7.5, 12), (13, 12)]
    st.poly([(x + px - 1.2, y + py - 1.2) for px, py in [(p[0] * 1.12, p[1] * 1.12) for p in pts]], "#111111")
    st.poly([(x + px, y + py) for px, py in pts], WHITE)


def card_hint(scr, item, touch=False):
    """MatchScreen:_cardHint on my turn, before I've played a card."""
    info = scr["items"][item]
    click = "Tap" if touch else "Click"
    if info["use"] in ("passive", "none"):
        return "Works by itself: just keep it in your hand.", False
    if info["use"] == "place":
        rng = scr["placing"].get(item, {}).get("range")
        reach = (" within %d tiles of you" % rng) if rng else " anywhere"
        if info.get("hidden"):
            return ("Tap HIDE" if touch else "Click it") + ", or drag it onto a tile" + reach + ". Rivals won't see it!", True
        return ("Tap PLACE" if touch else "Click it") + ", or drag it onto a tile" + reach + ".", True
    if info["use"] == "boost":
        return click + " to play it, then pick your die.", True
    return "", False


def wrapped_h(st, text, kind, size, width):
    f = get_font(kind, st.L(size))
    return len(st._wrap([(text, WHITE)], f, st.L(width), f.getlength(" "))) * size


def card_tip(st, scr, painter, item, anchor, hint, ready):
    """CardTip:show / _arrange, side "up" (a row of cards)."""
    C = st.C
    ax, ay, aw, ah = anchor
    info = scr["items"][item]
    color = st.theme["Category"].get(info["category"], C["brass"])
    card_w = max(116, min(186, math.floor(aw * 1.5)))
    card_h = math.floor(card_w / painter.S["aspect"])
    info_w = min(INFO_W, math.floor(st.w - card_w - 3 * GAP - 16))
    inner = info_w - 24
    # the rules panel's height (AutomaticSize Y, at least min(cardH, 150))
    hh = 10 + 30 + 6 + wrapped_h(st, info["text"], "body", 16, inner)
    if info["how"]:
        hh += 6 + wrapped_h(st, info["how"], "heavy", 13, inner)
    if hint:
        hh += 6 + 2 + 6 + wrapped_h(st, hint, "heavy", 15, inner)
    info_h = max(hh + 12, min(card_h, 150))
    w, h = card_w + GAP + info_w, max(card_h, info_h)
    cx = ax + aw / 2
    rules_right = cx + card_w / 2 + GAP + info_w <= st.w - 8
    card_x = 0 if rules_right else info_w + GAP
    x = cx - card_w / 2 - card_x
    y = ay - 8 - h
    x = max(8, min(x, max(8, st.w - w - 8)))
    y = max(8, min(y, max(8, st.h - h - 8)))
    with st.layer(clip=(x, y, w, h)):
        painter.item_front(st, x + card_x, y + h - card_h, card_w, item)
        ix, iy = x + (card_w + GAP if rules_right else 0), y + h - info_h
        st.rect(ix, iy, info_w, info_h, C["panelDeep"], corner=12, stroke=(C["line"], 3))
        px, py = ix + 12, iy + 10
        st.medallion(item, px + 15, py + 15, 30, color)
        st.label(px + 38, py, inner - 112, 30, info["name"], "chunky", 19, C["text"], truncate=True)
        badge(st, px + inner, py + 15, TIP_LABEL.get(info["category"], ""), color, height=22, text_size=13, anchor=(1, 0.5))
        py += 30 + 6
        th = wrapped_h(st, info["text"], "body", 16, inner)
        st.label(px, py, inner, th, info["text"], "body", 16, C["text"], wrap=True, valign="top")
        py += th
        if info["how"]:
            py += 6
            th = wrapped_h(st, info["how"], "heavy", 13, inner)
            st.label(px, py, inner, th, info["how"], "heavy", 13, C["textSoft"], wrap=True, valign="top")
            py += th
        if hint:
            py += 6
            st.rect(px, py, inner, 2, C["panelEdge"], corner=1, alpha=0.8)
            py += 2 + 6
            th = wrapped_h(st, hint, "heavy", 15, inner)
            st.label(px, py, inner, th, hint, "heavy", 15, C["brassLight"] if ready else C["textFaint"], wrap=True, valign="top")


def base_screen(data, scr, dev, held=None, hovered=None):
    """The match screen at my turn with nothing hovered on the board."""
    mt = Match(data, scr, dev)
    st = new_stage(data, scr, mt.m)
    bs, to_stage = mt.board(st, {"preview": None})
    painter = CardPainter(data["cards"])
    mt.chips(st)
    rects = mt.hand(st, painter, mt.snap["hand"], hovered=hovered, held=held)
    me = mt.players[mt.my_seat]
    return mt, st, bs, to_stage, painter, rects, me


def hover_moment(data, scr, out):
    dev = next(d for d in scr["devices"] if d["file"] == "pc")
    index = 0
    item = scr["snapshot"]["hand"][index]
    mt, st, bs, to_stage, painter, rects, me = base_screen(data, scr, dev, hovered=index)
    turn = scr["turn"]
    mt.power_panel(st, me["character"], me["power"], me["powerCap"])
    mt.dice_tray(st, turn["dice"], None, turn["power"], turn["clock"])
    mt.feed(st, scr["feed"])
    mt.top(st)
    hint, ready = card_hint(scr, item)
    card_tip(st, scr, painter, item, rects[index], hint, ready)
    x, y, w, h = rects[index]
    cursor(st, x + w * 0.55, y + h * 0.42)
    roblox_chrome(st, mt.m)
    save(st, dev, out)


def placing_moment(data, scr, out, item="fire", tile=13):
    dev = next(d for d in scr["devices"] if d["file"] == "pc")
    index = scr["snapshot"]["hand"].index(item)
    mt, st, bs, to_stage, painter, rects, me = base_screen(data, scr, dev, held=index)
    C = st.C
    info = scr["items"][item]
    color = st.theme["Category"].get(info["category"], C["sun"])
    turn = scr["turn"]
    # while a card is being placed it's not "my move" for the dice and the ability
    mt.power_panel(st, me["character"], me["power"], me["powerCap"], my_turn=False)
    mt.dice_tray(st, turn["dice"], None, turn["power"], turn["clock"], hint="")
    mt.feed(st, scr["feed"])
    mt.top(st)
    # the board's glow on the tiles the rules allow, and the preview on the one under the card
    f = mt.L["focus"]
    x0, y0, x1, y1 = bs.tileBox
    s = min(f["w"] / (x1 - x0), f["h"] / (y1 - y0))
    ox, oy = f["x"] + f["w"] / 2 - (x0 + x1) / 2 * s, f["y"] + f["h"] / 2 - (y0 + y1) / 2 * s
    r = bs.style["tileScale"] * UNIT
    with st.at(ox, oy, s):
        for t in scr["placing"][item]["valid"]:
            px, py = bs.pos[t]
            st.poly(hexagon(px, py, r * 1.1, bs.flat), color, alpha=0.5)
        # BoardView:previewTile: a CanvasGroup (GroupTransparency 0.2, scale 1.06) with a
        # rim in the card's colour, the tile top, and the hidden trap as only I'll see it
        px, py = bs.pos[tile]
        k = 1.06
        with st.layer(alpha=0.8):
            st.poly(hexagon(px, py, r * 1.08 * k, bs.flat), color)
            st.poly(hexagon(px, py, r * k, bs.flat), TOP.get(item, TILE_COLORS["normal"]))
            if info.get("hidden"):
                bs.trap_mark(st, {"item": item, "owner": mt.my_seat}, px, py, 0.8 * UNIT * k)
            else:
                bs.plaque(st, item, mt.my_seat, px, py, 0.86 * UNIT * k)
    # the name tag stays over my pawn
    cur = scr["snapshot"]["current"]
    wx, wy, share = bs.rest(cur)
    tx, ty = ox + wx * s, oy + (wy - bs.style["pawn"] * UNIT * 0.62 * share) * s
    name_tag(st, tx, ty - 4, "You", mt.seat_color(cur))
    # the hint strip (MatchScreen:_hint) with CANCEL
    hr = mt.L["hint"]
    hh = max(44, hr["h"])
    st.rect(hr["x"], hr["y"], hr["w"], hh, C["panel"], corner=12, stroke=(C["line"], 3))
    bw = 86 if hr["w"] < 420 else 110
    reach = " within %d tiles" % scr["placing"][item]["range"]
    prompt = "Drop " + info["name"] + " on a glowing tile" + reach + (". Only your team will see it!" if info.get("hidden") else "")
    st.label(hr["x"] + 12, hr["y"], hr["w"] - (24 + (bw + 6)), hh, prompt, "heavy", 13 if hr["w"] < 420 else 16, C["text"], wrap=True)
    button(st, hr["x"] + hr["w"] - 6 - bw, hr["y"] + 6, bw, hh - 12, text="CANCEL", style="red", text_size=15)
    # the card beside the pointer (Overlays.heldCard over a tile it can go on)
    pointer = (ox + px * s + 6, oy + py * s + 4)
    w = max(70, min(120, mt.L["hand"]["card"]["w"]))
    scale = 0.66
    cw = w * scale
    ccx, ccy = pointer[0] + w * 0.42, pointer[1] - w * 0.62
    painter.item_front(st, ccx - cw / 2, ccy - cw / painter.S["aspect"] / 2, cw, item)
    cursor(st, pointer[0], pointer[1])
    roblox_chrome(st, mt.m)
    save(st, dev, out)


def slam_gif(data, scr, out, item="fire", tile=13):
    import random
    from PIL import Image
    dev = next(d for d in scr["devices"] if d["file"] == "pc")
    index = scr["snapshot"]["hand"].index(item)
    mt, st, bs, to_stage, painter, rects, me = base_screen(data, scr, dev, held=index)
    C = st.C
    info = scr["items"][item]
    color = st.theme["Category"].get(info["category"], C["sun"])
    turn = scr["turn"]
    mt.power_panel(st, me["character"], me["power"], me["powerCap"], my_turn=False)
    mt.dice_tray(st, turn["dice"], None, turn["power"], turn["clock"], hint="")
    mt.feed(st, scr["feed"])
    mt.top(st)
    f = mt.L["focus"]
    x0, y0, x1, y1 = bs.tileBox
    s = min(f["w"] / (x1 - x0), f["h"] / (y1 - y0))
    ox, oy = f["x"] + f["w"] / 2 - (x0 + x1) / 2 * s, f["y"] + f["h"] / 2 - (y0 + y1) / 2 * s
    cur = scr["snapshot"]["current"]
    wx, wy, share = bs.rest(cur)
    name_tag(st, ox + wx * s, oy + (wy - bs.style["pawn"] * UNIT * 0.62 * share) * s - 4, "You", mt.seat_color(cur))
    base = st.img.copy()
    r = bs.style["tileScale"] * UNIT
    px, py = bs.pos[tile]
    tx, ty = ox + px * s, oy + py * s
    w = max(70, min(120, mt.L["hand"]["card"]["w"]))
    cw, ch = 520, 330
    cx0 = max(0, min(tx - cw / 2, st.w - cw))
    cy0 = max(0, min(ty - ch * 0.6, st.h - ch))
    frames, durations = [], []
    rnd = random.Random(5)
    dust = []
    for i in range(1, 9):
        a = (i / 8) * math.tau + rnd.random() * 0.4
        dust.append((a, 1.05 * (0.6 + rnd.random() * 0.6)))

    def frame(draw, dur, jolt=(0.0, 0.0)):
        st.img = base.copy()
        draw()
        k = st.ss
        crop = st.img.crop((int((cx0 + jolt[0]) * k), int((cy0 + jolt[1]) * k), int((cx0 + jolt[0] + cw) * k), int((cy0 + jolt[1] + ch) * k)))
        frames.append(crop.resize((cw * 2, ch * 2), resample=Image.LANCZOS).convert("RGB"))
        durations.append(dur)

    def glows():
        with st.at(ox, oy, s):
            for t in scr["placing"][item]["valid"]:
                gx, gy = bs.pos[t]
                st.poly(hexagon(gx, gy, r * 1.1, bs.flat), color, alpha=0.5)

    def ghost():
        with st.at(ox, oy, s):
            k = 1.06
            with st.layer(alpha=0.8):
                st.poly(hexagon(px, py, r * 1.08 * k, bs.flat), color)
                st.poly(hexagon(px, py, r * k, bs.flat), TOP.get(item, TILE_COLORS["normal"]))
                bs.trap_mark(st, {"item": item, "owner": mt.my_seat}, px, py, 0.8 * UNIT * k)

    def card(cx, cy, scale):
        cwid = w * scale
        painter.item_front(st, cx - cwid / 2, cy - cwid / painter.S["aspect"] / 2, cwid, item)

    # 1. over the tile: the card beside the pointer, the tile showing its new look
    for i, (dx, dy) in enumerate([(34, -30), (18, -16), (6, 4)]):
        def f1(dx=dx, dy=dy):
            glows()
            ghost()
            card(tx + dx + w * 0.42, ty + dy - w * 0.62, 0.66)
            cursor(st, tx + dx, ty + dy)
        frame(f1, 400 if i == 2 else 90)

    # 2. let go: the glow clears, the card is lifted a touch (0.09 s) and slapped down (0.07 s)
    def f2():
        ghost()
        card(tx, ty - 14, 0.9)
        cursor(st, tx + 6, ty + 4)
    frame(f2, 90)

    def f3():
        ghost()
        card(tx, ty, 0.45)
        cursor(st, tx + 6, ty + 4)
    frame(f3, 70)

    # 3. Effects.place: a ring (0.7 -> 2.4 tiles, 5 px, fading), cream dust flying out,
    # the board jolting (0.07 tiles for 0.2 s); the preview stays until the server answers
    for t, jolt in ((0.06, (3, -2)), (0.13, (-2, 2)), (0.21, (1, 1)), (0.31, (0, 0)), (0.43, (0, 0))):
        def f4(t=t):
            ghost()
            with st.at(ox, oy, s):
                q = min(1.0, t / 0.45)
                size = (0.7 + (2.4 - 0.7) * (1 - (1 - q) ** 2)) * UNIT
                st.circle(px, py, size, None, stroke=(color, 5, 1 - q * q))
                q2 = min(1.0, t / 0.42)
                e = 1 - (1 - q2) ** 2
                for a, dist in dust:
                    d = dist * UNIT * e
                    dd = 0.14 * UNIT * (1 - 0.8 * e)
                    st.circle(px + math.cos(a) * d, py + 0.25 * UNIT + math.sin(a) * d, dd, C["cream"],
                              stroke=(C["line"], max(1, 0.14 * UNIT * 0.12)))
            cursor(st, tx + 6, ty + 4)
        frame(f4, 60, jolt=jolt if t < 0.2 else (0, 0))

    # 4. the server's answer: the preview goes and the real (see-through) trap pops in
    for scale, dur in ((0.6, 70), (1.08, 70), (1.0, 1400)):
        def f5(scale=scale):
            with st.at(ox, oy, s):
                bs.trap_mark(st, {"item": item, "owner": mt.my_seat}, px, py, 0.8 * UNIT * scale)
            cursor(st, tx + 6, ty + 4)
        frame(f5, dur)
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=True)
    print("wrote", out, frames[0].size, len(frames), "frames")


def main():
    src, outdir = sys.argv[1], sys.argv[2]
    data, scr = load(src)
    hover_moment(data, scr, os.path.join(outdir, "11-card-hover-pc.png"))
    placing_moment(data, scr, os.path.join(outdir, "12-placing-pc.png"))
    slam_gif(data, scr, os.path.join(outdir, "13-placing-slam.gif"))


if __name__ == "__main__":
    main()
