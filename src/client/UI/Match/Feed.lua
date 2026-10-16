--[[
	Feed
	The running commentary of the match: short lines with a small icon, newest at the
	top, each fading away after a few seconds. It lives where the layout puts it (under
	the players on PC, top-centre on phones) and keeps only a few lines.

		local feed = Feed.new(parent)
		feed:layout(L.feed)                 -- { rect, lines, align = "left"|"right"|"center" }
		feed:add(text, color?, icon?)       -- text may use <font color> rich text
]]

local TextService = game:GetService("TextService")

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)

local C = Theme.C

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
	self.maxH = r.h + 30
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
	local size = self.textSize or 15
	local iconW = if icon then size + 2 + 6 else 0
	local padX, padY = 18, 6
	-- measure the line (tags stripped) so a long one wraps onto a taller row
	local plain = string.gsub(text, "<[^>]+>", "")
	local room = math.max(120, (self.maxW or 360) - padX - iconW)
	local bounds = TextService:GetTextSize(plain, size, Enum.Font.Oswald, Vector2.new(room, 1000))
	local textW = math.min(room, math.ceil(bounds.X * 1.06) + 2)
	local textH = math.max(size + 2, math.ceil(bounds.Y) + 2)
	local row = Util.new("Frame", {
		Name = "Line",
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(textW + padX + iconW, textH + padY),
		LayoutOrder = -self.n, -- newest on top
		ZIndex = 41,
		Parent = self.root,
	})
	Util.corner(row, 8)
	Util.stroke(row, C.line, 2)
	Util.pad(row, 8, 3, 10, 3)
	Util.list(row, "x", 6, "Left", "Center")
	if icon then
		local ic = Util.frame(row, { Name = "Icon", Size = UDim2.fromOffset(size + 2, size + 2), LayoutOrder = 1, ZIndex = 42 })
		Icons.medallion(ic, icon, iconColor or C.sun, { Size = UDim2.fromScale(1, 1) })
	end
	local label = Widgets.label(row, {
		text = text,
		font = "heavy",
		size = size,
		-- (a line's colour is darkened until it reads on the cream row)
		color = if color then Theme.inkOf(color) else C.text,
		z = 42,
		rich = true,
		wrap = true,
		layoutOrder = 2,
		sizeUDim = UDim2.fromOffset(textW, textH),
	})
	label.TextYAlignment = Enum.TextYAlignment.Center
	table.insert(self.lines, 1, row)
	-- keep as many lines as fit (two-line rows take two places)
	local used = 0
	for i, line in self.lines do
		used += line.Size.Y.Offset + 4
		if i > 1 and (i > self.max or used > (self.maxH or math.huge)) then
			for j = #self.lines, i, -1 do
				local old = table.remove(self.lines, j)
				if old then
					old:Destroy()
				end
			end
			break
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
