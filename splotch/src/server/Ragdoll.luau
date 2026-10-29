--[[
	Ragdoll: real R6 ragdolls. setup() adds a disabled ball-socket and a limb
	collider for every limb joint. set() swaps the Motor6Ds for the sockets.

	The server toggles the joints (so every client sees the same thing) and the
	character's owner switches its humanoid into the Physics state and applies
	the launch velocity (see client/MovementController).
]]

local Ragdoll = {}

type JointSpec = { motor: string, limb: string, upper: number, twist: number, axis: Vector3 }

local JOINTS: { JointSpec } = {
	{ motor = "Neck", limb = "Head", upper = 40, twist = 35, axis = Vector3.new(0, 1, 0) },
	{ motor = "Left Shoulder", limb = "Left Arm", upper = 110, twist = 70, axis = Vector3.new(0, -1, 0) },
	{ motor = "Right Shoulder", limb = "Right Arm", upper = 110, twist = 70, axis = Vector3.new(0, -1, 0) },
	{ motor = "Left Hip", limb = "Left Leg", upper = 75, twist = 20, axis = Vector3.new(0, -1, 0) },
	{ motor = "Right Hip", limb = "Right Leg", upper = 75, twist = 20, axis = Vector3.new(0, -1, 0) },
}

-- An attachment at `position` whose primary (X) axis points along `axis`.
local function axisAttachment(parent: BasePart, name: string, position: Vector3, axis: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = CFrame.fromMatrix(position, axis, Vector3.new(0, 0, -1))
	attachment.Parent = parent
	return attachment
end

function Ragdoll.setup(character: Model)
	local torso = character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	for _, spec in JOINTS do
		local motor = torso:FindFirstChild(spec.motor)
		local limb = character:FindFirstChild(spec.limb)
		if motor and motor:IsA("Motor6D") and limb and limb:IsA("BasePart") then
			local a0 = axisAttachment(torso, "Rag" .. spec.motor, motor.C0.Position, spec.axis)
			local a1 = axisAttachment(limb, "Rag" .. spec.motor, motor.C1.Position, spec.axis)
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "Rag" .. spec.motor
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = spec.upper
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -spec.twist
			socket.TwistUpperAngle = spec.twist
			socket.Enabled = false
			socket.Parent = torso

			if spec.limb ~= "Head" then
				-- R6 limbs never collide on their own; this lets them rest on the floor.
				local collider = Instance.new("Part")
				collider.Name = "RagCollider"
				collider.Size = limb.Size * Vector3.new(0.7, 0.8, 0.7)
				collider.Transparency = 1
				collider.CanCollide = false
				collider.CanQuery = false
				collider.CanTouch = false
				collider.Massless = true
				collider.CFrame = limb.CFrame
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = limb
				weld.Part1 = collider
				weld.Parent = collider
				collider.Parent = limb
			end
		end
	end
end

function Ragdoll.set(character: Model, on: boolean)
	local torso = character:FindFirstChild("Torso")
	if not torso then
		return
	end
	for _, spec in JOINTS do
		local motor = torso:FindFirstChild(spec.motor)
		local socket = torso:FindFirstChild("Rag" .. spec.motor)
		if motor and motor:IsA("Motor6D") then
			motor.Enabled = not on
		end
		if socket and socket:IsA("BallSocketConstraint") then
			socket.Enabled = on
		end
		local limb = character:FindFirstChild(spec.limb)
		local collider = limb and limb:FindFirstChild("RagCollider")
		if collider and collider:IsA("BasePart") then
			collider.CanCollide = on
		end
	end
	character:SetAttribute("Ragdolled", on)
end

return Ragdoll
