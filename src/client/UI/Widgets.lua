--[[
	Widgets
	Buttons, panels, labels and other reusable pieces. Flat colour on paper, rounded
	corners, light borders. Anything you can press sits on a darker edge of its own
	colour and sinks into it when pressed. Three kinds of button and no more: the
	orange one for the thing that matters on a screen, a white one for everything else,
	red for anything you can't take back (and green for "done").
]]

local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Sound = require(script.Parent.Parent.Sound)

local C = Theme.C
local hex = Theme.hex

local Widgets = {}

-- The screen the UI is on (Root keeps this current), so modals and toasts can fit it.
Widgets.metrics = Layout.metrics(1280, 720)

--[[
	A button's colours: its face, the darker edge it sits on, its lettering, and a
	border (white buttons only: a coloured face needs none).
]]
local function paint(face: Color3, text: Color3, edge: Color3?, border: Color3?)
	return {
		face = face,
		dark = edge or Util.shade(face, -0.22),
		stroke = border,
		text = text,
	}
end

local primary = paint(C.orange, C.white, C.orangeDark)
local secondary = paint(C.panelRaised, C.text, C.panelEdge, C.line)
local success = paint(C.lime, C.white, C.limeDark)
local danger = paint(C.coral, C.white, C.coralDark)
local muted = paint(C.panelDeep, C.textFaint, hex("D9D0C0"))

-- (the old names all land on one of those)
Widgets.ButtonStyles = {
	primary = primary,
	secondary = secondary,
	success = success,
	danger = danger,
	muted = muted,
	brass = primary,
	sun = primary,
	orange = primary,
	green = success,
	red = danger,
	wood = secondary,
	blue = secondary,
	purple = secondary,
	pink = secondary,
	panel = secondary,
	parchment = secondary,
	dark = muted,
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
		TextColor3 = o.color or C.text,
		TextSize = o.size or 18,
		TextWrapped = o.wrap == true,
		RichText = o.rich == true,
		TextXAlignment = Enum.TextXAlignment[({ left = "Left", center = "Center", right = "Right" })[o.align or "left"]],
		TextYAlignment = Enum.TextYAlignment[({ top = "Top", center = "Center", bottom = "Bottom" })[o.valign or "center"]],
		Size = o.sizeUDim or UDim2.new(1, 0, 0, (o.size or 18) + 8),
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
	-- Lettering has no outline: it sits on flat colour that's chosen to read. The few
	-- labels drawn straight over the board's art ask for a thin dark one (o.ink).
	if o.ink or (o.outline and o.outline == C.ink) then
		Util.new("UIStroke", { Color = C.ink, Thickness = o.outlineThickness or 1.5, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
	end
	label.Parent = parent
	return label
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

-- Words that keep their own capitals when a button's text is put in sentence case.
local KEEP = {
	ROBLOX = "Roblox",
	TRAPISQUE = "Trapisque",
	VIP = "VIP",
	XP = "XP",
	GG = "GG",
	OK = "OK",
	UTC = "UTC",
	ID = "ID",
	TV = "TV",
}

--[[
	Button text in sentence case: "FIND A MATCH" reads "Find a match". Text that already
	has small letters is left alone (a name, a line someone typed), and so is a single
	capital or a number ("R$ 10", "+3", "Q").
]]
function Widgets.caseOf(text: string): string
	if string.find(text, "%l") or not string.find(text, "%u%u") then
		return text
	end
	local out = string.lower(text)
	out = string.gsub(out, "^([^%a]*)(%a)", function(pre: string, c: string)
		return pre .. string.upper(c)
	end)
	out = string.gsub(out, "%a+", function(word: string)
		return KEEP[string.upper(word)] or word
	end)
	return out
end

--[[
	Widgets.button(parent, {
		text, icon (IconData id), style = "wood", size (UDim2), position, anchor,
		textSize = 22, font = "chunky", onClick, disabled, layoutOrder, name, depth = 5
	}) -> button object { root, label, setText, setEnabled, setStyle, flash, pulse }
]]
function Widgets.button(parent: Instance?, o: { [string]: any })
	local style = Widgets.ButtonStyles[o.style or "wood"] or Widgets.ButtonStyles.wood
	local depth = math.min(o.depth or 4, 4)
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

	local face = Util.new("Frame", {
		Name = "Face",
		BackgroundColor3 = style.face,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -depth),
		ZIndex = 2,
		Parent = root,
	})
	Util.corner(face, o.corner or 12)
	local faceStroke = Util.stroke(face, style.stroke or style.face, 2)
	faceStroke.Enabled = style.stroke ~= nil
	-- (printed paint is flat: the old candy shine stays, invisible, for the code that
	-- still toggles it)
	local gloss = Util.new("Frame", {
		Name = "Gloss",
		BackgroundColor3 = C.white,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0.36, 0),
		Position = UDim2.fromOffset(5, 4),
		ZIndex = 3,
		Parent = face,
	})
	Util.corner(gloss, 8)
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
		-- a flat glyph in the lettering's colour
		Icons.make(iconHolder, iconId, { ink = style.text, bg = style.face, acc = style.text, acc2 = style.text, hi = style.face, line = style.text }, nil)
	end
	if o.icon then
		local holder = Util.frame(content, {
			Name = "IconHolder",
			Size = UDim2.fromScale(0.5, 0.5),
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
			text = Widgets.caseOf(o.text),
			font = if o.font == "heavy" or o.font == "body" then o.font else "chunky",
			size = math.min(o.textSize or 20, 22),
			color = style.text,
			align = "center",
			sizeUDim = UDim2.new(0, 0, 1, 0),
			z = 6,
		}
		label = Widgets.label(textHolder, textOpts)
		label.AutomaticSize = Enum.AutomaticSize.X
	end

	local btn = { root = root, label = label, face = face, enabled = o.disabled ~= true, hovering = false }

	local function restyle(s)
		style = s
		side.BackgroundColor3 = s.dark
		face.BackgroundColor3 = s.face
		faceStroke.Enabled = s.stroke ~= nil
		if s.stroke then
			faceStroke.Color = s.stroke
		end
		if label then
			label.TextColor3 = s.text
		end
		drawIcon()
	end

	local function visualEnabled(on: boolean)
		root.Active = on
		local t = if on then 0 else 0.35
		face.BackgroundTransparency = t
		side.BackgroundTransparency = t
		gloss.Visible = on
		if label then
			label.TextTransparency = if on then 0 else 0.4
		end
	end

	function btn.setText(_self, text: string)
		if label then
			label.Text = Widgets.caseOf(text)
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
			gloss.Visible = true
		end
	end

	-- swap the icon (only on buttons created with one)
	function btn.setIcon(_self, id: string)
		if id ~= iconId then
			iconId = id
			drawIcon()
		end
	end

	-- a slow, soft brightening to draw the eye (ROLL on your turn); the button doesn't move
	local pulsing = false
	function btn.pulse(_self, on: boolean)
		if pulsing == on then
			return
		end
		pulsing = on
		if on then
			task.spawn(function()
				while pulsing and root.Parent do
					if not btn.hovering then
						Util.tween(hover, 1.1, { BackgroundTransparency = 0.9 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					end
					task.wait(1.1)
					if not pulsing then
						break
					end
					if not btn.hovering then
						Util.tween(hover, 1.1, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					end
					task.wait(1.1)
				end
				if not btn.hovering then
					Util.tween(hover, 0.2, { BackgroundTransparency = 1 })
				end
			end)
		end
	end

	-- a small tag on the corner ("2", "NEW"); nil removes it
	local badge: Frame? = nil
	function btn.setBadge(_self, text: string?)
		if badge then
			badge:Destroy()
			badge = nil
		end
		if text then
			badge = Widgets.badge(root, {
				name = "Badge",
				text = text,
				color = C.bad,
				height = 22,
				textSize = 14,
				anchor = Vector2.new(1, 0),
				position = UDim2.new(1, 6, 0, -8),
				z = 30,
			})
		end
	end

	function btn.flash(_self)
		hover.BackgroundTransparency = 0.4
		Util.tween(hover, 0.4, { BackgroundTransparency = 1 })
	end
	function btn.setOnClick(_self, fn: (() -> ())?)
		o.onClick = fn
	end

	root.MouseEnter:Connect(function()
		if not btn.enabled then
			return
		end
		btn.hovering = true
		Util.tween(hover, 0.12, { BackgroundTransparency = 0.9 })
		Util.tween(scale, 0.15, { Scale = 1.02 }, Enum.EasingStyle.Quad)
	end)
	root.MouseLeave:Connect(function()
		btn.hovering = false
		Util.tween(hover, 0.15, { BackgroundTransparency = 1 })
		Util.tween(scale, 0.15, { Scale = 1 })
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
	opts.corner = o.corner or 10
	opts.depth = o.depth or 3
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

--[[
	Widgets.panel(parent, {
		style = "walnut" | "wood" | "dark" | "board", title, size, position, anchor,
		padding = 18, name, z
	}) -> content frame, root frame
	"walnut" (the default, the name is historical) is a paper panel with a light
	border. "bright" is a panel in a flat colour (o.color). A title is a plain heading
	across the top.
]]
function Widgets.panel(parent: Instance?, o: { [string]: any }): (Frame, Frame)
	local style = o.style or "walnut"
	if style == "parchment" then
		style = "walnut"
	end
	local root = Util.new("Frame", {
		Name = o.name or "Panel",
		BorderSizePixel = 0,
		Size = o.size or UDim2.fromOffset(400, 300),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		ZIndex = o.z or 1,
		LayoutOrder = o.layoutOrder or 0,
	})
	local corner = o.corner or 16
	Util.corner(root, corner)
	if style == "walnut" then
		root.BackgroundColor3 = C.panel
		Util.stroke(root, C.line, 2)
	elseif style == "wood" or style == "board" then
		-- a panel set on a panel (the Potion Seller's stall)
		root.BackgroundColor3 = if style == "board" then C.panelDeep else C.panelRaised
		Util.stroke(root, C.line, 2)
	elseif style == "dark" then
		root.BackgroundColor3 = C.panelDeep
		root.BackgroundTransparency = 0.04
		Util.stroke(root, C.line, 2)
	elseif style == "bright" then
		root.BackgroundColor3 = o.color or C.sun
	end
	if o.shadow == true then
		task.defer(function()
			if root.Parent then
				Util.shadow(root, { offset = 4, offsetX = 0, transparency = 0.82, color = C.shadow })
			end
		end)
	end

	local content = Util.frame(root, { Name = "Content", ZIndex = 2 })
	local pad = o.padding or 18
	Util.pad(content, pad, (o.title and pad + 40) or pad, pad, pad)

	if o.title then
		local heading = Widgets.ribbon(root, o.title, { width = o.titleWidth, color = o.titleColor })
		heading.AnchorPoint = Vector2.new(0.5, 0)
		heading.Position = UDim2.new(0.5, 0, 0, pad - 2)
	end
	root.Parent = parent
	return content, root
end

-- A panel's heading: plain text across its top, as wide as it's allowed (o.width).
-- (The name is historical: it used to be a tilted banner.)
function Widgets.ribbon(parent: Instance, text: string, o: { [string]: any }?)
	local opts = o or {}
	local holder = Util.frame(parent, {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.new(1, -120, 0, 34),
		ZIndex = 20,
	})
	Widgets.label(holder, {
		name = "Heading",
		text = text,
		font = "chunky",
		size = opts.size or 24,
		color = opts.textColor or C.text,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
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
		BackgroundColor3 = C.panelEdge,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.new(0.9, 0, 0, 2),
		LayoutOrder = layoutOrder or 0,
		Parent = parent,
	})
	Util.corner(f, 1)
	return f
end

-- On/off switch: a green track when on, a white knob.
function Widgets.toggle(parent: Instance, o: { [string]: any })
	local value = o.value == true
	local root = Util.new("TextButton", {
		Name = o.name or "Toggle",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.panelDeep,
		BorderSizePixel = 0,
		Size = o.size or UDim2.fromOffset(74, 36),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
		Parent = parent,
	})
	Util.corner(root, 0.5)
	local fill = Util.new("Frame", {
		BackgroundColor3 = C.lime,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = if value then 0 else 1,
		Parent = root,
	})
	Util.corner(fill, 0.5)
	local knob = Util.new("Frame", {
		Name = "Knob",
		BackgroundColor3 = C.panelRaised,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 0, 0.8, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Position = UDim2.fromScale(if value then 0.72 else 0.28, 0.5),
		ZIndex = 2,
		Parent = root,
	})
	knob.Size = UDim2.fromScale(0.78, 0.78)
	Util.corner(knob, 0.5)
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
	A volume slider: a brass fill on a dark track, with a knob to drag (or tap anywhere
	on it). Moves in 5% steps.
		local s = Widgets.slider(parent, { value = 0.7, onChange = fn(v), onRelease = fn(v),
			size, position, anchor, layoutOrder, name })
		s:set(v) ; s.root
]]
function Widgets.slider(parent: Instance, o: { [string]: any })
	local root = Util.new("TextButton", {
		Name = o.name or "Slider",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = o.size or UDim2.fromOffset(220, 36),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
		Parent = parent,
	})
	local track = Util.new("Frame", {
		Name = "Track",
		BackgroundColor3 = C.panelDeep,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.new(1, -24, 0, 10),
		Parent = root,
	})
	Util.corner(track, 0.5)
	local value = math.clamp(o.value or 0, 0, 1)
	local fill = Util.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = C.orange,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(value, 1),
		ZIndex = 2,
		Parent = track,
	})
	Util.corner(fill, 0.5)
	local knob = Util.new("Frame", {
		Name = "Knob",
		BackgroundColor3 = C.panelRaised,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(value, 0.5),
		Size = UDim2.fromOffset(24, 24),
		ZIndex = 3,
		Parent = track,
	})
	Util.corner(knob, 0.5)
	Util.stroke(knob, C.line, 2)
	local s = { root = root }
	local function show(v: number)
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
	end
	function s.set(_self, v: number)
		value = math.clamp(v, 0, 1)
		show(value)
	end
	local held: InputObject? = nil
	local function pick(input: InputObject)
		local p = Util.inputPos(input)
		local x0, w = track.AbsolutePosition.X, math.max(1, track.AbsoluteSize.X)
		local v = math.floor(math.clamp((p.X - x0) / w, 0, 1) * 20 + 0.5) / 20
		if v ~= value then
			value = v
			show(v)
			if o.onChange then
				o.onChange(v)
			end
		end
	end
	root.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			held = input
			Util.tween(Util.scaler(knob), 0.1, { Scale = 1.2 }, Enum.EasingStyle.Back)
			pick(input)
		end
	end)
	local moved = UserInputService.InputChanged:Connect(function(input)
		local h = held
		if not h then
			return
		end
		if input == h or (h.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
			pick(input)
		end
	end)
	local ended = UserInputService.InputEnded:Connect(function(input)
		local h = held
		if not h then
			return
		end
		if input == h or (h.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
			held = nil
			Util.tween(Util.scaler(knob), 0.12, { Scale = 1 })
			Sound.play("click")
			if o.onRelease then
				task.spawn(o.onRelease, value)
			end
		end
	end)
	root.Destroying:Connect(function()
		moved:Disconnect()
		ended:Disconnect()
	end)
	return s
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
	local n = #o.options
	-- (o.columns: wrap into rows of that many, for a long list like the maps; placed
	-- once the buttons are made)
	local cols = o.columns
	local wrap = cols ~= nil and n > cols
	if not wrap then
		local layout = Util.list(root, "x", 6, o.align or "Left", "Center")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
	end
	local c = { root = root, value = o.value, enabled = true }
	local buttons = {}
	local function paint()
		for _, b in buttons do
			local on = b.value == c.value
			b.frame.BackgroundColor3 = if on then C.orange else C.panelRaised
			b.stroke.Color = if on then C.orange else C.line
			b.label.TextColor3 = if on then C.white else C.textSoft
			b.frame.BackgroundTransparency = if c.enabled or on then 0 else 0.4
		end
	end
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
		Util.corner(f, 10)
		local stroke = Util.stroke(f, C.line, 2)
		local label = Widgets.label(f, {
			text = Widgets.caseOf(opt.text),
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
	if wrap and cols then
		Util.grid(root, cols, math.ceil(n / cols), 6)
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
		BackgroundColor3 = o.track or C.panelDeep,
		BorderSizePixel = 0,
		Size = o.size or UDim2.fromOffset(200, 14),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
		ZIndex = o.z or 1,
		Parent = parent,
	})
	Util.corner(root, 0.5)
	-- (a bare track: no outline)
	local fill = Util.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = o.color or C.sun,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(math.clamp(o.value or 0, 0, 1), 1),
		ZIndex = (o.z or 1) + 1,
		Parent = root,
	})
	Util.corner(fill, 0.5)
	if false then
		local shine = Util.new("Frame", {
			Name = "Shine",
			BackgroundColor3 = C.white,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -6, 0.28, 0),
			Position = UDim2.new(0, 3, 0.16, 0),
			ZIndex = (o.z or 1) + 2,
			Parent = fill,
		})
		Util.corner(shine, 0.5)
	end
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

-- Text input, set into the panel.
function Widgets.textBox(parent: Instance, o: { [string]: any }): TextBox
	local box = Util.new("TextBox", {
		Name = o.name or "TextBox",
		BackgroundColor3 = C.panelDeep,
		BorderSizePixel = 0,
		Text = o.text or "",
		PlaceholderText = o.placeholder or "",
		PlaceholderColor3 = C.textFaint,
		TextColor3 = C.text,
		FontFace = if o.font == "chunky" then Theme.Font.Chunky else Theme.Font.BodyHeavy,
		TextSize = o.textSize or 22,
		ClearTextOnFocus = false,
		Size = o.size or UDim2.fromOffset(200, 44),
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
		Parent = parent,
	})
	box.BackgroundColor3 = C.panelRaised
	Util.corner(box, 12)
	local stroke = Util.stroke(box, C.line, 2)
	box.Focused:Connect(function()
		Util.tween(stroke, 0.15, { Color = C.orange })
	end)
	box.FocusLost:Connect(function(enter)
		Util.tween(stroke, 0.15, { Color = C.line })
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
		ScrollBarImageColor3 = C.panelEdge,
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
	if o.stroke then
		Util.stroke(b, o.stroke, 2)
	end
	Util.pad(b, 8, 0, 8, 0)
	Widgets.label(b, {
		text = o.text or "",
		font = "chunky",
		size = o.textSize or 15,
		color = o.textColor or Theme.textOn(o.color or C.bad),
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
	Util.tween(dim, 0.2, { BackgroundTransparency = 0.35 })
	-- fit the screen: shrink a little if needed, below Roblox's top bar and inside the safe area
	local m = Widgets.metrics
	local w, h, fit = Layout.modal(m, o.width or 560, o.height or 420, o.minScale)
	local cx, cy = Layout.modalCenter(m)
	local content, panel = Widgets.panel(dim, {
		title = o.title,
		titleWidth = o.titleWidth,
		size = UDim2.fromOffset(w, h),
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromOffset(cx, cy),
		z = 101,
		style = o.style or "walnut",
	})
	if fit < 0.999 then
		Util.new("UIScale", { Name = "Fit", Scale = fit, Parent = panel })
	end
	Util.popIn(panel, 0.35, 0.7)
	Sound.play("open")
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local i = table.find(Widgets.openModals, close)
		if i then
			table.remove(Widgets.openModals, i)
		end
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
			style = "panel",
			size = UDim2.fromOffset(38, 40),
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -12, 0, 12),
			onClick = close,
			z = 120,
		})
		x.root.ZIndex = 120
		dim.Activated:Connect(function()
			if o.closeOnBackdrop ~= false then
				close()
			end
		end)
		-- (a controller's B button closes the top one: Widgets.closeTop)
		table.insert(Widgets.openModals, close)
	end
	return content, close, panel
end

-- The close functions of the open modals, oldest first.
Widgets.openModals = {} :: { () -> () }

-- Closes the modal on top (a controller's B, Escape). Returns whether there was one.
function Widgets.closeTop(): boolean
	local close = Widgets.openModals[#Widgets.openModals]
	if close then
		close()
		return true
	end
	return false
end

local toastHolder: Frame? = nil

local function placeToasts()
	local holder = toastHolder
	if not holder then
		return
	end
	local m = Widgets.metrics
	local safe = Layout.safeRect(m, 8)
	local top = math.max(m.topbar.y1, safe.y) + 8
	holder.Position = UDim2.fromOffset(safe.x + safe.w / 2, top)
	holder.Size = UDim2.fromOffset(math.min(560, safe.w), safe.y + safe.h - top)
end

function Widgets.setToastLayer(layer: Instance)
	toastHolder = Util.frame(layer, {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 200,
	})
	Util.list(toastHolder :: Frame, "y", 8, "Center", "Top")
	placeToasts()
end

--[[
	How big a modal can be on this screen at full size (stage pixels), and whether that's
	narrow enough (an upright phone) that a page should stack its columns instead of
	shrinking them.
]]
function Widgets.room(): (number, number, boolean)
	local m = Widgets.metrics
	if not m then
		return 1000, 700, false
	end
	local w, h = Layout.modalRoom(m)
	return w, h, w < 760
end

-- Root calls this whenever the screen changes size or shape.
function Widgets.setMetrics(m)
	Widgets.metrics = m
	placeToasts()
end

local TOAST_COLORS = {
	info = C.sky,
	error = C.coral,
	reward = C.sun,
	party = C.lime,
	turn = C.sun,
}

function Widgets.toast(text: string, kind: string?)
	local holder = toastHolder
	if not holder then
		return
	end
	local color = TOAST_COLORS[kind or "info"] or C.info
	local note = Util.new("Frame", {
		Name = "Toast",
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 201,
		Parent = holder,
	})
	Util.corner(note, 12)
	Util.stroke(note, C.line, 2)
	-- a coloured stripe down the left says what kind of news it is
	local stripe = Util.new("Frame", {
		Name = "Stripe",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		ZIndex = 202,
		Parent = note,
	})
	Util.corner(stripe, 4)
	Util.pad(note, 22, 10, 16, 10)
	local maxW = math.min(540, Layout.safeRect(Widgets.metrics, 8).w)
	Util.new("UISizeConstraint", { MaxSize = Vector2.new(maxW, 200), Parent = note })
	local label = Widgets.label(note, {
		text = text,
		font = "heavy",
		size = 18,
		color = C.text,
		wrap = true,
		align = "center",
		z = 202,
	})
	-- as wide as the text needs, up to the room there is, and as tall as it wraps to (Roblox
	-- sizes a wrapping label that grows both ways by its first line only)
	local room = maxW - 32
	local bounds = TextService:GetTextSize(text, 18, Enum.Font.Nunito, Vector2.new(room / 1.12, 1000))
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.fromOffset(math.min(room, math.ceil(bounds.X * 1.12) + 4), 0)
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

-- Is the user on a touch device? (bigger hit areas, tap-then-confirm flows)
function Widgets.isTouch(): boolean
	return Widgets.metrics.touch or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end

return Widgets
