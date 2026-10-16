--[[
	StickerArt
	Trapisque's illustrations, in one style: chunky shapes, a thick ink outline around
	every piece (drawn automatically, see Icons.draw), flat pirate inks with one shine.
	Only the characters have faces; cards, tokens and hazards are plain objects.

	Pure data (no Roblox APIs), so the offline preview renders exactly the same art.

	Ops are the IconData ops plus:
		{"eyes", cx, cy, gap, d, mood=, look={x,y}}  two eyes   (mood: normal happy angry sad
		{"eye", cx, cy, d, mood=}                     one eye     shock sleepy wink dizzy closed)
		{"mouth", cx, cy, w, mood=}   smile grin open o flat frown smirk teeth
		{"blush", cx, cy, gap, d}     {"shine", cx, cy, d, rot=}
	Option ol = false: no outline for this piece (details inside a shape).

	StickerArt.cards[id], .tokens[kind], .hazards[kind], .misc[name]: op lists
	StickerArt.mascot(characterId, mood?): op list for that character's mascot
]]

local StickerArt = {}

-- The palette every illustration draws from: the pirate inks (Theme mirrors them).
local P = {
	line = "#1C1A24",
	white = "#FFFFFF",
	cream = "#FFF8E7",
	coral = "#D7263D", -- pirate red
	coralDark = "#9E1B2C",
	orange = "#F08A24",
	orangeDark = "#B8601A",
	sun = "#F5B700", -- gold
	sunDark = "#C98F00",
	lime = "#5DB54A",
	limeDark = "#357A30",
	leaf = "#3E8E41",
	sky = "#1E7FD6",
	skyDark = "#145A9C",
	ice = "#8FD3EE",
	iceLight = "#D6F1FA",
	grape = "#2B4C7E", -- navy (no purple anywhere)
	grapeDark = "#1C3459",
	pink = "#D94C9C",
	pinkDark = "#A1336F",
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

cards.juice = {
	{ "line", 0.6, 0.27, 0.72, 0.05, 0.05, c = P.white },
	{ "rect", 0.5, 0.6, 0.58, 0.66, r = 0.14, c = P.pink },
	{ "rect", 0.5, 0.31, 0.58, 0.1, r = 0.3, c = P.pinkDark },
	{ "rect", 0.5, 0.72, 0.42, 0.24, r = 0.25, c = P.white, ol = false },
	{ "path", { { 0.54, 0.62 }, { 0.46, 0.73 }, { 0.54, 0.72 }, { 0.46, 0.83 } }, 0.045, c = P.sun, ol = false },
	shine(0.29, 0.52, 0.18, 0),
	eyes(0.5, 0.48, 0.18, 0.11, "happy"),
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

cards.trampoline = {
	{ "line", 0.22, 0.64, 0.14, 0.92, 0.055, c = P.steelDark },
	{ "line", 0.78, 0.64, 0.86, 0.92, 0.055, c = P.steelDark },
	{ "pill", 0.5, 0.6, 0.88, 0.2, c = P.pink },
	{ "pill", 0.5, 0.6, 0.62, 0.06, c = P.pinkDark, ol = false },
	eyes(0.5, 0.57, 0.2, 0.09, "happy"),
	{ "chevron", 0.5, 0.36, 0.26, 0.08, dir = 0, c = P.white },
	{ "chevron", 0.5, 0.24, 0.22, 0.07, dir = 0, c = P.white },
	{ "circle", 0.5, 0.1, 0.12, c = P.sun },
}

-- Potions: one bottle, different brews ----------------------------------------------

local function potion(liquid: string, symbol: { any }, mood: string?)
	return join({
		{ "rect", 0.5, 0.14, 0.24, 0.1, r = 0.3, c = P.wood },
		{ "rect", 0.5, 0.28, 0.2, 0.2, r = 0.15, c = P.glass },
		{ "circle", 0.5, 0.62, 0.66, c = P.glass },
		{ "half", 0.5, 0.6, 0.58, dir = 180, c = liquid, ol = false },
		{ "rect", 0.5, 0.6, 0.58, 0.05, c = liquid, ol = false },
		{ "circle", 0.62, 0.52, 0.05, c = P.white, ol = false },
		{ "circle", 0.68, 0.45, 0.035, c = P.white, ol = false },
		shine(0.31, 0.52, 0.2, 20),
		eyes(0.5, 0.71, 0.15, 0.1, mood or "normal"),
		mouth(0.5, 0.8, 0.08, "smile"),
	}, symbol)
end

cards.speed_potion = potion(P.sky, {
	{ "path", { { 0.54, 0.34 }, { 0.46, 0.45 }, { 0.54, 0.45 }, { 0.46, 0.56 } }, 0.05, c = P.sun },
}, "happy")
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

StickerArt.misc = {
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
-- the characters
---------------------------------------------------------------------------

--[[
	The crew: six cartoon pirates, each one a clear silhouette in its own colour (the
	player's colour everywhere): a big head with a big nose, dot eyes and brows (no
	googly eyes, no blush), a coat in the character's colour and one thing in the left
	hand. All six share the same head and hands, so accessories fit everyone:
		head  centre (0.5, 0.38), 0.34 across; eyes at y 0.36 (x 0.425 / 0.575);
		      nose (0.52, 0.42); mouth y 0.49; hats sit on y 0.25
		body  0.55 to 0.89 (collar y 0.57); hands (0.25, 0.83) left, (0.75, 0.83) right
		feet  y 0.93
]]

-- The character's colour and its darker shade (Theme.Character mirrors these).
local BODY = {
	mage = { "#1E7FD6", "#145A9C" }, -- blue
	trapper = { "#F08A24", "#B8601A" }, -- orange
	fire_starter = { "#D7263D", "#9E1B2C" }, -- red
	naturalist = { "#43A047", "#2E7D32" }, -- green
	warper = { "#D94C9C", "#A1336F" }, -- pink
	overseer = { "#F5B700", "#C98F00" }, -- gold
}
StickerArt.bodyColor = BODY

-- Faces: eyes (dots), brows and mouth for each mood.
local MOODS = {
	idle = { eyes = "normal", brows = "normal", mouth = "smile" },
	happy = { eyes = "happy", brows = "raised", mouth = "grin" },
	shock = { eyes = "shock", brows = "raised", mouth = "o" },
	sad = { eyes = "normal", brows = "sad", mouth = "frown" },
	dizzy = { eyes = "dizzy", brows = "normal", mouth = "flat" },
	smug = { eyes = "smug", brows = "smug", mouth = "smirk" },
	angry = { eyes = "normal", brows = "angry", mouth = "teeth" },
	cheeky = { eyes = "wink", brows = "angry", mouth = "grin" },
}
StickerArt.moods = MOODS

-- A hex colour a little darker (noses are the skin, one shade down).
local function darker(hex: string, k: number): string
	local r = tonumber(string.sub(hex, 2, 3), 16) or 0
	local g = tonumber(string.sub(hex, 4, 5), 16) or 0
	local b = tonumber(string.sub(hex, 6, 7), 16) or 0
	return string.format("#%02X%02X%02X", math.floor(r * k), math.floor(g * k), math.floor(b * k))
end

local INK = P.line
local BOOTS = "#3A2A1E"
local CREAM = P.cream
local GOLD = P.sun
local WHITE = "#F3F1EA"
local HAIR_DARK = "#2A2018"

-- Everyone's base: boots, trousers, coat, arms and hands, ears and head.
local function figure(o)
	local coat = o.coat
	local ops = {}
	local function add(op)
		table.insert(ops, op)
	end
	for _, op in o.back or {} do
		add(op)
	end
	-- feet (boots, or bare feet)
	local feet = o.feet or BOOTS
	add({ "rect", 0.41, 0.93, 0.15, 0.08, r = 0.4, c = feet })
	add({ "rect", 0.59, 0.93, 0.15, 0.08, r = 0.4, c = feet })
	if not o.robe then
		add({ "rect", 0.5, 0.86, 0.28, 0.1, r = 0.2, c = o.trousers or "#4A3A2A" })
	end
	-- arms behind the coat, hands in front
	add({ "pill", 0.27, 0.71, 0.11, 0.27, rot = 14, c = coat })
	add({ "pill", 0.73, 0.71, 0.11, 0.27, rot = -14, c = coat })
	-- the coat (a robe reaches the boots)
	if o.robe then
		add({ "rect", 0.5, 0.74, 0.46, 0.4, r = 0.16, c = coat })
	else
		add({ "rect", 0.5, 0.72, 0.44, 0.34, r = 0.18, c = coat })
	end
	for _, op in o.coatDetail or {} do
		add(op)
	end
	add({ "circle", 0.25, 0.84, 0.1, c = o.skin })
	add({ "circle", 0.75, 0.84, 0.1, c = o.skin })
	for _, op in o.hand or {} do
		add(op)
	end
	-- head
	for _, op in o.hairBack or {} do
		add(op)
	end
	add({ "circle", 0.33, 0.4, 0.08, c = o.skin })
	add({ "circle", 0.67, 0.4, 0.08, c = o.skin })
	add({ "circle", 0.5, 0.38, 0.34, c = o.skin })
	for _, op in o.faceDetail or {} do
		add(op)
	end
	return ops
end

-- What makes each one themselves: clothes, hair, hat (which an accessory hat
-- replaces), the thing in their hand, and their usual mood.
local CREW = {
	mage = {
		skin = "#F2C9A0",
		coat = BODY.mage[1],
		coatDark = BODY.mage[2],
		robe = true,
		coatDetail = {
			{ "line", 0.5, 0.58, 0.5, 0.92, 0.03, c = GOLD, ol = false },
			{ "star", 0.38, 0.72, 0.07, c = GOLD, ol = false },
		},
		-- an ice staff in the left hand
		hand = {
			{ "line", 0.2, 0.5, 0.2, 0.98, 0.035, c = "#9C6B3A" },
			{ "drop", 0.2, 0.47, 0.05, dir = 0, c = "#8FD3EE" },
		},
		-- a long white beard
		faceDetail = {
			{ "half", 0.5, 0.47, 0.3, dir = 180, c = WHITE },
			{ "tri", 0.5, 0.6, 0.2, dir = 180, c = WHITE },
			{ "pill", 0.45, 0.465, 0.12, 0.05, rot = 10, c = WHITE },
			{ "pill", 0.55, 0.465, 0.12, 0.05, rot = -10, c = WHITE },
		},
		browColor = WHITE,
		hat = {
			{ "taper", { { 0.5, 0.25 }, { 0.53, 0.11 }, { 0.63, 0.03 } }, 0.34, 0.05, c = BODY.mage[1] },
			{ "pill", 0.5, 0.25, 0.56, 0.08, c = BODY.mage[1] },
			{ "line", 0.36, 0.22, 0.64, 0.22, 0.025, c = GOLD, ol = false },
			{ "circle", 0.47, 0.14, 0.07, c = GOLD, ol = false },
			{ "circle", 0.49, 0.13, 0.06, c = BODY.mage[1], ol = false },
		},
		mood = "idle",
	},
	trapper = {
		skin = "#E2AD80",
		coat = BODY.trapper[1],
		coatDark = BODY.trapper[2],
		trousers = "#5A4632",
		-- a fur collar and a belt with a brass buckle
		coatDetail = {
			{ "pill", 0.5, 0.58, 0.36, 0.08, c = "#8B5A2B" },
			{ "rect", 0.5, 0.8, 0.44, 0.05, c = "#5A3A22", ol = false },
			{ "rect", 0.5, 0.8, 0.06, 0.06, r = 0.2, c = GOLD, ol = false },
		},
		-- a coil of rope (a filled coil: a ring's outline balloons at big sizes)
		hand = {
			{ "line", 0.22, 0.87, 0.26, 0.97, 0.025, c = "#C9A26B" },
			{ "circle", 0.22, 0.8, 0.15, c = "#C9A26B" },
			{ "circle", 0.22, 0.8, 0.09, c = "#A8844E", ol = false },
			{ "circle", 0.22, 0.8, 0.045, c = "#C9A26B", ol = false },
		},
		-- long auburn hair: a braid over her shoulder, locks framing her face
		hairBack = {
			{ "circle", 0.5, 0.39, 0.4, c = "#C0562A" },
			{ "pill", 0.69, 0.6, 0.09, 0.3, rot = -10, c = "#C0562A" },
			{ "line", 0.66, 0.55, 0.72, 0.53, 0.015, c = "#7A3212", ol = false },
			{ "line", 0.67, 0.62, 0.73, 0.6, 0.015, c = "#7A3212", ol = false },
			{ "circle", 0.705, 0.75, 0.05, c = "#3F8F4A" },
		},
		faceDetail = {
			{ "pill", 0.35, 0.41, 0.06, 0.15, c = "#C0562A", ol = false },
			{ "pill", 0.65, 0.41, 0.06, 0.15, c = "#C0562A", ol = false },
			{ "circle", 0.4, 0.45, 0.05, c = "#E8907A", ol = false },
			{ "circle", 0.6, 0.45, 0.05, c = "#E8907A", ol = false },
		},
		lashes = true,
		-- a coonskin cap with its striped tail
		hat = {
			{ "taper", { { 0.63, 0.25 }, { 0.75, 0.32 }, { 0.78, 0.46 } }, 0.08, 0.06, c = "#7A6A58" },
			{ "line", 0.72, 0.3, 0.77, 0.33, 0.02, c = HAIR_DARK, ol = false },
			{ "line", 0.76, 0.38, 0.8, 0.39, 0.02, c = HAIR_DARK, ol = false },
			{ "half", 0.5, 0.27, 0.37, dir = 0, c = "#7A6A58" },
			{ "pill", 0.5, 0.27, 0.39, 0.07, c = "#5A4C3E" },
		},
		mood = "idle",
	},
	fire_starter = {
		skin = "#A86B45",
		coat = BODY.fire_starter[1],
		coatDark = BODY.fire_starter[2],
		trousers = "#3A3A44",
		coatDetail = {
			{ "circle", 0.5, 0.64, 0.035, c = GOLD, ol = false },
			{ "circle", 0.5, 0.72, 0.035, c = GOLD, ol = false },
			{ "rect", 0.5, 0.79, 0.44, 0.05, c = "#3A2A1E", ol = false },
		},
		-- a lit torch
		hand = {
			{ "line", 0.24, 0.88, 0.18, 0.58, 0.04, c = "#9C6B3A" },
			{ "drop", 0.18, 0.52, 0.06, dir = 0, c = P.orange },
			{ "drop", 0.18, 0.535, 0.03, dir = 0, c = GOLD, ol = false },
		},
		-- a bushy black chin beard
		faceDetail = { { "half", 0.5, 0.52, 0.24, dir = 180, c = HAIR_DARK } },
		hat = {
			{ "pill", 0.7, 0.3, 0.06, 0.14, rot = 55, c = BODY.fire_starter[1] },
			{ "pill", 0.71, 0.34, 0.06, 0.12, rot = 100, c = BODY.fire_starter[1] },
			{ "half", 0.5, 0.29, 0.37, dir = 0, c = BODY.fire_starter[1] },
			{ "circle", 0.42, 0.25, 0.04, c = CREAM, ol = false },
			{ "circle", 0.56, 0.21, 0.04, c = CREAM, ol = false },
		},
		mood = "cheeky",
	},
	naturalist = {
		skin = "#C68A5A",
		coat = BODY.naturalist[1],
		coatDark = BODY.naturalist[2],
		trousers = "#8C6B3E",
		feet = "#C68A5A",
		coatDetail = {
			{ "tri", 0.34, 0.89, 0.08, dir = 180, c = BODY.naturalist[1], ol = false },
			{ "tri", 0.45, 0.89, 0.08, dir = 180, c = BODY.naturalist[1], ol = false },
			{ "tri", 0.56, 0.89, 0.08, dir = 180, c = BODY.naturalist[1], ol = false },
			{ "tri", 0.67, 0.89, 0.08, dir = 180, c = BODY.naturalist[1], ol = false },
			{ "line", 0.32, 0.6, 0.68, 0.84, 0.03, c = "#8C6B3E", ol = false },
		},
		-- a coconut
		hand = { { "circle", 0.21, 0.8, 0.12, c = "#7A4A1F" } },
		-- two braids
		hairBack = {
			{ "pill", 0.34, 0.52, 0.07, 0.2, c = "#4A2E1A" },
			{ "pill", 0.66, 0.52, 0.07, 0.2, c = "#4A2E1A" },
		},
		faceDetail = {
			{ "half", 0.5, 0.29, 0.34, dir = 0, c = "#4A2E1A" },
			{ "circle", 0.4, 0.42, 0.018, c = "#8C5A3A", ol = false },
			{ "circle", 0.6, 0.42, 0.018, c = "#8C5A3A", ol = false },
		},
		-- a big leaf for a hat, and a flower
		hat = {
			{ "line", 0.34, 0.26, 0.66, 0.26, 0.022, c = "#357A30" },
			{ "drop", 0.38, 0.225, 0.06, dir = -45, c = "#5DB54A" },
			{ "drop", 0.62, 0.225, 0.06, dir = 45, c = "#5DB54A" },
			{ "drop", 0.5, 0.205, 0.065, dir = 0, c = "#7CC85A" },
			{ "circle", 0.67, 0.28, 0.08, c = P.pink },
			{ "circle", 0.67, 0.28, 0.03, c = GOLD, ol = false },
		},
		lashes = true,
		mood = "happy",
	},
	warper = {
		skin = "#F0C29A",
		coat = BODY.warper[1],
		coatDark = BODY.warper[2],
		trousers = "#2A2836",
		-- a frilly white cravat
		coatDetail = {
			{ "tri", 0.5, 0.58, 0.16, dir = 180, c = CREAM },
			{ "circle", 0.5, 0.6, 0.05, c = CREAM, ol = false },
		},
		-- a gold pocket watch
		hand = {
			{ "line", 0.25, 0.8, 0.3, 0.7, 0.015, c = GOLD, ol = false },
			{ "circle", 0.22, 0.85, 0.12, c = GOLD },
			{ "circle", 0.22, 0.85, 0.08, c = CREAM, ol = false },
			{ "line", 0.22, 0.85, 0.22, 0.815, 0.015, c = INK, ol = false },
			{ "line", 0.22, 0.85, 0.245, 0.85, 0.015, c = INK, ol = false },
		},
		-- a thin curly moustache
		faceDetail = {
			{ "pill", 0.455, 0.465, 0.09, 0.03, rot = 12, c = "#5A3A22" },
			{ "pill", 0.545, 0.465, 0.09, 0.03, rot = -12, c = "#5A3A22" },
			{ "circle", 0.405, 0.45, 0.03, c = "#5A3A22", ol = false },
			{ "circle", 0.595, 0.45, 0.03, c = "#5A3A22", ol = false },
		},
		-- a wide hat with a huge white feather
		hat = {
			{ "taper", { { 0.58, 0.2 }, { 0.71, 0.1 }, { 0.83, 0.07 } }, 0.09, 0.03, c = WHITE },
			{ "rect", 0.5, 0.19, 0.3, 0.13, r = 0.3, c = BODY.warper[1] },
			{ "rect", 0.5, 0.225, 0.3, 0.035, c = INK, ol = false },
			{ "pill", 0.5, 0.26, 0.64, 0.08, c = BODY.warper[1] },
		},
		mood = "idle",
	},
	overseer = {
		skin = "#7A4E2D",
		coat = BODY.overseer[1],
		coatDark = BODY.overseer[2],
		trousers = "#2A2836",
		-- a harbour master's gold coat: navy lapels and cuffs, brass buttons, a white jabot
		coatDetail = {
			{ "line", 0.44, 0.6, 0.46, 0.86, 0.035, c = "#2B4C7E", ol = false },
			{ "line", 0.56, 0.6, 0.54, 0.86, 0.035, c = "#2B4C7E", ol = false },
			{ "circle", 0.4, 0.7, 0.035, c = "#A87A00", ol = false },
			{ "circle", 0.4, 0.78, 0.035, c = "#A87A00", ol = false },
			{ "circle", 0.6, 0.7, 0.035, c = "#A87A00", ol = false },
			{ "circle", 0.6, 0.78, 0.035, c = "#A87A00", ol = false },
			{ "tri", 0.5, 0.615, 0.1, dir = 180, c = CREAM },
			{ "pill", 0.255, 0.8, 0.12, 0.05, rot = 14, c = "#2B4C7E" },
			{ "pill", 0.745, 0.8, 0.12, 0.05, rot = -14, c = "#2B4C7E" },
		},
		-- a brass spyglass, pulled out
		hand = {
			{ "line", 0.25, 0.88, 0.185, 0.67, 0.075, c = "#C9A227" },
			{ "line", 0.185, 0.67, 0.155, 0.57, 0.055, c = "#A87A00" },
			{ "line", 0.232, 0.82, 0.222, 0.785, 0.08, c = "#8A6410", ol = false },
		},
		-- grey hair at the temples and a short grey beard
		faceDetail = {
			{ "pill", 0.345, 0.37, 0.05, 0.1, c = "#C9C2B6", ol = false },
			{ "pill", 0.655, 0.37, 0.05, 0.1, c = "#C9C2B6", ol = false },
			{ "half", 0.5, 0.485, 0.29, dir = 180, c = "#D8D2C8" },
			{ "pill", 0.455, 0.47, 0.1, 0.04, rot = 10, c = "#D8D2C8" },
			{ "pill", 0.545, 0.47, 0.1, 0.04, rot = -10, c = "#D8D2C8" },
		},
		browColor = "#D8D2C8",
		-- a navy tricorn with gold trim and a cockade
		hat = {
			{ "tri", 0.29, 0.21, 0.1, dir = -40, c = "#2B4C7E" },
			{ "tri", 0.71, 0.21, 0.1, dir = 40, c = "#2B4C7E" },
			{ "half", 0.5, 0.255, 0.3, dir = 0, c = "#2B4C7E" },
			{ "pill", 0.5, 0.255, 0.5, 0.08, c = "#2B4C7E" },
			{ "line", 0.28, 0.275, 0.72, 0.275, 0.018, c = GOLD, ol = false },
			{ "circle", 0.5, 0.235, 0.07, c = GOLD },
			{ "circle", 0.5, 0.235, 0.028, c = "#2B4C7E", ol = false },
		},
		mood = "idle",
	},
}
StickerArt.crew = CREW

-- Objects have no faces in the pirate look (only the characters do), and no shines
-- or sparkles: the eyes, mouths, cheeks, glints and twinkles come off every card,
-- token, hazard and odd bit.
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

--[[
	A character, pulling a face: mood = idle | happy | shock | sad | dizzy | smug |
	angry | cheeky (nil = their usual one). opts.hat: they wear a hat (an accessory),
	so their own comes off. opts.bust: just the head and shoulders (portraits);
	opts.crop: a bust for a round portrait that crops it (Icons.medallion), whose coat
	runs off the bottom and whose hat stays inside the circle.
]]
function StickerArt.mascot(characterId: string, moodName: string?, opts: { [string]: any }?)
	local crew = CREW[characterId] or CREW.mage
	local mood = MOODS[moodName or crew.mood or "idle"] or MOODS.idle
	local bust = opts ~= nil and (opts.bust == true or opts.crop == true)
	local crop = opts ~= nil and opts.crop == true
	local ops
	if bust then
		-- just the head and the shoulders of the coat
		ops = {}
		for _, op in crew.hairBack or {} do
			table.insert(ops, op)
		end
		if crop then
			table.insert(ops, { "rect", 0.5, 0.98, 0.7, 0.76, r = 0.32, c = crew.coat })
		else
			table.insert(ops, { "half", 0.5, 0.74, 0.56, dir = 0, c = crew.coat })
		end
		table.insert(ops, { "circle", 0.33, 0.4, 0.08, c = crew.skin })
		table.insert(ops, { "circle", 0.67, 0.4, 0.08, c = crew.skin })
		table.insert(ops, { "circle", 0.5, 0.38, 0.34, c = crew.skin })
		for _, op in crew.faceDetail or {} do
			table.insert(ops, op)
		end
	else
		ops = figure(table.clone(crew))
	end
	if not (opts and opts.hat) then
		for _, op in crew.hat or {} do
			table.insert(ops, op)
		end
	end
	-- the face goes on last: a small nose, then the brows, eyes (lashes) and mouth
	table.insert(ops, { "pill", 0.5, 0.435, 0.06, 0.05, c = darker(crew.skin, 0.8), ol = false })
	table.insert(ops, { "brows", 0.5, 0.3, 0.15, 0.06, mood = mood.brows, c = crew.browColor })
	table.insert(ops, { "dots", 0.5, 0.36, 0.15, 0.045, mood = mood.eyes })
	if crew.lashes and mood.eyes ~= "happy" and mood.eyes ~= "dizzy" then
		table.insert(ops, { "line", 0.39, 0.335, 0.365, 0.315, 0.014, c = INK, ol = false })
		table.insert(ops, { "line", 0.61, 0.335, 0.635, 0.315, 0.014, c = INK, ol = false })
	end
	table.insert(ops, { "mouth", 0.5, 0.5, 0.1, mood = mood.mouth })
	if crop then
		return { { "group", s = 1.05, dy = 0.13, ops = ops } }
	elseif bust then
		return { { "group", s = 1.4, dy = 0.17, ops = ops } }
	end
	return ops
end

return StickerArt
