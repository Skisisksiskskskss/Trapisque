--[[
	Server-side helpers for querying the world and players' characters.
]]

local Players = game:GetService("Players")

local World = {}

local mapFolder: Folder? = nil
local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Include

function World.setMap(folder: Folder)
	mapFolder = folder
	mapParams.FilterDescendantsInstances = { folder }
end

function World.map(): Folder
	return mapFolder :: Folder
end

-- Raycast params that only see map geometry (not characters or effects).
function World.mapParams(): RaycastParams
	return mapParams
end

function World.raycastMap(origin: Vector3, direction: Vector3): RaycastResult?
	return workspace:Raycast(origin, direction, mapParams)
end

-- First surface below a point, within `depth` studs.
function World.groundBelow(position: Vector3, depth: number?): RaycastResult?
	return workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -(depth or 12) - 1, 0), mapParams)
end

-- Character, humanoid and root of a living player, or nil.
function World.alive(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

-- Every living player except `exclude`, with their root part.
function World.livingPlayers(exclude: Player?): { { player: Player, root: BasePart, humanoid: Humanoid } }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player ~= exclude then
			local _, humanoid, root = World.alive(player)
			if humanoid and root then
				table.insert(list, { player = player, root = root, humanoid = humanoid })
			end
		end
	end
	return list
end

return World
