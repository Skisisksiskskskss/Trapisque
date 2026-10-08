--[[
	HandBar
	The wooden shelf along the bottom of the match screen: your character with its
	ability button, the cards in your hand, and the big ROLL button.

		local bar = HandBar.new(parent, { character = "mage", seat = 1 })
		bar:setHand(hand, armed)          -- item ids; armed = { [itemId] = true }
		bar:setTurn(info)                 -- { mine, phase, waitingFor, anchor, busy }
		bar:setAbility(ready, progress, usedThisTurn)
		bar.onCard(itemId, index)         -- a card was clicked
		bar.onRoll(), bar.onAbility(), bar.onRecall(), bar.onPortrait()
		bar:cardCenter(index) -> Vector2? (absolute screen position of a card)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Game.Characters)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local Cards = require(UI.Cards)
local CardStyle = require(UI.CardStyle)

local C = Theme.C

local HandBar = {}
HandBar.__index = HandBar

-- Ability button colour per character (Widgets button styles)
local ABILITY_STYLE = {
	mage = "blue",
	trapper = "wood",
	fire_starter = "red",
	warper = "purple",
	overseer = "brass",
}

local CHARACTER_W = 214
local ACTIONS_W = 176
local CARD_MAX_W = 86
local CARD_GAP = 8

function HandBar.new(parent: Instance, opts)
	local self = setmetatable({}, HandBar)
	self.character = opts.character
	self.cards = {} -- { { id, card, slot } }
	self.hand = {}
	self.armed = {}
	self.maid = Util.maid()

	local content, root = Widgets.panel(parent, {
		name = "HandBar",
		style = "board",
		size = UDim2.fromScale(1, 1),
		padding = 10,
	})
	self.root = root

	self:_buildCharacter(content)
	self:_buildActions(content)

	-- the hand itself, between the character and the buttons
	local hand = Util.frame(content, {
		Name = "Hand",
		Position = UDim2.fromOffset(CHARACTER_W + 10, 0),
		Size = UDim2.new(1, -(CHARACTER_W + ACTIONS_W + 20), 1, 0),
	})
	self.handArea = hand
	local row = Util.frame(hand, { Name = "Row" })
	local layout = Util.list(row, "x", CARD_GAP, "Center", "Center")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	self.row = row
	self.empty = Widgets.label(hand, {
		name = "Empty",
		text = "No cards yet. Land on tokens to spin for some!",
		font = "heavy",
		size = 17,
		color = C.woodPale,
		align = "center",
		sizeUDim = UDim2.fromScale(1, 1),
		wrap = true,
	})
	self.maid:add(hand:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layoutCards()
	end))
	return self
end

function HandBar:destroy()
	self.maid:clean()
	self.root:Destroy()
end

---------------------------------------------------------------------------
-- character + ability
---------------------------------------------------------------------------

function HandBar:_buildCharacter(content: Frame)
	local def = Characters.get(self.character or "")
	local color = Theme.Character[self.character] or C.inkSoft
	local box = Util.frame(content, {
		Name = "Character",
		Size = UDim2.new(0, CHARACTER_W, 1, 0),
	})
	-- portrait (click to read your character card)
	local portrait = Util.new("TextButton", {
		Name = "Portrait",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(84, 84),
		Parent = box,
	})
	Icons.medallion(portrait, self.character or "info", color, { Size = UDim2.fromScale(1, 1) })
	portrait.Activated:Connect(function()
		if self.onPortrait then
			self.onPortrait()
		end
	end)
	portrait.MouseEnter:Connect(function()
		Util.tween(Util.scaler(portrait), 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
	end)
	portrait.MouseLeave:Connect(function()
		Util.tween(Util.scaler(portrait), 0.12, { Scale = 1 })
	end)

	local right = Util.frame(box, {
		Name = "Info",
		Position = UDim2.fromOffset(100, 0),
		Size = UDim2.new(1, -100, 1, 0),
	})
	Widgets.label(right, {
		name = "Name",
		text = if def then def.name else "",
		font = "chunky",
		size = 22,
		color = C.parchment,
		sizeUDim = UDim2.new(1, 0, 0, 26),
		position = UDim2.fromOffset(0, 18),
	})
	local ability = def and def.ability
	if ability then
		self.abilityDef = ability
		self.abilityButton = Widgets.button(right, {
			name = "Ability",
			text = string.upper(ability.name),
			style = ABILITY_STYLE[self.character] or "wood",
			textSize = 20,
			size = UDim2.new(1, -6, 0, 48),
			position = UDim2.fromOffset(0, 48),
			onClick = function()
				if self.onAbility then
					self.onAbility()
				end
			end,
		})
		-- recharge pips under the button
		local pips = Util.frame(right, {
			Name = "Pips",
			Position = UDim2.fromOffset(0, 104),
			Size = UDim2.new(1, -6, 0, 14),
		})
		Util.list(pips, "x", 5, "Center", "Center")
		self.pips = pips
		self.pipNote = Widgets.label(right, {
			name = "PipNote",
			text = "",
			font = "heavy",
			size = 13,
			color = C.woodPale,
			align = "center",
			sizeUDim = UDim2.new(1, -6, 0, 16),
			position = UDim2.fromOffset(0, 120),
		})
	else
		Widgets.label(right, {
			name = "Passive",
			text = "No ability to use: your strength is always on.",
			font = "heavy",
			size = 14,
			color = C.woodPale,
			wrap = true,
			sizeUDim = UDim2.new(1, -6, 0, 60),
			position = UDim2.fromOffset(0, 50),
			valign = "top",
		})
	end
end

-- ready: charged; progress: cycles/rounds counted so far; used: already used this turn
function HandBar:setAbility(ready: boolean, progress: number, used: boolean, myTurn: boolean)
	local ab = self.abilityDef
	local btn = self.abilityButton
	if not ab or not btn then
		return
	end
	btn:setEnabled(ready and not used and myTurn)
	btn:pulse(ready and not used and myTurn)
	Util.clear(self.pips, true)
	local note = ""
	if ab.recharge == "perTurn" then
		note = if used then "Used this turn" else "Every turn"
	elseif ab.recharge == "once" then
		note = if ready then "Once per game" else "Used up"
	else
		local amount = ab.amount or 1
		for i = 1, amount do
			local filled = ready or i <= progress
			local pip = Util.new("Frame", {
				Name = "Pip" .. i,
				BackgroundColor3 = if filled then C.brass else C.woodDeep,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(12, 12),
				LayoutOrder = i,
				Parent = self.pips,
			})
			Util.corner(pip, 0.5)
			Util.stroke(pip, C.brassDark, 1.5)
		end
		local unit = if ab.recharge == "rounds" then "rounds" else "treasure runs"
		note = if ready then "Charged!" else ("Recharges in " .. math.max(0, amount - progress) .. " " .. unit)
	end
	self.pipNote.Text = note
end

---------------------------------------------------------------------------
-- actions
---------------------------------------------------------------------------

function HandBar:_buildActions(content: Frame)
	local box = Util.frame(content, {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, ACTIONS_W, 1, 0),
	})
	self.rollButton = Widgets.button(box, {
		name = "Roll",
		text = "ROLL",
		icon = "dice",
		style = "brass",
		textSize = 32,
		depth = 7,
		size = UDim2.new(1, 0, 0, 74),
		position = UDim2.fromOffset(0, 8),
		onClick = function()
			if self.onRoll then
				self.onRoll()
			end
		end,
	})
	self.recallButton = Widgets.button(box, {
		name = "Recall",
		text = "RECALL",
		icon = "time_potion",
		style = "purple",
		textSize = 18,
		size = UDim2.new(1, 0, 0, 42),
		position = UDim2.fromOffset(0, 92),
		onClick = function()
			if self.onRecall then
				self.onRecall()
			end
		end,
	})
	self.recallButton.root.Visible = false
	self.waitLabel = Widgets.label(box, {
		name = "Waiting",
		text = "",
		font = "heavy",
		size = 15,
		color = C.woodPale,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromOffset(0, 96),
	})
end

--[[
	info = {
		mine = boolean,        -- it's my turn
		phase = string,        -- engine phase ("action", "shop", "over")
		waitingFor = string?,  -- whose turn it is (when not mine)
		anchor = number,       -- my time anchor tile (0 = none)
		busy = boolean,        -- animations still playing / a request in flight
	}
]]
function HandBar:setTurn(info)
	local canAct = info.mine and info.phase == "action" and not info.busy
	self.myTurn = info.mine
	self.canAct = canAct
	self.rollButton:setEnabled(canAct)
	self.rollButton:pulse(canAct)
	if info.mine and info.phase == "shop" then
		self.rollButton:setText("SHOPPING")
	elseif info.mine then
		self.rollButton:setText("ROLL")
	else
		self.rollButton:setText("WAIT")
	end
	local showRecall = info.mine and (info.anchor or 0) > 0 and info.phase == "action"
	self.recallButton.root.Visible = showRecall
	self.recallButton:setEnabled(canAct)
	self.waitLabel.Visible = not showRecall
	if info.phase == "over" then
		self.waitLabel.Text = "Game over!"
	elseif info.mine then
		self.waitLabel.Text = if info.phase == "shop" then "Pick some potions" else "Your turn: roll or play a card"
	else
		self.waitLabel.Text = if info.waitingFor then (info.waitingFor .. " is playing...") else ""
	end
	for _, entry in self.cards do
		entry.card.root:SetAttribute("Playable", canAct)
	end
end

---------------------------------------------------------------------------
-- the hand
---------------------------------------------------------------------------

local function sameList(a, b): boolean
	if #a ~= #b then
		return false
	end
	for i, v in a do
		if b[i] ~= v then
			return false
		end
	end
	return true
end

function HandBar:setHand(hand: { string }, armed: { [string]: boolean }?)
	armed = armed or {}
	local changed = not sameList(hand, self.hand)
	self.hand = table.clone(hand)
	self.armed = armed :: { [string]: boolean }
	if changed then
		for _, entry in self.cards do
			entry.slot:Destroy()
		end
		self.cards = {}
		for i, id in hand do
			local slot = Util.frame(self.row, {
				Name = "Slot" .. i,
				Size = UDim2.fromOffset(CARD_MAX_W, CARD_MAX_W / CardStyle.aspect),
				LayoutOrder = i,
			})
			local card = Cards.item(slot, id, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
			})
			Cards.interactive(card, function()
				if self.onCard then
					self.onCard(id, i)
				end
			end)
			table.insert(self.cards, { id = id, card = card, slot = slot })
		end
		self:_layoutCards()
	end
	-- armed boosts stand up out of the hand with a brass rim
	for _, entry in self.cards do
		local on = self.armed[entry.id] == true
		local root = entry.card.root
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
		Util.tween(root, 0.2, { Position = UDim2.new(0.5, 0, 0.5, if on then -14 else 0) }, Enum.EasingStyle.Back)
	end
	self.empty.Visible = #hand == 0
end

function HandBar:_layoutCards()
	local n = #self.cards
	if n == 0 then
		return
	end
	local area = self.handArea.AbsoluteSize / Util.inheritedScale(self.handArea)
	local maxH = area.Y - 18
	local w = math.min(CARD_MAX_W, (area.X - (n - 1) * CARD_GAP) / n, maxH * CardStyle.aspect)
	for _, entry in self.cards do
		entry.slot.Size = UDim2.fromOffset(w, w / CardStyle.aspect)
	end
end

-- Absolute screen centre of card `index` (for cards flying in or out).
function HandBar:cardCenter(index: number?): Vector2?
	local entry = if index then self.cards[index] else nil
	local target: GuiObject = if entry then entry.slot else self.row
	return target.AbsolutePosition + target.AbsoluteSize / 2
end

-- Flash a card that can't be played right now.
function HandBar:nudgeCard(index: number)
	local entry = self.cards[index]
	if entry then
		Util.shake(entry.card.root, 5, 0.25)
	end
end

return HandBar
