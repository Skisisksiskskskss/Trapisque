--[[
	Box volumes tagged with a zone name ("SafeZone", "Shelter", "Hazard").
	Zone parts are invisible, non-colliding and non-queryable; only their CFrame
	and Size matter.
]]

local CollectionService = game:GetService("CollectionService")

local Zones = {}

Zones.SAFE = "SafeZone"
Zones.SHELTER = "Shelter"
Zones.HAZARD = "Hazard"

local function inside(part: BasePart, position: Vector3, margin: number): boolean
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X + margin and math.abs(p.Y) <= half.Y + margin and math.abs(p.Z) <= half.Z + margin
end

function Zones.contains(tag: string, position: Vector3, margin: number?): boolean
	for _, part in CollectionService:GetTagged(tag) do
		if part:IsA("BasePart") and inside(part, position, margin or 0) then
			return true
		end
	end
	return false
end

return Zones
