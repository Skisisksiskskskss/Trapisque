-- Prints every board as JSON (used by tools/preview_maps.py)
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")

local function enc(v)
	local t = type(v)
	if t == "number" then
		return tostring(v)
	elseif t == "string" then
		return '"' .. v .. '"'
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "nil" then
		return "null"
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			local parts = {}
			for _, x in ipairs(v) do
				table.insert(parts, enc(x))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, x in pairs(v) do
			table.insert(parts, '"' .. tostring(k) .. '":' .. enc(x))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end

local out = {}
for _, def in Maps.list do
	local b = Board.get(def)
	local tiles = {}
	for _, t in b.tiles do
		table.insert(tiles, { id = t.id, q = t.q, r = t.r, x = t.x, y = t.y, kind = t.kind, branch = t.branch or 0, next = b.nextMain[t.id] or 0, shortcut = b.shortcut[t.id] or 0, dist = b.dist[t.id] or -1 })
	end
	local natural = {}
	for idx, kind in b.naturalInit do
		table.insert(natural, { tile = idx, kind = kind })
	end
	table.insert(out, { id = def.id, name = def.name, count = b.count, total = b.totalTiles, routeLength = b.routeLength, tiles = tiles, tokens = b.tokenSpots, natural = natural })
end
print(enc(out))
