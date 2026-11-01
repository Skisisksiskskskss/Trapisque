--!strict
-- Consumable boosts the player owns (from codes, daily rewards, gifts or purchases) and activates on demand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local BoostService = {}

BoostService.IronDoorSeconds = 300

function BoostService.Grant(player: Player, name: string, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Boosts[name] = (data.Boosts[name] or 0) + amount
	DataService.MarkDirty(player)
end

-- Applies a boost effect immediately (used for activations and purchases).
function BoostService.Apply(player: Player, name: string): (boolean, string)
	local session = DataService.GetSession(player)
	if not session then
		return false, "Not ready"
	end
	if name == "Overcharge" then
		if session.Overcharge then
			return false, "Overcharge is already active!"
		end
		session.Overcharge = true
		return true, "⚡ OVERCHARGE armed: +50% crystal power on your next showdown!"
	elseif name == "IronDoor" then
		session.IronDoorUntil = math.max(session.IronDoorUntil, os.time()) + BoostService.IronDoorSeconds
		local plot = PlotService.ForPlayer(player)
		if plot and PlotService.IsDoorBroken(plot) then
			PlotService.RepairDoor(plot)
		end
		return true, "🛡️ IRON DOOR: your door can't break for 5 minutes!"
	elseif name == "LuckyWave" then
		if session.LuckyPending then
			return false, "A Lucky Wave is already on its way!"
		end
		session.LuckyPending = true
		return true, "🍀 LUCKY WAVE: your next brainrot is extra rare and guaranteed!"
	elseif name == "GoldenWave" then
		if session.GoldenPending then
			return false, "A Golden Wave is already on its way!"
		end
		session.GoldenPending = true
		return true, "✨ GOLDEN WAVE: your next brainrot will be GOLD!"
	elseif name == "InstantRepair" then
		local plot = PlotService.ForPlayer(player)
		if not plot or not PlotService.IsDoorBroken(plot) then
			return false, "Your door isn't broken"
		end
		PlotService.RepairDoor(plot)
		return true, "🔧 Door repaired!"
	end
	return false, "Unknown boost"
end

local function onUseBoost(player: Player, name: unknown): (boolean, string)
	if not DataService.Throttle(player, "UseBoost", 0.3) then
		return false, "Slow down!"
	end
	local data = DataService.Get(player)
	if not data or type(name) ~= "string" then
		return false, "Not ready"
	end
	local count = data.Boosts[name] or 0
	if count <= 0 then
		return false, "You don't have any"
	end
	local ok, message = BoostService.Apply(player, name)
	if ok then
		data.Boosts[name] = count - 1
		DataService.MarkDirty(player)
		PlotService.PublishStats(player)
	end
	return ok, message
end

function BoostService.Start()
	Net.Function("UseBoost").OnServerInvoke = onUseBoost
end

return BoostService
