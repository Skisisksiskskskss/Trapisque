--[[
	Util
	Small helpers for building and animating UI in code.
]]

local TweenService = game:GetService("TweenService")

local Util = {}

---------------------------------------------------------------------------
-- feature detection (newer UI features degrade gracefully)
---------------------------------------------------------------------------
Util.has = {}
do
	local s = Instance.new("UIStroke")
	Util.has.scaledStroke = pcall(function()
		(s :: any).StrokeSizingMode = (Enum :: any).StrokeSizingMode.ScaledSize
	end)
	s:Destroy()
end

---------------------------------------------------------------------------
-- instances
---------------------------------------------------------------------------

function Util.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- A plain transparent frame (the most common building block).
function Util.frame(parent: Instance?, props: { [string]: any }?): Frame
	local f = Util.new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	})
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(f :: any)[k] = v
			end
		end
	end
	f.Parent = parent
	return f
end

function Util.corner(inst: Instance, radius: number?): UICorner
	local r = radius or 8
	return Util.new("UICorner", {
		CornerRadius = if r <= 1 then UDim.new(r, 0) else UDim.new(0, r),
		Parent = inst,
	})
end

function Util.stroke(inst: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	return Util.new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")
			then Enum.ApplyStrokeMode.Contextual
			else Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

-- Stroke whose thickness scales with its parent (fraction of the smaller side).
-- Falls back to `fallbackPx` pixels where scaled strokes aren't supported.
function Util.scaledStroke(inst: Instance, color: Color3, fraction: number, fallbackPx: number): UIStroke
	local s = Util.new("UIStroke", {
		Color = color,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = fallbackPx,
		Parent = inst,
	})
	if Util.has.scaledStroke then
		pcall(function()
			(s :: any).StrokeSizingMode = (Enum :: any).StrokeSizingMode.ScaledSize
			s.Thickness = fraction
		end)
	end
	return s
end

function Util.pad(inst: Instance, l: number, t: number?, r: number?, b: number?): UIPadding
	return Util.new("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t or l),
		PaddingRight = UDim.new(0, r or l),
		PaddingBottom = UDim.new(0, b or t or l),
		Parent = inst,
	})
end

function Util.list(inst: Instance, direction: string?, padding: number?, hAlign: string?, vAlign: string?): UIListLayout
	return Util.new("UIListLayout", {
		FillDirection = if direction == "x" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		HorizontalAlignment = Enum.HorizontalAlignment[hAlign or "Center"],
		VerticalAlignment = Enum.VerticalAlignment[vAlign or "Center"],
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = inst,
	})
end

function Util.ratio(inst: Instance, r: number): UIAspectRatioConstraint
	return Util.new("UIAspectRatioConstraint", { AspectRatio = r, Parent = inst })
end

-- Colors: a ColorSequence from a list of colors (evenly spaced) or {time, color} pairs.
function Util.seq(list: { any }): ColorSequence
	local kps = {}
	for i, v in list do
		if typeof(v) == "Color3" then
			local t = if #list == 1 then 0 else (i - 1) / (#list - 1)
			table.insert(kps, ColorSequenceKeypoint.new(t, v))
		else
			table.insert(kps, ColorSequenceKeypoint.new(v[1], v[2]))
		end
	end
	if #kps == 1 then
		table.insert(kps, ColorSequenceKeypoint.new(1, kps[1].Value))
		kps[1] = ColorSequenceKeypoint.new(0, kps[1].Value)
	end
	return ColorSequence.new(kps)
end

function Util.nseq(list: { any }): NumberSequence
	local kps = {}
	for i, v in list do
		if type(v) == "number" then
			local t = if #list == 1 then 0 else (i - 1) / (#list - 1)
			table.insert(kps, NumberSequenceKeypoint.new(t, v))
		else
			table.insert(kps, NumberSequenceKeypoint.new(v[1], v[2]))
		end
	end
	return NumberSequence.new(kps)
end

function Util.grad(inst: Instance, colors: any, rotation: number?, transparency: any?): UIGradient
	local g = Util.new("UIGradient", {
		Color = if typeof(colors) == "ColorSequence" then colors else Util.seq(colors),
		Rotation = rotation or 90,
		Parent = inst,
	})
	if transparency then
		g.Transparency = if typeof(transparency) == "NumberSequence" then transparency else Util.nseq(transparency)
	end
	return g
end

-- Product of every UIScale above `inst` (the stage scales the whole UI); with
-- includeSelf, also the UIScales directly inside `inst`.
--[[
	Where an input is, in the pixels AbsolutePosition uses in our full-screen
	(IgnoreGuiInset) ScreenGui. InputObject.Position starts below Roblox's top bar, so
	the bar's height is added back.
]]
function Util.inputPos(input: InputObject | Vector3 | Vector2): Vector2
	local GuiService = game:GetService("GuiService")
	local inset = GuiService:GetGuiInset()
	local p = if typeof(input) == "Instance" then (input :: InputObject).Position else input
	return Vector2.new((p :: any).X, (p :: any).Y) + inset
end

function Util.inheritedScale(inst: Instance, includeSelf: boolean?): number
	local s = 1
	local node: Instance? = if includeSelf then inst else inst.Parent
	while node do
		for _, child in node:GetChildren() do
			if child:IsA("UIScale") then
				s *= child.Scale
			end
		end
		node = node.Parent
	end
	return s
end

-- Hard drop shadow: a flat dark copy of the frame's shape, offset straight down.
function Util.shadow(inst: GuiObject, opts: { [string]: any }?)
	local o = opts or {}
	local offset = o.offset or 4
	local transparency = o.transparency or 0.55
	local parent = inst.Parent
	if not parent then
		return
	end
	local sh = Util.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = o.color or Color3.new(0, 0, 0),
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		AnchorPoint = inst.AnchorPoint,
		Position = inst.Position + UDim2.fromOffset(0, offset),
		Size = inst.Size,
		Rotation = inst.Rotation,
		ZIndex = math.max(0, inst.ZIndex - 1),
		Parent = parent,
	})
	local c = inst:FindFirstChildOfClass("UICorner")
	if c then
		c:Clone().Parent = sh
	end
	inst:GetPropertyChangedSignal("Position"):Connect(function()
		sh.Position = inst.Position + UDim2.fromOffset(0, offset)
	end)
	inst:GetPropertyChangedSignal("Size"):Connect(function()
		sh.Size = inst.Size
	end)
	inst:GetPropertyChangedSignal("Visible"):Connect(function()
		sh.Visible = inst.Visible
	end)
	inst.Destroying:Connect(function()
		sh:Destroy()
	end)
end

---------------------------------------------------------------------------
-- color math
---------------------------------------------------------------------------

function Util.mix(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

-- amount > 0 lightens toward white, < 0 darkens toward black
function Util.shade(c: Color3, amount: number): Color3
	if amount >= 0 then
		return c:Lerp(Color3.new(1, 1, 1), amount)
	end
	return c:Lerp(Color3.new(0, 0, 0), -amount)
end

---------------------------------------------------------------------------
-- tweening
---------------------------------------------------------------------------

function Util.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, delay: number?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	t:Play()
	return t
end

-- Tween and wait for it (yields).
function Util.tweenWait(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = Util.tween(inst, time, props, style, dir)
	if time > 0 then
		t.Completed:Wait()
	end
end

-- Returns (or creates) a UIScale on inst for pop/squash animations.
function Util.scaler(inst: Instance): UIScale
	local s = inst:FindFirstChild("PopScale")
	if not s then
		s = Util.new("UIScale", { Name = "PopScale", Parent = inst })
	end
	return s :: UIScale
end

-- Pops an element in from small to full size.
function Util.popIn(inst: GuiObject, time: number?, from: number?)
	local s = Util.scaler(inst)
	s.Scale = from or 0.6
	Util.tween(s, time or 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

-- A quick bounce (scale up then back).
function Util.bump(inst: GuiObject, amount: number?)
	local s = Util.scaler(inst)
	local peak = 1 + (amount or 0.12)
	Util.tween(s, 0.08, { Scale = peak }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.08, function()
		if s.Parent then
			Util.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end)
end

-- Horizontal shake (e.g. "not allowed" or getting hit).
function Util.shake(inst: GuiObject, strength: number?, time: number?)
	local base = inst.Position
	local s = strength or 6
	local steps = 6
	local dt = (time or 0.3) / steps
	task.spawn(function()
		for i = 1, steps do
			if not inst.Parent then
				return
			end
			local dx = (if i % 2 == 0 then 1 else -1) * s * (1 - i / steps)
			inst.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(dt)
		end
		if inst.Parent then
			inst.Position = base
		end
	end)
end

---------------------------------------------------------------------------
-- cleanup
---------------------------------------------------------------------------

local Maid = {}
Maid.__index = Maid

function Util.maid()
	return setmetatable({ items = {} }, Maid)
end

function Maid:add(item)
	table.insert(self.items, item)
	return item
end

function Maid:clean()
	for _, item in self.items do
		local t = typeof(item)
		if t == "RBXScriptConnection" then
			item:Disconnect()
		elseif t == "Instance" then
			item:Destroy()
		elseif type(item) == "function" then
			task.spawn(item)
		elseif type(item) == "table" and item.Destroy then
			item:Destroy()
		end
	end
	self.items = {}
end

function Util.clear(inst: Instance, keepLayouts: boolean?)
	for _, c in inst:GetChildren() do
		if not (keepLayouts and (c:IsA("UIListLayout") or c:IsA("UIGridLayout") or c:IsA("UIPadding") or c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient"))) then
			c:Destroy()
		end
	end
end

function Util.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Util.commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

return Util
