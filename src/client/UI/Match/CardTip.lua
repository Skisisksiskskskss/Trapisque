--[[
	CardTip
	Reading a card without opening anything: hover a card in your hand (or tap it on a
	touch screen) and it rises out of the hand, big, with its rules beside it: what it
	does, how it's played, and what clicking it will do right now. Moving along the
	hand slides the tip from card to card. On touch screens the tip also carries the
	card's buttons, since there's no hover.

		local tip = CardTip.new(layer)
		tip:show(itemId, {
			anchor = { x, y, w, h },     -- the hand card, in stage pixels
			side = "up" | "left" | "right", -- where there's room (towards the board)
			hint = "Click or drag it onto the board",
			ready = true,                -- the hint is something you can do now
			actions = { { text, style, onClick } }?, -- touch: buttons on the tip
		})
		tip:hide() ; tip:destroy() ; tip.visible
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Game.Items)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Icons = require(UI.Icons)
local Cards = require(UI.Cards)
local CardStyle = require(UI.CardStyle)

local C = Theme.C

local CardTip = {}
CardTip.__index = CardTip

local INFO_W = 264
local GAP = 10

local CATEGORY_LABEL = {
	trap = "TRAP",
	assist = "ASSIST",
	neutral = "NEUTRAL",
	potion = "POTION",
	natural = "NATURAL",
}

function CardTip.new(layer: Instance)
	local self = setmetatable({}, CardTip)
	self.layer = layer
	self.visible = false
	self.itemId = nil
	self.group = nil
	return self
end

-- The stage size (the layer fills the stage).
function CardTip:_stage(): Vector2
	local layer = self.layer :: GuiObject
	local k = Util.inheritedScale(layer, true)
	return layer.AbsoluteSize / math.max(k, 1e-3)
end

-- The rules panel: name, kind, what it does, how it's played, what a click does now.
local function buildInfo(parent: Frame, itemId: string, o, width: number, height: number)
	local def = Items.get(itemId)
	local color = Theme.Category[def and def.category or "neutral"] or C.brass
	local panel = Util.new("Frame", {
		Name = "Info",
		BackgroundColor3 = C.panelDeep,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
		Parent = parent,
	})
	Util.corner(panel, 12)
	Util.stroke(panel, color, 2)
	Util.new("UISizeConstraint", { MinSize = Vector2.new(width, math.min(height, 150)), Parent = panel })
	Util.pad(panel, 12, 10, 12, 12)
	local list = Util.list(panel, "y", 6, "Left", "Top")
	list.SortOrder = Enum.SortOrder.LayoutOrder

	-- name and kind
	local head = Util.frame(panel, { Name = "Head", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, ZIndex = 3 })
	local icon = Util.frame(head, { Size = UDim2.fromOffset(30, 30), ZIndex = 3 })
	Icons.medallion(icon, itemId, color, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	local name = Widgets.label(head, {
		text = if def then def.name else itemId,
		font = "chunky",
		size = 19,
		color = C.text,
		sizeUDim = UDim2.new(1, -112, 1, 0),
		position = UDim2.fromOffset(38, 0),
		z = 3,
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	Widgets.badge(head, {
		text = CATEGORY_LABEL[def and def.category or ""] or "",
		color = color,
		height = 22,
		textSize = 13,
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, 0, 0.5, 0),
		z = 4,
	})

	-- what it does
	local rules = Widgets.label(panel, {
		name = "Rules",
		text = if def then def.text else "",
		font = "body",
		size = 16,
		color = C.text,
		wrap = true,
		valign = "top",
		sizeUDim = UDim2.new(1, 0, 0, 0),
		layoutOrder = 2,
		z = 3,
	})
	rules.AutomaticSize = Enum.AutomaticSize.Y

	-- how it's played
	local how = if def and def.price then (def.price .. (if def.price == 1 then " coin" else " coins") .. " at the Potion Seller") else (CardStyle.useText[def and def.use or "none"] or "")
	if how ~= "" then
		local line = Widgets.label(panel, {
			name = "How",
			text = how,
			font = "heavy",
			size = 13,
			color = C.textSoft,
			wrap = true,
			sizeUDim = UDim2.new(1, 0, 0, 0),
			layoutOrder = 3,
			z = 3,
		})
		line.AutomaticSize = Enum.AutomaticSize.Y
	end

	-- what clicking does right now
	if o.hint and o.hint ~= "" then
		local div = Widgets.divider(panel, 4)
		div.Size = UDim2.new(1, 0, 0, 2)
		div.ZIndex = 3
		local hint = Widgets.label(panel, {
			name = "Hint",
			text = o.hint,
			font = "heavy",
			size = 15,
			color = if o.ready then C.brassLight else C.textFaint,
			wrap = true,
			sizeUDim = UDim2.new(1, 0, 0, 0),
			layoutOrder = 5,
			z = 3,
		})
		hint.AutomaticSize = Enum.AutomaticSize.Y
	end

	-- touch screens: the card's buttons
	if o.actions and #o.actions > 0 then
		local row = Util.frame(panel, { Name = "Actions", Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 6, ZIndex = 3 })
		Util.list(row, "x", 8, "Center", "Center")
		local n = #o.actions
		for i, a in o.actions do
			local b = Widgets.button(row, {
				text = a.text,
				style = a.style or "wood",
				textSize = 15,
				size = UDim2.new(1 / n, -8 * (n - 1) / n, 1, 0),
				layoutOrder = i,
				z = 4,
				onClick = a.onClick,
			})
			if a.disabled then
				b:setEnabled(false)
			end
		end
	end
	return panel
end

--[[
	Shows (or slides over to) the tip for `itemId`. The big card sits right above the
	hand card it came from (or beside it, for a column of cards), with the rules panel
	next to it on whichever side has room, or under it on a narrow screen.
]]
function CardTip:show(itemId: string, o)
	local stage = self:_stage()
	local cardW = math.clamp(math.floor(o.anchor.w * 1.5), 116, 186)
	local cardH = math.floor(cardW / CardStyle.aspect)
	local infoW = math.min(INFO_W, math.floor(stage.X - cardW - 3 * GAP - 16))
	local stacked = infoW < 180 -- no room beside the card: the rules go under it
	if stacked then
		infoW = math.min(INFO_W + 40, math.floor(stage.X - 24))
	end

	-- rebuild when the card (or what the tip says) changes; otherwise just slide
	local key = itemId .. "|" .. tostring(o.hint) .. "|" .. tostring(o.ready) .. "|" .. tostring(o.actions and #o.actions or 0)
	local fresh = self.group == nil or self.key ~= key
	if fresh then
		local wasVisible = self.visible and self.group ~= nil
		if self.group then
			self.group:Destroy()
		end
		local group = Util.new("CanvasGroup", {
			Name = "CardTip",
			BackgroundTransparency = 1,
			GroupTransparency = if wasVisible then 0 else 1,
			Size = UDim2.fromOffset(cardW, cardH),
			ZIndex = 75,
			Parent = self.layer,
		})
		local cardSlot = Util.frame(group, { Name = "CardSlot", Size = UDim2.fromOffset(cardW, cardH), ZIndex = 2 })
		Cards.item(cardSlot, itemId, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
		})
		local info = buildInfo(group, itemId, o, infoW, cardH)
		self.group = group
		self.cardSlot = cardSlot
		self.info = info
		self.itemId = itemId
		self.key = key
		self.infoH = nil
		if not wasVisible then
			local s = Util.scaler(group)
			s.Scale = 0.86
			Util.tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
			Util.tween(group, 0.12, { GroupTransparency = 0 })
		else
			-- another card under the pointer: a small hop so the change reads
			Util.bump(cardSlot, 0.05)
		end
	end
	self.visible = true
	self.last = { o = o, cardW = cardW, cardH = cardH, infoW = infoW, stacked = stacked, stage = stage }
	self:_arrange(not fresh)
	if fresh then
		-- the rules panel's height is known a frame later
		task.defer(function()
			if self.group and self.info and self.info.Parent then
				local k = Util.inheritedScale(self.info, false)
				self.infoH = self.info.AbsoluteSize.Y / math.max(k, 1e-3)
				self:_arrange(false)
			end
		end)
	end
end

-- Positions the card, the rules and the whole tip (stage pixels).
function CardTip:_arrange(animate: boolean)
	local l = self.last
	local group = self.group :: CanvasGroup?
	local cardSlot = self.cardSlot :: Frame?
	local info = self.info :: Frame?
	if not l or not group or not cardSlot or not info then
		return
	end
	local o, stage = l.o, l.stage
	local a = o.anchor
	local side = o.side or "up"
	local cardW, cardH, infoW = l.cardW, l.cardH, l.infoW
	local infoH = self.infoH or math.min(cardH, 150)
	local w, h
	if l.stacked then
		w, h = math.max(cardW, infoW), cardH + GAP + infoH
		cardSlot.Position = UDim2.fromOffset((w - cardW) / 2, 0)
		info.Position = UDim2.fromOffset((w - infoW) / 2, cardH + GAP)
	else
		w, h = cardW + GAP + infoW, math.max(cardH, infoH)
	end
	-- where the tip goes: right above the hand card, or beside a column of cards
	local cx, cy = a.x + a.w / 2, a.y + a.h / 2
	local x, y
	if side == "up" then
		x = cx - cardW / 2
		y = a.y - 8 - h
	elseif side == "left" then
		x = a.x - GAP - w
		y = cy - h / 2
	else
		x = a.x + a.w + GAP
		y = cy - h / 2
	end
	if not l.stacked then
		-- the rules sit on the side away from the screen's edge (and away from the hand)
		local rulesRight = if side == "left" then false elseif side == "right" then true else cx + cardW / 2 + GAP + infoW <= stage.X - 8
		local cardX = if rulesRight then 0 else infoW + GAP
		cardSlot.Position = UDim2.fromOffset(cardX, h - cardH)
		info.Position = UDim2.fromOffset(if rulesRight then cardW + GAP else 0, h - infoH)
		if side == "up" then
			x = cx - cardW / 2 - cardX
		end
	else
		x = cx - w / 2
	end
	x = math.clamp(x, 8, math.max(8, stage.X - w - 8))
	y = math.clamp(y, 8, math.max(8, stage.Y - h - 8))
	group.Size = UDim2.fromOffset(w, h)
	if animate then
		Util.tween(group, 0.12, { Position = UDim2.fromOffset(x, y) }, Enum.EasingStyle.Quad)
	else
		group.Position = UDim2.fromOffset(x, y)
	end
end

function CardTip:hide()
	if not self.visible then
		return
	end
	self.visible = false
	local group = self.group
	self.group = nil
	self.itemId = nil
	self.key = nil
	if group then
		Util.tween(group, 0.1, { GroupTransparency = 1 })
		Util.tween(Util.scaler(group), 0.1, { Scale = 0.92 })
		task.delay(0.11, function()
			group:Destroy()
		end)
	end
end

function CardTip:destroy()
	self.visible = false
	if self.group then
		self.group:Destroy()
		self.group = nil
	end
end

return CardTip
