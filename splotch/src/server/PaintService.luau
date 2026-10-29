--[[
	PaintService: turns splats into painted cells and keeps every client in sync.

	Splats paint every cell within a radius on any nearby paintable face that can
	"see" the impact point, so a shot at the base of a wall paints both the floor
	and the wall, but never the far side of the wall.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local PaintGrid = require(Shared.PaintGrid)
local Paintables = require(Shared.Paintables)
local Remotes = require(Shared.Remotes)

local PaintStore = require(script.Parent.PaintStore)
local World = require(script.Parent.World)

local PaintService = {}

local store = PaintStore.new(Config.MAX_CELLS_PER_COLOR)
local lifetime = Config.PAINT_LIFETIME
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local LOS_OFFSET = 0.3
local LOS_SLACK = 0.35

function PaintService.init()
	overlapParams.FilterDescendantsInstances = { World.map() }

	Remotes.PaintReady.OnServerEvent:Connect(function(player)
		local keys, colors = store:snapshot()
		Remotes.PaintSync:FireClient(player, "snapshot", keys, colors)
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Config.PAINT_FLUSH_INTERVAL then
			return
		end
		elapsed = 0
		store:decay(os.clock(), lifetime)
		local keys, colors = store:takeChanges()
		if #keys > 0 then
			Remotes.PaintSync:FireAllClients("delta", keys, colors)
		end
	end)
end

-- True when nothing solid sits between a splat and a cell it wants to paint.
local function canSee(from: Vector3, cellCenter: Vector3, cellNormal: Vector3): boolean
	local target = cellCenter + cellNormal * 0.2
	local direction = target - from
	local result = World.raycastMap(from, direction)
	return result == nil or (result.Position - from).Magnitude >= direction.Magnitude - LOS_SLACK
end

--[[
	Paints a disc of `radius` around `point` in `colorId`. `normal` is the surface
	normal at the impact (used to step the visibility checks off the surface) and
	`hitPart` the part that was struck, if known. Returns how many cells changed.
]]
function PaintService.splat(
	colorId: number,
	point: Vector3,
	normal: Vector3?,
	radius: number,
	hitPart: BasePart?
): number
	local up = normal or Vector3.new(0, 1, 0)
	local from = point + up * LOS_OFFSET
	local hitFace = if hitPart then PaintGrid.faceFromNormal(hitPart.CFrame, up) else nil
	local now = os.clock()
	local changed = 0

	for _, part in workspace:GetPartBoundsInRadius(point, radius + 1, overlapParams) do
		local paintId = Paintables.idOf(part)
		if paintId then
			PaintGrid.forEachCellInRadius(
				part,
				paintId,
				point,
				radius,
				Config.CELL_SIZE,
				function(key, center, cellNormal)
					-- Cells on the struck face itself are always visible; everything
					-- else (other faces, neighbouring parts) needs a clear line.
					local _, face = PaintGrid.decode(key)
					if not (part == hitPart and face == hitFace) and not canSee(from, center, cellNormal) then
						return
					end
					if store:paint(key, colorId, now) then
						changed += 1
					end
				end
			)
		end
	end
	return changed
end

-- Paints the ground under `position` (used by dashes, slams and character hits).
function PaintService.splatGround(colorId: number, position: Vector3, radius: number, depth: number?): boolean
	local ground = World.groundBelow(position, depth)
	if not ground then
		return false
	end
	PaintService.splat(colorId, ground.Position, ground.Normal, radius, ground.Instance :: BasePart)
	return true
end

-- ColorId of the paint at a raycast hit, or nil when unpainted / unpaintable.
function PaintService.ownerAt(result: RaycastResult?): number?
	if not result then
		return nil
	end
	local paintId = Paintables.idOf(result.Instance)
	if not paintId then
		return nil
	end
	local key = PaintGrid.cellAt(result.Instance :: BasePart, paintId, result.Position, result.Normal, Config.CELL_SIZE)
	return store:ownerOf(key)
end

function PaintService.clearColor(colorId: number)
	store:clearColor(colorId)
end

function PaintService.clearAll()
	store:clearAll()
	Remotes.PaintSync:FireAllClients("clear")
end

function PaintService.setLifetime(seconds: number)
	lifetime = seconds
end

return PaintService
