--!nocheck
--[[
	Autopilot: plays like a person. Each frame the game's own bot brain reads
	the client's world and the autopilot presses the real input keys (or
	taps the screen halves in couch mode), so input handling is exercised too.
]]

local Autopilot = {}
Autopilot.__index = Autopilot

function Autopilot.new(Mock, side, skill: number?)
	local self = setmetatable({}, Autopilot)
	self.Mock = Mock
	self.side = side
	self.skill = skill or 0.97
	self.App = Mock.module(side, "Client/UI/App")
	self.Bot = Mock.module(side, "Shared/Sim/Bot")
	self.Rng = Mock.module(side, "Shared/Sim/Rng")
	self.brains = {}
	self.held = {}
	self.enabled = true
	self.useTouch = false
	self.flaps = 0
	self.abilities = 0
	self.match = nil
	local Enum = Mock.Enum
	self.flapKeys = { solo = { Enum.KeyCode.Space }, couch = { Enum.KeyCode.W, Enum.KeyCode.Up } }
	self.abilityKeys = { solo = { Enum.KeyCode.E }, couch = { Enum.KeyCode.S, Enum.KeyCode.Down } }
	return self
end

function Autopilot:frame()
	local Mock = self.Mock
	for key, how in self.held do
		if how == "touch" then
			Mock.touch(self.side, key, 0, 0, false)
		else
			Mock.key(self.side, key, false)
		end
	end
	table.clear(self.held)
	local match = self.App.match
	if match ~= self.match then
		self.match = match
		table.clear(self.brains)
	end
	if not (self.enabled and match and match.world and not match.ended) then
		return
	end
	local slots = match.localSlots or {}
	local couch = #slots >= 2
	for i, slot in slots do
		local bird = match.world.birds[slot]
		if bird and bird.alive ~= false then
			local brain = self.brains[slot]
			if not brain then
				brain = self.Bot.newBrain(self.skill, self.Rng.new(slot * 7 + #slots))
				self.brains[slot] = brain
			end
			local ok, flap, ability = pcall(self.Bot.think, match.world, bird, brain)
			if not ok then
				Mock.problem("autopilot", tostring(flap))
				return
			end
			if flap then
				if self.useTouch then
					-- couch on a phone: top half of the screen is player 1
					local vp = self.side.viewport
					local id = "pilot" .. i
					Mock.touch(self.side, id, vp.X / 2, if i == 1 then vp.Y * 0.25 else vp.Y * 0.75, true)
					self.held[id] = "touch"
				else
					local key = (if couch then self.flapKeys.couch else self.flapKeys.solo)[i]
					Mock.key(self.side, key, true)
					self.held[key] = "key"
				end
				self.flaps += 1
			end
			if ability then
				local key = (if couch then self.abilityKeys.couch else self.abilityKeys.solo)[i]
				Mock.key(self.side, key, true)
				Mock.key(self.side, key, false)
				self.abilities += 1
			end
		end
	end
end

return Autopilot
