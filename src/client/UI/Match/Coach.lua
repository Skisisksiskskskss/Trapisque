--[[
	Coach
	The guided first match's teacher: a speech panel from the Overseer (who sees
	everything, after all) along the bottom of the board, with a bouncing arrow at
	whatever the line is about. Each lesson (Shared/Meta/Tutorial.steps) shows once,
	when its moment comes up in the match.

		local coach = Coach.new(screen)    -- screen: the MatchScreen
		coach:event(e)                     -- every event the screen plays
		coach:trigger(name)                -- other moments ("previewed")
		coach:layout(L)                    -- the match layout (Layout.match)
		coach:destroy()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tutorial = require(ReplicatedStorage.Shared.Meta.Tutorial)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local Icons = require(UI.Icons)

local Client = UI.Parent
local Sound = require(Client.Sound)

local C = Theme.C

local Coach = {}
Coach.__index = Coach

local GUIDE = "overseer"

function Coach.new(screen)
	local self = setmetatable({}, Coach)
	self.screen = screen
	self.shown = {}
	self.myTurns = 0
	local root = Util.new("Frame", {
		Name = "Coach",
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 70,
		Parent = screen.root,
	})
	Util.corner(root, 14)
	Util.stroke(root, C.line, 4)
	self.root = root
	local face = Util.frame(root, {
		Name = "Guide",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		ZIndex = 71,
	})
	Icons.medallion(face, GUIDE, Theme.Character[GUIDE] or C.sun, { Size = UDim2.fromScale(1, 1), ZIndex = 71 })
	self.face = face
	self.text = Widgets.label(root, {
		text = "",
		font = "heavy",
		size = 18,
		minSize = 11,
		color = C.text,
		wrap = true,
		scaled = true,
		sizeUDim = UDim2.new(1, -96, 1, -16),
		position = UDim2.fromOffset(84, 8),
		z = 72,
	})
	-- the arrow that points at the dice, the cards or the ability
	local arrow = Util.frame(screen.root, { Name = "CoachArrow", Size = UDim2.fromOffset(46, 46), ZIndex = 72, Visible = false })
	Icons.make(arrow, "down", Icons.flatColors(C.sun, C.panel), { Size = UDim2.fromScale(1, 1), ZIndex = 72 }, 0.08)
	self.arrow = arrow
	task.spawn(function()
		local t = 0
		while root.Parent do
			t += task.wait(0.03)
			if arrow.Visible and self.arrowAt then
				local a = self.arrowAt
				arrow.Position = UDim2.fromOffset(a.X - 23, a.Y - 52 + math.sin(t * 6) * 6)
			end
		end
	end)
	return self
end

function Coach:layout(L)
	self.L = L
	local f = L.focus
	local w = math.min(560, f.w - 24)
	local h = if f.w < 420 then 92 else 84
	self.root.Position = UDim2.fromOffset(f.x + (f.w - w) / 2, f.y + f.h - h - 10)
	self.root.Size = UDim2.fromOffset(w, h)
	self:_point(self.pointAt)
end

-- The arrow sits over the middle of what the line is about.
function Coach:_point(what: string?)
	self.pointAt = what
	local L = self.L
	local r = nil
	if L then
		if what == "dice" then
			r = L.roll
		elseif what == "hand" then
			r = L.hand.rect
		elseif what == "ability" then
			r = L.ability
		end
	end
	if not r then
		self.arrow.Visible = false
		return
	end
	self.arrowAt = Vector2.new(r.x + r.w / 2, r.y)
	self.arrow.Visible = true
end

function Coach:_show(step)
	self.shown[step.id] = true
	self.text.Text = step.text
	self.root.Visible = true
	Util.popIn(self.root, 0.3, 0.8)
	Util.bump(self.face, 0.1)
	Sound.play("pop")
	self:_point(step.point)
	local token = {}
	self.token = token
	if step.when == "won" or step.when == "nearRiver" or step.when == "ability" then
		task.delay(6, function()
			if self.token == token then
				self.root.Visible = false
				self.arrow.Visible = false
			end
		end)
	end
end

function Coach:trigger(name: string)
	for _, step in Tutorial.steps do
		if step.when == name and not self.shown[step.id] then
			self:_show(step)
			return
		end
	end
end

-- Lessons that wait for something in the match.
function Coach:event(e)
	local me = self.screen.mySeat
	local t = e.t
	if t == "turn" and e.p == me then
		self.myTurns += 1
		if self.myTurns == 1 then
			self:trigger("myTurn1")
		elseif self.myTurns == 2 then
			self:trigger("myTurn2")
		end
	elseif t == "gain" and e.p == me then
		self:trigger("gotCard")
	elseif t == "place" and e.p == me then
		self:trigger("placed")
	elseif t == "power" and e.p == me and e.full then
		self:trigger("powerFull")
	elseif t == "ability" and e.p == me then
		self:trigger("ability")
	elseif t == "gameover" then
		self:trigger("won")
	elseif t == "move" and e.p == me then
		-- a river a few tiles ahead
		local tile = e.path[#e.path]
		local view = self.screen.view
		for river, kind in view.natural or {} do
			if kind == "river" and tile and river > tile and river - tile <= 6 then
				self:trigger("nearRiver")
				break
			end
		end
	elseif t == "choose" and e.p == me then
		-- they moved: the "tap again to go" line has done its job
		if self.pointAt == "dice" then
			self.arrow.Visible = false
		end
	end
end

function Coach:destroy()
	self.token = nil
	self.root:Destroy()
	self.arrow:Destroy()
end

return Coach
