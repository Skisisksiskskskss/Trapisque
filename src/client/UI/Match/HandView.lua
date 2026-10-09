--[[
	HandView
	Your cards, as a row (PC, upright phones) or a column (landscape phones). Cards are
	added and removed one at a time, the moment their animation lands, so the hand never
	lags behind what you just saw. Too many cards to fit? They shrink a little (to 70%),
	then the hand scrolls.

		local hand = HandView.new(parent, { touch = bool })
		hand:layout(L.hand)                 -- { rect, dir = "x"|"y", card = { w, h }, gap }
		hand:setHand(ids, armed)            -- reconcile with the server's hand
		hand:add(id) ; hand:remove(id)      -- one card in / out, animated
		hand:slotCenter(index?) -> Vector2  -- absolute screen position (nil: where the next card goes)
		hand.onCard(id, index)
]]

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Cards = require(UI.Cards)
local CardStyle = require(UI.CardStyle)

local C = Theme.C
local hex = Theme.hex

local HandView = {}
HandView.__index = HandView

function HandView.new(parent: Instance, opts)
	local self = setmetatable({}, HandView)
	self.touch = opts and opts.touch == true
	self.list = {} -- { { id, slot, card } }
	self.armed = {}
	self.maid = Util.maid()
	self.root = Util.frame(parent, { Name = "Hand" })
	self.scroll = (Util.new("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.brass,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = self.root,
	}) :: ScrollingFrame)
	self.listLayout = Util.list(self.scroll, "x", 8, "Center", "Center")
	self.listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	self.empty = Widgets.label(self.root, {
		name = "Empty",
		text = "No cards yet. Land on tokens to spin for some!",
		font = "heavy",
		size = 15,
		color = C.parchment,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.fromScale(1, 1),
		outline = C.ink,
	})
	return self
end

function HandView:destroy()
	self.maid:clean()
	self.root:Destroy()
end

function HandView:layout(spec)
	self.spec = spec
	local r = spec.rect
	self.root.Position = UDim2.fromOffset(r.x, r.y)
	self.root.Size = UDim2.fromOffset(r.w, r.h)
	local vertical = spec.dir == "y"
	local scroll = self.scroll :: ScrollingFrame
	self.listLayout.FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	self.listLayout.Padding = UDim.new(0, spec.gap or 6)
	self.listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	self.listLayout.VerticalAlignment = if vertical then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Center
	scroll.ScrollingDirection = if vertical then Enum.ScrollingDirection.Y else Enum.ScrollingDirection.X
	scroll.AutomaticCanvasSize = if vertical then Enum.AutomaticSize.Y else Enum.AutomaticSize.X
	-- room for armed cards to stand up out of the row
	Util.clear(scroll, true)
	local pad = scroll:FindFirstChildOfClass("UIPadding") or Util.pad(scroll, 0)
	pad.PaddingTop = UDim.new(0, if vertical then 4 else 8)
	pad.PaddingLeft = UDim.new(0, if vertical then 4 else 6)
	pad.PaddingRight = UDim.new(0, if vertical then 14 else 6)
	self.empty.TextSize = if r.w < 200 then 12 else 15
	local ids = {}
	for _, e in self.list do
		table.insert(ids, e.id)
	end
	self.list = {}
	for _, id in ids do
		self:_make(id, false)
	end
	self:_resize()
	self:_refresh()
end

-- card size: as big as the layout asks, shrinking (down to 70%) before it scrolls
function HandView:_cardSize(): (number, number)
	local spec = self.spec
	local n = math.max(1, #self.list)
	local w, h = spec.card.w, spec.card.h
	local gap = spec.gap or 6
	local r = spec.rect
	if spec.dir == "y" then
		local fit = (r.h - 8 - (n - 1) * gap) / n
		h = math.clamp(fit, h * 0.7, h)
		w = h * CardStyle.aspect
	else
		local fit = (r.w - 12 - (n - 1) * gap) / n
		w = math.clamp(fit, w * 0.7, w)
		h = w / CardStyle.aspect
	end
	return w, h
end

function HandView:_resize()
	if not self.spec then
		return
	end
	local w, h = self:_cardSize()
	for _, e in self.list do
		e.slot.Size = UDim2.fromOffset(w, h)
	end
end

function HandView:_make(id: string, animate: boolean)
	local index = #self.list + 1
	local slot = Util.frame(self.scroll, {
		Name = "Slot",
		Size = UDim2.fromOffset(self.spec.card.w, self.spec.card.h),
		LayoutOrder = index,
	})
	local card = Cards.item(slot, id, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	})
	local entry = { id = id, slot = slot, card = card }
	Cards.interactive(card, function()
		local i = table.find(self.list, entry)
		if self.onCard and i then
			self.onCard(id, i)
		end
	end)
	table.insert(self.list, entry)
	if animate then
		local s = Util.scaler(card.root)
		s.Scale = 0.4
		Util.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	return entry
end

-- keyboard numbers (PC) and the raised, brass-rimmed look of armed boosts
function HandView:_refresh()
	for i, e in self.list do
		e.slot.LayoutOrder = i
		local root = e.card.root
		local key = root:FindFirstChild("KeyHint")
		if not self.touch and i <= 9 then
			if not key then
				local badge = Util.new("Frame", {
					Name = "KeyHint",
					BackgroundColor3 = hex("1F150E"),
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.12, 0.06),
					Size = UDim2.fromOffset(18, 18),
					ZIndex = 45,
					Parent = root,
				})
				Util.corner(badge, 5)
				Util.stroke(badge, C.brass, 1.5)
				Widgets.label(badge, {
					name = "N",
					text = tostring(i),
					font = "chunky",
					size = 12,
					color = C.brass,
					align = "center",
					sizeUDim = UDim2.fromScale(1, 1),
					z = 46,
				})
				key = badge
			end
			local label = (key :: Frame):FindFirstChild("N", true)
			if label then
				(label :: TextLabel).Text = tostring(i)
			end
		elseif key then
			key:Destroy()
		end
		local on = self.armed[e.id] == true
		local rim = root:FindFirstChild("ArmedRim")
		if on and not rim then
			local r = Util.new("Frame", {
				Name = "ArmedRim",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 40,
				Parent = root,
			})
			Util.corner(r, CardStyle.corner)
			Util.stroke(r, C.brassLight, 4)
		elseif not on and rim then
			rim:Destroy()
		end
		local lift = if on then -10 else 0
		if self.spec and self.spec.dir == "y" then
			-- a column of cards: armed ones slide out towards the board
			Util.tween(root, 0.2, { Position = UDim2.new(0.5, -lift, 0.5, 0) }, Enum.EasingStyle.Back)
		else
			Util.tween(root, 0.2, { Position = UDim2.new(0.5, 0, 0.5, lift) }, Enum.EasingStyle.Back)
		end
	end
	self.empty.Visible = #self.list == 0
end

-- Reconcile with an authoritative hand (keeps cards that are already there).
function HandView:setHand(ids: { string }, armed: { [string]: boolean }?)
	self.armed = armed or {}
	if not self.spec then
		self.pending = ids
		return
	end
	local same = #ids == #self.list
	if same then
		for i, id in ids do
			if self.list[i].id ~= id then
				same = false
				break
			end
		end
	end
	if not same then
		for _, e in self.list do
			e.slot:Destroy()
		end
		self.list = {}
		for _, id in ids do
			self:_make(id, false)
		end
		self:_resize()
	end
	self:_refresh()
end

function HandView:setArmed(armed: { [string]: boolean })
	self.armed = armed
	self:_refresh()
end

-- A card arrives (its flight just landed on the hand).
function HandView:add(id: string)
	if not self.spec then
		return
	end
	self:_make(id, true)
	self:_resize()
	self:_refresh()
	-- show the newest card if the hand scrolls
	task.defer(function()
		local cs = self.scroll.AbsoluteCanvasSize
		local ws = self.scroll.AbsoluteWindowSize
		self.scroll.CanvasPosition = Vector2.new(math.max(0, cs.X - ws.X), math.max(0, cs.Y - ws.Y))
	end)
end

-- A card leaves (played, placed, given away). Removes the first copy of `id`.
function HandView:remove(id: string)
	for i, e in self.list do
		if e.id == id then
			table.remove(self.list, i)
			local s = Util.scaler(e.card.root)
			Util.tween(s, 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.delay(0.19, function()
				e.slot:Destroy()
				self:_resize()
			end)
			self:_refresh()
			return
		end
	end
end

function HandView:ids(): { string }
	local out = {}
	for _, e in self.list do
		table.insert(out, e.id)
	end
	return out
end

-- Absolute screen centre of card `index`, or of where the next card will go.
function HandView:slotCenter(index: number?): Vector2
	local e = if index then self.list[index] else self.list[#self.list]
	if e then
		local c = e.slot.AbsolutePosition + e.slot.AbsoluteSize / 2
		if not index then
			-- one slot further along
			local step = e.slot.AbsoluteSize + Vector2.new(6, 6)
			if self.spec and self.spec.dir == "y" then
				c += Vector2.new(0, step.Y)
			else
				c += Vector2.new(step.X, 0)
			end
			local rootEnd = self.root.AbsolutePosition + self.root.AbsoluteSize
			c = Vector2.new(math.min(c.X, rootEnd.X - 20), math.min(c.Y, rootEnd.Y - 20))
		end
		return c
	end
	return self.root.AbsolutePosition + self.root.AbsoluteSize / 2
end

-- Wiggle a card that can't be played right now.
function HandView:nudge(index: number)
	local e = self.list[index]
	if e then
		Util.shake(e.card.root, 5, 0.25)
	end
end

return HandView
