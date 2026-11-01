--!strict
-- Holds the latest server snapshot for the local player plus server-wide info, and exposes change signals.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local StateController = {}

StateController.Changed = Signal.new() :: Signal.Signal<{ [string]: any }>
StateController.InfoChanged = Signal.new() :: Signal.Signal<{ [string]: any }>

local state: { [string]: any }? = nil
local info: { [string]: any } = {
	NextWaveAt = 0,
	ActiveEvent = "",
	EventEndsAt = 0,
	NextEventName = "",
	NextEventAt = 0,
	ServerLuckUntil = 0,
	ServerLuckBy = "",
	WeekendBoost = false,
}

function StateController.Get(): { [string]: any }?
	return state
end

function StateController.Info(): { [string]: any }
	return info
end

function StateController.Now(): number
	return Workspace:GetServerTimeNow()
end

function StateController.HasPass(name: string): boolean
	local current = state
	return current ~= nil and current.Passes ~= nil and current.Passes[name] == true
end

function StateController.Start()
	Net.Event("State").OnClientEvent:Connect(function(newState: { [string]: any })
		state = newState
		StateController.Changed:Fire(newState)
	end)
	Net.Event("ServerInfo").OnClientEvent:Connect(function(newInfo: { [string]: any })
		info = newInfo
		StateController.InfoChanged:Fire(newInfo)
	end)
end

return StateController
