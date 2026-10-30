--[[
	TeleportUtil
	TeleportAsync with retries, plus a retry for teleports that fail after starting.
]]

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local TeleportUtil = {}

local retries = {} -- [Player] = attempts after TeleportInitFailed
local onFailed = Instance.new("BindableEvent")
TeleportUtil.Failed = onFailed.Event -- (player, message)

function TeleportUtil.teleport(players: { Player }, placeId: number, options: TeleportOptions?)
	local lastErr
	for attempt = 1, 3 do
		local present = {}
		for _, p in players do
			if p.Parent == Players then
				table.insert(present, p)
			end
		end
		if #present == 0 then
			return false, "Nobody left to teleport."
		end
		local ok, err = pcall(function()
			return TeleportService:TeleportAsync(placeId, present, options)
		end)
		if ok then
			return true
		end
		lastErr = err
		warn("[Trapisque] teleport attempt " .. attempt .. " failed: " .. tostring(err))
		task.wait(attempt * 1.5)
	end
	return false, tostring(lastErr)
end

function TeleportUtil.init()
	TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
		local n = (retries[player] or 0) + 1
		retries[player] = n
		if n <= 2 and (result == Enum.TeleportResult.Flooded or result == Enum.TeleportResult.Failure) then
			task.delay(2, function()
				if player.Parent == Players then
					pcall(function()
						TeleportService:TeleportAsync(placeId, { player }, options)
					end)
				end
			end)
		else
			retries[player] = nil
			onFailed:Fire(player, message)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		retries[player] = nil
	end)
end

return TeleportUtil
