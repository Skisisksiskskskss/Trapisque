--[[
	HazardService: the spinning sweeper on the central stage.

	The bar's angle is a pure function of the shared server clock, so every
	client animates it smoothly on its own (see client/Fx) and the server never
	has to replicate its motion. Hits are found geometrically each step
	(distance from each character to the bar), which is reliable for
	client-owned characters in a way Touched events are not.
]]

local RunService = game:GetService("RunService")

local CombatService = require(script.Parent.CombatService)
local World = require(script.Parent.World)

local HazardService = {}

local HIT_THICKNESS = 2.2 -- distance from the bar's axis that counts as a hit
local HEIGHT_BELOW = 1 -- root may be this far below the bar's pivot height...
local HEIGHT_ABOVE = 4.5 -- ...or this far above it (jumping clears it)
local REHIT_DELAY = 0.8

function HazardService.init()
	local bar = World.map():FindFirstChild("SweeperBar")
	if not bar or not bar:IsA("BasePart") then
		return
	end
	local pivot = bar.Position
	local armLength = bar:GetAttribute("ArmLength") or 21
	local speed = bar:GetAttribute("Speed") or 1
	local lastHit: { [any]: number } = {}

	RunService.Heartbeat:Connect(function()
		local angle = (workspace:GetServerTimeNow() * speed) % (math.pi * 2)
		local axis = CFrame.Angles(0, angle, 0).RightVector
		local now = os.clock()

		for _, target in World.livingTargets(nil) do
			local offset = target.root.Position - pivot
			local height = offset.Y
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			local along = flatOffset:Dot(axis)
			local across = (flatOffset - axis * along).Magnitude
			if
				height > -HEIGHT_BELOW
				and height < HEIGHT_ABOVE
				and math.abs(along) <= armLength
				and across <= HIT_THICKNESS
				and now - (lastHit[target.key] or 0) > REHIT_DELAY
			then
				lastHit[target.key] = now
				-- The bar's velocity at this point is perpendicular to the arm.
				local tangent = Vector3.new(flatOffset.Z, 0, -flatOffset.X)
				tangent = if tangent.Magnitude > 0.1 then tangent.Unit else axis
				local outward = if flatOffset.Magnitude > 0.1 then flatOffset.Unit else Vector3.zero
				CombatService.applyHit(nil, target.key, {
					damage = 8,
					knockback = tangent * 62 + outward * 22 + Vector3.new(0, 38, 0),
					ragdoll = 0.6,
					heavy = true,
					position = target.root.Position,
				})
			end
		end
	end)
end

return HazardService
