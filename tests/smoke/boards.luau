--[[
	The maps on their own (no match): every map, lying down and stood up for upright
	phones, with a few tokens, hazards and pieces on it (in a few finishes, two on their
	mastery stands). For checking the map art quickly: tools/shots.sh boards.
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
		if cfg.only == nil or cfg.only == def.id then
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
			local snap = { players = {}, tokens = {}, placed = {}, natural = {}, embers = {} }
			local seats = {}
			for i = 1, 4 do
				seats[i] = characters[((i + #def.id) % 8) + 1]
			end
			Theme.setSeatCharacters(seats)
			for i, spot in board.tokenSpots do
				if i % 2 == 1 then
					table.insert(snap.tokens, { tile = spot, kind = ({ "trap", "assist", "neutral", "potion", "coin" })[(i % 5) + 1] })
				end
			end
			for tile, kind in board.naturalInit do
				table.insert(snap.natural, { tile = tile, kind = kind })
			end
			table.insert(snap.placed, { tile = 9, item = "wall", owner = 2 })
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
