--[[
	Layout
	Where everything goes on screen, for any screen. Pure logic (no Roblox APIs) so it
	can be tested for overlaps at many screen sizes and drawn by the offline previewer.

	Layout.metrics(physW, physH, opts) turns the real screen into the stage the UI is
	built on (Root applies it):
		m.vw, m.vh   stage size in virtual pixels
		m.scale      real pixels per virtual pixel
		m.form       "wide"  PC, laptop, tablet in landscape (stage about 1280 x 720)
		             "short" phone in landscape (stage about 900 x 420)
		             "tall"  phone or tablet held upright (stage 420 or 620 wide)
		m.touch      touch is the main input
		m.safe       { l, t, r, b }  device safe-area insets (notches, home bar)
		m.topbar     { y0, y1, l, r } Roblox's top bar: its top and bottom, where its left
		             buttons end and where its right buttons start (x)

	Every rect is { x, y, w, h } in stage pixels.
]]

local Layout = {}

export type Rect = { x: number, y: number, w: number, h: number }

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = math.max(0, w), h = math.max(0, h) }
end
Layout.rect = rect

function Layout.right(r: Rect): number
	return r.x + r.w
end

function Layout.bottom(r: Rect): number
	return r.y + r.h
end

-- True when two rects share any area (touching edges don't count).
function Layout.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w - 0.01 and b.x < a.x + a.w - 0.01 and a.y < b.y + b.h - 0.01 and b.y < a.y + a.h - 0.01
end

function Layout.inside(a: Rect, outer: Rect): boolean
	return a.x >= outer.x - 0.01
		and a.y >= outer.y - 0.01
		and a.x + a.w <= outer.x + outer.w + 0.01
		and a.y + a.h <= outer.y + outer.h + 0.01
end

---------------------------------------------------------------------------
-- metrics
---------------------------------------------------------------------------

function Layout.metrics(physW: number, physH: number, opts: { [string]: any }?)
	local o = opts or {}
	physW = math.max(physW, 2)
	physH = math.max(physH, 2)
	local aspect = physW / physH
	local form, scale
	if aspect < 0.9 then
		form = "tall"
		scale = physW / (if physW >= 700 then 620 else 420)
	elseif physH < 560 then
		form = "short"
		scale = math.min(physH / 420, physW / 780)
	else
		form = "wide"
		scale = math.min(physH / 720, physW / 980)
	end
	local function v(px: number?): number
		return (px or 0) / scale
	end
	local sp = o.safe or {}
	local tb = o.topbar or {}
	local defaultBar = if form == "wide" then 58 else 48
	return {
		vw = physW / scale,
		vh = physH / scale,
		scale = scale,
		form = form,
		touch = o.touch == true,
		safe = { l = v(sp.l), t = v(sp.t), r = v(sp.r), b = v(sp.b) },
		topbar = {
			y0 = v(tb.y0 or 0),
			y1 = v(tb.y1 or defaultBar),
			l = v(tb.l or 120),
			r = v(tb.r or (physW - 60)),
		},
	}
end

-- The part of the stage the HUD may use: inside the safe area, with a margin.
function Layout.safeRect(m, margin: number?): Rect
	local M = margin or 0
	return rect(m.safe.l + M, m.safe.t + M, m.vw - m.safe.l - m.safe.r - 2 * M, m.vh - m.safe.t - m.safe.b - 2 * M)
end

-- The free middle of Roblox's top bar (between its left and right buttons).
function Layout.bandRect(m, gap: number?): Rect
	local G = gap or 0
	local x0 = math.max(m.topbar.l, m.safe.l) + G
	local x1 = math.min(m.topbar.r, m.vw - m.safe.r) - G
	-- never above the safe area (a status bar or notch can sit over the bar's top)
	local y0 = math.max(m.topbar.y0, m.safe.t)
	local h = m.topbar.y1 - y0
	local inset = math.min(6, math.max(0, h) * 0.12)
	return rect(x0, y0 + inset, x1 - x0, h - 2 * inset)
end

-- Rects Roblox draws its own buttons in (the HUD must keep out of them).
function Layout.coreRects(m): { Rect }
	local h = m.topbar.y1
	return {
		rect(0, 0, m.topbar.l, h),
		rect(m.topbar.r, 0, m.vw - m.topbar.r, h),
	}
end

---------------------------------------------------------------------------
-- match screen
---------------------------------------------------------------------------

--[[
	Layout.match(m, players) -> {
		focus    the board's tiles are fitted into this rect (the map runs on under the HUD)
		players  { rect, dir = "y"|"x", chip = { w, h, kind = "full"|"band"|"stack" }, gap }
		hand     { rect, card = { w, h }, gap }
		ability  rect (character portrait + ability button)
		roll     rect (the big ROLL button; RECALL sits on top of it when you have an anchor)
		info     rect (round and mode)
		buttons  { rect, size, gap, count }
		feed     { rect, lines, align }
		hint     rect (the "pick a tile" strip)
		popup    rect (modals and sheets stay inside this)
	}
]]
function Layout.match(m, players: number)
	local n = math.clamp(players or 4, 1, 6)
	local form = m.form
	local M = if form == "wide" then 12 else 8
	local G = if form == "wide" then 10 else 6
	local safe = Layout.safeRect(m, M)
	local x0, x1 = safe.x, safe.x + safe.w
	local yBottom = safe.y + safe.h
	local barBottom = math.max(m.topbar.y1, m.safe.t)
	local top = math.max(barBottom + G, safe.y)
	local band = Layout.bandRect(m, G)
	local L = { form = form, popup = safe }
	local BUTTONS = 4
	-- smallest button that's still comfortable to click or tap (about 34 real pixels)
	local minButton = math.ceil(34 / m.scale)

	if form == "wide" then
		local colW = 240
		local dockH = 132
		local rollW = 196
		-- top bar: round info on the left of the free band, icon buttons on the right
		local bh = math.min(band.h, 44)
		local by = band.y + (band.h - bh) / 2
		local buttonsW = BUTTONS * bh + (BUTTONS - 1) * 6
		local bandFits = bh >= minButton and band.w >= buttonsW + 200 + G
		local colTop = top
		if bandFits then
			L.buttons = { rect = rect(band.x + band.w - buttonsW, by, buttonsW, bh), size = bh, gap = 6, count = BUTTONS }
			L.info = rect(band.x, by, math.min(360, band.w - buttonsW - G), bh)
		else
			-- no room in the bar: they top the players' column instead (the board keeps its height)
			local bs = math.max(40, minButton)
			L.info = rect(x0, top, colW, 34)
			local bw = BUTTONS * bs + (BUTTONS - 1) * 6
			L.buttons = { rect = rect(x0, top + 34 + 6, bw, bs), size = bs, gap = 6, count = BUTTONS }
			colTop = top + 34 + 6 + bs + G
		end
		local dockY = yBottom - dockH
		L.ability = rect(x0, dockY, colW, dockH)
		L.roll = rect(x1 - rollW, dockY, rollW, dockH)
		local handX = x0 + colW + G
		L.hand = { rect = rect(handX, dockY, (x1 - rollW - G) - handX, dockH), card = { w = 88, h = 122 }, gap = 8 }
		local chipH = 64
		local colH = dockY - G - colTop
		local chipGap = 8
		local fitH = math.floor((colH - (n - 1) * chipGap) / n)
		chipH = math.clamp(fitH, 44, chipH)
		L.players = {
			rect = rect(x0, colTop, colW, n * chipH + (n - 1) * chipGap),
			dir = "y",
			chip = { w = colW, h = chipH, kind = "full" },
			gap = chipGap,
		}
		L.focus = rect(handX, top, x1 - handX, dockY - G - top)
		-- the feed lives in the players' column under the chips (off the board); with a
		-- full table there's little room left, so it falls back to the board's corner
		local feedTop = colTop + L.players.rect.h + 14
		local feedRoom = dockY - G - feedTop
		if feedRoom >= 2 * 30 then
			local lines = math.min(6, math.floor(feedRoom / 30))
			L.feed = { rect = rect(x0, feedTop, colW, lines * 30), lines = lines, align = "left" }
		else
			local feedW = math.min(380, L.focus.w * 0.4)
			L.feed = { rect = rect(x1 - feedW, top, feedW, 3 * 30), lines = 3, align = "right" }
		end
		L.hint = rect(L.focus.x + (L.focus.w - math.min(560, L.focus.w - 20)) / 2, top, math.min(560, L.focus.w - 20), 52)
		return L
	end

	if form == "short" then
		-- landscape phone: height is what's scarce. Players ride in Roblox's top bar, cards
		-- stand in a column on the left (left thumb), actions on the right (right thumb).
		local dockW = 156
		local chipGap = 6
		local chipW = math.min(124, (band.w - (n - 1) * chipGap) / n)
		local bandFits = chipW >= 84 and band.h >= 30
		local chipH = math.clamp(band.h, 30, 46)
		-- right dock: buttons on top, ability, then ROLL at the bottom (under the right thumb)
		local bs = math.max(36, minButton)
		local buttonsW = BUTTONS * bs + (BUTTONS - 1) * 6
		dockW = math.max(dockW, buttonsW)
		local dockX = x1 - dockW
		L.buttons = { rect = rect(x1 - buttonsW, top, buttonsW, bs), size = bs, gap = 6, count = BUTTONS }
		L.info = rect(dockX, top + bs + 4, dockW, 20)
		local rollH = 92
		L.roll = rect(dockX, yBottom - rollH, dockW, rollH)
		local abilityH = 74
		L.ability = rect(dockX, L.roll.y - G - abilityH, dockW, abilityH)
		local cardW = math.max(58, math.ceil(52 / m.scale))
		local cardH = math.ceil(cardW * 1.38)
		if bandFits then
			local rowW = n * chipW + (n - 1) * chipGap
			L.players = {
				rect = rect(band.x + (band.w - rowW) / 2, band.y + (band.h - chipH) / 2, rowW, chipH),
				dir = "x",
				chip = { w = chipW, h = chipH, kind = "band" },
				gap = chipGap,
			}
			-- room on the right for an armed card to slide out towards the board
			local handW = cardW + 18
			L.hand = { rect = rect(x0, top, handW, yBottom - top), dir = "y", card = { w = cardW, h = cardH }, gap = 6 }
			local fx = x0 + handW + G
			L.focus = rect(fx, top, dockX - G - fx, yBottom - top)
		else
			-- no room in the bar: players get a narrow column and the cards go along the bottom
			local colW = 112
			chipH = math.clamp(math.floor((yBottom - top - (n - 1) * chipGap) / n), 34, 46)
			L.players = {
				rect = rect(x0, top, colW, n * chipH + (n - 1) * chipGap),
				dir = "y",
				chip = { w = colW, h = chipH, kind = "band" },
				gap = chipGap,
			}
			local leftX = x0 + colW + G
			local handH = cardH + 4
			L.hand = { rect = rect(leftX, yBottom - handH, dockX - G - leftX, handH), dir = "x", card = { w = cardW, h = cardH }, gap = 6 }
			L.focus = rect(leftX, top, dockX - G - leftX, L.hand.rect.y - G - top)
		end
		-- the feed fills the gap in the right dock (between the round and the ability),
		-- so it never covers the board; only if that gap is too small does it float on top
		local gapTop = L.info.y + L.info.h + G
		local gapH = L.ability.y - G - gapTop
		if gapH >= 48 then
			-- a narrow column: an entry may wrap onto two lines
			local lines = math.clamp(math.floor((gapH + 4) / 44), 1, 3)
			L.feed = { rect = rect(dockX, gapTop, dockW, gapH), lines = lines, align = "right" }
		else
			local feedW = math.min(320, L.focus.w * 0.6)
			L.feed = { rect = rect(L.focus.x + (L.focus.w - feedW) / 2, top, feedW, 24), lines = 1, align = "center" }
		end
		L.hint = rect(L.focus.x + 4, top, L.focus.w - 8, 44)
		return L
	end

	-- tall: the top bar holds the buttons, players sit in a row under it, the board fills
	-- the middle, and cards share the bottom with ROLL and the ability (stacked on the right)
	local bh = math.min(band.h, 40)
	local by = band.y + (band.h - bh) / 2
	local wantButtons = 3
	local buttonsW = wantButtons * bh + (wantButtons - 1) * 6
	if bh >= minButton and band.w >= buttonsW then
		L.buttons = { rect = rect(band.x + band.w - buttonsW, by, buttonsW, bh), size = bh, gap = 6, count = wantButtons }
		local infoW = band.w - buttonsW - G
		if infoW >= 90 then
			L.info = rect(band.x, by, infoW, bh)
		end
	else
		local bs = math.max(36, minButton)
		buttonsW = wantButtons * bs + (wantButtons - 1) * 6
		L.buttons = { rect = rect(x1 - buttonsW, top, buttonsW, bs), size = bs, gap = 6, count = wantButtons }
		L.info = rect(x0, top, (x1 - buttonsW - G) - x0, bs)
		top += bs + G
	end
	local chipGap = if n >= 5 then 4 else 6
	local rowW = x1 - x0
	local chipW = math.min(112, (rowW - (n - 1) * chipGap) / n)
	local chipH = 68
	local playersW = n * chipW + (n - 1) * chipGap
	L.players = {
		rect = rect(x0 + (rowW - playersW) / 2, top, playersW, chipH),
		dir = "x",
		chip = { w = chipW, h = chipH, kind = "stack" },
		gap = chipGap,
	}
	local cardW = math.max(64, math.ceil(58 / m.scale))
	local cardH = math.ceil(cardW * 1.38)
	local rollH = math.max(60, math.ceil(58 / m.scale))
	local abilityH = math.max(36, minButton)
	local bottomH = math.max(cardH + 8, rollH + G + abilityH)
	local bottomY = yBottom - bottomH
	local actionW = math.max(132, math.ceil(120 / m.scale))
	local actionX = x1 - actionW
	L.ability = rect(actionX, bottomY, actionW, abilityH)
	L.roll = rect(actionX, bottomY + abilityH + G, actionW, bottomH - abilityH - G)
	L.hand = { rect = rect(x0, bottomY, actionX - G - x0, bottomH), dir = "x", card = { w = cardW, h = cardH }, gap = 6 }
	local focusTop = top + chipH + G
	L.focus = rect(x0, focusTop, rowW, bottomY - G - focusTop)
	-- no spare room on an upright phone: the newest line only, briefly, over the board's top
	L.feed = { rect = rect(x0, focusTop, rowW, 24), lines = 1, align = "center" }
	L.hint = rect(x0, focusTop, rowW, 48)
	return L
end

-- The HUD rects that must never overlap each other (the feed and hint float over the board).
-- `info` can be missing on narrow phones (the round shows in the menu instead).
function Layout.matchHud(L): { [string]: Rect }
	return {
		players = L.players.rect,
		hand = L.hand.rect,
		ability = L.ability,
		roll = L.roll,
		info = L.info,
		buttons = L.buttons.rect,
	}
end

---------------------------------------------------------------------------
-- lobby
---------------------------------------------------------------------------

--[[
	Layout.lobby(m) -> {
		form
		title     rect or nil (the big "Trapisque")
		profile   { rect, kind = "full" | "compact" }  your avatar, level, gems
		tabs      rect or nil   upright phones switch between Play / Party / Top
		play, party, leaders    panel rects (on upright phones all three share one;
		                        leaders is nil when the leaderboard opens from the menu)
		compact   true when the panels must use their compact layouts
		nav       { rect, kind = "full" | "short" | "icon" }   the menu buttons
		invites   rect          where party invites stack up
	}
	PC: title and profile on top, Play | Party | Top across the middle (Top moves to the
	menu when there isn't room), the menu along the bottom. Phones held sideways: the
	profile sits in the free middle of Roblox's top bar and everything else is compact.
	Phones held upright: one panel at a time under tabs, icon menu at the bottom.
]]
function Layout.lobby(m)
	local form = m.form
	local safe = Layout.safeRect(m, 0)
	local top = math.max(m.topbar.y1, safe.y)
	local out: { [string]: any } = { form = form }

	if form == "wide" then
		local M = 24
		local x0, x1 = safe.x + M, safe.x + safe.w - M
		local y0 = top + 8
		local navH = 66
		local nav = rect(x0, safe.y + safe.h - 22 - navH, x1 - x0, navH)
		local profile = rect(x1 - 400, y0, 400, 74)
		out.profile = { rect = profile, kind = "full" }
		out.title = rect(x0, y0 - 6, math.min(420, profile.x - 16 - x0), 70)
		local body = rect(x0, y0 + 96, x1 - x0, nav.y - 14 - (y0 + 96))
		if body.w >= 1180 then
			local G = 16
			local playW = math.floor((body.w - 2 * G) * 0.42)
			local partyW = math.floor((body.w - 2 * G) * 0.29)
			out.play = rect(body.x, body.y, playW, body.h)
			out.party = rect(body.x + playW + G, body.y, partyW, body.h)
			out.leaders = rect(body.x + playW + partyW + 2 * G, body.y, body.w - playW - partyW - 2 * G, body.h)
		else
			local G = 24
			local playW = math.floor((body.w - G) * 0.55)
			out.play = rect(body.x, body.y, playW, body.h)
			out.party = rect(body.x + playW + G, body.y, body.w - playW - G, body.h)
		end
		out.compact = false
		out.nav = { rect = nav, kind = "full" }
		out.invites = rect(x1 - 380, body.y, 380, nav.y - 12 - body.y)
	elseif form == "short" then
		local M = 10
		local x0, x1 = safe.x + M, safe.x + safe.w - M
		-- the profile chip rides in the free middle of Roblox's top bar
		local band = Layout.bandRect(m, 10)
		local chipW = math.min(340, band.w)
		out.profile = { rect = rect(band.x + band.w - chipW, band.y, chipW, band.h), kind = "compact" }
		if band.w - chipW >= 190 then
			out.title = rect(band.x, band.y, math.min(240, band.w - chipW - 16), band.h)
		end
		local navH = math.max(46, math.ceil(44 / m.scale))
		local nav = rect(x0, safe.y + safe.h - 8 - navH, x1 - x0, navH)
		local y0 = top + 6
		local body = rect(x0, y0, x1 - x0, nav.y - 8 - y0)
		local G = 10
		local playW = math.floor((body.w - G) * 0.56)
		out.play = rect(body.x, body.y, playW, body.h)
		out.party = rect(body.x + playW + G, body.y, body.w - playW - G, body.h)
		out.compact = true
		out.nav = { rect = nav, kind = "short" }
		out.invites = rect(x1 - 340, body.y, 340, body.h)
	else
		local M = 10
		local x0, x1 = safe.x + M, safe.x + safe.w - M
		local y = top + 6
		out.title = rect(x0, y, x1 - x0, 46)
		y += 46 + 6
		out.profile = { rect = rect(x0, y, x1 - x0, 64), kind = "full" }
		y += 64 + 10
		out.tabs = rect(x0, y, x1 - x0, 44)
		y += 44 + 8
		local navH = 62
		local nav = rect(x0, safe.y + safe.h - 8 - navH, x1 - x0, navH)
		local body = rect(x0, y, x1 - x0, nav.y - 10 - y)
		out.play = body
		out.party = body
		out.leaders = body
		out.compact = false
		out.nav = { rect = nav, kind = "icon" }
		out.invites = rect(x0, body.y, x1 - x0, body.h)
	end
	return out
end

---------------------------------------------------------------------------
-- modals
---------------------------------------------------------------------------

-- The room a modal has at full size: inside the safe area and below Roblox's top bar.
function Layout.modalRoom(m): (number, number)
	local safe = Layout.safeRect(m, if m.form == "wide" then 16 else 6)
	local top = math.max(m.topbar.y1 + 4, safe.y)
	return safe.w, safe.y + safe.h - top
end

-- Fits a modal designed at w x h into the safe area. Returns the size to build at and
-- the UIScale to apply (shrinks only when it must, never below `minScale`).
function Layout.modal(m, w: number, h: number, minScale: number?): (number, number, number)
	local availW, availH = Layout.modalRoom(m)
	local scale = math.min(1, availW / w, availH / h)
	scale = math.max(scale, minScale or 0.5)
	-- if even the minimum scale doesn't fit, build it narrower/shorter instead
	local bw = math.min(w, availW / scale)
	local bh = math.min(h, availH / scale)
	return bw, bh, scale
end

-- Centre of the area modals use (below Roblox's top bar).
function Layout.modalCenter(m): (number, number)
	local safe = Layout.safeRect(m, 0)
	local top = math.max(m.topbar.y1, safe.y)
	return safe.x + safe.w / 2, top + (safe.y + safe.h - top) / 2
end

return Layout
