--[[
	Loading
	A Trapisque splash (the wooden table, the title and a turning compass) shown while
	the game streams in, instead of Roblox's default loading screen. Plain frames only:
	it runs from ReplicatedFirst before any of the game's modules exist.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local TABLE = Color3.fromHex("2A1C13")
local PLANK = Color3.fromHex("221710")
local PARCHMENT = Color3.fromHex("F3E4C1")
local INK = Color3.fromHex("4A3020")
local BRASS = Color3.fromHex("E3B04B")
local RED = Color3.fromHex("B5372B")

local gui = Instance.new("ScreenGui")
gui.Name = "TrapisqueLoading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
pcall(function()
	(gui :: any).ScreenInsets = Enum.ScreenInsets.None
end)

local bg = Instance.new("Frame")
bg.Name = "Table"
bg.BackgroundColor3 = TABLE
bg.BorderSizePixel = 0
bg.Size = UDim2.fromScale(1, 1)
bg.Parent = gui
for i = 0, 14 do
	local plank = Instance.new("Frame")
	plank.BackgroundColor3 = PLANK
	plank.BackgroundTransparency = 0.2
	plank.BorderSizePixel = 0
	plank.Position = UDim2.fromScale(0, i / 14)
	plank.Size = UDim2.new(1, 0, 0, 3)
	plank.Parent = bg
end

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.36)
title.Size = UDim2.fromScale(0.6, 0.14)
title.Font = Enum.Font.Fondamento
title.Text = "Trapisque"
title.TextScaled = true
title.TextColor3 = PARCHMENT
title.Parent = bg
local outline = Instance.new("UIStroke")
outline.Color = INK
outline.Thickness = 3
outline.Parent = title

-- compass rose: a brass ring, four ink spokes and a red north needle
local compass = Instance.new("Frame")
compass.Name = "Compass"
compass.BackgroundTransparency = 1
compass.AnchorPoint = Vector2.new(0.5, 0.5)
compass.Position = UDim2.fromScale(0.5, 0.58)
compass.Size = UDim2.fromScale(0.1, 0.1)
compass.SizeConstraint = Enum.SizeConstraint.RelativeYY
compass.Parent = bg
local ring = Instance.new("Frame")
ring.BackgroundTransparency = 1
ring.Size = UDim2.fromScale(1, 1)
ring.Parent = compass
Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
local ringStroke = Instance.new("UIStroke")
ringStroke.Color = BRASS
ringStroke.Thickness = 4
ringStroke.Parent = ring
for _, rot in { 0, 90 } do
	local spoke = Instance.new("Frame")
	spoke.BackgroundColor3 = PARCHMENT
	spoke.BorderSizePixel = 0
	spoke.AnchorPoint = Vector2.new(0.5, 0.5)
	spoke.Position = UDim2.fromScale(0.5, 0.5)
	spoke.Size = UDim2.fromScale(0.08, 0.86)
	spoke.Rotation = rot
	spoke.Parent = compass
	Instance.new("UICorner", spoke).CornerRadius = UDim.new(0.5, 0)
end
local needle = Instance.new("Frame")
needle.BackgroundColor3 = RED
needle.BorderSizePixel = 0
needle.AnchorPoint = Vector2.new(0.5, 1)
needle.Position = UDim2.fromScale(0.5, 0.5)
needle.Size = UDim2.fromScale(0.1, 0.42)
needle.Parent = compass
Instance.new("UICorner", needle).CornerRadius = UDim.new(0.5, 0)
local hub = Instance.new("Frame")
hub.BackgroundColor3 = BRASS
hub.BorderSizePixel = 0
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Position = UDim2.fromScale(0.5, 0.5)
hub.Size = UDim2.fromScale(0.2, 0.2)
hub.Parent = compass
Instance.new("UICorner", hub).CornerRadius = UDim.new(0.5, 0)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.fromScale(0.5, 0.68)
status.Size = UDim2.fromScale(0.5, 0.04)
status.Font = Enum.Font.Nunito
status.Text = "Loading the treasure map..."
status.TextScaled = true
status.TextColor3 = PARCHMENT
status.TextTransparency = 0.2
status.Parent = bg

gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local spinning = true
task.spawn(function()
	while spinning do
		compass.Rotation = (compass.Rotation + 3) % 360
		task.wait()
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
-- hand over once the game's own UI is up (it shows its own "Unrolling the map...")
local playerGui = player:WaitForChild("PlayerGui")
local waited = 0
while not playerGui:FindFirstChild("Trapisque") and waited < 20 do
	waited += task.wait(0.1)
end
task.wait(0.2)

local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
for _, d in gui:GetDescendants() do
	if d:IsA("Frame") then
		TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("TextLabel") then
		TweenService:Create(d, info, { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, info, { Transparency = 1 }):Play()
	end
end
task.wait(0.4)
spinning = false
gui:Destroy()
