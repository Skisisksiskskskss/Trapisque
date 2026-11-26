--[[
	Backdrop: full-screen graph paper behind everything. In menus it shows the
	original title-screen animation (a row of bouncing pastel birds and drifting
	specks); during matches it dims to frame the arena.
]]

local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)

local Backdrop = {}
Backdrop.__index = Backdrop

function Backdrop.new(gui: ScreenGui)
	local self = setmetatable({}, Backdrop)
	local root = Instance.new("Frame")
	root.Name = "Paper"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.Paper
	root.BorderSizePixel = 0
	root.Parent = gui
	self.root = root

	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Theme.Paper, Theme.PaperDark)
	g.Rotation = 90
	g.Parent = root

	-- grid every 30 px
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromScale(1, 1)
	grid.Parent = root
	for i = 0, 80 do
		local v = Instance.new("Frame")
		v.BorderSizePixel = 0
		v.BackgroundColor3 = Color3.new(0, 0, 0)
		v.BackgroundTransparency = 0.97
		v.Size = UDim2.new(0, 2, 1, 0)
		v.Position = UDim2.new(0, i * 30, 0, 0)
		v.Parent = grid
		local h = Instance.new("Frame")
		h.BorderSizePixel = 0
		h.BackgroundColor3 = Color3.new(0, 0, 0)
		h.BackgroundTransparency = 0.97
		h.Size = UDim2.new(1, 0, 0, 2)
		h.Position = UDim2.new(0, 0, 0, i * 30)
		h.Parent = grid
	end

	-- bouncing birds (title animation from the original menu)
	self.birds = {}
	self.parts = {} -- per bird: the pieces whose transparency fades in quiet mode
	self.fade = 0
	self.fadeTarget = 0
	local deco = Instance.new("Frame")
	deco.BackgroundTransparency = 1
	deco.Size = UDim2.fromScale(1, 1)
	deco.Parent = root
	self.deco = deco
	for i = 0, 11 do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Size = UDim2.fromOffset(26, 26)
		b.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = b
		local s = Instance.new("UIStroke")
		s.Thickness = 2
		s.Color = Theme.Ink
		s.Parent = b
		local eye = Instance.new("Frame")
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Size = UDim2.fromScale(0.3, 0.3)
		eye.Position = UDim2.fromScale(0.72, 0.4)
		eye.BackgroundColor3 = Color3.new(1, 1, 1)
		eye.BorderSizePixel = 0
		local ec = Instance.new("UICorner")
		ec.CornerRadius = UDim.new(0.5, 0)
		ec.Parent = eye
		local pupil = eye:Clone()
		pupil.Size = UDim2.fromScale(0.5, 0.5)
		pupil.Position = UDim2.fromScale(0.62, 0.5)
		pupil.BackgroundColor3 = Theme.Ink
		pupil.Parent = eye
		eye.Parent = b
		local wing = Instance.new("Frame")
		wing.AnchorPoint = Vector2.new(0.5, 0.5)
		wing.Size = UDim2.fromScale(0.42, 0.55)
		wing.Position = UDim2.fromScale(0.38, 0.62)
		wing.Rotation = 45
		wing.BackgroundColor3 = Color3.new(1, 1, 1)
		wing.BorderSizePixel = 0
		local wc = Instance.new("UICorner")
		wc.CornerRadius = UDim.new(0.5, 0)
		wc.Parent = wing
		local ws = Instance.new("UIStroke")
		ws.Thickness = 1.5
		ws.Color = Theme.Ink
		ws.Parent = wing
		wing.Parent = b
		b.Parent = deco
		self.birds[i + 1] = b
		self.parts[i + 1] = { fills = { b, eye, pupil, wing }, strokes = { s, ws } }
	end
	self.specks = {}
	for i = 1, 20 do
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Size = UDim2.fromOffset(4, 4)
		d.BackgroundColor3 = Color3.new(0, 0, 0)
		d.BackgroundTransparency = 0.9
		d.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = d
		d.Parent = deco
		self.specks[i] = d
	end

	self.dim = Instance.new("Frame")
	self.dim.BackgroundColor3 = Theme.Letterbox
	self.dim.BackgroundTransparency = 1
	self.dim.BorderSizePixel = 0
	self.dim.Size = UDim2.fromScale(1, 1)
	self.dim.ZIndex = 5
	self.dim.Parent = root

	self.menu = true
	RunService.RenderStepped:Connect(function()
		if self.menu then
			self:animate(os.clock())
		end
	end)
	return self
end

function Backdrop:animate(t: number)
	-- quiet mode: fade the hopping birds behind content screens so text stays readable
	if math.abs(self.fadeTarget - self.fade) > 0.002 then
		self.fade += (self.fadeTarget - self.fade) * 0.15
		for _, parts in self.parts do
			for _, f in parts.fills do
				f.BackgroundTransparency = self.fade
			end
			for _, st in parts.strokes do
				st.Transparency = self.fade
			end
		end
	end
	for i, b in self.birds do
		local k = i - 1
		local x = (k / 12) + 1 / 24
		local bounce = math.abs(math.sin(t * 3 + k * 0.5))
		-- hop along the bottom of the screen (squish when landing), clear of the logo
		b.Position = UDim2.new(x, 0, 0.94, -bounce * 60)
		local squish = 1 + (1 - bounce) * 0.3
		local size = 24 + math.sin(t * 2 + k) * 5
		b.Size = UDim2.fromOffset(size / squish, size * squish)
		b.Rotation = math.deg(math.sin(t + k * 0.3) * 0.2)
		b.BackgroundColor3 = Color3.fromHSV(((t * 30 + k * 30) % 360) / 360, 0.35, 1)
	end
	for i, d in self.specks do
		local px = (math.sin(t * 0.5 + i) * 0.5 + 0.5)
		local py = ((t * 20 + i * 30) % 900) / 900
		d.Position = UDim2.fromScale(px, py)
		d.BackgroundTransparency = 0.88 - math.sin(t * 2 + i) * 0.05
	end
end

-- quiet = true behind screens with text (everything except the title screen)
function Backdrop:setQuiet(quiet: boolean)
	self.fadeTarget = if quiet then 0.8 else 0
end

function Backdrop:setMenuMode(menu: boolean)
	self.menu = menu
	self.deco.Visible = menu
	self.dim.BackgroundTransparency = if menu then 1 else 0.06
end

return Backdrop
