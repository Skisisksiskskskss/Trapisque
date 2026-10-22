--[[
	The experience's store art, drawn by the game's own UI code (no outside images):
	  store-icon     512 x 512    the Mage and the Fire Starter over the sea, and the name
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
local Icons = requireModule("Client/UI/Icons")
local Widgets = requireModule("Client/UI/Widgets")
local StickerArt = requireModule("Client/UI/StickerArt")
local CosmeticArt = requireModule("Client/UI/CosmeticArt")
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
	-- the Fire Starter (behind, right) and the Mage (in front, left), grinning
	Icons.sticker(bg, StickerArt.mascot("fire_starter", "cheeky", { bust = true }), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(330, 220),
		Size = UDim2.fromOffset(300, 300),
		ZIndex = 5,
	}, 0.04)
	Icons.sticker(bg, StickerArt.mascot("mage", "happy", { bust = true }), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(190, 230),
		Size = UDim2.fromOffset(320, 320),
		ZIndex = 8,
	}, 0.04)
	-- a gold die tumbling between them
	local die = Util.frame(bg, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(268, 360),
		Size = UDim2.fromOffset(92, 92),
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
	Icons.sticker(root, StickerArt.misc.chest, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(W / 2, 690),
		Size = UDim2.fromOffset(300, 300),
		ZIndex = 45,
	}, 0.05)
	for i, at in { { W / 2 - 205, 820, -16 }, { W / 2 + 205, 830, 12 } } do
		local die = Util.frame(root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(at[1], at[2]),
			Size = UDim2.fromOffset(120, 120),
			Rotation = at[3],
			ZIndex = 46,
		})
		CosmeticArt.preview(die, if i == 1 then "dice_doubloon" else "dice_ivory", nil, { Size = UDim2.fromScale(1, 1), ZIndex = 46 })
	end
	-- the whole crew, three either side
	local crew = {
		{ "mage", "happy", nil, 250 },
		{ "trapper", "cheeky", nil, 520 },
		{ "fire_starter", "happy", "acc_parrot", 770 },
		{ "naturalist", "happy", nil, 1150 },
		{ "warper", "smug", nil, 1400 },
		{ "overseer", "happy", nil, 1670 },
	}
	for i, c in crew do
		local size = 380
		CosmeticArt.character(root, c[1], c[3], {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(c[4], H - 18 + (if i == 2 or i == 5 then 14 else 0)),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 50 + i,
		}, c[2])
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
