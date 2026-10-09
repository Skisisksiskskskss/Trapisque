--[[
	Trapisque server entry point.
	Trapisque is a fully 2D game drawn with UI, so nobody gets an avatar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

local Config = require(ReplicatedStorage.Shared.Config)

local Net = require(script.Parent.Net)
local ServerInfo = require(script.Parent.ServerInfo)
local TeleportUtil = require(script.Parent.TeleportUtil)
local DataService = require(script.Parent.DataService)
local GachaService = require(script.Parent.GachaService)
local PartyService = require(script.Parent.PartyService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchService = require(script.Parent.MatchService)
local LeaderboardService = require(script.Parent.LeaderboardService)

Net.init()
TeleportUtil.init()
DataService.init()
LeaderboardService.init(DataService.get)
GachaService.init()
PartyService.init()
MatchmakingService.init()
MatchService.init()

TeleportUtil.Failed:Connect(function(player, message)
	Net.push(player, "teleporting", nil)
	Net.push(player, "toast", { text = "Teleport failed: " .. tostring(message), kind = "error" })
end)

-- First call every client makes: everything it needs to draw the right screen.
Net.handle("hello", function(player)
	DataService.waitFor(player, 20)
	local match = MatchService.get(player)
	return true, {
		version = Config.Version,
		role = ServerInfo.role,
		studio = ServerInfo.isStudio,
		profile = DataService.view(player),
		party = PartyService.view(PartyService.get(player)),
		match = match and match:resync(player) or nil,
		status = MatchService.status(player),
	}
end)

print(string.format("[Trapisque] v%s server ready (%s%s)", Config.Version, ServerInfo.role, if ServerInfo.isStudio then ", Studio" else ""))
