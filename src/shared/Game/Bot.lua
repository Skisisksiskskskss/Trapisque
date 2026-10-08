--[[
	Bot
	A simple, readable AI for Trapisque. Bots fill empty seats, replace players who
	leave, and power "Practice vs Bots".

	Bot.decide(game, seat) returns ONE command for the bot whose turn it is. The server
	calls it repeatedly (with a short "thinking" pause) until the bot's turn ends.
	Bots never cheat: they only use information a player could see on the board, plus
	their own hand.
]]

local Config = require(script.Parent.Parent.Config)
local Items = require(script.Parent.Items)
local Characters = require(script.Parent.Characters)

local Rules = Config.Rules

local Bot = {}

local TRAP_VALUE = {
	spike = 10,
	grog = 8,
	snare = 7,
	fire = 6,
	mudslide = 5,
	ice = 5,
	wall = 4,
	mud = 3,
	river_trap = 6,
	gate_trap = 6,
	slime_trap = 5,
	conveyor = 4,
	shifting_sands = 3,
	spore_warper = 3,
	teleporter = 1,
}

local function has(p, item)
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

local function leader(game, list)
	local best, bestScore = nil, -math.huge
	for _, o in list do
		local s = game:score(o)
		if s > bestScore then
			best, bestScore = o, s
		end
	end
	return best
end

local function dist(game, p)
	return game.board.dist[p.tile] or 0
end

local function needsToScore(p)
	return not p.finished
end

---------------------------------------------------------------------------
-- ability
---------------------------------------------------------------------------

local function abilityCommand(game, p)
	local def = Characters.get(p.character)
	local ab = def and def.ability
	if not ab or not p.ability.ready or game.turn == nil or game.turn.abilityUsed then
		return nil
	end
	local opps = opponents(game, p)
	if ab.id == "hex" then
		local target = leader(game, opps)
		if target then
			if target.character ~= "mage" and not target.status.frozen then
				return { type = "ability", target = target.index, option = "freeze" }
			elseif not target.status.burning then
				return { type = "ability", target = target.index, option = "burn" }
			end
		end
	elseif ab.id == "scavenge" then
		if #p.hand < Rules.HandLimit then
			return { type = "ability" }
		end
	elseif ab.id == "ignite" then
		for _, o in opps do
			if o.tile == p.tile and not o.status.burning then
				return { type = "ability", target = o.index }
			end
		end
	elseif ab.id == "warp" then
		local myDist = dist(game, p)
		local best, bestGain = nil, 0
		for _, o in game.players do
			if o ~= p and o.tile ~= p.tile then
				local gain
				if needsToScore(p) then
					gain = myDist - dist(game, o) -- how much closer I'd get
				elseif o.team ~= p.team then
					gain = myDist - dist(game, o) -- send a leading opponent back to my spot
				else
					gain = 0
				end
				if o.team == p.team and needsToScore(o) then
					gain -= (dist(game, o) - myDist) * 2 -- don't hurt teammates
				end
				if gain > bestGain then
					best, bestGain = o, gain
				end
			end
		end
		if best and bestGain >= 8 then
			return { type = "ability", target = best.index }
		end
	elseif ab.id == "nudge" then
		if needsToScore(p) and dist(game, p) == 1 then
			return { type = "ability", target = p.index, option = "fwd" }
		end
		for _, o in game.players do
			if o.team == p.team and o ~= p and needsToScore(o) and dist(game, o) == 1 then
				return { type = "ability", target = o.index, option = "fwd" }
			end
		end
		local target = leader(game, opps)
		if target and #target.trail > 1 then
			return { type = "ability", target = target.index, option = "back" }
		end
		if needsToScore(p) then
			return { type = "ability", target = p.index, option = "fwd" }
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- placing cards
---------------------------------------------------------------------------

-- Best tile to drop `item`, or nil. Higher score = more opponents likely to land there.
local function bestPlacement(game, p, item)
	local candidates = {}
	local seen = {}
	local opps = opponents(game, p)
	local myPath = if needsToScore(p) then game:projectPath(p, 6) else {}
	local mates = {}
	for _, o in game.players do
		if o ~= p and o.team == p.team and needsToScore(o) then
			table.insert(mates, game:projectPath(o, 6))
		end
	end
	local helpful = item == "teleporter"
	for _, o in opps do
		for k, tile in game:projectPath(o, 6) do
			if not seen[tile] then
				seen[tile] = true
				local dir = if item == "conveyor" then "back" else nil
				if game:canPlace(item, tile, dir) then
					local score = 0
					for _, other in opps do
						local path = game:projectPath(other, 6)
						if table.find(path, tile) then
							-- closer to the treasure = juicier target
							score += 1 + other.treasures * 0.5 + (if dist(game, other) < 10 then 0.5 else 0)
						end
					end
					if table.find(myPath, tile) then
						score -= 2
					end
					for _, path in mates do
						if table.find(path, tile) then
							score -= 1.5
						end
					end
					-- middle rolls (2-5) are slightly more reachable with boosts in play
					if k >= 2 and k <= 5 then
						score += 0.25
					end
					table.insert(candidates, { tile = tile, score = score, dir = dir })
				end
			end
		end
	end
	if helpful then
		-- teleporters: just drop one somewhere legal ahead of me
		for _, tile in myPath do
			if game:canPlace(item, tile, nil) then
				return { tile = tile, score = 1 }
			end
		end
		return nil
	end
	table.sort(candidates, function(a, b)
		return a.score > b.score
	end)
	if candidates[1] and candidates[1].score > 0 then
		return candidates[1]
	end
	return nil
end

local function placeCommand(game, p)
	-- pick the most valuable placeable card we hold
	local best, bestValue = nil, 0
	for _, item in p.hand do
		local def = Items.get(item)
		if def and def.use == "place" then
			local v = TRAP_VALUE[item] or 1
			if v > bestValue then
				best, bestValue = item, v
			end
		end
	end
	if not best then
		return nil
	end
	local opps = opponents(game, p)
	local lead = leader(game, opps)
	if not lead then
		return nil
	end
	-- how eager are we to spend our turn placing?
	local eagerness = 0.3
	if game:score(lead) >= game:score(p) then
		eagerness += 0.3
	end
	if dist(game, lead) <= 10 then
		eagerness += 0.2
	end
	if p.finished then
		eagerness += 0.15 -- finished teammates still carry treasure, but love to make trouble
	end
	if #p.hand >= Rules.HandLimit - 1 then
		eagerness += 0.2
	end
	if game.rng:float() > eagerness then
		return nil
	end
	local spot = bestPlacement(game, p, best)
	if not spot then
		return nil
	end
	return { type = "use", item = best, tile = spot.tile, dir = spot.dir }
end

---------------------------------------------------------------------------
-- shop
---------------------------------------------------------------------------

local SHOP_PRIORITY = { "phoenix_potion", "telepathy_potion", "jeopardy_potion", "time_potion", "speed_potion" }

local function shopCommand(game, p)
	local bought = game.turn and game.turn.botBought or 0
	if bought < 2 then
		for _, item in SHOP_PRIORITY do
			local def = Items.get(item)
			local owned = has(p, item)
			if
				not owned
				and p.coins >= def.price
				and (game.stock[item] or 0) > 0
				and #p.hand < Rules.HandLimit
			then
				if game.turn then
					game.turn.botBought = bought + 1
				end
				return { type = "buy", item = item }
			end
		end
	end
	return { type = "shopDone" }
end

---------------------------------------------------------------------------
-- main decision
---------------------------------------------------------------------------

local function hasRoomFor(mate, item): boolean
	local n = 0
	for _, v in mate.hand do
		if v == item then
			n += 1
		end
	end
	return n < Rules.PerItemLimit
end

function Bot.decide(game, seat: number)
	local p = game.players[seat]
	if game.phase == "shop" then
		return shopCommand(game, p)
	end
	if game.phase ~= "action" or game.turn == nil then
		return nil
	end
	local rng = game.rng

	-- free actions first
	local cmd = abilityCommand(game, p)
	if cmd then
		return cmd
	end

	if p.finished and game.mode.isTeam and #p.hand > 0 then
		for _, mate in game.players do
			if mate ~= p and mate.team == p.team and not mate.finished and #mate.hand < Rules.HandLimit then
				for _, item in p.hand do
					if hasRoomFor(mate, item) then
						return { type = "give", item = item, target = mate.index }
					end
				end
			end
		end
	end

	local def = Characters.get(p.character)
	local ab = def and def.ability
	if has(p, "regeneration") and ab and ab.recharge ~= "perTurn" and not p.ability.ready then
		return { type = "use", item = "regeneration" }
	end

	if has(p, "time_potion") and not p.anchor and p.tile ~= game.board.start and dist(game, p) <= 8 then
		return { type = "use", item = "time_potion" }
	end

	-- main action
	if p.anchor and (game.board.dist[p.anchor.tile] or 99) + 6 < dist(game, p) then
		return { type = "recall" }
	end

	local opps = opponents(game, p)
	local lead = leader(game, opps)

	if has(p, "jeopardy_potion") and lead and game:score(lead) - game:score(p) >= 600 then
		return { type = "use", item = "jeopardy_potion", target = lead.index }
	end

	if has(p, "telepathy_potion") then
		if needsToScore(p) and dist(game, p) <= Rules.TelepathyMax then
			return { type = "use", item = "telepathy_potion", target = p.index, steps = dist(game, p) }
		end
		for _, o in opps do
			if needsToScore(o) and dist(game, o) <= 4 and #o.trail > 1 then
				return { type = "use", item = "telepathy_potion", target = o.index, steps = -Rules.TelepathyMax }
			end
		end
	end

	cmd = placeCommand(game, p)
	if cmd then
		return cmd
	end

	if has(p, "moonwalk") and #p.trail > 1 and rng:float() < 0.2 then
		-- step back onto a juicy token if there is one
		for steps = 1, math.min(Rules.MoonwalkMax, #p.trail - 1) do
			local tile = p.trail[#p.trail - steps]
			local token = game.tokens[tile]
			if token == "assist" or (token == "potion" and p.coins >= 2) then
				if not (p.status.burning and steps > 1) then
					return { type = "use", item = "moonwalk", steps = steps }
				end
			end
		end
	end

	-- arm boosts before rolling (not when the treasure is already 1-2 steps away)
	if needsToScore(p) and dist(game, p) > 2 then
		for _, item in { "speed_boost", "bounce_pad", "speed_potion" } do
			if has(p, item) and not game.turn.armed[item] then
				return { type = "arm", item = item }
			end
		end
	end

	return { type = "roll" }
end

return Bot
