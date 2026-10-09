--[[
	ActionDock
	Your two action areas: the big ROLL button (with RECALL beside it when you have a
	Time Travel anchor) and your character's ability button with its recharge pips.
	Both fill whatever rects the layout gives them, so the same pieces work on a PC,
	a phone held sideways and a phone held upright.

		local dock = ActionDock.new(parent, { character = "mage", touch = bool })
		dock:layout(L.ability, L.roll, form)
		dock:setTurn({ mine, phase, waitingFor, anchor, busy })
		dock:setAbility(ready, progress, usedThisTurn, myTurn)
		dock.onRoll(), dock.onAbility(), dock.onRecall(), dock.onPortrait()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Game.Characters)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)

local C = Theme.C
local hex = Theme.hex

local ActionDock = {}
ActionDock.__index = ActionDock

-- Ability button colour per character (Widgets button styles)
local ABILITY_STYLE = {
	mage = "blue",
	trapper = "wood",
	fire_starter = "red",
	warper = "purple",
	overseer = "brass",
}

function ActionDock.new(parent: Instance, opts)
	local self = setmetatable({}, ActionDock)
	self.character = opts.character
	self.touch = opts.touch == true
	self.def = Characters.get(self.character or "")
	self.abilityRoot = Util.frame(parent, { Name = "Ability" })
	self.rollRoot = Util.frame(parent, { Name = "RollDock" })
	self.turn = { mine = false, phase = "action", busy = true, anchor = 0 }
	self.ability = { ready = false, progress = 0, used = false, myTurn = false }
	return self
end

function ActionDock:destroy()
	self.abilityRoot:Destroy()
	self.rollRoot:Destroy()
end

local function place(f: Frame, r)
	f.Position = UDim2.fromOffset(r.x, r.y)
	f.Size = UDim2.fromOffset(r.w, r.h)
end

function ActionDock:layout(abilityRect, rollRect, form: string)
	self.form = form
	place(self.abilityRoot, abilityRect)
	place(self.rollRoot, rollRect)
	Util.clear(self.abilityRoot)
	Util.clear(self.rollRoot)
	self:_buildAbility(abilityRect, form)
	self:_buildRoll(rollRect, form)
	self:setTurn(self.turn)
	local a = self.ability
	self:setAbility(a.ready, a.progress, a.used, a.myTurn)
end

---------------------------------------------------------------------------
-- ability
---------------------------------------------------------------------------

function ActionDock:_buildAbility(r, form: string)
	local def = self.def
	local color = Theme.Character[self.character] or C.inkSoft
	local box = self.abilityRoot
	local ability = def and def.ability
	self.abilityDef = ability
	self.abilityButton = nil
	self.pips = nil
	self.pipNote = nil

	local function portrait(size: number, x: number, y: number)
		local p = Util.new("TextButton", {
			Name = "Portrait",
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(size, size),
			Parent = box,
		})
		Icons.medallion(p, self.character or "info", color, { Size = UDim2.fromScale(1, 1) })
		p.Activated:Connect(function()
			if self.onPortrait then
				self.onPortrait()
			end
		end)
		p.MouseEnter:Connect(function()
			Util.tween(Util.scaler(p), 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
		end)
		p.MouseLeave:Connect(function()
			Util.tween(Util.scaler(p), 0.12, { Scale = 1 })
		end)
		return p
	end

	local function abilityButton(x: number, y: number, w: number, h: number, textSize: number)
		return Widgets.button(box, {
			name = "AbilityButton",
			text = if ability then string.upper(ability.name) else "",
			style = ABILITY_STYLE[self.character] or "wood",
			textSize = textSize,
			size = UDim2.fromOffset(w, h),
			position = UDim2.fromOffset(x, y),
			onClick = function()
				if self.onAbility then
					self.onAbility()
				end
			end,
		})
	end

	if form == "wide" then
		-- a dark card: portrait, character name, ability button, recharge pips
		local bg = Util.new("Frame", {
			Name = "Back",
			BackgroundColor3 = hex("1F150E"),
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
			Parent = box,
		})
		Util.corner(bg, 14)
		Util.stroke(bg, Util.shade(color, -0.2), 2)
		local ps = math.min(76, r.h - 40)
		portrait(ps, 10, 10)
		Widgets.label(box, {
			name = "Name",
			text = if def then def.name else "",
			font = "chunky",
			size = 20,
			color = C.parchment,
			sizeUDim = UDim2.fromOffset(r.w - ps - 26, 24),
			position = UDim2.fromOffset(ps + 18, 10),
		})
		if ability then
			self.abilityButton = abilityButton(ps + 18, 38, r.w - ps - 28, 42, 18)
			self:_pips(ps + 18, 86, r.w - ps - 28)
		else
			Widgets.label(box, {
				text = "Your strength is always on.",
				font = "heavy",
				size = 13,
				color = hex("BFA98A"),
				wrap = true,
				valign = "top",
				sizeUDim = UDim2.fromOffset(r.w - ps - 28, 44),
				position = UDim2.fromOffset(ps + 18, 40),
			})
		end
		-- the passive, under the portrait
		Widgets.label(box, {
			name = "Hint",
			text = "Tap your portrait to read your card",
			font = "body",
			size = 11,
			color = hex("8F7B60"),
			align = "center",
			sizeUDim = UDim2.fromOffset(r.w - 16, 14),
			position = UDim2.new(0, 8, 1, -20),
		}).Visible = r.h >= 120
	elseif form == "short" then
		local ps = math.min(40, r.h - 30)
		portrait(ps, 0, 2)
		if ability then
			self.abilityButton = abilityButton(ps + 6, 0, r.w - ps - 6, math.max(38, r.h - 30), 15)
			self:_pips(0, r.h - 24, r.w)
		else
			Widgets.label(box, {
				text = if def then def.name else "",
				font = "chunky",
				size = 15,
				color = C.parchment,
				outline = C.ink,
				sizeUDim = UDim2.fromOffset(r.w - ps - 6, ps),
				position = UDim2.fromOffset(ps + 6, 2),
			})
		end
	else
		-- upright phone: one button; the pips ride inside it as text
		if ability then
			self.abilityButton = abilityButton(0, 0, r.w, r.h, 14)
		else
			local ps = r.h
			portrait(ps, 0, 0)
			Widgets.label(box, {
				text = if def then def.name else "",
				font = "chunky",
				size = 14,
				color = C.parchment,
				outline = C.ink,
				sizeUDim = UDim2.fromOffset(r.w - ps - 6, r.h),
				position = UDim2.fromOffset(ps + 6, 0),
			})
		end
	end
end

function ActionDock:_pips(x: number, y: number, w: number)
	local row = Util.frame(self.abilityRoot, {
		Name = "Pips",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, 18),
	})
	Util.list(row, "x", 5, "Center", "Center")
	self.pips = row
	self.pipNote = Widgets.label(self.abilityRoot, {
		name = "PipNote",
		text = "",
		font = "heavy",
		size = 12,
		color = C.woodPale,
		align = "center",
		sizeUDim = UDim2.fromOffset(w, 14),
		position = UDim2.fromOffset(x, y + 18),
	})
	self.pipNote.Visible = self.form == "wide"
end

-- ready: charged; progress: cycles/rounds counted so far; used: already used this turn
function ActionDock:setAbility(ready: boolean, progress: number, used: boolean, myTurn: boolean)
	self.ability = { ready = ready, progress = progress, used = used, myTurn = myTurn }
	local ab = self.abilityDef
	local btn = self.abilityButton
	if not ab or not btn then
		return
	end
	local usable = ready and not used and myTurn
	btn:setEnabled(usable)
	btn:pulse(usable)
	local note = ""
	local dots = ""
	if ab.recharge == "perTurn" then
		note = if used then "Used this turn" else "Every turn"
	elseif ab.recharge == "once" then
		note = if ready then "Once per game" else "Used up"
	else
		local amount = ab.amount or 1
		for i = 1, amount do
			dots ..= if ready or i <= progress then "●" else "○"
		end
		local left = math.max(1, amount - progress)
		local unit = if ab.recharge == "rounds" then "round" else "treasure run"
		note = if ready then "Charged!" else ("Recharges in " .. left .. " " .. unit .. (if left == 1 then "" else "s"))
		if self.pips then
			Util.clear(self.pips, true)
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
		end
	end
	if self.pipNote then
		self.pipNote.Text = note
	end
	if self.form == "tall" then
		btn:setText(string.upper(ab.name) .. (if dots ~= "" then ("  " .. dots) else ""))
	end
end

---------------------------------------------------------------------------
-- roll / recall
---------------------------------------------------------------------------

function ActionDock:_buildRoll(r, form: string)
	local box = self.rollRoot
	self.rollButton = Widgets.button(box, {
		name = "Roll",
		text = "ROLL",
		icon = "dice",
		style = "brass",
		textSize = if form == "wide" then 32 elseif form == "short" then 24 else 22,
		depth = if form == "wide" then 7 else 5,
		size = UDim2.fromScale(1, 1),
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
		textSize = if form == "wide" then 18 else 14,
		size = UDim2.fromScale(1, 1),
		onClick = function()
			if self.onRecall then
				self.onRecall()
			end
		end,
	})
	self.recallButton.root.Visible = false
	if form == "wide" then
		self.waitLabel = Widgets.label(box, {
			name = "Status",
			text = "",
			font = "heavy",
			size = 14,
			color = C.parchment,
			outline = C.ink,
			align = "center",
			wrap = true,
			sizeUDim = UDim2.new(1, 0, 0, 36),
			position = UDim2.new(0, 0, 1, -36),
		})
	else
		self.waitLabel = nil
	end
	self.rollRect = r
end

-- Splits the roll area between ROLL and RECALL when you have an anchor.
function ActionDock:_arrangeRoll(showRecall: boolean)
	local r = self.rollRect
	if not r then
		return
	end
	local roll, recall = self.rollButton.root, self.recallButton.root
	local hasStatus = self.waitLabel ~= nil
	local statusH = if hasStatus then 40 else 0
	if showRecall then
		if self.form == "tall" then
			-- side by side
			local w = (r.w - 6) * 0.62
			roll.Size = UDim2.fromOffset(w, r.h)
			roll.Position = UDim2.fromOffset(0, 0)
			recall.Size = UDim2.fromOffset(r.w - w - 6, r.h)
			recall.Position = UDim2.fromOffset(w + 6, 0)
		else
			local h = (r.h - statusH - 6) * 0.62
			roll.Size = UDim2.fromOffset(r.w, h)
			roll.Position = UDim2.fromOffset(0, 0)
			recall.Size = UDim2.fromOffset(r.w, r.h - statusH - h - 6)
			recall.Position = UDim2.fromOffset(0, h + 6)
		end
	else
		roll.Size = UDim2.fromOffset(r.w, r.h - statusH)
		roll.Position = UDim2.fromOffset(0, 0)
	end
	recall.Visible = showRecall
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
function ActionDock:setTurn(info)
	self.turn = info
	if not self.rollButton then
		return
	end
	local canAct = info.mine and info.phase == "action" and not info.busy
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
	self.recallButton:setEnabled(canAct)
	self:_arrangeRoll(showRecall)
	if self.waitLabel then
		if info.phase == "over" then
			self.waitLabel.Text = "Game over!"
		elseif info.mine then
			self.waitLabel.Text = if info.phase == "shop" then "Pick some potions" elseif self.touch then "Your turn: roll or play a card" else "Your turn  ·  Space to roll"
		else
			self.waitLabel.Text = if info.waitingFor then (info.waitingFor .. " is playing...") else ""
		end
	end
end

return ActionDock
