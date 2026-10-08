--[[
	PawnPatterns
	The designs painted on pawn faces (and drawing ops for dice pips), in the IconData op
	format. The pawn face is the circle centred at (0.5, 0.5) with radius 0.5, and every
	pattern stays inside it, so no clipping is needed.

	Colors: "acc" = the skin's accent, "acc2" = the skin's second fill color.
	Pure data/logic (no Roblox APIs) so the offline previewer can draw it too.
]]

local P = {}

-- Chords of the face circle: straight stripes that stop at the rim.
local function chords(angle: number, offsets: { number }, width: number, color: string, inset: number?)
	local ops = {}
	local a = math.rad(angle)
	local tx, ty = math.cos(a), math.sin(a) -- along the stripe
	local nx, ny = -ty, tx -- across stripes
	local R = 0.5 - (inset or 0.04)
	for _, off in offsets do
		local half = math.sqrt(math.max(0, R * R - off * off)) - width * 0.4
		if half > 0.02 then
			local cx, cy = 0.5 + nx * off, 0.5 + ny * off
			table.insert(ops, { "line", cx - tx * half, cy - ty * half, cx + tx * half, cy + ty * half, width, c = color })
		end
	end
	return ops
end

P.ring = { { "ring", 0.5, 0.5, 0.6, 0.075, c = "acc" } }

P.dots = {
	{ "circle", 0.5, 0.5, 0.16, c = "acc" },
	{ "circle", 0.5, 0.24, 0.11, c = "acc" },
	{ "circle", 0.73, 0.38, 0.1, c = "acc" },
	{ "circle", 0.68, 0.68, 0.11, c = "acc" },
	{ "circle", 0.35, 0.73, 0.1, c = "acc" },
	{ "circle", 0.27, 0.43, 0.11, c = "acc" },
}

P.stripes = chords(-45, { -0.3, -0.1, 0.1, 0.3 }, 0.1, "acc")
P.bands = chords(0, { -0.24, 0, 0.24 }, 0.13, "acc")

P.split = {
	{ "half", 0.5, 0.5, 0.92, dir = -35, c = "acc2" },
	{ "line", 0.5 - 0.37, 0.5 - 0.26, 0.5 + 0.37, 0.5 + 0.26, 0.05, c = "acc" },
}

P.wave = {
	{ "taper", { { 0.14, 0.4 }, { 0.3, 0.32 }, { 0.5, 0.4 }, { 0.7, 0.48 }, { 0.86, 0.4 } }, 0.07, 0.05, c = "acc" },
	{ "taper", { { 0.12, 0.6 }, { 0.3, 0.52 }, { 0.5, 0.6 }, { 0.7, 0.68 }, { 0.88, 0.6 } }, 0.07, 0.05, c = "acc" },
	{ "circle", 0.62, 0.24, 0.07, c = "acc" },
	{ "circle", 0.36, 0.78, 0.06, c = "acc" },
}

P.leaf = {
	{ "drop", 0.44, 0.56, 0.2, dir = 45, c = "acc" },
	{ "line", 0.28, 0.72, 0.6, 0.4, 0.035, c = "acc2" },
	{ "drop", 0.66, 0.34, 0.08, dir = 30, c = "acc" },
}

P.gem = {
	{ "hex", 0.5, 0.5, 0.56, c = "acc2" },
	{ "hex", 0.5, 0.5, 0.34, c = "acc" },
	{ "line", 0.5, 0.22, 0.5, 0.33, 0.03, c = "acc" },
	{ "line", 0.26, 0.36, 0.35, 0.41, 0.03, c = "acc" },
	{ "line", 0.74, 0.36, 0.65, 0.41, 0.03, c = "acc" },
	{ "line", 0.26, 0.64, 0.35, 0.59, 0.03, c = "acc" },
	{ "line", 0.74, 0.64, 0.65, 0.59, 0.03, c = "acc" },
	{ "line", 0.5, 0.78, 0.5, 0.67, 0.03, c = "acc" },
}

P.checker = {
	{ "rect", 0.5, 0.5, 0.2, 0.2, rot = 45, c = "acc" },
	{ "rect", 0.29, 0.5, 0.2, 0.2, rot = 45, c = "acc" },
	{ "rect", 0.71, 0.5, 0.2, 0.2, rot = 45, c = "acc" },
	{ "rect", 0.5, 0.29, 0.2, 0.2, rot = 45, c = "acc" },
	{ "rect", 0.5, 0.71, 0.2, 0.2, rot = 45, c = "acc" },
	{ "rect", 0.355, 0.355, 0.08, 0.08, rot = 45, c = "acc" },
	{ "rect", 0.645, 0.355, 0.08, 0.08, rot = 45, c = "acc" },
	{ "rect", 0.355, 0.645, 0.08, 0.08, rot = 45, c = "acc" },
	{ "rect", 0.645, 0.645, 0.08, 0.08, rot = 45, c = "acc" },
}

P.stars = {
	{ "star", 0.5, 0.5, 0.3, c = "acc" },
	{ "sparkle", 0.26, 0.3, 0.14, c = "acc" },
	{ "sparkle", 0.74, 0.28, 0.1, c = "acc" },
	{ "sparkle", 0.72, 0.72, 0.13, c = "acc" },
	{ "circle", 0.3, 0.7, 0.05, c = "acc" },
	{ "circle", 0.82, 0.5, 0.04, c = "acc" },
	{ "circle", 0.2, 0.52, 0.035, c = "acc" },
}

P.flame = {
	{ "taper", { { 0.5, 0.82 }, { 0.58, 0.6 }, { 0.44, 0.4 }, { 0.52, 0.16 } }, 0.3, 0.04, c = "acc" },
	{ "taper", { { 0.34, 0.78 }, { 0.26, 0.6 }, { 0.32, 0.44 } }, 0.16, 0.03, c = "acc" },
	{ "taper", { { 0.66, 0.78 }, { 0.76, 0.62 }, { 0.7, 0.48 } }, 0.15, 0.03, c = "acc" },
	{ "taper", { { 0.5, 0.82 }, { 0.54, 0.68 }, { 0.48, 0.56 } }, 0.14, 0.02, c = "acc2" },
}

P.snow = {
	{ "line", 0.5, 0.2, 0.5, 0.8, 0.06, c = "acc" },
	{ "line", 0.24, 0.35, 0.76, 0.65, 0.06, c = "acc" },
	{ "line", 0.24, 0.65, 0.76, 0.35, 0.06, c = "acc" },
	{ "chevron", 0.5, 0.31, 0.16, 0.05, dir = 0, c = "acc" },
	{ "chevron", 0.5, 0.69, 0.16, 0.05, dir = 180, c = "acc" },
	{ "chevron", 0.34, 0.41, 0.16, 0.05, dir = -60, c = "acc" },
	{ "chevron", 0.66, 0.41, 0.16, 0.05, dir = 60, c = "acc" },
	{ "chevron", 0.34, 0.59, 0.16, 0.05, dir = -120, c = "acc" },
	{ "chevron", 0.66, 0.59, 0.16, 0.05, dir = 120, c = "acc" },
	{ "hex", 0.5, 0.5, 0.12, c = "acc" },
}

P.drip = {
	{ "rect", 0.5, 0.2, 0.62, 0.12, c = "acc" },
	{ "pill", 0.3, 0.3, 0.12, 0.24, c = "acc" },
	{ "pill", 0.48, 0.36, 0.13, 0.34, c = "acc" },
	{ "pill", 0.66, 0.3, 0.11, 0.22, c = "acc" },
	{ "circle", 0.48, 0.58, 0.09, c = "acc" },
	{ "circle", 0.66, 0.47, 0.07, c = "acc" },
	{ "ring", 0.36, 0.7, 0.12, 0.03, c = "acc" },
	{ "ring", 0.64, 0.74, 0.08, 0.025, c = "acc" },
}

P.star = { { "star", 0.5, 0.52, 0.62, c = "acc" }, { "star", 0.5, 0.53, 0.3, c = "acc2" } }

P.wings = {
	{ "taper", { { 0.45, 0.52 }, { 0.3, 0.38 }, { 0.15, 0.26 } }, 0.17, 0.03, c = "acc" },
	{ "taper", { { 0.45, 0.57 }, { 0.28, 0.5 }, { 0.13, 0.46 } }, 0.12, 0.02, c = "acc" },
	{ "taper", { { 0.55, 0.52 }, { 0.7, 0.38 }, { 0.85, 0.26 } }, 0.17, 0.03, c = "acc" },
	{ "taper", { { 0.55, 0.57 }, { 0.72, 0.5 }, { 0.87, 0.46 } }, 0.12, 0.02, c = "acc" },
	{ "drop", 0.5, 0.55, 0.1, c = "acc" },
	{ "taper", { { 0.5, 0.62 }, { 0.46, 0.74 }, { 0.4, 0.85 } }, 0.08, 0.02, c = "acc" },
	{ "taper", { { 0.5, 0.62 }, { 0.5, 0.76 }, { 0.5, 0.88 } }, 0.08, 0.02, c = "acc" },
	{ "taper", { { 0.5, 0.62 }, { 0.54, 0.74 }, { 0.6, 0.85 } }, 0.08, 0.02, c = "acc" },
}

P.eye = {
	{ "pill", 0.5, 0.5, 0.66, 0.36, c = "acc" },
	{ "circle", 0.5, 0.5, 0.3, c = "acc2" },
	{ "circle", 0.5, 0.5, 0.14, c = "acc" },
	{ "circle", 0.45, 0.45, 0.06, c = "acc" },
}

P.diamond = {
	{ "tri", 0.5, 0.44, 0.52, dir = 180, c = "acc" },
	{ "rect", 0.5, 0.37, 0.3, 0.14, c = "acc" },
	{ "tri", 0.35, 0.44, 0.26, dir = 0, c = "acc" },
	{ "tri", 0.65, 0.44, 0.26, dir = 0, c = "acc" },
	{ "line", 0.38, 0.44, 0.5, 0.66, 0.025, c = "acc2" },
	{ "line", 0.62, 0.44, 0.5, 0.66, 0.025, c = "acc2" },
	{ "sparkle", 0.72, 0.26, 0.12, c = "acc" },
}

P.chest = {
	{ "half", 0.5, 0.46, 0.5, dir = 0, c = "acc" },
	{ "rect", 0.5, 0.6, 0.5, 0.28, r = 0.1, c = "acc" },
	{ "rect", 0.5, 0.47, 0.5, 0.03, c = "acc2" },
	{ "rect", 0.5, 0.5, 0.1, 0.12, r = 0.2, c = "acc2" },
	{ "sparkle", 0.24, 0.3, 0.12, c = "acc" },
	{ "sparkle", 0.78, 0.26, 0.1, c = "acc" },
}

P.crown = {
	{ "tri", 0.33, 0.56, 0.22, dir = 0, c = "acc" },
	{ "tri", 0.5, 0.55, 0.26, dir = 0, c = "acc" },
	{ "tri", 0.67, 0.56, 0.22, dir = 0, c = "acc" },
	{ "rect", 0.5, 0.6, 0.46, 0.1, c = "acc" },
	{ "rect", 0.5, 0.68, 0.5, 0.08, r = 0.3, c = "acc" },
	{ "circle", 0.33, 0.44, 0.07, c = "acc" },
	{ "circle", 0.5, 0.41, 0.08, c = "acc" },
	{ "circle", 0.67, 0.44, 0.07, c = "acc" },
}

-- Dice pips: positions on a unit face for values 1..6
P.pips = {
	[1] = { { 0.5, 0.5 } },
	[2] = { { 0.28, 0.28 }, { 0.72, 0.72 } },
	[3] = { { 0.26, 0.26 }, { 0.5, 0.5 }, { 0.74, 0.74 } },
	[4] = { { 0.28, 0.28 }, { 0.72, 0.28 }, { 0.28, 0.72 }, { 0.72, 0.72 } },
	[5] = { { 0.26, 0.26 }, { 0.74, 0.26 }, { 0.5, 0.5 }, { 0.26, 0.74 }, { 0.74, 0.74 } },
	[6] = { { 0.28, 0.24 }, { 0.72, 0.24 }, { 0.28, 0.5 }, { 0.72, 0.5 }, { 0.28, 0.76 }, { 0.72, 0.76 } },
}

return P
