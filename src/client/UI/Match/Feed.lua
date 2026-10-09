--[[
	Feed
	The running commentary of the match: short lines with a small icon, newest at the
	top, each fading away after a few seconds. It lives where the layout puts it (under
	the players on PC, top-centre on phones) and keeps only a few lines.

		local feed = Feed.new(parent)
		feed:layout(L.feed)                 -- { rect, lines, align = "left"|"right"|"center" }
		feed:add(text, color?, icon?)       -- text may use <font color> rich text
]]

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)

local C = Theme.C
local hex = Theme.hex

local Feed = {}
Feed.__index = Feed

local LIFE = 7

function Feed.new(parent: Instance)
	local self = setmetatable({}, Feed)
	self.root = Util.frame(parent, { Name = "Feed", ZIndex = 40 })
	self.listLayout = Util.list(self.root, "y", 4, "Right", "Top")
	self.lines = {}
	self.n = 0
	self.max = 4
	self.history = {}
	return self
end

function Feed:destroy()
	self.root:Destroy()
end

function Feed:layout(spec)
	local r = spec.rect
	self.root.Position = UDim2.fromOffset(r.x, r.y)
	self.root.Size = UDim2.fromOffset(r.w, r.h + 40)
	self.max = spec.lines or 4
	self.align = spec.align or "right"
	self.listLayout.HorizontalAlignment = if self.align == "center"
		then Enum.HorizontalAlignment.Center
		elseif self.align == "left" then Enum.HorizontalAlignment.Left
		else Enum.HorizontalAlignment.Right
	self.maxW = r.w
	self.textSize = if r.w < 340 then 13 else 15
	while #self.lines > self.max do
		local old = table.remove(self.lines)
		if old then
			old:Destroy()
		end
	end
end

function Feed:add(text: string, color: Color3?, icon: string?, iconColor: Color3?)
	table.insert(self.history, text)
	if #self.history > 60 then
		table.remove(self.history, 1)
	end
	self.n += 1
	local row = Util.new("Frame", {
		Name = "Line",
		BackgroundColor3 = hex("1F150E"),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		LayoutOrder = -self.n, -- newest on top
		ZIndex = 41,
		Parent = self.root,
	})
	Util.corner(row, 8)
	Util.pad(row, 8, 3, 10, 3)
	Util.list(row, "x", 6, "Left", "Center")
	if icon then
		local ic = Util.frame(row, { Name = "Icon", Size = UDim2.fromOffset(self.textSize + 2, self.textSize + 2), LayoutOrder = 1, ZIndex = 42 })
		Icons.medallion(ic, icon, iconColor or C.brassDark, { Size = UDim2.fromScale(1, 1) })
	end
	local label = Widgets.label(row, {
		text = text,
		font = "heavy",
		size = self.textSize or 15,
		color = color or C.parchment,
		z = 42,
		rich = true,
		layoutOrder = 2,
	})
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.TextWrapped = true
	Util.new("UISizeConstraint", { MaxSize = Vector2.new(math.max(120, (self.maxW or 360) - 40), 60), Parent = label })
	table.insert(self.lines, 1, row)
	while #self.lines > self.max do
		local old = table.remove(self.lines)
		if old then
			old:Destroy()
		end
	end
	Util.popIn(row, 0.2, 0.7)
	task.delay(LIFE, function()
		if row.Parent then
			Util.tween(row, 0.5, { BackgroundTransparency = 1 })
			Util.tween(label, 0.5, { TextTransparency = 1 })
			for _, d in row:GetDescendants() do
				if d:IsA("Frame") and d ~= row then
					Util.tween(d, 0.5, { BackgroundTransparency = 1 })
				elseif d:IsA("UIStroke") then
					Util.tween(d, 0.5, { Transparency = 1 })
				end
			end
			task.delay(0.5, function()
				local i = table.find(self.lines, row)
				if i then
					table.remove(self.lines, i)
				end
				row:Destroy()
			end)
		end
	end)
end

return Feed
