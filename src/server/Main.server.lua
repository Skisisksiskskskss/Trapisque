--[[
	Trapisque server entry point.
	Trapisque is a fully 2D game drawn with UI, so nobody gets an avatar.

	The "hello" every client starts with is answered before anything else starts, and
	each service then starts on its own. One that breaks, or hangs on a Roblox service
	(Studio can, with DataStores or MessagingService in an unpublished place), is
	reported in the output and never keeps players out.
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
local ChatService = require(script.Parent.ChatService)
local AdminService = require(script.Parent.AdminService)

Net.init()

-- Runs fn; on an error, says what broke and gives back nil.
local function try(what: string, fn: (...any) -> any, ...: any): any
	local ok, result = pcall(fn, ...)
	if not ok then
		warn(string.format("[Trapisque] %s failed: %s", what, tostring(result)))
		return nil
	end
	return result
end

-- First call every client makes: everything it needs to draw the right screen. Each
-- part is fetched on its own, so one that fails leaves a gap instead of an error.
Net.handle("hello", function(player)
	DataService.waitFor(player, 20)
	local match = try("finding the player's match", MatchService.get, player)
	return true, {
		version = Config.Version,
		role = ServerInfo.role,
		studio = ServerInfo.isStudio,
		profile = try("the profile", DataService.view, player),
		party = try("the party", function()
			return PartyService.view(PartyService.get(player))
		end),
		match = if match then try("the match", match.resync, match, player) else nil,
		status = try("the match status", MatchService.status, player),
		chat = try("the chat status", ChatService.status, player),
		staff = try("the staff role", AdminService.role, player),
	}
end)

-- Starts a service in its own thread, waiting a few seconds at most for it.
local function start(name: string, fn: () -> ())
	local done = false
	task.spawn(function()
		try("starting " .. name, fn)
		done = true
	end)
	local deadline = os.clock() + 5
	while not done and os.clock() < deadline do
		task.wait()
	end
	if not done then
		warn("[Trapisque] " .. name .. " is still starting; carrying on without waiting for it")
	end
end

start("TeleportUtil", TeleportUtil.init)
start("DataService", DataService.init)
start("LeaderboardService", function()
	LeaderboardService.init(DataService.get)
end)
start("GachaService", GachaService.init)
start("PartyService", PartyService.init)
start("MatchmakingService", MatchmakingService.init)
start("MatchService", MatchService.init)
start("ChatService", ChatService.init)
start("AdminService", AdminService.init)

TeleportUtil.Failed:Connect(function(player, message)
	Net.push(player, "teleporting", nil)
	Net.push(player, "toast", { text = "Teleport failed: " .. tostring(message), kind = "error" })
end)

print(string.format("[Trapisque] v%s server ready (%s%s)", Config.Version, ServerInfo.role, if ServerInfo.isStudio then ", Studio" else ""))
