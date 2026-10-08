--[[
	Root
	The single ScreenGui everything lives in. It hides Roblox's own UI, scales a
	virtual 1280x720-ish stage to any screen, draws the wooden tabletop background and
	switches between screens with animated transitions.

	Layers (bottom to top): Background, Screens, Overlay, Popups, Toasts
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local C = Theme.C

local Root = {}

local player = Players.LocalPlayer
local current = nil -- { name, frame, destroy }
local resizeCallbacks = {}

Root.vw = 1280
Root.vh = 720
Root.scale = 1

local function layer(name: string, z: number): Frame
	return Util.frame(Root.stage, { Name = name, ZIndex = z })
end

local function buildBackground(bg: Frame)
	bg.BackgroundTransparency = 0
	bg.BackgroundColor3 = C.table
	-- planks
	for i = 0, 14 do
		local plank = Util.new("Frame", {
			Name = "Plank",
			BackgroundColor3 = C.tablePlank,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, i / 14, 0),
			Size = UDim2.new(1, 0, 0, 3),
			ZIndex = 1,
			Parent = bg,
		})
		plank.Rotation = (math.random() - 0.5) * 0.3
	end
	Widgets.grain(bg, C.tableLight, 22)
end

function Root.init()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Util.new("ScreenGui", {
		Name = "Trapisque",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = playerGui,
	})
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.None
	end)
	Root.gui = gui

	Root.background = Util.frame(gui, { Name = "Background", ZIndex = 0 })
	buildBackground(Root.background)

	local stage = Util.frame(gui, { Name = "Stage", ZIndex = 1 })
	Root.stage = stage
	Root.uiScale = Util.new("UIScale", { Parent = stage })

	Root.screens = layer("Screens", 1)
	Root.overlay = layer("Overlay", 2)
	Root.popups = layer("Popups", 3)
	Root.toasts = layer("Toasts", 4)
	Widgets.setToastLayer(Root.toasts)

	local camera = workspace.CurrentCamera
	local function resize()
		local vp = camera.ViewportSize
		if vp.X < 2 or vp.Y < 2 then
			return
		end
		local targetH = if vp.Y < 520 then 600 else Theme.VirtualHeight
		local scale = math.min(vp.Y / targetH, vp.X / Theme.MinVirtualWidth)
		Root.scale = scale
		Root.vw = vp.X / scale
		Root.vh = vp.Y / scale
		stage.Size = UDim2.fromOffset(Root.vw, Root.vh)
		Root.uiScale.Scale = scale
		for _, fn in resizeCallbacks do
			task.spawn(fn, Root.vw, Root.vh)
		end
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	resize()
	-- the camera can be swapped out; keep listening
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		camera = workspace.CurrentCamera
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
		resize()
	end)
end

function Root.onResize(fn: (number, number) -> ()): () -> ()
	table.insert(resizeCallbacks, fn)
	task.spawn(fn, Root.vw, Root.vh)
	return function()
		local i = table.find(resizeCallbacks, fn)
		if i then
			table.remove(resizeCallbacks, i)
		end
	end
end

-- How much of the top of the screen Roblox's buttons cover (virtual pixels).
function Root.topInset(): number
	local ok, inset = pcall(function()
		return (GuiService :: any).TopbarInset
	end)
	if ok and typeof(inset) == "Rect" then
		return math.max(48, inset.Max.Y / Root.scale + 6)
	end
	return 56
end

--[[
	Shows a screen. `build(container)` creates its UI and may return a cleanup function.
	The old screen slides away, the new one rises in.
]]
function Root.show(name: string, build: (Frame) -> (() -> ())?)
	local old = current
	local frame = Util.frame(Root.screens, { Name = "Screen_" .. name })
	local group = Util.new("CanvasGroup", {
		Name = "Fade",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 1,
		Parent = frame,
	})
	local cleanup = nil
	local ok, err = pcall(function()
		cleanup = build(group)
	end)
	if not ok then
		warn("[Trapisque] screen '" .. name .. "' failed to build: " .. tostring(err))
	end
	current = { name = name, frame = frame, cleanup = cleanup }
	group.Position = UDim2.fromOffset(0, 24)
	Util.tween(group, 0.35, { GroupTransparency = 0, Position = UDim2.new() }, Enum.EasingStyle.Quint)
	-- once visible, drop the CanvasGroup's texture cost by re-parenting children
	task.delay(0.4, function()
		if group.Parent and current and current.frame == frame then
			for _, child in group:GetChildren() do
				child.Parent = frame
			end
		end
	end)
	if old then
		local oldGroup = Util.new("CanvasGroup", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = old.frame,
		})
		for _, child in old.frame:GetChildren() do
			if child ~= oldGroup then
				child.Parent = oldGroup
			end
		end
		Util.tween(oldGroup, 0.25, { GroupTransparency = 1, Position = UDim2.fromOffset(0, -18) })
		task.delay(0.26, function()
			if old.cleanup then
				pcall(old.cleanup)
			end
			old.frame:Destroy()
		end)
	end
end

function Root.currentName(): string?
	return current and current.name
end

-- Full-screen "teleporting" curtain with a spinning compass.
local curtain: Frame? = nil
function Root.curtain(message: string?)
	if not message then
		if curtain then
			local c = curtain
			curtain = nil
			Util.tween(c, 0.3, { BackgroundTransparency = 1 })
			for _, d in c:GetDescendants() do
				if d:IsA("TextLabel") then
					Util.tween(d, 0.3, { TextTransparency = 1 })
				end
			end
			task.delay(0.32, function()
				c:Destroy()
			end)
		end
		return
	end
	if curtain then
		local label = curtain:FindFirstChild("Message", true)
		if label then
			(label :: TextLabel).Text = message
		end
		return
	end
	local Icons = require(script.Parent.Icons)
	local c = Util.new("Frame", {
		Name = "Curtain",
		BackgroundColor3 = C.table,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 500,
		Parent = Root.popups,
	})
	curtain = c
	Util.tween(c, 0.3, { BackgroundTransparency = 0.05 })
	local compass = Icons.make(c, "compass", Icons.inkColors(C.brass, C.table), {
		Size = UDim2.fromOffset(110, 110),
		Position = UDim2.fromScale(0.5, 0.44),
		SizeConstraint = Enum.SizeConstraint.RelativeXY,
		ZIndex = 501,
	})
	task.spawn(function()
		while compass.Parent do
			compass.Rotation = (compass.Rotation + 3) % 360
			RunService.RenderStepped:Wait()
		end
	end)
	Widgets.label(c, {
		name = "Message",
		text = message,
		font = "display",
		size = 34,
		color = C.parchment,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 50),
		anchor = Vector2.new(0.5, 0),
		position = UDim2.fromScale(0.5, 0.56),
		z = 501,
	})
end

return Root
