--[[
	Trapisque client entry point.
	There are no avatars and no 3D: the whole game is UI. This script sets the stage,
	says hello to the server and routes between the lobby and matches.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Client = script.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)
local Root = require(Client.UI.Root)
local Widgets = require(Client.UI.Widgets)
local LobbyScreen = require(Client.UI.Lobby.LobbyScreen)
local MatchScreen = require(Client.UI.Match.MatchScreen)

local player = Players.LocalPlayer

-- Roblox's own HUD pieces we don't use (the chat and menu stay available)
local function hideCoreGui()
	for _, kind in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.EmotesMenu } do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(kind, false)
		end)
	end
	pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
end
hideCoreGui()

-- Nothing to look at in 3D: park the camera.
local function parkCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.new(0, 10000, 0)
	end
end
parkCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(parkCamera)

Root.init()

---------------------------------------------------------------------------
-- server pushes
---------------------------------------------------------------------------

Net.on("profile", function(profile)
	State.set("profile", profile)
	if profile and profile.settings then
		Sound.applySettings(profile.settings)
	end
end)
Net.on("party", function(party)
	State.set("party", party)
end)
Net.on("queue", function(queue)
	State.set("queue", queue)
end)
Net.on("invite", function(data)
	LobbyScreen.invite(data)
end)
Net.on("toast", function(data)
	if type(data) == "table" and data.text then
		Widgets.toast(data.text, data.kind)
	end
end)
Net.on("teleporting", function(data)
	State.set("teleporting", data)
	Root.curtain(if data then (data.reason or "Teleporting...") else nil)
end)
Net.on("match.waiting", function(data)
	Root.curtain(string.format("Waiting for players... %d / %d", data.arrived or 0, data.expected or 0))
end)
Net.on("match.start", function(payload)
	Root.curtain(nil)
	State.set("queue", nil)
	MatchScreen.show(payload)
end)
Net.on("match.closed", function()
	if MatchScreen.current() then
		LobbyScreen.show()
	end
end)

---------------------------------------------------------------------------
-- hello
---------------------------------------------------------------------------

local function hello()
	for attempt = 1, 8 do
		local ok, data = Net.request("hello")
		if ok and type(data) == "table" then
			return data
		end
		task.wait(math.min(8, attempt * 1.5))
	end
	return nil
end

Root.curtain("Unrolling the map...")
local data = hello()
if not data then
	Root.curtain("Couldn't reach the server. Try rejoining!")
	return
end
State.set("version", data.version)
State.set("role", data.role)
State.set("studio", data.studio)
State.set("profile", data.profile)
State.set("party", data.party)
if data.profile and data.profile.settings then
	Sound.applySettings(data.profile.settings)
end
Sound.preload()

if data.match then
	-- rejoined (or arrived on a match server) while a match is running
	Root.curtain(nil)
	MatchScreen.show(data.match)
elseif data.role == "match" then
	-- a reserved match server: the match starts once everyone has arrived
	Root.curtain("Getting the board ready...")
else
	Root.curtain(nil)
	LobbyScreen.show()
end

print(string.format("[Trapisque] client ready (v%s, %s) for %s", tostring(data.version), tostring(data.role), player.Name))
