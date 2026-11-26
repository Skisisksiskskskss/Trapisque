--[[
	Skuishi Berds - server entry point.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local LeaderboardService = require(Services.LeaderboardService)
local MatchService = require(Services.MatchService)
local ShopService = require(Services.ShopService)
local ProductService = require(Services.ProductService)

-- create remotes before anything else so clients can find them
local net = Remotes.net()
Remotes.fast()
Remotes.ask()

DataService.init()
LeaderboardService.init()
MatchService.init()
ShopService.init()
ProductService.init()

-- Push profile changes to the owning client (at most once per frame)
local dirty: { [Player]: boolean } = {}
DataService.Changed:Connect(function(player)
	dirty[player] = true
end)
RunService.Heartbeat:Connect(function()
	for player in dirty do
		dirty[player] = nil
		local data = DataService.get(player)
		if data and player.Parent then
			net:FireClient(player, "Profile", ShopService.sanitize(data))
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	dirty[player] = nil
end)

print("[Skuishi Berds] server ready")
