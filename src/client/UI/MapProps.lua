--[[
	MapProps
	The things that stand around the maps' trails: palms and huts on the island, towers
	and cannons in the fortress, mangroves and lily pads in the swamp, ships at sea. Sticker
	art (see StickerArt / Icons.sticker for the ops): flat pirate inks, one heavy ink
	outline around the whole shape, no faces. Pure data.

	MapProps[kind] = ops in a square canvas; the prop stands on the canvas's bottom middle.
]]

local P = {
	line = "#1C1A24",
	cream = "#FFF8E7",
	white = "#FFFFFF",
	sand = "#F2C879",
	sandDark = "#D9A54A",
	trunk = "#9C6B3A",
	trunkDark = "#6E4520",
	leaf = "#4FA548",
	leafDark = "#357A30",
	leafLight = "#7CC35A",
	rock = "#A39B8B",
	rockDark = "#7D776B",
	rockLight = "#C9C2B2",
	wood = "#B87333",
	woodDark = "#7A4A1F",
	woodLight = "#D69A5B",
	straw = "#E8C26A",
	strawDark = "#C99A3E",
	red = "#D7263D",
	redDark = "#9E1B2C",
	gold = "#F5B700",
	orange = "#F08A24",
	navy = "#2B4C7E",
	iron = "#3A3A44",
	ironLight = "#6B6B78",
	stone = "#BDB5A3",
	stoneDark = "#8C8476",
	water = "#2A8FBF",
	moss = "#55803A",
	mossDark = "#3F6A2C",
	swampLeaf = "#3E8E41",
	pink = "#D94C9C",
	bone = "#F3E6C8",
	slime = "#9BCF2E",
}

local MapProps = {}
MapProps.palette = P

-- island ------------------------------------------------------------------

MapProps.palm = {
	{ "taper", { { 0.44, 0.97 }, { 0.47, 0.72 }, { 0.56, 0.4 } }, 0.12, 0.075, c = P.trunk },
	{ "line", 0.45, 0.86, 0.5, 0.85, 0.03, c = P.trunkDark, ol = false },
	{ "line", 0.47, 0.72, 0.52, 0.71, 0.03, c = P.trunkDark, ol = false },
	{ "line", 0.5, 0.58, 0.55, 0.57, 0.03, c = P.trunkDark, ol = false },
	{ "pill", 0.33, 0.36, 0.44, 0.13, rot = 24, c = P.leafDark },
	{ "pill", 0.8, 0.36, 0.44, 0.13, rot = -24, c = P.leafDark },
	{ "pill", 0.38, 0.24, 0.42, 0.13, rot = -22, c = P.leaf },
	{ "pill", 0.74, 0.24, 0.42, 0.13, rot = 22, c = P.leaf },
	{ "pill", 0.57, 0.19, 0.13, 0.32, rot = 4, c = P.leafLight },
	{ "circle", 0.52, 0.42, 0.1, c = P.trunkDark },
	{ "circle", 0.62, 0.41, 0.1, c = P.trunkDark },
}

MapProps.bush = {
	{ "circle", 0.3, 0.66, 0.42, c = P.leafDark },
	{ "circle", 0.7, 0.66, 0.42, c = P.leafDark },
	{ "circle", 0.5, 0.52, 0.5, c = P.leaf },
	{ "circle", 0.42, 0.44, 0.14, c = P.leafLight, ol = false },
	{ "circle", 0.3, 0.6, 0.07, c = P.red, ol = false },
	{ "circle", 0.66, 0.68, 0.07, c = P.red, ol = false },
}

MapProps.rock = {
	{ "rect", 0.44, 0.66, 0.66, 0.5, r = 0.45, c = P.rock },
	{ "rect", 0.74, 0.76, 0.36, 0.28, r = 0.45, c = P.rockDark },
	{ "line", 0.28, 0.58, 0.4, 0.5, 0.05, c = P.rockLight, ol = false },
}

MapProps.hut = {
	{ "rect", 0.5, 0.74, 0.62, 0.38, r = 0.06, c = P.woodLight },
	{ "line", 0.24, 0.66, 0.76, 0.66, 0.025, c = P.woodDark, ol = false },
	{ "line", 0.24, 0.8, 0.76, 0.8, 0.025, c = P.woodDark, ol = false },
	{ "rect", 0.5, 0.79, 0.16, 0.26, r = 0.3, c = P.trunkDark },
	{ "tri", 0.5, 0.56, 0.92, dir = 0, c = P.straw },
	{ "line", 0.32, 0.47, 0.5, 0.29, 0.03, c = P.strawDark, ol = false },
	{ "line", 0.68, 0.47, 0.5, 0.29, 0.03, c = P.strawDark, ol = false },
}

MapProps.flowers = {
	{ "line", 0.35, 0.92, 0.38, 0.6, 0.05, c = P.leafDark },
	{ "line", 0.62, 0.92, 0.62, 0.52, 0.05, c = P.leafDark },
	{ "circle", 0.38, 0.56, 0.24, c = P.pink },
	{ "circle", 0.38, 0.56, 0.09, c = P.gold, ol = false },
	{ "circle", 0.63, 0.46, 0.26, c = P.red },
	{ "circle", 0.63, 0.46, 0.1, c = P.gold, ol = false },
}

MapProps.gull = {
	{ "arc", 0.34, 0.6, 0.36, 0.07, dir = 0, keep = 0.42, c = P.white },
	{ "arc", 0.66, 0.6, 0.36, 0.07, dir = 0, keep = 0.42, c = P.white },
}

MapProps.skullrock = {
	{ "rect", 0.5, 0.62, 0.94, 0.66, r = 0.42, c = P.rock },
	{ "rect", 0.5, 0.52, 0.66, 0.5, r = 0.45, c = P.bone },
	{ "rect", 0.5, 0.74, 0.4, 0.2, r = 0.3, c = P.bone },
	{ "circle", 0.38, 0.5, 0.16, c = P.line, ol = false },
	{ "circle", 0.62, 0.5, 0.16, c = P.line, ol = false },
	{ "tri", 0.5, 0.64, 0.1, dir = 0, c = P.line, ol = false },
	{ "line", 0.42, 0.74, 0.42, 0.82, 0.03, c = P.line, ol = false },
	{ "line", 0.5, 0.74, 0.5, 0.82, 0.03, c = P.line, ol = false },
	{ "line", 0.58, 0.74, 0.58, 0.82, 0.03, c = P.line, ol = false },
	{ "rect", 0.86, 0.86, 0.26, 0.2, r = 0.45, c = P.rockDark },
}

-- at sea ------------------------------------------------------------------

MapProps.ship = {
	{ "line", 0.4, 0.66, 0.4, 0.1, 0.035, c = P.trunkDark },
	{ "line", 0.66, 0.66, 0.66, 0.2, 0.035, c = P.trunkDark },
	{ "rect", 0.4, 0.32, 0.36, 0.3, r = 0.08, c = P.cream },
	{ "rect", 0.66, 0.4, 0.28, 0.24, r = 0.08, c = P.cream },
	{ "rect", 0.42, 0.06, 0.12, 0.08, r = 0.1, c = P.line, ol = false },
	{ "circle", 0.4, 0.3, 0.1, c = P.red, ol = false },
	{ "half", 0.52, 0.66, 0.84, dir = 180, c = P.wood },
	{ "rect", 0.52, 0.68, 0.84, 0.06, c = P.woodDark, ol = false },
	{ "circle", 0.36, 0.76, 0.06, c = P.line, ol = false },
	{ "circle", 0.52, 0.78, 0.06, c = P.line, ol = false },
	{ "circle", 0.68, 0.76, 0.06, c = P.line, ol = false },
	{ "arc", 0.14, 0.92, 0.24, 0.05, dir = 0, keep = 0.42, c = P.white, ol = false },
	{ "arc", 0.88, 0.92, 0.24, 0.05, dir = 0, keep = 0.42, c = P.white, ol = false },
}

MapProps.wreck = {
	{ "rect", 0.42, 0.7, 0.7, 0.3, r = 0.3, rot = -12, c = P.woodDark },
	{ "line", 0.18, 0.66, 0.66, 0.56, 0.04, c = P.wood, ol = false },
	{ "line", 0.6, 0.62, 0.74, 0.18, 0.045, c = P.trunkDark },
	{ "rect", 0.72, 0.36, 0.26, 0.2, r = 0.06, rot = 14, c = P.bone },
	{ "line", 0.66, 0.44, 0.8, 0.3, 0.03, c = P.line, ol = false },
	{ "rect", 0.84, 0.82, 0.22, 0.16, r = 0.4, c = P.rock },
	{ "arc", 0.2, 0.92, 0.28, 0.05, dir = 0, keep = 0.42, c = P.white, ol = false },
}

MapProps.barrel = {
	{ "rect", 0.5, 0.6, 0.56, 0.68, r = 0.3, c = P.wood },
	{ "rect", 0.5, 0.42, 0.6, 0.07, c = P.iron, ol = false },
	{ "rect", 0.5, 0.78, 0.6, 0.07, c = P.iron, ol = false },
	{ "line", 0.4, 0.34, 0.4, 0.86, 0.025, c = P.woodDark, ol = false },
	{ "line", 0.6, 0.34, 0.6, 0.86, 0.025, c = P.woodDark, ol = false },
}

MapProps.islet = {
	{ "rect", 0.5, 0.78, 0.9, 0.3, r = 0.5, c = P.sand },
	{ "taper", { { 0.5, 0.8 }, { 0.52, 0.55 }, { 0.58, 0.36 } }, 0.08, 0.05, c = P.trunk },
	{ "pill", 0.44, 0.33, 0.34, 0.1, rot = 22, c = P.leaf },
	{ "pill", 0.74, 0.33, 0.34, 0.1, rot = -22, c = P.leaf },
	{ "pill", 0.59, 0.24, 0.1, 0.26, c = P.leafLight },
}

-- the fortress ----------------------------------------------------------------

MapProps.crate = {
	{ "rect", 0.5, 0.6, 0.66, 0.66, r = 0.08, c = P.woodLight },
	{ "line", 0.24, 0.34, 0.76, 0.86, 0.06, c = P.wood, ol = false },
	{ "line", 0.2, 0.3, 0.8, 0.3, 0.04, c = P.woodDark, ol = false },
	{ "line", 0.2, 0.9, 0.8, 0.9, 0.04, c = P.woodDark, ol = false },
}

MapProps.torch = {
	{ "line", 0.5, 0.95, 0.5, 0.44, 0.09, c = P.trunk },
	{ "rect", 0.5, 0.44, 0.2, 0.08, r = 0.2, c = P.iron },
	{ "drop", 0.5, 0.3, 0.13, dir = 0, c = P.orange },
	{ "drop", 0.5, 0.34, 0.07, dir = 0, c = P.gold, ol = false },
}

MapProps.cannon = {
	{ "pill", 0.52, 0.5, 0.72, 0.26, rot = -14, c = P.iron },
	{ "circle", 0.86, 0.42, 0.18, c = P.iron },
	{ "circle", 0.86, 0.42, 0.08, c = P.line, ol = false },
	{ "line", 0.26, 0.56, 0.72, 0.44, 0.035, c = P.ironLight, ol = false },
	{ "circle", 0.38, 0.72, 0.34, c = P.wood },
	{ "circle", 0.38, 0.72, 0.1, c = P.woodDark, ol = false },
	{ "circle", 0.1, 0.84, 0.12, c = P.line },
	{ "circle", 0.22, 0.88, 0.12, c = P.line },
}

MapProps.gatepost = {
	{ "rect", 0.5, 0.62, 0.6, 0.66, r = 0.06, c = P.stone },
	{ "rect", 0.29, 0.26, 0.18, 0.16, r = 0.1, c = P.stone },
	{ "rect", 0.71, 0.26, 0.18, 0.16, r = 0.1, c = P.stone },
	{ "line", 0.24, 0.5, 0.76, 0.5, 0.025, c = P.stoneDark, ol = false },
	{ "line", 0.24, 0.72, 0.76, 0.72, 0.025, c = P.stoneDark, ol = false },
	{ "rect", 0.5, 0.6, 0.14, 0.2, r = 0.5, c = P.line, ol = false },
}

MapProps.keep = {
	{ "rect", 0.5, 0.62, 0.84, 0.62, r = 0.05, c = P.stone },
	{ "rect", 0.2, 0.26, 0.2, 0.18, r = 0.08, c = P.stone },
	{ "rect", 0.5, 0.26, 0.2, 0.18, r = 0.08, c = P.stone },
	{ "rect", 0.8, 0.26, 0.2, 0.18, r = 0.08, c = P.stone },
	{ "line", 0.12, 0.52, 0.88, 0.52, 0.025, c = P.stoneDark, ol = false },
	{ "line", 0.12, 0.72, 0.88, 0.72, 0.025, c = P.stoneDark, ol = false },
	{ "line", 0.5, 0.06, 0.5, -0.24, 0.03, c = P.trunkDark },
	{ "rect", 0.62, -0.17, 0.22, 0.14, r = 0.08, c = P.line },
	{ "circle", 0.6, -0.17, 0.06, c = P.bone, ol = false },
	{ "rect", 0.5, 0.8, 0.22, 0.3, r = 0.45, c = P.trunkDark },
}

MapProps.flag = {
	{ "line", 0.3, 0.96, 0.3, 0.1, 0.05, c = P.trunkDark },
	{ "rect", 0.58, 0.28, 0.54, 0.36, r = 0.06, c = P.line },
	{ "circle", 0.58, 0.25, 0.16, c = P.bone, ol = false },
	{ "line", 0.44, 0.38, 0.72, 0.18, 0.035, c = P.bone, ol = false },
	{ "line", 0.44, 0.18, 0.72, 0.38, 0.035, c = P.bone, ol = false },
	{ "circle", 0.3, 0.08, 0.08, c = P.gold },
}

-- the swamp -----------------------------------------------------------------

MapProps.mangrove = {
	{ "taper", { { 0.5, 0.86 }, { 0.5, 0.6 }, { 0.5, 0.42 } }, 0.12, 0.08, c = P.trunkDark },
	{ "taper", { { 0.5, 0.7 }, { 0.32, 0.8 }, { 0.22, 0.96 } }, 0.06, 0.04, c = P.trunkDark },
	{ "taper", { { 0.5, 0.7 }, { 0.68, 0.8 }, { 0.78, 0.96 } }, 0.06, 0.04, c = P.trunkDark },
	{ "circle", 0.3, 0.36, 0.42, c = P.mossDark },
	{ "circle", 0.7, 0.36, 0.42, c = P.mossDark },
	{ "circle", 0.5, 0.26, 0.5, c = P.swampLeaf },
	{ "circle", 0.42, 0.2, 0.16, c = P.leafLight, ol = false },
}

MapProps.reeds = {
	{ "line", 0.3, 0.95, 0.26, 0.4, 0.04, c = P.mossDark },
	{ "line", 0.5, 0.95, 0.5, 0.26, 0.04, c = P.mossDark },
	{ "line", 0.7, 0.95, 0.76, 0.44, 0.04, c = P.mossDark },
	{ "pill", 0.26, 0.42, 0.09, 0.2, c = P.trunk },
	{ "pill", 0.5, 0.28, 0.09, 0.2, c = P.trunk },
	{ "pill", 0.76, 0.46, 0.09, 0.2, c = P.trunk },
}

MapProps.mushroom = {
	{ "rect", 0.5, 0.78, 0.2, 0.32, r = 0.4, c = P.bone },
	{ "half", 0.5, 0.62, 0.72, dir = 0, c = P.red },
	{ "circle", 0.36, 0.5, 0.1, c = P.white, ol = false },
	{ "circle", 0.6, 0.44, 0.12, c = P.white, ol = false },
	{ "circle", 0.7, 0.56, 0.07, c = P.white, ol = false },
}

MapProps.log = {
	{ "pill", 0.5, 0.66, 0.92, 0.3, c = P.trunk },
	{ "circle", 0.83, 0.66, 0.28, c = P.woodLight },
	{ "ring", 0.83, 0.66, 0.16, 0.03, c = P.trunk, ol = false },
	{ "line", 0.18, 0.62, 0.6, 0.62, 0.03, c = P.trunkDark, ol = false },
	{ "circle", 0.32, 0.5, 0.12, c = P.leaf },
}

MapProps.stump = {
	{ "rect", 0.5, 0.68, 0.56, 0.44, r = 0.12, c = P.trunk },
	{ "pill", 0.5, 0.46, 0.56, 0.18, c = P.woodLight },
	{ "ring", 0.5, 0.46, 0.3, 0.03, c = P.trunk, ol = false },
	{ "line", 0.36, 0.6, 0.36, 0.84, 0.03, c = P.trunkDark, ol = false },
}

MapProps.lily = {
	{ "circle", 0.5, 0.6, 0.7, c = P.leaf },
	{ "tri", 0.5, 0.6, 0.3, dir = 30, c = "#3D6E5C", ol = false },
	{ "circle", 0.62, 0.46, 0.2, c = P.pink },
	{ "circle", 0.62, 0.46, 0.08, c = P.gold, ol = false },
}

MapProps.bubbles = {
	{ "ring", 0.36, 0.6, 0.34, 0.05, c = P.slime },
	{ "ring", 0.66, 0.42, 0.24, 0.045, c = P.slime },
	{ "ring", 0.66, 0.76, 0.16, 0.04, c = P.slime },
}

MapProps.sunken = {
	{ "rect", 0.5, 0.82, 0.86, 0.22, r = 0.45, rot = 8, c = P.woodDark },
	{ "line", 0.44, 0.82, 0.62, 0.08, 0.05, c = P.trunkDark },
	{ "line", 0.36, 0.34, 0.74, 0.44, 0.035, c = P.trunkDark },
	{ "rect", 0.56, 0.6, 0.3, 0.26, r = 0.06, rot = 10, c = P.bone },
	{ "line", 0.46, 0.52, 0.64, 0.7, 0.03, c = P.line, ol = false },
	{ "circle", 0.2, 0.86, 0.1, c = P.slime },
}

MapProps.deadtree = {
	{ "taper", { { 0.5, 0.96 }, { 0.48, 0.6 }, { 0.52, 0.3 } }, 0.14, 0.06, c = P.stoneDark },
	{ "taper", { { 0.49, 0.62 }, { 0.32, 0.44 }, { 0.2, 0.36 } }, 0.06, 0.03, c = P.stoneDark },
	{ "taper", { { 0.5, 0.48 }, { 0.68, 0.32 }, { 0.82, 0.3 } }, 0.06, 0.03, c = P.stoneDark },
	{ "taper", { { 0.52, 0.32 }, { 0.6, 0.16 }, { 0.62, 0.06 } }, 0.05, 0.025, c = P.stoneDark },
	{ "pill", 0.3, 0.98, 0.5, 0.08, c = P.mossDark },
}

-- flat on the ground ---------------------------------------------------------

-- X marks the spot: under the Treasure, its arms reaching out past the tile
MapProps.xmark = {
	{ "line", 0.12, 0.12, 0.88, 0.88, 0.13, c = P.red },
	{ "line", 0.88, 0.12, 0.12, 0.88, 0.13, c = P.red },
}

-- a wooden pier (drawn turned to the trail): planks across, posts along the sides
MapProps.dock = {
	{ "rect", 0.5, 0.5, 1, 0.42, r = 0.04, c = P.woodLight },
	{ "line", 0.2, 0.3, 0.2, 0.7, 0.025, c = P.woodDark, ol = false },
	{ "line", 0.4, 0.3, 0.4, 0.7, 0.025, c = P.woodDark, ol = false },
	{ "line", 0.6, 0.3, 0.6, 0.7, 0.025, c = P.woodDark, ol = false },
	{ "line", 0.8, 0.3, 0.8, 0.7, 0.025, c = P.woodDark, ol = false },
	{ "circle", 0.06, 0.26, 0.1, c = P.trunkDark },
	{ "circle", 0.06, 0.74, 0.1, c = P.trunkDark },
	{ "circle", 0.5, 0.26, 0.1, c = P.trunkDark },
	{ "circle", 0.5, 0.74, 0.1, c = P.trunkDark },
}

return MapProps
