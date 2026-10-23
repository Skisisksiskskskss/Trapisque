--[[
	Engine
	The complete, authoritative Trapisque rules. Pure Luau: no Roblox APIs, so it runs
	the same on the server and in the offline test-suite.

	Usage
		local game = Engine.new({ mode = "chaos", map = "blissful", seed = 42,
			players = { { id = "u1", name = "Ana", character = "mage" }, { id = "bot1", name = "Bot", isBot = true } } })
		local events = game:start()
		local ok, err, events = game:command(seat, { type = "move", die = 1 })

	Every state change is reported as an event table (field `t` is the type) so clients
	can animate exactly what happened. Some events are secret (a hidden trap being placed):
	Engine:eventsFor(seat, events) gives the version a seat may see. See docs/RULES.md.

	A turn
		Your two dice roll by themselves when your turn starts. Then, in any order:
			play      play ONE card from your hand (hide a trap, boost your move...)
			ability   use your ability, if your Power bar is full
			give      (team modes) pass a card to a teammate - counts as your card
		and finally one of:
			move      pick a die to move with; the other die charges your Power
			          (doubles: the second die of the pair moves you backwards, or
			          move the total, which charges no Power)
			recall    warp back to your Time Travel anchor instead of moving
		Landing on a Potion Seller opens the shop: buy / shopDone.
		Scavenge offers two cards: pick.

	Between turns (the end of every round) Haunted Hollow's ghosts drift toward the Start
	and Mount Kaboom's volcano counts down to its next eruption.

	Extra options for Engine.new:
		rig     { [seat] = { { a, b }, ... } } the dice those seats roll, in order (the
		        guided first match), then random dice again
		hands   { [seat] = { item, ... } } starting cards instead of the random ones
		firstSeat  this seat takes the first turn
		rules   a private match's house rules (Shared/Game/HouseRules: the board, starting
		        Power and cards, abilities, Wanted posters, the underdog die, banned cards)
]]

local Config = require(script.Parent.Parent.Config)
local Rng = require(script.Parent.Rng)
local Items = require(script.Parent.Items)
local Characters = require(script.Parent.Characters)
local Maps = require(script.Parent.Maps)
local Modes = require(script.Parent.Modes)
local Board = require(script.Parent.Board)

local Rules = Config.Rules
local CharCfg = Config.Characters

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

-- Slime halves what's left of a move (rounding up, so you always get somewhere).
local function halve(m: number): number
	return math.ceil(m / 2)
end
Engine.halve = halve

local function trapCap(p): number
	if p.character == "trapper" then
		return CharCfg.trapper.trapCap
	end
	return Rules.TrapCap
end

local function newStats()
	return {
		deaths = 0, -- times you were knocked out
		kos = 0, -- players your traps knocked out
		gotchas = 0, -- times your hidden traps caught someone
		bonks = 0, -- bonks you landed
		bonked = 0, -- bonks you took
		placed = 0,
		played = 0,
		spins = 0,
		bought = 0,
		abilities = 0,
		doubles = 0,
		underdog = 0,
		bounties = 0, -- Wanted posters claimed
		wantedRounds = 0, -- rounds that ended with a price on your head
		rolled = 0, -- the sum of every die you rolled...
		rolls = 0, -- ...and how many (for the Unluckiest Roller)
		tiles = 0, -- tiles walked
		coins = 0, -- coins earned
	}
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function Engine.new(opts)
	local self = setmetatable({}, Engine)
	local mode = Modes.get(opts.mode)
	assert(mode, "Engine: unknown mode " .. tostring(opts.mode))
	-- a private match's house rules (none: the standard rules)
	local rules = opts.rules or {}
	local mapDef = Maps.variant(Maps.get(opts.map), rules.board)
	assert(mapDef, "Engine: unknown map " .. tostring(opts.map))
	assert(#opts.players >= 1 and #opts.players <= 6, "Engine: 1-6 players")

	self.mode = mode
	self.map = mapDef
	self.rules = rules
	self.banned = rules.banned or {}
	self.board = Board.get(mapDef)
	self.seed = opts.seed or 1
	self.rng = Rng.new(self.seed)
	self.target = opts.target or mode.target
	self.teamTarget = self.target * mode.teamSize
	-- a weekly event's twist on the rules (Shared/Meta/Progress events), or none
	self.mut = opts.mutator or {}
	self.length = opts.length or "classic"
	local caps = Rules.MaxRounds
	self.maxRounds = if type(caps) == "table" then (caps[self.length] or caps.classic) else caps
	self.rig = opts.rig or {}
	self.startHands = opts.hands
	self.firstSeat = opts.firstSeat
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
	self.placed = {} -- [tile] = visible piece: { item, owner, team, uses, dir, tiles }
	self.cover = {} -- [tile] = origin tile of the conveyor covering it
	self.traps = {} -- [tile] = { trap, ... } hidden traps (a tile can hold several)
	self.natural = {} -- [tile] = "river" | "gate" | "slime"
	self.embers = {} -- [tile] = { owner, team } burning tiles left by a Blast Off
	self.ghosts = {} -- Haunted Hollow: the tile each ghost floats over
	self.ghostAt = {} -- [tile] = ghost number
	self.lava = {} -- Mount Kaboom: the lava stream tiles (natural "lava")
	self.wanted = nil :: { seat: number, pot: number, most: boolean? }? -- the price on the leader's head
	self.teleporters = {} -- tiles, in placement order (pairs: 1-2, 3-4, ...)
	self.placeOrder = 0
	self.stock = {}
	for _, id in Items.potions do
		self.stock[id] = if self.banned[id] then 0 else Rules.PotionStock
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
			coins = Rules.StartingCoins,
			hand = {},
			power = 0,
			status = { frozen = 0, burning = 0, skip = 0 },
			anchor = nil,
			stats = newStats(),
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
-- events and secrets
---------------------------------------------------------------------------

function Engine:_emit(evt)
	table.insert(self.events, evt)
end

function Engine:_flushEvents()
	local out = self.events
	self.events = {}
	return out
end

-- Who may see a secret: { team = n, overseer = true? } (that team, and Overseers if
-- set), { seat = n } or { seats = { [n] = true } }.
function Engine:_mayKnow(seat: number, secret): boolean
	if secret.seat ~= nil then
		return secret.seat == seat
	end
	if secret.seats ~= nil then
		return secret.seats[seat] == true
	end
	local p = self.players[seat]
	if not p then
		return false
	end
	if secret.team ~= nil and p.team == secret.team then
		return true
	end
	return secret.overseer == true and p.character == "overseer"
end

--[[
	The events as `seat` may see them. A secret event carries `secret` (who may know)
	and optionally `alt` (what everyone else sees instead, or nothing).
]]
function Engine:eventsFor(seat: number, events)
	local out = {}
	for _, e in events do
		local secret = e.secret
		if secret == nil then
			table.insert(out, e)
		elseif self:_mayKnow(seat, secret) then
			local copy = table.clone(e)
			copy.secret = nil
			copy.alt = nil
			table.insert(out, copy)
		elseif e.alt ~= nil then
			table.insert(out, e.alt)
		end
	end
	return out
end

-- Can `seat` see this hidden trap? Its owner's team, Overseers, and X-Ray drinkers can.
function Engine:canSee(seat: number, trap): boolean
	if trap.public then
		return true
	end
	local p = self.players[seat]
	if not p then
		return false
	end
	if trap.team ~= nil and p.team == trap.team then
		return true
	end
	if p.character == "overseer" then
		return true
	end
	return trap.seenBy ~= nil and trap.seenBy[seat] == true
end

---------------------------------------------------------------------------
-- setup
---------------------------------------------------------------------------

function Engine:start()
	assert(self.phase == "setup", "Engine: already started")
	local rng = self.rng

	-- characters: one of each per match, because a character's colour is its player's
	-- colour. Picks are kept; when two players picked the same one, a random one of them
	-- keeps it and the other gets a character nobody has (and is told why). Anyone
	-- without a pick gets one nobody has.
	local taken = {}
	local wanting = {}
	for _, p in self.players do
		if p.character ~= nil and Characters.get(p.character) ~= nil then
			table.insert(wanting, p)
		else
			p.character = nil
		end
	end
	rng:shuffle(wanting)
	for _, p in wanting do
		if taken[p.character] then
			p.wanted = p.character
			p.character = nil
		else
			taken[p.character] = true
		end
	end
	for _, p in self.players do
		if p.character == nil then
			local free = {}
			for _, c in Characters.ids do
				if not taken[c] then
					table.insert(free, c)
				end
			end
			p.character = if #free > 0 then rng:pick(free) else rng:pick(Characters.ids)
			taken[p.character] = true
		end
	end

	-- turn order: shuffled (the guided match puts its player first)
	local order = {}
	for _, p in self.players do
		table.insert(order, p.index)
	end
	rng:shuffle(order)
	local first = self.firstSeat and table.find(order, self.firstSeat)
	if first then
		table.insert(order, 1, table.remove(order, first))
	end
	self.turnOrder = order

	-- natural hazards and map traps
	for tile, kind in self.board.naturalInit do
		self.natural[tile] = kind
		if kind == "lava" then
			table.insert(self.lava, tile)
		end
	end
	table.sort(self.lava)
	for _, tile in self.map.ghosts or {} do
		if tile < self.board.treasure - 1 then
			table.insert(self.ghosts, tile)
		end
	end
	self:_indexGhosts()
	for tile, item in self.map.startingPlaced or {} do
		if tile >= self.board.treasure then
			continue
		end
		if Items.isHidden(item) then
			self:_addTrap(tile, item, 0, nil, true)
		else
			self:_addPlaced(tile, item, 0, nil)
		end
	end

	-- tokens: a random token on every token spot, at least one Potion Seller
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
		table.insert(setup.players, { seat = p.index, character = p.character, team = p.team, wanted = p.wanted })
	end
	self:_emit(setup)

	-- starting cards: one assist card each (house rules: up to three), plus the Trapper's
	-- trap and the Fire Starter's Fire; never a banned card
	local starters = {}
	for _, id in Items.wheels.assist do
		if id ~= "coin" and id ~= "bkb" and not self.banned[id] then
			table.insert(starters, id)
		end
	end
	local traps = {}
	for _, id in Items.trapIds do
		if id ~= "wall" and not self.banned[id] then
			table.insert(traps, id)
		end
	end
	for _, p in self.players do
		local dealt = {}
		for _ = 1, math.clamp(self.rules.cards or 1, 0, 3) do
			if #starters > 0 then
				table.insert(dealt, rng:pick(starters))
			end
		end
		local fixed = self.startHands and self.startHands[p.index]
		if fixed then
			dealt = copyList(fixed)
		elseif p.character == "trapper" and #traps > 0 then
			table.insert(dealt, rng:pick(traps))
		elseif p.character == "fire_starter" and not self.banned.fire then
			table.insert(dealt, "fire")
		end
		for _ = 1, self.mut.startTraps or 0 do
			if #traps > 0 then
				table.insert(dealt, rng:pick(traps))
			end
		end
		for _, item in dealt do
			if #p.hand < Rules.HandLimit then
				table.insert(p.hand, item)
			end
		end
		self:_emit({
			t = "deal",
			p = p.index,
			items = dealt,
			secret = { seat = p.index },
			alt = { t = "deal", p = p.index, count = #dealt },
		})
	end

	-- house rules: Power to start with
	if self.rules.power == "half" or self.rules.power == "full" then
		for _, p in self.players do
			local cap = Engine.powerCap(p)
			self:_gainPower(p, if self.rules.power == "full" then cap else math.floor(cap / 2))
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
			self:_endRound()
			if self.phase == "over" then
				return
			end
			self.round += 1
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
	self.landings = 0
	self.turn = {
		number = self.turnCount,
		dice = {},
		cardsPlayed = 0,
		abilityUsed = false,
		boost = nil,
		canShop = false,
	}
	self.phase = "action"
	self:_emit({ t = "turn", p = seat, round = self.round, n = self.turnCount })
	self:_clearEmbers(seat)
	if p.status.skip > 0 then
		-- Snared: roll to break free, or lose the turn
		p.status.skip -= 1
		local roll = self.rng:int(1, 6)
		local free = roll >= Rules.SnareEscapeMin
		self:_emit({ t = "snareRoll", p = seat, roll = roll, free = free })
		if not free then
			self:_emit({ t = "skip", p = seat })
			self.turn = nil
			return false
		end
	end
	if p.status.burning > 0 then
		-- Burning: hop back a tile (it can land you on something nasty)
		p.status.burning -= 1
		self:_emit({ t = "burn", p = seat, left = p.status.burning })
		self:_shiftBack(p, 1, "burn")
		self:_land(p, true)
		if p.status.burning == 0 then
			self:_emit({ t = "status", p = seat, status = "burning", on = false })
		end
		if self.phase == "over" then
			return true
		end
	end
	self:_roll(p, false)
	return true
end

-- Rolls the current player's dice: two, or one while Frozen.
function Engine:_roll(p, reroll: boolean)
	local frozen = false
	if reroll then
		frozen = #self.turn.dice == 1
	elseif p.status.frozen > 0 then
		frozen = true
		p.status.frozen -= 1
	end
	-- Frozen: one die, and you shuffle along at half speed (rounded up)
	local dice
	local underdog = false
	local rigged = self.rig[p.index]
	local fixed = if rigged and not reroll then table.remove(rigged, 1) else nil
	if fixed and not frozen then
		dice = copyList(fixed)
	elseif frozen then
		dice = { halve(self:_die(p)) }
	else
		dice = {}
		local base = math.clamp(self.mut.diceCount or 2, 2, 3)
		local n = base
		if reroll then
			-- a reroll rolls as many dice as before
			n = math.max(base, #self.turn.dice)
			underdog = self.turn.gold ~= nil
		elseif n < 3 and self:underdogSeat() == p.index then
			-- clearly last: an extra gold die to move with (it charges no Power)
			n += 1
			underdog = true
			p.stats.underdog += 1
		end
		for _ = 1, n do
			table.insert(dice, self:_die(p))
		end
	end
	self.turn.dice = dice
	self.turn.frozen = frozen
	self.turn.gold = if underdog then #dice else nil
	if not frozen then
		for _, d in dice do
			p.stats.rolled += d
			p.stats.rolls += 1
		end
	end
	for i = 2, #dice do
		if Engine.isBackDie(dice, i, self.turn.gold) then
			p.stats.doubles += 1
			break
		end
	end
	self:_emit({ t = "roll", p = p.index, dice = copyList(dice), frozen = frozen, reroll = reroll, underdog = underdog, gold = self.turn.gold })
	if frozen and not reroll and p.status.frozen == 0 then
		self:_emit({ t = "status", p = p.index, status = "frozen", on = false })
	end
end

-- One die for `p` (the Gambler's Loaded Dice never roll a 1).
function Engine:_die(p): number
	return self.rng:int(if p.character == "gambler" then 2 else 1, 6)
end

function Engine:_finishTurn()
	if self.phase == "over" then
		return
	end
	self.phase = "action"
	self:_advance()
end

---------------------------------------------------------------------------
-- the end of a round: ghosts drift, the volcano rumbles
---------------------------------------------------------------------------

function Engine:_indexGhosts()
	self.ghostAt = {}
	for i, tile in self.ghosts do
		self.ghostAt[tile] = i
	end
end

-- Where a ghost on `tile` drifts next: one tile toward the Start; from just past the
-- Start it floats back to just before the treasure and comes down the trail again.
function Engine:_ghostStep(tile: number): number
	local prev = self.board.prevMain[tile]
	if prev == nil or prev <= self.board.start + 1 then
		return self.board.treasure - 2
	end
	return prev
end

-- Will the volcano erupt at the end of this round?
function Engine:eruptsThisRound(): boolean
	return #self.lava > 0 and (Rules.EruptEvery or 0) > 0 and self.round % Rules.EruptEvery == 0
end

function Engine:_endRound()
	if #self.ghosts > 0 then
		local moves = {}
		for i, from in self.ghosts do
			local path = {}
			local tile = from
			for _ = 1, Rules.GhostDrift or 0 do
				tile = self:_ghostStep(tile)
				table.insert(path, tile)
			end
			self.ghosts[i] = tile
			table.insert(moves, { ghost = i, from = from, path = path })
		end
		self:_indexGhosts()
		self:_emit({ t = "ghosts", moves = moves })
	end
	if self:eruptsThisRound() then
		-- KABOOM: lava pours down the streams and scorches anyone standing in one
		self:_emit({ t = "erupt", tiles = copyList(self.lava), round = self.round })
		for _, p in self.players do
			if self.phase ~= "over" and self.natural[p.tile] == "lava" then
				self:_scorch(p)
			end
		end
	end
	self:_postWanted()
end

---------------------------------------------------------------------------
-- Wanted: a price on the leader's head (Rules.Wanted*)
---------------------------------------------------------------------------

-- Whoever leads the race clearly: Rules.WantedLead tiles or more ahead of every rival.
function Engine:clearLeader(): number?
	local best, bestP = nil, -math.huge
	for _, p in self.players do
		local pr = self:progress(p)
		if pr > bestP then
			best, bestP = p, pr
		end
	end
	if not best then
		return nil
	end
	local rival = -math.huge
	for _, p in self.players do
		if self:isOpponent(best, p) then
			rival = math.max(rival, self:progress(p))
		end
	end
	if rival == -math.huge or bestP - rival < Rules.WantedLead then
		return nil
	end
	return best.index
end

-- At the end of a round the poster goes up on the clear leader (or its price rises).
function Engine:_postWanted()
	if self.rules.wanted == false or self.round < Rules.WantedFrom or self.phase == "over" then
		return
	end
	local leader = self:clearLeader()
	local w = self.wanted
	if w and leader == w.seat then
		self:_raiseWanted("round")
	elseif leader then
		self.wanted = { seat = leader, pot = Rules.WantedStart }
		self:_emit({ t = "wanted", p = leader, pot = Rules.WantedStart, from = if w then w.seat else nil })
	end
	if self.wanted then
		self.players[self.wanted.seat].stats.wantedRounds += 1
	end
end

-- The price on the Wanted's head goes up by a coin; at the top they're Most Wanted,
-- and every hidden trap of theirs is out in the open (so are the ones they hide next).
function Engine:_raiseWanted(why: string)
	local w = self.wanted
	if not w or w.pot >= Rules.WantedMax then
		return
	end
	w.pot += 1
	self:_emit({ t = "wantedUp", p = w.seat, pot = w.pot, why = why })
	if w.pot >= Rules.WantedMax and not w.most then
		w.most = true
		local exposed = {}
		for _, entry in self:trapsOf(w.seat) do
			if not entry.trap.public then
				entry.trap.public = true
				table.insert(exposed, { tile = entry.tile, item = entry.trap.item, owner = w.seat })
			end
		end
		self:_emit({ t = "mostWanted", p = w.seat, pot = w.pot, traps = exposed })
	end
end

-- `hunter` bonked the Wanted or caught them in a trap: the coins, and one of their cards.
function Engine:_claimWanted(hunter, outlaw, how: string)
	local w = self.wanted
	if not w or w.seat ~= outlaw.index or not self:isOpponent(hunter, outlaw) then
		return
	end
	self.wanted = nil
	hunter.stats.bounties += 1
	self:_emit({ t = "wantedClaim", p = hunter.index, target = outlaw.index, pot = w.pot, how = how })
	self:_addCoins(hunter, w.pot, "bounty")
	if #outlaw.hand > 0 and #hunter.hand < Rules.HandLimit then
		-- (only the two of them know which card it was)
		local loot = table.remove(outlaw.hand, self.rng:int(1, #outlaw.hand))
		table.insert(hunter.hand, loot)
		self:_emit({
			t = "loot",
			p = hunter.index,
			target = outlaw.index,
			item = loot,
			secret = { seats = { [hunter.index] = true, [outlaw.index] = true } },
			alt = { t = "loot", p = hunter.index, target = outlaw.index },
		})
	end
end

-- The Wanted made it to the treasure: they got away, and the price on their head is theirs.
function Engine:_cashInWanted(p)
	local w = self.wanted
	if not w or w.seat ~= p.index then
		return
	end
	self.wanted = nil
	self:_emit({ t = "wantedCashIn", p = p.index, pot = w.pot })
	self:_addCoins(p, w.pot, "bounty")
end

-- Caught in an eruption: Burning, and you scramble back. A Fire Cloak keeps you safe.
function Engine:_scorch(p)
	if removeCard(p, "cloak") then
		self:_emit({ t = "useCard", p = p.index, item = "cloak", tile = p.tile, why = "lava" })
		return
	end
	self:_emit({ t = "scorch", p = p.index, tile = p.tile, lava = true })
	self:_setStatus(p, "burning", "lava")
	self:_shiftBack(p, Rules.EruptBack or 0, "scorched")
	self:_land(p, true)
end

---------------------------------------------------------------------------
-- board layer helpers
---------------------------------------------------------------------------

function Engine:_addPlaced(tile: number, item: string, owner: number, dir: string?)
	local p = self.players[owner]
	local entry = { item = item, owner = owner, team = p and p.team, uses = Rules.PlacedUses[item], dir = dir }
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
	return entry
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

-- One trigger of a visible piece: decrements uses and removes it when spent.
function Engine:_usePlaced(tile: number)
	local entry = self.placed[tile]
	if not entry or entry.uses == nil then
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

-- Embers (Blast Off) --------------------------------------------------------

function Engine:_clearEmbers(seat: number)
	local tiles = {}
	for tile, e in self.embers do
		if e.owner == seat then
			table.insert(tiles, tile)
		end
	end
	if #tiles > 0 then
		table.sort(tiles)
		for _, tile in tiles do
			self.embers[tile] = nil
		end
		self:_emit({ t = "embersOut", p = seat, tiles = tiles })
	end
end

-- Hidden traps -------------------------------------------------------------

function Engine:_addTrap(tile: number, item: string, owner: number, team: number?, public: boolean?)
	self.placeOrder += 1
	local trap = { item = item, owner = owner, team = team, order = self.placeOrder, public = public == true, seenBy = {} }
	local list = self.traps[tile]
	if not list then
		list = {}
		self.traps[tile] = list
	end
	table.insert(list, trap)
	return trap
end

function Engine:_takeTrap(tile: number, trap)
	local list = self.traps[tile]
	if not list then
		return
	end
	local i = table.find(list, trap)
	if i then
		table.remove(list, i)
	end
	if #list == 0 then
		self.traps[tile] = nil
	end
end

-- Every hidden trap a player owns, oldest first: { {tile, trap}, ... }
function Engine:trapsOf(seat: number)
	local out = {}
	for tile, list in self.traps do
		for _, trap in list do
			if trap.owner == seat then
				table.insert(out, { tile = tile, trap = trap })
			end
		end
	end
	table.sort(out, function(a, b)
		return a.trap.order < b.trap.order
	end)
	return out
end

-- The secret that goes with an event about `trap`: who may know about it.
local function trapSecret(trap)
	if trap.public then
		return nil
	end
	return { team = trap.team, overseer = true }
end

---------------------------------------------------------------------------
-- placement rules
---------------------------------------------------------------------------

--[[
	Placement rules, shared with the client (it passes layers rebuilt from a snapshot).
	layers = { placed, cover, natural, tokens, traps? }   `traps` only holds what the
	placer can see; hidden traps they can't see never block a tile.
	ctx = { from = tile, range = number?, seat = number?, team = number? }
	(range nil = anywhere on the board)
]]
function Engine.checkPlacement(board, layers, itemId: string, tile: number, dir: string?, ctx): (boolean, string?)
	local def = Items.get(itemId)
	if not def or def.use ~= "place" then
		return false, "That card can't be placed."
	end
	if type(tile) ~= "number" or board.tiles[tile] == nil then
		return false, "Pick a tile on the board."
	end
	ctx = ctx or {}
	local function free(t: number): (boolean, string?)
		if board:isSpecial(t) then
			return false, "Not on the Start or Treasure tile."
		end
		if layers.tokens[t] then
			return false, "That tile already has a token."
		end
		if layers.natural[t] then
			return false, "A hazard is already there."
		end
		if layers.placed[t] or layers.cover[t] then
			return false, "Something is already there."
		end
		if board.tiles[t].kind == "shortcutGate" then
			return false, "Not on a shortcut gate."
		end
		local mine = layers.traps and layers.traps[t]
		if mine then
			for _, trap in mine do
				if trap.public or (ctx.team ~= nil and trap.team == ctx.team) then
					return false, "There's already a trap there."
				end
			end
		end
		return true, nil
	end
	if ctx.range ~= nil and ctx.from ~= nil and board:raceDistance(ctx.from, tile) > ctx.range then
		return false, "Too far: place it within " .. ctx.range .. " tiles of you."
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

-- The placement context for player `p` (how far from them they may place). `mut` is
-- the game's event twist, if any.
function Engine.placeContext(p, mut: { [string]: any }?)
	return {
		from = p.tile,
		range = if p.character == "trapper" then nil else ((mut and mut.trapRange) or Rules.TrapRange),
		seat = p.index,
		team = p.team,
	}
end

-- The board as `seat` sees it, for placement checks.
function Engine:layersFor(seat: number)
	local traps = {}
	for tile, list in self.traps do
		for _, trap in list do
			if self:canSee(seat, trap) then
				traps[tile] = traps[tile] or {}
				table.insert(traps[tile], trap)
			end
		end
	end
	return { placed = self.placed, cover = self.cover, natural = self.natural, tokens = self.tokens, traps = traps }
end

function Engine:canPlace(p, itemId: string, tile: number, dir: string?): (boolean, string?)
	return Engine.checkPlacement(self.board, self:layersFor(p.index), itemId, tile, dir, Engine.placeContext(p, self.mut))
end

---------------------------------------------------------------------------
-- cards, coins and power
---------------------------------------------------------------------------

function Engine:_giveCard(p, item: string, source: string?)
	if #p.hand >= Rules.HandLimit then
		self:_emit({ t = "handFull", p = p.index, item = item })
		return false
	end
	table.insert(p.hand, item)
	self:_emit({ t = "gain", p = p.index, item = item, source = source })
	return true
end

function Engine:_addCoins(p, n: number, why: string)
	if n <= 0 then
		return
	end
	p.coins += n
	p.stats.coins += n
	self:_emit({ t = "coin", p = p.index, coins = p.coins, gain = n, why = why })
end

function Engine:_spin(p, wheel: string)
	local segments = Items.wheels[wheel]
	-- (a banned card's slice never comes up)
	local allowed = {}
	for i, seg in segments do
		if not self.banned[seg] then
			table.insert(allowed, i)
		end
	end
	local index = allowed[self.rng:int(1, #allowed)]
	local segment = segments[index]
	local result = if segment == "bkb" then self.map.counterItem else segment
	p.stats.spins += 1
	self:_emit({ t = "spin", p = p.index, wheel = wheel, index = index, result = result })
	if result == "coin" then
		self:_addCoins(p, 1, "wheel")
	else
		self:_giveCard(p, result, wheel)
	end
end

function Engine.powerCap(p): number
	return Characters.cost(p.character)
end

function Engine:_gainPower(p, n: number)
	if self.rules.abilities == false then
		-- (no abilities, no Power)
		return
	end
	local cap = Engine.powerCap(p)
	local before = p.power
	p.power = math.clamp(p.power + n, 0, cap)
	if p.power ~= before then
		self:_emit({ t = "power", p = p.index, power = p.power, gain = p.power - before, full = p.power >= cap })
	end
end

---------------------------------------------------------------------------
-- statuses, knockouts, treasure
---------------------------------------------------------------------------

function Engine:_setStatus(p, status: string, source: string, turns: number?)
	if status == "frozen" then
		if p.character == "mage" then
			self:_emit({ t = "immune", p = p.index, what = "frozen" })
			return
		end
		p.status.frozen = math.max(p.status.frozen, turns or Rules.FrozenTurns)
		self:_emit({ t = "status", p = p.index, status = "frozen", on = true, turns = p.status.frozen, source = source })
	elseif status == "burning" then
		p.status.burning = math.max(p.status.burning, Rules.BurningTurns)
		self:_emit({ t = "status", p = p.index, status = "burning", on = true, turns = p.status.burning, source = source })
	elseif status == "snared" then
		p.status.skip += 1
		self:_emit({ t = "snared", p = p.index, source = source })
	end
end

function Engine:_sendToStart(p, kind: string)
	p.tile = self.board.start
	p.trail = { self.board.start }
	self:_emit({ t = "move", p = p.index, path = { self.board.start }, kind = kind })
end

-- Knocked out (Spike, Grog): back to the Start. Returns true if it happened.
function Engine:_knockout(p, cause: string, by: number?): boolean
	if removeCard(p, "phoenix_potion") then
		self:_emit({ t = "phoenix", p = p.index, cause = cause })
		return false
	end
	p.stats.deaths += 1
	local killer = by and self.players[by]
	if killer and killer ~= p then
		killer.stats.kos += 1
	end
	self:_emit({ t = "death", p = p.index, cause = cause, by = by })
	self:_sendToStart(p, "respawn")
	return true
end

function Engine:teamTreasures(team: number): number
	local n = 0
	for _, p in self.players do
		if p.team == team then
			n += p.treasures
		end
	end
	return n
end

function Engine:_reachTreasure(p)
	p.treasures += 1
	self:_emit({ t = "treasure", p = p.index, treasures = p.treasures, team = self:teamTreasures(p.team) })
	self:_addCoins(p, Rules.CoinsPerTreasure, "treasure")
	self:_cashInWanted(p)
	self:_sendToStart(p, "home")
	if self:teamTreasures(p.team) >= self.teamTarget then
		self:_gameOver(p.team, "treasure")
	end
end

function Engine:score(p): number
	-- treasures first, then how close you are to the next one
	return p.treasures * 1000 + (1000 - (self.board.dist[p.tile] or 0))
end

--[[
	How far along the race `p` is, in tiles: every treasure counts as a whole lap, then
	how far into this lap they are. So scoring a treasure and starting again from the
	Start never counts as falling behind.
]]
function Engine:progress(p): number
	local board = self.board
	local lap = board.dist[board.start] or 0
	return p.treasures * lap + (lap - (board.dist[p.tile] or lap))
end

--[[
	The underdog: the one player who is clearly last, behind everyone else by
	Rules.UnderdogGap tiles or more (laps included). nil when nobody is.
]]
function Engine:underdogSeat(): number?
	if #self.players < 2 or self.rules.underdog == false then
		return nil
	end
	local last, lastP, second = nil, math.huge, math.huge
	for _, p in self.players do
		local pr = self:progress(p)
		if pr < lastP then
			second = lastP
			last, lastP = p.index, pr
		elseif pr < second then
			second = pr
		end
	end
	if last and second - lastP >= (Rules.UnderdogGap or math.huge) then
		return last
	end
	return nil
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

--[[
	Where a forward walk of `m` steps goes, without changing anything. Used for the
	real walk, for previews on screen and by bots. `state` needs: board, natural,
	placed, and optionally ghostAt (Haunted Hollow); the walker
	`p` needs tile, hand, character and (for a ghost's scare) trail.

	Returns {
		path = { tiles }, tile = landing tile,
		result = "landed" | "stopped" (river/gate/lava) | "blocked" (wall) | "treasure"
			| "scared" (walked into a ghost: `flee` is the way back, `tile` its end),
		uses = { "key" | "bridge" | "boots" | "lantern" | "cloak" | "shield", ... } in
			order, with the tile,
		slowed = tile where slime slowed you (or nil), crumbles = { wall tiles passed },
	}
]]
function Engine.walkPlan(state, p, m: number, leap: boolean?)
	local board = state.board
	local keys = count(p.hand, "key")
	local bridges = count(p.hand, "bridge")
	local boots = count(p.hand, "boots")
	local lanterns = count(p.hand, "lantern")
	local cloaks = count(p.hand, "cloak")
	local shields = count(p.hand, "shield")
	local ghostAt = state.ghostAt or {}
	-- the Naturalist (and a Gambler's Double Down, `leap`) goes straight through hazards
	local wild = p.character == "naturalist" or leap == true
	local plan = { path = {}, tile = p.tile, result = "landed", uses = {}, slowed = nil, crumbles = {} }
	local wallsBlock = m < Rules.WallPassMin
	local cur = p.tile
	local left = m
	while left > 0 do
		local nxt
		local sc = board.shortcut[cur]
		if sc and keys > 0 then
			keys -= 1
			table.insert(plan.uses, { item = "key", tile = sc, why = "shortcut" })
			nxt = sc
		else
			nxt = board.nextMain[cur]
		end
		if not nxt then
			break
		end
		-- walls: you can't move past one unless you move 5+; landing on it is fine
		local piece = state.placed[nxt]
		if piece and piece.item == "wall" and left > 1 then
			if wallsBlock then
				if shields > 0 then
					shields -= 1
					table.insert(plan.uses, { item = "shield", tile = nxt, why = "wall" })
					table.insert(plan.crumbles, nxt)
				else
					plan.result = "blocked"
					plan.blockedAt = nxt
					break
				end
			else
				table.insert(plan.crumbles, nxt)
			end
		end
		cur = nxt
		table.insert(plan.path, nxt)
		left -= 1
		if nxt == board.treasure then
			plan.result = "treasure"
			break
		end
		-- a ghost in your way scares you back (a Lantern shines it away)
		if ghostAt[nxt] and not wild then
			if lanterns > 0 then
				lanterns -= 1
				table.insert(plan.uses, { item = "lantern", tile = nxt, why = "ghost" })
			else
				plan.result = "scared"
				plan.hazard = "ghost"
				plan.scaredAt = nxt
				break
			end
		end
		-- hazards stop you on them (slime only drags you back a few steps), unless you
		-- carry the card that gets you past
		local nat = state.natural[nxt]
		if nat and not wild and left > 0 then
			local counter = Items.naturalCounter[nat]
			local have = if counter == "key" then keys elseif counter == "bridge" then bridges elseif counter == "cloak" then cloaks else boots
			if have > 0 then
				if counter == "key" then
					keys -= 1
				elseif counter == "bridge" then
					bridges -= 1
				elseif counter == "cloak" then
					cloaks -= 1
				else
					boots -= 1
				end
				table.insert(plan.uses, { item = counter, tile = nxt })
			elseif nat == "slime" and (Rules.SlimeDrag or 0) > 0 and left > Rules.SlimeDrag then
				left -= Rules.SlimeDrag
				plan.slowed = nxt
			else
				plan.result = "stopped"
				plan.hazard = nat
				break
			end
		end
	end
	plan.tile = cur
	if plan.result == "scared" then
		-- run back the way you came
		local trail = {}
		for _, t in p.trail or { p.tile } do
			table.insert(trail, t)
		end
		for _, t in plan.path do
			table.insert(trail, t)
		end
		local flee = {}
		for i = 1, math.min(Rules.GhostScare or 0, #trail - 1) do
			table.insert(flee, trail[#trail - i])
		end
		plan.flee = flee
		plan.tile = if #flee > 0 then flee[#flee] else cur
	end
	return plan
end

-- A backward walk retraces your trail (Moonwalk). Hazards and walls don't stop it.
function Engine.backPlan(p, m: number)
	local trail = p.trail
	local path = {}
	local n = math.min(m, #trail - 1)
	for i = 1, n do
		table.insert(path, trail[#trail - i])
	end
	return { path = path, tile = if #path > 0 then path[#path] else p.tile, result = "landed", uses = {}, crumbles = {} }
end

function Engine:_walk(p, m: number): string
	local plan = Engine.walkPlan(self, p, m, self.turn ~= nil and self.turn.double == true)
	local path = {}
	local function flush()
		if #path > 0 then
			self:_emit({ t = "move", p = p.index, path = path, kind = "walk" })
			path = {}
		end
	end
	local useAt = {}
	for _, u in plan.uses do
		useAt[u.tile] = useAt[u.tile] or {}
		table.insert(useAt[u.tile], u)
	end
	local function applyUses(tile: number)
		for _, u in useAt[tile] or {} do
			flush()
			if u.item == "shield" then
				removeCard(p, "shield")
				self:_emit({ t = "shield", p = p.index, item = "wall", tile = tile })
			else
				removeCard(p, u.item)
				self:_emit({ t = "useCard", p = p.index, item = u.item, tile = tile, why = u.why })
			end
		end
	end
	for _, tile in plan.path do
		applyUses(tile)
		p.tile = tile
		table.insert(p.trail, tile)
		table.insert(path, tile)
		p.stats.tiles += 1
		if tile == plan.slowed then
			-- waded through slime: it cost a few steps
			flush()
			self:_emit({ t = "natural", p = p.index, kind = "slime", tile = tile, drag = Rules.SlimeDrag })
		end
	end
	flush()
	if plan.result == "blocked" then
		self:_emit({ t = "blocked", p = p.index, tile = plan.blockedAt })
	elseif plan.result == "stopped" then
		self:_emit({ t = "natural", p = p.index, kind = plan.hazard, tile = p.tile })
	elseif plan.result == "scared" then
		self:_emit({ t = "boo", p = p.index, tile = p.tile, ghost = self.ghostAt[p.tile] })
		self:_shiftBack(p, Rules.GhostScare or 0, "scared")
	end
	for _, tile in plan.crumbles do
		if self.placed[tile] and self.placed[tile].item == "wall" then
			self:_removePlaced(tile, "crumble")
		end
	end
	return plan.result
end

-- Forced movement (traps, bonks, potions, abilities). Callers then resolve the tile it
-- ends on with _land(p, true).
function Engine:_shiftForward(p, n: number, kind: string)
	local board = self.board
	local path = {}
	for _ = 1, n do
		local nxt = board.nextMain[p.tile]
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
	self:_emit({ t = "move", p = p.index, path = { tile }, kind = kind })
end

function Engine:_swap(a, b, kind: string)
	local ta, tb = a.tile, b.tile
	local trailA, trailB = a.trail, b.trail
	a.tile, b.tile = tb, ta
	a.trail, b.trail = trailB, trailA
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

-- One action can chain landings (bonked onto a Mudslide, back onto a belt...). Pieces
-- wear out so chains end on their own; this is only a safety net.
local MAX_LANDINGS = 16

-- Resolves the tile `p` ended up on. Every way of arriving counts: a walk, a trap
-- pushing you, a bonk, a Nudge, a swap, a belt... `forced` is true for anything but
-- the current player's own move. `teleported`: you just came through a teleporter, so
-- the one you arrive on doesn't send you straight back.
function Engine:_land(p: any, forced: boolean?, teleported: boolean?): ()
	if self.phase == "over" then
		return
	end
	self.landings = (self.landings or 0) + 1
	if self.landings > MAX_LANDINGS then
		return
	end
	local tile = p.tile
	if tile == self.board.start or tile == self.board.treasure then
		return
	end
	local origin = self.cover[tile]
	if origin then
		self:_rideConveyor(p, origin)
		return
	end
	-- hidden traps (other teams' traps go off, oldest first)
	local list = self.traps[tile]
	if list then
		for _, trap in copyList(list) do
			if trap.public or trap.team ~= p.team then
				local deaths = p.stats.deaths
				self:_triggerTrap(p, tile, trap)
				if p.tile ~= tile or p.stats.deaths ~= deaths or self.phase == "over" then
					return
				end
			end
		end
	end
	local ember = self.embers[tile]
	if ember and ember.team ~= p.team then
		self:_emit({ t = "scorch", p = p.index, tile = tile, owner = ember.owner })
		self:_setStatus(p, "burning", "embers")
	end
	local piece = self.placed[tile]
	if piece and not (teleported and piece.item == "teleporter") then
		if piece.item == "wall" then
			self:_emit({ t = "trigger", p = p.index, tile = tile, item = "wall", owner = piece.owner })
			self:_removePlaced(tile, "crumble")
		else
			self:_triggerPiece(p, tile, piece)
			if p.tile ~= tile or self.phase == "over" then
				return
			end
		end
	end
	-- bonk everyone from another team standing here
	if not forced or Rules.BonkChain then
		for _, other in self.players do
			if other ~= p and other.tile == tile and other.team ~= p.team and p.tile == tile then
				self:_bonk(p, other)
				if self.phase == "over" then
					return
				end
			end
		end
	end
	if p.tile ~= tile then
		return
	end
	local token = self.tokens[tile]
	if token then
		if token == "potion" then
			-- the shop opens for the player whose turn it is, on their own move
			if p.index == self.current and self.turn and self.turn.canShop then
				self.phase = "shop"
				self.turn.shopTile = tile
				self:_emit({ t = "shop", p = p.index, tile = tile })
			end
		else
			self:_spin(p, token)
			self:_relocateToken(tile)
		end
	end
end

-- `back` overrides how far the victim flies; `trample` (a Stampede running them over)
-- doesn't bounce the attacker forward.
function Engine:_bonk(attacker, victim, back: number?, trample: boolean?)
	if removeCard(victim, "shield") then
		self:_emit({ t = "shield", p = victim.index, item = "bonk", tile = victim.tile, by = attacker.index })
		return
	end
	attacker.stats.bonks += 1
	victim.stats.bonked += 1
	self:_emit({ t = "bonk", p = attacker.index, target = victim.index, tile = victim.tile })
	local w = self.wanted
	if w and w.seat == victim.index then
		self:_claimWanted(attacker, victim, "bonk")
	elseif w and w.seat == attacker.index then
		self:_raiseWanted("bonk")
	end
	if attacker.character == "fire_starter" then
		self:_setStatus(victim, "burning", "bonk")
	end
	local knock = back or self.mut.bonkBack or Rules.BonkBack
	if back == nil and attacker.character == "cannoneer" then
		-- Broadside: the Cannoneer's bonks knock rivals further
		knock += CharCfg.cannoneer.extraBack
	end
	self:_shiftBack(victim, knock, "bonk")
	self:_land(victim, true)
	if not trample and (Rules.BonkBounce or 0) > 0 and self.phase ~= "over" then
		self:_shiftForward(attacker, Rules.BonkBounce, "bounce")
		self:_land(attacker, true)
	end
end

-- A used token jumps to a random free tile, so the board keeps changing.
function Engine:_relocateToken(tile: number)
	local kind = self.tokens[tile]
	if not kind then
		return
	end
	local board = self.board
	local occupied = {}
	for _, other in self.players do
		occupied[other.tile] = true
	end
	local candidates = {}
	for id = 1, board.count do
		if
			id ~= tile
			and not board:isSpecial(id)
			and self.tokens[id] == nil
			and self.placed[id] == nil
			and self.cover[id] == nil
			and self.natural[id] == nil
			and board.tiles[id].kind ~= "shortcutGate"
			and not occupied[id]
		then
			table.insert(candidates, id)
		end
	end
	if #candidates == 0 then
		return
	end
	local dest = self.rng:pick(candidates)
	self.tokens[tile] = nil
	self.tokens[dest] = kind
	self:_emit({ t = "tokenMove", from = tile, to = dest, token = kind })
end

function Engine:_rideConveyor(p, origin: number)
	local entry = self.placed[origin]
	if not entry then
		return
	end
	self:_emit({ t = "trigger", p = p.index, tile = p.tile, item = "conveyor", owner = entry.owner, dir = entry.dir })
	local tiles = entry.tiles
	local pos = table.find(tiles, p.tile) or 1
	self:_usePlaced(origin)
	if entry.dir == "fwd" then
		self:_shiftForward(p, #tiles - pos + 1, "conveyor")
	else
		-- ride back off the start of the belt (retrace the trail)
		self:_shiftBack(p, pos, "conveyor")
	end
	self:_land(p, true)
end

function Engine:_triggerTrap(p, tile: number, trap)
	local item = trap.item
	self:_takeTrap(tile, trap)
	self:_emit({ t = "trigger", p = p.index, tile = tile, item = item, owner = trap.owner, hidden = not trap.public })
	if removeCard(p, "shield") then
		self:_emit({ t = "shield", p = p.index, item = item, tile = tile })
		return
	end
	local owner = self.players[trap.owner]
	if owner and owner ~= p then
		owner.stats.gotchas += 1
		self:_emit({ t = "gotcha", p = owner.index, target = p.index, item = item })
		self:_addCoins(owner, Rules.CoinsPerGotcha, "gotcha")
		self:_gainPower(owner, Rules.PowerPerGotcha)
		local w = self.wanted
		if w and w.seat == p.index then
			self:_claimWanted(owner, p, "trap")
		elseif w and w.seat == owner.index then
			self:_raiseWanted("trap")
		end
	end
	local by = if owner then owner.index else nil
	self:_trapEffect(p, item, by)
	if owner and owner ~= p and owner.character == "trapper" and self.phase ~= "over" then
		-- Bounty Hunter: the Trapper hops forward
		self:_emit({ t = "bounty", p = owner.index })
		self:_shiftForward(owner, CharCfg.trapper.bounty, "bounty")
		self:_land(owner, true)
	end
end

function Engine:_trapEffect(p, item: string, by: number?)
	if item == "spike" then
		self:_knockout(p, "spike", by)
	elseif item == "grog" then
		local roll = self.rng:int(1, 6)
		local survived = roll >= Rules.GrogSurviveMin
		self:_emit({ t = "grog", p = p.index, roll = roll, survived = survived })
		if not survived then
			self:_knockout(p, "grog", by)
		end
	elseif item == "fire" then
		self:_setStatus(p, "burning", "fire")
	elseif item == "ice" then
		self:_setStatus(p, "frozen", "ice")
	elseif item == "snare" then
		self:_setStatus(p, "snared", "snare")
	elseif item == "mudslide" then
		self:_shiftBack(p, Rules.MudslideBack, "mudslide")
		self:_land(p, true)
	elseif item == "banana" then
		if #p.hand > 0 then
			local lost = table.remove(p.hand, self.rng:int(1, #p.hand))
			self:_emit({ t = "drop", p = p.index, item = lost })
		end
		self:_shiftBack(p, Rules.BananaBack, "banana")
		self:_land(p, true)
	end
end

-- Shifting Sands slide you forward in even rounds and backwards in odd ones.
function Engine.sandsForward(round: number): boolean
	return round % 2 == 0
end

-- Visible pieces: teleporters, spore warpers, shifting sands.
function Engine:_triggerPiece(p, tile: number, piece)
	local item = piece.item
	self:_emit({ t = "trigger", p = p.index, tile = tile, item = item, owner = piece.owner })
	if item == "teleporter" then
		local partner = self:_teleportPartner(tile)
		if partner then
			self:_warpTo(p, partner, "teleport")
			self:_land(p, true, true)
		else
			self:_emit({ t = "fizzle", p = p.index, item = item, tile = tile })
		end
	elseif item == "spore_warper" then
		self:_removePlaced(tile, "used")
		if p.character == "warper" then
			self:_emit({ t = "immune", p = p.index, what = "swap" })
		else
			local other = self:_nearestOther(p)
			if other then
				self:_swap(p, other, "spore")
				self:_land(p, true, false)
				self:_land(other, true, false)
			else
				self:_emit({ t = "fizzle", p = p.index, item = item, tile = tile })
			end
		end
	elseif item == "sands" then
		self:_usePlaced(tile)
		if Engine.sandsForward(self.round) then
			self:_shiftForward(p, Rules.SandsSlide, "sands")
		else
			self:_shiftBack(p, Rules.SandsSlide, "sands")
		end
		self:_land(p, true, false)
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
	self.landings = 0
	self.turn.canShop = true
	if self.phase == "shop" then
		if kind == "buy" then
			ok, err = self:_cmdBuy(p, cmd)
		elseif kind == "shopDone" then
			ok, err = self:_cmdShopDone(p)
		else
			return fail("Finish shopping first.")
		end
	elseif self.phase == "pick" then
		if kind == "pick" then
			ok, err = self:_cmdPick(p, cmd)
		else
			return fail("Pick a card first.")
		end
	elseif kind == "move" then
		ok, err = self:_cmdMove(p, cmd)
	elseif kind == "play" then
		ok, err = self:_cmdPlay(p, cmd)
	elseif kind == "ability" then
		ok, err = self:_cmdAbility(p, cmd)
	elseif kind == "recall" then
		ok, err = self:_cmdRecall(p)
	elseif kind == "give" then
		ok, err = self:_cmdGive(p, cmd)
	else
		return fail("Unknown command.")
	end
	if self.turn then
		self.turn.canShop = false
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
	elseif self.phase == "pick" then
		return self:command(self.current, { type = "pick", index = 1 })
	elseif self.phase == "action" and self.turn then
		local dice = self.turn.dice
		local die = 1
		for i, d in dice do
			if d > dice[die] then
				die = i
			end
		end
		return self:command(self.current, { type = "move", die = die })
	end
	return false, "Nothing to do.", {}
end

-- Is die `i` the second of a pair (doubles)? That one moves you backwards. The
-- underdog's gold die (`gold`, its place in the roll) never pairs up.
function Engine.isBackDie(dice: { number }, i: number, gold: number?): boolean
	if i == gold then
		return false
	end
	for j = 1, i - 1 do
		if j ~= gold and dice[j] == dice[i] then
			return true
		end
	end
	return false
end

-- The dice that count for doubles: all of them but the underdog's gold die.
local function plainDice(dice: { number }, gold: number?): { number }
	local out = {}
	for i, d in dice do
		if i ~= gold then
			table.insert(out, d)
		end
	end
	return out
end

--[[
	What moving with die `die` (its place in the roll: 1, 2 or 3) does: the steps, the
	Power the best of the other dice charges, and whether it goes backwards (the second
	die of a pair). "sum" is the total of two doubles (no Power). `gold` is the
	underdog's extra die: it can be moved with but never charges Power or pairs up.
	Shared by the engine, the bots and the match screen.
]]
function Engine.dieOption(dice: { number }, die: any, gold: number?): (number?, number?, boolean?)
	if die == "sum" then
		local plain = plainDice(dice, gold)
		if #plain == 2 and plain[1] == plain[2] then
			return plain[1] + plain[2], 0, false
		end
		return nil, nil, nil
	end
	local i = tonumber(die)
	if i == nil or i ~= math.floor(i) or dice[i :: number] == nil then
		return nil, nil, nil
	end
	local other = 0
	for j, d in dice do
		if j ~= i and j ~= gold and d > other then
			other = d
		end
	end
	return dice[i :: number], other, Engine.isBackDie(dice, i :: number, gold)
end

-- The dice option `die` for the current turn: steps, Power gained, backwards.
function Engine:moveOption(die: any): (number?, number?, boolean?)
	local turn = self.turn
	if not turn then
		return nil, nil, nil
	end
	return Engine.dieOption(turn.dice, die, turn.gold)
end

-- Applies the boost played this turn to a move of `m` steps: (steps, backwards).
-- `double`: the Gambler's Double Down (it doesn't double a Speed Boost again).
function Engine.boosted(m: number, boost: string?, double: boolean?): (number, boolean)
	local def = boost and Items.get(boost)
	if not def then
		return if double then m * 2 else m, false
	end
	if def.boost == "double" then
		return m * 2, false
	elseif def.boost == "plus" then
		return (if double then m * 2 else m) + (def.amount or 0), false
	elseif def.boost == "back" then
		return if double then m * 2 else m, true
	end
	return if double then m * 2 else m, false
end

function Engine:_cmdMove(p, cmd)
	local m, gain, backDie = self:moveOption(cmd.die)
	if not m then
		return false, "Pick one of your dice."
	end
	local backwards
	m, backwards = Engine.boosted(m, self.turn.boost, self.turn.double)
	backwards = backwards or backDie == true
	self:_emit({
		t = "choose",
		p = p.index,
		die = cmd.die,
		move = m,
		back = backwards,
		boost = self.turn.boost,
	})
	if (gain :: number) > 0 then
		self:_gainPower(p, (gain :: number) * (self.mut.powerMult or 1))
	end
	self.turn.boost = nil
	self.turn.moved = true
	if backwards then
		local plan = Engine.backPlan(p, m)
		if #plan.path > 0 then
			for _ = 1, #plan.path do
				table.remove(p.trail)
			end
			p.tile = p.trail[#p.trail]
			p.stats.tiles += #plan.path
			self:_emit({ t = "move", p = p.index, path = plan.path, kind = "moonwalk" })
			self:_land(p, false)
		end
	else
		local result = self:_walk(p, m)
		if result == "treasure" then
			self:_reachTreasure(p)
		else
			-- a ghost chased you back: you didn't land there by your own move
			self:_land(p, result == "scared")
		end
	end
	if self.phase == "action" then
		self:_finishTurn()
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

function Engine:_cmdPlay(p, cmd)
	local item = cmd.item
	local def = type(item) == "string" and Items.get(item)
	if not def or def.category == "coin" then
		return false, "Unknown card."
	end
	if not hasCard(p, item) then
		return false, "You don't have that card."
	end
	if def.use == "passive" then
		return false, "That card works by itself."
	end
	if self.turn.cardsPlayed >= Rules.CardsPerTurn then
		return false, "You've already played a card this turn."
	end
	local use = def.use
	if use == "place" then
		local tile = tonumber(cmd.tile)
		local dir = cmd.dir
		local ok, why = self:canPlace(p, item, tile :: number, dir)
		if not ok then
			return false, why
		end
		removeCard(p, item)
		self:_spend(p, item)
		p.stats.placed += 1
		if def.hidden then
			-- your oldest trap goes if you already have as many out as you may
			local mine = self:trapsOf(p.index)
			while #mine >= trapCap(p) do
				local oldest = table.remove(mine, 1)
				self:_takeTrap(oldest.tile, oldest.trap)
				self:_emit({
					t = "removed",
					tile = oldest.tile,
					item = oldest.trap.item,
					reason = "replaced",
					secret = trapSecret(oldest.trap),
				})
			end
			-- (the Most Wanted can't hide anything any more)
			local exposed = self.wanted ~= nil and self.wanted.most == true and self.wanted.seat == p.index
			local trap = self:_addTrap(tile :: number, item, p.index, p.team, exposed)
			self:_emit({
				t = "place",
				p = p.index,
				item = item,
				tile = tile,
				hidden = true,
				secret = trapSecret(trap),
				alt = { t = "hide", p = p.index },
			})
		else
			self:_addPlaced(tile :: number, item, p.index, if item == "conveyor" then dir else nil)
			self:_emit({ t = "place", p = p.index, item = item, tile = tile, dir = if item == "conveyor" then dir else nil })
		end
		return true
	elseif use == "boost" then
		removeCard(p, item)
		self:_spend(p, item)
		self.turn.boost = item
		self:_emit({ t = "play", p = p.index, item = item })
		return true
	elseif use == "juice" then
		if p.power >= Engine.powerCap(p) then
			return false, "Your Power is already full."
		end
		removeCard(p, item)
		self:_spend(p, item)
		self:_emit({ t = "play", p = p.index, item = item })
		self:_gainPower(p, Engine.powerCap(p))
		return true
	elseif use == "reroll" then
		removeCard(p, item)
		self:_spend(p, item)
		self:_emit({ t = "play", p = p.index, item = item })
		self:_roll(p, true)
		return true
	elseif use == "compass" then
		if self.turn.frozen then
			return false, "You're Frozen: the needle won't move."
		end
		local i = tonumber(cmd.die)
		local value = tonumber(cmd.value)
		if not i or self.turn.dice[i] == nil then
			return false, "Pick one of your dice."
		end
		if not value or value ~= math.floor(value) or value < 1 or value > 6 then
			return false, "Pick a number from 1 to 6."
		end
		removeCard(p, item)
		self:_spend(p, item)
		self:_emit({ t = "play", p = p.index, item = item })
		local from = self.turn.dice[i]
		self.turn.dice[i] = value
		self:_emit({ t = "compass", p = p.index, die = i, from = from, value = value, dice = copyList(self.turn.dice) })
		return true
	elseif use == "anchor" then
		if p.anchor then
			return false, "You already have a time anchor."
		end
		removeCard(p, item)
		self:_spend(p, item)
		p.anchor = { tile = p.tile, trail = copyList(p.trail) }
		self:_emit({ t = "play", p = p.index, item = item, tile = p.tile })
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
		if steps < 0 and #t.trail <= 1 then
			return false, "They're already at the Start."
		end
		removeCard(p, item)
		self:_spend(p, item)
		self:_emit({ t = "play", p = p.index, item = item, target = t.index, steps = steps })
		self:_shift(t, steps, "telepathy")
		self:_land(t, true)
		return true
	elseif use == "jeopardy" then
		local t, why = self:_validTarget(p, cmd.target, false)
		if not t then
			return false, why
		end
		removeCard(p, item)
		self:_spend(p, item)
		p.hand, t.hand = t.hand, p.hand
		self:_emit({ t = "play", p = p.index, item = item, target = t.index })
		-- both new hands ride along; each player only sees their own
		self:_emit({
			t = "handSwap",
			a = p.index,
			b = t.index,
			handA = copyList(p.hand),
			handB = copyList(t.hand),
			secret = { seats = { [p.index] = true, [t.index] = true } },
			alt = { t = "handSwap", a = p.index, b = t.index, countA = #p.hand, countB = #t.hand },
		})
		self:_shiftBack(t, Rules.JeopardySteps, "jeopardy")
		self:_land(t, true)
		self:_shiftForward(p, Rules.JeopardySteps, "jeopardy")
		self:_land(p, true)
		return true
	elseif use == "steal" then
		local t, why = self:_validTarget(p, cmd.target, false)
		if not t then
			return false, why
		end
		if t.team == p.team then
			return false, "Steal from a rival, not a teammate."
		end
		if #t.hand == 0 then
			return false, "They have no cards to steal."
		end
		removeCard(p, item)
		self:_spend(p, item)
		self:_emit({ t = "play", p = p.index, item = item, target = t.index })
		local taken = table.remove(t.hand, self.rng:int(1, #t.hand))
		table.insert(p.hand, taken)
		-- only the two of them see which card it was
		self:_emit({
			t = "steal",
			p = p.index,
			target = t.index,
			item = taken,
			secret = { seats = { [p.index] = true, [t.index] = true } },
			alt = { t = "steal", p = p.index, target = t.index },
		})
		return true
	elseif use == "xray" then
		removeCard(p, item)
		self:_spend(p, item)
		local seen = {}
		for tile, list in self.traps do
			for _, trap in list do
				if not self:canSee(p.index, trap) then
					trap.seenBy[p.index] = true
					table.insert(seen, { tile = tile, item = trap.item, owner = trap.owner })
				end
			end
		end
		self:_emit({
			t = "xray",
			p = p.index,
			traps = seen,
			secret = { seat = p.index },
			alt = { t = "play", p = p.index, item = item },
		})
		return true
	end
	return false, "That card works by itself."
end

-- Bookkeeping for a card leaving your hand by being played.
function Engine:_spend(p, _item: string)
	self.turn.cardsPlayed += 1
	p.stats.played += 1
end

function Engine:_cmdRecall(p)
	local anchor = p.anchor
	if not anchor then
		return false, "You have no time anchor."
	end
	p.anchor = nil
	self.turn.moved = true
	self:_emit({ t = "recall", p = p.index, tile = anchor.tile })
	self:_warpTo(p, anchor.tile, "recall", anchor.trail)
	self:_land(p)
	if self.phase == "action" then
		self:_finishTurn()
	end
	return true
end

function Engine:_cmdGive(p, cmd)
	if not self.mode.isTeam then
		return false, "Only in team modes."
	end
	if self.turn.cardsPlayed >= Rules.CardsPerTurn then
		return false, "You've already played a card this turn."
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
	if #t.hand >= Rules.HandLimit then
		return false, t.name .. "'s hand is full."
	end
	removeCard(p, item)
	self.turn.cardsPlayed += 1
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
	if #p.hand >= Rules.HandLimit then
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
	local turn = self.turn
	if turn and turn.shopTile then
		self:_relocateToken(turn.shopTile)
		turn.shopTile = nil
	end
	if turn and not turn.moved then
		-- the shop opened before you moved (an ability or card put you there): carry on
		return true
	end
	self:_finishTurn()
	return true
end

-- Scavenge: keep one of the two cards on offer.
function Engine:_cmdPick(p, cmd)
	local pick = self.turn.pick
	local i = tonumber(cmd.index)
	if not pick or (i ~= 1 and i ~= 2) or pick.options[i :: number] == nil then
		return false, "Pick one of the cards."
	end
	local item = pick.options[i :: number]
	self.turn.pick = nil
	self.phase = "action"
	self:_emit({ t = "picked", p = p.index, secret = { seat = p.index }, alt = { t = "picked", p = p.index } })
	self:_giveCard(p, item, "scavenge")
	return true
end

-- Everyone a Mage's Blizzard freezes: every rival.
function Engine:_blizzardTargets(p): { number }
	local hit = {}
	for _, o in self.players do
		if o.team ~= p.team then
			table.insert(hit, o.index)
		end
	end
	return hit
end

function Engine:_cmdAbility(p, cmd)
	if self.rules.abilities == false then
		return false, "Abilities are off in this match."
	end
	local cdef = Characters.get(p.character)
	local ab = cdef and cdef.ability
	if not ab then
		return false, "Your character has no ability."
	end
	if self.turn.abilityUsed then
		return false, "You already used your ability this turn."
	end
	if p.power < ab.cost then
		return false, "Your Power bar isn't full yet."
	end
	local id = ab.id
	local target
	if ab.target == "other" or ab.target == "any" then
		local why
		target, why = self:_validTarget(p, cmd.target, ab.target == "any")
		if not target then
			return false, why
		end
		if ab.range and self.board:raceDistance(p.tile, target.tile) > ab.range then
			return false, "Too far: they must be within " .. ab.range .. " tiles."
		end
	end
	local option = cmd.option
	if ab.options and id ~= "scavenge" and not table.find(ab.options, option) then
		return false, "Choose an option."
	end
	local tile = tonumber(cmd.tile)
	if id == "warp" then
		if target.tile == p.tile then
			return false, "You're already on the same tile."
		end
		if target.character == "warper" then
			return false, "Warpers can't be swapped."
		end
	end
	if id == "nudge" and option == "back" and #target.trail <= 1 then
		return false, "They're already at the Start."
	end

	-- commit
	self.turn.abilityUsed = true
	p.stats.abilities += 1
	p.power = 0
	self:_emit({ t = "ability", p = p.index, ability = id, target = target and target.index, option = option, tile = tile })
	if id == "blizzard" then
		local hit = self:_blizzardTargets(p)
		self:_emit({ t = "blizzard", p = p.index, targets = hit })
		for _, seat in hit do
			self:_setStatus(self.players[seat], "frozen", "blizzard", CharCfg.mage.turns)
		end
		-- and the Mage skates ahead on the ice
		if (CharCfg.mage.skate or 0) > 0 then
			self:_shiftForward(p, CharCfg.mage.skate, "skate")
			if self.phase ~= "over" and p.tile ~= self.board.start then
				self:_land(p, true)
			end
		end
	elseif id == "scavenge" then
		local pool = {}
		for _, t in Items.trapIds do
			if not self.banned[t] then
				table.insert(pool, t)
			end
		end
		local a = table.remove(pool, self.rng:int(1, #pool))
		local b = if #pool > 0 then pool[self.rng:int(1, #pool)] else a
		self.turn.pick = { kind = "scavenge", options = { a, b } }
		self.phase = "pick"
		self:_emit({
			t = "offer",
			p = p.index,
			options = { a, b },
			secret = { seat = p.index },
			alt = { t = "offer", p = p.index },
		})
	elseif id == "blast" then
		local from = p.tile
		self:_shiftForward(p, CharCfg.fire_starter.blast, "blast")
		if self.phase ~= "over" then
			-- the tiles flown over burn until the Fire Starter's next turn
			local burnt = {}
			local cur = from
			while true do
				cur = self.board.nextMain[cur]
				if not cur or cur == p.tile or cur == self.board.treasure then
					break
				end
				if not self.board:isSpecial(cur) then
					self.embers[cur] = { owner = p.index, team = p.team }
					table.insert(burnt, cur)
				end
				if #burnt >= CharCfg.fire_starter.blast then
					break
				end
			end
			if #burnt > 0 then
				self:_emit({ t = "embers", p = p.index, tiles = burnt })
			end
			if p.tile ~= self.board.start then
				self:_land(p, true)
			end
		end
	elseif id == "stampede" then
		-- the herd charges ahead; rivals on the tiles it runs over (the last one too) are
		-- trampled back
		local over = {}
		local cur = p.tile
		for _ = 1, CharCfg.naturalist.charge do
			cur = self.board.nextMain[cur]
			if not cur or cur == self.board.treasure then
				break
			end
			over[cur] = true
		end
		self:_shiftForward(p, CharCfg.naturalist.charge, "stampede")
		if self.phase ~= "over" then
			for _, other in self.players do
				if self.phase ~= "over" and other ~= p and self:isOpponent(p, other) and over[other.tile] then
					self:_bonk(p, other, CharCfg.naturalist.trample, true)
				end
			end
			if self.phase ~= "over" and p.tile ~= self.board.start then
				self:_land(p, true)
			end
		end
	elseif id == "warp" then
		self:_swap(p, target, "warp")
		self:_land(p, true)
		self:_land(target, true)
	elseif id == "nudge" then
		local steps = CharCfg.overseer.steps
		self:_shift(target, if option == "fwd" then steps else -steps, "nudge")
		self:_land(target, true)
	elseif id == "doubledown" then
		-- this turn's move counts double
		self.turn.double = true
		self:_emit({ t = "doubleDown", p = p.index })
	elseif id == "cannonball" then
		-- fly at the nearest rival ahead (along the trail) and land on them with a bonk
		local cfg = CharCfg.cannoneer
		local cur, hit = p.tile, nil
		for step = 1, cfg.range do
			cur = self.board.nextMain[cur]
			if not cur or cur == self.board.treasure then
				break
			end
			for _, o in self.players do
				if o ~= p and self:isOpponent(p, o) and o.tile == cur then
					hit = step
					break
				end
			end
			if hit then
				break
			end
		end
		local steps = hit or cfg.fly
		self:_emit({ t = "cannon", p = p.index, steps = steps, hit = hit ~= nil })
		self:_shiftForward(p, steps, "cannon")
		if self.phase ~= "over" and p.tile ~= self.board.start then
			self:_land(p, false)
		end
	end
	return true
end

---------------------------------------------------------------------------
-- outside the turn: the match host's hooks
---------------------------------------------------------------------------

-- Coins from outside the rules (a lucky catch while fishing between turns). Returns
-- the events to send.
function Engine:grantCoins(seat: number, n: number, why: string)
	local p = self.players[seat]
	if not p or self.phase == "over" or self.phase == "setup" then
		return {}
	end
	self:_addCoins(p, n, why)
	return self:_flushEvents()
end

-- A player drops into a bot's seat (Quick Play drop-in). Returns the events to send.
function Engine:takeSeat(seat: number, info)
	local p = self.players[seat]
	if not p or not p.isBot then
		return {}
	end
	p.isBot = false
	p.id = info.id or p.id
	p.userId = info.userId
	p.name = info.name or p.name
	-- (back: they're the player who had this seat, back from a dropped connection)
	self:_emit({ t = "joined", p = seat, name = p.name, back = info.back == true or nil })
	return self:_flushEvents()
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

-- A plain-data view of the game for clients. `forSeat` sees their own hand and the
-- hidden traps they're allowed to see.
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
			power = p.power,
			powerCap = if self.rules.abilities == false then 0 else Engine.powerCap(p),
			frozen = p.status.frozen,
			burning = p.status.burning,
			skip = p.status.skip,
			anchor = if p.anchor then p.anchor.tile else 0,
			trailLength = #p.trail,
			stats = table.clone(p.stats),
		})
	end
	local tokens, placed, natural, traps, embers = {}, {}, {}, {}, {}
	for tile, kind in self.tokens do
		table.insert(tokens, { tile = tile, kind = kind })
	end
	for tile, ember in self.embers do
		table.insert(embers, { tile = tile, owner = ember.owner })
	end
	for tile, e in self.placed do
		table.insert(placed, { tile = tile, item = e.item, owner = e.owner, dir = e.dir, uses = e.uses, tiles = e.tiles })
	end
	for tile, kind in self.natural do
		table.insert(natural, { tile = tile, kind = kind })
	end
	for tile, list in self.traps do
		for _, trap in list do
			if forSeat and self:canSee(forSeat, trap) then
				table.insert(traps, { tile = tile, item = trap.item, owner = trap.owner, team = trap.team, public = trap.public })
			end
		end
	end
	local turn = self.turn
	local snap = {
		mode = self.mode.id,
		map = self.map.id,
		phase = self.phase,
		current = self.current,
		round = self.round,
		turnNo = self.turnCount,
		target = self.target,
		teamTarget = self.teamTarget,
		order = copyList(self.turnOrder or {}),
		players = players,
		tokens = tokens,
		placed = placed,
		natural = natural,
		traps = traps,
		embers = embers,
		teleporters = copyList(self.teleporters),
		stock = table.clone(self.stock),
		winnerTeam = self.winnerTeam,
		ranking = self.ranking and copyList(self.ranking) or nil,
		endReason = self.endReason,
		dice = if turn then copyList(turn.dice) else {},
		gold = if turn then turn.gold else nil,
		cardsPlayed = if turn then turn.cardsPlayed else 0,
		abilityUsed = if turn then turn.abilityUsed else false,
		boost = if turn then turn.boost else nil,
		double = if turn then turn.double == true else false,
		mutator = table.clone(self.mut),
		rules = { abilities = self.rules.abilities ~= false, wanted = self.rules.wanted ~= false, underdog = self.rules.underdog ~= false, board = self.rules.board or "full", banned = table.clone(self.banned) },
		underdog = if self.phase ~= "over" then self:underdogSeat() else nil,
		wanted = if self.wanted then { seat = self.wanted.seat, pot = self.wanted.pot, most = self.wanted.most == true } else nil,
		ghosts = copyList(self.ghosts),
		erupting = self:eruptsThisRound(),
	}
	if forSeat and self.players[forSeat] then
		local me = self.players[forSeat]
		snap.hand = copyList(me.hand)
		snap.trail = copyList(me.trail)
		if turn and turn.pick and forSeat == self.current then
			snap.pick = copyList(turn.pick.options)
		end
	end
	return snap
end

-- Rebuilds lookup layers from a snapshot (client-side placement previews).
function Engine.layersFromSnapshot(board, snap)
	local layers = { placed = {}, cover = {}, natural = {}, tokens = {}, traps = {} }
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
	for _, trap in snap.traps or {} do
		layers.traps[trap.tile] = layers.traps[trap.tile] or {}
		table.insert(layers.traps[trap.tile], trap)
	end
	return layers
end

Engine.hasCard = hasCard
Engine.countCards = count

return Engine
