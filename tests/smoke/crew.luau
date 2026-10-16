--[[
	The six characters in a row (and a few wearing accessory packs), large: for checking
	the character art quickly. tools/shots.sh crew.
]]

local F = Fake
F.mount(F.ReplicatedStorage, "Shared", getNode("Shared"))
F.setScreen({ w = 1500, h = 760 })
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

local CosmeticArt = requireModule("Client/UI/CosmeticArt")
local Icons = requireModule("Client/UI/Icons")
local ids = { "mage", "trapper", "fire_starter", "naturalist", "warper", "overseer" }
local packs = { "acc_gentleman", "acc_captain", "acc_parrot", "acc_propeller", "acc_kraken", "acc_gulls" }
local moods = { "happy", "shock", "angry", "sad", "dizzy", "smug" }
for i, id in ids do
	local x = 20 + (i - 1) * 245
	CosmeticArt.character(bg, id, nil, { Position = UDim2.fromOffset(x, 10), Size = UDim2.fromOffset(230, 230) })
	CosmeticArt.character(bg, id, packs[i], { Position = UDim2.fromOffset(x, 260), Size = UDim2.fromOffset(150, 150) })
	CosmeticArt.character(bg, id, nil, { Position = UDim2.fromOffset(x + 140, 300) , Size = UDim2.fromOffset(100, 100) }, moods[i])
	Icons.medallion(bg, id, Color3.fromHex("2B4C7E"), { AnchorPoint = Vector2.zero, Position = UDim2.fromOffset(x + 60, 440), Size = UDim2.fromOffset(90, 90) })
	-- board size
	CosmeticArt.character(bg, id, nil, { Position = UDim2.fromOffset(x + 70, 560), Size = UDim2.fromOffset(60, 60) })
end
F.run(0.3)
F.shot("crew")
