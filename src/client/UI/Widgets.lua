--[[
	Widgets
	Buttons, panels, labels and other reusable pieces in Trapisque's tabletop style:
	wooden planks, brass, parchment and ink. Every widget animates on hover and press.
]]

local UserInputService = game:GetService("UserInputService")

local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Sound = require(script.Parent.Parent.Sound)

local C = Theme.C
local hex = Theme.hex

local Widgets = {}

Widgets.ButtonStyles = {
	wood = { face = C.wood, light = C.woodLight, dark = C.woodDark, stroke = C.woodDeep, text = C.engrave, engraved = true },
	brass = { face = C.brass, light = C.brassLight, dark = C.brassDark, stroke = hex("6E4F12"), text = hex("4A3008"), engraved = true },
	red = { face = hex("C2513B"), light = hex("DD735D"), dark = hex("8A3122"), stroke = hex("5A1D12"), text = C.white, outline = hex("5A1D12") },
	green = { face = hex("5E9A3C"), light = hex("80BB5C"), dark = hex("3D6B24"), stroke = hex("284616"), text = C.white, outline = hex("284616") },
	blue = { face = hex("4C80B8"), light = hex("6FA0D4"), dark = hex("33597F"), stroke = hex("1F3A55"), text = C.white, outline = hex("1F3A55") },
	purple = { face = hex("7A61A8"), light = hex("9A83C8"), dark = hex("554279"), stroke = hex("362A4E"), text = C.white, outline = hex("362A4E") },
	parchment = { face = C.parchment, light = hex("FFF7E2"), dark = C.parchmentDark, stroke = C.parchmentEdge, text = C.ink, engraved = true },
	dark = { face = hex("3A281B"), light = hex("4D3726"), dark = hex("221710"), stroke = hex("120B07"), text = C.parchment, outline = hex("120B07") },
}

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------

local FONT = {
	display = Theme.Font.Display,
	chunky = Theme.Font.Chunky,
	body = Theme.Font.Body,
	heavy = Theme.Font.BodyHeavy,
	regular = Theme.Font.BodyRegular,
}

--[[
	Widgets.label(parent, {
		text, font = "body", size = 18, color, align = "left"|"center"|"right",
		wrap, scaled (TextScaled with max size), autoY (AutomaticSize Y), outline (Color3),
		position, sizeUDim (Size), anchor, layoutOrder, name, z
	})
]]
function Widgets.label(parent: Instance?, o: { [string]: any }): TextLabel
	local label = Util.new("TextLabel", {
		Name = o.name or "Label",
		BackgroundTransparency = 1,
		Text = o.text or "",
		FontFace = FONT[o.font or "body"] or Theme.Font.Body,
		TextColor3 = o.color or C.textDark,
		TextSize = o.size or 18,
		TextWrapped = o.wrap == true,
		RichText = o.rich == true,
		TextXAlignment = Enum.TextXAlignment[({ left = "Left", center = "Center", right = "Right" })[o.align or "left"]],
		TextYAlignment = Enum.TextYAlignment[({ top = "Top", center = "Center", bottom = "Bottom" })[o.valign or "center"]],
		Size = o.sizeUDim or UDim2.new(1, 0, 0, (o.size or 18) + 6),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
		ZIndex = o.z or 1,
	})
	if o.scaled then
		label.TextScaled = true
		Util.new("UITextSizeConstraint", { MaxTextSize = o.size or 18, MinTextSize = o.minSize or 8, Parent = label })
	end
	if o.autoY then
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(label.Size.X.Scale, label.Size.X.Offset, 0, 0)
	end
	if o.outline then
		Util.new("UIStroke", { Color = o.outline, Thickness = o.outlineThickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
	end
	label.Parent = parent
	return label
end

-- Burned-in text on wood: dark letters, one flat layer.
function Widgets.carved(parent: Instance, o: { [string]: any }): TextLabel
	local opts = table.clone(o)
	opts.color = o.color or C.engrave
	return Widgets.label(parent, opts)
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

--[[
	Widgets.button(parent, {
		text, icon (IconData id), style = "wood", size (UDim2), position, anchor,
		textSize = 22, font = "chunky", onClick, disabled, layoutOrder, name, depth = 5
	}) -> button object { root, label, setText, setEnabled, setStyle, flash, pulse }
]]
function Widgets.button(parent: Instance?, o: { [string]: any })
	local style = Widgets.ButtonStyles[o.style or "wood"] or Widgets.ButtonStyles.wood
	local depth = o.depth or 5
	local root = Util.new("TextButton", {
		Name = o.name or "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = o.size or UDim2.fromOffset(200, 54),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
		ZIndex = o.z or 1,
		Selectable = true,
	})
	local scale = Util.new("UIScale", { Parent = root })

	-- the "side" visible under the face gives the button depth
	local side = Util.new("Frame", {
		Name = "Side",
		BackgroundColor3 = style.dark,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -depth),
		Position = UDim2.fromOffset(0, depth),
		Parent = root,
	})
	Util.corner(side, o.corner or 12)
	local sideStroke = Util.stroke(side, style.stroke, 2)

	local face = Util.new("Frame", {
		Name = "Face",
		BackgroundColor3 = style.face,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -depth),
		ZIndex = 2,
		Parent = root,
	})
	Util.corner(face, o.corner or 12)
	local faceStroke = Util.stroke(face, style.stroke, 2)
	local hover = Util.new("Frame", {
		Name = "Hover",
		BackgroundColor3 = C.white,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = face,
	})
	Util.corner(hover, o.corner or 12)

	local content = Util.frame(face, { Name = "Content", ZIndex = 5 })
	local list = Util.list(content, "x", 8, "Center", "Center")
	list.Parent = content

	local iconHolder: Frame? = nil
	local iconId = o.icon
	local function drawIcon()
		if not iconHolder then
			return
		end
		for _, child in iconHolder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if not iconId then
			return
		end
		if style.engraved then
			Icons.engraved(iconHolder, iconId, style.face, { Size = UDim2.fromScale(1, 1) })
		else
			Icons.make(iconHolder, iconId, Icons.flatColors(style.text, style.face, style.text))
		end
	end
	if o.icon then
		local holder = Util.frame(content, {
			Name = "IconHolder",
			Size = UDim2.fromScale(0.62, 0.62),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			LayoutOrder = 1,
			ZIndex = 5,
		})
		Util.ratio(holder, 1)
		iconHolder = holder
		drawIcon()
	end

	local label
	if o.text then
		local textHolder = Util.frame(content, {
			Name = "TextHolder",
			Size = UDim2.new(0, 0, 0.8, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 2,
			ZIndex = 5,
		})
		local textOpts = {
			text = o.text,
			font = o.font or "chunky",
			size = o.textSize or 22,
			color = style.text,
			align = "center",
			sizeUDim = UDim2.new(0, 0, 1, 0),
			z = 6,
			outline = style.outline,
			outlineThickness = 2,
		}
		label = Widgets.label(textHolder, textOpts)
		label.AutomaticSize = Enum.AutomaticSize.X
	end

	local btn = { root = root, label = label, face = face, enabled = o.disabled ~= true, hovering = false }

	local function restyle(s)
		style = s
		side.BackgroundColor3 = s.dark
		sideStroke.Color = s.stroke
		face.BackgroundColor3 = s.face
		faceStroke.Color = s.stroke
		if label then
			label.TextColor3 = s.text
			local outline = label:FindFirstChildOfClass("UIStroke")
			if s.outline then
				if not outline then
					outline = Util.new("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
				end
				(outline :: UIStroke).Color = s.outline
			elseif outline then
				outline:Destroy()
			end
		end
		drawIcon()
	end

	local function visualEnabled(on: boolean)
		root.Active = on
		local t = if on then 0 else 0.35
		face.BackgroundTransparency = t
		side.BackgroundTransparency = t
		if label then
			label.TextTransparency = if on then 0 else 0.4
		end
	end

	function btn.setText(_self, text: string)
		if label then
			label.Text = text
		end
	end

	function btn.setEnabled(_self, on: boolean)
		btn.enabled = on
		visualEnabled(on)
	end

	function btn.setStyle(_self, name: string)
		local s = Widgets.ButtonStyles[name] or style
		if s ~= style then
			restyle(s)
		end
	end

	-- swap the icon (only on buttons created with one)
	function btn.setIcon(_self, id: string)
		if id ~= iconId then
			iconId = id
			drawIcon()
		end
	end

	-- gentle breathing glow to draw the eye (e.g. ROLL on your turn)
	local pulsing = false
	function btn.pulse(_self, on: boolean)
		if pulsing == on then
			return
		end
		pulsing = on
		if on then
			task.spawn(function()
				while pulsing and root.Parent do
					Util.tween(scale, 0.55, { Scale = 1.05 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					task.wait(0.55)
					if not pulsing then
						break
					end
					Util.tween(scale, 0.55, { Scale = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					task.wait(0.55)
				end
				Util.tween(scale, 0.2, { Scale = 1 })
			end)
		end
	end

	function btn.flash(_self)
		hover.BackgroundTransparency = 0.4
		Util.tween(hover, 0.4, { BackgroundTransparency = 1 })
	end

	root.MouseEnter:Connect(function()
		if not btn.enabled then
			return
		end
		btn.hovering = true
		Util.tween(hover, 0.12, { BackgroundTransparency = 0.88 })
		if not pulsing then
			Util.tween(scale, 0.15, { Scale = 1.04 }, Enum.EasingStyle.Back)
		end
	end)
	root.MouseLeave:Connect(function()
		btn.hovering = false
		Util.tween(hover, 0.15, { BackgroundTransparency = 1 })
		if not pulsing then
			Util.tween(scale, 0.15, { Scale = 1 })
		end
		face.Position = UDim2.new()
	end)
	root.MouseButton1Down:Connect(function()
		if not btn.enabled then
			return
		end
		Util.tween(face, 0.06, { Position = UDim2.fromOffset(0, depth - 1) })
	end)
	root.MouseButton1Up:Connect(function()
		Util.tween(face, 0.1, { Position = UDim2.new() }, Enum.EasingStyle.Back)
	end)
	root.Activated:Connect(function()
		if not btn.enabled then
			Sound.play("error")
			Util.shake(face, 4, 0.25)
			return
		end
		Util.tween(face, 0.1, { Position = UDim2.new() }, Enum.EasingStyle.Back)
		Sound.play("click")
		if o.onClick then
			task.spawn(o.onClick)
		end
	end)

	visualEnabled(btn.enabled)
	root.Parent = parent
	return btn
end

-- Small square icon-only button.
function Widgets.iconButton(parent: Instance?, o: { [string]: any })
	local opts = table.clone(o)
	opts.text = nil
	opts.size = o.size or UDim2.fromOffset(48, 50)
	opts.corner = o.corner or 12
	opts.depth = o.depth or 4
	local b = Widgets.button(parent, opts)
	local holder = b.root:FindFirstChild("IconHolder", true)
	if holder then
		holder.Size = UDim2.fromScale(o.iconScale or 0.66, o.iconScale or 0.66)
	end
	return b
end

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------

local function grain(parent: Instance, color: Color3, count: number)
	local canvas = Util.frame(parent, { Name = "Grain", ZIndex = 1 })
	for i = 1, count do
		local y = (i - 0.5) / count + (math.random() - 0.5) * 0.06
		local line = Util.new("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.1, y),
			Size = UDim2.new(0.75 + math.random() * 0.2, 0, 0, 2),
			Rotation = (math.random() - 0.5) * 1.6,
			Parent = canvas,
		})
		Util.corner(line, 1)
	end
	return canvas
end
Widgets.grain = grain

--[[
	Widgets.panel(parent, {
		style = "parchment" | "wood" | "dark" | "board", title, size, position, anchor,
		padding = 18, name, z
	}) -> content frame, root frame
]]
function Widgets.panel(parent: Instance?, o: { [string]: any }): (Frame, Frame)
	local style = o.style or "parchment"
	local root = Util.new("Frame", {
		Name = o.name or "Panel",
		BorderSizePixel = 0,
		Size = o.size or UDim2.fromOffset(400, 300),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		ZIndex = o.z or 1,
		LayoutOrder = o.layoutOrder or 0,
	})
	local corner = o.corner or 14
	Util.corner(root, corner)
	if style == "parchment" then
		root.BackgroundColor3 = C.parchment
		Util.stroke(root, C.burn, 3)
		local neat = Util.new("Frame", {
			Name = "Neatline",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -14, 1, -14),
			Position = UDim2.fromOffset(7, 7),
			Parent = root,
		})
		Util.corner(neat, math.max(4, corner - 6))
		Util.stroke(neat, C.inkFaint, 1.5, 0.3)
	elseif style == "wood" or style == "board" then
		root.BackgroundColor3 = if style == "board" then C.woodDark else C.wood
		Util.stroke(root, C.woodDeep, 3)
		grain(root, C.woodDeep, 6)
	elseif style == "dark" then
		root.BackgroundColor3 = hex("1F150E")
		root.BackgroundTransparency = 0.12
		Util.stroke(root, C.brassDark, 2, 0.2)
	end
	if o.shadow ~= false then
		task.defer(function()
			if root.Parent then
				Util.shadow(root, { offset = 6, transparency = 0.6 })
			end
		end)
	end

	local content = Util.frame(root, { Name = "Content", ZIndex = 2 })
	local pad = o.padding or 18
	Util.pad(content, pad, (o.title and pad + 54) or pad, pad, pad)

	if o.title then
		-- the title plate sits inside the panel, centred under its top edge
		local plate = Widgets.ribbon(root, o.title, { width = o.titleWidth, color = o.titleColor })
		plate.AnchorPoint = Vector2.new(0.5, 0)
		plate.Position = UDim2.new(0.5, 0, 0, 14)
	end
	root.Parent = parent
	return content, root
end

-- Title ribbon (scroll banner) centred on the top edge of `parent`.
function Widgets.ribbon(parent: Instance, text: string, o: { [string]: any }?)
	-- a title cartouche: a paper plaque with a double inked border (like the map's frame)
	local opts = o or {}
	local holder = Util.frame(parent, {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(opts.width or 280, 44),
		ZIndex = 20,
	})
	local band = Util.new("Frame", {
		Name = "Band",
		BackgroundColor3 = opts.color or C.parchmentMid,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 22,
		Parent = holder,
	})
	Util.corner(band, 8)
	Util.stroke(band, C.ink, 2, 0.1)
	local inner = Util.new("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
		ZIndex = 22,
		Parent = band,
	})
	Util.corner(inner, 5)
	Util.stroke(inner, C.ink, 1, 0.45)
	Widgets.label(band, {
		text = text,
		font = "display",
		size = 28,
		color = C.ink,
		align = "center",
		sizeUDim = UDim2.new(1, -16, 1, -8),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		scaled = true,
		z = 23,
	})
	return holder
end

---------------------------------------------------------------------------
-- Misc controls
---------------------------------------------------------------------------

function Widgets.divider(parent: Instance, layoutOrder: number?)
	local f = Util.new("Frame", {
		Name = "Divider",
		BackgroundColor3 = C.inkFaint,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.new(0.9, 0, 0, 2),
		LayoutOrder = layoutOrder or 0,
		Parent = parent,
	})
	Util.corner(f, 1)
	return f
end

-- On/off switch made of a brass track and a wooden knob.
function Widgets.toggle(parent: Instance, o: { [string]: any })
	local value = o.value == true
	local root = Util.new("TextButton", {
		Name = o.name or "Toggle",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.woodDeep,
		BorderSizePixel = 0,
		Size = o.size or UDim2.fromOffset(74, 36),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
		Parent = parent,
	})
	Util.corner(root, 0.5)
	Util.stroke(root, C.woodDeep, 2)
	local fill = Util.new("Frame", {
		BackgroundColor3 = C.good,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = if value then 0 else 1,
		Parent = root,
	})
	Util.corner(fill, 0.5)
	local knob = Util.new("Frame", {
		Name = "Knob",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 0, 0.8, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Position = UDim2.fromScale(if value then 0.72 else 0.28, 0.5),
		ZIndex = 2,
		Parent = root,
	})
	knob.Size = UDim2.fromScale(0.8, 0.8)
	Util.corner(knob, 0.5)
	Util.stroke(knob, C.woodDeep, 2)
	local t = {}
	function t.set(_self, v: boolean, silent: boolean?)
		value = v
		Util.tween(knob, 0.18, { Position = UDim2.fromScale(if v then 0.72 else 0.28, 0.5) }, Enum.EasingStyle.Back)
		Util.tween(fill, 0.18, { BackgroundTransparency = if v then 0 else 1 })
		if not silent and o.onChange then
			task.spawn(o.onChange, v)
		end
	end
	function t.get()
		return value
	end
	root.Activated:Connect(function()
		Sound.play("click")
		t:set(not value)
	end)
	t.root = root
	return t
end

--[[
	A row of options where one is picked (map, length, bots...).
		local c = Widgets.choice(parent, { options = { { text = "Quick", value = "quick" }, ... },
			value = "quick", onChange = fn, size = UDim2, position, layoutOrder, textSize })
		c:set(value)  c.value  c:setEnabled(bool)
]]
function Widgets.choice(parent: Instance, o: { [string]: any })
	local root = Util.frame(parent, {
		Name = o.name or "Choice",
		Size = o.size or UDim2.fromOffset(360, 40),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
	})
	local layout = Util.list(root, "x", 6, o.align or "Left", "Center")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	local c = { root = root, value = o.value, enabled = true }
	local buttons = {}
	local function paint()
		for _, b in buttons do
			local on = b.value == c.value
			b.frame.BackgroundColor3 = if on then C.brass else C.parchment
			b.stroke.Color = if on then C.brassDark else C.parchmentEdge
			b.label.TextColor3 = if on then C.ink else C.inkSoft
			b.frame.BackgroundTransparency = if c.enabled or on then 0 else 0.4
		end
	end
	local n = #o.options
	for i, opt in o.options do
		local f = Util.new("TextButton", {
			Name = "Option" .. i,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Size = UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0),
			LayoutOrder = i,
			Parent = root,
		})
		Util.corner(f, 8)
		local stroke = Util.stroke(f, C.parchmentEdge, 2)
		local label = Widgets.label(f, {
			text = opt.text,
			font = "chunky",
			size = o.textSize or 17,
			align = "center",
			sizeUDim = UDim2.new(1, -8, 1, 0),
			position = UDim2.fromOffset(4, 0),
			scaled = true,
		})
		local b = { frame = f, stroke = stroke, label = label, value = opt.value }
		table.insert(buttons, b)
		f.Activated:Connect(function()
			if not c.enabled or c.value == opt.value then
				return
			end
			Sound.play("click")
			c.value = opt.value
			paint()
			Util.bump(f, 0.06)
			if o.onChange then
				task.spawn(o.onChange, opt.value)
			end
		end)
	end
	function c.set(_self, value: any)
		c.value = value
		paint()
	end
	function c.setEnabled(_self, on: boolean)
		c.enabled = on
		paint()
	end
	paint()
	return c
end

-- Horizontal progress bar (XP, timers).
function Widgets.progress(parent: Instance, o: { [string]: any })
	local root = Util.new("Frame", {
		Name = o.name or "Progress",
		BackgroundColor3 = o.track or C.woodDeep,
		BorderSizePixel = 0,
		Size = o.size or UDim2.fromOffset(200, 14),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
		ZIndex = o.z or 1,
		Parent = parent,
	})
	Util.corner(root, 0.5)
	Util.stroke(root, C.woodDeep, 2)
	local fill = Util.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = o.color or C.brass,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(math.clamp(o.value or 0, 0, 1), 1),
		ZIndex = (o.z or 1) + 1,
		Parent = root,
	})
	Util.corner(fill, 0.5)
	local p = { root = root, fill = fill }
	function p.set(_self, v: number, instant: boolean?)
		local s = UDim2.fromScale(math.clamp(v, 0, 1), 1)
		if instant then
			fill.Size = s
		else
			Util.tween(fill, 0.35, { Size = s })
		end
	end
	return p
end

-- Parchment text input.
function Widgets.textBox(parent: Instance, o: { [string]: any }): TextBox
	local box = Util.new("TextBox", {
		Name = o.name or "TextBox",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		Text = o.text or "",
		PlaceholderText = o.placeholder or "",
		PlaceholderColor3 = C.inkFaint,
		TextColor3 = C.ink,
		FontFace = if o.font == "chunky" then Theme.Font.Chunky else Theme.Font.BodyHeavy,
		TextSize = o.textSize or 22,
		ClearTextOnFocus = false,
		Size = o.size or UDim2.fromOffset(200, 44),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
		Parent = parent,
	})
	Util.corner(box, 10)
	local stroke = Util.stroke(box, C.parchmentEdge, 2)
	box.Focused:Connect(function()
		Util.tween(stroke, 0.15, { Color = C.brassDark, Thickness = 3 })
	end)
	box.FocusLost:Connect(function(enter)
		Util.tween(stroke, 0.15, { Color = C.parchmentEdge, Thickness = 2 })
		if enter and o.onSubmit then
			task.spawn(o.onSubmit, box.Text)
		end
	end)
	if o.maxLength then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local t = box.Text
			if o.upper then
				t = string.upper(t)
			end
			if #t > o.maxLength then
				t = string.sub(t, 1, o.maxLength)
			end
			if t ~= box.Text then
				box.Text = t
			end
		end)
	end
	return box
end

-- Themed scrolling list.
function Widgets.scroll(parent: Instance, o: { [string]: any }): ScrollingFrame
	local sf = Util.new("ScrollingFrame", {
		Name = o.name or "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = o.size or UDim2.fromScale(1, 1),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = if o.horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollingDirection = if o.horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.woodDark,
		ScrollBarImageTransparency = 0.2,
		LayoutOrder = o.layoutOrder or 0,
		Parent = parent,
	})
	if o.grid then
		Util.new("UIGridLayout", {
			CellSize = o.grid,
			CellPadding = UDim2.fromOffset(o.gap or 10, o.gap or 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = sf,
		})
	else
		Util.list(sf, if o.horizontal then "x" else "y", o.gap or 8, o.hAlign or "Center", "Top")
	end
	Util.pad(sf, o.padding or 6)
	return sf
end

-- Small rounded tag (counts, "NEW!", rarity names).
function Widgets.badge(parent: Instance, o: { [string]: any }): Frame
	local b = Util.new("Frame", {
		Name = o.name or "Badge",
		BackgroundColor3 = o.color or C.bad,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, o.height or 24),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		ZIndex = o.z or 10,
		LayoutOrder = o.layoutOrder or 0,
		Parent = parent,
	})
	Util.corner(b, 0.5)
	Util.stroke(b, o.stroke or Util.shade(o.color or C.bad, -0.4), 2)
	Util.pad(b, 8, 0, 8, 0)
	Widgets.label(b, {
		text = o.text or "",
		font = "chunky",
		size = o.textSize or 16,
		color = o.textColor or C.white,
		align = "center",
		sizeUDim = UDim2.fromScale(0, 1),
		z = (o.z or 10) + 1,
	}).AutomaticSize = Enum.AutomaticSize.X
	return b
end

---------------------------------------------------------------------------
-- Modal dialogs and toasts
---------------------------------------------------------------------------

--[[
	Widgets.modal(layer, { title, width = 560, height = 420, onClose, noClose })
	-> content frame, close()
]]
function Widgets.modal(layer: Instance, o: { [string]: any })
	local dim = Util.new("TextButton", {
		Name = "Modal",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.dim,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = layer,
	})
	Util.tween(dim, 0.2, { BackgroundTransparency = 0.45 })
	local content, panel = Widgets.panel(dim, {
		title = o.title,
		titleWidth = o.titleWidth,
		size = UDim2.fromOffset(o.width or 560, o.height or 420),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.52),
		z = 101,
		style = o.style or "parchment",
	})
	Util.popIn(panel, 0.35, 0.7)
	Sound.play("open")
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Sound.play("close")
		Util.tween(dim, 0.15, { BackgroundTransparency = 1 })
		Util.tween(Util.scaler(panel), 0.15, { Scale = 0.8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.16, function()
			dim:Destroy()
		end)
		if o.onClose then
			task.spawn(o.onClose)
		end
	end
	if not o.noClose then
		-- close button tucked inside the top-right corner
		local x = Widgets.iconButton(panel, {
			icon = "close",
			style = "red",
			size = UDim2.fromOffset(40, 42),
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -14, 0, 14),
			onClick = close,
			z = 120,
		})
		x.root.ZIndex = 120
		dim.Activated:Connect(function()
			if o.closeOnBackdrop ~= false then
				close()
			end
		end)
	end
	return content, close, panel
end

local toastHolder: Frame? = nil

function Widgets.setToastLayer(layer: Instance)
	toastHolder = Util.frame(layer, {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(0, 560, 1, -80),
		ZIndex = 200,
	})
	Util.list(toastHolder :: Frame, "y", 8, "Center", "Top")
end

local TOAST_COLORS = {
	info = C.info,
	error = C.bad,
	reward = C.brass,
	party = C.good,
	turn = C.brass,
}

function Widgets.toast(text: string, kind: string?)
	local holder = toastHolder
	if not holder then
		return
	end
	local color = TOAST_COLORS[kind or "info"] or C.info
	local note = Util.new("Frame", {
		Name = "Toast",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 201,
		Parent = holder,
	})
	Util.corner(note, 10)
	Util.stroke(note, color, 3)
	Util.pad(note, 16, 10, 16, 10)
	Util.new("UISizeConstraint", { MaxSize = Vector2.new(540, 200), Parent = note })
	local label = Widgets.label(note, {
		text = text,
		font = "heavy",
		size = 19,
		color = C.textDark,
		wrap = true,
		align = "center",
		z = 202,
	})
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	Util.new("UISizeConstraint", { MaxSize = Vector2.new(508, 200), Parent = label })
	Util.popIn(note, 0.3, 0.6)
	if kind == "error" then
		Sound.play("error")
	end
	task.delay(if #text > 60 then 5 else 3.5, function()
		if note.Parent then
			Util.tween(Util.scaler(note), 0.2, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.2)
			note:Destroy()
		end
	end)
end

-- Is the user on a touch device? (bigger hit areas)
function Widgets.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return Widgets
