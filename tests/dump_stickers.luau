-- Prints StickerArt as JSON for the offline preview (tools/preview/stickers.py)
local S = requireModule("Client/UI/StickerArt")
local Characters = requireModule("Shared/Game/Characters")

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
		local isArray = true
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
		local keys = {}
		for k in pairs(v) do
			if type(k) == "string" then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		for _, k in keys do
			table.insert(parts, '"' .. k .. '":' .. enc(v[k]))
		end
		if n > 0 then
			table.insert(parts, '"__args":[' .. table.concat(args, ",") .. "]")
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end

local mascots = {}
for _, id in Characters.ids do
	local moods = {}
	for _, m in { "default", "idle", "happy", "shock", "sad", "dizzy", "smug", "angry" } do
		moods[m] = S.mascot(id, if m == "default" then nil else m)
	end
	mascots[id] = moods
end
print(enc({
	cards = S.cards,
	tokens = S.tokens,
	hazards = S.hazards,
	misc = S.misc,
	mascots = mascots,
	palette = S.palette,
	body = S.bodyColor,
}))
