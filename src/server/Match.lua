--[[
	Match
	Runs one Trapisque game on the server: wraps the rules Engine, drives bots, turn
	timers and away players (Shared/Game/TurnClock), and streams events + snapshots to
	every player. Each batch says when it starts and ends on the server's clock, so a
	screen that falls behind (lag, a slow device) speeds up instead of drifting.
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
local Pacing = require(Shared.Game.Pacing)
local TurnClock = require(Shared.Game.TurnClock)
local Cosmetics = require(Shared.Meta.Cosmetics)
local Progress = require(Shared.Meta.Progress)
local QuickChat = require(Shared.Meta.QuickChat)

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)

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
	emote_oops = { "oops", "nofair", "close" },
	emote_nice = { "gotcha", "yoho", "arr" },
	emote_gg = { "gg", "wp" },
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
		-- about half the bots dress up
		accessory = if random:NextNumber() < 0.5 then pick("accessory", "rare") else Cosmetics.defaults.accessory,
		dice = pick("dice", "rare"),
		trail = pick("trail", "rare"),
		title = "title_none",
		level = random:NextInteger(1, 12),
		vip = false,
	}
end

--[[
	spec = {
		mode, map ("random" ok), length, kind ("public" | "private" | "practice"),
		humans = { { player = Player, team = number? } },
		bots = { { team = number? } },
		teamsPreset = boolean, -- teams given for every seat
		parties = { { leader, members, settings } }, -- restored after reserved matches
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
	self.length = spec.length or "quick"
	self.parties = spec.parties or {}
	self.closed = false
	self.finished = false
	self.phase = "intro"

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
	end

	-- the weekly event queue plays with the week's twist on the rules
	local mutator = nil
	if mode.isEvent then
		local event = Progress.eventById(spec.event) or Progress.currentEvent()
		self.event = event.id
		mutator = event.mutator
	end

	self.engine = Engine.new({
		mode = mode.id,
		map = mapId,
		players = enginePlayers,
		seed = random:NextInteger(1, 2 ^ 30),
		target = Modes.targetFor(mode, self.length),
		length = self.length,
		teamsPreset = spec.teamsPreset == true,
		mutator = mutator,
	})
	-- practice games have no turn timer (nobody is waiting on you)
	self.clock = TurnClock.new({ timed = self.kind ~= "practice" })
	self.lastEmote = {}
	self.busyUntil = 0
	self.lastTurn = -1
	self.lastPhase = ""
	self.botAt = nil
	self.botSteps = 0
	return self
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

function Match:seatList()
	local list = {}
	for seat, info in self.seats do
		local p = self.engine.players[seat]
		table.insert(list, {
			seat = seat,
			name = info.name,
			username = info.username,
			userId = info.userId,
			isBot = info.isBot,
			team = p.team,
			character = p.character,
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
function Match:_payloadFor(seat: number, events, timing)
	return {
		id = self.id,
		events = self.engine:eventsFor(seat, events),
		snapshot = self.engine:snapshot(seat),
		deadline = serverTime(self.clock.deadline),
		auto = self.clock:isAway(seat),
		startAt = timing and timing.startAt,
		endAt = timing and timing.endAt,
	}
end

function Match:start()
	local events = self.engine:start()
	self.phase = "playing"
	local now = os.clock()
	local engine = self.engine
	self.busyUntil = now + T.IntroTime + Pacing.total(events)
	self.lastTurn = engine.turnCount
	self.lastPhase = engine.phase
	self.clock:begin(engine.current, engine.phase, self.busyUntil, engine.turnCount)
	local timing = { startAt = serverTime(now + T.IntroTime), endAt = serverTime(self.busyUntil) }
	local seats = self:seatList()
	for seat, info in self.seats do
		if info.player then
			local payload = self:_payloadFor(seat, events, timing)
			payload.seat = seat
			payload.kind = self.kind
			payload.mode = self.mode.id
			payload.map = self.mapId
			payload.length = self.length
			payload.target = self.engine.target
			payload.seats = seats
			payload.intro = T.IntroTime
			Net.push(info.player, "match.start", payload)
		end
	end
	task.spawn(function()
		self:_loop()
	end)
end

-- Full state for a client that needs to resync.
function Match:resync(player: Player)
	local seat = self.seatOf[player]
	if not seat then
		return nil
	end
	local payload = self:_payloadFor(seat, {})
	payload.seat = seat
	payload.kind = self.kind
	payload.mode = self.mode.id
	payload.map = self.mapId
	payload.length = self.length
	payload.target = self.engine.target
	payload.seats = self:seatList()
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
	else
		self.clock:extend(self.busyUntil)
	end
	local timing = { startAt = serverTime(startsAt), endAt = serverTime(self.busyUntil) }
	for seat, info in self.seats do
		if info.player and info.player.Parent == Players then
			Net.push(info.player, "match.events", self:_payloadFor(seat, events, timing))
		end
	end
	self:_botReactions(events)
	if engine:isOver() then
		self:_finish()
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
							self:_botSay(s, if random:NextNumber() < 0.5 then "gg" else "wp")
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
	if self.closed or not q or not info then
		return
	end
	local p = self.engine.players[seat]
	local line = { from = 0, name = info.name, seat = seat, text = q.text, quick = q.id, voice = "auto", character = p and p.character }
	for _, h in self:humans() do
		Net.push(h, "chat.line", line)
	end
end

function Match:_sendEmote(seat: number, emoteId: string)
	if self.closed then
		return
	end
	local info = self.seats[seat]
	local voice = if info and info.player then DataService.voiceOf(info.player) else "auto"
	for _, p in self:humans() do
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
	if self.botSteps <= 15 then
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
	local wait = math.max(0, self.busyUntil - os.clock())
	task.delay(wait, function()
		for seat, info in self.seats do
			local player = info.player
			if player and player.Parent == Players then
				local p = engine.players[seat]
				local reward = DataService.applyMatchResult(player, {
					treasures = p.treasures,
					won = p.team == engine.winnerTeam,
					practice = self.kind == "practice",
					ranked = self.kind == "public" and not self.mode.isTeam and not self.mode.isEvent,
					place = table.find(engine.ranking or {}, seat) or #self.seats,
					players = #self.seats,
					character = p.character,
					mode = self.mode.id,
					event = self.event,
					stats = table.clone(p.stats),
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
				})
				DataService.pushProfile(player)
				task.spawn(DataService.save, player, false)
			end
		end
		task.delay(T.ResultsTime, function()
			self:close("results")
		end)
	end)
end

function Match:playerLeft(player: Player)
	local seat = self.seatOf[player]
	if not seat then
		return
	end
	self.seatOf[player] = nil
	local info = self.seats[seat]
	info.player = nil
	if not self.finished then
		info.isBot = true
		info.name ..= " (bot)"
		self.engine.players[seat].isBot = true
		self.engine.players[seat].name = info.name
		self:_broadcast({ { t = "left", p = seat, name = info.name } })
	end
	if #self:humans() == 0 then
		self:close("empty")
	end
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
