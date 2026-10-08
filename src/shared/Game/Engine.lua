--[[
	Engine
	The complete, authoritative Trapisque rules. Pure Luau: no Roblox APIs, so it runs
	the same on the server and in the offline test-suite.

	Usage
		local game = Engine.new({ mode = "chaos", map = "blissful", seed = 42,
			players = { { id = "u1", name = "Ana" }, { id = "bot1", name = "Bot", isBot = true } } })
		local events = game:start()
		local ok, err, events = game:command(seat, { type = "roll" })

	Every state change is reported as an event table (field `t` is the type) so clients
	can animate exactly what happened. See docs/RULES.md for the rules in plain English.

	Turn structure
		Free actions (any order, before your main action):
			ability     use your character ability (once per turn, if charged)
			arm         arm/disarm a Boost card for this turn's roll
			regen       play Regeneration
			anchor      drop a Time Travel anchor
			give        (finished team players) hand a card to a teammate
		Main action (ends your turn):
			roll        roll the die and move
			place       play a card onto the board
			moonwalk    step back 1-3 tiles
			telepathy   move any player 1-3 tiles
			jeopardy    Double Jeopardy
			recall      warp back to your Time Travel anchor
		Landing on a Potion Seller opens the shop: buy / shopDone.
]]

local Config = require(script.Parent.Parent.Config)
local Rng = require(script.Parent.Rng)
local Items = require(script.Parent.Items)
local Characters = require(script.Parent.Characters)
local Maps = require(script.Parent.Maps)
local Modes = require(script.Parent.Modes)
local Board = require(script.Parent.Board)

local Rules = Config.Rules

local Engine = {}
Engine.__index = Engine

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------

local function copyList(list)
	local out = table.create(#list)
	for i, v in list do
		out[i] = v
	end
	return out
end

local function count(list, value): number
	local n = 0
	for _, v in list do
		if v == value then
			n += 1
		end
	end
	return n
end

-- Ice / slime: even moves are halved, odd moves lose 1 (rulebook wording).
local function chill(m: number): number
	if m % 2 == 0 then
		return m // 2
	end
	return m - 1
end
Engine.chill = chill

local function hasCard(p, item: string): boolean
	return table.find(p.hand, item) ~= nil
end

local function removeCard(p, item: string): boolean
	local i = table.find(p.hand, item)
	if i then
		table.remove(p.hand, i)
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function Engine.new(opts)
	local self = setmetatable({}, Engine)
	local mode = Modes.get(opts.mode)
	assert(mode, "Engine: unknown mode " .. tostring(opts.mode))
	local mapDef = Maps.get(opts.map)
	assert(mapDef, "Engine: unknown map " .. tostring(opts.map))
	assert(#opts.players >= 1 and #opts.players <= 6, "Engine: 1-6 players")

	self.mode = mode
	self.map = mapDef
	self.board = Board.get(mapDef)
	self.seed = opts.seed or 1
	self.rng = Rng.new(self.seed)
	self.target = opts.target or mode.target
	self.length = opts.length or "classic"
	self.rechargeCycles = if self.target <= 2 then Rules.QuickRechargeCycles else Rules.AbilityRechargeCycles
	local caps = Rules.MaxRounds
	self.maxRounds = if type(caps) == "table" then (caps[self.length] or caps.classic) else caps
	self.events = {}
	self.phase = "setup"
	self.round = 0
	self.turnCount = 0
	self.turnPtr = 0
	self.turn = nil
	self.current = 0
	self.ranking = nil
	self.winnerTeam = nil
	self.endReason = nil

	-- board layers
	self.tokens = {} -- [tile] = "trap" | "assist" | "neutral" | "potion"
	self.placed = {} -- [tile] = { item, owner, uses, dir, tiles }
	self.cover = {} -- [tile] = origin tile of the conveyor covering it
	self.natural = {} -- [tile] = "river" | "gate" | "slime"
	self.teleporters = {} -- tiles, in placement order (pairs: 1-2, 3-4, ...)
	self.stock = {}
	for _, id in Items.potions do
		self.stock[id] = Rules.PotionStock
	end

	-- players
	self.players = {}
	for i, info in opts.players do
		local p = {
			index = i,
			id = info.id or ("p" .. i),
			userId = info.userId,
			name = info.name or ("Player " .. i),
			isBot = info.isBot == true,
			team = info.team,
			character = info.character,
			tile = self.board.start,
			trail = { self.board.start },
			treasures = 0,
			laps = 0,
			coins = Rules.StartingCoins,
			hand = {},
			status = { burning = false, frozen = false, boots = false, held = false, skip = 0 },
			ability = { ready = true, progress = 0 },
			anchor = nil,
			finished = false,
			stats = { deaths = 0, placed = 0, used = 0, spins = 0, bought = 0, abilities = 0 },
		}
		self.players[i] = p
	end
	self:_assignTeams(opts.teamsPreset == true)
	return self
end

function Engine:_assignTeams(preset: boolean)
	local mode = self.mode
	if not mode.isTeam then
		for _, p in self.players do
			p.team = p.index
		end
		return
	end
	if preset then
		for _, p in self.players do
			assert(p.team, "Engine: teamsPreset requires a team for every player")
		end
		return
	end
	-- Fill teams in seat order: players who arrive together (a party) sit together.
	for _, p in self.players do
		p.team = ((p.index - 1) // mode.teamSize) + 1
	end
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------

function Engine:_emit(evt)
	table.insert(self.events, evt)
end

function Engine:_flushEvents()
	local out = self.events
	self.events = {}
	return out
end

---------------------------------------------------------------------------
-- setup
---------------------------------------------------------------------------

function Engine:start()
	assert(self.phase == "setup", "Engine: already started")
	local rng = self.rng

	-- characters: draw at random, one of each (rulebook)
	local pool = copyList(Characters.ids)
	rng:shuffle(pool)
	for i, p in self.players do
		if p.character == nil or Characters.get(p.character) == nil then
			-- skip characters already claimed by presets
			local pick
			for j, c in pool do
				local taken = false
				for _, other in self.players do
					if other.character == c then
						taken = true
						break
					end
				end
				if not taken then
					pick = table.remove(pool, j)
					break
				end
			end
			p.character = pick or Characters.ids[((i - 1) % #Characters.ids) + 1]
		end
	end

	-- turn order: Overseer always first, everyone else shuffled
	local order = {}
	for _, p in self.players do
		if p.character ~= "overseer" then
			table.insert(order, p.index)
		end
	end
	rng:shuffle(order)
	for _, p in self.players do
		if p.character == "overseer" then
			table.insert(order, 1, p.index)
		end
	end
	self.turnOrder = order

	-- natural traps and pre-set dangers from the map
	for tile, kind in self.board.naturalInit do
		self.natural[tile] = kind
	end
	for tile, item in self.map.startingPlaced or {} do
		self:_addPlaced(tile, item, 0, nil)
	end

	-- tokens: a random token on every token spot (rulebook), at least one Potion Seller
	local spots = copyList(self.board.tokenSpots)
	for _, tile in spots do
		self.tokens[tile] = rng:weighted(Config.TokenWeights)
	end
	local sellers = 0
	for _, kind in self.tokens do
		if kind == "potion" then
			sellers += 1
		end
	end
	if sellers < Config.MinPotionSellers and #spots > 0 then
		local candidates = {}
		for _, tile in spots do
			if self.tokens[tile] ~= "potion" then
				table.insert(candidates, tile)
			end
		end
		rng:shuffle(candidates)
		for i = 1, math.min(Config.MinPotionSellers - sellers, #candidates) do
			self.tokens[candidates[i]] = "potion"
		end
	end

	local setup = { t = "setup", players = {}, order = copyList(order) }
	for _, p in self.players do
		table.insert(setup.players, { seat = p.index, character = p.character, team = p.team })
	end
	self:_emit(setup)

	-- starting cards
	for _, p in self.players do
		local dealt = {}
		if p.character == "trapper" then
			for _ = 1, Rules.TrapperStartingTraps do
				table.insert(dealt, rng:pick(Items.trapIds))
			end
		elseif p.character == "fire_starter" then
			for _ = 1, Rules.FireStarterStartingFires do
				table.insert(dealt, "fire")
			end
		end
		if #dealt > 0 then
			for _, item in dealt do
				table.insert(p.hand, item)
			end
			self:_emit({ t = "deal", p = p.index, items = dealt })
		end
	end

	self.phase = "action"
	self.round = 1
	self:_advance()
	return self:_flushEvents()
end

---------------------------------------------------------------------------
-- turn flow
---------------------------------------------------------------------------

function Engine:currentPlayer()
	return self.players[self.current]
end

-- Moves to the next player who can act. Skipped turns are consumed here.
function Engine:_advance()
	self.turn = nil
	local guard = 0
	while self.phase ~= "over" do
		guard += 1
		if guard > 1000 then
			error("Engine: _advance looped too long")
		end
		self.turnPtr += 1
		if self.turnPtr > #self.turnOrder then
			self.turnPtr = 1
			self.round += 1
			self:_onNewRound()
			if self.round > self.maxRounds then
				self:_gameOver(nil, "rounds")
				return
			end
		end
		if self:_beginTurn() then
			return
		end
	end
end

function Engine:_beginTurn(): boolean
	local seat = self.turnOrder[self.turnPtr]
	local p = self.players[seat]
	self.current = seat
	self.turnCount += 1
	self.turn = { armed = {}, abilityUsed = false, number = self.turnCount }
	self.phase = "action"
	self:_emit({ t = "turn", p = seat, round = self.round, n = self.turnCount })
	if p.status.skip > 0 then
		p.status.skip -= 1
		self:_emit({ t = "skip", p = seat })
		self.turn = nil
		return false
	end
	return true
end

function Engine:_finishTurn()
	if self.phase == "over" then
		return
	end
	self.phase = "action"
	self:_advance()
end

function Engine:_onNewRound()
	for _, p in self.players do
		local def = Characters.get(p.character)
		local ab = def and def.ability
		if ab and ab.recharge == "rounds" and not p.ability.ready then
			p.ability.progress += 1
			if p.ability.progress >= ab.amount then
				p.ability.ready = true
				p.ability.progress = 0
				self:_emit({ t = "recharge", p = p.index })
			end
		end
	end
end

function Engine:_onCycleComplete(p)
	local def = Characters.get(p.character)
	local ab = def and def.ability
	if ab and ab.recharge == "cycles" and not p.ability.ready then
		p.ability.progress += 1
		if p.ability.progress >= self.rechargeCycles then
			p.ability.ready = true
			p.ability.progress = 0
			self:_emit({ t = "recharge", p = p.index })
		end
	end
end

---------------------------------------------------------------------------
-- board layer helpers
---------------------------------------------------------------------------

function Engine:_addPlaced(tile: number, item: string, owner: number, dir: string?)
	local entry = { item = item, owner = owner, uses = Rules.PlacedUses[item], dir = dir }
	if item == "conveyor" then
		local tiles = self.board:span(tile, Rules.ConveyorLength)
		assert(tiles, "Engine: conveyor span invalid")
		entry.tiles = tiles
		for _, t in tiles do
			self.cover[t] = tile
		end
	elseif item == "teleporter" then
		table.insert(self.teleporters, tile)
	end
	self.placed[tile] = entry
end

function Engine:_removePlaced(tile: number, reason: string)
	local entry = self.placed[tile]
	if not entry then
		return
	end
	if entry.tiles then
		for _, t in entry.tiles do
			self.cover[t] = nil
		end
	end
	if entry.item == "teleporter" then
		local i = table.find(self.teleporters, tile)
		if i then
			table.remove(self.teleporters, i)
		end
	end
	self.placed[tile] = nil
	self:_emit({ t = "removed", tile = tile, item = entry.item, reason = reason })
end

-- One trigger of a placed item: decrements uses and removes it when spent.
function Engine:_usePlaced(tile: number)
	local entry = self.placed[tile]
	if not entry then
		return
	end
	if entry.uses == nil then
		if Items.isTrap(entry.item) or entry.item == "spore_warper" then
			self:_removePlaced(tile, "used")
		end
		return
	end
	entry.uses -= 1
	if entry.uses <= 0 then
		self:_removePlaced(tile, "used")
	end
end

function Engine:_teleportPartner(tile: number): number?
	local i = table.find(self.teleporters, tile)
	if not i then
		return nil
	end
	local partnerIndex = if i % 2 == 1 then i + 1 else i - 1
	return self.teleporters[partnerIndex]
end

-- Placement rules, shared with the client (it passes layers rebuilt from a snapshot).
-- layers = { placed, cover, natural, tokens, teleporters? }
function Engine.checkPlacement(board, layers, itemId: string, tile: number, dir: string?): (boolean, string?)
	local def = Items.get(itemId)
	if not def or def.use ~= "place" then
		return false, "That card can't be placed."
	end
	if type(tile) ~= "number" or board.tiles[tile] == nil then
		return false, "Pick a tile on the board."
	end
	local function free(t: number): (boolean, string?)
		if board:isSpecial(t) then
			return false, "Not on the Start or Treasure tile."
		end
		if layers.tokens[t] then
			return false, "That tile already has a token."
		end
		if layers.natural[t] then
			return false, "A natural trap is already there."
		end
		if layers.placed[t] or layers.cover[t] then
			return false, "Something is already placed there."
		end
		if board.tiles[t].kind == "shortcutGate" then
			return false, "Not on a shortcut gate."
		end
		return true, nil
	end
	if itemId == "conveyor" then
		if dir ~= "fwd" and dir ~= "back" then
			return false, "Choose a direction for the belt."
		end
		local span = board:span(tile, Rules.ConveyorLength)
		if not span then
			return false, "The belt needs 3 tiles before the treasure."
		end
		for _, t in span do
			local ok, why = free(t)
			if not ok then
				return false, "Belt blocked: " .. why
			end
		end
		return true, nil
	end
	local ok, why = free(tile)
	if not ok then
		return false, why
	end
	if itemId == "teleporter" and (board.dist[tile] or 0) < Rules.TeleporterMinDistance then
		return false, "Teleporters must be at least " .. Rules.TeleporterMinDistance .. " tiles from the treasure."
	end
	return true, nil
end

function Engine:canPlace(itemId: string, tile: number, dir: string?): (boolean, string?)
	return Engine.checkPlacement(self.board, self, itemId, tile, dir)
end

---------------------------------------------------------------------------
-- cards
---------------------------------------------------------------------------

function Engine:_giveCard(p, item: string, source: string?)
	if #p.hand >= Rules.HandLimit or count(p.hand, item) >= Rules.PerItemLimit then
		self:_emit({ t = "handFull", p = p.index, item = item })
		return false
	end
	table.insert(p.hand, item)
	self:_emit({ t = "gain", p = p.index, item = item, source = source })
	return true
end

function Engine:_spin(p, wheel: string)
	local segments = Items.wheels[wheel]
	local index = self.rng:int(1, #segments)
	local segment = segments[index]
	local result = segment
	if segment == "bkb" then
		result = if p.character == "naturalist" then self.map.naturalCard else self.map.counterItem
	end
	p.stats.spins += 1
	self:_emit({ t = "spin", p = p.index, wheel = wheel, index = index, result = result })
	if result == "coin" then
		p.coins += 1
		self:_emit({ t = "coin", p = p.index, coins = p.coins })
	else
		self:_giveCard(p, result, wheel)
	end
end

---------------------------------------------------------------------------
-- statuses, death, treasure
---------------------------------------------------------------------------

function Engine:_setStatus(p, status: string, source: string)
	if status == "frozen" and p.character == "mage" then
		self:_emit({ t = "immune", p = p.index, what = "ice" })
		return
	end
	p.status[status] = true
	self:_emit({ t = "status", p = p.index, status = status, on = true, source = source })
end

function Engine:_clearCycleStatuses(p)
	p.status.burning = false
	p.status.frozen = false
	p.status.boots = false
	p.status.held = false
end

function Engine:_sendToStart(p, kind: string)
	p.tile = self.board.start
	p.trail = { self.board.start }
	self:_clearCycleStatuses(p)
	self:_emit({ t = "move", p = p.index, path = { self.board.start }, kind = kind })
end

-- Returns true if the player actually died.
function Engine:_kill(p, cause: string, fromTrap: boolean): boolean
	if removeCard(p, "phoenix_potion") then
		self:_emit({ t = "phoenix", p = p.index, cause = cause })
		return false
	end
	local doubled = p.status.burning or (fromTrap and p.character == "naturalist")
	local lost = false
	if doubled and not p.finished and p.treasures > 0 then
		p.treasures -= 1
		lost = true
	end
	p.stats.deaths += 1
	self:_emit({ t = "death", p = p.index, cause = cause, lost = lost, treasures = p.treasures })
	self:_sendToStart(p, "respawn")
	return true
end

function Engine:_reachTreasure(p)
	p.laps += 1
	if p.finished then
		-- (rulebook) a finished player keeps playing to help their team, but their laps
		-- don't count towards anyone's treasures and earn nothing
		self:_emit({ t = "lap", p = p.index })
		self:_onCycleComplete(p)
		self:_sendToStart(p, "home")
		return
	end
	p.treasures += 1
	p.coins += Rules.CoinsPerTreasure
	self:_emit({ t = "treasure", p = p.index, treasures = p.treasures, coins = p.coins })
	self:_onCycleComplete(p)
	self:_sendToStart(p, "home")
	if p.treasures >= self.target then
		p.finished = true
		self:_emit({ t = "finished", p = p.index })
		self:_checkWin(p)
	end
end

function Engine:_checkWin(p)
	if self.phase == "over" then
		return
	end
	if not self.mode.isTeam then
		self:_gameOver(p.team, "treasure")
		return
	end
	for _, other in self.players do
		if other.team == p.team and not other.finished then
			return
		end
	end
	self:_gameOver(p.team, "treasure")
end

function Engine:score(p): number
	-- treasures first, then how close you are to the next one
	return p.treasures * 1000 + (1000 - (self.board.dist[p.tile] or 0))
end

function Engine:teamScore(team: number): number
	local s = 0
	for _, p in self.players do
		if p.team == team then
			s += self:score(p)
		end
	end
	return s
end

function Engine:_gameOver(winnerTeam: number?, reason: string)
	if self.phase == "over" then
		return
	end
	if winnerTeam == nil then
		-- decided by score (round limit)
		local best, bestScore = nil, -math.huge
		local seen = {}
		for _, p in self.players do
			if not seen[p.team] then
				seen[p.team] = true
				local s = self:teamScore(p.team)
				if self.mode.isTeam then
					-- average so uneven teams compare fairly
					local n = 0
					for _, q in self.players do
						if q.team == p.team then
							n += 1
						end
					end
					s = s / math.max(n, 1)
				end
				if s > bestScore then
					best, bestScore = p.team, s
				end
			end
		end
		winnerTeam = best
	end
	self.winnerTeam = winnerTeam
	self.endReason = reason
	self.phase = "over"
	self.turn = nil

	local ranking = {}
	for _, p in self.players do
		table.insert(ranking, p.index)
	end
	table.sort(ranking, function(a, b)
		local pa, pb = self.players[a], self.players[b]
		local wa, wb = pa.team == winnerTeam, pb.team == winnerTeam
		if wa ~= wb then
			return wa
		end
		if self.mode.isTeam and pa.team ~= pb.team then
			return self:teamScore(pa.team) > self:teamScore(pb.team)
		end
		local sa, sb = self:score(pa), self:score(pb)
		if sa ~= sb then
			return sa > sb
		end
		return a < b
	end)
	self.ranking = ranking
	self:_emit({ t = "gameover", team = winnerTeam, ranking = copyList(ranking), reason = reason })
end

---------------------------------------------------------------------------
-- movement
---------------------------------------------------------------------------

-- Where a dice walk goes next from `cur`. Gated shortcuts need a Key (or the Naturalist).
function Engine:_peekNext(p, cur: number, keys: number): (number?, boolean)
	local sc = self.board.shortcut[cur]
	if sc and (p.character == "naturalist" or keys > 0) then
		return sc, p.character ~= "naturalist"
	end
	return self.board.nextMain[cur], false
end

-- The tiles a dice walk of `m` steps would visit (no side effects).
function Engine:projectPath(p, m: number): { number }
	local path = {}
	local cur = p.tile
	local keys = count(p.hand, "key")
	for _ = 1, m do
		local nxt, usedKey = self:_peekNext(p, cur, keys)
		if not nxt then
			break
		end
		if usedKey then
			keys -= 1
		end
		table.insert(path, nxt)
		cur = nxt
		if nxt == self.board.treasure then
			break
		end
	end
	return path
end

-- Dice walk. Returns "landed" | "blocked" | "stopped" | "treasure".
function Engine:_walk(p, m: number): string
	local board = self.board
	local path = {}
	local crumbled = {}
	local function flush()
		if #path > 0 then
			self:_emit({ t = "move", p = p.index, path = path, kind = "walk" })
			path = {}
		end
	end
	local wallsBlock = m < Rules.WallPassMin
	local steps = 0
	local result = "landed"
	while steps < m do
		local cur = p.tile
		local nxt, usesKey = self:_peekNext(p, cur, count(p.hand, "key"))
		if not nxt then
			break
		end
		if usesKey then
			removeCard(p, "key")
			flush()
			self:_emit({ t = "useCard", p = p.index, item = "key", tile = nxt, why = "shortcut" })
		end
		-- walls: you can't move past one unless you move 5+; landing on it is fine
		local entry = self.placed[nxt]
		if entry and entry.item == "wall" and steps + 1 < m then
			if wallsBlock then
				if removeCard(p, "shield") then
					flush()
					self:_emit({ t = "shield", p = p.index, item = "wall", tile = nxt })
					table.insert(crumbled, nxt)
				else
					flush()
					self:_emit({ t = "blocked", p = p.index, tile = nxt })
					result = "blocked"
					break
				end
			else
				table.insert(crumbled, nxt)
			end
		end
		p.tile = nxt
		table.insert(p.trail, nxt)
		table.insert(path, nxt)
		steps += 1
		if nxt == board.treasure then
			result = "treasure"
			break
		end
		local nat = self.natural[nxt]
		if nat and p.character ~= "naturalist" then
			if nat == "river" then
				if removeCard(p, "bridge") then
					flush()
					self:_emit({ t = "useCard", p = p.index, item = "bridge", tile = nxt })
				else
					-- (digital) the rulebook only says a Bridge gets you across; without one
					-- you fall in and your move ends at the river
					flush()
					self:_emit({ t = "natural", p = p.index, kind = "river", tile = nxt })
					result = "stopped"
					break
				end
			elseif nat == "gate" then
				if removeCard(p, "key") then
					flush()
					self:_emit({ t = "useCard", p = p.index, item = "key", tile = nxt })
				else
					flush()
					p.status.held = true
					self:_emit({ t = "natural", p = p.index, kind = "gate", tile = nxt })
					result = "stopped"
					break
				end
			end
		end
	end
	flush()
	for _, tile in crumbled do
		if self.placed[tile] and self.placed[tile].item == "wall" then
			self:_removePlaced(tile, "crumble")
		end
	end
	return result
end

-- Forced movement (traps, potions, abilities). Ignores traps, tokens and natural traps.
function Engine:_shiftForward(p, n: number, kind: string)
	local board = self.board
	local path = {}
	p.status.held = false
	for _ = 1, n do
		local cur = p.tile
		local nxt = (p.character == "naturalist" and board.shortcut[cur]) or board.nextMain[cur]
		if not nxt then
			break
		end
		p.tile = nxt
		table.insert(p.trail, nxt)
		table.insert(path, nxt)
		if nxt == board.treasure then
			self:_emit({ t = "move", p = p.index, path = path, kind = kind })
			self:_reachTreasure(p)
			return
		end
	end
	if #path > 0 then
		self:_emit({ t = "move", p = p.index, path = path, kind = kind })
	end
end

function Engine:_shiftBack(p, n: number, kind: string)
	local path = {}
	p.status.held = false
	for _ = 1, n do
		if #p.trail <= 1 then
			break
		end
		table.remove(p.trail)
		p.tile = p.trail[#p.trail]
		table.insert(path, p.tile)
	end
	if #path > 0 then
		self:_emit({ t = "move", p = p.index, path = path, kind = kind })
	end
end

function Engine:_shift(p, n: number, kind: string)
	if n > 0 then
		self:_shiftForward(p, n, kind)
	elseif n < 0 then
		self:_shiftBack(p, -n, kind)
	end
end

function Engine:_warpTo(p, tile: number, kind: string, trail: { number }?)
	p.tile = tile
	p.trail = if trail then copyList(trail) else copyList(self.board.pathFromStart[tile])
	p.status.held = false
	self:_emit({ t = "move", p = p.index, path = { tile }, kind = kind })
end

function Engine:_swap(a, b, kind: string)
	local ta, tb = a.tile, b.tile
	local trailA, trailB = a.trail, b.trail
	a.tile, b.tile = tb, ta
	a.trail, b.trail = trailB, trailA
	a.status.held = false
	b.status.held = false
	self:_emit({ t = "swap", a = a.index, b = b.index, kind = kind, ta = a.tile, tb = b.tile })
end

function Engine:_nearestOther(p)
	local best, bestDist = {}, math.huge
	for _, other in self.players do
		if other ~= p and other.character ~= "warper" then
			local d = self.board:tileDistance(p.tile, other.tile)
			if d < bestDist then
				best, bestDist = { other }, d
			elseif d == bestDist then
				table.insert(best, other)
			end
		end
	end
	if #best == 0 then
		return nil
	end
	return self.rng:pick(best)
end

---------------------------------------------------------------------------
-- landing
---------------------------------------------------------------------------

function Engine:_land(p)
	if self.phase == "over" then
		return
	end
	local tile = p.tile
	if tile == self.board.start then
		return
	end
	local origin = self.cover[tile]
	if origin then
		self:_rideConveyor(p, origin)
		return
	end
	local entry = self.placed[tile]
	if entry then
		if entry.item == "wall" then
			self:_emit({ t = "trigger", p = p.index, tile = tile, item = "wall", owner = entry.owner })
			self:_removePlaced(tile, "crumble")
		else
			local deaths = p.stats.deaths
			self:_trigger(p, tile, entry)
			if p.tile ~= tile or p.stats.deaths ~= deaths or self.phase == "over" then
				return
			end
		end
	end
	local token = self.tokens[tile]
	if token then
		if token == "potion" then
			self.phase = "shop"
			self:_emit({ t = "shop", p = p.index, tile = tile })
		else
			self:_spin(p, token)
		end
	end
end

function Engine:_rideConveyor(p, origin: number)
	local entry = self.placed[origin]
	if not entry then
		return
	end
	self:_emit({ t = "trigger", p = p.index, tile = p.tile, item = "conveyor", owner = entry.owner, dir = entry.dir })
	local tiles = entry.tiles
	local steps
	if entry.dir == "fwd" then
		local pos = table.find(tiles, p.tile) or 1
		steps = #tiles - pos + 1
		self:_usePlaced(origin)
		self:_shiftForward(p, steps, "conveyor")
	else
		-- ride back off the start of the belt (retrace the trail)
		local pos = table.find(tiles, p.tile) or 1
		steps = pos
		self:_usePlaced(origin)
		self:_shiftBack(p, steps, "conveyor")
	end
end

function Engine:_trigger(p, tile: number, entry)
	local item = entry.item
	local def = Items.get(item)
	self:_emit({ t = "trigger", p = p.index, tile = tile, item = item, owner = entry.owner })
	if def.category == "trap" then
		self:_usePlaced(tile)
		if removeCard(p, "shield") then
			self:_emit({ t = "shield", p = p.index, item = item, tile = tile })
			return
		end
		local double = p.status.burning or p.character == "naturalist"
		local mult = if double then 2 else 1
		if item == "spike" then
			self:_kill(p, "spike", true)
		elseif item == "fire" then
			self:_setStatus(p, "burning", "fire")
		elseif item == "ice" then
			self:_setStatus(p, "frozen", "ice")
		elseif item == "mudslide" then
			self:_shiftBack(p, Rules.MudslideBack * mult, "mudslide")
		elseif item == "mud" then
			self:_shiftBack(p, Rules.MudBack * mult, "mud")
		elseif item == "snare" then
			p.status.skip += 1
			self:_emit({ t = "snared", p = p.index })
		elseif item == "grog" then
			local roll = self.rng:int(1, 6)
			local survived = roll >= Rules.GrogSurviveMin
			self:_emit({ t = "grog", p = p.index, roll = roll, survived = survived })
			if not survived then
				self:_kill(p, "grog", true)
			end
		end
		return
	end
	-- neutral cards
	if item == "teleporter" then
		local partner = self:_teleportPartner(tile)
		if partner then
			self:_warpTo(p, partner, "teleport")
		else
			self:_emit({ t = "fizzle", p = p.index, item = item, tile = tile })
		end
	elseif item == "spore_warper" then
		self:_usePlaced(tile)
		if p.character == "warper" then
			self:_emit({ t = "immune", p = p.index, what = "swap" })
		else
			local other = self:_nearestOther(p)
			if other then
				self:_swap(p, other, "spore")
			else
				self:_emit({ t = "fizzle", p = p.index, item = item, tile = tile })
			end
		end
	elseif item == "shifting_sands" then
		self:_usePlaced(tile)
		local k = p.treasures
		local cycle = k + 1
		self:_emit({ t = "sands", p = p.index, amount = k, forward = cycle % 2 == 0 })
		if k > 0 then
			if cycle % 2 == 0 then
				self:_shiftForward(p, k, "sands")
			else
				self:_shiftBack(p, k, "sands")
			end
		end
	end
end

---------------------------------------------------------------------------
-- commands
---------------------------------------------------------------------------

local function fail(msg: string)
	return false, msg, {}
end

function Engine:command(seat: number, cmd)
	if type(cmd) ~= "table" or type(cmd.type) ~= "string" then
		return fail("Bad command.")
	end
	if self.phase == "over" then
		return fail("The game is over.")
	end
	if self.phase == "setup" then
		return fail("The game hasn't started.")
	end
	if seat ~= self.current then
		return fail("It's not your turn.")
	end
	local p = self.players[seat]
	local kind = cmd.type
	local ok, err
	if self.phase == "shop" then
		if kind == "buy" then
			ok, err = self:_cmdBuy(p, cmd)
		elseif kind == "shopDone" then
			ok, err = self:_cmdShopDone(p)
		else
			return fail("Finish shopping first.")
		end
	elseif kind == "roll" then
		ok, err = self:_cmdRoll(p)
	elseif kind == "use" then
		ok, err = self:_cmdUse(p, cmd)
	elseif kind == "arm" then
		ok, err = self:_cmdArm(p, cmd)
	elseif kind == "ability" then
		ok, err = self:_cmdAbility(p, cmd)
	elseif kind == "recall" then
		ok, err = self:_cmdRecall(p)
	elseif kind == "give" then
		ok, err = self:_cmdGive(p, cmd)
	else
		return fail("Unknown command.")
	end
	if not ok then
		-- nothing should have been emitted, but never leak half-done events
		self.events = {}
		return false, err, {}
	end
	return true, nil, self:_flushEvents()
end

-- What a timed-out player does automatically.
function Engine:autoAct()
	if self.phase == "shop" then
		return self:command(self.current, { type = "shopDone" })
	elseif self.phase == "action" then
		return self:command(self.current, { type = "roll" })
	end
	return false, "Nothing to do.", {}
end

function Engine:_cmdRoll(p)
	local rng = self.rng
	local die = rng:int(1, 6)
	local escaped = nil
	if p.status.held then
		if die < Rules.GateEscapeMin then
			self:_emit({ t = "roll", p = p.index, die = die, move = 0, held = true, escaped = false, mods = {} })
			self:_finishTurn()
			return true
		end
		p.status.held = false
		escaped = true
	end
	local m = die
	local mods = {}
	if p.status.frozen then
		m = chill(m)
		table.insert(mods, "frozen")
	end
	local armed = self.turn and self.turn.armed or {}
	local burning = p.status.burning
	if armed.speed_boost and removeCard(p, "speed_boost") then
		m = if burning then math.floor(m * 1.5) else m * 2
		table.insert(mods, "speed_boost")
	end
	if armed.speed_potion and removeCard(p, "speed_potion") then
		m += 1
		table.insert(mods, "speed_potion")
	end
	if armed.bounce_pad and removeCard(p, "bounce_pad") then
		m += if burning then math.max(1, Rules.BounceForward // 2) else Rules.BounceForward
		table.insert(mods, "bounce_pad")
	end
	if self.turn then
		self.turn.armed = {}
	end
	-- slime: if the move would cross slime, the whole move is chilled (unless Boots)
	if m > 0 and p.character ~= "naturalist" and not p.status.boots then
		local crosses = false
		for _, t in self:projectPath(p, m) do
			if self.natural[t] == "slime" then
				crosses = true
				break
			end
		end
		if crosses then
			if removeCard(p, "boots") then
				p.status.boots = true
				table.insert(mods, "boots")
			else
				m = chill(m)
				table.insert(mods, "slime")
			end
		end
	end
	self:_emit({ t = "roll", p = p.index, die = die, move = m, mods = mods, escaped = escaped })
	if m > 0 then
		local result = self:_walk(p, m)
		if result == "treasure" then
			self:_reachTreasure(p)
		elseif result == "landed" or result == "blocked" then
			self:_land(p)
		end
	end
	if self.phase == "action" then
		self:_finishTurn()
	end
	return true
end

function Engine:_cmdArm(p, cmd)
	local item = cmd.item
	local def = type(item) == "string" and Items.get(item)
	if not def or def.use ~= "boost" then
		return false, "That card isn't a boost."
	end
	if not hasCard(p, item) then
		return false, "You don't have that card."
	end
	local armed = self.turn.armed
	if armed[item] then
		armed[item] = nil
		self:_emit({ t = "arm", p = p.index, item = item, on = false })
	else
		armed[item] = true
		self:_emit({ t = "arm", p = p.index, item = item, on = true })
	end
	return true
end

function Engine:_validTarget(p, target, allowSelf: boolean): (any, string?)
	if type(target) ~= "number" then
		return nil, "Choose a player."
	end
	local t = self.players[target]
	if not t then
		return nil, "Choose a player."
	end
	if t == p and not allowSelf then
		return nil, "Choose someone else."
	end
	return t, nil
end

function Engine:_cmdUse(p, cmd)
	local item = cmd.item
	local def = type(item) == "string" and Items.get(item)
	if not def then
		return false, "Unknown card."
	end
	if not hasCard(p, item) then
		return false, "You don't have that card."
	end
	local use = def.use
	if use == "place" then
		local tile = tonumber(cmd.tile)
		local dir = cmd.dir
		local ok, why = self:canPlace(item, tile :: number, dir)
		if not ok then
			return false, why
		end
		removeCard(p, item)
		p.stats.placed += 1
		p.stats.used += 1
		if def.category == "natural" then
			self.natural[tile :: number] = def.natural
		else
			self:_addPlaced(tile :: number, item, p.index, if item == "conveyor" then dir else nil)
		end
		self:_emit({ t = "place", p = p.index, item = item, tile = tile, dir = if item == "conveyor" then dir else nil })
		self:_finishTurn()
		return true
	elseif use == "moonwalk" then
		local max = Rules.MoonwalkMax
		if p.status.burning then
			max = math.max(1, max // 2)
		end
		local steps = tonumber(cmd.steps)
		if not steps or steps ~= math.floor(steps) or steps < 1 or steps > max then
			return false, "Moonwalk 1 to " .. max .. " tiles."
		end
		if #p.trail <= 1 then
			return false, "You're already at the start."
		end
		removeCard(p, item)
		p.stats.used += 1
		self:_emit({ t = "useCard", p = p.index, item = item, steps = steps })
		self:_shiftBack(p, steps, "moonwalk")
		self:_land(p)
		if self.phase == "action" then
			self:_finishTurn()
		end
		return true
	elseif use == "telepathy" then
		local t, why = self:_validTarget(p, cmd.target, true)
		if not t then
			return false, why
		end
		local steps = tonumber(cmd.steps)
		if not steps or steps ~= math.floor(steps) or steps == 0 or math.abs(steps) > Rules.TelepathyMax then
			return false, "Move them 1 to " .. Rules.TelepathyMax .. " tiles."
		end
		removeCard(p, item)
		p.stats.used += 1
		self:_emit({ t = "useCard", p = p.index, item = item, target = t.index, steps = steps })
		self:_shift(t, steps, "telepathy")
		self:_finishTurn()
		return true
	elseif use == "jeopardy" then
		local t, why = self:_validTarget(p, cmd.target, false)
		if not t then
			return false, why
		end
		removeCard(p, item)
		p.stats.used += 1
		p.hand, t.hand = t.hand, p.hand
		self:_emit({ t = "useCard", p = p.index, item = item, target = t.index })
		self:_emit({ t = "handSwap", a = p.index, b = t.index })
		self:_shiftBack(t, Rules.JeopardySteps, "jeopardy")
		self:_shiftForward(p, Rules.JeopardySteps, "jeopardy")
		self:_finishTurn()
		return true
	elseif use == "regen" then
		local cdef = Characters.get(p.character)
		local ab = cdef and cdef.ability
		if not ab or ab.recharge == "perTurn" then
			return false, "Your character has nothing to recharge."
		end
		if p.ability.ready then
			return false, "Your ability is already charged."
		end
		removeCard(p, item)
		p.stats.used += 1
		p.ability.ready = true
		p.ability.progress = 0
		self:_emit({ t = "useCard", p = p.index, item = item })
		self:_emit({ t = "recharge", p = p.index })
		return true
	elseif use == "anchor" then
		if p.anchor then
			return false, "You already have a time anchor."
		end
		removeCard(p, item)
		p.stats.used += 1
		p.anchor = { tile = p.tile, trail = copyList(p.trail) }
		self:_emit({ t = "useCard", p = p.index, item = item, tile = p.tile })
		return true
	elseif use == "boost" then
		return self:_cmdArm(p, { item = item })
	end
	return false, "That card works automatically."
end

function Engine:_cmdRecall(p)
	local anchor = p.anchor
	if not anchor then
		return false, "You have no time anchor."
	end
	p.anchor = nil
	self:_emit({ t = "recall", p = p.index, tile = anchor.tile })
	self:_warpTo(p, anchor.tile, "recall", anchor.trail)
	self:_finishTurn()
	return true
end

function Engine:_cmdGive(p, cmd)
	if not self.mode.isTeam then
		return false, "Only in team modes."
	end
	if not p.finished then
		return false, "Finish your treasures before giving cards away."
	end
	local t, why = self:_validTarget(p, cmd.target, false)
	if not t then
		return false, why
	end
	if t.team ~= p.team then
		return false, "You can only give cards to a teammate."
	end
	local item = cmd.item
	if type(item) ~= "string" or not hasCard(p, item) then
		return false, "You don't have that card."
	end
	if #t.hand >= Rules.HandLimit or count(t.hand, item) >= Rules.PerItemLimit then
		return false, t.name .. "'s hand is full."
	end
	removeCard(p, item)
	table.insert(t.hand, item)
	self:_emit({ t = "give", p = p.index, target = t.index, item = item })
	return true
end

function Engine:_cmdBuy(p, cmd)
	local item = cmd.item
	local def = type(item) == "string" and Items.get(item)
	if not def or def.category ~= "potion" then
		return false, "The Potion Seller doesn't sell that."
	end
	if (self.stock[item] or 0) <= 0 then
		return false, "Sold out."
	end
	if p.coins < def.price then
		return false, "Not enough coins."
	end
	if #p.hand >= Rules.HandLimit or count(p.hand, item) >= Rules.PerItemLimit then
		return false, "Your hand is full."
	end
	p.coins -= def.price
	self.stock[item] -= 1
	p.stats.bought += 1
	table.insert(p.hand, item)
	self:_emit({ t = "buy", p = p.index, item = item, coins = p.coins })
	return true
end

function Engine:_cmdShopDone(p)
	self:_emit({ t = "shopClose", p = p.index })
	self.phase = "action"
	self:_finishTurn()
	return true
end

function Engine:_cmdAbility(p, cmd)
	local cdef = Characters.get(p.character)
	local ab = cdef and cdef.ability
	if not ab then
		return false, "Your character has no active ability."
	end
	if self.turn.abilityUsed then
		return false, "You already used your ability this turn."
	end
	if not p.ability.ready then
		return false, "Your ability is recharging."
	end
	local id = ab.id
	local target
	if ab.target ~= "none" then
		local why
		target, why = self:_validTarget(p, cmd.target, ab.target == "any")
		if not target then
			return false, why
		end
		if ab.target == "sameTile" and target.tile ~= p.tile then
			return false, "They must be on your tile."
		end
	end
	local option = cmd.option
	if ab.options and not table.find(ab.options, option) then
		return false, "Choose an option."
	end
	if id == "hex" and option == "freeze" and target.character == "mage" then
		return false, "Mages can't be frozen."
	end
	if id == "warp" and target.tile == p.tile then
		return false, "You're already on the same tile."
	end
	if id == "nudge" and option == "back" and #target.trail <= 1 then
		return false, "They're already at the start."
	end

	-- commit
	self.turn.abilityUsed = true
	p.stats.abilities += 1
	if ab.recharge ~= "perTurn" then
		p.ability.ready = false
		p.ability.progress = 0
	end
	self:_emit({ t = "ability", p = p.index, ability = id, target = target and target.index, option = option })
	if id == "hex" then
		self:_setStatus(target, if option == "freeze" then "frozen" else "burning", "hex")
	elseif id == "scavenge" then
		self:_spin(p, "trap")
	elseif id == "ignite" then
		self:_setStatus(target, "burning", "ignite")
	elseif id == "warp" then
		self:_swap(p, target, "warp")
	elseif id == "nudge" then
		self:_shift(target, if option == "fwd" then 1 else -1, "nudge")
	end
	return true
end

---------------------------------------------------------------------------
-- queries
---------------------------------------------------------------------------

function Engine:isOver(): boolean
	return self.phase == "over"
end

function Engine:teammates(p)
	local out = {}
	for _, other in self.players do
		if other ~= p and other.team == p.team then
			table.insert(out, other)
		end
	end
	return out
end

function Engine:isOpponent(a, b): boolean
	return a.team ~= b.team
end

-- A plain-data view of the game for clients. `forSeat` sees their own hand.
function Engine:snapshot(forSeat: number?)
	local players = {}
	for _, p in self.players do
		table.insert(players, {
			seat = p.index,
			id = p.id,
			userId = p.userId,
			name = p.name,
			isBot = p.isBot,
			team = p.team,
			character = p.character,
			tile = p.tile,
			treasures = p.treasures,
			coins = p.coins,
			handCount = #p.hand,
			burning = p.status.burning,
			frozen = p.status.frozen,
			boots = p.status.boots,
			held = p.status.held,
			skip = p.status.skip,
			abilityReady = p.ability.ready,
			abilityProgress = p.ability.progress,
			anchor = if p.anchor then p.anchor.tile else 0,
			finished = p.finished,
			trailLength = #p.trail,
			stats = table.clone(p.stats),
		})
	end
	local tokens, placed, natural = {}, {}, {}
	for tile, kind in self.tokens do
		table.insert(tokens, { tile = tile, kind = kind })
	end
	for tile, e in self.placed do
		table.insert(placed, { tile = tile, item = e.item, owner = e.owner, dir = e.dir, uses = e.uses, tiles = e.tiles })
	end
	for tile, kind in self.natural do
		table.insert(natural, { tile = tile, kind = kind })
	end
	local snap = {
		mode = self.mode.id,
		map = self.map.id,
		phase = self.phase,
		current = self.current,
		round = self.round,
		turnNo = self.turnCount,
		target = self.target,
		order = copyList(self.turnOrder or {}),
		players = players,
		tokens = tokens,
		placed = placed,
		natural = natural,
		teleporters = copyList(self.teleporters),
		stock = table.clone(self.stock),
		winnerTeam = self.winnerTeam,
		ranking = self.ranking and copyList(self.ranking) or nil,
		endReason = self.endReason,
		abilityUsed = self.turn ~= nil and self.turn.abilityUsed or false,
	}
	if forSeat and self.players[forSeat] then
		local me = self.players[forSeat]
		snap.hand = copyList(me.hand)
		if forSeat == self.current and self.turn then
			local armed = {}
			for item in self.turn.armed do
				table.insert(armed, item)
			end
			snap.armed = armed
		else
			snap.armed = {}
		end
	end
	return snap
end

-- Rebuilds lookup layers from a snapshot (client-side placement previews).
function Engine.layersFromSnapshot(board, snap)
	local layers = { placed = {}, cover = {}, natural = {}, tokens = {} }
	for _, t in snap.tokens do
		layers.tokens[t.tile] = t.kind
	end
	for _, n in snap.natural do
		layers.natural[n.tile] = n.kind
	end
	for _, e in snap.placed do
		layers.placed[e.tile] = e
		if e.tiles then
			for _, t in e.tiles do
				layers.cover[t] = e.tile
			end
		end
	end
	return layers
end

Engine.hasCard = hasCard
Engine.countCards = count

return Engine
