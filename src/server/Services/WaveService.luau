--!strict
-- The heart of the game. Every WaveInterval seconds one brainrot per player bursts out of the central portal and
-- marches to its owner's door. CHARGE taps add crystal power; the showdown decides Captured / DoorHeld /
-- DoorBroken. Brainrots that beat a crystal escape and run a lap of the ring road, where any strong enough crystal
-- can beam them. All timing uses server time so clients can animate the exact same motion locally.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Config.Brainrots)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local BrainrotStats = require(Shared.Modules.BrainrotStats)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)
local WaveRoll = require(Shared.Modules.WaveRoll)
local PlayerStats = require(script.Parent.Parent.Modules.PlayerStats)
local ServerState = require(script.Parent.Parent.Modules.ServerState)
local BrainrotService = require(script.Parent.BrainrotService)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local PlotService = require(script.Parent.PlotService)

export type Entry = {
	Id: number,
	Plot: number,
	UserId: number,
	Roll: WaveRoll.Roll,
	Start: number,
	Arrive: number,
	Resolve: number,
	Resolved: boolean,
}

local WaveService = {}

WaveService.Resolved = Signal.new() :: Signal.Signal<Player, string, Entry>

local random = Random.new()
local rng: WaveRoll.Rng = {
	NextNumber = function(_self: WaveRoll.Rng): number
		return random:NextNumber()
	end,
}
local nextEntryId = 0
local nextEscapeId = 0
local pending: { [Player]: { Entry } } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rarityName(roll: WaveRoll.Roll): string
	return Rarities.Get(roll.Rarity).Name
end

local function announce(text: string, color: Color3?)
	Net.Event("Announce"):FireAllClients(text, color or Color3.fromRGB(255, 220, 90))
end
WaveService.Announce = announce

local function walkTime(plotIndex: number, size: string): number
	local distance = (MapService.StopPosition(plotIndex) - MapService.PortalEdge(plotIndex)).Magnitude
	local speed = GameConfig.WalkSpeed / (Sizes.Get(size).Scale ^ 0.35)
	return distance / speed
end

local function serialize(entry: Entry): { [string]: any }
	return {
		Id = entry.Id,
		Plot = entry.Plot,
		UserId = entry.UserId,
		BrainrotId = entry.Roll.Id,
		Mutation = entry.Roll.Mutation,
		Size = entry.Roll.Size,
		Power = entry.Roll.Power,
		Boss = entry.Roll.Boss,
		Guaranteed = entry.Roll.Guaranteed,
		Start = entry.Start,
		Arrive = entry.Arrive,
		Resolve = entry.Resolve,
	}
end

local function rollParams(player: Player): WaveRoll.RollParams?
	local data = DataService.Get(player)
	local session = DataService.GetSession(player)
	if not data or not session then
		return nil
	end
	local params: WaveRoll.RollParams = {
		Tier = data.Tier,
		Rebirths = data.Rebirths,
		Luck = PlayerStats.Luck(session.Passes),
		MutationMult = PlayerStats.MutationMultipliers(session.Passes),
		ForcedMutation = nil,
	}
	if session.GoldenPending then
		params.ForcedMutation = "Gold"
		session.GoldenPending = false
	end
	return params
end

local function makeEntry(player: Player, plotIndex: number, roll: WaveRoll.Roll, startAt: number): Entry
	nextEntryId += 1
	local start = startAt
	local arrive = start + GameConfig.EmergeTime + walkTime(plotIndex, roll.Size)
	return {
		Id = nextEntryId,
		Plot = plotIndex,
		UserId = player.UserId,
		Roll = roll,
		Start = start,
		Arrive = arrive,
		Resolve = arrive + GameConfig.ShowdownTime,
		Resolved = false,
	}
end

local function hasPending(player: Player): boolean
	local list = pending[player]
	if not list then
		return false
	end
	for _, entry in list do
		if not entry.Resolved then
			return true
		end
	end
	return false
end
WaveService.HasPending = hasPending

-- Returns the remaining unresolved entries for a player, clearing finished ones.
local function prune(player: Player)
	local list = pending[player]
	if not list then
		return
	end
	local keep = {}
	for _, entry in list do
		if not entry.Resolved then
			table.insert(keep, entry)
		end
	end
	pending[player] = keep
end

local resolveEntry: (Entry) -> ()

local function schedule(player: Player, entries: { Entry })
	local list = pending[player]
	if not list then
		list = {}
		pending[player] = list
	end
	for _, entry in entries do
		table.insert(list, entry)
		task.delay(math.max(0, entry.Resolve - now()), resolveEntry, entry)
	end
end

local function rollsFor(player: Player, stampede: boolean, tutorial: boolean): { WaveRoll.Roll }
	local data = DataService.Get(player)
	local session = DataService.GetSession(player)
	local params = rollParams(player)
	if not data or not session or not params then
		return {}
	end
	if tutorial then
		return { WaveRoll.Tutorial() }
	end
	session.WaveCount += 1
	local rolls = {}
	local crystal = PlayerStats.CrystalPower(data, session.Passes)
	local isBoss = stampede or (session.WaveCount % GameConfig.BossEvery == 0)
	if session.LuckyPending then
		session.LuckyPending = false
		table.insert(rolls, WaveRoll.RollLucky(rng, params))
	elseif isBoss then
		local minMult = if stampede then 1.3 else GameConfig.BossPowerMin
		local maxMult = if stampede then 2.6 else GameConfig.BossPowerMax
		table.insert(rolls, WaveRoll.RollBoss(rng, params, crystal, minMult, maxMult))
	else
		table.insert(rolls, WaveRoll.RollNormal(rng, params))
	end
	if session.Passes.DoubleWave then
		params.ForcedMutation = nil
		table.insert(rolls, WaveRoll.RollNormal(rng, params))
	end
	return rolls
end

-- Launches a wave for the given players (all players for a global wave, one for a personal wave).
local function launch(targets: { Player }, stampede: boolean, tutorialFor: Player?)
	local serialized = {}
	local startAt = now() + 0.6
	for _, player in targets do
		local plot = PlotService.ForPlayer(player)
		if not plot or not plot.Parts or hasPending(player) then
			continue
		end
		local rolls = rollsFor(player, stampede, player == tutorialFor)
		local entries = {}
		for lane, roll in rolls do
			local entry = makeEntry(player, plot.Index, roll, startAt + (lane - 1) * 1.8)
			table.insert(entries, entry)
			table.insert(serialized, serialize(entry))
		end
		local session = DataService.GetSession(player)
		if session then
			session.Charge = 0
		end
		schedule(player, entries)
	end
	if #serialized > 0 then
		Net.Event("WaveStart"):FireAllClients(serialized, stampede)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Escapes
---------------------------------------------------------------------------------------------------------------

local function canHold(player: Player): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	return BrainrotService.FirstFreeSlot(data) ~= nil or BrainrotService.StorageCount(data) < GameConfig.StorageMax
end

local function startEscape(roll: WaveRoll.Roll, fromPlot: number, fromUserId: number, startAt: number)
	nextEscapeId += 1
	local escapeId = nextEscapeId
	local startAngle = MapService.PlotAngle(fromPlot)
	local dir = if random:NextNumber() < 0.5 then 1 else -1
	local radius = GameConfig.RingRoadRadius
	local speed = GameConfig.EscapeSpeed
	local lapTime = 2 * math.pi * radius / speed * GameConfig.EscapeLaps
	Net.Event("EscapeStart"):FireAllClients({
		Id = escapeId,
		BrainrotId = roll.Id,
		Mutation = roll.Mutation,
		Size = roll.Size,
		Power = roll.Power,
		FromPlot = fromPlot,
		Angle = startAngle,
		Dir = dir,
		Start = startAt,
		Speed = speed,
		Radius = radius,
		LapTime = lapTime,
	})

	local finished = false
	local stepAngle = 2 * math.pi / GameConfig.MaxPlots
	for step = 1, GameConfig.MaxPlots * GameConfig.EscapeLaps do
		local plotIndex = ((fromPlot - 1 + dir * step) % GameConfig.MaxPlots) + 1
		local passTime = startAt + step * stepAngle * radius / speed
		task.delay(math.max(0, passTime - now()), function()
			if finished or plotIndex == fromPlot then
				return
			end
			local plot = PlotService.Get(plotIndex)
			local owner = plot and plot.Owner
			if not plot or not owner or owner.UserId == fromUserId then
				return
			end
			local data = DataService.Get(owner)
			local session = DataService.GetSession(owner)
			if not data or not session or not canHold(owner) then
				return
			end
			local power = PlayerStats.CrystalPower(data, session.Passes)
			if power < roll.Power then
				return
			end
			finished = true
			Net.Event("EscapeEnd"):FireAllClients(escapeId, plotIndex, now())
			task.delay(1.1, function()
				if owner.Parent then
					BrainrotService.Add(owner, roll.Id, roll.Mutation, roll.Size, "Escape")
					DataService.AddStat(owner, "Captures", 1)
				end
			end)
			local def = Brainrots.ById[roll.Id]
			BrainrotService.Notify(owner, string.format("Your crystal beamed an escaped %s!", def.Name), "good")
			if roll.Rarity >= 4 then
				announce(
					string.format(
						"%s's crystal snatched an escaped %s %s!",
						owner.DisplayName,
						string.upper(rarityName(roll)),
						def.Name
					),
					Rarities.Get(roll.Rarity).Color
				)
			end
		end)
	end
	task.delay(math.max(0, startAt + lapTime - now()), function()
		if not finished then
			finished = true
			Net.Event("EscapeEnd"):FireAllClients(escapeId, 0, now())
		end
	end)
end

---------------------------------------------------------------------------------------------------------------
-- Showdown
---------------------------------------------------------------------------------------------------------------

resolveEntry = function(entry: Entry)
	if entry.Resolved then
		return
	end
	entry.Resolved = true
	local player = Players:GetPlayerByUserId(entry.UserId)
	local plot = PlotService.Get(entry.Plot)
	if not player or not plot or plot.Owner ~= player then
		return
	end
	local data = DataService.Get(player)
	local session = DataService.GetSession(player)
	if not data or not session then
		return
	end
	local roll = entry.Roll
	local def = Brainrots.ById[roll.Id]
	local overcharge = if session.Overcharge then 0.5 else 0
	local crystal = PlayerStats.CrystalPower(data, session.Passes) * (1 + session.Charge + overcharge)
	local outcome: string
	if roll.Guaranteed or roll.Power <= crystal then
		outcome = "Captured"
		task.delay(1.0, function()
			if player.Parent then
				BrainrotService.Add(player, roll.Id, roll.Mutation, roll.Size, if roll.Boss then "Boss" else "Wave")
			end
		end)
		DataService.AddStat(player, "Captures", 1)
		if roll.Boss then
			DataService.AddStat(player, "Bosses", 1)
		end
		local rarity = Rarities.Get(roll.Rarity)
		local mutation = Mutations.Get(roll.Mutation)
		if rarity.Announce or mutation.Announce or roll.Size == "Giant" then
			announce(
				string.format(
					"%s beamed a %s %s!",
					player.DisplayName,
					string.upper(rarity.Name),
					BrainrotStats.DisplayName(roll.Id, roll.Mutation, roll.Size)
				),
				rarity.Color
			)
		end
	else
		local ironDoor = session.IronDoorUntil > os.time()
		local door = PlayerStats.DoorStrength(data, session.Passes)
		if ironDoor or door >= roll.Power then
			outcome = "DoorHeld"
			BrainrotService.Notify(
				player,
				if ironDoor
					then "Your Iron Door held! The brainrot ran off."
					else "Your door held! Upgrade your crystal to beam it next time.",
				"info"
			)
		else
			-- Short delay so the door vanishes exactly when the brainrot slams into it on every client.
			task.delay(0.4, function()
				if plot.Owner == player then
					PlotService.BreakDoor(plot, GameConfig.DoorBrokenTime)
				end
			end)
			DataService.AddStat(player, "DoorsBroken", 1)
			if PlotService.IsShielded(player) then
				outcome = "Shielded"
				BrainrotService.Notify(player, "Your door broke, but your Newbie Shield keeps thieves out!", "shield")
			else
				outcome = "DoorBroken"
				BrainrotService.Notify(
					player,
					"Your door is BROKEN! Hold REPAIR at the door before thieves get in!",
					"bad"
				)
				if roll.Rarity >= 4 or roll.Boss then
					announce(
						string.format("A %s smashed %s's door! RAID!", def.Name, player.DisplayName),
						Color3.fromRGB(255, 90, 90)
					)
				end
			end
		end
		startEscape(roll, entry.Plot, entry.UserId, now() + 1.3)
	end
	if overcharge > 0 then
		session.Overcharge = false
	end
	Net.Event("WaveResult"):FireAllClients({
		Id = entry.Id,
		Plot = entry.Plot,
		Outcome = outcome,
		Crystal = crystal,
		Power = roll.Power,
	})
	prune(player)
	if not hasPending(player) then
		session.Charge = 0
	end
	DataService.MarkDirty(player)
	WaveService.Resolved:Fire(player, outcome, entry)
end

---------------------------------------------------------------------------------------------------------------
-- Input + public API
---------------------------------------------------------------------------------------------------------------

local function onCharge(player: Player)
	local session = DataService.GetSession(player)
	local list = pending[player]
	if not session or not list then
		return
	end
	local t = now()
	local active = false
	for _, entry in list do
		if not entry.Resolved and t >= entry.Start and t <= entry.Resolve - 0.1 then
			active = true
			break
		end
	end
	if not active then
		return
	end
	local clock = os.clock()
	if clock - session.LastTap < GameConfig.ChargeMinTapInterval then
		return
	end
	session.LastTap = clock
	session.Charge = math.min(GameConfig.ChargeMax, session.Charge + GameConfig.ChargePerTap)
end

-- Sends a personal welcome wave to a brand-new player (their guaranteed first brainrot).
function WaveService.SendWelcomeWave(player: Player)
	task.delay(GameConfig.FirstWaveDelay, function()
		if not player.Parent or hasPending(player) then
			return
		end
		-- Skip the welcome wave if a global wave is about to start anyway.
		if ServerState.NextWaveAt - now() < GameConfig.WaveInterval * 0.25 then
			return
		end
		launch({ player }, false, player)
	end)
end

function WaveService.PendingFor(player: Player): { Entry }
	return pending[player] or {}
end

function WaveService.Start()
	Net.Event("Charge").OnServerEvent:Connect(onCharge)

	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)

	PlotService.BaseBuilt:Connect(function(player)
		local data = DataService.Get(player)
		local session = DataService.GetSession(player)
		if data and session and not session.WelcomeSent and (data.Stats.Captures or 0) == 0 then
			session.WelcomeSent = true
			WaveService.SendWelcomeWave(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		if player.Parent then
			ServerState.SendTo(player)
		end
	end)

	task.spawn(function()
		ServerState.NextWaveAt = now() + GameConfig.WaveInterval
		ServerState.Broadcast()
		while true do
			local wait = ServerState.NextWaveAt - now()
			if wait > 0 then
				task.wait(wait)
			end
			ServerState.WaveNumber += 1
			local stampede = ServerState.StampedeNextWave
			ServerState.StampedeNextWave = false
			if stampede then
				announce("🐘 STAMPEDE! Every brainrot this wave is a BOSS!", Color3.fromRGB(255, 120, 60))
			end
			ServerState.NextWaveAt = now() + GameConfig.WaveInterval
			ServerState.Broadcast()
			local targets = {}
			for _, player in DataService.Players() do
				table.insert(targets, player)
			end
			launch(targets, stampede, nil)
		end
	end)
end

return WaveService
