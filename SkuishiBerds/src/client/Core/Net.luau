--[[
	Net: client side of the remotes. Handlers are registered per message name.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local Net = {}

local net = Remotes.net()
local fast = Remotes.fast()
local ask = Remotes.ask()

local handlers: { [string]: { (...any) -> () } } = {}
local fastHandler: ((number, number, any) -> ())? = nil

net.OnClientEvent:Connect(function(msg, ...)
	local list = handlers[msg]
	if list then
		for _, fn in table.clone(list) do
			local ok, err = pcall(fn, ...)
			if not ok then
				warn("[Net] handler " .. tostring(msg) .. ": " .. tostring(err))
			end
		end
	end
end)

fast.OnClientEvent:Connect(function(matchId, tick, snap)
	if fastHandler then
		fastHandler(matchId, tick, snap)
	end
end)

function Net.on(msg: string, fn: (...any) -> ())
	handlers[msg] = handlers[msg] or {}
	table.insert(handlers[msg], fn)
	return {
		Disconnect = function()
			local list = handlers[msg]
			local idx = list and table.find(list, fn)
			if idx then
				table.remove(list, idx)
			end
		end,
	}
end

function Net.onFast(fn)
	fastHandler = fn
end

function Net.send(msg: string, ...)
	net:FireServer(msg, ...)
end

function Net.sendFast(matchId: number, tick: number, states)
	fast:FireServer(matchId, tick, states)
end

function Net.ask(action: string, ...): any
	local args = { ... }
	local ok, result = pcall(function()
		return ask:InvokeServer(action, table.unpack(args))
	end)
	if not ok then
		warn("[Net] ask " .. action .. " failed: " .. tostring(result))
		return nil
	end
	return result
end

return Net
