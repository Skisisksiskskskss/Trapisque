-- Dumps items, characters, card style and icons for tools/preview/cards.py
local Items = requireModule("Shared/Game/Items")
local Characters = requireModule("Shared/Game/Characters")
local CardStyle = requireModule("Client/UI/CardStyle")
local IconData = requireModule("Client/UI/IconData")

local function enc(v)
	local t = type(v)
	if t == "number" then
		return string.format("%.6g", v)
	elseif t == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
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

local items = {}
for _, def in Items.list do
	table.insert(items, { id = def.id, name = def.name, category = def.category, use = def.use, text = def.text, price = def.price or 0 })
end
local chars = {}
for _, c in Characters.list do
	table.insert(chars, { id = c.id, name = c.name, tagline = c.tagline, passive = c.passive, ability = c.ability or false })
end
print('{"items":' .. enc(items) .. ',"characters":' .. enc(chars) .. ',"style":' .. enc(CardStyle) .. ',"icons":' .. enc(IconData) .. "}")
