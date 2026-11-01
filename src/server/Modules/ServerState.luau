--!strict
-- Shared mutable server-wide state (events, timers). Written by EventService/WaveService, read everywhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)

local ServerState = {
	WaveNumber = 0,
	NextWaveAt = 0, -- workspace:GetServerTimeNow() timestamp
	CashEventMult = 1, -- e.g. weekend 2x cash
	LuckEventMult = 1,
	MutationMult = {} :: { [string]: number },
	ServerLuckUntil = 0, -- purchased Server Luck (os.time)
	ServerLuckBy = "",
	ActiveEvent = "", -- "" | "GoldenHour" | "Stampede" | ...
	EventEndsAt = 0, -- server time
	NextEventName = "",
	NextEventAt = 0, -- server time
	StampedeNextWave = false,
	WeekendBoost = false,
}

function ServerState.Snapshot(): { [string]: any }
	return {
		WaveNumber = ServerState.WaveNumber,
		NextWaveAt = ServerState.NextWaveAt,
		ActiveEvent = ServerState.ActiveEvent,
		EventEndsAt = ServerState.EventEndsAt,
		NextEventName = ServerState.NextEventName,
		NextEventAt = ServerState.NextEventAt,
		ServerLuckUntil = ServerState.ServerLuckUntil,
		ServerLuckBy = ServerState.ServerLuckBy,
		StampedeNextWave = ServerState.StampedeNextWave,
		WeekendBoost = ServerState.WeekendBoost,
	}
end

function ServerState.Broadcast()
	Net.Event("ServerInfo"):FireAllClients(ServerState.Snapshot())
end

function ServerState.SendTo(player: Player)
	Net.Event("ServerInfo"):FireClient(player, ServerState.Snapshot())
end

return ServerState
