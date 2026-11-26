--[[
	Input: turns touches, keys, mouse and gamepads into
	  Flap(player, down)   player = 1 or 2 (couch), down = pressed / released
	  Ability(player)

	Solo / online: tap anywhere, Space / W / Up / click, gamepad A or R2.
	               Ability: E / Q / Shift / S / Down / right-click, gamepad X or L2.
	Couch:         P1 (top bird) = top half of the screen, W (flap) / S (ability)
	               P2 (bottom)   = bottom half, Up (flap) / Down (ability)
	               Two gamepads: one each. One gamepad: L1/L2 = P1, R1/R2 = P2.
]]

local UserInputService = game:GetService("UserInputService")

local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.Signal)

local Input = {}
Input.__index = Input

local SOLO_FLAP = {
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonR2] = true,
	[Enum.KeyCode.ButtonR1] = true,
}
local SOLO_ABILITY = {
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.Q] = true,
	[Enum.KeyCode.LeftShift] = true,
	[Enum.KeyCode.RightShift] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.Down] = true,
	[Enum.KeyCode.ButtonX] = true,
	[Enum.KeyCode.ButtonL2] = true,
	[Enum.KeyCode.ButtonL1] = true,
	[Enum.KeyCode.ButtonY] = true,
}

local GAMEPAD_INDEX = {
	[Enum.UserInputType.Gamepad1] = 1,
	[Enum.UserInputType.Gamepad2] = 2,
	[Enum.UserInputType.Gamepad3] = 3,
	[Enum.UserInputType.Gamepad4] = 4,
}

function Input.new(couch: boolean)
	local self = setmetatable({}, Input)
	self.couch = couch
	self.Flap = Signal.new()
	self.Ability = Signal.new()
	self.conns = {}
	self.touchOwner = {}
	self.enabled = true

	table.insert(
		self.conns,
		UserInputService.InputBegan:Connect(function(io, processed)
			self:onInput(io, processed, true)
		end)
	)
	table.insert(
		self.conns,
		UserInputService.InputEnded:Connect(function(io, processed)
			self:onInput(io, processed, false)
		end)
	)
	return self
end

function Input:emitFlap(player: number, down: boolean)
	if self.enabled then
		self.Flap:Fire(player, down)
	end
end

function Input:emitAbility(player: number)
	if self.enabled then
		self.Ability:Fire(player)
	end
end

function Input:onInput(io: InputObject, processed: boolean, began: boolean)
	local t = io.UserInputType
	if t == Enum.UserInputType.Touch then
		if began then
			if processed then
				return -- tapped a UI button
			end
			local player = 1
			if self.couch then
				local y = io.Position.Y
				local h = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 800
				player = if y < h / 2 then 1 else 2
			end
			self.touchOwner[io] = player
			self:emitFlap(player, true)
		else
			local player = self.touchOwner[io]
			if player then
				self.touchOwner[io] = nil
				self:emitFlap(player, false)
			end
		end
		return
	end

	if t == Enum.UserInputType.MouseButton1 then
		if processed and began then
			return
		end
		self:emitFlap(1, began)
		return
	end
	if t == Enum.UserInputType.MouseButton2 then
		if began and not processed then
			self:emitAbility(1)
		end
		return
	end

	local key = io.KeyCode
	if t == Enum.UserInputType.Keyboard then
		if processed and began then
			return -- typing in chat
		end
		if self.couch then
			if key == Enum.KeyCode.W then
				self:emitFlap(1, began)
			elseif key == Enum.KeyCode.S and began then
				self:emitAbility(1)
			elseif key == Enum.KeyCode.Up then
				self:emitFlap(2, began)
			elseif key == Enum.KeyCode.Down and began then
				self:emitAbility(2)
			end
		else
			if SOLO_FLAP[key] then
				self:emitFlap(1, began)
			elseif SOLO_ABILITY[key] and began then
				self:emitAbility(1)
			end
		end
		return
	end

	local pad = GAMEPAD_INDEX[t]
	if pad then
		if self.couch then
			local pads = UserInputService:GetConnectedGamepads()
			if #pads >= 2 then
				local player = if pad == 1 then 1 else 2
				if key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.ButtonR2 then
					self:emitFlap(player, began)
				elseif (key == Enum.KeyCode.ButtonX or key == Enum.KeyCode.ButtonL2) and began then
					self:emitAbility(player)
				end
			else
				if key == Enum.KeyCode.ButtonL1 then
					self:emitFlap(1, began)
				elseif key == Enum.KeyCode.ButtonL2 and began then
					self:emitAbility(1)
				elseif key == Enum.KeyCode.ButtonR1 then
					self:emitFlap(2, began)
				elseif key == Enum.KeyCode.ButtonR2 and began then
					self:emitAbility(2)
				end
			end
		else
			if SOLO_FLAP[key] then
				self:emitFlap(1, began)
			elseif SOLO_ABILITY[key] and began then
				self:emitAbility(1)
			end
		end
	end
end

function Input:destroy()
	for _, c in self.conns do
		c:Disconnect()
	end
	self.Flap:DisconnectAll()
	self.Ability:DisconnectAll()
end

return Input
