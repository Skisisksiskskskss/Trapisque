--[[
	DailyShop
	The Shop's daily deals: four cosmetics you can buy straight for Gems, no random
	rolls. They change every day at 00:00 UTC and are the same on every server, worked
	out from the day number. Only chest cosmetics are sold (never gamepass items), one
	of each rarity in Config.DailyShop.Slots.

		DailyShop.deals(day) -> { { id, price }, ... }
		DailyShop.secondsLeft(now) -> until the next deals
]]

local Config = require(script.Parent.Parent.Config)
local Cosmetics = require(script.Parent.Cosmetics)

local DailyShop = {}

local DAY = 86400

local function lcg(seed: number)
	local state = math.floor(seed) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(n: number): number
		state = (state * 48271) % 2147483647
		return 1 + state % n
	end
end

-- Chest cosmetics of a rarity, in catalog order (so every server agrees).
local function pool(rarity: string): { string }
	local out = {}
	for _, def in Cosmetics.list do
		if def.source == nil and def.rarity == rarity and def.category ~= "title" then
			table.insert(out, def.id)
		end
	end
	return out
end

function DailyShop.deals(day: number)
	local rand = lcg(day * 7919 + 4243)
	local out = {}
	local taken = {}
	for _, rarity in Config.DailyShop.Slots do
		local list = pool(rarity)
		if #list > 0 then
			local id = list[rand(#list)]
			for _ = 1, 6 do
				if not taken[id] then
					break
				end
				id = list[rand(#list)]
			end
			if not taken[id] then
				taken[id] = true
				table.insert(out, { id = id, price = Config.DailyShop.Prices[rarity] or 500 })
			end
		end
	end
	return out
end

function DailyShop.today(now: number?): number
	return (now or os.time()) // DAY
end

function DailyShop.secondsLeft(now: number?): number
	local t = now or os.time()
	return DAY - (t % DAY)
end

return DailyShop
