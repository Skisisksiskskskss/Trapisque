--[[
	The maps on their own (no match): every map, lying down and stood up for upright
	phones, with a few tokens, hazards and pieces on it (in a few finishes, two on their
	mastery stands). For checking the map art quickly: tools/shots.sh boards. SMOKE.only
	picks one map and SMOKE.orient ("flat", "upright" or "both") which way it lies.
]]

local F = Fake
local cfg = SMOKE or {}

F.mount(F.ReplicatedStorage, "Shared", getNode("Shared"))
F.setScreen({ w = cfg.w or 1600, h = cfg.h or 900 })
local player = F.addPlayer("Tester", 4242)
F.run(0.2)
local gui = Instance.new("ScreenGui")
gui.Name = "Boards"
gui.IgnoreGuiInset = true
gui.Parent = player:FindFirstChild("PlayerGui")

requireModule("Client/UI/Art").localSheets = true
local BoardView = requireModule("Client/UI/Match/BoardView")
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")
local Theme = requireModule("Client/UI/Theme")

local characters = { "mage", "trapper", "fire_starter", "naturalist", "warper", "overseer", "gambler", "cannoneer" }
for _, def in Maps.list do
	for _, rotate in { false, true } do
		local orient = cfg.orient or "both"
		if (cfg.only == nil or cfg.only == def.id) and (orient == "both" or (orient == "upright") == rotate) then
			local w, h = if rotate then 520 else (cfg.w or 1600), if rotate then 900 else (cfg.h or 900)
			F.setScreen({ w = w, h = h })
			local holder = Instance.new("Frame")
			holder.Name = "Holder"
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromScale(1, 1)
			holder.Parent = gui
			local view = BoardView.new(holder, def.id, { rotate = rotate, mySeat = 1 })
			view:setFocus({ x = 20, y = 20, w = w - 40, h = h - 40 }, true)
			local board = Board.get(def)
			local snap: any = { players = {}, tokens = {}, placed = {}, natural = {}, embers = {} }
					-- the newest maps' own things: the Kraken's mark, the drawbridges (one up, one
			-- down) and the cogs
			local reserved = {}
			if def.kraken then
				snap.kraken = { tile = 12, zone = { 11, 12, 13 } }
			end
			if def.drawbridges then
				snap.bridges = {}
				for i, tiles in def.drawbridges do
					table.insert(snap.bridges, { tiles = tiles, up = i == 1 })
					for _, t in tiles do
						reserved[t] = true
					end
				end
			end
			snap.gears = def.gears
			for _, t in (snap.kraken and snap.kraken.zone) or {} do
				reserved[t] = true
			end
			for _, t in def.gears or {} do
				reserved[t] = true
			end
			local seats = {}
			for i = 1, 4 do
				seats[i] = characters[((i + #def.id) % 8) + 1]
			end
			Theme.setSeatCharacters(seats)
			for i, spot in board.tokenSpots do
				if i % 2 == 1 and not reserved[spot] then
					table.insert(snap.tokens, { tile = spot, kind = ({ "trap", "assist", "neutral", "potion", "coin" })[(i % 5) + 1] })
				end
			end
			for tile, kind in board.naturalInit do
				table.insert(snap.natural, { tile = tile, kind = kind })
			end
			-- Frostbite Floes: one floe of thin ice cracked, one given way
			table.sort(snap.natural, function(a, b)
				return a.tile < b.tile
			end)
			local ice = {}
			for _, n in snap.natural do
				if n.kind == "thinice" then
					table.insert(ice, n)
				end
			end
			if ice[2] then
				snap.cracks = { ice[2].tile }
			end
			if ice[3] then
				ice[3].kind = "hole"
			end
			-- board pieces and hidden traps this player can see (theirs, and one a teammate
			-- hid), on tiles with nothing else on them
			local used = { [1] = true, [5] = true, [14] = true }
			for t in reserved do
				used[t] = true
			end
			for _, t in snap.tokens do
				used[t.tile] = true
			end
			for _, n in snap.natural do
				used[n.tile] = true
			end
			-- (the first plain tile from there with `n` plain ones in a row, for a belt)
			local function free(from: number, n: number?): number?
				local function plain(t: number): boolean
					local tile = board.tiles[t]
					return tile ~= nil and tile.kind == "normal" and not used[t]
				end
				for t = from, board.totalTiles do
					local ok = true
					for k = 0, (n or 1) - 1 do
						ok = ok and plain(t + k)
					end
					if ok then
						for k = 0, (n or 1) - 1 do
							used[t + k] = true
						end
						return t
					end
				end
				return nil
			end
			for _, p in { { 9, "wall", 2 }, { 16, "teleporter", 3 }, { 23, "sands", 2 }, { 33, "spore_warper", 4 } } do
				local t = free(p[1])
				if t then
					table.insert(snap.placed, { tile = t, item = p[2], owner = p[3] })
				end
			end
			local beltAt = free(26, 3)
			if beltAt then
				table.insert(snap.placed, { tile = beltAt, item = "conveyor", owner = 3, dir = "forward", tiles = { beltAt, beltAt + 1, beltAt + 2 } })
			end
			snap.traps = {}
			for _, p in { { 7, "banana", 1 }, { 11, "spike", 1 }, { 19, "grog", 3 }, { 30, "ice", 1 } } do
				local t = free(p[1])
				if t then
					table.insert(snap.traps, { tile = t, item = p[2], owner = p[3] })
				end
			end
			local burning = free(13)
			if burning then
				table.insert(snap.embers, { tile = burning, owner = 2 })
			end
			for i = 1, 4 do
				table.insert(snap.players, { seat = i, character = seats[i], tile = ({ 1, 1, 5, 14 })[i], name = "P" .. i })
			end
			local looks = { { finish = "fin_gold", base = 2 }, { finish = "fin_marble", base = 1 }, {}, { finish = "fin_glass" } }
			for i, pl in snap.players do
				view:addPawn(i, { character = pl.character, name = pl.name, tagName = if i == 1 then "You" else pl.name, look = looks[i] }, pl.tile)
			end
			view:applySnapshot(snap)
			view:setCurrent(1)
			F.run(0.5)
			F.shot("board-" .. def.id .. (if rotate then "-upright" else ""))
			holder:Destroy()
		end
	end
end
