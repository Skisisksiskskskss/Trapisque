-- Dumps a mid-game board scene per map as JSON (used by tools/preview/board.py)
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")
local Rng = requireModule("Shared/Game/Rng")
local Engine = requireModule("Shared/Game/Engine")
local Bot = requireModule("Shared/Game/Bot")
local BoardLayout = requireModule("Client/UI/Match/BoardLayout")
local IconData = requireModule("Client/UI/IconData")
local DecorData = requireModule("Client/UI/DecorData")

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

local scenes = {}
for i, def in Maps.list do
	local board = Board.get(def)
	local layout = BoardLayout.build(board, def, Rng)
	local players = {}
	for s = 1, 4 do
		players[s] = { id = "b" .. s, name = "Bot " .. s, isBot = true }
	end
	local g = Engine.new({ mode = "chaos", map = def.id, players = players, seed = 40 + i, target = 3 })
	g:start()
	for _ = 1, 70 do
		local cmd = Bot.decide(g, g.current)
		local ok = cmd and g:command(g.current, cmd)
		if not ok then
			g:autoAct()
		end
		if g.phase == "over" then
			break
		end
	end
	table.insert(scenes, { layout = layout, snapshot = g:snapshot(1) })
end
print('{"scenes":' .. enc(scenes) .. ',"icons":' .. enc(IconData) .. ',"decor":' .. enc(DecorData) .. "}")
