--[[
	StickerArt
	Trapisque's illustrations, in one style: chunky shapes, a thick dark outline around
	every piece (drawn automatically, see Icons.draw), flat candy colours with one shine,
	and faces. Traps, cards, potions and the characters all have eyes, so the whole cast
	feels like it belongs together.

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

-- The palette every illustration draws from (Theme mirrors the UI colours).
local P = {
	line = "#1B1030",
	white = "#FFFFFF",
	cream = "#FFF4E2",
	coral = "#FF4F5E",
	coralDark = "#C9303F",
	orange = "#FF9A3C",
	orangeDark = "#D9661A",
	sun = "#FFD23F",
	sunDark = "#E0A81C",
	lime = "#8BE04E",
	limeDark = "#4FAE2A",
	leaf = "#3FA34D",
	sky = "#45C3FF",
	skyDark = "#1E8FD6",
	ice = "#9FE6FF",
	iceLight = "#D9F6FF",
	grape = "#9A6BFF",
	grapeDark = "#6B3FD6",
	pink = "#FF6FB8",
	pinkDark = "#D9408C",
	steel = "#C9D3E6",
	steelDark = "#8792AD",
	wood = "#C98A4B",
	woodDark = "#8E5726",
	mud = "#A8743F",
	mudDark = "#6E4520",
	slime = "#A6E83A",
	slimeDark = "#6DB21F",
	water = "#3FA7F5",
	waterDark = "#1F6FC4",
	glass = "#E3F7FF",
	brick = "#F07A55",
	mortar = "#8E3A2A",
	grog = "#6CC24A",
	grogDark = "#3F8F2A",
	moon = "#FFE58A",
	moonDark = "#E8C45A",
}
StickerArt.palette = P

---------------------------------------------------------------------------
-- face helpers
---------------------------------------------------------------------------

local function eyes(cx: number, cy: number, gap: number, d: number, mood: string?, look: { number }?)
	return { "eyes", cx, cy, gap, d, mood = mood or "normal", look = look }
end

local function eye(cx: number, cy: number, d: number, mood: string?, look: { number }?)
	return { "eye", cx, cy, d, mood = mood or "normal", look = look }
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

-- Body colour, darker shade (feet, details) for each character.
local BODY = {
	mage = { P.sky, P.skyDark },
	trapper = { "#E8893A", "#A95A1E" },
	fire_starter = { P.coral, P.coralDark },
	naturalist = { P.lime, P.limeDark },
	warper = { P.grape, P.grapeDark },
	overseer = { P.sun, P.sunDark },
}
StickerArt.bodyColor = BODY

local MOODS = {
	idle = { eyes = "normal", mouth = "smile" },
	happy = { eyes = "happy", mouth = "grin" },
	shock = { eyes = "shock", mouth = "o" },
	sad = { eyes = "sad", mouth = "frown" },
	dizzy = { eyes = "dizzy", mouth = "flat" },
	smug = { eyes = "normal", mouth = "smirk", look = { 0.7, 0 } },
	angry = { eyes = "angry", mouth = "teeth" },
	cheeky = { eyes = "angry", mouth = "grin" },
}
StickerArt.moods = MOODS

-- What sits behind the body (ears, tails, flames), on top of it (hats, masks) and
-- each character's own default face.
local GEAR = {
	mage = {
		front = {
			{ "taper", { { 0.5, 0.31 }, { 0.53, 0.17 }, { 0.65, 0.04 } }, 0.38, 0.05, c = "#7B4CE6" },
			{ "pill", 0.5, 0.32, 0.72, 0.11, c = "#7B4CE6" },
			{ "rect", 0.5, 0.27, 0.36, 0.05, r = 0.3, c = P.sun, ol = false },
			{ "star", 0.47, 0.17, 0.12, c = P.sun },
		},
		mood = "smug",
	},
	trapper = {
		back = {
			{ "taper", { { 0.74, 0.84 }, { 0.93, 0.7 }, { 0.9, 0.46 } }, 0.15, 0.12, c = "#E8893A" },
			{ "line", 0.86, 0.58, 0.97, 0.6, 0.04, c = "#5A3218", ol = false },
			{ "line", 0.84, 0.7, 0.94, 0.76, 0.04, c = "#5A3218", ol = false },
			{ "circle", 0.29, 0.34, 0.2, c = "#E8893A" },
			{ "circle", 0.71, 0.34, 0.2, c = "#E8893A" },
			{ "circle", 0.29, 0.34, 0.09, c = "#5A3218", ol = false },
			{ "circle", 0.71, 0.34, 0.09, c = "#5A3218", ol = false },
		},
		front = {
			{ "pill", 0.5, 0.56, 0.58, 0.17, c = "#5A3218", ol = false },
			{ "circle", 0.5, 0.665, 0.07, c = P.line, ol = false },
		},
		mood = "smug",
	},
	fire_starter = {
		back = {
			{ "drop", 0.33, 0.35, 0.12, dir = -30, c = P.orange },
			{ "drop", 0.67, 0.35, 0.12, dir = 30, c = P.orange },
			{ "drop", 0.5, 0.31, 0.17, dir = 0, c = P.orange },
			{ "drop", 0.5, 0.35, 0.09, dir = 0, c = P.sun, ol = false },
		},
		mood = "cheeky",
	},
	naturalist = {
		back = {
			{ "line", 0.5, 0.33, 0.5, 0.18, 0.045, c = P.leaf },
			{ "drop", 0.4, 0.17, 0.08, dir = -65, c = P.leaf },
			{ "drop", 0.6, 0.15, 0.08, dir = 65, c = P.leaf },
		},
		front = {
			{ "circle", 0.3, 0.66, 0.025, c = P.leaf, ol = false },
			{ "circle", 0.27, 0.62, 0.02, c = P.leaf, ol = false },
			{ "circle", 0.7, 0.66, 0.025, c = P.leaf, ol = false },
			{ "circle", 0.73, 0.62, 0.02, c = P.leaf, ol = false },
			{ "circle", 0.76, 0.42, 0.1, c = P.pink },
			{ "circle", 0.76, 0.42, 0.04, c = P.sun, ol = false },
		},
		mood = "happy",
	},
	warper = {
		back = {
			{ "tri", 0.32, 0.36, 0.22, dir = -18, c = P.grape },
			{ "tri", 0.68, 0.36, 0.22, dir = 18, c = P.grape },
			{ "tri", 0.33, 0.37, 0.1, dir = -18, c = P.pink, ol = false },
			{ "tri", 0.67, 0.37, 0.1, dir = 18, c = P.pink, ol = false },
		},
		front = {
			{ "ring", 0.5, 0.82, 0.16, 0.04, c = P.sky, ol = false },
			{ "circle", 0.5, 0.82, 0.05, c = P.sky, ol = false },
		},
		mood = "smug",
	},
	overseer = {
		back = {
			{ "rect", 0.5, 0.31, 0.38, 0.1, r = 0.2, c = P.orange },
			{ "tri", 0.37, 0.27, 0.13, dir = 0, c = P.orange },
			{ "tri", 0.5, 0.25, 0.15, dir = 0, c = P.orange },
			{ "tri", 0.63, 0.27, 0.13, dir = 0, c = P.orange },
			{ "circle", 0.5, 0.31, 0.05, c = P.pink, ol = false },
		},
		cyclops = true,
		mood = "idle",
	},
}

--[[
	The mascot for a character. mood: idle | happy | shock | sad | dizzy | smug | angry
	(nil = the character's usual face).
]]
function StickerArt.mascot(characterId: string, moodName: string?)
	local colors = BODY[characterId] or { P.steel, P.steelDark }
	local gear = GEAR[characterId] or {}
	local mood = MOODS[moodName or gear.mood or "idle"] or MOODS.idle
	local body, dark = colors[1], colors[2]
	local ops = {}
	for _, op in gear.back or {} do
		table.insert(ops, op)
	end
	-- feet, nubby arms, body
	table.insert(ops, { "pill", 0.37, 0.93, 0.2, 0.1, c = dark })
	table.insert(ops, { "pill", 0.63, 0.93, 0.2, 0.1, c = dark })
	table.insert(ops, { "pill", 0.19, 0.68, 0.12, 0.2, rot = 25, c = body })
	table.insert(ops, { "pill", 0.81, 0.68, 0.12, 0.2, rot = -25, c = body })
	table.insert(ops, { "rect", 0.5, 0.62, 0.62, 0.62, r = 0.46, c = body })
	table.insert(ops, shine(0.3, 0.47, 0.17, 25))
	for _, op in gear.front or {} do
		table.insert(ops, op)
	end
	if gear.cyclops then
		table.insert(ops, eye(0.5, 0.56, 0.28, mood.eyes, mood.look))
		table.insert(ops, mouth(0.5, 0.77, 0.12, mood.mouth))
	else
		table.insert(ops, eyes(0.5, 0.56, 0.21, 0.17, mood.eyes, mood.look))
		table.insert(ops, mouth(0.5, 0.72, 0.13, mood.mouth))
		table.insert(ops, blush(0.5, 0.67, 0.38, 0.08))
	end
	return ops
end

return StickerArt
