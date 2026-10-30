--[[
	The eight playing pieces and emblems, large: for checking the character art quickly.
	Each column: the painted piece, the same piece in a finish, the three emblems
	(classic, Ghost Crew, Gilded), and the piece at the size it stands on the board.
	tools/shots.sh crew.
]]

local F = Fake
F.mount(F.ReplicatedStorage, "Shared", getNode("Shared"))
F.setScreen({ w = 1500, h = 900 })
local player = F.addPlayer("Tester", 4242)
F.run(0.2)
local gui = Instance.new("ScreenGui")
gui.Name = "Crew"
gui.IgnoreGuiInset = true
gui.Parent = player:FindFirstChild("PlayerGui")
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromHex("F3E6C8")
bg.Parent = gui

requireModule("Client/UI/Art").localSheets = true
local PieceArt = requireModule("Client/UI/PieceArt")
local Icons = requireModule("Client/UI/Icons")
local Cosmetics = requireModule("Shared/Meta/Cosmetics")
local ids = { "mage", "trapper", "fire_starter", "naturalist", "warper", "overseer", "gambler", "cannoneer" }
local finishes = Cosmetics.byCategory.finish
for i, id in ids do
	local x = 20 + (i - 1) * 184
	PieceArt.icon(bg, id, nil, { Position = UDim2.fromOffset(x + 10, 10), Size = UDim2.fromOffset(160, 200) })
	PieceArt.icon(bg, id, finishes[(i % #finishes) + 2].id, { Position = UDim2.fromOffset(x + 40, 230), Size = UDim2.fromOffset(100, 125) })
	Icons.emblem(bg, id, { AnchorPoint = Vector2.zero, Position = UDim2.fromOffset(x + 20, 370), Size = UDim2.fromOffset(140, 140) })
	Icons.emblem(bg, id .. ":ghost", { AnchorPoint = Vector2.zero, Position = UDim2.fromOffset(x + 14, 530), Size = UDim2.fromOffset(74, 74) })
	Icons.emblem(bg, id .. ":gilded", { AnchorPoint = Vector2.zero, Position = UDim2.fromOffset(x + 96, 530), Size = UDim2.fromOffset(74, 74) })
	-- board size
	PieceArt.icon(bg, id, nil, { Position = UDim2.fromOffset(x + 66, 640), Size = UDim2.fromOffset(48, 60) })
end
F.run(0.3)
F.shot("crew")
