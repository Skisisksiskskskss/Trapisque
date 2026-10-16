--[[
	Loading
	A Trapisque splash (the night-purple table, the title in candy lettering and two
	dice tumbling) shown while the game streams in, instead of Roblox's default loading
	screen. Plain frames only: it runs from ReplicatedFirst before any of the game's
	modules exist, so its few colours are copied from Theme.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local TABLE = Color3.fromHex("1F1438") -- Theme bg
local DOTS = Color3.fromHex("2B1D4D") -- Theme panel
local LINE = Color3.fromHex("1B1030") -- the sticker outline
local CREAM = Color3.fromHex("FFF4E2")
local SUN = Color3.fromHex("FFD23F")
local LAVENDER = Color3.fromHex("CBBDF0")

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
-- a scatter of soft dots on the table
for i = 0, 23 do
	local dot = Instance.new("Frame")
	dot.BackgroundColor3 = DOTS
	dot.BorderSizePixel = 0
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(((i * 37) % 100) / 100, ((i * 61 + 13) % 100) / 100)
	dot.Size = UDim2.fromScale(0.05 + (i % 3) * 0.02, 0.05 + (i % 3) * 0.02)
	dot.SizeConstraint = Enum.SizeConstraint.RelativeYY
	dot.Parent = bg
	Instance.new("UICorner", dot).CornerRadius = UDim.new(0.5, 0)
end

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.34)
title.Size = UDim2.fromScale(0.6, 0.15)
title.Font = Enum.Font.LuckiestGuy
title.Text = "TRAPISQUE"
title.TextScaled = true
title.TextColor3 = SUN
title.Rotation = -3
title.Parent = bg
local outline = Instance.new("UIStroke")
outline.Color = LINE
outline.Thickness = 5
outline.Parent = title

-- two candy dice tumbling side by side
local PIPS = {
	{ { 0.5, 0.5 } },
	{ { 0.28, 0.28 }, { 0.72, 0.72 } },
	{ { 0.28, 0.28 }, { 0.5, 0.5 }, { 0.72, 0.72 } },
	{ { 0.28, 0.28 }, { 0.72, 0.28 }, { 0.28, 0.72 }, { 0.72, 0.72 } },
	{ { 0.28, 0.28 }, { 0.72, 0.28 }, { 0.5, 0.5 }, { 0.28, 0.72 }, { 0.72, 0.72 } },
	{ { 0.28, 0.25 }, { 0.72, 0.25 }, { 0.28, 0.5 }, { 0.72, 0.5 }, { 0.28, 0.75 }, { 0.72, 0.75 } },
}
-- the pair is sized by the screen's height and spaced inside its own box, so they
-- keep their gap on a wide monitor and on a phone held upright alike
local pair = Instance.new("Frame")
pair.Name = "Dice"
pair.BackgroundTransparency = 1
pair.AnchorPoint = Vector2.new(0.5, 0.5)
pair.Position = UDim2.fromScale(0.5, 0.56)
pair.Size = UDim2.fromScale(0.24, 0.1)
pair.SizeConstraint = Enum.SizeConstraint.RelativeYY
pair.Parent = bg
local dice = {}
for i, x in { 0.2, 0.8 } do
	local die = Instance.new("Frame")
	die.Name = "Die" .. i
	die.BackgroundColor3 = CREAM
	die.BorderSizePixel = 0
	die.AnchorPoint = Vector2.new(0.5, 0.5)
	die.Position = UDim2.fromScale(x, 0.5)
	die.Size = UDim2.fromScale(1, 1)
	die.SizeConstraint = Enum.SizeConstraint.RelativeYY
	die.Parent = pair
	Instance.new("UICorner", die).CornerRadius = UDim.new(0.22, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = LINE
	stroke.Thickness = 4
	stroke.Parent = die
	local pips = Instance.new("Frame")
	pips.Name = "Pips"
	pips.BackgroundTransparency = 1
	pips.Size = UDim2.fromScale(1, 1)
	pips.Parent = die
	dice[i] = { frame = die, pips = pips }
end
local function showFace(d, n: number)
	for _, child in d.pips:GetChildren() do
		child:Destroy()
	end
	for _, at in PIPS[n] do
		local pip = Instance.new("Frame")
		pip.BackgroundColor3 = LINE
		pip.BorderSizePixel = 0
		pip.AnchorPoint = Vector2.new(0.5, 0.5)
		pip.Position = UDim2.fromScale(at[1], at[2])
		pip.Size = UDim2.fromScale(0.18, 0.18)
		pip.Parent = d.pips
		Instance.new("UICorner", pip).CornerRadius = UDim.new(0.5, 0)
	end
end
showFace(dice[1], 5)
showFace(dice[2], 2)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.fromScale(0.5, 0.68)
status.Size = UDim2.fromScale(0.5, 0.04)
status.Font = Enum.Font.Nunito
status.Text = "Setting up the board..."
status.TextScaled = true
status.TextColor3 = LAVENDER
status.Parent = bg

gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local spinning = true
task.spawn(function()
	-- the dice tumble, land, rest a moment, and roll again
	while spinning do
		for _ = 1, 8 do
			for _, d in dice do
				showFace(d, math.random(1, 6))
				d.frame.Rotation = math.random(-25, 25)
			end
			task.wait(0.07)
		end
		for _, d in dice do
			d.frame.Rotation = 0
		end
		task.wait(0.9)
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
