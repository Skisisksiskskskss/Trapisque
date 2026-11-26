--[[
	Widgets: the menu building blocks. Chunky pastel buttons with #222 ink
	outlines (the original's sketch style) that squish when pressed.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Widgets = {}

local INK = Theme.Ink

local function corner(f: GuiObject, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = f
	return c
end
Widgets.corner = corner

local function stroke(f: GuiObject, px: number, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = px
	s.Color = color or INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	return s
end
Widgets.stroke = stroke

function Widgets.pad(f: GuiObject, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = f
	return p
end

function Widgets.list(f: GuiObject, padding: number, horizontal: boolean?, align: Enum.HorizontalAlignment?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Center
	l.VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = f
	return l
end

function Widgets.grid(f: GuiObject, cell: UDim2, padding: number)
	local g = Instance.new("UIGridLayout")
	g.CellSize = cell
	g.CellPadding = UDim2.fromOffset(padding, padding)
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	return g
end

function Widgets.frame(parent: Instance?, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = if props.color then props.alpha or 0 else 1
	f.BackgroundColor3 = props.color or Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	f.Size = props.size or UDim2.fromScale(1, 1)
	f.Position = props.position or UDim2.new()
	f.AnchorPoint = props.anchor or Vector2.new()
	f.LayoutOrder = props.order or 0
	f.ZIndex = props.z or 1
	f.Name = props.name or "Frame"
	f.Visible = props.visible ~= false
	f.ClipsDescendants = props.clip == true
	if props.round then
		corner(f, props.round)
	end
	if props.stroke then
		stroke(f, props.stroke, props.strokeColor)
	end
	f.Parent = parent
	return f
end

function Widgets.label(parent: Instance?, props): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = props.size or UDim2.new(1, 0, 0, 30)
	t.Position = props.position or UDim2.new()
	t.AnchorPoint = props.anchor or Vector2.new()
	t.Font = props.font or Theme.FontTitle
	t.Text = props.text or ""
	t.TextColor3 = props.color or INK
	t.TextScaled = props.scaled ~= false
	t.TextSize = props.textSize or 20
	t.TextWrapped = true
	t.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	t.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	t.RichText = props.rich == true
	t.LayoutOrder = props.order or 0
	t.ZIndex = props.z or 2
	t.Name = props.name or "Label"
	if props.strokeColor then
		local s = Instance.new("UIStroke")
		s.Color = props.strokeColor
		s.Thickness = props.strokeThickness or 2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Parent = t
	end
	if props.maxText then
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = props.maxText
		c.Parent = t
	end
	t.Parent = parent
	return t
end

-- Squishy button --------------------------------------------------------------------------
function Widgets.button(parent: Instance?, props): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = props.color or Theme.White
	b.BorderSizePixel = 0
	b.Size = props.size or UDim2.new(1, 0, 0, 56)
	b.Position = props.position or UDim2.new()
	b.AnchorPoint = props.anchor or Vector2.new()
	b.LayoutOrder = props.order or 0
	b.ZIndex = props.z or 3
	b.Name = props.name or "Button"
	b.Text = ""
	corner(b, props.round or 14)
	stroke(b, props.strokeWidth or 3, props.strokeColor)
	local scale = Instance.new("UIScale")
	scale.Parent = b

	Widgets.label(b, {
		text = props.text or "",
		size = if props.sub then UDim2.new(0.9, 0, 0.5, 0) else UDim2.new(0.9, 0, 0.62, 0),
		position = if props.sub then UDim2.fromScale(0.5, 0.36) else UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		font = props.font or Theme.FontTitle,
		color = props.textColor or INK,
		z = (props.z or 3) + 1,
		name = "Title",
		maxText = props.maxText or 34,
	})
	if props.sub then
		Widgets.label(b, {
			text = props.sub,
			size = UDim2.new(0.92, 0, 0.26, 0),
			position = UDim2.fromScale(0.5, 0.74),
			anchor = Vector2.new(0.5, 0.5),
			font = Theme.FontBody,
			color = props.subColor or Theme.InkSoft,
			z = (props.z or 3) + 1,
			name = "Sub",
			maxText = 18,
		})
	end

	local downInfo = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local upInfo = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, downInfo, { Scale = 0.93 }):Play()
	end)
	local function up()
		TweenService:Create(scale, upInfo, { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(up)
	b.MouseLeave:Connect(up)
	if props.onClick then
		b.Activated:Connect(function()
			if Widgets.clickSound then
				Widgets.clickSound()
			end
			props.onClick()
		end)
	end
	b.Parent = parent
	return b
end

function Widgets.setText(button: Instance, text: string)
	local t = button:FindFirstChild("Title")
	if t then
		(t :: TextLabel).Text = text
	end
end

-- Scrolling container with a vertical list or grid ---------------------------------------
function Widgets.scroll(parent: Instance?, props): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = props.size or UDim2.fromScale(1, 1)
	s.Position = props.position or UDim2.new()
	s.AnchorPoint = props.anchor or Vector2.new()
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = INK
	s.ScrollBarImageTransparency = 0.6
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.LayoutOrder = props.order or 0
	s.ZIndex = props.z or 2
	s.Name = props.name or "Scroll"
	s.Parent = parent
	return s
end

-- Toasts ------------------------------------------------------------------------------------
local toastHolder: Frame? = nil

function Widgets.setToastHolder(f: Frame)
	toastHolder = f
end

function Widgets.toast(text: string, color: Color3?)
	if not toastHolder then
		return
	end
	local f = Widgets.frame(toastHolder, {
		color = color or Theme.Yellow,
		size = UDim2.new(1, 0, 0, 44),
		round = 12,
		stroke = 3,
		z = 200,
	})
	Widgets.label(f, {
		text = text,
		size = UDim2.new(0.92, 0, 0.7, 0),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		font = Theme.FontTitle,
		z = 201,
		maxText = 22,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = f
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.6, function()
		if f.Parent then
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
			task.wait(0.22)
			f:Destroy()
		end
	end)
end

-- Modal confirm -----------------------------------------------------------------------------
function Widgets.confirm(
	parent: Instance,
	title: string,
	body: string,
	okText: string,
	onOk: () -> (),
	cancelText: string?
)
	local shade = Widgets.frame(parent, { color = Color3.new(0, 0, 0), alpha = 0.45, z = 300, name = "Modal" })
	local card = Widgets.frame(shade, {
		color = Theme.Paper,
		size = UDim2.new(0.86, 0, 0, 250),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		round = 18,
		stroke = 4,
		z = 301,
	})
	local max = Instance.new("UISizeConstraint")
	max.MaxSize = Vector2.new(440, 300)
	max.Parent = card
	Widgets.label(
		card,
		{ text = title, size = UDim2.new(0.9, 0, 0, 42), position = UDim2.new(0.05, 0, 0, 14), z = 302, maxText = 32 }
	)
	Widgets.label(card, {
		text = body,
		size = UDim2.new(0.88, 0, 0, 90),
		position = UDim2.new(0.06, 0, 0, 62),
		font = Theme.FontBody,
		color = Theme.InkSoft,
		z = 302,
		maxText = 20,
	})
	local function close()
		shade:Destroy()
	end
	Widgets.button(card, {
		text = okText,
		color = Theme.Mint,
		size = UDim2.new(0.42, 0, 0, 54),
		position = UDim2.new(0.53, 0, 1, -70),
		z = 303,
		onClick = function()
			close()
			onOk()
		end,
	})
	Widgets.button(card, {
		text = cancelText or "Cancel",
		color = Theme.White,
		size = UDim2.new(0.42, 0, 0, 54),
		position = UDim2.new(0.05, 0, 1, -70),
		z = 303,
		onClick = close,
	})
	return shade
end

-- Header bar with back button + title --------------------------------------------------------
function Widgets.header(parent: Instance, title: string, onBack: (() -> ())?)
	local bar = Widgets.frame(parent, { size = UDim2.new(1, 0, 0, 64), name = "Header", z = 5 })
	if onBack then
		Widgets.button(bar, {
			text = "<",
			color = Theme.White,
			size = UDim2.fromOffset(54, 54),
			position = UDim2.new(0, 4, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			z = 6,
			onClick = onBack,
		})
	end
	Widgets.label(bar, {
		text = title,
		size = UDim2.new(1, -140, 0, 46),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchor = Vector2.new(0.5, 0.5),
		z = 6,
		maxText = 40,
		strokeColor = Theme.White,
		strokeThickness = 3,
	})
	return bar
end

return Widgets
