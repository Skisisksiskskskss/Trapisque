--[[
	ShopService: request/response API (RemoteFunction "Ask").

	  Profile                      -> sanitized profile
	  Buy(category, id)            buy a cosmetic with coins
	  BuyBird(id)                  unlock a bird with coins
	  Equip(which, field, value)   which = 1 (P1 / online) or 2 (couch P2)
	  Leaderboard(board)           top 50
	  Daily                        claim the daily reward
	  Settings(table)              save audio/visual settings
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local Birds = require(Shared.Config.Birds)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local ShopService = {}

local function sanitize(data)
	local out = table.clone(data)
	out.receipts = nil
	out.receiptOrder = nil
	out.level = DataService.levelFor(data.xp)
	out.persistent = DataService.Persistent
	return out
end
ShopService.sanitize = sanitize

local FIELD_CATEGORY = {
	color = "color",
	patternColor = "color",
	pattern = "pattern",
	hat = "hat",
	death = "death",
	bird = "bird",
}

local handlers = {}

function handlers.Profile(player)
	local data = DataService.waitFor(player, 20)
	return data and sanitize(data)
end

function handlers.Buy(player, category, id)
	if type(category) ~= "string" or type(id) ~= "string" then
		return { ok = false, err = "bad request" }
	end
	local item = Cosmetics.get(category, id)
	local data = DataService.get(player)
	if not item or not data then
		return { ok = false, err = "unknown item" }
	end
	if item.robuxOnly then
		return { ok = false, err = "robux only" }
	end
	if data.owned[category][id] then
		return { ok = true, owned = true }
	end
	if data.coins < item.price then
		return { ok = false, err = "not enough coins" }
	end
	DataService.update(player, function(d)
		d.coins -= item.price
		d.owned[category][id] = true
	end)
	return { ok = true }
end

function handlers.BuyBird(player, id)
	local def = type(id) == "string" and Birds.ById[id]
	local data = DataService.get(player)
	if not def or not data then
		return { ok = false, err = "unknown bird" }
	end
	if data.owned.bird[id] then
		return { ok = true, owned = true }
	end
	if data.coins < def.price then
		return { ok = false, err = "not enough coins" }
	end
	DataService.update(player, function(d)
		d.coins -= def.price
		d.owned.bird[id] = true
	end)
	return { ok = true }
end

function handlers.Equip(player, which, field, value)
	local data = DataService.get(player)
	if not data or (which ~= 1 and which ~= 2) or type(field) ~= "string" then
		return { ok = false }
	end
	if field == "patternAlpha" then
		local alpha = tonumber(value)
		if not alpha then
			return { ok = false }
		end
		DataService.update(player, function(d)
			local lo = if which == 1 then d.loadout else d.loadout2
			lo.patternAlpha = math.clamp(alpha, 0, 1)
		end)
		return { ok = true }
	end
	local category = FIELD_CATEGORY[field]
	if not category or type(value) ~= "string" then
		return { ok = false }
	end
	if not data.owned[category] or not data.owned[category][value] then
		return { ok = false, err = "not owned" }
	end
	DataService.update(player, function(d)
		local lo = if which == 1 then d.loadout else d.loadout2
		lo[field] = value
	end)
	return { ok = true }
end

function handlers.Leaderboard(_player, board)
	if board ~= "SoloBest" and board ~= "DuoBest" and board ~= "VersusWins" then
		return {}
	end
	return { rows = LeaderboardService.get(board), available = LeaderboardService.isAvailable() }
end

function handlers.Daily(player)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	local today = math.floor(os.time() / 86400)
	if data.daily.day >= today then
		return { ok = false, err = "already claimed", streak = data.daily.streak }
	end
	local streak = if data.daily.day == today - 1 then data.daily.streak + 1 else 1
	local coins = 50 + 25 * math.min(streak - 1, 6)
	local token = streak % 7 == 0
	DataService.update(player, function(d)
		d.daily.day = today
		d.daily.streak = streak
		d.coins += coins
		if token then
			d.reviveTokens += 1
		end
	end)
	return { ok = true, coins = coins, streak = streak, token = token }
end

function handlers.Settings(player, settings)
	if type(settings) ~= "table" then
		return { ok = false }
	end
	DataService.update(player, function(d)
		d.settings.music = math.clamp(tonumber(settings.music) or d.settings.music, 0, 1)
		d.settings.sfx = math.clamp(tonumber(settings.sfx) or d.settings.sfx, 0, 1)
		if type(settings.shake) == "boolean" then
			d.settings.shake = settings.shake
		end
		if type(settings.eventText) == "boolean" then
			d.settings.eventText = settings.eventText
		end
	end)
	return { ok = true }
end

function ShopService.init()
	local ask = Remotes.ask()
	ask.OnServerInvoke = function(player, action, ...)
		local handler = handlers[action]
		if not handler then
			return nil
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn("[ShopService] " .. tostring(action) .. ": " .. tostring(result))
			return { ok = false, err = "server error" }
		end
		return result
	end
end

return ShopService
