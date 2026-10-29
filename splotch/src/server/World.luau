--[[
	Server-side helpers for querying the world and combatants.

	A combatant is either a Player or a training dummy Model. Both have a State
	entry, so combat code treats them the same way; only a few things (sending
	remotes, leaderstats) check which kind it is.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local World = {}

export type Combatant = Player | Model
export type Target = { key: Combatant, character: Model, root: BasePart, humanoid: Humanoid }

World.DUMMY_TAG = "Dummy"

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

function World.isPlayer(key: Combatant): boolean
	return typeof(key) == "Instance" and key:IsA("Player")
end

function World.characterOf(key: Combatant): Model?
	if World.isPlayer(key) then
		return (key :: Player).Character
	end
	return key :: Model
end

-- The combatant that owns a character model, if any.
function World.combatantFromCharacter(character: Instance?): Combatant?
	if not character or not character:IsA("Model") then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		return player
	end
	if CollectionService:HasTag(character, World.DUMMY_TAG) then
		return character
	end
	return nil
end

function World.nameOf(key: Combatant): string
	if World.isPlayer(key) then
		return (key :: Player).DisplayName
	end
	return (key :: Model).Name
end

-- Character, humanoid and root of a living combatant, or nil.
function World.alive(key: Combatant): (Model?, Humanoid?, BasePart?)
	local character = World.characterOf(key)
	if not character or not character.Parent then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

-- Root part of a living combatant, or nil.
function World.rootOf(key: Combatant?): BasePart?
	if not key then
		return nil
	end
	local _, _, root = World.alive(key)
	return root
end

-- Every living combatant (players and dummies) except `exclude`.
function World.livingTargets(exclude: Combatant?): { Target }
	local list = {}
	local function consider(key: Combatant)
		if key ~= exclude then
			local character, humanoid, root = World.alive(key)
			if character and humanoid and root then
				table.insert(list, { key = key, character = character, root = root, humanoid = humanoid })
			end
		end
	end
	for _, player in Players:GetPlayers() do
		consider(player)
	end
	for _, dummy in CollectionService:GetTagged(World.DUMMY_TAG) do
		if dummy:IsA("Model") then
			consider(dummy)
		end
	end
	return list
end

return World
