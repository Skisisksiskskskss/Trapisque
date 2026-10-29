--[[
	Hitbox queries against living characters. Characters are treated as vertical
	capsules around their root part, which is forgiving and cheap.
]]

local Shared = game:GetService("ReplicatedStorage").Shared
local Geometry = require(Shared.Geometry)

local World = require(script.Parent.World)

local Hitbox = {}

local CAPSULE_DOWN = 2.6 -- from root to feet
local CAPSULE_UP = 1.8 -- from root to top of head
local CAPSULE_RADIUS = 1.4

export type Target = { player: Player, root: BasePart, humanoid: Humanoid }

-- Living players (other than `owner`) whose capsule touches the sphere.
function Hitbox.sphere(owner: Player?, center: Vector3, radius: number): { Target }
	local hits = {}
	for _, target in World.livingPlayers(owner) do
		local rootPos = target.root.Position
		local closestY = math.clamp(center.Y, rootPos.Y - CAPSULE_DOWN, rootPos.Y + CAPSULE_UP)
		local closest = Vector3.new(rootPos.X, closestY, rootPos.Z)
		if (closest - center).Magnitude <= radius + CAPSULE_RADIUS then
			table.insert(hits, target)
		end
	end
	return hits
end

-- Living players inside a horizontal cone (half angle in degrees).
function Hitbox.cone(owner: Player?, origin: Vector3, direction: Vector3, range: number, halfAngle: number, height: number?): { Target }
	local hits = {}
	local flatDir = Geometry.flat(direction)
	local cosLimit = math.cos(math.rad(halfAngle))
	for _, target in World.livingPlayers(owner) do
		local offset = target.root.Position - origin
		local flatOffset = Vector3.new(offset.X, 0, offset.Z)
		local distance = flatOffset.Magnitude
		if math.abs(offset.Y) <= (height or 8) and distance <= range + CAPSULE_RADIUS then
			-- Point blank always counts; otherwise check the angle.
			if distance < 3 or flatOffset.Unit:Dot(flatDir) >= cosLimit then
				table.insert(hits, target)
			end
		end
	end
	return hits
end

-- Earliest living player (not `owner`) touched by a moving sphere a -> b.
-- Returns the target and the 0..1 fraction along the segment.
function Hitbox.sweep(owner: Player?, a: Vector3, b: Vector3, radius: number): (Target?, number)
	local best: Target? = nil
	local bestT = math.huge
	for _, target in World.livingPlayers(owner) do
		local rootPos = target.root.Position
		local distance, t = Geometry.segmentSegment(
			a,
			b,
			rootPos - Vector3.new(0, CAPSULE_DOWN, 0),
			rootPos + Vector3.new(0, CAPSULE_UP, 0)
		)
		if distance <= radius + CAPSULE_RADIUS and t < bestT then
			best, bestT = target, t
		end
	end
	return best, bestT
end

return Hitbox
