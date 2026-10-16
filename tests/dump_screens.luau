-- Dumps everything the screen previews need (tools/preview/hud.py, lobby.py, pages.py):
--   * each device's stage and layout from the game's own Layout module (Layout.match,
--     Layout.lobby, the modal room)
--   * a match on Slimy Snares at the moment it's MY turn: my dice rolled (5 and 2), the
--     5 hovered so the board shows where it goes (the path from Engine.walkPlan and the
--     tags MatchScreen:_outcome would put over it), one of my hidden traps on the board,
--     a rival Frozen, my Power nearly full, a hand of cards and the feed's last lines
--     (the same sentences MatchScreen writes)
--   * my profile for the lobby (level, gems, trophies and rank, character mastery, daily
--     quests, login streak, this week's event) and the match's results screen
-- Bundle after tests/preview_skins.luau.
local Layout = requireModule("Client/UI/Layout")
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")
local Rng = requireModule("Shared/Game/Rng")
local Engine = requireModule("Shared/Game/Engine")
local Bot = requireModule("Shared/Game/Bot")
local Items = requireModule("Shared/Game/Items")
local Characters = requireModule("Shared/Game/Characters")
local Modes = requireModule("Shared/Game/Modes")
local Config = requireModule("Shared/Config")
local Progress = requireModule("Shared/Meta/Progress")
local Cosmetics = requireModule("Shared/Meta/Cosmetics")
local Gacha = requireModule("Shared/Meta/Gacha")
local BoardLayout = requireModule("Client/UI/Match/BoardLayout")
local CardStyle = requireModule("Client/UI/CardStyle")
local Theme = PreviewTheme()
local C = Theme.C
local Rules = Config.Rules

local DEVICES = {
	{ name = "PC 1920 x 1080", file = "pc", w = 1920, h = 1080 },
	{ name = "Phone held sideways (iPhone 14)", file = "phone-landscape", w = 844, h = 390, touch = true, safe = { l = 47, r = 47, b = 21 }, bar = { y1 = 48, l = 160 } },
	{ name = "Phone held upright (iPhone 14)", file = "phone-portrait", w = 390, h = 844, touch = true, safe = { t = 47, b = 34 }, bar = { y0 = 47, y1 = 95, l = 110, r = 340 } },
}

-- a fixed day, so the previews don't change from one run to the next
local NOW = 1792065600 -- 2026-10-15 12:00 UTC
local MY_ID = 3141592

---------------------------------------------------------------------------
-- the match
---------------------------------------------------------------------------
local def = Maps.get("slimy")
local board = Board.get(def)
local names = { "Explorer", "Bot Pip", "Bot Lily", "Bot Marlo" }
local characters = { "mage", "trapper", "fire_starter", "warper" }
local players = {}
for s = 1, 4 do
	players[s] = { id = "p" .. s, name = names[s], isBot = s > 1, character = characters[s], userId = if s == 1 then MY_ID else nil }
end
local g = Engine.new({ mode = "chaos", map = def.id, players = players, seed = 7, target = 3, length = "standard" })
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

-- the moment: my turn, round 6, my dice on the tray
-- (Pip just landed on me at 17: I was knocked back to 15 and he bounced on to 18;
-- Marlo is Frozen on 9, where my hidden Ice caught him)
local ME_TILE, LILY_TILE, PIP_TILE, MARLO_TILE = 15, 20, 18, 9
snap.current = 1
snap.phase = "action"
snap.round = 6
snap.dice = { 5, 2 }
snap.cardsPlayed = 0
snap.hand = { "fire", "speed_boost", "boots", "trampoline", "phoenix_potion" }
local state = {
	[1] = { tile = ME_TILE, treasures = 1, coins = 3, power = 5, frozen = 0, burning = 0, skip = 0 },
	[2] = { tile = PIP_TILE, treasures = 1, coins = 2, power = 4, frozen = 0, burning = 1, skip = 0 },
	[3] = { tile = LILY_TILE, treasures = 0, coins = 1, power = 2, frozen = 0, burning = 0, skip = 0 },
	[4] = { tile = MARLO_TILE, treasures = 1, coins = 2, power = 6, frozen = 2, burning = 0, skip = 0 },
}
local hands = { 5, 3, 2, 4 }
for _, p in snap.players do
	for k, v in state[p.seat] do
		p[k] = v
	end
	p.handCount = hands[p.seat]
	p.anchor = 0
end
-- nothing sits on the tiles the pawns stand on or under my path (tokens there would
-- have been picked up); keep the rest of what the bots left on the board
local path = {}
local keep = { [ME_TILE] = true, [LILY_TILE] = true, [PIP_TILE] = true, [MARLO_TILE] = true }
local function clearTile(t: number)
	for i = #snap.tokens, 1, -1 do
		if snap.tokens[i].tile == t then
			table.remove(snap.tokens, i)
		end
	end
	for i = #snap.placed, 1, -1 do
		local e = snap.placed[i]
		for _, ct in e.tiles or { e.tile } do
			if ct == t then
				table.remove(snap.placed, i)
				break
			end
		end
	end
	for i = #snap.traps, 1, -1 do
		if snap.traps[i].tile == t then
			table.remove(snap.traps, i)
		end
	end
end
for t in keep do
	clearTile(t)
end
snap.embers = {}
-- the board pieces on show: Pip's trampoline and Marlo's teleporter (on free tiles)
local function used(t: number): boolean
	for _, x in snap.tokens do
		if x.tile == t then
			return true
		end
	end
	for _, n in snap.natural do
		if n.tile == t then
			return true
		end
	end
	for _, e in snap.placed do
		for _, ct in e.tiles or { e.tile } do
			if ct == t then
				return true
			end
		end
	end
	for _, x in snap.traps do
		if x.tile == t then
			return true
		end
	end
	return keep[t] == true or board:isSpecial(t) or board.tiles[t].kind ~= "normal"
end
local function freeFrom(t: number): number
	while used(t) do
		t += 1
	end
	return t
end
local function hasPiece(item: string): boolean
	for _, e in snap.placed do
		if e.item == item then
			return true
		end
	end
	return false
end
if not hasPiece("trampoline") then
	table.insert(snap.placed, { tile = freeFrom(26), item = "trampoline", owner = 2, uses = 2 })
end
if not hasPiece("teleporter") then
	table.insert(snap.placed, { tile = freeFrom(30), item = "teleporter", owner = 4 })
end
-- my hidden Spike, a few tiles ahead of me (only I see it)
local hasMine = false
for _, t in snap.traps do
	if t.owner == 1 then
		hasMine = true
	end
end
if not hasMine then
	table.insert(snap.traps, { tile = freeFrom(23), item = "spike", owner = 1, team = 1, public = false })
end
-- the time on my turn's clock, and the chip's draining timer
local deadlineLeft = 38

-- where the hovered die (the 5) takes me, as MatchScreen:_planFor works it out
local me = snap.players[1]
local hover = 1
local function moveOption(key)
	local dice = snap.dice
	local d = dice[key]
	local other = 0
	for j, x in dice do
		if j ~= key and x > other then
			other = x
		end
	end
	return d, other
end
local steps, gain = moveOption(hover)
local naturalMap, placedMap = {}, {}
for _, n in snap.natural do
	naturalMap[n.tile] = n.kind
end
for _, e in snap.placed do
	placedMap[e.tile] = e
end
local plan = Engine.walkPlan({ board = board, natural = naturalMap, placed = placedMap }, { tile = me.tile, hand = snap.hand, character = me.character }, steps)

-- MatchScreen:_outcome: what the landing tile holds for me, as tags
local tags = {}
local function add(text: string, color: string)
	table.insert(tags, { text = text, color = color })
end
do
	local tile = plan.tile
	if plan.result == "treasure" then
		add("TREASURE!", C.sun)
	else
		if plan.result == "blocked" then
			add("WALL!", C.coral)
		elseif plan.result == "stopped" then
			add(string.upper(plan.hazard or "hazard") .. " STOPS YOU", C.sky)
		end
		if plan.slowed then
			add("SLIME -" .. tostring(Rules.SlimeDrag or 0), C.slime)
		end
		for _, u in plan.uses or {} do
			local d = Items.get(u.item)
			add("USES " .. string.upper(if d then d.name else u.item), C.mint)
		end
		if tile ~= board.start then
			for _, p in snap.players do
				if p.seat ~= 1 and p.tile == tile and p.team ~= me.team then
					add("BONK " .. string.upper(p.name) .. "!", C.sun)
				end
			end
			for _, tr in snap.traps do
				if tr.tile == tile and (tr.public or tr.team ~= me.team) then
					add("TRAP!", C.coral)
					break
				end
			end
			local piece = placedMap[tile]
			if piece then
				local pn = { teleporter = "TELEPORT", trampoline = "BOING +" .. Rules.TrampolineForward, spore_warper = "SWAP!", wall = "WALL" }
				local d = Items.get(piece.item)
				add(pn[piece.item] or string.upper(if d then d.name else piece.item), C.grape)
			end
			for _, t in snap.tokens do
				if t.tile == tile then
					if t.kind == "potion" then
						add("SHOP", C.orange)
					else
						add("+CARD", Theme.Category[t.kind] or C.lime)
					end
				end
			end
		end
	end
	if gain > 0 then
		add("+" .. tostring(gain) .. " POWER", C.sun)
	end
end

-- the feed (MatchScreen's sentences; names in their seat colour, lightened 25%)
local function lighten(hex: string, t: number): string
	local r = tonumber(string.sub(hex, 2, 3), 16)
	local gg = tonumber(string.sub(hex, 4, 5), 16)
	local b = tonumber(string.sub(hex, 6, 7), 16)
	local function f(v: number): number
		return math.floor(v + (255 - v) * t + 0.5)
	end
	return string.format("%02X%02X%02X", f(r), f(gg), f(b))
end
local function tag(seat: number): string
	local name = if seat == 1 then "You" else names[seat]
	return string.format('<font color="#%s">%s</font>', lighten(Theme.Seat[seat], 0.25), name)
end
local ice = Items.get("ice")
local feed = {
	-- newest first: Pip's turn, then Marlo's
	{ text = "BOING! " .. tag(2) .. " bonked " .. tag(1) .. " back " .. Rules.BonkBack .. "!", color = C.sun, icon = "star", iconColor = C.sun },
	{ text = tag(2) .. " moves 6", icon = "dice", iconColor = C.sun },
	{ text = tag(4) .. " is frozen (" .. Rules.FrozenTurns .. " turns)", icon = "snowflake", iconColor = C.sky },
	{ text = "GOTCHA! " .. tag(1) .. " caught " .. tag(4) .. " with a " .. ice.name .. " (+1 coin, +" .. Rules.PowerPerGotcha .. " Power)", color = C.sun, icon = "ice", iconColor = C.trap },
	{ text = tag(4) .. " stepped on " .. tag(1) .. "'s hidden " .. ice.name .. "!", icon = "ice", iconColor = C.trap },
}

-- where my Fire card could go right now (the tiles that glow while placing it), as
-- MatchScreen:_placeFlow works it out
local placing = {}
do
	local layers = Engine.layersFromSnapshot(board, snap)
	local ctx = Engine.placeContext({ tile = me.tile, character = me.character, index = 1, team = me.team }, snap.mutator)
	for _, item in { "fire", "trampoline" } do
		local valid = {}
		for id in board.tiles do
			if Engine.checkPlacement(board, layers, item, id, "fwd", ctx) then
				table.insert(valid, id)
			end
		end
		table.sort(valid)
		placing[item] = { valid = valid, range = ctx.range }
	end
end

-- per-orientation board layouts (an upright phone stands the board up)
local function boardData(rotate: boolean)
	return BoardLayout.build(board, def, Rng, { rotate = rotate })
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
	})
end

local seats = {}
for _, p in snap.players do
	table.insert(seats, {
		seat = p.seat,
		name = p.name,
		username = if p.seat == 1 then "explorer_42" else nil,
		userId = if p.seat == 1 then MY_ID else nil,
		isBot = p.isBot,
		character = p.character,
		team = p.team,
		pawn = ({ "pawn_classic", "pawn_ocean", "pawn_classic", "pawn_bee" })[p.seat],
	})
end
local charInfo = {}
for _, c in Characters.list do
	charInfo[c.id] = {
		name = c.name,
		ability = if c.ability then { name = c.ability.name, cost = c.ability.cost, text = c.ability.text } else nil,
		passiveName = c.passiveName,
		passive = c.passive,
		tagline = c.tagline,
	}
end
local itemInfo = {}
for _, it in Items.list do
	itemInfo[it.id] = { name = it.name, text = it.text, use = it.use, category = it.category, price = it.price, hidden = it.hidden, how = CardStyle.howToPlay(it) }
end

---------------------------------------------------------------------------
-- the lobby, its pages and the results
---------------------------------------------------------------------------
-- my mastery after the match below (the Mage just reached level 4)
local masteryXp = { mage = 640, trapper = 150, fire_starter = 320, naturalist = 0, warper = 60, overseer = 930 }
local mastery = {}
for _, c in Characters.list do
	local xp = masteryXp[c.id] or 0
	local into, need = Progress.masteryProgress(xp)
	local level = Progress.masteryLevel(xp)
	-- CharacterSelect nextTitle
	local at, tier = nil, nil
	for lv, t in Progress.masteryTitles do
		if lv > level and (at == nil or lv < at) then
			at, tier = lv, t
		end
	end
	mastery[c.id] = { xp = xp, level = level, into = into, need = need, titleAt = at, titleName = if tier then Progress.masteryTitleName[tier] else nil }
end
-- today's quests: three from the real pool (Bonk 5 rivals, a gotcha quest done, ...)
local function quest(id: string, progress: number, index: number)
	local q = Progress.questById[id]
	return { index = index, id = id, text = Progress.questText(q), goal = q.goal, gems = q.gems, progress = math.min(progress, q.goal), done = progress >= q.goal }
end
local quests = { quest("bonks", 3, 1), quest("gotchas", 3, 2), quest("treasures", 3, 3) }
local trophies = 604
local rank = Progress.rank(trophies)
local event = Progress.currentEvent(NOW)
local modes = {}
for _, mode in Modes.list do
	table.insert(modes, { id = mode.id, name = mode.name, short = mode.short, blurb = mode.blurb, minPlayers = mode.minPlayers, maxPlayers = mode.maxPlayers, isTeam = mode.isTeam, isEvent = mode.isEvent == true })
end
local titleDef = Cosmetics.get("title_mage_fan")
local profile = {
	name = "Explorer",
	username = "explorer_42",
	userId = MY_ID,
	level = 7,
	xp = 305,
	xpNext = Config.xpForLevel(7),
	gems = 1240,
	trophies = trophies,
	rank = rank,
	character = "mage",
	title = if titleDef then titleDef.look else nil,
	quests = quests,
	questRerolled = false,
	questBonus = false,
	streak = { count = 4 },
	freeChests = 1,
}

-- the match that just ended: I won with 3 treasures
local resultRows = {
	{ seat = 1, name = "Explorer", username = "explorer_42", userId = MY_ID, character = "mage", treasures = 3, won = true, stats = { bonks = 2, gotchas = 1 } },
	{ seat = 2, name = "Bot Pip", isBot = true, character = "trapper", treasures = 2, won = false, stats = { bonks = 1, gotchas = 0 } },
	{ seat = 4, name = "Bot Marlo", isBot = true, character = "warper", treasures = 1, won = false, stats = { bonks = 0, gotchas = 2 } },
	{ seat = 3, name = "Bot Lily", isBot = true, character = "fire_starter", treasures = 0, won = false, stats = { bonks = 1, gotchas = 0 } },
}
local R = Config.Rewards
local myResult = { treasures = 3, won = true, stats = { bonks = 2, gotchas = 1, abilities = 2 }, character = "mage" }
local gainXp = Progress.masteryXp(myResult)
local before = masteryXp.mage - gainXp
local beforeLevel, afterLevel = Progress.masteryLevel(before), Progress.masteryLevel(masteryXp.mage)
local masteryGems = 0
for lv = beforeLevel + 1, afterLevel do
	masteryGems += Progress.masteryGems(lv)
end
local into, need = Progress.masteryProgress(masteryXp.mage)
local trophyDelta = Progress.trophyDelta(1, 4, true, false, trophies - 10)
local results = {
	reason = "treasure",
	kind = "public",
	ranking = { 1, 2, 4, 3 },
	results = resultRows,
	resultsTime = Config.Timing.ResultsTime,
	reward = {
		gems = R.MatchGems + R.TreasureGems * 3 + R.WinGems,
		xp = R.MatchXP + R.TreasureXP * 3 + R.WinXP,
		levelsGained = 0,
		level = 7,
		bonus = {},
		mastery = { character = "mage", xp = gainXp, level = afterLevel, levelsGained = afterLevel - beforeLevel, into = into, need = need, gems = masteryGems, titles = {} },
		quests = {
			changed = {
				{ index = 1, text = quests[1].text, progress = 3, goal = quests[1].goal, done = false, gems = quests[1].gems },
				{ index = 2, text = quests[2].text, progress = 3, goal = quests[2].goal, done = true, gems = quests[2].gems },
				{ index = 3, text = quests[3].text, progress = 3, goal = quests[3].goal, done = false, gems = quests[3].gems },
			},
			gems = quests[2].gems,
			chest = false,
		},
		trophies = { delta = trophyDelta, total = trophies, rank = rank.id, rankUp = Progress.rank(trophies - trophyDelta).min < rank.min },
	},
}

-- the chests page (Chests.open), with pity counters part-way along (Chests pityText)
local pityCounters = { explorer = { epic = 3, legendary = 12 }, royal = { legendary = 6 } }
local chests = {}
for _, c in Gacha.chests do
	local best = nil
	for _, rule in c.pity do
		local since = (pityCounters[c.id] or {})[rule.rarity] or 0
		local left = math.max(1, rule.every - since)
		local r = Cosmetics.rarityById[rule.rarity]
		local text = (if r then r.name else rule.rarity) .. " or better within " .. left .. (if left == 1 then " chest" else " chests")
		if best == nil or Gacha.rarityRank(rule.rarity) > best.rank and left <= 10 then
			best = { rank = Gacha.rarityRank(rule.rarity), text = text }
		end
	end
	table.insert(chests, {
		id = c.id,
		name = c.name,
		blurb = c.blurb,
		price = c.price,
		tenPrice = c.tenPrice,
		look = c.look,
		odds = Gacha.odds(c, false),
		pity = if best then best.text else "",
	})
end

print(PreviewJson({
	devices = devices,
	boards = { wide = boardData(false), tall = boardData(true) },
	snapshot = snap,
	seats = seats,
	characters = charInfo,
	items = itemInfo,
	useText = CardStyle.useText,
	map = { id = def.id, name = def.name, theme = def.theme },
	mode = { short = Modes.get("chaos").short, length = "Standard", target = 3 },
	turn = { dice = snap.dice, hover = hover, power = { 2, 5 }, clock = deadlineLeft, deadline = Config.Timing.TurnTime },
	preview = { path = plan.path, tile = plan.tile, tags = tags, character = me.character },
	placing = placing,
	feed = feed,
	profile = profile,
	mastery = mastery,
	event = event,
	modes = modes,
	ranks = Progress.ranks,
	streakGems = Progress.streakGems,
	streakChestDay = Progress.StreakChestDay,
	results = results,
	chests = chests,
	rarities = Cosmetics.rarities,
	theme = Theme,
	now = NOW,
}))
