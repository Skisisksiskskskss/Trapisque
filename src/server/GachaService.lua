--[[
	GachaService
	Opens Treasure Chests on the server. Gems are earned by playing only (they can't be
	bought with Robux), odds are shown in the chest screen, and the Lucky Charm pass is
	ignored for players in regions that restrict paid random items.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gacha = require(Shared.Meta.Gacha)
local Cosmetics = require(Shared.Meta.Cosmetics)
local Rng = require(Shared.Game.Rng)

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)

local GachaService = {}

-- Rng-compatible adapter around Roblox's Random (better entropy for loot)
local random = Random.new()
local rng = setmetatable({}, { __index = Rng })
function rng.float(_self)
	return random:NextNumber()
end

local busy = {}

function GachaService.open(player: Player, chestId: string, count: number)
	local chest = Gacha.byId[chestId]
	if not chest then
		return false, "Unknown chest."
	end
	if count ~= 1 and count ~= 10 then
		return false, "Open 1 or 10 at a time."
	end
	local data = DataService.get(player)
	if not data then
		return false, "Your profile is still loading."
	end
	if busy[player] then
		return false, "Hang on, still opening!"
	end

	local usedFree = false
	if count == 1 and (data.freeChests[chestId] or 0) > 0 then
		data.freeChests[chestId] -= 1
		usedFree = true
	else
		local cost = if count == 10 then chest.tenPrice else chest.price
		if data.gems < cost then
			return false, "Not enough Gems. Play matches to earn more!"
		end
		data.gems -= cost
	end

	busy[player] = true
	local lucky = DataService.isLucky(player)
	data.pity[chestId] = data.pity[chestId] or {}
	local results = {}
	for _ = 1, count do
		local item, rarity, pityHit = Gacha.roll(chest, data.pity[chestId], data.owned, rng, lucky)
		local isNew = not data.owned[item]
		local refund = 0
		if isNew then
			data.owned[item] = true
		else
			refund = Gacha.dupeRefund[rarity] or 0
			data.gems += refund
		end
		table.insert(results, {
			item = item,
			rarity = rarity,
			new = isNew,
			refund = refund,
			pity = pityHit,
			category = Cosmetics.get(item).category,
		})
	end
	data.chestsOpened += count
	busy[player] = nil
	DataService.pushProfile(player)
	task.spawn(DataService.save, player, false)
	return true, { chest = chestId, results = results, usedFree = usedFree, lucky = lucky }
end

function GachaService.init()
	Net.handle("gacha.open", function(player, payload)
		return GachaService.open(player, payload.chest, tonumber(payload.count) or 1)
	end)
	Net.handle("gacha.odds", function(player, payload)
		local chest = Gacha.byId[payload.chest]
		if not chest then
			return false, "Unknown chest."
		end
		return true, { odds = Gacha.odds(chest, DataService.isLucky(player)), lucky = DataService.isLucky(player) }
	end)
end

return GachaService
