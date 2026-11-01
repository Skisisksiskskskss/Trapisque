--!strict
-- Crystal / Door / Base Tier upgrades and Rebirth. All costs and gates come from shared Economy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Themes = require(Shared.Config.Themes)
local Format = require(Shared.Modules.Format)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)
local BrainrotService = require(script.Parent.BrainrotService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local UpgradeService = {}

UpgradeService.Upgraded = Signal.new() :: Signal.Signal<Player, string>

local function announce(text: string, color: Color3)
	Net.Event("Announce"):FireAllClients(text, color)
end

local function onUpgrade(player: Player, kind: unknown): (boolean, string)
	if not DataService.Throttle(player, "Upgrade", 0.08) then
		return false, "Slow down!"
	end
	local data = DataService.Get(player)
	if not data or type(kind) ~= "string" then
		return false, "Not ready"
	end
	local maxLevel = Economy.MaxLevelForTier(data.Tier)
	if kind == "Crystal" then
		if data.CrystalLevel >= maxLevel then
			return false,
				if data.Tier < Economy.MaxTier then "Crystal maxed! Upgrade your base tier." else "Crystal fully maxed!"
		end
		local cost = Economy.CrystalCost(data.CrystalLevel)
		if not DataService.SpendCash(player, cost) then
			return false, "Need " .. Format.Cash(cost)
		end
		data.CrystalLevel += 1
	elseif kind == "Door" then
		if data.DoorLevel >= maxLevel then
			return false,
				if data.Tier < Economy.MaxTier then "Door maxed! Upgrade your base tier." else "Door fully maxed!"
		end
		local cost = Economy.DoorCost(data.DoorLevel)
		if not DataService.SpendCash(player, cost) then
			return false, "Need " .. Format.Cash(cost)
		end
		data.DoorLevel += 1
	elseif kind == "Tier" then
		if data.Tier >= Economy.MaxTier then
			return false, "Max tier reached! Time to Rebirth."
		end
		if not Economy.CanTierUp(data.Tier, data.CrystalLevel) then
			return false, string.format("Max your crystal first (Lv %d)", Economy.MaxLevelForTier(data.Tier))
		end
		local cost = Economy.TierCost(data.Tier)
		if not DataService.SpendCash(player, cost) then
			return false, "Need " .. Format.Cash(cost)
		end
		BrainrotService.CollectAll(player)
		data.Tier += 1
		PlotService.Rebuild(player)
		local theme = Themes.Get(data.Tier)
		Net.Event("Effect"):FireClient(player, "TierUp", { Tier = data.Tier, Name = theme.Name })
		if data.Tier >= 5 then
			announce(string.format("%s upgraded to %s!", player.DisplayName, theme.Name), theme.Glow)
		end
	else
		return false, "Unknown upgrade"
	end
	DataService.MarkDirty(player)
	UpgradeService.Upgraded:Fire(player, kind)
	return true, "Upgraded!"
end

local function onRebirth(player: Player): (boolean, string)
	if not DataService.Throttle(player, "Rebirth", 1) then
		return false, "Slow down!"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Not ready"
	end
	if not Economy.CanRebirth(data.Tier, data.CrystalLevel, data.Cash, data.Rebirths) then
		return false,
			string.format(
				"Reach Tier %d, max your crystal and have %s",
				Economy.MaxTier,
				Format.Cash(Economy.RebirthCost(data.Rebirths))
			)
	end
	BrainrotService.CollectAll(player)
	data.Rebirths += 1
	data.Cash = 0
	data.Tier = 1
	data.CrystalLevel = 1
	data.DoorLevel = 1
	-- Keep every brainrot: the best ones go back on the (fewer) tier-1 pedestals, the rest wait in storage.
	PlotService.Rebuild(player)
	BrainrotService.PlaceBest(player)
	Net.Event("Effect"):FireClient(player, "Rebirth", { Rebirths = data.Rebirths })
	announce(
		string.format("%s REBIRTHED! (Rebirth %d)", player.DisplayName, data.Rebirths),
		Color3.fromRGB(255, 120, 230)
	)
	DataService.MarkDirty(player)
	DataService.SaveNow(player)
	UpgradeService.Upgraded:Fire(player, "Rebirth")
	return true, "Rebirthed!"
end

function UpgradeService.Start()
	Net.Function("Upgrade").OnServerInvoke = onUpgrade
	Net.Function("Rebirth").OnServerInvoke = onRebirth
end

return UpgradeService
