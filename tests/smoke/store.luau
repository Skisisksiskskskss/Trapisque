--[[
	The experience's store art, drawn by the game's own UI code (no outside images):
	  store-icon     512 x 512    the Mage and the Fire Starter, face to face, and the name
	  store-banner   1920 x 1080  the island map, the title, the whole crew and a treasure
	  badges/<key>   512 x 512    each badge's medal (Shared/Meta/Badges), for the Creator
	                              Dashboard (Roblox shows a badge's picture in a circle)
	tools/shots.sh art (writes the icon and banner into OUT); tools/shots.sh badges.
]]

local F = Fake
F.mount(F.ReplicatedStorage, "Shared", getNode("Shared"))
F.setScreen({ w = 512, h = 512, inset = 0 })
local player = F.addPlayer("Tester", 4242)
F.run(0.2)

local Theme = requireModule("Client/UI/Theme")
local Util = requireModule("Client/UI/Util")
local Widgets = requireModule("Client/UI/Widgets")
local CosmeticArt = requireModule("Client/UI/CosmeticArt")
local Art = requireModule("Client/UI/Art")
local PieceArt = requireModule("Client/UI/PieceArt")
-- the illustrations come straight from the sheet files (art/sheets)
Art.localSheets = true
local BoardView = requireModule("Client/UI/Match/BoardView")
local Board = requireModule("Shared/Game/Board")
local Maps = requireModule("Shared/Game/Maps")

local C = Theme.C

local function screenGui(name: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.IgnoreGuiInset = true
	gui.Parent = player:FindFirstChild("PlayerGui")
	return gui
end

-- the plain sea the game's menus sit on
local function sea(parent: Instance, _w: number, _h: number, _marks: number)
	return Util.new("Frame", {
		Name = "Sea",
		BackgroundColor3 = C.bg,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
end

-- big title lettering (Roblox caps text at 100px, so it's scaled up as a whole)
local function title(parent: Instance, text: string, cx: number, cy: number, scale: number, z: number?)
	local holder = Util.frame(parent, {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(620, 120),
		ZIndex = z or 20,
	})
	Util.new("UIScale", { Scale = scale, Parent = holder })
	Widgets.label(holder, {
		text = text,
		font = "display",
		size = 100,
		color = C.textLight,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
		z = (z or 20) + 1,
	})
	return holder
end

local badgesOnly = SMOKE ~= nil and SMOKE.name == "badges"

---------------------------------------------------------------------------
-- icon
---------------------------------------------------------------------------
if not badgesOnly then
	F.setScreen({ w = 512, h = 512, inset = 0 })
	local gui = screenGui("Icon")
	local bg = sea(gui, 512, 512, 10)
	-- two of the crew's emblems, big enough to read at the size Roblox shows icons: the
	-- Fire Starter's flame (behind, right) and the Mage's snowflake (in front, left), each
	-- with its playing piece standing by it
	Art.label(bg, "emblems/fire_starter", Vector2.new(352, 196), 250, false, { ZIndex = 5, Rotation = 10 })
	Art.label(bg, "emblems/mage", Vector2.new(170, 232), 290, false, { ZIndex = 8, Rotation = -8 })
	PieceArt.icon(bg, "fire_starter", "fin_paint", { Position = UDim2.fromOffset(372, 250), Size = UDim2.fromOffset(110, 138), ZIndex = 9 })
	PieceArt.icon(bg, "mage", "fin_gold", { Position = UDim2.fromOffset(26, 262), Size = UDim2.fromOffset(110, 138), ZIndex = 10 })
	-- a band of shade the name sits on
	Util.new("Frame", {
		Name = "Band",
		BackgroundColor3 = C.bgDeep,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 404),
		Size = UDim2.fromOffset(512, 108),
		ZIndex = 25,
		Parent = bg,
	})
	-- a gold die tumbling in the corner
	local die = Util.frame(bg, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(446, 70),
		Size = UDim2.fromOffset(84, 84),
		Rotation = 14,
		ZIndex = 12,
	})
	CosmeticArt.preview(die, "dice_doubloon", nil, { Size = UDim2.fromScale(1, 1), ZIndex = 12 })
	-- the name along the bottom, as on the loading screen
	title(bg, "Trapisque", 256, 456, 0.9, 30)
	F.run(0.5)
	F.shot("store-icon")
	gui:Destroy()
end

---------------------------------------------------------------------------
-- banner
---------------------------------------------------------------------------
if not badgesOnly then
	local W, H = 1920, 1080
	F.setScreen({ w = W, h = H, inset = 0 })
	local gui = screenGui("Banner")
	local root = Util.new("Frame", {
		Name = "Root",
		BackgroundColor3 = C.bg,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	-- the island, filling the frame
	local holder = Util.frame(root, { Name = "Map", ZIndex = 1 })
	local def = Maps.get("blissful")
	local view = BoardView.new(holder, def.id, { mySeat = 1 })
	view:setFocus({ x = -140, y = -120, w = W + 280, h = H + 240 }, true)
	local board = Board.get(def)
	local snap = { players = {}, tokens = {}, placed = {}, natural = {}, embers = {} }
	for i, spot in board.tokenSpots do
		table.insert(snap.tokens, { tile = spot, kind = ({ "trap", "assist", "neutral", "potion", "coin" })[(i % 5) + 1] })
	end
	for tile, kind in board.naturalInit do
		table.insert(snap.natural, { tile = tile, kind = kind })
	end
	view:applySnapshot(snap)
	-- pushed back a little so the crew and the title stand out
	Util.new("Frame", {
		Name = "Shade",
		BackgroundColor3 = C.bgDeep,
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = root,
	})
	title(root, "Trapisque", W / 2, 180, 2.25, 40)
	Widgets.label(root, {
		text = "Race to the treasure. Hide traps. Bonk your friends.",
		font = "heavy",
		size = 44,
		color = C.textLightSoft,
		align = "center",
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromOffset(W / 2, 352),
		sizeUDim = UDim2.fromOffset(1200, 60),
		z = 41,
	})
	-- the treasure, with two dice
	Art.label(root, "items/chest", Vector2.new(W / 2, 650), 380, false, { ZIndex = 45 })
	for i, at in { { W / 2 - 200, 610, -16 }, { W / 2 + 200, 620, 12 } } do
		local die = Util.frame(root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(at[1], at[2]),
			Size = UDim2.fromOffset(120, 120),
			Rotation = at[3],
			ZIndex = 46,
		})
		CosmeticArt.preview(die, if i == 1 then "dice_doubloon" else "dice_ivory", nil, { Size = UDim2.fromScale(1, 1), ZIndex = 46 })
	end
	-- the whole crew along the bottom, four either side of the treasure: each one's
	-- playing piece standing in front of their emblem (the back row a little higher)
	local crew = { "mage", "trapper", "fire_starter", "naturalist", "warper", "overseer", "gambler", "cannoneer" }
	for i, id in crew do
		local left = i <= 4
		local k = if left then i - 1 else i - 5
		local x = if left then 130 + k * 190 else W - 130 - (3 - k) * 190
		local back = k % 2 == 1
		local y = H - (if back then 250 else 200)
		Art.label(root, "emblems/" .. id, Vector2.new(x, y), if back then 190 else 210, false, { ZIndex = if back then 50 else 60 })
		PieceArt.icon(root, id, if i == 3 then "fin_gold" else "fin_paint", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(x + 70, H - (if back then 40 else 10)),
			Size = UDim2.fromOffset(if back then 104 else 120, if back then 130 else 150),
			ZIndex = if back then 51 else 61,
		})
	end
	F.run(0.5)
	F.shot("store-banner")
	gui:Destroy()
end

---------------------------------------------------------------------------
-- badge icons
---------------------------------------------------------------------------
if badgesOnly then
	local Badges = requireModule("Shared/Meta/Badges")
	local BadgeArt = requireModule("Client/UI/BadgeArt")
	F.setScreen({ w = 512, h = 512, inset = 0 })
	for _, b in Badges.list do
		local gui = screenGui("Badge")
		local bg = sea(gui, 512, 512, 8)
		BadgeArt.medal(bg, b.key, true, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(256, 256),
			Size = UDim2.fromOffset(496, 496),
			ZIndex = 5,
		})
		F.run(0.2)
		F.shot("badges/" .. b.key)
		gui:Destroy()
	end
end
