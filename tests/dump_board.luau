-- Dumps a mid-game scene on each map as JSON for tools/preview/board.py (the board
-- sheets), plus the art the board draws with (StickerArt, DecorData, pawn patterns and
-- skins) and the palette. Bundle after tests/preview_skins.luau.
--
-- Each scene is a real game played by bots for a while (tokens, hazards and whatever
-- the bots placed), then staged so every kind of sticker shows: a couple of board
-- pieces (and the conveyor on one map), a hidden trap of the viewer's (seat 1), embers
-- on one map, and four pawns spread out, one Frozen and one Burning.
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")
local Rng = requireModule("Shared/Game/Rng")
local Engine = requireModule("Shared/Game/Engine")
local Bot = requireModule("Shared/Game/Bot")
local BoardLayout = requireModule("Client/UI/Match/BoardLayout")
local StickerArt = requireModule("Client/UI/StickerArt")
local DecorData = requireModule("Client/UI/DecorData")
local IconData = requireModule("Client/UI/IconData")
local PawnPatterns = requireModule("Client/UI/PawnPatterns")
local Cosmetics = requireModule("Shared/Meta/Cosmetics")
local Characters = requireModule("Shared/Game/Characters")
local Theme = PreviewTheme()

local SPECS = {
	blissful = {
		chars = { "mage", "trapper", "fire_starter", "naturalist" },
		skins = { "pawn_classic", "pawn_ocean", "pawn_classic", "pawn_bee" },
		seed = 21,
		at = { 0.2, 0.36, 0.36, 0.62 }, -- where along the route each pawn stands
		frozen = 2,
		burning = 4,
		current = 1,
		pieces = { { item = "teleporter", owner = 2, at = 0.5 }, { item = "trampoline", owner = 3, at = 0.72 } },
		trap = { item = "spike", at = 0.28 },
	},
	junction = {
		chars = { "warper", "overseer", "mage", "trapper" },
		skins = { "pawn_classic", "pawn_galaxy", "pawn_classic", "pawn_ocean" },
		seed = 22,
		at = { 0.3, 0.16, 0.52, 0.7 },
		frozen = 4,
		burning = 2,
		current = 3,
		pieces = {
			{ item = "wall", owner = 4, at = 0.42 },
			{ item = "spore_warper", owner = 1, at = 0.6 },
			{ item = "conveyor", owner = 2, at = 0.74, dir = "fwd" },
		},
		trap = { item = "fire", at = 0.36 },
	},
	slimy = {
		chars = { "naturalist", "fire_starter", "warper", "overseer" },
		skins = { "pawn_bee", "pawn_classic", "pawn_ocean", "pawn_classic" },
		seed = 23,
		at = { 0.24, 0.45, 0.13, 0.45 },
		frozen = 3,
		burning = 1,
		skip = 4,
		current = 2,
		pieces = { { item = "trampoline", owner = 2, at = 0.32 }, { item = "teleporter", owner = 4, at = 0.58 } },
		trap = { item = "ice", at = 0.52 },
		embers = { owner = 2, at = 0.36, count = 2 },
	},
}

local scenes = {}
for _, def in Maps.list do
	local spec = SPECS[def.id]
	local board = Board.get(def)
	local layout = BoardLayout.build(board, def, Rng)
	local players = {}
	for s = 1, 4 do
		players[s] = { id = "p" .. s, name = "Player " .. s, isBot = true, character = spec.chars[s] }
	end
	local g = Engine.new({ mode = "chaos", map = def.id, players = players, seed = spec.seed, target = 3 })
	g:start()
	for _ = 1, 30 do
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

	-- what's on each tile so far
	local used = {}
	local function mark(t)
		used[t] = true
	end
	for _, t in snap.tokens do
		mark(t.tile)
	end
	for _, n in snap.natural do
		mark(n.tile)
	end
	for _, e in snap.placed do
		for _, t in e.tiles or { e.tile } do
			mark(t)
		end
	end
	for _, t in snap.traps do
		mark(t.tile)
	end
	-- the first empty normal tile on the main route at or after `frac` of the way
	local function freeAt(frac: number, span: number?): number?
		local start = math.max(2, math.floor(board.count * frac))
		for id = start, board.count - 1 do
			local tiles = if span then board:span(id, span) else { id }
			local ok = tiles ~= nil
			for _, t in tiles or {} do
				if used[t] or board:isSpecial(t) or board.tiles[t].kind ~= "normal" or board.tiles[t].branch ~= nil then
					ok = false
				end
			end
			if ok then
				return id
			end
		end
		return nil
	end
	-- the pieces this scene shows (on free tiles, the way the rules allow)
	for _, p in spec.pieces do
		local span = if p.item == "conveyor" then 3 else nil
		local tile = freeAt(p.at, span)
		if p.item == "teleporter" then
			while tile and (board.dist[tile] or 0) < 8 do
				tile = freeAt((tile + 1) / board.count)
			end
		end
		if tile then
			local entry = { tile = tile, item = p.item, owner = p.owner, dir = p.dir, uses = 1 }
			if span then
				entry.tiles = board:span(tile, span)
			end
			for _, t in entry.tiles or { tile } do
				mark(t)
			end
			table.insert(snap.placed, entry)
		end
	end
	-- a hidden trap of mine (seat 1): I see it see-through, nobody else does
	do
		local tile = freeAt(spec.trap.at)
		if tile then
			mark(tile)
			table.insert(snap.traps, { tile = tile, item = spec.trap.item, owner = 1, team = 1, public = false })
		end
	end
	-- embers behind a Fire Starter's Blast Off
	snap.embers = {}
	if spec.embers then
		local first = freeAt(spec.embers.at)
		for i = 0, spec.embers.count - 1 do
			if first then
				table.insert(snap.embers, { tile = first + i, owner = spec.embers.owner })
				mark(first + i)
			end
		end
	end
	-- the pawns: spread out (two share a tile on some maps), with their statuses
	local tileAt = {}
	local out = {}
	for s, p in snap.players do
		local frac = spec.at[s]
		local tile = tileAt[frac]
		if not tile then
			tile = freeAt(frac) or board.start
			tileAt[frac] = tile
			mark(tile)
		end
		table.insert(out, {
			seat = p.seat,
			name = p.name,
			character = spec.chars[s],
			tile = tile,
			pawn = spec.skins[s],
			frozen = if spec.frozen == s then 2 else 0,
			burning = if spec.burning == s then 1 else 0,
			skip = if spec.skip == s then 1 else 0,
		})
	end
	table.insert(scenes, {
		layout = layout,
		view = {
			tokens = snap.tokens,
			natural = snap.natural,
			placed = snap.placed,
			traps = snap.traps,
			embers = snap.embers,
			players = out,
			current = spec.current,
		},
	})
end

-- every mood of every mascot (pawns pull faces; the path ghost is "happy")
local moods = {}
local defaults = {}
for _, id in Characters.ids do
	local set = { default = StickerArt.mascot(id) }
	for m in StickerArt.moods do
		set[m] = StickerArt.mascot(id, m)
	end
	moods[id] = set
	defaults[id] = set.default
end
local looks = {}
for _, def in Cosmetics.list do
	if def.category == "pawn" or def.category == "dice" then
		looks[def.id] = def.look
	end
end
local patterns = {}
for k, v in pairs(PawnPatterns) do
	if k ~= "pips" then
		patterns[k] = v
	end
end
local slots = {}
for n, layoutDef in BoardLayout.PawnSlots do
	local list = {}
	for i, p in ipairs(layoutDef) do
		list[i] = p
	end
	slots[n] = { scale = layoutDef.scale, at = list }
end
print(PreviewJson({
	scenes = scenes,
	art = {
		decor = DecorData,
		tokens = StickerArt.tokens,
		hazards = StickerArt.hazards,
		misc = StickerArt.misc,
		cards = StickerArt.cards,
		mascotMoods = moods,
		mascots = defaults,
		icons = IconData,
	},
	style = BoardLayout.Style,
	slots = slots,
	looks = looks,
	defaults = { pawn = Cosmetics.defaults.pawn, dice = Cosmetics.defaults.dice },
	patterns = patterns,
	pips = PawnPatterns.pips,
	theme = Theme,
}))
