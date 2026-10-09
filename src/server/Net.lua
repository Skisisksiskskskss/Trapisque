--[[
	Net
	One RemoteFunction for client requests and one RemoteEvent for server pushes.

	Requests: client calls Request:InvokeServer(action, payload) and gets back
		{ ok = true, data = ... } or { ok = false, err = "message" }
	Handlers are registered with Net.handle(action, fn) where fn(player, payload)
	returns (true, data) or (false, "error message").

	Pushes: Net.push(player, kind, data) fires Push on that client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Net = {}

local handlers = {}
local buckets = {}

local folder = Instance.new("Folder")
folder.Name = "TrapisqueNet"
local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = folder
local push = Instance.new("RemoteEvent")
push.Name = "Push"
push.Parent = folder

-- token bucket rate limiting per player
local function allow(player: Player): boolean
	local rate = Config.Server.RequestRateLimit
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = rate, t = now }
		buckets[player] = b
	end
	b.tokens = math.min(rate, b.tokens + (now - b.t) * rate)
	b.t = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function Net.handle(action: string, fn)
	assert(handlers[action] == nil, "Net: duplicate handler " .. action)
	handlers[action] = fn
end

function Net.push(player: Player, kind: string, data: any)
	if player.Parent == Players then
		push:FireClient(player, kind, data)
	end
end

function Net.pushAll(kind: string, data: any)
	push:FireAllClients(kind, data)
end

function Net.init()
	request.OnServerInvoke = function(player: Player, action: any, payload: any)
		if type(action) ~= "string" then
			return { ok = false, err = "Bad request." }
		end
		if not allow(player) then
			return { ok = false, err = "Slow down a little!" }
		end
		local fn = handlers[action]
		if not fn then
			return { ok = false, err = "Unknown request." }
		end
		if payload ~= nil and type(payload) ~= "table" then
			return { ok = false, err = "Bad request." }
		end
		local ok, success, result = pcall(fn, player, payload or {})
		if not ok then
			warn("[Trapisque] handler '" .. action .. "' failed: " .. tostring(success))
			return { ok = false, err = "Something went wrong. Try again." }
		end
		if success == false then
			return { ok = false, err = tostring(result or "That didn't work.") }
		end
		return { ok = true, data = result }
	end
	folder.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Net
