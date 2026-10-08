-- Dumps cosmetics + pawn patterns + icons as JSON (tools/preview/cosmetics.py)
local Cosmetics = requireModule("Shared/Meta/Cosmetics")
local Gacha = requireModule("Shared/Meta/Gacha")
local PawnPatterns = requireModule("Client/UI/PawnPatterns")
local IconData = requireModule("Client/UI/IconData")

local function enc(v)
	local t = type(v)
	if t == "number" then
		return string.format("%.6g", v)
	elseif t == "string" then
		return '"' .. v:gsub('"', '\\"') .. '"'
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		local n = #v
		local isArray = n > 0 or next(v) == nil
		for k in pairs(v) do
			if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
				isArray = false
			end
		end
		local parts = {}
		if isArray then
			for i = 1, n do
				table.insert(parts, enc(v[i]))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local args = {}
		for i = 1, n do
			table.insert(args, enc(v[i]))
		end
		for k, x in pairs(v) do
			if type(k) ~= "number" or k > n or k < 1 then
				table.insert(parts, '"' .. tostring(k) .. '":' .. enc(x))
			end
		end
		if n > 0 then
			table.insert(parts, '"__args":[' .. table.concat(args, ",") .. "]")
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end

local list = {}
for _, def in Cosmetics.list do
	table.insert(list, { id = def.id, name = def.name, category = def.category, rarity = def.rarity, source = def.source or "", look = def.look })
end
local pips = {}
for i = 1, 6 do
	pips[i] = PawnPatterns.pips[i]
end
local patterns = {}
for k, v in pairs(PawnPatterns) do
	if k ~= "pips" then
		patterns[k] = v
	end
end
local chests = {}
for _, c in Gacha.chests do
	table.insert(chests, { id = c.id, name = c.name, price = c.price, look = c.look, odds = Gacha.odds(c, false), lucky = Gacha.odds(c, true) })
end
print('{"items":' .. enc(list) .. ',"rarities":' .. enc(Cosmetics.rarities) .. ',"patterns":' .. enc(patterns) .. ',"pips":' .. enc(pips) .. ',"icons":' .. enc(IconData) .. ',"chests":' .. enc(chests) .. "}")
