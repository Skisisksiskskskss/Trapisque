--!strict
-- Server bootstrap: creates remotes, then initialises and starts every service in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)

Net.Setup()

local Services = script:WaitForChild("Services")

type Service = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

local order = {
	"DataService",
	"MapService",
	"PlotService",
	"BrainrotService",
	"UpgradeService",
	"BoostService",
	"RewardService",
	"WaveService",
	"SyncService",
}

local loaded: { Service } = {}
for _, name in order do
	local module = Services:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		table.insert(loaded, (require :: any)(module) :: Service)
	else
		warn("[Server] missing service " .. name)
	end
end

for _, service in loaded do
	if service.Init then
		service.Init()
	end
end
for _, service in loaded do
	if service.Start then
		task.spawn(service.Start)
	end
end

-- Players are only loaded once every service is listening.
local DataService = require(Services:WaitForChild("DataService")) :: any
DataService.BeginLoading()

print("[Beam a Brainrot] server ready")
