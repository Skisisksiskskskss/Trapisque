--[[
	Paints a few splats onto a floor and a wall with the game's own PaintGrid
	(cells and splat shapes) and prints the result as JSON for
	tools/render_paint.py.

	lune run tools/dump-paint.luau > build/paint.json
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local env = setmetatable({ CFrame = roblox.CFrame, Vector3 = roblox.Vector3 }, { __index = getfenv() })
local PaintGrid = luau.load(fs.readFile("src/shared/PaintGrid.luau"), { environment = env })()

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local CELL = 3

local floor = { CFrame = CFrame.new(0, -1, 0), Size = Vector3.new(40, 2, 31) }
local owners = {}
local splats = {
	{ Vector3.new(-6, 0, -4), 6, 1 },
	{ Vector3.new(4, 0, 2), 6, 2 },
	{ Vector3.new(12, 0, -8), 4.5, 1 },
	{ Vector3.new(-14, 0, 10), 7, 2 },
	{ Vector3.new(19, 0, 14), 5, 1 }, -- near a corner: must stay inside the floor
}
for _, splat in splats do
	PaintGrid.forEachCellInRadius(floor, 1, splat[1], splat[2], CELL, function(key)
		owners[key] = splat[3]
	end)
end

local out = { floor = { size = { floor.Size.X, floor.Size.Z } }, cells = {} }
for key, color in owners do
	local cframe, size, round = PaintGrid.splatGeometry(floor, key, CELL, 0.05, 0.1)
	table.insert(out.cells, {
		x = cframe.Position.X,
		z = cframe.Position.Z,
		y = cframe.Position.Y,
		round = round,
		size = { size.X, size.Y, size.Z },
		color = color,
	})
end
print(serde.encode("json", out, false))
