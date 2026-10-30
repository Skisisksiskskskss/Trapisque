--[[
	Chat (client)
	The game chat as it arrives (server "chat.line"): the last lines are kept for the
	chat window, and screens listen to pop it as a bubble over whoever said it.

		Chat.onLine(fn(line)) -> disconnect
		Chat.say(text) ; Chat.quick(id)       -> ok, err (yields)
		Chat.history() -> { line }
		Chat.typing() -> "ok" | "pass" | "settings" | "muted"
		Chat.mute(userId, on) ; Chat.isMuted(userId)   -- hide someone, just for you
		Chat.block(userId) -> ok                         -- Roblox's block (asks first)
		Chat.isBlocked(userId)
		Chat.report(userId, reason) -> ok, err (yields) -- to the game's staff

	People you've blocked on Roblox never show up in the chat at all (their lines and
	bubbles are dropped as they arrive), and blocking someone here blocks them on Roblox.

	Settings can switch the bubbles off.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)

local Client = script.Parent
local Net = require(Client.Net)
local State = require(Client.State)

local Chat = {}

local history: { any } = {}
local listeners: { (any) -> () } = {}
local muted: { [number]: boolean } = {}
local blocked: { [number]: boolean } = {}

local function settings()
	local p = State.get("profile")
	return p and p.settings or {}
end

function Chat.bubbles(): boolean
	return settings().bubbles ~= false
end

Net.on("chat.line", function(line)
	if type(line) ~= "table" or type(line.text) ~= "string" then
		return
	end
	if line.from and (muted[line.from] or blocked[line.from]) then
		return
	end
	line.at = os.clock()
	table.insert(history, line)
	while #history > Config.Chat.History do
		table.remove(history, 1)
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

function Chat.isBlocked(userId: number): boolean
	return blocked[userId] == true
end

-- Their lines leave the chat window's history too.
local function forget(userId: number)
	for i = #history, 1, -1 do
		if history[i].from == userId then
			table.remove(history, i)
		end
	end
end

-- Roblox's own "Block this person?" box. Only for someone on this server.
function Chat.block(userId: number): boolean
	local who = Players:GetPlayerByUserId(userId)
	if not who then
		return false
	end
	return (pcall(function()
		StarterGui:SetCore("PromptBlockPlayer", who)
	end))
end

function Chat.report(userId: number, reason: string): (boolean, any)
	return Net.request("chat.report", { userId = userId, reason = reason })
end

-- Roblox's core scripts set these up a moment after the game starts: keep asking.
local function core(name: string): any
	for _ = 1, 20 do
		local ok, value = pcall(function()
			return StarterGui:GetCore(name)
		end)
		if ok then
			return value
		end
		task.wait(1)
	end
	return nil
end

task.spawn(function()
	local ids = core("GetBlockedUserIds")
	if type(ids) == "table" then
		for _, id in ids do
			if type(id) == "number" then
				blocked[id] = true
			end
		end
	end
	for name, on in { PlayerBlockedEvent = true, PlayerUnblockedEvent = false } do
		local event = core(name)
		if typeof(event) == "Instance" and event:IsA("BindableEvent") then
			event.Event:Connect(function(who)
				if typeof(who) == "Instance" and who:IsA("Player") then
					blocked[who.UserId] = if on then true else nil
					if on then
						forget(who.UserId)
					end
				end
			end)
		end
	end
end)

return Chat
