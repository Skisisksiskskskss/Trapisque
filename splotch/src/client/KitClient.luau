--[[
	KitClient: the client half of each skill. A skill function runs the instant
	the key is pressed (movement, aim) and returns the payload sent to the
	server, or nil to cancel without spending the cooldown.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Geometry = require(Shared.Geometry)
local Remotes = require(Shared.Remotes)

local CameraController = require(script.Parent.CameraController)
local MovementController = require(script.Parent.MovementController)

local KitClient = {}

local player = Players.LocalPlayer

type Payload = { [string]: any }

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Where thrown things leave from: just above and in front of your head.
local function throwOrigin(): Vector3?
	local root = rootPart()
	if not root then
		return nil
	end
	return root.Position + Vector3.new(0, 1.6, 0) + CameraController.flatLook() * 1.2
end

-- A throw aimed so its arc lands on whatever is under the mouse.
local function lob(speed: number, gravity: number): Payload?
	local origin = throwOrigin()
	if not origin then
		return nil
	end
	return {
		origin = origin,
		direction = Geometry.ballisticDirection(origin, CameraController.getAimPoint(), speed, gravity),
	}
end

-- A straight shot at whatever is under the mouse.
local function aimed(): Payload?
	local origin = throwOrigin()
	if not origin then
		return nil
	end
	local target = CameraController.getAimPoint()
	local direction = target - origin
	if direction.Magnitude < 0.1 then
		direction = CameraController.flatLook()
	end
	return { origin = origin, direction = direction.Unit }
end

local TAGGER = Characters.DEFS.Tagger.skills
local PLASTER = Characters.DEFS.Plaster.skills

KitClient.Tagger = {
	function(): Payload?
		local direction = CameraController.flatLook()
		local params = TAGGER[1].params
		MovementController.skillDash(direction, params.speed, params.time)
		return { dir = direction }
	end,
	function(): Payload?
		return lob(TAGGER[2].params.speed, TAGGER[2].params.gravity)
	end,
	function(): Payload?
		return lob(TAGGER[3].params.speed, TAGGER[3].params.gravity)
	end,
	function(): Payload?
		return aimed()
	end,
}

KitClient.Plaster = {
	function(): Payload?
		MovementController.slam(PLASTER[1].params, function(position)
			Remotes.Action:FireServer("SkillEvent", 1, "land", position)
		end)
		return {}
	end,
	function(): Payload?
		return aimed()
	end,
	function(): Payload?
		return { dir = CameraController.flatLook() }
	end,
	function(): Payload?
		local direction = CameraController.flatLook()
		local params = PLASTER[4].params
		MovementController.skillDash(direction, params.speed, params.time)
		return { dir = direction }
	end,
}

return KitClient
