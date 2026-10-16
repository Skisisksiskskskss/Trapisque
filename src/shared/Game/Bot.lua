--[[
	Bot
	The AI that fills empty seats, replaces players who leave and powers practice games.

	Bot.decide(game, seat) returns ONE command for the bot whose turn it is. The server
	calls it again (with a short "thinking" pause) until the bot's turn ends.

	How it thinks: every choice is scored in "tiles" (one tile of progress = 1 point).
	A move is worth the progress it makes plus whatever it lands on (a token, a bonk, a
	trap it can see...) plus the Power the other die charges. Before hiding a trap it
	predicts where each opponent is likely to land next turn by imagining their 36
	possible rolls. Bots never cheat: they only see the hidden traps a player in their
	seat could see.
]]

local Config = require(script.Parent.Parent.Config)
local Items = require(script.Parent.Items)
local Characters = require(script.Parent.Characters)
local Engine = require(script.Parent.Engine)

local Rules = Config.Rules
local CharCfg = Config.Characters

local Bot = {}

-- What a tile's contents are worth to whoever lands there (in tiles).
local TOKEN_VALUE = { trap = 2.6, assist = 3.0, neutral = 1.6 }
local BONK_VALUE = 2.4
local TREASURE_BONUS = 12

-- Roughly what a full Power bar is worth for each character (spread over its pips).
local ABILITY_VALUE = {
	mage = 4.5,
	trapper = 4.0,
	fire_starter = 4.2,
	naturalist = 3.6,
	warper = 7.0,
	overseer = 1.6,
}

local TRAP_ORDER = { "spike", "grog", "snare", "mudslide", "ice", "banana", "fire", "wall" }

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------

local function has(p, item: string): boolean
	return table.find(p.hand, item) ~= nil
end

local function opponents(game, p)
	local out = {}
	for _, o in game.players do
		if o.team ~= p.team then
			table.insert(out, o)
		end
	end
	return out
end

-- Distance to the treasure the way `p` will actually walk it (shortcuts need a Key).
local function distOf(game, p, tile: number): number
	local board = game.board
	if has(p, "key") then
		return board.dist[tile] or 0
	end
	return board.mainDist[tile] or board.dist[tile] or 0
end

-- How threatening an opponent is: treasures first, then closeness to the treasure.
local function threat(game, o): number
	return o.treasures * 1000 + (1000 - (game.board.dist[o.tile] or 0))
end

local function leader(game, list)
	local best, bestScore = nil, -math.huge
	for _, o in list do
		local s = threat(game, o)
		if s > bestScore then
			best, bestScore = o, s
		end
	end
	return best
end

-- How much hurting `o` matters to `p` (the leader matters most).
local function victimWeight(game, p, o): number
	local w = 1 + 0.35 * (o.treasures - p.treasures)
	local lead = leader(game, opponents(game, p))
	if lead == o then
		w += 0.4
	end
	if (game.board.dist[o.tile] or 99) <= 8 then
		w += 0.3
	end
	return math.max(0.4, w)
end

-- Tiles of progress `o` would lose to a trap on their way (how bad it is for them).
local function trapSeverity(game, item: string, o): number
	local board = game.board
	local lapDone = board.routeLength - (board.mainDist[o.tile] or board.routeLength)
	if item == "spike" then
		if has(o, "phoenix_potion") then
			return 1.5
		end
		return 2 + lapDone * 0.9
	elseif item == "grog" then
		if has(o, "phoenix_potion") then
			return 0.8
		end
		return 1 + lapDone * 0.45
	elseif item == "snare" then
		return 4.5
	elseif item == "mudslide" then
		return 3.4
	elseif item == "banana" then
		return 2.2 + math.min(#o.hand, 1) * 1.6
	elseif item == "ice" then
		if o.character == "mage" then
			return 0
		end
		return 3.0
	elseif item == "fire" then
		return 2.4
	end
	return 1
end

local function hostileVisibleTraps(game, p, tile: number)
	local out = {}
	for _, trap in game.traps[tile] or {} do
		if (trap.public or trap.team ~= p.team) and game:canSee(p.index, trap) then
			table.insert(out, trap)
		end
	end
	return out
end

---------------------------------------------------------------------------
-- evaluating a move
---------------------------------------------------------------------------

-- What landing on `tile` is worth to `p` (without the progress itself).
local function landingValue(game, p, tile: number, viewer: any?): number
	local board = game.board
	if tile == board.start or tile == board.treasure then
		return 0
	end
	local v = 0
	if game.cover[tile] then
		local origin = game.cover[tile]
		local belt = game.placed[origin]
		if belt then
			local pos = table.find(belt.tiles, tile) or 1
			if belt.dir == "fwd" then
				v += #belt.tiles - pos + 1
			else
				v -= pos
			end
		end
		return v
	end
	for _, trap in hostileVisibleTraps(game, viewer or p, tile) do
		if trap.team ~= p.team or trap.public then
			v -= trapSeverity(game, trap.item, p)
		end
	end
	local ember = game.embers[tile]
	if ember and ember.team ~= p.team then
		v -= trapSeverity(game, "fire", p)
	end
	local piece = game.placed[tile]
	if piece then
		if piece.item == "teleporter" then
			local partner = game:_teleportPartner(tile)
			if partner then
				v += (board.dist[tile] or 0) - (board.dist[partner] or 0)
			end
		elseif piece.item == "trampoline" then
			v += Rules.TrampolineForward
		elseif piece.item == "spore_warper" and p.character ~= "warper" then
			-- swaps with the nearest player: usually a coin flip, worth a little if they're ahead
			v += 0
		end
	end
	for _, o in game.players do
		if o ~= p and o.tile == tile and o.team ~= p.team and o.character ~= "warper" then
			v += BONK_VALUE * victimWeight(game, p, o)
			if p.character == "fire_starter" then
				v += 1.2
			end
		end
	end
	local token = game.tokens[tile]
	if token == "potion" then
		v += if p.coins >= 2 and #p.hand < Rules.HandLimit then 1.8 else 0.3
	elseif token then
		if #p.hand >= Rules.HandLimit then
			v += 0.4
		else
			v += TOKEN_VALUE[token] or 1
		end
	end
	return v
end

local function powerValue(p, gain: number): number
	local cap = Engine.powerCap(p)
	if cap <= 0 then
		return 0
	end
	local room = math.max(0, cap - p.power)
	return math.min(gain, room) * (ABILITY_VALUE[p.character] or 3) / cap
end

-- The value of moving `m` steps (forwards or backwards) and charging `gain` Power.
local function moveValue(game, p, m: number, backwards: boolean, gain: number, viewer: any?): (number, number)
	local before = distOf(game, p, p.tile)
	local plan
	if backwards then
		plan = Engine.backPlan(p, m)
	else
		plan = Engine.walkPlan(game, p, m)
	end
	local v
	if plan.result == "treasure" then
		v = before + TREASURE_BONUS
	else
		v = before - distOf(game, p, plan.tile)
		v += landingValue(game, p, plan.tile, viewer)
		if plan.result == "stopped" then
			v -= 0.5
		end
	end
	-- cards a walk would burn through (Key, Bridge, Boots, Shield) are worth a little
	v -= #plan.uses * 0.6
	v += powerValue(p, gain)
	return v, plan.tile
end

-- Every way `p` could move with these dice: { die, m, back, gain }. `gold` is the
-- underdog's extra die (it charges no Power).
local function moveOptions(dice, boost: string?, gold: number?)
	local out = {}
	local keys = {}
	for i in dice do
		table.insert(keys, i)
	end
	if Engine.dieOption(dice, "sum", gold) then
		table.insert(keys, "sum")
	end
	for _, key in keys do
		local m, gain, backDie = Engine.dieOption(dice, key, gold)
		local steps, back = Engine.boosted(m :: number, boost)
		table.insert(out, { die = key, m = steps, back = back or backDie == true, gain = gain })
	end
	return out
end

local function bestMove(game, p, dice, boost: string?, viewer: any?, gold: number?)
	local best, bestV, bestTile = nil, -math.huge, nil
	for _, opt in moveOptions(dice, boost, gold) do
		local v, tile = moveValue(game, p, opt.m, opt.back, opt.gain, viewer)
		if v > bestV then
			best, bestV, bestTile = opt, v, tile
		end
	end
	return best, bestV, bestTile
end

-- Average best-move value over every roll (for rerolls and predictions).
local function expectedRollValue(game, p, oneDie: boolean): number
	local total, n = 0, 0
	if oneDie then
		for a = 1, 6 do
			local _, v = bestMove(game, p, { Engine.halve(a) }, nil)
			total += v
			n += 1
		end
	else
		for a = 1, 6 do
			for b = 1, 6 do
				local _, v = bestMove(game, p, { a, b }, nil)
				total += v
				n += 1
			end
		end
	end
	return total / n
end

--[[
	Where opponent `o` is likely to land on their next turn: { [tile] = probability }.
	We imagine all 36 rolls and let them pick the way a bot would (they can't see our
	hidden traps, so those don't scare them off).
]]
local function landingOdds(game, o)
	local odds = {}
	local frozen = o.status.frozen > 0
	local skip = o.status.skip > 0
	if skip then
		odds[o.tile] = 1
		return odds
	end
	local function add(tile, w)
		odds[tile] = (odds[tile] or 0) + w
	end
	if frozen then
		for a = 1, 6 do
			local _, _, tile = bestMove(game, o, { Engine.halve(a) }, nil)
			add(tile, 1 / 6)
		end
	else
		for a = 1, 6 do
			for b = 1, 6 do
				local _, _, tile = bestMove(game, o, { a, b }, nil)
				add(tile, 1 / 36)
			end
		end
	end
	return odds
end

local function predictions(game, p)
	local turn = game.turn
	turn.botCache = turn.botCache or {}
	local cache = turn.botCache
	if cache.odds == nil then
		local odds = {}
		for _, o in opponents(game, p) do
			odds[o.index] = landingOdds(game, o)
		end
		cache.odds = odds
	end
	return cache.odds
end

---------------------------------------------------------------------------
-- placing cards
---------------------------------------------------------------------------

-- Tiles near `p` where a card could go (within range; Trappers: anywhere).
local function candidateTiles(game, p, item: string)
	local out = {}
	local ctx = Engine.placeContext(p, game.mut)
	local layers = game:layersFor(p.index)
	for tile = 1, game.board.totalTiles do
		local dir = if item == "conveyor" then "back" else nil
		if Engine.checkPlacement(game.board, layers, item, tile, dir, ctx) then
			table.insert(out, tile)
		end
	end
	return out
end

-- The best tile to hide `item`, and how much it's worth.
local function bestTrapTile(game, p, item: string)
	local odds = predictions(game, p)
	-- what a catch is worth to me: a coin, some Power (and a hop for the Trapper)
	local reward = 0.8 + powerValue(p, Rules.PowerPerGotcha)
	if p.character == "trapper" then
		reward += CharCfg.trapper.bounty
	end
	local best, bestV = nil, 0
	for _, tile in candidateTiles(game, p, item) do
		local v = 0
		for _, o in opponents(game, p) do
			local chance = odds[o.index] and odds[o.index][tile]
			if chance then
				v += chance * (trapSeverity(game, item, o) * victimWeight(game, p, o) + reward)
			end
		end
		-- traps stay until they catch someone: tiles just ahead of opponents keep paying off
		for _, o in opponents(game, p) do
			local d = game.board:raceDistance(o.tile, tile)
			if (game.board.dist[tile] or 0) < (game.board.dist[o.tile] or 0) and d >= 1 and d <= 12 then
				v += 0.02 * trapSeverity(game, item, o)
			end
		end
		if v > bestV then
			best, bestV = tile, v
		end
	end
	return best, bestV
end

-- A wall right in front of the opponent closest to the treasure.
local function bestWallTile(game, p)
	local lead = leader(game, opponents(game, p))
	if not lead then
		return nil, 0
	end
	local board = game.board
	local tiles = candidateTiles(game, p, "wall")
	local best, bestV = nil, 0
	for _, tile in tiles do
		local ahead = (board.dist[lead.tile] or 0) - (board.dist[tile] or 0)
		if ahead >= 2 and ahead <= 5 then
			local v = 2.2 * victimWeight(game, p, lead) * (1 - (ahead - 2) * 0.15)
			if (board.dist[lead.tile] or 99) <= 12 then
				v += 0.8
			end
			if v > bestV then
				best, bestV = tile, v
			end
		end
	end
	return best, bestV
end

local function bestNeutralPlay(game, p, item: string)
	local board = game.board
	if item == "trampoline" then
		-- just ahead of me, where I might land next turn
		local best, bestV = nil, 0
		for _, tile in candidateTiles(game, p, item) do
			local ahead = (board.dist[p.tile] or 0) - (board.dist[tile] or 0)
			if ahead >= 3 and ahead <= 6 then
				local v = 0.9
				if v > bestV then
					best, bestV = tile, v
				end
			end
		end
		return if best then { type = "play", item = item, tile = best } else nil, bestV
	elseif item == "conveyor" then
		local tile, v = bestTrapTile(game, p, "mudslide")
		if tile and game:canPlace(p, item, tile, "back") then
			return { type = "play", item = item, tile = tile, dir = "back" }, v * 0.7
		end
		return nil, 0
	elseif item == "teleporter" then
		-- far ahead of me, so the pair links a long jump
		local best, bestV = nil, 0
		for _, tile in candidateTiles(game, p, item) do
			local ahead = (board.dist[p.tile] or 0) - (board.dist[tile] or 0)
			if ahead >= 2 then
				local v = 0.5 + ahead * 0.05
				if v > bestV then
					best, bestV = tile, v
				end
			end
		end
		return if best then { type = "play", item = item, tile = best } else nil, bestV
	elseif item == "spore_warper" then
		local lead = leader(game, opponents(game, p))
		if lead and (board.dist[lead.tile] or 0) + 6 < (board.dist[p.tile] or 0) then
			local tile, v = bestTrapTile(game, p, "mudslide")
			if tile then
				return { type = "play", item = item, tile = tile }, v * 0.6
			end
		end
		return nil, 0
	end
	return nil, 0
end

---------------------------------------------------------------------------
-- choosing a card to play
---------------------------------------------------------------------------

local function bestCardPlay(game, p)
	local dice = game.turn.dice
	local gold = game.turn.gold
	local _, baseV = bestMove(game, p, dice, nil, nil, gold)
	local handFull = #p.hand >= Rules.HandLimit - 1
	local best, bestV = nil, 0
	local function consider(cmd, v)
		if cmd and v > bestV then
			best, bestV = cmd, v
		end
	end
	local seen = {}
	for _, item in p.hand do
		if not seen[item] then
			seen[item] = true
			local def = Items.get(item)
			local use = def and def.use
			if use == "boost" then
				local _, v = bestMove(game, p, dice, item, nil, gold)
				consider({ type = "play", item = item }, v - baseV - 1.2)
			elseif use == "reroll" then
				local v = expectedRollValue(game, p, #dice == 1)
				consider({ type = "play", item = item }, v - baseV - 1.4)
			elseif use == "juice" then
				local cap = Engine.powerCap(p)
				if p.power < cap and not game.turn.abilityUsed then
					consider({ type = "play", item = item }, (cap - p.power) / cap * (ABILITY_VALUE[p.character] or 3) - 1.5)
				end
			elseif use == "place" and def.category == "trap" then
				if item == "wall" then
					local tile, v = bestWallTile(game, p)
					consider(tile and { type = "play", item = item, tile = tile }, v - 0.6 + (if handFull then 1 else 0))
				else
					local tile, v = bestTrapTile(game, p, item)
					consider(tile and { type = "play", item = item, tile = tile }, v - 0.45 + (if handFull then 1 else 0))
				end
			elseif use == "place" then
				local cmd, v = bestNeutralPlay(game, p, item)
				consider(cmd, v - 0.5 + (if handFull then 0.8 else 0))
			elseif use == "telepathy" then
				local board = game.board
				-- pull myself onto the treasure
				local d = board.dist[p.tile] or 99
				if d >= 1 and d <= Rules.TelepathyMax and board.mainDist[p.tile] == d then
					consider({ type = "play", item = item, target = p.index, steps = d }, 8)
				end
				for _, o in opponents(game, p) do
					if #o.trail > 1 then
						-- push them back onto a trap I can see
						for steps = 1, math.min(Rules.TelepathyMax, #o.trail - 1) do
							local tile = o.trail[#o.trail - steps]
							local traps = hostileVisibleTraps(game, o, tile)
							local hurt = 0
							for _, trap in traps do
								if game:canSee(p.index, trap) then
									hurt += trapSeverity(game, trap.item, o)
								end
							end
							if hurt > 0 then
								consider({ type = "play", item = item, target = o.index, steps = -steps }, steps + hurt * victimWeight(game, p, o) - 1)
							end
						end
						if (board.dist[o.tile] or 99) <= 6 then
							consider({ type = "play", item = item, target = o.index, steps = -math.min(3, #o.trail - 1) }, 3 * victimWeight(game, p, o) - 1)
						end
					end
				end
			elseif use == "xray" then
				local unseen = 0
				for _, list in game.traps do
					for _, trap in list do
						if not game:canSee(p.index, trap) then
							unseen += 1
						end
					end
				end
				-- the count of hidden traps out there is public (everyone saw them being hidden)
				consider({ type = "play", item = item }, unseen * 0.8 - 1.2)
			elseif use == "anchor" then
				if not p.anchor and (game.board.dist[p.tile] or 99) <= 7 and p.tile ~= game.board.start then
					consider({ type = "play", item = item }, 3)
				end
			elseif use == "jeopardy" then
				local lead = leader(game, opponents(game, p))
				if lead then
					local gap = (threat(game, lead) - threat(game, p)) / 150
					consider({ type = "play", item = item, target = lead.index }, gap + #lead.hand * 0.4 - 2)
				end
			end
		end
	end
	-- team modes: pass a card I can't use well to a teammate with room
	if game.mode.isTeam and handFull and best == nil then
		for _, mate in game:teammates(p) do
			if #mate.hand < Rules.HandLimit - 1 then
				return { type = "give", item = p.hand[1], target = mate.index }, 0.5
			end
		end
	end
	return best, bestV
end

---------------------------------------------------------------------------
-- abilities
---------------------------------------------------------------------------

local function abilityCommand(game, p)
	local def = Characters.get(p.character)
	local ab = def and def.ability
	if not ab or game.turn.abilityUsed or p.power < ab.cost then
		return nil
	end
	local board = game.board
	local opps = opponents(game, p)
	if ab.id == "blizzard" then
		local n, w = 0, 0
		for _, o in opps do
			if o.status.frozen == 0 and o.character ~= "mage" then
				n += 1
				w += victimWeight(game, p, o)
			end
		end
		if n > 0 and (w >= 1.2 or p.power >= ab.cost) then
			return { type = "ability" }
		end
	elseif ab.id == "scavenge" then
		if #p.hand < Rules.HandLimit then
			return { type = "ability" }
		end
	elseif ab.id == "blast" then
		-- a wall in the way doesn't stop a rocket, so just go (unless I'm at the Start with
		-- nothing ahead worth reaching: it's still +4, so always worth it)
		return { type = "ability" }
	elseif ab.id == "stampede" then
		-- the Power bar can't overfill, so waiting for someone to trample only wastes
		-- charge: +3 is always worth it, and a rival in the way is a bonus
		return { type = "ability" }
	elseif ab.id == "warp" then
		local myDist = distOf(game, p, p.tile)
		local best, bestGain = nil, 0
		for _, o in game.players do
			if o ~= p and o.tile ~= p.tile and o.character ~= "warper" and board:raceDistance(p.tile, o.tile) <= ab.range then
				local gain = myDist - distOf(game, p, o.tile)
				if o.team == p.team then
					gain = gain - (distOf(game, o, p.tile) - distOf(game, o, o.tile)) * 1.5
				end
				if gain > bestGain then
					best, bestGain = o, gain
				end
			end
		end
		if best and bestGain >= 3 then
			return { type = "ability", target = best.index }
		end
	elseif ab.id == "nudge" then
		-- myself onto the treasure or something good, or an opponent onto a trap
		local steps = CharCfg.overseer.steps
		local d = board.dist[p.tile] or 99
		if d <= steps and board.mainDist[p.tile] == d then
			return { type = "ability", target = p.index, option = "fwd" }
		end
		local bestCmd, bestV = nil, 0.6
		local fwd = p.tile
		for _ = 1, steps do
			fwd = board.nextMain[fwd] or fwd
		end
		if fwd ~= board.treasure then
			local v = landingValue(game, p, fwd) + steps
			if v > bestV then
				bestCmd, bestV = { type = "ability", target = p.index, option = "fwd" }, v
			end
		end
		for _, o in opps do
			if #o.trail > steps then
				local back = o.trail[#o.trail - steps]
				local hurt = steps * 0.6
				for _, trap in hostileVisibleTraps(game, o, back) do
					if game:canSee(p.index, trap) then
						hurt += trapSeverity(game, trap.item, o)
					end
				end
				local v = hurt * victimWeight(game, p, o)
				if v > bestV then
					bestCmd, bestV = { type = "ability", target = o.index, option = "back" }, v
				end
			end
		end
		return bestCmd
	end
	return nil
end

---------------------------------------------------------------------------
-- shop and picks
---------------------------------------------------------------------------

local function shopCommand(game, p)
	local bought = game.turn and game.turn.botBought or 0
	if bought < 2 and #p.hand < Rules.HandLimit then
		local wants = {}
		if not has(p, "phoenix_potion") then
			table.insert(wants, "phoenix_potion")
		end
		table.insert(wants, "telepathy_potion")
		local unseen = 0
		for _, list in game.traps do
			for _, trap in list do
				if not game:canSee(p.index, trap) then
					unseen += 1
				end
			end
		end
		if unseen >= 2 and not has(p, "xray_potion") then
			table.insert(wants, 2, "xray_potion")
		end
		if not has(p, "time_potion") and not p.anchor then
			table.insert(wants, "time_potion")
		end
		table.insert(wants, "jeopardy_potion")
		table.insert(wants, "speed_potion")
		for _, item in wants do
			local def = Items.get(item)
			if p.coins >= def.price and (game.stock[item] or 0) > 0 then
				game.turn.botBought = bought + 1
				return { type = "buy", item = item }
			end
		end
	end
	return { type = "shopDone" }
end

local function pickCommand(game, p)
	local pick = game.turn and game.turn.pick
	if not pick then
		return { type = "pick", index = 1 }
	end
	local best, bestRank = 1, math.huge
	for i, item in pick.options do
		local rank = table.find(TRAP_ORDER, item) or 99
		if rank < bestRank then
			best, bestRank = i, rank
		end
	end
	return { type = "pick", index = best }
end

---------------------------------------------------------------------------
-- main decision
---------------------------------------------------------------------------

function Bot.decide(game, seat: number)
	local p = game.players[seat]
	if game.phase == "shop" then
		return shopCommand(game, p)
	elseif game.phase == "pick" then
		return pickCommand(game, p)
	end
	if game.phase ~= "action" or game.turn == nil then
		return nil
	end
	local turn = game.turn

	-- free actions first: the ability (its bar is full, so waiting wastes charge)
	local cmd = abilityCommand(game, p)
	if cmd then
		return cmd
	end

	-- one card per turn
	if turn.cardsPlayed < Rules.CardsPerTurn then
		local play, v = bestCardPlay(game, p)
		if play and v > 0 then
			return play
		end
	end

	-- then move: pick the better die (forwards, backwards with the second of a pair, or the
	-- total of doubles), or recall
	local best, bestV = bestMove(game, p, turn.dice, turn.boost, nil, turn.gold)
	if p.anchor then
		local here = distOf(game, p, p.tile)
		local there = distOf(game, p, p.anchor.tile)
		local v = here - there + landingValue(game, p, p.anchor.tile)
		if v > bestV + 1 then
			return { type = "recall" }
		end
	end
	return { type = "move", die = if best then best.die else 1 }
end

-- Exposed for tests and the tutorial hints.
Bot.moveValue = moveValue
Bot.bestMove = bestMove
Bot.landingOdds = landingOdds

return Bot
