--[[
	FishArt
	The catches from fishing between turns (Shared/Meta/Fishing): their illustrations
	(art/fish.py: fish/<catch id>), or without the art, sticker art drawn from shapes
	(plain objects in flat inks with the ink outline, a dot of an eye).

		FishArt.image(parent, catchId, props, dark?) -> Frame   -- dark: just its shape, in
		                                                        -- one dark ink (not caught yet)
		FishArt.ops(catchId) -> sticker ops
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fishing = require(ReplicatedStorage.Shared.Meta.Fishing)

local Icons = require(script.Parent.Icons)
local Art = require(script.Parent.Art)

local FishArt = {}

FishArt.DARK = Color3.fromHex("3A3846")

local INK = "#2A2830"
local CREAM = "#FFF9EF"

local function fish(body: string, fin: string, kind: string)
	if kind == "slim" then
		return {
			{ "tri", 0.18, 0.5, 0.26, dir = 90, c = fin },
			{ "pill", 0.54, 0.5, 0.66, 0.3, c = body },
			{ "tri", 0.52, 0.34, 0.16, dir = 0, c = fin, ol = false },
			{ "line", 0.44, 0.56, 0.7, 0.56, 0.025, c = CREAM, ol = false },
			{ "circle", 0.74, 0.46, 0.05, c = INK, ol = false },
		}
	elseif kind == "round" then
		return {
			{ "tri", 0.2, 0.5, 0.3, dir = 90, c = fin },
			{ "circle", 0.56, 0.5, 0.54, c = body },
			{ "tri", 0.56, 0.24, 0.2, dir = 0, c = fin },
			{ "line", 0.5, 0.3, 0.5, 0.7, 0.04, c = fin, ol = false },
			{ "circle", 0.7, 0.44, 0.06, c = INK, ol = false },
		}
	elseif kind == "puffer" then
		return {
			{ "tri", 0.18, 0.5, 0.22, dir = 90, c = fin },
			{ "circle", 0.54, 0.52, 0.62, c = body },
			{ "tri", 0.54, 0.18, 0.08, dir = 0, c = fin, ol = false },
			{ "tri", 0.3, 0.3, 0.08, dir = -45, c = fin, ol = false },
			{ "tri", 0.78, 0.3, 0.08, dir = 45, c = fin, ol = false },
			{ "tri", 0.54, 0.86, 0.08, dir = 180, c = fin, ol = false },
			{ "circle", 0.7, 0.46, 0.07, c = INK, ol = false },
		}
	elseif kind == "squid" then
		return {
			{ "line", 0.34, 0.62, 0.22, 0.9, 0.05, c = fin },
			{ "line", 0.44, 0.64, 0.4, 0.94, 0.05, c = fin },
			{ "line", 0.56, 0.64, 0.6, 0.94, 0.05, c = fin },
			{ "line", 0.66, 0.62, 0.78, 0.9, 0.05, c = fin },
			{ "pill", 0.5, 0.4, 0.42, 0.56, c = body },
			{ "tri", 0.5, 0.1, 0.24, dir = 0, c = body },
			{ "circle", 0.42, 0.5, 0.06, c = INK, ol = false },
			{ "circle", 0.58, 0.5, 0.06, c = INK, ol = false },
		}
	elseif kind == "sword" then
		return {
			{ "tri", 0.14, 0.5, 0.26, dir = 90, c = fin },
			{ "pill", 0.46, 0.5, 0.56, 0.24, c = body },
			{ "line", 0.7, 0.48, 0.98, 0.42, 0.03, c = fin },
			{ "tri", 0.44, 0.32, 0.2, dir = 0, c = fin, ol = false },
			{ "circle", 0.64, 0.46, 0.045, c = INK, ol = false },
		}
	elseif kind == "eel" then
		return {
			{ "path", { { 0.08, 0.62 }, { 0.28, 0.46 }, { 0.48, 0.6 }, { 0.68, 0.46 }, { 0.84, 0.5 } }, 0.15, c = body },
			{ "circle", 0.85, 0.5, 0.2, c = body },
			{ "line", 0.3, 0.45, 0.46, 0.57, 0.03, c = fin, ol = false },
			{ "circle", 0.88, 0.46, 0.045, c = INK, ol = false },
		}
	elseif kind == "cat" then
		return {
			{ "tri", 0.16, 0.5, 0.26, dir = 90, c = fin },
			{ "pill", 0.54, 0.52, 0.7, 0.32, c = body },
			{ "tri", 0.5, 0.35, 0.14, dir = 0, c = fin, ol = false },
			{ "line", 0.86, 0.57, 0.98, 0.68, 0.02, c = INK, ol = false },
			{ "line", 0.86, 0.55, 0.99, 0.52, 0.02, c = INK, ol = false },
			{ "circle", 0.76, 0.46, 0.05, c = INK, ol = false },
		}
	elseif kind == "angler" then
		return {
			{ "tri", 0.18, 0.56, 0.26, dir = 90, c = body },
			{ "line", 0.62, 0.34, 0.8, 0.16, 0.025, c = body },
			{ "circle", 0.56, 0.58, 0.56, c = body },
			{ "circle", 0.82, 0.14, 0.11, c = fin },
			{ "tri", 0.78, 0.68, 0.08, dir = 180, c = CREAM, ol = false },
			{ "circle", 0.68, 0.5, 0.06, c = CREAM, ol = false },
		}
	elseif kind == "crab" then
		return {
			{ "line", 0.32, 0.62, 0.16, 0.8, 0.04, c = body },
			{ "line", 0.68, 0.62, 0.84, 0.8, 0.04, c = body },
			{ "circle", 0.2, 0.34, 0.2, c = fin },
			{ "circle", 0.8, 0.34, 0.2, c = fin },
			{ "pill", 0.5, 0.56, 0.6, 0.36, c = body },
			{ "circle", 0.42, 0.48, 0.05, c = CREAM, ol = false },
			{ "circle", 0.58, 0.48, 0.05, c = CREAM, ol = false },
		}
	elseif kind == "boot" then
		return {
			{ "rect", 0.4, 0.42, 0.3, 0.52, r = 0.12, c = body },
			{ "pill", 0.55, 0.74, 0.62, 0.26, c = body },
			{ "rect", 0.55, 0.88, 0.66, 0.07, r = 0.4, c = fin },
			{ "line", 0.32, 0.36, 0.48, 0.36, 0.03, c = fin, ol = false },
			{ "circle", 0.76, 0.3, 0.1, c = "#8FD3EE" },
		}
	elseif kind == "coin" then
		return {
			{ "circle", 0.5, 0.5, 0.78, c = body },
			{ "circle", 0.5, 0.5, 0.58, c = fin, ol = false },
			{ "star", 0.5, 0.5, 0.34, c = body, ol = false },
		}
	end
	return { { "circle", 0.5, 0.5, 0.6, c = body } }
end

function FishArt.ops(catchId: string)
	local def = Fishing.byId[catchId]
	local look = def and def.look or { body = "#9FB8C9", fin = "#6E8BA3", kind = "slim" }
	return fish(look.body, look.fin, look.kind)
end

-- The catch's picture in a frame filling `props` (its size and place): the illustration,
-- or its sticker. `dark`: only its shape, in one dark ink.
function FishArt.image(parent: Instance, catchId: string, props: { [string]: any }?, dark: boolean?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Catch"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	for k, v in props or {} do
		(holder :: any)[k] = v
	end
	holder.Parent = parent
	local name = "fish/" .. catchId
	local art = Art.has(name) and Art.image(holder, name, { ZIndex = holder.ZIndex })
	if art then
		local img = art:FindFirstChild("Image") :: ImageLabel?
		if img and dark then
			img.ImageColor3 = Color3.new(0, 0, 0)
			img.ImageTransparency = 0.45
		end
		return holder
	end
	local ops = FishArt.ops(catchId)
	if dark then
		local out = {}
		for _, op in ops do
			local copy = table.clone(op)
			copy.c = "#3A3846"
			table.insert(out, copy)
		end
		ops = out
	end
	Icons.sticker(holder, ops, { ZIndex = holder.ZIndex }, 0.06)
	return holder
end

return FishArt
