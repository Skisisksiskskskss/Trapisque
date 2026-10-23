--[[
	Trapisque client entry point.
	There are no avatars and no 3D: the whole game is UI. This script sets the stage,
	says hello to the server and routes between the lobby and matches.

	The loading screen (ReplicatedFirst) follows along through two attributes on the
	local player: TrapisqueLoad (0 to 1) and TrapisqueLoadText. It lifts as soon as the
	lobby is up; sounds and music keep loading behind it (Sound.preload).
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

-- tells the loading screen how far along we are
local function loading(progress: number, text: string?)
	local me = Players.LocalPlayer
	me:SetAttribute("TrapisqueLoad", progress)
	if text then
		me:SetAttribute("TrapisqueLoadText", text)
	end
end
loading(0.4, "Charting the seas...")

local Client = script.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)
local Root = require(Client.UI.Root)
local Art = require(Client.UI.Art)
local Widgets = require(Client.UI.Widgets)
local StaffPanel = require(Client.UI.StaffPanel)
local _Chat = require(Client.Chat) -- starts listening for chat lines straight away
local LobbyScreen = require(Client.UI.Lobby.LobbyScreen)
local MatchScreen = require(Client.UI.Match.MatchScreen)
local MapVote = require(Client.UI.Match.MapVote)
local RejoinOffer = require(Client.UI.Lobby.RejoinOffer)
local BadgeToast = require(Client.UI.BadgeToast)
local Gamepad = require(Client.Gamepad)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progress = require(ReplicatedStorage.Shared.Meta.Progress)

local player = Players.LocalPlayer

-- the owner can switch the weekly event; every screen shows the one in play
local function syncEvent()
	local id = ReplicatedStorage:GetAttribute("TrapisqueEvent")
	Progress.eventOverride = if type(id) == "string" and id ~= "" then id else nil
end
syncEvent()
ReplicatedStorage:GetAttributeChangedSignal("TrapisqueEvent"):Connect(syncEvent)

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
Gamepad.init()

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
Net.on("staff.announce", function(data)
	StaffPanel.announce(Root.toasts, data)
end)
Net.on("staff.role", function(data)
	State.set("staff", if type(data) == "table" then data.role else nil)
	if type(data) == "table" and data.role then
		Widgets.toast("You're now an admin! Open the panel from Settings (or the match menu).", "reward")
	end
end)
Net.on("teleporting", function(data)
	State.set("teleporting", data)
	Root.curtain(if data then (data.reason or "Teleporting...") else nil)
end)
Net.on("match.waiting", function(data)
	Root.curtain(string.format("Waiting for players... %d / %d", data.arrived or 0, data.expected or 0))
end)
Net.on("match.vote", function(data)
	Root.curtain(nil)
	State.set("queue", nil)
	MapVote.show(Root.popups, data)
end)
Net.on("match.voted", function(data)
	if type(data) == "table" and data.map then
		MapVote.result(data)
	end
end)
Net.on("match.start", function(payload)
	Root.curtain(nil)
	State.set("queue", nil)
	MapVote.close()
	MatchScreen.show(payload)
end)
Net.on("badge", function(data)
	if type(data) == "table" and data.key then
		BadgeToast.show(Root.toasts, data.key)
	end
end)
Net.on("match.closed", function()
	if MatchScreen.current() then
		LobbyScreen.show()
	end
end)

---------------------------------------------------------------------------
-- hello
---------------------------------------------------------------------------

-- Keeps asking until the server answers, saying why on the loading screen when it
-- takes a while (and in the output).
local function hello()
	local attempt = 0
	while true do
		attempt += 1
		local ok, data = Net.request("hello")
		if ok and type(data) == "table" then
			return data
		end
		warn(string.format("[Trapisque] the server didn't answer hello (try %d): %s", attempt, tostring(data)))
		if attempt >= 2 then
			loading(0.55, string.format("Still hailing the harbour (%s)...", tostring(data)))
		end
		task.wait(math.min(6, attempt * 1.5))
	end
end

loading(0.55, "Hailing the harbour...")
local data = hello()
loading(0.8, "Unpacking your sea chest...")
-- a save that's slow to load arrives on its own a little later
if data.profile == nil then
	local t0 = os.clock()
	while State.get("profile") == nil and os.clock() - t0 < 30 do
		task.wait(0.2)
	end
	data.profile = State.get("profile")
end
State.set("version", data.version)
State.set("role", data.role)
State.set("studio", data.studio)
State.set("profile", data.profile)
State.set("party", data.party)
State.set("chat", data.chat)
State.set("staff", data.staff)
if data.profile and data.profile.settings then
	Sound.applySettings(data.profile.settings)
end
-- the art sheets: built (or loaded, once uploaded) before the first screen draws them
loading(0.9, "Setting out the pieces...")
Art.preload(8)
-- sounds and music load in the background; the lobby shows how far along they are
Sound.preload(function(done, total)
	State.set("loadingRest", if done >= total then nil else done / math.max(1, total))
end)

if data.match then
	-- rejoined (or arrived on a match server) while a match is running
	MatchScreen.show(data.match)
elseif data.role == "match" then
	-- a reserved match server: the match starts once everyone has arrived
	Root.curtain("Getting the board ready...")
else
	LobbyScreen.show()
	-- your connection dropped mid-match: your seat is still kept on another server
	if data.rejoin then
		task.delay(1.5, RejoinOffer.show, Root.popups, data.rejoin)
	end
end
loading(1, "Land ho!")

print(string.format("[Trapisque] client ready (v%s, %s) for %s", tostring(data.version), tostring(data.role), player.Name))
