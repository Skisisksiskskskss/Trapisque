--[[
	PaintGrid maps points on the faces of block parts to paint cells.

	Every paintable part has a numeric PaintId. Each of its six faces is cut into
	square cells anchored at the face's corner, so a cell is identified by
	(paintId, face, u, v), packed into a single number key. Cells on a face's far
	edges are clipped to the face, so paint never overhangs a part.

	This module is pure math (no services), so it runs the same on server, client
	and in the Lune unit tests.
]]

local PaintGrid = {}

local UV_RANGE = 1024
local FACE_RANGE = 8
-- A splat may still reach a face whose plane is this far in front of the point.
local BEHIND_TOLERANCE = 0.6

export type Face = { normal: Vector3, u: Vector3, v: Vector3 }

-- Face index -> local normal and the two local axes spanning the face.
local FACES: { Face } = {
	{ normal = Vector3.new(1, 0, 0), u = Vector3.new(0, 0, 1), v = Vector3.new(0, 1, 0) },
	{ normal = Vector3.new(-1, 0, 0), u = Vector3.new(0, 0, 1), v = Vector3.new(0, 1, 0) },
	{ normal = Vector3.new(0, 1, 0), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 0, 1) },
	{ normal = Vector3.new(0, -1, 0), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 0, 1) },
	{ normal = Vector3.new(0, 0, 1), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 1, 0) },
	{ normal = Vector3.new(0, 0, -1), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 1, 0) },
}
PaintGrid.FACES = FACES

type PartLike = { CFrame: CFrame, Size: Vector3 }

function PaintGrid.encode(paintId: number, face: number, u: number, v: number): number
	return ((paintId * FACE_RANGE + face) * UV_RANGE + u) * UV_RANGE + v
end

function PaintGrid.decode(key: number): (number, number, number, number)
	local v = key % UV_RANGE
	key = (key - v) // UV_RANGE
	local u = key % UV_RANGE
	key = (key - u) // UV_RANGE
	local face = key % FACE_RANGE
	local paintId = (key - face) // FACE_RANGE
	return paintId, face, u, v
end

local function faceDims(size: Vector3, f: Face): (number, number, number)
	local halfN = math.abs(size:Dot(f.normal)) / 2
	local sizeU = math.abs(size:Dot(f.u))
	local sizeV = math.abs(size:Dot(f.v))
	return halfN, sizeU, sizeV
end

local function cellCount(length: number, cellSize: number): number
	return math.clamp(math.ceil(length / cellSize - 1e-6), 1, UV_RANGE)
end

-- Lower bound, upper bound and centre of cell `index` along an axis of `length`.
local function cellSpan(index: number, length: number, cellSize: number): (number, number, number)
	local lo = -length / 2 + index * cellSize
	local hi = math.min(lo + cellSize, length / 2)
	return lo, hi, (lo + hi) / 2
end

-- The face of `cframe` whose outward normal best matches `worldNormal`.
function PaintGrid.faceFromNormal(cframe: CFrame, worldNormal: Vector3): number
	local localNormal = cframe:VectorToObjectSpace(worldNormal)
	local best, bestDot = 1, -math.huge
	for index, f in FACES do
		local d = localNormal:Dot(f.normal)
		if d > bestDot then
			best, bestDot = index, d
		end
	end
	return best
end

-- Key of the cell under a surface hit (position + normal, e.g. a RaycastResult).
function PaintGrid.cellAt(
	part: PartLike,
	paintId: number,
	worldPos: Vector3,
	worldNormal: Vector3,
	cellSize: number
): number
	local face = PaintGrid.faceFromNormal(part.CFrame, worldNormal)
	local f = FACES[face]
	local p = part.CFrame:PointToObjectSpace(worldPos)
	local _, sizeU, sizeV = faceDims(part.Size, f)
	local u = math.clamp(math.floor((p:Dot(f.u) + sizeU / 2) / cellSize), 0, cellCount(sizeU, cellSize) - 1)
	local v = math.clamp(math.floor((p:Dot(f.v) + sizeV / 2) / cellSize), 0, cellCount(sizeV, cellSize) - 1)
	return PaintGrid.encode(paintId, face, u, v)
end

-- World CFrame and size of the thin slab that renders a cell.
function PaintGrid.cellSlab(
	part: PartLike,
	key: number,
	cellSize: number,
	lift: number,
	thickness: number
): (CFrame, Vector3)
	local _, face, u, v = PaintGrid.decode(key)
	local f = FACES[face]
	local halfN, sizeU, sizeV = faceDims(part.Size, f)
	local loU, hiU, cu = cellSpan(u, sizeU, cellSize)
	local loV, hiV, cv = cellSpan(v, sizeV, cellSize)
	local center = f.normal * (halfN + lift + thickness / 2) + f.u * cu + f.v * cv
	-- Slab axes: X along u, Y along the normal, Z along +/- v.
	local localCFrame = CFrame.fromMatrix(center, f.u, f.normal)
	return part.CFrame * localCFrame, Vector3.new(hiU - loU, thickness, hiV - loV)
end

--[[
	Calls visit(key, worldCenter, worldNormal) for every cell on any face of
	`part` within `radius` of `worldPoint`. Faces the point is behind (inside the
	part) are skipped, so a splat never paints the underside of the floor it hit.
]]
function PaintGrid.forEachCellInRadius(
	part: PartLike,
	paintId: number,
	worldPoint: Vector3,
	radius: number,
	cellSize: number,
	visit: (key: number, worldCenter: Vector3, worldNormal: Vector3) -> ()
)
	local cframe = part.CFrame
	local p = cframe:PointToObjectSpace(worldPoint)
	for face, f in FACES do
		local halfN, sizeU, sizeV = faceDims(part.Size, f)
		local dN = p:Dot(f.normal) - halfN
		if dN >= -BEHIND_TOLERANCE and dN <= radius then
			local planar = math.sqrt(math.max(radius * radius - dN * dN, 0))
			local pu, pv = p:Dot(f.u), p:Dot(f.v)
			local u0 = math.max(0, math.floor((pu - planar + sizeU / 2) / cellSize))
			local u1 = math.min(cellCount(sizeU, cellSize) - 1, math.floor((pu + planar + sizeU / 2) / cellSize))
			local v0 = math.max(0, math.floor((pv - planar + sizeV / 2) / cellSize))
			local v1 = math.min(cellCount(sizeV, cellSize) - 1, math.floor((pv + planar + sizeV / 2) / cellSize))
			local worldNormal = cframe:VectorToWorldSpace(f.normal)
			for u = u0, u1 do
				local _, _, cu = cellSpan(u, sizeU, cellSize)
				for v = v0, v1 do
					local _, _, cv = cellSpan(v, sizeV, cellSize)
					local du, dv = cu - pu, cv - pv
					if du * du + dv * dv <= planar * planar then
						local localCenter = f.normal * halfN + f.u * cu + f.v * cv
						visit(PaintGrid.encode(paintId, face, u, v), cframe:PointToWorldSpace(localCenter), worldNormal)
					end
				end
			end
		end
	end
end

return PaintGrid
