--[[
	PaintRenderer: mirrors the server's paint state and draws it.

	Each painted cell is a thin, non-colliding, non-queryable slab hugging its
	surface. Slabs are pooled because paint is laid and erased constantly. The
	local owner table also answers "whose paint is this?" for movement checks.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local PaintGrid = require(Shared.PaintGrid)
local Paintables = require(Shared.Paintables)
local Palette = require(Shared.Palette)
local Remotes = require(Shared.Remotes)

local PaintRenderer = {}

local MAX_POOL = 4000
local CLEAR_FADE_TIME = 1.2

local owners: { [number]: number } = {}
local slabs: { [number]: Part } = {}
local pool: { Part } = {}
local folder: Folder
local hasSnapshot = false

local function newSlab(): Part
	local slab = table.remove(pool)
	if slab then
		slab.Transparency = 0
		return slab
	end
	slab = Instance.new("Part")
	slab.Name = "Paint"
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.CastShadow = false
	slab.Material = Enum.Material.SmoothPlastic
	slab.Reflectance = 0.04
	slab.TopSurface = Enum.SurfaceType.Smooth
	slab.BottomSurface = Enum.SurfaceType.Smooth
	return slab
end

local function releaseSlab(slab: Part)
	if #pool < MAX_POOL then
		slab.Parent = nil
		table.insert(pool, slab)
	else
		slab:Destroy()
	end
end

local function setCell(key: number, colorId: number)
	if colorId == 0 then
		owners[key] = nil
		local slab = slabs[key]
		if slab then
			slabs[key] = nil
			releaseSlab(slab)
		end
		return
	end

	owners[key] = colorId
	local slab = slabs[key]
	if not slab then
		local paintId = PaintGrid.decode(key)
		local part = Paintables.get(paintId)
		if not part then
			return
		end
		local cframe, size = PaintGrid.cellSlab(
			part,
			key,
			Config.CELL_SIZE,
			Config.PAINT_VISUAL_LIFT,
			Config.PAINT_VISUAL_THICKNESS
		)
		slab = newSlab()
		slab.CFrame = cframe
		slab.Size = size
		slabs[key] = slab
		slab.Parent = folder
	end
	slab.Color = Palette.color(colorId)
end

local function clearAll()
	owners = {}
	local fading = slabs
	slabs = {}
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local alpha = math.clamp((os.clock() - started) / CLEAR_FADE_TIME, 0, 1)
		for _, slab in fading do
			slab.Transparency = alpha
		end
		if alpha >= 1 then
			connection:Disconnect()
			for _, slab in fading do
				releaseSlab(slab)
			end
		end
	end)
end

function PaintRenderer.init()
	folder = Instance.new("Folder")
	folder.Name = "PaintVisuals"
	folder.Parent = workspace

	Paintables.listen()

	Remotes.PaintSync.OnClientEvent:Connect(function(mode: string, keys: { number }?, colors: { number }?)
		if mode == "clear" then
			clearAll()
			return
		end
		if mode == "snapshot" then
			hasSnapshot = true
		elseif not hasSnapshot then
			-- Deltas before our snapshot are already included in it.
			return
		end
		if keys and colors then
			for index, key in keys do
				setCell(key, colors[index])
			end
		end
	end)

	-- Wait until every paintable part has replicated, then ask for the state.
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local expected = map:GetAttribute("PaintableCount") or 0
		local deadline = os.clock() + 10
		while os.clock() < deadline do
			local count = 0
			for id = 1, expected do
				if Paintables.get(id) then
					count += 1
				end
			end
			if count >= expected then
				break
			end
			task.wait(0.2)
		end
		Remotes.PaintReady:FireServer()
	end)
end

-- ColorId of the paint at a raycast hit, or nil.
function PaintRenderer.ownerAt(result: RaycastResult?): number?
	if not result then
		return nil
	end
	local paintId = Paintables.idOf(result.Instance)
	if not paintId then
		return nil
	end
	return owners[PaintGrid.cellAt(result.Instance :: BasePart, paintId, result.Position, result.Normal, Config.CELL_SIZE)]
end

return PaintRenderer
