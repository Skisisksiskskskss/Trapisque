-- Dumps everything tools/preview/screens.py needs to draw the match screen and the lobby
-- at several real screen sizes: each device's layout (Layout.match / Layout.lobby), a
-- mid-game board in both orientations, and the tile skins recorded from TileSkins.
-- Bundle after tests/preview_skins.luau.
local Layout = requireModule("Client/UI/Layout")
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")
local Rng = requireModule("Shared/Game/Rng")
local Engine = requireModule("Shared/Game/Engine")
local Bot = requireModule("Shared/Game/Bot")
local Items = requireModule("Shared/Game/Items")
local Characters = requireModule("Shared/Game/Characters")
local BoardLayout = requireModule("Client/UI/Match/BoardLayout")
local Cosmetics = requireModule("Shared/Meta/Cosmetics")

local DEVICES = {
	{ name = "PC 1920 x 1080", file = "pc", w = 1920, h = 1080 },
	{ name = "Phone held sideways (iPhone 14)", file = "phone-landscape", w = 844, h = 390, touch = true, safe = { l = 47, r = 47, b = 21 }, bar = { y1 = 48, l = 160 } },
	{ name = "Phone held upright (iPhone 14)", file = "phone-portrait", w = 390, h = 844, touch = true, safe = { t = 47, b = 34 }, bar = { y0 = 47, y1 = 95, l = 110, r = 340 } },
}

local S = BoardLayout.Style
local def = Maps.get("slimy")
local board = Board.get(def)

-- a game a few rounds in, played by bots
local names = { "Explorer", "Bot Pip", "Bot Marlo", "Bot Juniper" }
local characters = { "mage", "trapper", "fire_starter", "warper" }
local players = {}
for s = 1, 4 do
	players[s] = { id = "p" .. s, name = names[s], isBot = s > 1, character = characters[s] }
end
local g = Engine.new({ mode = "chaos", map = def.id, players = players, seed = 7, target = 3 })
g:start()
for _ = 1, 36 do
	local cmd = Bot.decide(g, g.current)
	local ok = cmd and g:command(g.current, cmd)
	if not ok then
		g:autoAct()
	end
	if g.phase == "over" then
		break
	end
end
local snap = g:snapshot(1)

-- tidy the scene for the preview: your turn, a full hand, a few statuses, and one of
-- every kind of card on the board so every tile skin shows
snap.current = 1
snap.phase = "action"
snap.round = math.max(snap.round, 6)
snap.hand = { "spike", "speed_boost", "shield", "teleporter", "time_potion" }
snap.armed = { "speed_boost" }
for _, p in snap.players do
	p.burning, p.frozen, p.held = false, false, false
end
snap.players[2].frozen = true
snap.players[3].burning = true
-- spread the pawns out (two share a tile, so that shows too)
snap.players[1].tile = 11
snap.players[2].tile = 15
snap.players[3].tile = 11
snap.players[4].tile = 28
snap.players[1].treasures = 1
snap.players[1].coins = 3
snap.players[1].handCount = 5
snap.players[2].treasures = 2
snap.players[3].treasures = 1
snap.players[4].treasures = 0

local used = {}
for _, t in snap.tokens do
	used[t.tile] = true
end
for _, n in snap.natural do
	used[n.tile] = true
end
for _, e in snap.placed do
	for _, t in e.tiles or { e.tile } do
		used[t] = true
	end
end
for _, p in snap.players do
	used[p.tile] = true
end
local function freeTile(from: number): number?
	for id = from, board.count do
		if not used[id] and not board:isSpecial(id) and board.tiles[id].kind == "normal" then
			return id
		end
	end
	return nil
end
-- a conveyor belt across three free tiles
for start = 14, board.count - 4 do
	local span = board:span(start, 3)
	local ok = span ~= nil
	for _, t in span or {} do
		if used[t] or board:isSpecial(t) or board.tiles[t].kind ~= "normal" then
			ok = false
		end
	end
	if ok then
		for _, t in span do
			used[t] = true
		end
		table.insert(snap.placed, { tile = start, item = "conveyor", owner = 2, dir = "fwd", tiles = span })
		break
	end
end
local want = { "spike", "fire", "ice", "mud", "wall", "snare", "grog", "teleporter", "spore_warper", "shifting_sands", "mudslide" }
local next = 4
for i, item in want do
	local have = false
	for _, e in snap.placed do
		if e.item == item then
			have = true
		end
	end
	if not have then
		local tile = freeTile(next)
		if tile then
			used[tile] = true
			table.insert(snap.placed, { tile = tile, item = item, owner = ((i - 1) % 4) + 1 })
			next = tile + 3
		end
	end
end
-- per-orientation board data: the layout, each tile's skin and the belt directions
local function boardData(rotate: boolean)
	local layout = BoardLayout.build(board, def, Rng, { rotate = rotate })
	local pos = {}
	for _, t in layout.tiles do
		pos[t.id] = { t.x, t.y }
	end
	local skin, belt = {}, {}
	for _, e in snap.placed do
		if e.item == "conveyor" and e.tiles then
			for i, t in e.tiles do
				local from, to = t, e.tiles[i + 1]
				if not to then
					from, to = e.tiles[i - 1] or t, t
				end
				local vx, vy = pos[to][1] - pos[from][1], pos[to][2] - pos[from][2]
				belt[t] = math.deg(math.atan2(vy, vx)) + (if e.dir == "back" then 180 else 0)
			end
		end
	end
	local function addSkin(tile: number, kind: string)
		skin[tostring(tile)] = { kind = kind, top = SkinTop(kind), ops = RecordSkin(kind, rotate, S.tileScale / 2, belt[tile]) }
	end
	for _, e in snap.placed do
		if e.item ~= "conveyor" then
			addSkin(e.tile, e.item)
		end
	end
	for t in belt do
		addSkin(t, "conveyor")
	end
	for _, n in snap.natural do
		addSkin(n.tile, n.kind)
	end
	return { layout = layout, skins = skin, rotated = rotate }
end

local devices = {}
for _, d in DEVICES do
	local bar = d.bar or {}
	local m = Layout.metrics(d.w, d.h, {
		touch = d.touch,
		safe = d.safe,
		topbar = { y0 = bar.y0, y1 = bar.y1, l = bar.l, r = bar.r },
	})
	table.insert(devices, {
		name = d.name,
		file = d.file,
		w = d.w,
		h = d.h,
		m = m,
		match = Layout.match(m, #snap.players),
		lobby = Layout.lobby(m),
		modal = { Layout.modal(m, 520, 600) },
		modalCenter = { Layout.modalCenter(m) },
	})
end

-- every skin on its own tile, for the skin sheet
local sheet = {}
for _, kind in { "spike", "fire", "ice", "mud", "mudslide", "wall", "snare", "grog", "teleporter", "spore_warper", "shifting_sands", "conveyor", "slime", "river", "gate" } do
	local itemDef = Items.get(kind)
	local naturalNames = { slime = "Slime (natural)", river = "River (natural)", gate = "Locked gate (natural)" }
	table.insert(sheet, {
		kind = kind,
		name = naturalNames[kind] or (if itemDef then itemDef.name else kind),
		category = if itemDef then itemDef.category else "natural",
		top = SkinTop(kind),
		ops = RecordSkin(kind, false, S.tileScale / 2, 0),
	})
end

local seats = {}
for _, p in snap.players do
	table.insert(seats, {
		seat = p.seat,
		name = p.name,
		username = if p.seat == 1 then "explorer_42" else nil,
		isBot = p.isBot,
		character = p.character,
		team = p.team,
	})
end
local charInfo = {}
for _, c in Characters.list do
	charInfo[c.id] = {
		name = c.name,
		ability = c.ability and c.ability.name or nil,
		recharge = c.ability and c.ability.recharge or nil,
		amount = c.ability and c.ability.amount or nil,
	}
end
local itemNames = {}
for _, id in snap.hand do
	itemNames[id] = Items.get(id).name
end
local skins = { "pawn_classic", "pawn_ocean", "pawn_bee", "pawn_galaxy" }
local looks = {}
for _, id in skins do
	looks[id] = Cosmetics.get(id).look
end

print(PreviewJson({
	devices = devices,
	boards = { wide = boardData(false), tall = boardData(true) },
	snapshot = snap,
	seats = seats,
	characters = charInfo,
	itemNames = itemNames,
	sheet = sheet,
	map = { name = def.name, theme = def.theme },
	style = { tileScale = S.tileScale, tileDepth = S.tileDepth, pawn = S.pawn, pawnDisc = S.pawnDisc, coast = S.coast },
	pawnSkins = skins,
	pawnLooks = looks,
}))
