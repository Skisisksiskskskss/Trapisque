--[[
	FishArt
	The catches from fishing between turns (Shared/Meta/Fishing), as sticker art: plain
	objects in flat inks with the ink outline, no faces (a fish gets one dot of an eye,
	like a printed field guide).

		FishArt.ops(catchId) -> sticker ops
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fishing = require(ReplicatedStorage.Shared.Meta.Fishing)

local FishArt = {}

local INK = "#1C1A24"
local CREAM = "#FFF8E7"

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

return FishArt
