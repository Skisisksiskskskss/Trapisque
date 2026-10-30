--[[
	StickerArt
	Trapisque's code-drawn illustrations, in one style: simple shapes, a thin ink outline
	around every piece (drawn automatically, see Icons.draw), flat colours, two tones at
	most. They stand in for the art (art/cards.py's badges) when the art sheets can't be
	drawn; the hazards and odd bits are drawn from them.

	Pure data (no Roblox APIs), so the offline preview renders exactly the same art.

	Ops are the IconData ops plus:
		{"eyes", cx, cy, gap, d, mood=, look={x,y}}  two eyes   (mood: normal happy angry sad
		{"eye", cx, cy, d, mood=}                     one eye     shock sleepy wink dizzy closed)
		{"mouth", cx, cy, w, mood=}   smile grin open o flat frown smirk teeth
		{"blush", cx, cy, gap, d}     {"shine", cx, cy, d, rot=}
	Option ol = false: no outline for this piece (details inside a shape).

	StickerArt.cards[id], .tokens[kind], .hazards[kind], .misc[name]: op lists
]]

local StickerArt = {}

-- The palette every illustration draws from (Theme mirrors it).
local P = {
	line = "#2A2830",
	white = "#FFFFFF",
	cream = "#FFF9EF",
	coral = "#D64545", -- red
	coralDark = "#A83434",
	orange = "#EE8A2E",
	orangeDark = "#B8601A",
	sun = "#E7B023", -- gold
	sunDark = "#B88A12",
	lime = "#3E9F5B",
	limeDark = "#2E7744",
	leaf = "#3E8E41",
	sky = "#3C82C4",
	skyDark = "#2B6299",
	ice = "#8FD3EE",
	iceLight = "#D6F1FA",
	grape = "#2F4C6E", -- navy (no purple anywhere)
	grapeDark = "#22384F",
	pink = "#D35A9C",
	pinkDark = "#A43F77",
	steel = "#B8BDC7",
	steelDark = "#7D8592",
	wood = "#B87333",
	woodDark = "#7A4A1F",
	mud = "#9C6B3A",
	mudDark = "#6E4520",
	slime = "#9BCF2E",
	slimeDark = "#6DA020",
	water = "#2E8FB3",
	waterDark = "#1F6A8A",
	glass = "#E3F4F7",
	brick = "#E07A4F",
	mortar = "#8E3A2A",
	grog = "#5DB54A",
	grogDark = "#357A30",
	moon = "#FFE7A3",
	moonDark = "#E0C070",
	sand = "#E8C77E",
	sandDark = "#C29A4F",
}
StickerArt.palette = P

---------------------------------------------------------------------------
-- face helpers
---------------------------------------------------------------------------

local function eyes(cx: number, cy: number, gap: number, d: number, mood: string?, look: { number }?)
	return { "eyes", cx, cy, gap, d, mood = mood or "normal", look = look }
end

local function mouth(cx: number, cy: number, w: number, mood: string?)
	return { "mouth", cx, cy, w, mood = mood or "smile" }
end

local function shine(cx: number, cy: number, d: number, rot: number?)
	return { "shine", cx, cy, d, rot = rot or 30 }
end

local function blush(cx: number, cy: number, gap: number, d: number)
	return { "blush", cx, cy, gap, d }
end

local function join(...)
	local out = {}
	for _, list in { ... } do
		for _, op in list do
			table.insert(out, op)
		end
	end
	return out
end

---------------------------------------------------------------------------
-- card art
---------------------------------------------------------------------------

local cards = {}
StickerArt.cards = cards

-- Traps ----------------------------------------------------------------------

cards.spike = {
	{ "taper", { { 0.2, 0.86 }, { 0.2, 0.42 } }, 0.22, 0.04, c = P.steelDark },
	{ "taper", { { 0.8, 0.86 }, { 0.8, 0.42 } }, 0.22, 0.04, c = P.steelDark },
	{ "taper", { { 0.5, 0.86 }, { 0.5, 0.06 } }, 0.46, 0.05, c = P.steel },
	{ "rect", 0.5, 0.88, 0.92, 0.12, r = 0.45, c = P.steelDark },
	shine(0.38, 0.5, 0.2, 8),
	eyes(0.5, 0.6, 0.17, 0.14, "angry"),
	mouth(0.5, 0.75, 0.17, "teeth"),
}

cards.grog = {
	{ "tri", 0.27, 0.27, 0.18, dir = -25, c = P.cream },
	{ "tri", 0.73, 0.27, 0.18, dir = 25, c = P.cream },
	{ "rect", 0.5, 0.59, 0.84, 0.72, r = 0.46, c = P.grog },
	{ "circle", 0.25, 0.74, 0.1, c = P.grogDark, ol = false },
	{ "circle", 0.78, 0.47, 0.08, c = P.grogDark, ol = false },
	{ "circle", 0.73, 0.8, 0.06, c = P.grogDark, ol = false },
	shine(0.27, 0.45, 0.16, 25),
	eyes(0.5, 0.46, 0.28, 0.19, "angry"),
	mouth(0.5, 0.7, 0.44, "teeth"),
}

cards.fire = {
	{ "drop", 0.3, 0.64, 0.13, dir = -35, c = P.orange },
	{ "drop", 0.7, 0.64, 0.13, dir = 35, c = P.orange },
	{ "drop", 0.5, 0.6, 0.31, dir = 0, c = P.orange },
	{ "drop", 0.5, 0.7, 0.2, dir = 0, c = P.sun, ol = false },
	eyes(0.5, 0.62, 0.17, 0.13, "normal", { 0.6, -0.2 }),
	mouth(0.5, 0.76, 0.15, "grin"),
}

cards.ice = {
	{ "rect", 0.5, 0.57, 0.72, 0.66, r = 0.22, c = P.ice },
	{ "rect", 0.5, 0.34, 0.54, 0.1, r = 0.5, c = P.iceLight, ol = false },
	shine(0.26, 0.54, 0.24, 0),
	eyes(0.5, 0.55, 0.25, 0.16, "shock"),
	mouth(0.5, 0.74, 0.22, "teeth"),
	{ "sparkle", 0.86, 0.2, 0.18, c = P.white },
	{ "sparkle", 0.13, 0.86, 0.13, c = P.white },
}

cards.snare = {
	{ "rect", 0.5, 0.52, 0.8, 0.14, c = P.line },
	{ "half", 0.5, 0.58, 0.84, dir = 180, c = P.steel },
	{ "half", 0.5, 0.46, 0.84, dir = 0, c = P.steel },
	{ "tri", 0.2, 0.465, 0.11, dir = 180, c = P.white, ol = false },
	{ "tri", 0.35, 0.465, 0.11, dir = 180, c = P.white, ol = false },
	{ "tri", 0.5, 0.465, 0.11, dir = 180, c = P.white, ol = false },
	{ "tri", 0.65, 0.465, 0.11, dir = 180, c = P.white, ol = false },
	{ "tri", 0.8, 0.465, 0.11, dir = 180, c = P.white, ol = false },
	{ "tri", 0.275, 0.575, 0.11, dir = 0, c = P.white, ol = false },
	{ "tri", 0.425, 0.575, 0.11, dir = 0, c = P.white, ol = false },
	{ "tri", 0.575, 0.575, 0.11, dir = 0, c = P.white, ol = false },
	{ "tri", 0.725, 0.575, 0.11, dir = 0, c = P.white, ol = false },
	shine(0.27, 0.22, 0.14, 50),
	eyes(0.5, 0.3, 0.24, 0.15, "angry"),
}

cards.mudslide = {
	{ "pill", 0.5, 0.8, 0.92, 0.24, c = P.mud },
	{ "circle", 0.71, 0.66, 0.36, c = P.mud },
	{ "circle", 0.42, 0.57, 0.58, c = P.mud },
	{ "circle", 0.84, 0.86, 0.1, c = P.mudDark, ol = false },
	shine(0.27, 0.45, 0.16, 30),
	eyes(0.41, 0.55, 0.19, 0.15, "normal", { -0.8, 0.3 }),
	mouth(0.43, 0.7, 0.13, "o"),
	{ "line", 0.82, 0.36, 0.96, 0.36, 0.035, c = P.white, ol = false },
	{ "line", 0.86, 0.47, 0.97, 0.47, 0.035, c = P.white, ol = false },
}

cards.banana = {
	{ "drop", 0.29, 0.69, 0.14, dir = -118, c = P.sun },
	{ "drop", 0.71, 0.69, 0.14, dir = 118, c = P.sun },
	{ "pill", 0.5, 0.82, 0.5, 0.14, c = P.sunDark },
	{ "drop", 0.5, 0.6, 0.22, dir = 0, c = P.sun },
	{ "rect", 0.5, 0.22, 0.07, 0.08, r = 0.3, c = P.mudDark },
	shine(0.42, 0.55, 0.16, 10),
	eyes(0.5, 0.6, 0.15, 0.11, "wink"),
	mouth(0.5, 0.72, 0.13, "open"),
}

cards.wall = {
	{ "rect", 0.5, 0.58, 0.88, 0.68, r = 0.1, c = P.mortar },
	{ "rect", 0.285, 0.355, 0.39, 0.18, r = 0.18, c = P.brick, ol = false },
	{ "rect", 0.715, 0.355, 0.39, 0.18, r = 0.18, c = P.brick, ol = false },
	{ "rect", 0.155, 0.58, 0.19, 0.18, r = 0.18, c = P.brick, ol = false },
	{ "rect", 0.5, 0.58, 0.44, 0.18, r = 0.18, c = P.brick, ol = false },
	{ "rect", 0.845, 0.58, 0.19, 0.18, r = 0.18, c = P.brick, ol = false },
	{ "rect", 0.285, 0.805, 0.39, 0.18, r = 0.18, c = P.brick, ol = false },
	{ "rect", 0.715, 0.805, 0.39, 0.18, r = 0.18, c = P.brick, ol = false },
	eyes(0.5, 0.55, 0.24, 0.15, "angry"),
	mouth(0.5, 0.69, 0.18, "flat"),
}

-- Assist cards -----------------------------------------------------------------

cards.speed_boost = {
	{ "line", 0.07, 0.36, 0.24, 0.36, 0.05, c = P.white, ol = false },
	{ "line", 0.04, 0.52, 0.2, 0.52, 0.05, c = P.white, ol = false },
	{ "line", 0.08, 0.68, 0.22, 0.68, 0.05, c = P.white, ol = false },
	{ "path", { { 0.66, 0.08 }, { 0.38, 0.5 }, { 0.64, 0.5 }, { 0.36, 0.92 } }, 0.18, c = P.sun },
	eyes(0.51, 0.49, 0.13, 0.1, "happy"),
	{ "text", 0.8, 0.82, 0.3, 0.2, "x2", c = P.white, font = "chunky", stroke = 0.025 },
}

cards.bounce_pad = {
	{ "pill", 0.5, 0.89, 0.72, 0.1, c = P.steelDark },
	{ "path", { { 0.33, 0.85 }, { 0.67, 0.77 }, { 0.33, 0.69 }, { 0.67, 0.61 }, { 0.33, 0.53 } }, 0.07, c = P.steel },
	{ "pill", 0.5, 0.44, 0.82, 0.22, c = P.lime },
	eyes(0.5, 0.43, 0.2, 0.1, "happy"),
	{ "chevron", 0.5, 0.2, 0.26, 0.08, dir = 0, c = P.white },
	{ "chevron", 0.5, 0.1, 0.2, 0.07, dir = 0, c = P.white },
}

cards.moonwalk = {
	{ "circle", 0.5, 0.47, 0.7, c = P.moon },
	{ "circle", 0.3, 0.32, 0.11, c = P.moonDark, ol = false },
	{ "circle", 0.7, 0.68, 0.09, c = P.moonDark, ol = false },
	{ "circle", 0.33, 0.66, 0.06, c = P.moonDark, ol = false },
	{ "rect", 0.37, 0.44, 0.21, 0.13, r = 0.45, c = P.line, ol = false },
	{ "rect", 0.63, 0.44, 0.21, 0.13, r = 0.45, c = P.line, ol = false },
	{ "line", 0.45, 0.42, 0.55, 0.42, 0.03, c = P.line, ol = false },
	{ "line", 0.31, 0.41, 0.36, 0.41, 0.025, c = P.white, ol = false },
	{ "line", 0.57, 0.41, 0.62, 0.41, 0.025, c = P.white, ol = false },
	mouth(0.53, 0.6, 0.15, "smirk"),
	{ "arrow", 0.5, 0.92, 0.5, 0.07, dir = 270, c = P.white },
}

cards.clover = {
	{ "line", 0.52, 0.62, 0.66, 0.93, 0.06, c = P.leaf },
	{ "circle", 0.35, 0.35, 0.34, c = P.lime },
	{ "circle", 0.65, 0.35, 0.34, c = P.lime },
	{ "circle", 0.35, 0.63, 0.34, c = P.lime },
	{ "circle", 0.65, 0.63, 0.34, c = P.lime },
	{ "circle", 0.5, 0.49, 0.34, c = P.lime, ol = false },
	shine(0.29, 0.3, 0.12, 40),
	eyes(0.5, 0.46, 0.15, 0.1, "happy"),
	mouth(0.5, 0.57, 0.11, "smile"),
	blush(0.5, 0.53, 0.25, 0.07),
}

-- Regeneration: a full charge (a bolt in a ring)
cards.juice = {
	{ "ring", 0.5, 0.5, 0.84, 0.11, c = P.lime },
	{ "path", { { 0.6, 0.16 }, { 0.38, 0.54 }, { 0.62, 0.46 }, { 0.4, 0.84 } }, 0.13, c = P.sun },
}

-- a brass compass, its needle swung round
cards.compass = {
	{ "rect", 0.5, 0.1, 0.16, 0.1, r = 0.35, c = P.sunDark },
	{ "circle", 0.5, 0.54, 0.84, c = P.sun },
	{ "circle", 0.5, 0.54, 0.66, c = P.cream, ol = false },
	{ "taper", { { 0.5, 0.54 }, { 0.68, 0.28 } }, 0.15, 0.02, c = P.coral },
	{ "taper", { { 0.5, 0.54 }, { 0.32, 0.8 } }, 0.15, 0.02, c = P.steel },
	{ "circle", 0.5, 0.54, 0.08, c = P.line, ol = false },
}

cards.shield = {
	{ "tri", 0.5, 0.52, 0.76, dir = 180, c = P.sky },
	{ "rect", 0.5, 0.36, 0.76, 0.46, r = 0.24, c = P.sky },
	{ "tri", 0.5, 0.54, 0.5, dir = 180, c = P.skyDark, ol = false },
	{ "rect", 0.5, 0.42, 0.5, 0.3, r = 0.3, c = P.skyDark, ol = false },
	{ "star", 0.5, 0.5, 0.3, c = P.sun },
	shine(0.25, 0.34, 0.16, 20),
	eyes(0.5, 0.27, 0.22, 0.11, "angry"),
}

cards.bridge = {
	{ "pill", 0.5, 0.84, 0.98, 0.22, c = P.water },
	{ "arc", 0.2, 0.84, 0.16, 0.035, dir = 0, c = P.white, ol = false },
	{ "arc", 0.8, 0.84, 0.16, 0.035, dir = 0, c = P.white, ol = false },
	{ "arc", 0.5, 0.86, 0.9, 0.16, dir = 0, c = P.wood },
	{ "rect", 0.5, 0.45, 0.96, 0.12, r = 0.4, c = P.wood },
	{ "line", 0.26, 0.45, 0.26, 0.51, 0.025, c = P.woodDark, ol = false },
	{ "line", 0.5, 0.42, 0.5, 0.51, 0.025, c = P.woodDark, ol = false },
	{ "line", 0.74, 0.45, 0.74, 0.51, 0.025, c = P.woodDark, ol = false },
	{ "line", 0.06, 0.26, 0.94, 0.26, 0.05, c = P.woodDark },
	{ "rect", 0.14, 0.34, 0.05, 0.16, r = 0.3, c = P.woodDark },
	{ "rect", 0.5, 0.33, 0.05, 0.14, r = 0.3, c = P.woodDark },
	{ "rect", 0.86, 0.34, 0.05, 0.16, r = 0.3, c = P.woodDark },
	eyes(0.5, 0.64, 0.2, 0.11, "happy"),
}

cards.key = {
	{ "rect", 0.62, 0.5, 0.5, 0.12, r = 0.3, c = P.sun },
	{ "rect", 0.75, 0.6, 0.07, 0.16, r = 0.2, c = P.sun },
	{ "rect", 0.86, 0.62, 0.07, 0.2, r = 0.2, c = P.sun },
	{ "circle", 0.28, 0.5, 0.44, c = P.sun },
	shine(0.18, 0.42, 0.12, 30),
	eyes(0.28, 0.48, 0.14, 0.1, "normal"),
	mouth(0.28, 0.58, 0.09, "smile"),
}

cards.boots = {
	{ "rect", 0.33, 0.44, 0.24, 0.5, r = 0.15, c = P.sun },
	{ "pill", 0.43, 0.74, 0.5, 0.24, c = P.sun },
	{ "rect", 0.43, 0.87, 0.54, 0.07, r = 0.45, c = P.sunDark },
	{ "rect", 0.65, 0.4, 0.24, 0.5, r = 0.15, c = P.orange },
	{ "pill", 0.75, 0.7, 0.42, 0.24, c = P.orange },
	{ "rect", 0.75, 0.83, 0.46, 0.07, r = 0.45, c = P.orangeDark },
	shine(0.27, 0.35, 0.12, 0),
	eyes(0.65, 0.42, 0.11, 0.08, "happy"),
}

cards.lantern = {
	{ "ring", 0.5, 0.12, 0.16, 0.045, c = P.steelDark },
	{ "rect", 0.5, 0.25, 0.46, 0.08, r = 0.3, c = P.steelDark },
	{ "rect", 0.5, 0.54, 0.4, 0.46, r = 0.2, c = P.moon },
	{ "line", 0.36, 0.34, 0.36, 0.76, 0.03, c = P.steelDark, ol = false },
	{ "line", 0.64, 0.34, 0.64, 0.76, 0.03, c = P.steelDark, ol = false },
	{ "drop", 0.5, 0.58, 0.09, dir = 0, c = P.orange, ol = false },
	{ "drop", 0.5, 0.61, 0.045, dir = 0, c = P.sun, ol = false },
	{ "rect", 0.5, 0.83, 0.46, 0.08, r = 0.3, c = P.steelDark },
}

cards.cloak = {
	{ "tri", 0.5, 0.92, 0.84, dir = 0, c = P.coral },
	{ "rect", 0.5, 0.22, 0.4, 0.12, r = 0.4, c = P.coralDark },
	{ "circle", 0.5, 0.25, 0.08, c = P.sun },
	{ "tri", 0.5, 0.92, 0.42, dir = 0, c = P.coralDark, ol = false },
	{ "drop", 0.5, 0.66, 0.1, dir = 0, c = P.sun, ol = false },
	{ "drop", 0.5, 0.7, 0.05, dir = 0, c = P.orange, ol = false },
}

-- a skating boot on its blade
cards.skates = {
	{ "rect", 0.42, 0.4, 0.3, 0.44, r = 0.18, c = P.coral },
	{ "rect", 0.55, 0.62, 0.56, 0.2, r = 0.45, c = P.coral },
	{ "rect", 0.4, 0.2, 0.34, 0.1, r = 0.4, c = P.cream },
	{ "line", 0.35, 0.33, 0.48, 0.36, 0.025, c = P.coralDark, ol = false },
	{ "line", 0.35, 0.43, 0.48, 0.46, 0.025, c = P.coralDark, ol = false },
	{ "line", 0.32, 0.72, 0.32, 0.83, 0.045, c = P.steelDark },
	{ "line", 0.72, 0.72, 0.72, 0.83, 0.045, c = P.steelDark },
	{ "pill", 0.54, 0.85, 0.76, 0.07, c = P.steel },
	shine(0.35, 0.33, 0.08, 20),
}

-- a barbed harpoon and a coil of its line
cards.harpoon = {
	{ "ring", 0.27, 0.76, 0.3, 0.05, c = P.sand },
	{ "line", 0.18, 0.84, 0.7, 0.3, 0.06, c = P.wood },
	{ "tri", 0.7, 0.3, 0.2, dir = 45, c = P.steel },
	{ "line", 0.64, 0.36, 0.54, 0.3, 0.04, c = P.steelDark },
	{ "line", 0.64, 0.36, 0.7, 0.46, 0.04, c = P.steelDark },
	{ "rect", 0.6, 0.4, 0.1, 0.05, r = 0.3, rot = -45, c = P.steelDark },
}

-- a grappling hook on its rope
cards.grapple = {
	{ "line", 0.5, 0.04, 0.5, 0.18, 0.035, c = P.sand },
	{ "ring", 0.5, 0.21, 0.13, 0.04, c = P.steelDark },
	{ "line", 0.5, 0.27, 0.5, 0.68, 0.07, c = P.steelDark },
	{ "arc", 0.5, 0.62, 0.5, 0.07, dir = 180, c = P.steel },
	{ "tri", 0.26, 0.58, 0.13, dir = 0, c = P.steel },
	{ "tri", 0.74, 0.58, 0.13, dir = 0, c = P.steel },
	{ "tri", 0.5, 0.82, 0.12, dir = 180, c = P.steel },
}

-- Neutral cards ------------------------------------------------------------------

cards.teleporter = {
	{ "circle", 0.5, 0.5, 0.84, c = P.grape },
	{ "circle", 0.5, 0.5, 0.62, c = P.sky, ol = false },
	{ "circle", 0.5, 0.5, 0.4, c = P.iceLight, ol = false },
	{ "arc", 0.5, 0.5, 0.52, 0.05, dir = 40, keep = 0.35, c = P.grape, ol = false },
	{ "arc", 0.5, 0.5, 0.3, 0.05, dir = 220, keep = 0.35, c = P.grape, ol = false },
	{ "sparkle", 0.87, 0.13, 0.18, c = P.white },
	{ "sparkle", 0.13, 0.87, 0.16, c = P.white },
	{ "sparkle", 0.84, 0.82, 0.1, c = P.white },
}

cards.spore_warper = {
	{ "rect", 0.5, 0.74, 0.32, 0.36, r = 0.4, c = P.cream },
	{ "half", 0.5, 0.58, 0.88, dir = 0, c = P.grape },
	{ "rect", 0.5, 0.58, 0.88, 0.08, r = 0.5, c = P.grape },
	{ "circle", 0.32, 0.4, 0.13, c = P.white, ol = false },
	{ "circle", 0.58, 0.28, 0.1, c = P.white, ol = false },
	{ "circle", 0.72, 0.46, 0.08, c = P.white, ol = false },
	eyes(0.5, 0.74, 0.13, 0.1, "dizzy"),
	mouth(0.5, 0.85, 0.08, "o"),
}

cards.conveyor = {
	{ "pill", 0.5, 0.66, 0.94, 0.34, c = P.steelDark },
	{ "circle", 0.21, 0.66, 0.2, c = P.steel, ol = false },
	{ "circle", 0.5, 0.66, 0.2, c = P.steel, ol = false },
	{ "circle", 0.79, 0.66, 0.2, c = P.steel, ol = false },
	{ "circle", 0.21, 0.66, 0.07, c = P.line, ol = false },
	{ "circle", 0.5, 0.66, 0.07, c = P.line, ol = false },
	{ "circle", 0.79, 0.66, 0.07, c = P.line, ol = false },
	{ "arrow", 0.5, 0.26, 0.66, 0.11, dir = 90, c = P.sun },
}

-- a dune, and the two ways it can slide you
cards.sands = {
	{ "half", 0.5, 0.9, 0.98, dir = 0, c = P.sand },
	{ "line", 0.26, 0.76, 0.42, 0.7, 0.035, c = P.sandDark, ol = false },
	{ "line", 0.54, 0.62, 0.7, 0.68, 0.035, c = P.sandDark, ol = false },
	{ "arrow", 0.5, 0.14, 0.6, 0.1, dir = 90, c = P.white },
	{ "arrow", 0.5, 0.3, 0.6, 0.1, dir = 270, c = P.white },
}

-- Potions: one bottle, different brews ----------------------------------------------

local function potion(liquid: string, symbol: { any }, _mood: string?)
	return join({
		{ "rect", 0.5, 0.14, 0.24, 0.1, r = 0.3, c = P.wood },
		{ "rect", 0.5, 0.28, 0.2, 0.2, r = 0.15, c = P.glass },
		{ "circle", 0.5, 0.62, 0.66, c = P.glass },
		{ "half", 0.5, 0.6, 0.58, dir = 180, c = liquid, ol = false },
		{ "rect", 0.5, 0.6, 0.58, 0.05, c = liquid, ol = false },
	}, symbol)
end

cards.thief_potion = potion(P.coral, {
	{ "pill", 0.5, 0.45, 0.34, 0.12, c = P.line },
	{ "circle", 0.42, 0.45, 0.06, c = P.glass, ol = false },
	{ "circle", 0.58, 0.45, 0.06, c = P.glass, ol = false },
})
cards.phoenix_potion = potion(P.orange, {
	{ "drop", 0.5, 0.48, 0.07, dir = 0, c = P.coral },
})
cards.xray_potion = potion(P.lime, {
	{ "eye", 0.5, 0.45, 0.13, mood = "normal" },
})
cards.telepathy_potion = potion(P.pink, {
	{ "arc", 0.5, 0.45, 0.16, 0.035, dir = 90, keep = 0.75, c = P.grapeDark },
	{ "circle", 0.5, 0.45, 0.04, c = P.grapeDark },
}, "dizzy")
cards.time_potion = potion(P.grape, {
	{ "tri", 0.5, 0.39, 0.12, dir = 180, c = P.sun },
	{ "tri", 0.5, 0.51, 0.12, dir = 0, c = P.sun },
})
cards.jeopardy_potion = potion(P.sun, {
	{ "text", 0.5, 0.45, 0.2, 0.14, "?!", c = P.coral, font = "chunky" },
}, "angry")

cards.coin = {
	{ "circle", 0.5, 0.5, 0.84, c = P.sun },
	{ "circle", 0.5, 0.5, 0.64, c = P.sunDark, ol = false },
	{ "star", 0.5, 0.5, 0.38, c = P.sun },
	shine(0.28, 0.36, 0.16, 30),
}

---------------------------------------------------------------------------
-- board tokens, hazards and misc
---------------------------------------------------------------------------

StickerArt.tokens = {
	-- the symbol drawn on each token's coloured disc
	trap = {
		{ "circle", 0.5, 0.44, 0.62, c = P.cream },
		{ "rect", 0.5, 0.69, 0.38, 0.2, r = 0.3, c = P.cream },
		{ "circle", 0.37, 0.44, 0.17, c = P.line, ol = false },
		{ "circle", 0.63, 0.44, 0.17, c = P.line, ol = false },
		{ "tri", 0.5, 0.6, 0.09, dir = 0, c = P.line, ol = false },
		{ "rect", 0.43, 0.75, 0.035, 0.09, c = P.line, ol = false },
		{ "rect", 0.57, 0.75, 0.035, 0.09, c = P.line, ol = false },
	},
	assist = {
		{ "circle", 0.34, 0.42, 0.38, c = P.cream },
		{ "circle", 0.66, 0.42, 0.38, c = P.cream },
		{ "tri", 0.5, 0.49, 0.66, dir = 180, c = P.cream },
		{ "rect", 0.5, 0.5, 0.1, 0.32, r = 0.3, c = P.limeDark, ol = false },
		{ "rect", 0.5, 0.5, 0.32, 0.1, r = 0.3, c = P.limeDark, ol = false },
	},
	neutral = {
		{ "ring", 0.5, 0.5, 0.74, 0.12, c = P.cream },
		{ "arc", 0.5, 0.5, 0.42, 0.1, dir = 0, keep = 0.75, c = P.cream },
		{ "circle", 0.5, 0.5, 0.14, c = P.cream },
	},
	potion = {
		{ "rect", 0.5, 0.2, 0.22, 0.1, r = 0.3, c = P.wood },
		{ "rect", 0.5, 0.32, 0.18, 0.18, r = 0.2, c = P.cream },
		{ "circle", 0.5, 0.64, 0.6, c = P.cream },
		{ "half", 0.5, 0.64, 0.46, dir = 180, c = P.pink, ol = false },
		{ "rect", 0.5, 0.64, 0.46, 0.04, c = P.pink, ol = false },
	},
	coin = {
		{ "circle", 0.5, 0.5, 0.66, c = P.cream },
		{ "star", 0.5, 0.5, 0.36, c = P.sunDark, ol = false },
	},
}

StickerArt.hazards = {
	river = {
		{ "pill", 0.5, 0.52, 0.94, 0.62, c = P.water },
		{ "arc", 0.28, 0.45, 0.24, 0.05, dir = 0, c = P.white, ol = false },
		{ "arc", 0.52, 0.45, 0.24, 0.05, dir = 0, c = P.white, ol = false },
		{ "arc", 0.4, 0.62, 0.24, 0.05, dir = 0, c = P.white, ol = false },
		{ "arc", 0.66, 0.62, 0.24, 0.05, dir = 0, c = P.white, ol = false },
	},
	gate = {
		{ "rect", 0.5, 0.86, 0.9, 0.08, r = 0.4, c = P.steelDark },
		{ "rect", 0.18, 0.58, 0.07, 0.56, r = 0.3, c = P.steelDark },
		{ "rect", 0.34, 0.58, 0.07, 0.56, r = 0.3, c = P.steelDark },
		{ "rect", 0.66, 0.58, 0.07, 0.56, r = 0.3, c = P.steelDark },
		{ "rect", 0.82, 0.58, 0.07, 0.56, r = 0.3, c = P.steelDark },
		{ "arc", 0.5, 0.42, 0.72, 0.07, dir = 0, c = P.steelDark },
		{ "rect", 0.5, 0.62, 0.3, 0.28, r = 0.2, c = P.sun },
		{ "arc", 0.5, 0.48, 0.2, 0.05, dir = 0, c = P.steel },
		eyes(0.5, 0.59, 0.12, 0.08, "angry"),
		mouth(0.5, 0.69, 0.08, "flat"),
	},
	slime = {
		{ "circle", 0.5, 0.56, 0.6, c = P.slime },
		{ "circle", 0.26, 0.68, 0.34, c = P.slime },
		{ "circle", 0.75, 0.7, 0.3, c = P.slime },
		{ "rect", 0.5, 0.8, 0.8, 0.16, r = 0.5, c = P.slime },
		{ "pill", 0.36, 0.9, 0.09, 0.16, c = P.slime },
		{ "circle", 0.84, 0.24, 0.12, c = P.slime },
		{ "circle", 0.72, 0.14, 0.07, c = P.slime },
		shine(0.33, 0.47, 0.14, 30),
		eyes(0.5, 0.55, 0.2, 0.14, "normal", { 0, 0.5 }),
		mouth(0.5, 0.69, 0.12, "smile"),
	},
}

-- Frostbite Floes' cracked ice, Kraken's Reach's tentacle, Clockwork Cove's drawbridge
StickerArt.hazards.thinice = {
	{ "pill", 0.5, 0.56, 0.92, 0.6, c = P.iceLight },
	{ "line", 0.5, 0.56, 0.3, 0.4, 0.03, c = P.skyDark, ol = false },
	{ "line", 0.5, 0.56, 0.74, 0.44, 0.03, c = P.skyDark, ol = false },
	{ "line", 0.5, 0.56, 0.56, 0.78, 0.03, c = P.skyDark, ol = false },
	{ "line", 0.5, 0.56, 0.24, 0.66, 0.03, c = P.skyDark, ol = false },
	{ "line", 0.3, 0.4, 0.2, 0.42, 0.025, c = P.skyDark, ol = false },
	shine(0.28, 0.46, 0.1, 30),
}
StickerArt.hazards.kraken = {
	{ "taper", { { 0.38, 0.92 }, { 0.36, 0.6 }, { 0.46, 0.32 }, { 0.66, 0.2 }, { 0.78, 0.32 }, { 0.68, 0.42 } }, 0.24, 0.07, c = "#B5485E" },
	{ "circle", 0.47, 0.76, 0.07, c = "#F6D2D2" },
	{ "circle", 0.46, 0.62, 0.065, c = "#F6D2D2" },
	{ "circle", 0.5, 0.48, 0.06, c = "#F6D2D2" },
	{ "pill", 0.5, 0.92, 0.62, 0.1, c = P.water },
}
StickerArt.hazards.drawbridge = {
	{ "rect", 0.5, 0.86, 0.94, 0.16, r = 0.3, c = P.water },
	{ "rect", 0.14, 0.62, 0.2, 0.44, r = 0.12, c = P.brick },
	{ "rect", 0.86, 0.62, 0.2, 0.44, r = 0.12, c = P.brick },
	{ "rect", 0.36, 0.42, 0.42, 0.11, r = 0.2, rot = -38, c = P.wood },
	{ "rect", 0.64, 0.42, 0.42, 0.11, r = 0.2, rot = 38, c = P.wood },
	{ "line", 0.14, 0.38, 0.32, 0.22, 0.025, c = P.steelDark },
	{ "line", 0.86, 0.38, 0.68, 0.22, 0.025, c = P.steelDark },
}
-- where the thin ice gave way: open water till the round ends
StickerArt.hazards.hole = {
	{ "pill", 0.5, 0.56, 0.94, 0.62, c = P.iceLight },
	{ "pill", 0.5, 0.57, 0.66, 0.4, c = P.waterDark },
	{ "rect", 0.38, 0.54, 0.12, 0.08, r = 0.2, rot = -20, c = P.glass },
	{ "rect", 0.62, 0.6, 0.1, 0.07, r = 0.2, rot = 25, c = P.glass },
}
-- Clockwork Cove's cogs: a brass gear set into the tile
StickerArt.hazards.cog = (function()
	local shapes = {}
	for i = 0, 7 do
		local a = i * math.pi / 4
		table.insert(shapes, { "rect", 0.5 + 0.36 * math.cos(a), 0.5 + 0.36 * math.sin(a), 0.2, 0.18, r = 0.15, rot = math.deg(a), c = P.sunDark })
	end
	table.insert(shapes, { "circle", 0.5, 0.5, 0.36, c = P.sun })
	table.insert(shapes, { "circle", 0.5, 0.5, 0.16, c = P.sunDark })
	table.insert(shapes, { "circle", 0.5, 0.5, 0.06, c = P.line, ol = false })
	return shapes
end)()

-- Haunted Hollow's ghost (floats over its tile) and Mount Kaboom's lava stream
StickerArt.hazards.lava = {
	{ "rect", 0.5, 0.56, 0.94, 0.62, r = 0.45, c = "#F2541B" },
	{ "circle", 0.3, 0.52, 0.16, c = "#FFB000", ol = false },
	{ "circle", 0.62, 0.62, 0.12, c = "#FFB000", ol = false },
	{ "circle", 0.74, 0.44, 0.1, c = "#7A1E0C", ol = false },
	{ "circle", 0.46, 0.7, 0.08, c = "#7A1E0C", ol = false },
}

StickerArt.misc = {
	ghost = {
		{ "half", 0.5, 0.42, 0.66, dir = 0, c = "#F3F1EA" },
		{ "rect", 0.5, 0.58, 0.66, 0.32, c = "#F3F1EA" },
		{ "circle", 0.28, 0.76, 0.24, c = "#F3F1EA" },
		{ "circle", 0.5, 0.78, 0.24, c = "#F3F1EA" },
		{ "circle", 0.72, 0.76, 0.24, c = "#F3F1EA" },
		{ "pill", 0.4, 0.42, 0.11, 0.17, c = P.line, ol = false },
		{ "pill", 0.6, 0.42, 0.11, 0.17, c = P.line, ol = false },
		{ "circle", 0.5, 0.58, 0.09, c = P.line, ol = false },
	},
	chest = {
		{ "rect", 0.5, 0.66, 0.84, 0.46, r = 0.14, c = P.wood },
		{ "rect", 0.5, 0.42, 0.84, 0.26, r = 0.4, c = P.woodDark },
		{ "rect", 0.5, 0.55, 0.84, 0.08, c = P.sun },
		{ "rect", 0.22, 0.6, 0.08, 0.5, c = P.sun, ol = false },
		{ "rect", 0.78, 0.6, 0.08, 0.5, c = P.sun, ol = false },
		{ "rect", 0.5, 0.6, 0.16, 0.2, r = 0.25, c = P.sun },
		{ "circle", 0.5, 0.6, 0.05, c = P.line, ol = false },
		{ "sparkle", 0.12, 0.2, 0.18, c = P.white },
		{ "sparkle", 0.86, 0.14, 0.14, c = P.white },
	},
	flag = {
		{ "rect", 0.5, 0.88, 0.5, 0.1, r = 0.5, c = P.steelDark },
		{ "rect", 0.3, 0.5, 0.06, 0.8, r = 0.5, c = P.cream },
		{ "rect", 0.56, 0.32, 0.48, 0.34, r = 0.12, c = P.coral },
		{ "tri", 0.8, 0.32, 0.24, dir = 270, c = P.coral, ol = false },
	},
	snowflake = {
		{ "line", 0.5, 0.1, 0.5, 0.9, 0.11, c = P.ice },
		{ "line", 0.15, 0.3, 0.85, 0.7, 0.11, c = P.ice },
		{ "line", 0.15, 0.7, 0.85, 0.3, 0.11, c = P.ice },
		{ "circle", 0.5, 0.5, 0.26, c = P.ice },
	},
	flame = {
		{ "drop", 0.5, 0.6, 0.3, dir = 0, c = P.orange },
		{ "drop", 0.5, 0.7, 0.17, dir = 0, c = P.sun, ol = false },
	},
	bolt = {
		{ "path", { { 0.64, 0.08 }, { 0.36, 0.52 }, { 0.64, 0.48 }, { 0.36, 0.92 } }, 0.2, c = P.sun },
	},
	zzz = {
		{ "text", 0.38, 0.62, 0.5, 0.46, "Z", c = P.sky, font = "chunky", stroke = 0.04 },
		{ "text", 0.7, 0.32, 0.36, 0.32, "z", c = P.sky, font = "chunky", stroke = 0.035 },
	},
	star = {
		{ "star", 0.5, 0.52, 0.86, c = P.sun },
		shine(0.36, 0.42, 0.14, 30),
	},
}

---------------------------------------------------------------------------
-- the characters (their emblems are art: art/emblems.py)
---------------------------------------------------------------------------

-- The character's colour and its darker shade (Theme.Character mirrors these).
StickerArt.bodyColor = {
	mage = { "#2F7FD0", "#245F9C" }, -- blue
	trapper = { "#EE8A2E", "#B8601A" }, -- orange
	fire_starter = { "#D64545", "#A83434" }, -- red
	naturalist = { "#3E9F5B", "#2E7744" }, -- green
	warper = { "#D35A9C", "#A43F77" }, -- pink
	overseer = { "#E7B023", "#B88A12" }, -- gold
	gambler = { "#22A094", "#18786F" }, -- teal
	cannoneer = { "#93633A", "#654227" }, -- brown
}

-- Objects have no faces, and no shines or sparkles: the eyes, mouths, cheeks, glints
-- and twinkles come off every card, token, hazard and odd bit.
local STRIP = { eyes = true, eye = true, mouth = true, blush = true, shine = true, sparkle = true }
local function plain(list)
	for key, ops in list do
		local kept = {}
		for _, op in ops do
			if not STRIP[op[1]] then
				table.insert(kept, op)
			end
		end
		-- (an art made only of sparkles keeps them)
		list[key] = if #kept > 0 then kept else ops
	end
end
plain(StickerArt.cards)
plain(StickerArt.tokens)
plain(StickerArt.hazards)
plain(StickerArt.misc)

return StickerArt
