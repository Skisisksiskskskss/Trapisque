--[[
	Root
	The single ScreenGui everything lives in. It hides Roblox's own UI, sizes a virtual
	stage for the screen it's on (Layout.metrics: PC, landscape phone or upright phone),
	measures the safe area and Roblox's top bar so nothing sits under them, draws the
	wooden tabletop background and switches between screens with animated transitions.

	Layers (bottom to top): Background, Screens, Overlay, Popups, Toasts

		Root.metrics        the current Layout metrics (vw, vh, scale, form, touch, safe, topbar)
		Root.onResize(fn)   fn(vw, vh, metrics) now and whenever the screen changes
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)
local Layout = require(script.Parent.Layout)

local C = Theme.C

local Root = {}

local player = Players.LocalPlayer
local current = nil -- { name, frame, destroy }
local resizeCallbacks = {}

Root.metrics = Layout.metrics(1280, 720)
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

-- A full-screen frame in its own ScreenGui with the given insets, to read where the
-- engine thinks the safe area is (works the same on every device and orientation).
local function probe(playerGui: Instance, insets: string): Frame?
	local ok, frame = pcall(function()
		local g = Instance.new("ScreenGui")
		g.Name = "InsetProbe_" .. insets
		g.ResetOnSpawn = false
		g.DisplayOrder = -100
		g.IgnoreGuiInset = false
		;(g :: any).ScreenInsets = (Enum.ScreenInsets :: any)[insets]
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(1, 1)
		f.Parent = g
		g.Parent = playerGui
		return f
	end)
	return if ok then frame else nil
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
	-- the whole screen, for measuring against the probes
	local full = Util.frame(gui, { Name = "Full", ZIndex = 0 })

	local stage = Util.frame(gui, { Name = "Stage", ZIndex = 1 })
	Root.stage = stage
	Root.uiScale = Util.new("UIScale", { Parent = stage })

	Root.screens = layer("Screens", 1)
	Root.overlay = layer("Overlay", 2)
	Root.popups = layer("Popups", 3)
	Root.toasts = layer("Toasts", 4)
	Widgets.setToastLayer(Root.toasts)

	local deviceProbe = probe(playerGui, "DeviceSafeInsets")
	local camera = workspace.CurrentCamera

	local function resize()
		local abs = full.AbsoluteSize
		local vp = if abs.X > 2 and abs.Y > 2 then abs else camera.ViewportSize
		if vp.X < 2 or vp.Y < 2 then
			return
		end
		-- device safe area (notch, home bar), measured against our full-screen frame
		local safe = { l = 0, t = 0, r = 0, b = 0 }
		if deviceProbe and deviceProbe.AbsoluteSize.X > 2 then
			local fp, fs = full.AbsolutePosition, full.AbsoluteSize
			local dp, ds = deviceProbe.AbsolutePosition, deviceProbe.AbsoluteSize
			safe.l = math.max(0, dp.X - fp.X)
			safe.t = math.max(0, dp.Y - fp.Y)
			safe.r = math.max(0, (fp.X + fs.X) - (dp.X + ds.X))
			safe.b = math.max(0, (fp.Y + fs.Y) - (dp.Y + ds.Y))
		end
		-- Roblox's top bar: its height and the free stretch between its buttons
		local topbar = { y0 = 0, y1 = 58, l = 120, r = vp.X - 60 }
		local okBar, bar = pcall(function()
			return (GuiService :: any).TopbarInset
		end)
		if okBar and typeof(bar) == "Rect" and bar.Max.Y > 0 then
			topbar = { y0 = bar.Min.Y, y1 = bar.Max.Y, l = bar.Min.X, r = if bar.Max.X > bar.Min.X then bar.Max.X else vp.X }
		end
		local insetTop = GuiService:GetGuiInset()
		topbar.y1 = math.max(topbar.y1, insetTop.Y)
		local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		local m = Layout.metrics(vp.X, vp.Y, { touch = touch, safe = safe, topbar = topbar })
		Root.metrics = m
		Root.scale = m.scale
		Root.vw = m.vw
		Root.vh = m.vh
		stage.Size = UDim2.fromOffset(m.vw, m.vh)
		Root.uiScale.Scale = m.scale
		Widgets.setMetrics(m)
		for _, fn in resizeCallbacks do
			task.spawn(fn, m.vw, m.vh, m)
		end
	end
	-- changes settle over a frame or two (rotation, window drags): coalesce them
	local pending = false
	local function schedule()
		if pending then
			return
		end
		pending = true
		task.defer(function()
			pending = false
			resize()
		end)
	end
	full:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(schedule)
	if deviceProbe then
		deviceProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule)
		deviceProbe:GetPropertyChangedSignal("AbsolutePosition"):Connect(schedule)
	end
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(schedule)
	end)
	UserInputService.LastInputTypeChanged:Connect(function()
		local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		if touch ~= Root.metrics.touch then
			schedule()
		end
	end)
	resize()
	-- the camera can be swapped out; keep listening
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		camera = workspace.CurrentCamera
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(schedule)
		schedule()
	end)
end

function Root.onResize(fn: (number, number, any) -> ()): () -> ()
	table.insert(resizeCallbacks, fn)
	task.spawn(fn, Root.vw, Root.vh, Root.metrics)
	return function()
		local i = table.find(resizeCallbacks, fn)
		if i then
			table.remove(resizeCallbacks, i)
		end
	end
end

-- Where content may start below Roblox's top bar (stage pixels).
function Root.topInset(): number
	local m = Root.metrics
	return math.max(m.topbar.y1, m.safe.t) + 8
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
		color = C.text,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 50),
		anchor = Vector2.new(0.5, 0),
		position = UDim2.fromScale(0.5, 0.56),
		z = 501,
	})
end

return Root
