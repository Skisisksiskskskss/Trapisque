--[[
	MatchService: queues, match lifecycle, message routing and rewards.

	  Solo / Bot Buddy / Couch modes  start instantly (still server-hosted so
	                                  scores, coins and leaderboards are real)
	  Duos                            pairs two players; a couch pair is already
	                                  a full duo; after 20 s a bot partner fills in
	  Versus                          up to 6 birds; after 12 s bots fill the lobby
	                                  to 4 so a quiet server still gets a match
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Modes = require(Shared.Config.Modes)
local Birds = require(Shared.Config.Birds)
local Cosmetics = require(Shared.Config.Cosmetics)
local EventMeta = require(Shared.Config.Events)
local Remotes = require(Shared.Net.Remotes)

local Match = require(script.Parent.Match)
local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local MatchService = {}

local net: RemoteEvent
local fast: UnreliableRemoteEvent

local matches: { [number]: any } = {}
local playerMatch: { [Player]: any } = {}
local queues: { [string]: { any } } = { DUOS = {}, VERSUS = {} }
local playerQueue: { [Player]: string } = {}
local nextMatchId = 1

local BOT_NAMES = {
	"Chirpy",
	"Beaky",
	"Sir Flaps",
	"Nugget",
	"Pip",
	"Wobble",
	"Doodle",
	"Squawkers",
	"Tweetle",
	"Mochi",
	"Biscuit",
	"Pebble",
	"Noodle",
	"Bubbles",
	"Kiwi",
	"Mango",
}

-- Messaging -------------------------------------------------------------------

function MatchService.sendTo(player: Player, msg: string, ...)
	net:FireClient(player, msg, ...)
end

function MatchService.sendFast(player: Player, matchId: number, tick: number, snap)
	fast:FireClient(player, matchId, tick, snap)
end

-- Loadouts ----------------------------------------------------------------------

local function ownedOr(data, category: string, id: string?, fallback: string): string
	if id and data.owned[category] and data.owned[category][id] then
		return id
	end
	return fallback
end

local function sanitizeLoadout(data, loadout, default)
	loadout = loadout or default
	return {
		bird = ownedOr(data, "bird", loadout.bird, Birds.DEFAULT),
		color = ownedOr(data, "color", loadout.color, default.color),
		pattern = ownedOr(data, "pattern", loadout.pattern, "solid"),
		patternColor = ownedOr(data, "color", loadout.patternColor, "#ffffff"),
		patternAlpha = math.clamp(tonumber(loadout.patternAlpha) or 0.6, 0, 1),
		hat = ownedOr(data, "hat", loadout.hat, "none"),
		death = ownedOr(data, "death", loadout.death, "splat"),
	}
end

local function loadoutsFor(player: Player)
	local data = DataService.get(player)
	if not data then
		return { Cosmetics.DefaultLoadout, Cosmetics.DefaultLoadout2 }
	end
	return {
		sanitizeLoadout(data, data.loadout, Cosmetics.DefaultLoadout),
		sanitizeLoadout(data, data.loadout2, Cosmetics.DefaultLoadout2),
	}
end

local botRng = Random.new()

local function botEntry(skill: number)
	local free = {}
	for _, item in Cosmetics.Colors do
		if item.price == 0 and not item.robuxOnly then
			table.insert(free, item.id)
		end
	end
	local hats = {}
	for _, item in Cosmetics.Hats do
		if not item.robuxOnly then
			table.insert(hats, item.id)
		end
	end
	local patterns = { "solid", "spots", "stripes", "stars", "dots", "hearts" }
	local kinds = {}
	for _, def in Birds.List do
		table.insert(kinds, def.id)
	end
	return {
		bot = true,
		skill = skill,
		name = BOT_NAMES[botRng:NextInteger(1, #BOT_NAMES)] .. " (bot)",
		loadouts = {
			{
				bird = kinds[botRng:NextInteger(1, #kinds)],
				color = free[botRng:NextInteger(1, #free)],
				pattern = patterns[botRng:NextInteger(1, #patterns)],
				patternColor = "#ffffff",
				patternAlpha = 0.5,
				hat = hats[botRng:NextInteger(1, #hats)],
				death = "splat",
			},
		},
	}
end

-- Matches -------------------------------------------------------------------------

local function startMatch(modeId: string, entries, opts)
	local id = nextMatchId
	nextMatchId += 1
	local match = Match.new(MatchService, id, modeId, entries, opts)
	matches[id] = match
	for _, e in entries do
		if e.player then
			playerMatch[e.player] = match
			playerQueue[e.player] = nil
		end
	end
	match:start()
	return match
end

local function removeFromQueue(player: Player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end
	local q = queues[modeId]
	for i = #q, 1, -1 do
		if q[i].player == player then
			table.remove(q, i)
		end
	end
	playerQueue[player] = nil
	MatchService.sendTo(player, "QueueStatus", nil)
end

function MatchService.join(player: Player, modeId: string, opts)
	opts = type(opts) == "table" and opts or {}
	local mode = Modes[modeId]
	if not mode or playerMatch[player] then
		return
	end
	removeFromQueue(player)
	local couch = mode.couch or (opts.couch == true and mode.online)
	local entry = {
		player = player,
		couch = couch,
		since = os.clock(),
		loadouts = loadoutsFor(player),
	}

	if not mode.online then
		local labEvent = nil
		if modeId == "SOLO" and type(opts.labEvent) == "string" and EventMeta.ByName[opts.labEvent] then
			local data = DataService.get(player)
			if data and data.discovered[opts.labEvent] then
				labEvent = opts.labEvent
			end
		end
		local entries = { entry }
		if modeId == "BOT" then
			-- the bot is the top (upside-down) bird, like the original
			local bot = botEntry(0.9)
			bot.name = "Bot Buddy"
			table.insert(entries, 1, bot)
			-- player keeps their P1 look on the bottom bird
		end
		startMatch(modeId, entries, { labEvent = labEvent })
		return
	end

	if modeId == "DUOS" and couch then
		startMatch("DUOS", { entry }, {})
		return
	end

	table.insert(queues[modeId], entry)
	playerQueue[player] = modeId
	MatchService.sendTo(player, "QueueStatus", { mode = modeId, since = os.time() })
end

function MatchService.leave(player: Player)
	removeFromQueue(player)
	local match = playerMatch[player]
	if match then
		match:removePlayer(player)
		playerMatch[player] = nil
	end
end

local function processQueues()
	-- Duos: pair the two oldest solo entries; lonely players get a bot partner
	local dq = queues.DUOS
	while #dq >= 2 do
		local a = table.remove(dq, 1)
		local b = table.remove(dq, 1)
		startMatch("DUOS", { a, b }, {})
	end
	if #dq == 1 and os.clock() - dq[1].since >= GameConfig.DUO_QUEUE_SECONDS then
		local a = table.remove(dq, 1)
		local bot = botEntry(0.85)
		startMatch("DUOS", { a, bot }, {})
	end

	-- Versus
	local vq = queues.VERSUS
	if #vq > 0 then
		local function birdsOf(e)
			return if e.couch then 2 else 1
		end
		local total = 0
		for _, e in vq do
			total += birdsOf(e)
		end
		local waited = os.clock() - vq[1].since
		if total >= GameConfig.VERSUS_MAX_BIRDS or waited >= GameConfig.QUEUE_FILL_SECONDS then
			local entries, count = {}, 0
			local i = 1
			while i <= #vq do
				local e = vq[i]
				if count + birdsOf(e) <= GameConfig.VERSUS_MAX_BIRDS then
					table.insert(entries, e)
					count += birdsOf(e)
					table.remove(vq, i)
				else
					i += 1
				end
			end
			while count < GameConfig.VERSUS_MIN_BIRDS do
				table.insert(entries, botEntry(botRng:NextNumber(0.55, 0.85)))
				count += 1
			end
			startMatch("VERSUS", entries, {})
		else
			for _, e in vq do
				MatchService.sendTo(e.player, "QueueStatus", {
					mode = "VERSUS",
					birds = total,
					fillIn = math.max(0, math.ceil(GameConfig.QUEUE_FILL_SECONDS - waited)),
				})
			end
		end
	end
end

-- Hooks used by Match -----------------------------------------------------------------

function MatchService.recordDeath(player: Player)
	DataService.update(player, function(d)
		d.stats.deaths += 1
	end)
end

function MatchService.consumeReviveToken(player: Player): boolean
	local data = DataService.get(player)
	if not data or (data.reviveTokens or 0) <= 0 then
		return false
	end
	DataService.update(player, function(d)
		d.reviveTokens -= 1
	end)
	return true
end

-- Called by ProductService after a Revive purchase (the purchase granted a
-- revive token; using it here consumes that token)
function MatchService.reviveFromPurchase(player: Player): boolean
	local match = playerMatch[player]
	if match and match.state == "reviveOffer" then
		return match:tryRevive(player, false)
	end
	return false
end

function MatchService.discoverEvent(player: Player, name: string)
	local data = DataService.get(player)
	if not data or data.discovered[name] then
		return
	end
	DataService.update(player, function(d)
		d.discovered[name] = true
		d.coins += GameConfig.COINS_EVENT_DISCOVERY
	end)
	MatchService.sendTo(player, "Discovered", name, GameConfig.COINS_EVENT_DISCOVERY)
end

function MatchService.onMatchFinished(match, results)
	matches[match.id] = nil
	if not results then
		for player in match.players do
			playerMatch[player] = nil
		end
		return
	end

	local mode = match.mode
	local placements = results.placements
	for player, info in match.players do
		playerMatch[player] = nil
		if not player.Parent then
			continue
		end
		local personalStrums = 0
		local team = nil
		for _, slot in info.slots do
			local b = match.world.birds[slot]
			if b then
				personalStrums += b.strums
				team = b.team
			end
		end

		local coins = match.coins[player] or 0
		local placement = nil
		if mode.versus and team then
			placement = table.find(placements, team)
			if placement then
				coins += GameConfig.VERSUS_PLACEMENT_COINS[placement] or 0
			end
		end
		local xp = personalStrums * GameConfig.XP_PER_STRUM
		if placement == 1 then
			xp += 40
		end

		local summary = {
			mode = mode.id,
			score = results.score,
			placement = placement,
			coins = 0,
			xp = 0,
			newBest = false,
			practice = results.practice,
			birds = results.birds,
			placements = placements,
		}

		if not results.practice then
			summary.coins = coins
			summary.xp = xp
			local levelsBefore = DataService.get(player) and DataService.levelFor(DataService.get(player).xp) or 1
			DataService.update(player, function(d)
				d.coins += coins
				d.stats.games += 1
				d.stats.strums += personalStrums
				if mode.id == "SOLO" and results.score > d.stats.soloBest then
					d.stats.soloBest = results.score
					summary.newBest = true
				elseif (mode.id == "DUOS" or mode.id == "COUCH_COOP") and results.score > d.stats.duoBest then
					d.stats.duoBest = results.score
					summary.newBest = true
				end
				if mode.id == "VERSUS" then
					d.stats.versusGames += 1
					if placement == 1 and #placements > 1 then
						d.stats.versusWins += 1
					end
				end
			end)
			DataService.addXp(player, xp)
			local data = DataService.get(player)
			if data then
				summary.level = DataService.levelFor(data.xp)
				summary.levelUp = summary.level > levelsBefore
				if mode.leaderboard == "SoloBest" then
					LeaderboardService.submit("SoloBest", player, data.stats.soloBest)
				elseif mode.leaderboard == "DuoBest" then
					LeaderboardService.submit("DuoBest", player, data.stats.duoBest)
				elseif mode.leaderboard == "VersusWins" then
					LeaderboardService.submit("VersusWins", player, data.stats.versusWins)
				end
			end
		end
		MatchService.sendTo(player, "MatchEnd", match.id, summary)
	end
end

-- Client message routing ---------------------------------------------------------------

local MATCH_MESSAGES = {
	Strum = true,
	Hit = true,
	Ability = true,
	Entity = true,
	SpikeBreak = true,
	Revive = true,
}

local function onNet(player: Player, msg: any, ...)
	if type(msg) ~= "string" then
		return
	end
	if msg == "Queue" then
		local modeId, opts = ...
		if type(modeId) == "string" then
			MatchService.join(player, modeId, opts)
		end
	elseif msg == "Leave" then
		MatchService.leave(player)
	elseif MATCH_MESSAGES[msg] then
		local matchId = ...
		local match = playerMatch[player]
		if match and match.id == matchId then
			match:onClientMessage(player, msg, select(2, ...))
		end
	end
end

local function onFast(player: Player, matchId: any, tick: any, states: any)
	local match = playerMatch[player]
	if not match or match.id ~= matchId or type(tick) ~= "number" or type(states) ~= "table" then
		return
	end
	for _, st in states do
		if type(st) == "table" and type(st[1]) == "number" then
			local slot = st[1]
			local data = table.move(st, 2, #st, 1, {})
			match:onClientState(player, tick, slot, data)
		end
	end
end

function MatchService.matchOf(player: Player)
	return playerMatch[player]
end

function MatchService.init()
	net = Remotes.net()
	fast = Remotes.fast()
	net.OnServerEvent:Connect(onNet)
	fast.OnServerEvent:Connect(onFast)

	Players.PlayerRemoving:Connect(function(player)
		MatchService.leave(player)
	end)

	local queueAccum = 0
	RunService.Heartbeat:Connect(function(dt)
		for _, match in matches do
			local ok, err = pcall(match.update, match)
			if not ok then
				warn("[Match " .. match.id .. "] " .. tostring(err))
				match.state = "ended"
				matches[match.id] = nil
				for player in match.players do
					playerMatch[player] = nil
					MatchService.sendTo(
						player,
						"MatchEnd",
						match.id,
						{ error = true, mode = match.mode.id, score = match.world.score }
					)
				end
			end
		end
		queueAccum += dt
		if queueAccum >= 0.5 then
			queueAccum = 0
			processQueues()
		end
	end)
end

return MatchService
