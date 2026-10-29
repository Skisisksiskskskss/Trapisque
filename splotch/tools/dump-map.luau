--[[
	Builds the map offline with the real MapBuilder and prints every part as
	JSON (used by tools/render_map.py to draw a preview).

	lune run tools/dump-map.luau > build/map.json
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local env = setmetatable({
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
}, { __index = getfenv() })

local source = fs.readFile("src/server/MapBuilder.luau")
local MapBuilder = luau.load(source, { debugName = "MapBuilder", environment = env })()
local map, zones = MapBuilder.build()

local parts = {}
local function collect(folder: any, group: string)
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") then
			local cf = item.CFrame
			local rx, ry, rz = cf:ToOrientation()
			table.insert(parts, {
				name = item.Name,
				group = group,
				class = item.ClassName,
				position = { cf.Position.X, cf.Position.Y, cf.Position.Z },
				size = { item.Size.X, item.Size.Y, item.Size.Z },
				orientation = { rx, ry, rz },
				right = { cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z },
				look = { cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z },
				up = { cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z },
				color = { item.Color.R, item.Color.G, item.Color.B },
				transparency = item.Transparency,
				tags = item:GetTags(),
			})
		end
	end
end
collect(map, "map")
collect(zones, "zones")
print(serde.encode("json", parts, true))
