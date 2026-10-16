--[[
	Chat (client)
	The game chat as it arrives (server "chat.line"): the last lines are kept for the
	chat window, each one is read out loud in its speaker's voice (Voice), and screens
	listen to pop it as a bubble over whoever said it.

		Chat.onLine(fn(line)) -> disconnect
		Chat.say(text) ; Chat.quick(id)       -> ok, err (yields)
		Chat.history() -> { line }
		Chat.typing() -> "ok" | "pass" | "settings" | "muted"
		Chat.mute(userId, on) ; Chat.isMuted(userId)   -- hide someone, just for you

	In a match every line is spoken; in the lobby only yours and your party's are (a
	full lobby talking at once would be a racket). Settings can switch the voices and the
	bubbles off.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Voices = require(ReplicatedStorage.Shared.Meta.Voices)

local Client = script.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Voice = require(Client.Voice)

local Chat = {}

local player = Players.LocalPlayer
local history: { any } = {}
local listeners: { (any) -> () } = {}
local muted: { [number]: boolean } = {}

local function settings()
	local p = State.get("profile")
	return p and p.settings or {}
end

local function inParty(userId: number): boolean
	local party = State.get("party")
	for _, m in party and party.members or {} do
		if m.userId == userId then
			return true
		end
	end
	return false
end

function Chat.bubbles(): boolean
	return settings().bubbles ~= false
end

Net.on("chat.line", function(line)
	if type(line) ~= "table" or type(line.text) ~= "string" then
		return
	end
	if line.from and muted[line.from] then
		return
	end
	line.at = os.clock()
	table.insert(history, line)
	while #history > Config.Chat.History do
		table.remove(history, 1)
	end
	local spoken = line.seat ~= nil or line.from == player.UserId or inParty(line.from or 0)
	if spoken and settings().voices ~= false then
		Voice.say(line.text, Voices.resolve(line.voice, line.character))
	end
	for _, fn in table.clone(listeners) do
		task.spawn(fn, line)
	end
end)

function Chat.onLine(fn: (any) -> ()): () -> ()
	table.insert(listeners, fn)
	return function()
		local i = table.find(listeners, fn)
		if i then
			table.remove(listeners, i)
		end
	end
end

function Chat.history(): { any }
	return history
end

-- Whether you can type your own lines, and if not, why.
function Chat.typing(): string
	local status = State.get("chat") or {}
	if not State.hasPass("Chat") then
		return "pass"
	end
	if status.allowed == false then
		return "settings"
	end
	if status.muted then
		return "muted"
	end
	return "ok"
end

function Chat.say(text: string): (boolean, any)
	return Net.request("chat.send", { text = text })
end

function Chat.quick(id: string): (boolean, any)
	return Net.request("chat.send", { quick = id })
end

function Chat.mute(userId: number, on: boolean)
	muted[userId] = if on then true else nil
end

function Chat.isMuted(userId: number): boolean
	return muted[userId] == true
end

-- Settings: voices on or off take effect straight away.
State.watch("profile", function(p)
	Voice.setEnabled(not (p and p.settings and p.settings.voices == false))
end)

return Chat
