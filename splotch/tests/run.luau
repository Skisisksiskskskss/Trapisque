--[[
	Unit tests for the pure modules, run with Lune:  lune run tests/run.luau

	Modules are loaded with Roblox datatypes (Vector3, CFrame) injected as
	globals, exactly as they exist inside Roblox.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local function load(path: string): any
	local env = setmetatable({
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
	}, { __index = getfenv() })
	local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
	return chunk()
end

local PaintGrid = load("src/shared/PaintGrid.luau")
local PaintStore = load("src/server/PaintStore.luau")
local Geometry = load("src/shared/Geometry.luau")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local passed, failed = 0, 0
local currentTest = ""

local function check(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-4)
end

local function nearVector(a: any, b: any, tolerance: number?): boolean
	return (a - b).Magnitude <= (tolerance or 1e-4)
end

local function test(name: string, body: () -> ())
	currentTest = name
	local ok, err = pcall(body)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end

local function part(cframe: any, size: any)
	return { CFrame = cframe, Size = size }
end

-- PaintGrid --------------------------------------------------------------------

test("encode/decode round trip", function()
	for _, sample in { { 1, 1, 0, 0 }, { 57, 6, 1023, 1023 }, { 4000, 3, 512, 7 }, { 1, 5, 0, 900 } } do
		local key = PaintGrid.encode(sample[1], sample[2], sample[3], sample[4])
		local id, face, u, v = PaintGrid.decode(key)
		check(
			id == sample[1] and face == sample[2] and u == sample[3] and v == sample[4],
			"round trip failed for " .. key
		)
	end
end)

test("cellAt picks the top face cell under a point", function()
	local floor = part(CFrame.new(0, 0, 0), Vector3.new(12, 2, 12))
	local key = PaintGrid.cellAt(floor, 7, Vector3.new(0.5, 1, 0.5), Vector3.new(0, 1, 0), 3)
	local id, face, u, v = PaintGrid.decode(key)
	check(id == 7, "paint id")
	check(PaintGrid.FACES[face].normal == Vector3.new(0, 1, 0), "expected the top face, got " .. face)
	check(u == 2 and v == 2, "expected cell (2,2), got (" .. u .. "," .. v .. ")")
end)

test("cellAt clamps points on the far edge into the last cell", function()
	local floor = part(CFrame.new(0, 0, 0), Vector3.new(12, 2, 12))
	local key = PaintGrid.cellAt(floor, 1, Vector3.new(6, 1, -6), Vector3.new(0, 1, 0), 3)
	local _, _, u, v = PaintGrid.decode(key)
	check(u == 3 and v == 0, "expected (3,0), got (" .. u .. "," .. v .. ")")
end)

test("cell slabs are clipped to the face and lifted off it", function()
	local floor = part(CFrame.new(0, 0, 0), Vector3.new(10, 2, 10))
	-- Face 3 is +Y. Cell u = 3 spans x 4..5 (only 1 stud wide on a 10 stud face).
	local key = PaintGrid.encode(1, 3, 3, 0)
	local cframe, size = PaintGrid.cellSlab(floor, key, 3, 0.05, 0.1)
	check(near(size.X, 1) and near(size.Z, 3) and near(size.Y, 0.1), "unexpected slab size " .. tostring(size))
	check(
		nearVector(cframe.Position, Vector3.new(4.5, 1.1, -3.5)),
		"unexpected slab position " .. tostring(cframe.Position)
	)
	check(nearVector(cframe.UpVector, Vector3.new(0, 1, 0)), "slab should face up")
end)

test("splats only paint faces the point is in front of", function()
	local floor = part(CFrame.new(0, 0, 0), Vector3.new(30, 2, 30))
	local faces = {}
	local count = 0
	PaintGrid.forEachCellInRadius(floor, 1, Vector3.new(0, 1, 0), 5, 3, function(key)
		local _, face = PaintGrid.decode(key)
		faces[face] = true
		count += 1
	end)
	check(faces[3] == true, "top face should be painted")
	check(faces[4] == nil, "bottom face must never be painted from above")
	check(count >= 7 and count <= 12, "unexpected cell count " .. count)
end)

test("splats at an edge drip onto the side face", function()
	local floor = part(CFrame.new(0, 0, 0), Vector3.new(30, 2, 30))
	local faces = {}
	PaintGrid.forEachCellInRadius(floor, 1, Vector3.new(14.8, 1, 0), 5, 3, function(key)
		local _, face = PaintGrid.decode(key)
		faces[face] = true
	end)
	check(faces[3] == true, "top face")
	check(faces[1] == true, "the +X side face should catch the drip")
end)

test("every visited cell maps back to itself through cellAt", function()
	local cases = {
		part(CFrame.new(3, 2, -5), Vector3.new(14, 8, 9)),
		part(CFrame.new(0, 3, 0) * CFrame.Angles(0.3, 0.7, -0.2), Vector3.new(20, 2, 14)),
		part(CFrame.lookAt(Vector3.new(-100, -10, 0), Vector3.new(-80, 0, 0)), Vector3.new(14, 2, 44.7)),
	}
	for index, p in cases do
		local visited = 0
		local corners = { Vector3.new(1, 1, 1), Vector3.new(-1, 0.5, 0.2), Vector3.new(0, -1, 0.9) }
		for _, corner in corners do
			local point = p.CFrame:PointToWorldSpace(p.Size * 0.5 * corner)
			PaintGrid.forEachCellInRadius(p, 9, point, 6, 3, function(key, center, normal)
				visited += 1
				local again = PaintGrid.cellAt(p, 9, center, normal, 3)
				check(again == key, "case " .. index .. ": cell " .. key .. " came back as " .. again)
				local slab = PaintGrid.cellSlab(p, key, 3, 0, 0)
				check(nearVector(slab.Position, center, 1e-3), "case " .. index .. ": slab centre mismatch")
			end)
		end
		check(visited > 0, "case " .. index .. " painted nothing")
	end
end)

test("faceFromNormal follows rotation", function()
	local tilted = CFrame.Angles(0, 0, math.rad(90))
	-- Rotating 90 degrees about Z turns local +X into world +Y.
	check(PaintGrid.faceFromNormal(tilted, Vector3.new(0, 1, 0)) == 1, "local +X should now face up")
end)

-- PaintStore --------------------------------------------------------------------

test("painting tracks owners, counts and changes", function()
	local store = PaintStore.new(100)
	check(store:paint(1, 5, 0) == true, "first paint changes the cell")
	check(store:paint(1, 5, 1) == false, "repainting the same color is not a change")
	check(store:ownerOf(1) == 5 and store:countOf(5) == 1, "owner/count")
	store:paint(1, 6, 2)
	check(store:countOf(5) == 0 and store:countOf(6) == 1, "overwrite moves the count")
	local keys, colors = store:takeChanges()
	check(#keys == 1 and keys[1] == 1 and colors[1] == 6, "changes collapse to the latest color")
	local again = store:takeChanges()
	check(#again == 0, "changes reset after taking")
end)

test("the cap erases a color's oldest paint first", function()
	local store = PaintStore.new(3)
	for key = 1, 5 do
		store:paint(key, 1, key)
	end
	check(store:countOf(1) == 3, "count capped at 3, got " .. store:countOf(1))
	check(store:ownerOf(1) == nil and store:ownerOf(2) == nil, "oldest two erased")
	check(store:ownerOf(5) == 1, "newest kept")
end)

test("repainting refreshes a cell's age for the cap", function()
	local store = PaintStore.new(2)
	store:paint(10, 1, 0)
	store:paint(20, 1, 1)
	store:paint(10, 1, 2) -- 10 is now the newest
	store:paint(30, 1, 3)
	check(store:ownerOf(10) == 1, "refreshed cell survives")
	check(store:ownerOf(20) == nil, "stale-oldest cell is erased")
end)

test("decay erases paint older than the lifetime", function()
	local store = PaintStore.new(100)
	store:paint(1, 1, 0)
	store:paint(2, 1, 5)
	store:paint(3, 2, 1)
	store:decay(12, 10)
	check(store:ownerOf(1) == nil and store:ownerOf(3) == nil, "old paint gone")
	check(store:ownerOf(2) == 1, "fresh paint stays")
	local keys, colors = store:takeChanges()
	local erased = 0
	for index in keys do
		if colors[index] == 0 then
			erased += 1
		end
	end
	check(erased == 2, "two erasures reported, got " .. erased)
end)

test("a cell taken over by another color does not decay with the old one", function()
	local store = PaintStore.new(100)
	store:paint(1, 1, 0)
	store:paint(1, 2, 8)
	store:decay(12, 10)
	check(store:ownerOf(1) == 2, "takeover keeps the new owner")
end)

test("clearColor removes only that color", function()
	local store = PaintStore.new(100)
	store:paint(1, 1, 0)
	store:paint(2, 1, 0)
	store:paint(3, 2, 0)
	store:clearColor(1)
	check(store:ownerOf(1) == nil and store:ownerOf(2) == nil and store:ownerOf(3) == 2, "clearColor")
	check(store:countOf(1) == 0, "count reset")
end)

-- Geometry --------------------------------------------------------------------------

test("segment distance for crossing and parallel segments", function()
	local d1, s1 = Geometry.segmentSegment(
		Vector3.new(-1, 0, 0),
		Vector3.new(1, 0, 0),
		Vector3.new(0, -1, 2),
		Vector3.new(0, 1, 2)
	)
	check(near(d1, 2) and near(s1, 0.5), "crossing: " .. d1 .. " at " .. s1)
	local d2 =
		Geometry.segmentSegment(Vector3.new(0, 0, 0), Vector3.new(4, 0, 0), Vector3.new(0, 3, 0), Vector3.new(4, 3, 0))
	check(near(d2, 3), "parallel: " .. d2)
	local d3, s3 =
		Geometry.segmentSegment(Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), Vector3.new(5, 0, 0), Vector3.new(5, 0, 0))
	check(near(d3, 4) and near(s3, 1), "point beyond the end: " .. d3)
end)

test("ballistic aim hits the target", function()
	local origin = Vector3.new(0, 2, 0)
	for _, target in { Vector3.new(40, 2, 10), Vector3.new(-25, 12, 30), Vector3.new(60, -5, -20) } do
		local speed, gravity = 120, 60
		local direction = Geometry.ballisticDirection(origin, target, speed, gravity)
		local velocity = direction * speed
		local horizontal = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z).Magnitude
		local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local t = horizontal / flatSpeed
		local landed = Geometry.ballisticPosition(origin, velocity, gravity, t)
		check(nearVector(landed, target, 0.05), "missed " .. tostring(target) .. " by " .. (landed - target).Magnitude)
	end
end)

test("ballistic aim with no gravity points straight at the target", function()
	local direction = Geometry.ballisticDirection(Vector3.new(0, 0, 0), Vector3.new(3, 4, 0), 100, 0)
	check(nearVector(direction, Vector3.new(0.6, 0.8, 0)), "straight line")
end)

test("flat drops the vertical part", function()
	check(nearVector(Geometry.flat(Vector3.new(3, 9, 4)), Vector3.new(0.6, 0, 0.8)), "flat")
	check(nearVector(Geometry.flat(Vector3.new(0, 5, 0), Vector3.new(1, 0, 0)), Vector3.new(1, 0, 0)), "fallback")
end)

local _ = currentTest
print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
