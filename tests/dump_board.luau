-- Dumps a mid-game board scene per map as JSON (used by tools/preview/board.py).
-- Bundle after tests/preview_skins.luau (it records the tile skins).
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")
local Rng = requireModule("Shared/Game/Rng")
local Engine = requireModule("Shared/Game/Engine")
local Bot = requireModule("Shared/Game/Bot")
local BoardLayout = requireModule("Client/UI/Match/BoardLayout")
local IconData = requireModule("Client/UI/IconData")
local DecorData = requireModule("Client/UI/DecorData")
local PawnPatterns = requireModule("Client/UI/PawnPatterns")
local Cosmetics = requireModule("Shared/Meta/Cosmetics")

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
	local snap = g:snapshot(1)
	-- what each tile is reskinned as (recorded from the game's TileSkins)
	local pos, belt, skins = {}, {}, {}
	for _, t in layout.tiles do
		pos[t.id] = { t.x, t.y }
	end
	for _, e in snap.placed do
		if e.item == "conveyor" and e.tiles then
			for k, t in e.tiles do
				local from, to = t, e.tiles[k + 1]
				if not to then
					from, to = e.tiles[k - 1] or t, t
				end
				belt[t] = math.deg(math.atan2(pos[to][2] - pos[from][2], pos[to][1] - pos[from][1])) + (if e.dir == "back" then 180 else 0)
			end
		end
	end
	local function addSkin(tile, kind)
		skins[tostring(tile)] = { kind = kind, top = SkinTop(kind), ops = RecordSkin(kind, false, BoardLayout.Style.tileScale / 2, belt[tile]) }
	end
	for _, e in snap.placed do
		if e.item ~= "conveyor" then
			addSkin(e.tile, e.item)
		end
	end
	for t in belt do
		addSkin(t, "conveyor")
	end
	for _, n in snap.natural do
		addSkin(n.tile, n.kind)
	end
	table.insert(scenes, { layout = layout, snapshot = snap, skins = skins })
end
-- pawn skins used in the preview (seat -> skin), plus everything needed to draw them
local skins = { "pawn_classic", "pawn_ocean", "pawn_bee", "pawn_galaxy" }
local looks = {}
for _, id in skins do
	looks[id] = Cosmetics.get(id).look
end
local patterns = {}
for k, v in pairs(PawnPatterns) do
	if k ~= "pips" then
		patterns[k] = v
	end
end
local slots = {}
for n, layout in BoardLayout.PawnSlots do
	local list = {}
	for i, p in ipairs(layout) do
		list[i] = p
	end
	slots[n] = { scale = layout.scale, at = list }
end
print('{"scenes":' .. enc(scenes) .. ',"icons":' .. enc(IconData) .. ',"decor":' .. enc(DecorData)
	.. ',"skins":' .. enc(skins) .. ',"looks":' .. enc(looks) .. ',"patterns":' .. enc(patterns)
	.. ',"slots":' .. enc(slots) .. "}")
