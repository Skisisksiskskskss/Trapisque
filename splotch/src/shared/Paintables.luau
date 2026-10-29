--[[
	Registry of paintable parts by PaintId.

	The server tags map parts "Paintable" and gives each a PaintId attribute; both
	sides then look parts up by id. Attributes and tags replicate, so clients
	rebuild the same table from what they receive.
]]

local CollectionService = game:GetService("CollectionService")

local TAG = "Paintable"
local ID_ATTRIBUTE = "PaintId"

local Paintables = {}
Paintables.TAG = TAG

local byId: { [number]: BasePart } = {}

local function register(instance: Instance)
	local id = instance:GetAttribute(ID_ATTRIBUTE)
	if instance:IsA("BasePart") and typeof(id) == "number" then
		byId[id] = instance
	end
end

-- Server: number every tagged part. Call once, after the map is built.
function Paintables.assignIds(): number
	local count = 0
	for _, part in CollectionService:GetTagged(TAG) do
		if part:IsA("Part") and part.Shape == Enum.PartType.Block then
			count += 1
			part:SetAttribute(ID_ATTRIBUTE, count)
			byId[count] = part
		else
			CollectionService:RemoveTag(part, TAG)
		end
	end
	return count
end

-- Client: index every tagged part we have received, now and later.
function Paintables.listen()
	for _, part in CollectionService:GetTagged(TAG) do
		register(part)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
end

function Paintables.get(id: number): BasePart?
	return byId[id]
end

function Paintables.idOf(instance: Instance): number?
	local id = instance:GetAttribute(ID_ATTRIBUTE)
	return if typeof(id) == "number" then id else nil
end

return Paintables
