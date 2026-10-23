--[[
	Match
	Runs one Trapisque game on the server: wraps the rules Engine, drives bots, turn
	timers and away players (Shared/Game/TurnClock), and streams events + snapshots to
	every player. Each batch says when it starts and ends on the server's clock, so a
	screen that falls behind (lag, a slow device) speeds up instead of drifting.

	Around the game itself:
		vote        Quick Play (and private matches whose host turns it on) opens with a map
		            vote: three or four cards (maps, a face-down Mystery map, a map with a
		            twist), decided by the most votes or by a roulette wheel
		rules       a private match's house rules (Shared/Game/HouseRules)
		drop-in     someone searching for Quick Play can take over a bot's seat early on
		spectators  friends can watch: they get what everyone may see, and no hand
		fishing     between your turns you can fish off the board (Meta/Fishing)
		tutorial    the guided first match: scripted dice and cards, the human goes first
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Engine = require(Shared.Game.Engine)
local Bot = require(Shared.Game.Bot)
local Modes = require(Shared.Game.Modes)
local Maps = require(Shared.Game.Maps)
local HouseRules = require(Shared.Game.HouseRules)
local Voting = require(Shared.Game.Voting)
local Pacing = require(Shared.Game.Pacing)
local TurnClock = require(Shared.Game.TurnClock)
local Cosmetics = require(Shared.Meta.Cosmetics)
local Progress = require(Shared.Meta.Progress)
local QuickChat = require(Shared.Meta.QuickChat)
local Fishing = require(Shared.Meta.Fishing)
local Tutorial = require(Shared.Meta.Tutorial)

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local BadgeService = require(script.Parent.BadgeService)

local T = Config.Timing

local Match = {}
Match.__index = Match

local BOT_NAMES = {
	"Pip", "Nib", "Rusty", "Mossy", "Bolt", "Clank", "Fizz", "Pebble", "Tumble", "Sprocket",
	"Dot", "Gizmo", "Biscuit", "Nugget", "Pickle", "Waffle", "Cobble", "Barnacle",
}

local random = Random.new()

-- quick chat lines a bot may say instead of an emote
local BOT_LINES = {
	emote_oops = { "oops" },
	emote_nice = { "nice" },
	emote_gg = { "gg" },
}

local function botLook()
	local function pick(category, maxRarity)
		local options = {}
		for _, def in Cosmetics.byCategory[category] do
			if def.source == nil and (def.rarity == "common" or def.rarity == maxRarity) then
				table.insert(options, def.id)
			end
		end
		if #options == 0 then
			return Cosmetics.defaults[category]
		end
		return options[random:NextInteger(1, #options)]
	end
	return {
		-- about half the bots have a finer piece than the painted one
		finish = if random:NextNumber() < 0.5 then pick("finish", "rare") else Cosmetics.defaults.finish,
		dice = pick("dice", "rare"),
		trail = pick("trail", "rare"),
		title = "title_none",
		level = random:NextInteger(1, 12),
		vip = false,
		-- a few bots have played their character a lot
		base = if random:NextNumber() < 0.2 then 1 else 0,
	}
end

--[[
	spec = {
		mode, map ("random" ok), length, kind ("public" | "private" | "practice"),
		humans = { { player = Player, team = number?, character = string? } },
		bots = { { team = number? } },
		teamsPreset = boolean, -- teams given for every seat
		parties = { { leader, members, settings } }, -- restored after reserved matches
		vote = true | { style, mystery, wildcard }, -- open with a map vote (Quick Play: true)
		rules = table?,        -- a private match's house rules (HouseRules)
		tutorial = boolean,    -- the guided first match
	}
]]
function Match.new(spec, hooks)
	local self = setmetatable({}, Match)
	local mode = Modes.get(spec.mode)
	assert(mode, "Match: unknown mode")
	local mapId = spec.map
	if mapId == nil or mapId == "random" or not Maps.get(mapId) then
		mapId = Maps.list[random:NextInteger(1, #Maps.list)].id
	end
	self.id = HttpService:GenerateGUID(false)
	self.hooks = hooks or {}
	self.kind = spec.kind or "private"
	self.mode = mode
	self.mapId = mapId
	self.length = mode.length or spec.length or "quick"
	self.parties = spec.parties or {}
	self.tutorial = spec.tutorial == true
	self.closed = false
	self.finished = false
	self.phase = "intro"
	self.spectators = {} -- [Player] = true
	self.fishing = {} -- [seat] = { state, biteAt, token, coinRound }
	self.feats = {} -- [seat] = badge-worthy moments this match (BadgeService)

	-- seat order: by team when teams are preset, humans before bots otherwise
	local entries = {}
	for _, h in spec.humans do
		table.insert(entries, { player = h.player, team = h.team, isBot = false, character = h.character })
	end
	for _, b in spec.bots or {} do
		table.insert(entries, { team = b.team, isBot = true })
	end
	if spec.teamsPreset then
		table.sort(entries, function(a, b)
			if a.team ~= b.team then
				return (a.team or 0) < (b.team or 0)
			end
			if a.isBot ~= b.isBot then
				return not a.isBot
			end
			return false
		end)
	end
	assert(#entries >= 1 and #entries <= 6, "Match: 1-6 seats")

	local names = table.clone(BOT_NAMES)
	self.seats = {} -- [seat] = { player, userId, name, isBot, team, look }
	self.seatOf = {} -- [Player] = seat
	local enginePlayers = {}
	for seat, e in entries do
		local info
		if e.isBot then
			local name = table.remove(names, random:NextInteger(1, #names))
			info = { name = "Bot " .. name, userId = 0, isBot = true, team = e.team, look = botLook() }
		else
			info = {
				player = e.player,
				userId = e.player.UserId,
				name = e.player.DisplayName,
				username = e.player.Name,
				isBot = false,
				team = e.team,
				look = DataService.publicLook(e.player),
			}
			self.seatOf[e.player] = seat
		end
		self.seats[seat] = info
		-- humans play the character they picked in the lobby; bots get one at random
		local character = e.character
		if character == nil and not e.isBot then
			character = DataService.selectedCharacter(e.player)
		end
		enginePlayers[seat] = {
			id = if info.isBot then ("bot" .. seat) else ("u" .. info.userId),
			userId = info.userId,
			name = info.name,
			isBot = info.isBot,
			team = e.team,
			character = character,
		}
		self.feats[seat] = {}
	end
	self.enginePlayers = enginePlayers
	self.teamsPreset = spec.teamsPreset == true

	-- the weekly event queue plays with the week's twist on the rules
	if mode.isEvent then
		local event = Progress.eventById(spec.event) or Progress.currentEvent()
		self.event = event.id
		self.mutator = event.mutator
	end
	-- a private match's house rules, which can bring a twist of their own
	self.rules = if spec.rules then HouseRules.clean(spec.rules) else nil
	if self.rules and self.rules.twist ~= "none" then
		self:_addTwist(self.rules.twist)
	end
	-- (a rematch keeps the twist its map won the vote with)
	if spec.twist and spec.twist ~= self.twist then
		self:_addTwist(spec.twist)
	end

	-- the map vote: Quick Play's, or a private match's whose host turned it on
	if spec.vote then
		local cfg = if type(spec.vote) == "table" then spec.vote else { style = "majority", mystery = true }
		self.voteStyle = if cfg.style == "roulette" then "roulette" else "majority"
		local mapIds, eventIds = {}, {}
		for _, m in Maps.list do
			table.insert(mapIds, m.id)
		end
		for _, e in Progress.events do
			table.insert(eventIds, e.id)
		end
		self.voteOptions, self.mysteryMap = Voting.cards(cfg, mapIds, eventIds, self.twist, random)
		self.votes = {} -- [seat] = the option they voted for
	else
		self:_makeEngine(mapId)
	end
	-- practice games have no turn timer (nobody is waiting on you); a host can set one
	local timed, turnTime = self.kind ~= "practice", mode.turnTime
	if self.rules and self.rules.timer ~= HouseRules.defaults.timer then
		timed = timed and self.rules.timer > 0
		turnTime = if self.rules.timer > 0 then self.rules.timer else turnTime
	end
	self.clock = TurnClock.new({ timed = timed, turnTime = turnTime })
	self.lastEmote = {}
	self.busyUntil = 0
	self.lastTurn = -1
	self.lastPhase = ""
	self.botAt = nil
	self.botSteps = 0
	return self
end

-- A weekly event's twist on top of whatever twist the match already has.
function Match:_addTwist(eventId: string)
	local event = Progress.eventById(eventId)
	if not event then
		return
	end
	local mut = table.clone(self.mutator or {})
	for k, v in event.mutator do
		mut[k] = v
	end
	self.mutator = mut
	self.twist = event.id
end

function Match:_makeEngine(mapId: string)
	self.mapId = mapId
	local opts = {
		mode = self.mode.id,
		map = mapId,
		players = self.enginePlayers,
		seed = random:NextInteger(1, 2 ^ 30),
		target = Modes.targetFor(self.mode, self.length),
		length = self.length,
		teamsPreset = self.teamsPreset,
		mutator = self.mutator,
		rules = self.rules,
	}
	if self.tutorial then
		-- the guided match: the human goes first with scripted dice and cards
		local human = 1
		for seat, info in self.seats do
			if not info.isBot then
				human = seat
			end
		end
		opts.rig = Tutorial.dice(human, #self.seats)
		opts.hands = { [human] = table.clone(Tutorial.hand) }
		opts.firstSeat = human
	end
	self.engine = Engine.new(opts)
	-- everyone stands on the base they've earned with the character they ended up with
	for seat, info in self.seats do
		if info.player and info.look then
			info.look.base = DataService.baseFor(info.player, self.engine.players[seat].character)
		end
	end
end

function Match:humans(): { Player }
	local out = {}
	for _, info in self.seats do
		if info.player and info.player.Parent == Players then
			table.insert(out, info.player)
		end
	end
	return out
end

-- Everyone watching: the humans playing and the spectators.
function Match:audience(): { Player }
	local out = self:humans()
	for player in self.spectators do
		if player.Parent == Players then
			table.insert(out, player)
		end
	end
	return out
end

function Match:seatList()
	local list = {}
	for seat, info in self.seats do
		local p = self.engine and self.engine.players[seat]
		local ep = self.enginePlayers[seat]
		table.insert(list, {
			seat = seat,
			name = info.name,
			username = info.username,
			userId = info.userId,
			isBot = info.isBot,
			team = if p then p.team else ep.team,
			character = if p then p.character else ep.character,
			look = info.look,
		})
	end
	return list
end

-- os.clock() time -> the server time every client can read (0 for "never").
local function serverTime(clockTime: number): number
	if clockTime == math.huge then
		return 0
	end
	return workspace:GetServerTimeNow() + (clockTime - os.clock())
end

-- `timing` = { startAt, endAt }: when this batch starts and stops playing, server time.
-- Each seat only gets what it may know: rivals' hidden traps, other players' cards and
-- the like are left out or replaced by counts (Engine:eventsFor and Engine:snapshot).
-- Seat 0 is a spectator: only what everyone may see.
function Match:_payloadFor(seat: number, events, timing)
	return {
		id = self.id,
		events = self.engine:eventsFor(seat, events),
		snapshot = self.engine:snapshot(if seat > 0 then seat else nil),
		deadline = serverTime(self.clock.deadline),
		auto = seat > 0 and self.clock:isAway(seat),
		startAt = timing and timing.startAt,
		endAt = timing and timing.endAt,
	}
end

-- The fields every "match.start" / resync payload has.
function Match:_describe(payload, seat: number)
	payload.seat = seat
	payload.kind = self.kind
	payload.mode = self.mode.id
	payload.map = self.mapId
	payload.length = self.length
	payload.target = self.engine.target
	payload.seats = self:seatList()
	-- (the board to build: a house rule can cut it short)
	payload.board = if self.rules then self.rules.board else "full"
	payload.houseRules = if self.rules and HouseRules.changesPlay(self.rules) then HouseRules.describe(self.rules) else nil
	payload.twist = self.twist
	payload.tutorial = self.tutorial or nil
	payload.spectating = seat == 0 or nil
	return payload
end

function Match:start()
	if self.voteOptions and not self.engine then
		task.spawn(function()
			self:_runVote()
			if not self.closed then
				self:_begin()
			end
		end)
		return
	end
	self:_begin()
end

---------------------------------------------------------------------------
-- the map vote
---------------------------------------------------------------------------

function Match:_votePayload()
	local votes = {}
	for seat, option in self.votes do
		votes[tostring(seat)] = option
	end
	return {
		id = self.id,
		options = self.voteOptions,
		style = self.voteStyle,
		votes = votes,
		deadline = self.voteDeadline,
		seats = self:seatList(),
		mode = self.mode.id,
	}
end

function Match:_pushVote()
	local payload = self:_votePayload()
	for _, p in self:audience() do
		local data = table.clone(payload)
		data.seat = self.seatOf[p] or 0
		Net.push(p, "match.vote", data)
	end
end

function Match:_runVote()
	self.phase = "vote"
	self.voteDeadline = workspace:GetServerTimeNow() + T.VoteTime
	self:_pushVote()
	local ends = os.clock() + T.VoteTime
	while os.clock() < ends and not self.closed do
		task.wait(0.2)
		local all = true
		for _, p in self:humans() do
			if not self.votes[self.seatOf[p]] then
				all = false
			end
		end
		if all and #self:humans() > 0 then
			task.wait(0.8) -- everyone's in: a moment to see the result
			break
		end
	end
	local chosen, weights = Voting.tally(self.voteOptions, self.votes, self.voteStyle, random)
	local option = self.voteOptions[chosen]
	local mapId = if option.kind == "mystery" then self.mysteryMap or option.map else option.map
	if option.kind == "twist" then
		self:_addTwist(option.event)
	end
	self:_makeEngine(mapId)
	for _, p in self:audience() do
		Net.push(p, "match.voted", {
			id = self.id,
			option = chosen,
			map = mapId,
			mystery = option.kind == "mystery" or nil,
			event = option.event,
			style = self.voteStyle,
			weights = weights,
		})
	end
	-- (a roulette wheel takes a moment to spin, and a Mystery card to turn over)
	task.wait((if self.voteStyle == "roulette" then 4.2 else 1.2) + (if option.kind == "mystery" then 0.9 else 0))
end

-- `option`: the card's number (or, from an older screen, a map's id).
function Match:vote(player: Player, option: any)
	local seat = self.seatOf[player]
	if not seat or self.phase ~= "vote" then
		return false, "Voting is over."
	end
	local index = tonumber(option)
	if index == nil and type(option) == "string" then
		for i, o in self.voteOptions do
			if o.map == option and o.kind == "map" then
				index = i
			end
		end
	end
	if not index or not self.voteOptions[index] then
		return false, "Pick one of the maps."
	end
	self.votes[seat] = index
	self:_pushVote()
	return true
end

---------------------------------------------------------------------------
-- playing
---------------------------------------------------------------------------

function Match:_begin()
	local events = self.engine:start()
	self.phase = "playing"
	local now = os.clock()
	local engine = self.engine
	self.busyUntil = now + T.IntroTime + Pacing.total(events)
	self.lastTurn = engine.turnCount
	self.lastPhase = engine.phase
	self.clock:begin(engine.current, engine.phase, self.busyUntil, engine.turnCount)
	local timing = { startAt = serverTime(now + T.IntroTime), endAt = serverTime(self.busyUntil) }
	for seat, info in self.seats do
		if info.player then
			local payload = self:_describe(self:_payloadFor(seat, events, timing), seat)
			payload.intro = T.IntroTime
			Net.push(info.player, "match.start", payload)
		end
	end
	for player in self.spectators do
		local payload = self:_describe(self:_payloadFor(0, events, timing), 0)
		payload.intro = T.IntroTime
		Net.push(player, "match.start", payload)
	end
	self:_scanFeats(events)
	task.spawn(function()
		self:_loop()
	end)
end

-- Full state for a client that needs to resync (or a spectator who just arrived).
function Match:resync(player: Player)
	if not self.engine or self.phase == "vote" then
		return nil
	end
	local seat = self.seatOf[player] or (if self.spectators[player] then 0 else nil)
	if not seat then
		return nil
	end
	local payload = self:_describe(self:_payloadFor(seat, {}), seat)
	payload.intro = 0
	payload.resync = true
	return payload
end

function Match:_broadcast(events)
	if #events == 0 then
		return
	end
	local engine = self.engine
	local now = os.clock()
	local startsAt = math.max(self.busyUntil, now)
	self.busyUntil = startsAt + Pacing.total(events)
	if engine.turnCount ~= self.lastTurn or engine.phase ~= self.lastPhase then
		self.lastTurn = engine.turnCount
		self.lastPhase = engine.phase
		-- the next player's time starts once this batch has played out on screens
		self.clock:begin(engine.current, engine.phase, self.busyUntil, engine.turnCount)
		self.botAt = nil
		self.botSteps = 0
		-- whoever's turn it is now puts their rod away
		self:_stopFishing(engine.current)
	else
		self.clock:extend(self.busyUntil)
	end
	local timing = { startAt = serverTime(startsAt), endAt = serverTime(self.busyUntil) }
	for seat, info in self.seats do
		if info.player and info.player.Parent == Players then
			Net.push(info.player, "match.events", self:_payloadFor(seat, events, timing))
		end
	end
	if next(self.spectators) then
		local public = self:_payloadFor(0, events, timing)
		for player in self.spectators do
			Net.push(player, "match.events", public)
		end
	end
	self:_scanFeats(events)
	self:_botReactions(events)
	if engine:isOver() then
		self:_finish()
	end
end

-- Notes the moments badges care about (BadgeService.matchFeats).
function Match:_scanFeats(events)
	local bonksBy = {}
	for _, e in events do
		local f = e.p and self.feats[e.p]
		if e.t == "bonk" then
			bonksBy[e.p] = (bonksBy[e.p] or 0) + 1
			if self.lastAbility and self.lastAbility.seat == e.p and self.lastAbility.id == "cannonball" then
				self.feats[e.p].cannonBonk = true
			end
		elseif e.t == "roll" and f and not e.reroll then
			local d = e.dice or {}
			if #d == 2 and d[1] == 1 and d[2] == 1 then
				f.snakeEyes = true
			elseif #d == 2 and d[1] == 6 and d[2] == 6 then
				f.boxcars = true
			end
		elseif e.t == "grog" and f and e.survived then
			f.grog = true
		elseif e.t == "phoenix" and f then
			f.phoenix = true
		elseif e.t == "boo" and f then
			f.scared = (f.scared or 0) + 1
		elseif e.t == "scorch" and f and e.lava then
			f.scorched = true
		elseif e.t == "ability" then
			self.lastAbility = { seat = e.p, id = e.ability }
		elseif e.t == "doubleDown" and f then
			f.doubleDown = true
		elseif e.t == "treasure" and f and f.doubleDown then
			f.jackpot = true
		elseif e.t == "turn" then
			self.lastAbility = nil
			for _, ff in self.feats do
				ff.doubleDown = nil
			end
		end
	end
	for seat, n in bonksBy do
		if n >= 2 and self.feats[seat] then
			self.feats[seat].multiBonk = true
		end
	end
end

-- Bots occasionally emote, which makes a lobby full of bots feel alive.
function Match:_botReactions(events)
	for _, e in events do
		local seat, emote, chance = nil, nil, 0
		if e.t == "death" then
			seat, emote, chance = e.p, "emote_oops", 0.35
		elseif e.t == "treasure" then
			seat, emote, chance = e.p, "emote_nice", 0.25
		elseif e.t == "gotcha" then
			seat, emote, chance = e.p, "emote_nice", 0.2
		elseif e.t == "bonk" then
			seat, emote, chance = e.target, "emote_oops", 0.15
		elseif e.t == "gameover" then
			for s, info in self.seats do
				if info.isBot and random:NextNumber() < 0.6 then
					task.delay(random:NextNumber() * 2 + 1, function()
						if random:NextNumber() < 0.5 then
							self:_botSay(s, if random:NextNumber() < 0.5 then "gg" else "thanks")
						else
							self:_sendEmote(s, "emote_gg")
						end
					end)
				end
			end
		end
		if seat and self.seats[seat] and self.seats[seat].isBot and random:NextNumber() < chance then
			task.delay(random:NextNumber() + 0.8, function()
				-- half the time a bot says it with a quick chat line instead
				local line = BOT_LINES[emote]
				if line and random:NextNumber() < 0.5 then
					self:_botSay(seat, line[random:NextInteger(1, #line)])
				else
					self:_sendEmote(seat, emote)
				end
			end)
		end
	end
end

-- A bot's quick chat line (fixed text, like everyone's quick lines).
function Match:_botSay(seat: number, quickId: string)
	local q = QuickChat.get(quickId)
	local info = self.seats[seat]
	if self.closed or not q or not info or not info.isBot then
		return
	end
	local p = self.engine.players[seat]
	local line = { from = 0, name = info.name, seat = seat, text = q.text, quick = q.id, voice = "auto", character = p and p.character }
	for _, h in self:audience() do
		Net.push(h, "chat.line", line)
	end
end

function Match:_sendEmote(seat: number, emoteId: string)
	if self.closed then
		return
	end
	local info = self.seats[seat]
	local voice = if info and info.player then DataService.voiceOf(info.player) else "auto"
	for _, p in self:audience() do
		Net.push(p, "match.emote", { id = self.id, seat = seat, emote = emoteId, voice = voice })
	end
end

function Match:command(player: Player, cmd)
	local seat = self.seatOf[player]
	if not seat then
		return false, "You're not in this match."
	end
	if self.phase ~= "playing" then
		return false, "The match isn't running."
	end
	if type(cmd) ~= "table" then
		return false, "Bad command."
	end
	self:_active(seat)
	local engine = self.engine
	if seat ~= engine.current then
		return false, "It's not your turn."
	end
	-- only pass through known fields
	local clean = {
		type = cmd.type,
		item = cmd.item,
		tile = cmd.tile,
		dir = cmd.dir,
		target = cmd.target,
		steps = cmd.steps,
		option = cmd.option,
		die = cmd.die,
		value = cmd.value,
		index = cmd.index,
	}
	local ok, err, events = engine:command(seat, clean)
	if not ok then
		return false, err
	end
	self:_broadcast(events)
	return true
end

-- Any input from a human (a command, or the screen telling us they tapped or clicked).
function Match:_active(seat: number)
	if self.clock:activity(seat, os.clock()) then
		-- they were away: hand their seat back before the bot moves again
		if self.engine.current == seat then
			self.botAt = nil
		end
		local info = self.seats[seat]
		if info.player then
			Net.push(info.player, "match.auto", { id = self.id, on = false })
			Net.push(info.player, "toast", { text = "Welcome back! You're in control again.", kind = "info" })
		end
	end
end

-- The screen reports that the player is there (they tapped, clicked or pressed a key).
function Match:active(player: Player)
	local seat = self.seatOf[player]
	if seat and self.phase == "playing" then
		self:_active(seat)
	end
	return true
end

function Match:emote(player: Player, emoteId: any)
	local seat = self.seatOf[player]
	if not seat or type(emoteId) ~= "string" then
		return false, "Can't emote right now."
	end
	local data = DataService.get(player)
	if not data or not table.find(data.equipped.emotes, emoteId) then
		return false, "Equip that emote first."
	end
	local now = os.clock()
	if now - (self.lastEmote[seat] or 0) < 2 then
		return false, "Easy there!"
	end
	self.lastEmote[seat] = now
	self:_sendEmote(seat, emoteId)
	return true
end

function Match:_botStep(seat: number)
	local engine = self.engine
	self.botSteps += 1
	local ok, err, events
	-- the guided match's bots are gentle: no cards, no abilities, just a move
	if self.botSteps <= 15 and not (self.tutorial and self.seats[seat].player == nil) then
		local cmd = Bot.decide(engine, seat)
		if cmd then
			ok, err, events = engine:command(seat, cmd)
		end
	end
	if not ok then
		ok, err, events = engine:autoAct()
	end
	if ok then
		self:_broadcast(events)
	else
		warn("[Trapisque] bot stuck: " .. tostring(err))
	end
end

-- Time's up: the turn is played for them (a roll, or leaving the shop).
function Match:_timeout(seat: number)
	local info = self.seats[seat]
	if self.clock:expire() and info.player then
		-- the batch below carries auto = true, which shows the "take over" bar
		Net.push(info.player, "toast", { text = "You seem to be away, so a bot is playing your turns. Tap anywhere to take over.", kind = "info" })
	end
	local ok, _, events = self.engine:autoAct()
	if ok then
		self:_broadcast(events)
	end
end

function Match:_loop()
	local engine = self.engine
	while not self.closed and not engine:isOver() do
		task.wait(0.1)
		local now = os.clock()
		if now >= self.busyUntil then
			local seat = engine.current
			local info = self.seats[seat]
			if info and info.isBot then
				if not self.botAt then
					self.botAt = now + T.BotThinkMin + random:NextNumber() * (T.BotThinkMax - T.BotThinkMin)
				end
				if now >= self.botAt then
					self.botAt = nil
					self:_botStep(seat)
				end
			elseif info and self.clock:isAway(seat) then
				-- a bot plays for them, after a few seconds in which they can take over
				if not self.botAt then
					self.botAt = math.max(now + T.BotThinkMin, self.clock:botMayActAt())
				end
				if now >= self.botAt then
					self.botAt = nil
					self:_botStep(seat)
				end
			elseif self.clock:expired(now) then
				self:_timeout(seat)
			end
		end
	end
end

---------------------------------------------------------------------------
-- drop-in: a Quick Play searcher takes over a bot
---------------------------------------------------------------------------

-- The bot seat a newcomer would take (the one furthest along), or nil when this match
-- can't take anyone: only public free-for-alls, early on, before any treasure.
function Match:dropInSeat(): number?
	if self.closed or self.finished or self.kind ~= "public" or self.mode.isTeam or self.tutorial then
		return nil
	end
	local engine = self.engine
	if not engine or self.phase ~= "playing" or engine:isOver() or engine.round > Config.Matchmaking.DropInRounds then
		return nil
	end
	local best, bestProgress = nil, -math.huge
	for seat, info in self.seats do
		local p = engine.players[seat]
		if p.treasures > 0 then
			return nil
		end
		if info.isBot and info.player == nil and not info.left then
			local pr = engine:progress(p)
			if pr > bestProgress then
				best, bestProgress = seat, pr
			end
		end
	end
	return best
end

function Match:dropIn(player: Player): (boolean, string?)
	local seat = self:dropInSeat()
	if not seat then
		return false, "That match is full or nearly over."
	end
	local info = self.seats[seat]
	local was = info.name
	info.player = player
	info.userId = player.UserId
	info.name = player.DisplayName
	info.username = player.Name
	info.isBot = false
	info.look = DataService.publicLook(player)
	self.seatOf[player] = seat
	self.feats[seat] = {}
	self.clock:activity(seat, os.clock())
	local events = self.engine:takeSeat(seat, { id = "u" .. player.UserId, userId = player.UserId, name = player.DisplayName })
	info.look.base = DataService.baseFor(player, self.engine.players[seat].character)
	-- the newcomer gets the whole board first, then everyone sees them arrive
	local payload = self:resync(player)
	if payload then
		payload.droppedIn = { from = was, character = self.engine.players[seat].character }
		Net.push(player, "match.start", payload)
	end
	self:_broadcast(events)
	return true
end

---------------------------------------------------------------------------
-- spectators
---------------------------------------------------------------------------

function Match:addSpectator(player: Player): boolean
	if self.closed or self.finished or self.seatOf[player] then
		return false
	end
	self.spectators[player] = true
	if self.phase == "vote" then
		local data = self:_votePayload()
		data.seat = 0
		Net.push(player, "match.vote", data)
	else
		local payload = self:resync(player)
		if payload then
			Net.push(player, "match.start", payload)
		end
	end
	return true
end

function Match:removeSpectator(player: Player)
	self.spectators[player] = nil
end

function Match:isSpectator(player: Player): boolean
	return self.spectators[player] == true
end

---------------------------------------------------------------------------
-- fishing between turns
---------------------------------------------------------------------------

function Match:_stopFishing(seat: number?)
	local f = seat and self.fishing[seat]
	if f and f.state ~= "idle" then
		f.state = "idle"
		f.token = nil
		local info = self.seats[seat :: number]
		if info and info.player then
			Net.push(info.player, "fish.state", { state = "idle", reason = "turn" })
		end
	end
end

-- action: "cast" | "reel". The fish is chosen when the line goes in (its shadow shows
-- under the bobber); it nibbles a time or two, then bites. Reel within its window.
function Match:fish(player: Player, action: any)
	local seat = self.seatOf[player]
	if not seat or self.phase ~= "playing" or self.engine:isOver() then
		return false, "No fishing right now."
	end
	if seat == self.engine.current then
		return false, "It's your turn!"
	end
	local f = self.fishing[seat]
	if not f then
		f = { state = "idle" }
		self.fishing[seat] = f
	end
	local now = os.clock()
	if action == "cast" then
		if f.state ~= "idle" then
			return false, "Your line is already in the water."
		end
		local token = {}
		f.state = "cast"
		f.token = token
		-- what's down there, this map's waters (at most one coin a round)
		f.catch = Fishing.roll(self.engine.map.id, random:NextNumber(), random:NextNumber(), f.coinRound ~= self.engine.round)
		local wait = Fishing.BiteMin + random:NextNumber() * (Fishing.BiteMax - Fishing.BiteMin)
		-- a nibble or two first: pulling on one scares it off
		local nibbles = random:NextInteger(Fishing.Nibbles[1], Fishing.Nibbles[2])
		for i = 1, nibbles do
			local at = wait * i / (nibbles + 1) + (random:NextNumber() - 0.5) * 0.5
			task.delay(at, function()
				if f.token == token and f.state == "cast" and not self.closed then
					Net.push(player, "fish.state", { state = "nibble" })
				end
			end)
		end
		local window = Fishing.window(f.catch)
		task.delay(wait, function()
			if f.token == token and f.state == "cast" and not self.closed then
				f.state = "bite"
				f.biteAt = os.clock()
				Net.push(player, "fish.state", { state = "bite", window = window })
				task.delay(window + Fishing.Grace + 0.2, function()
					if f.token == token and f.state == "bite" then
						f.state = "idle"
						f.token = nil
						Net.push(player, "fish.state", { state = "idle", reason = "late" })
					end
				end)
			end
		end)
		return true, { state = "cast", shadow = Fishing.shadow(f.catch) }
	elseif action == "reel" then
		if f.state == "cast" then
			-- too soon: it was only nibbling, and now it's gone
			f.state = "idle"
			f.token = nil
			return true, { state = "idle", result = "early" }
		elseif f.state ~= "bite" then
			return true, { state = "idle", result = "nothing" }
		end
		f.state = "idle"
		f.token = nil
		local catch = f.catch or "sardine"
		if now - (f.biteAt or 0) > Fishing.window(catch) + Fishing.Grace then
			return true, { state = "idle", result = "late" }
		end
		-- landed it
		local def = Fishing.byId[catch]
		if catch == "coin" then
			f.coinRound = self.engine.round
			local events = self.engine:grantCoins(seat, 1, "fishing")
			self:_broadcast(events)
		end
		local size = Fishing.sizeOf(catch, random:NextNumber())
		local logged, record = DataService.addCatch(player, catch, size)
		if def and def.rarity == "legendary" then
			BadgeService.award(player, "golden_fish")
		end
		-- the others see what you landed
		for _, p in self:audience() do
			if p ~= player then
				Net.push(p, "fish.caught", { seat = seat, catch = catch, size = size })
			end
		end
		return true, { state = "idle", result = "caught", catch = catch, size = size, new = logged == 1, record = record }
	end
	return false, "Cast or reel."
end

---------------------------------------------------------------------------
-- the end
---------------------------------------------------------------------------

function Match:_finish()
	if self.finished then
		return
	end
	self.finished = true
	self.phase = "results"
	local engine = self.engine
	local results = {}
	for seat, info in self.seats do
		local p = engine.players[seat]
		table.insert(results, {
			seat = seat,
			name = info.name,
			username = info.username,
			userId = info.userId,
			isBot = info.isBot,
			team = p.team,
			character = p.character,
			treasures = p.treasures,
			won = p.team == engine.winnerTeam,
			place = table.find(engine.ranking or {}, seat) or #self.seats,
			stats = table.clone(p.stats),
			look = info.look,
		})
	end
	-- winners with the Victory Parade pass get their parade, seen by everyone
	local parade = {}
	for seat, info in self.seats do
		local p = engine.players[seat]
		if info.player and p.team == engine.winnerTeam and DataService.hasPass(info.player, "VictoryParade") then
			table.insert(parade, seat)
		end
	end
	-- someone from the crew (the owner or an admin) played in this match
	local staffAboard = false
	for _, info in self.seats do
		if info.player and BadgeService.isStaff(info.player) then
			staffAboard = true
		end
	end
	local wait = math.max(0, self.busyUntil - os.clock())
	task.delay(wait, function()
		for seat, info in self.seats do
			local player = info.player
			if player and player.Parent == Players then
				local p = engine.players[seat]
				local won = p.team == engine.winnerTeam
				local reward = DataService.applyMatchResult(player, {
					treasures = p.treasures,
					won = won,
					practice = self.kind == "practice",
					ranked = self.kind == "public" and not self.mode.isTeam and not self.mode.isEvent,
					place = table.find(engine.ranking or {}, seat) or #self.seats,
					players = #self.seats,
					character = p.character,
					mode = self.mode.id,
					event = self.event,
					stats = table.clone(p.stats),
					tutorial = self.tutorial,
				})
				BadgeService.matchFeats(player, {
					won = won,
					stats = p.stats,
					feats = self.feats[seat] or {},
					tutorial = self.tutorial,
					staffAboard = staffAboard and not BadgeService.isStaff(player),
					partySize = self:_partySizeOf(player),
				})
				LeaderboardService.submit(player, DataService.get(player))
				Net.push(player, "match.end", {
					id = self.id,
					ranking = engine.ranking,
					winnerTeam = engine.winnerTeam,
					reason = engine.endReason,
					results = results,
					reward = reward,
					kind = self.kind,
					resultsTime = T.ResultsTime,
					parade = parade,
					tutorial = self.tutorial or nil,
				})
				DataService.pushProfile(player)
				task.spawn(DataService.save, player, false)
			end
		end
		for player in self.spectators do
			Net.push(player, "match.end", {
				id = self.id,
				ranking = engine.ranking,
				winnerTeam = engine.winnerTeam,
				reason = engine.endReason,
				results = results,
				kind = self.kind,
				resultsTime = T.ResultsTime,
				parade = parade,
				spectating = true,
			})
		end
		task.delay(T.ResultsTime, function()
			self:close("results")
		end)
	end)
end

-- How many of a player's party played this match with them (them included).
function Match:_partySizeOf(player: Player): number
	for _, party in self.parties do
		if table.find(party.members, player.UserId) then
			local n = 0
			for _, info in self.seats do
				if info.player and table.find(party.members, info.userId) then
					n += 1
				end
			end
			return n
		end
	end
	return 1
end

function Match:playerLeft(player: Player)
	self.spectators[player] = nil
	local seat = self.seatOf[player]
	if not seat then
		return
	end
	self.seatOf[player] = nil
	self:_stopFishing(seat)
	local info = self.seats[seat]
	info.player = nil
	-- (a seat someone left stays a bot: nobody drops into it)
	info.left = true
	if not self.finished then
		info.isBot = true
		info.name ..= " (bot)"
		if self.engine then
			self.engine.players[seat].isBot = true
			self.engine.players[seat].name = info.name
			if self.phase == "playing" then
				self:_broadcast({ { t = "left", p = seat, name = info.name } })
			end
		else
			self.enginePlayers[seat].isBot = true
			self.enginePlayers[seat].name = info.name
		end
	end
	if #self:humans() == 0 then
		self:close("empty")
	end
end

---------------------------------------------------------------------------
-- rematch: once everyone still at the table asks, the same table plays again
---------------------------------------------------------------------------

function Match:voteRematch(player: Player)
	if self.phase ~= "results" or self.closed then
		return false, "Too late for a rematch."
	end
	if self.tutorial then
		return false, "The guided match is a one-off. Find a match!"
	end
	if not self.seatOf[player] then
		return false, "Only the players can ask for a rematch."
	end
	self.rematch = self.rematch or {}
	self.rematch[player] = true
	local votes, needed = 0, 0
	for _, info in self.seats do
		if info.player and info.player.Parent == Players then
			needed += 1
			if self.rematch[info.player] then
				votes += 1
			end
		end
	end
	for _, info in self.seats do
		if info.player and info.player.Parent == Players then
			Net.push(info.player, "match.rematch", { id = self.id, votes = votes, needed = needed })
		end
	end
	if votes >= needed and self.hooks.rematch then
		task.defer(self.hooks.rematch, self)
	end
	return true, { votes = votes, needed = needed }
end

-- The same table again: the same people in the same teams, on the same map with the
-- same settings (a seat someone left goes to a bot).
function Match:rematchSpec()
	local humans, bots = {}, {}
	for _, info in self.seats do
		if info.player and info.player.Parent == Players then
			table.insert(humans, { player = info.player, team = info.team })
		else
			table.insert(bots, { team = info.team })
		end
	end
	return {
		kind = self.kind,
		mode = self.mode.id,
		map = self.mapId,
		length = self.length,
		parties = self.parties,
		event = self.event,
		rules = self.rules,
		twist = if self.rules and self.rules.twist == self.twist then nil else self.twist,
		humans = humans,
		bots = bots,
		teamsPreset = true,
	}
end

function Match:close(reason: string)
	if self.closed then
		return
	end
	self.closed = true
	self.phase = "closed"
	if self.hooks.closed then
		self.hooks.closed(self, reason)
	end
end

return Match
