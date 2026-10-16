--[[
	AccessoryArt
	What characters wear: the pieces of every accessory pack, drawn on the character's
	own sticker canvas (StickerArt.mascot), in the same sticker style (ink outline, flat
	pirate inks). Pure data; CosmeticArt.accessory draws and animates it.

	Where things are on a character (canvas 0..1): the body is a round blob from y 0.31
	to 0.93 (x 0.19 to 0.81), the eyes sit at y 0.56 (x 0.395 and 0.605; the Overseer has
	one big eye at x 0.5), the mouth at y 0.72, the nubby arms at (0.19, 0.68) and
	(0.81, 0.68).

	piece = {
		ops,             -- sticker ops
		two / one,       -- or: ops for two-eyed characters / the one-eyed Overseer
		back = true,     -- drawn behind the character (a cape)
		hat = true,      -- sits on the head: the character's own headgear comes off
		anim = { { kind, pivot = { x, y }, ops, time, amount, delay } },
	}
	anim kinds: spin (turns round its pivot), wiggle (rocks by `amount` degrees), bob
	(floats up and down by `amount`), rise (floats up by `amount` and pops), fall
	(drops by `amount`), flicker and glint (pulses in size), orbit (circles the pivot,
	staying upright).
]]

local P = {
	line = "#1C1A24",
	white = "#FFFFFF",
	cream = "#FFF8E7",
	red = "#D7263D",
	redDark = "#9E1B2C",
	gold = "#F5B700",
	goldDark = "#C98F00",
	navy = "#2B4C7E",
	navyDark = "#1C3459",
	ink = "#2A2836",
	brown = "#6E4520",
	wood = "#B87333",
	steel = "#B8BDC7",
	glass = "#BFE6F2",
	sea = "#2E8FB3",
	green = "#4FA548",
	greenDark = "#357A30",
	orange = "#F08A24",
	pink = "#D94C9C",
	coral = "#E0603A",
	coralDark = "#B04424",
	cloud = "#C9D1DB",
	cloudDark = "#8E99A8",
	bone = "#F3E6C8",
}

local AccessoryArt = {}
AccessoryArt.palette = P

local pieces = {}
AccessoryArt.pieces = pieces

-- face ------------------------------------------------------------------------

pieces.monocle = {
	two = {
		{ "ring", 0.605, 0.56, 0.25, 0.035, c = P.gold },
		{ "line", 0.7, 0.63, 0.76, 0.84, 0.018, c = P.gold, ol = false },
	},
	one = {
		{ "ring", 0.5, 0.56, 0.37, 0.04, c = P.gold },
		{ "line", 0.66, 0.66, 0.72, 0.86, 0.02, c = P.gold, ol = false },
	},
}

pieces.moustache = {
	two = {
		{ "pill", 0.44, 0.665, 0.15, 0.065, rot = 14, c = P.brown },
		{ "pill", 0.56, 0.665, 0.15, 0.065, rot = -14, c = P.brown },
		{ "circle", 0.365, 0.645, 0.05, c = P.brown },
		{ "circle", 0.635, 0.645, 0.05, c = P.brown },
	},
	one = {
		{ "pill", 0.44, 0.735, 0.15, 0.06, rot = 14, c = P.brown },
		{ "pill", 0.56, 0.735, 0.15, 0.06, rot = -14, c = P.brown },
		{ "circle", 0.365, 0.715, 0.05, c = P.brown },
		{ "circle", 0.635, 0.715, 0.05, c = P.brown },
	},
}

pieces.beard = {
	two = {
		{ "half", 0.5, 0.74, 0.44, dir = 180, c = P.white },
		{ "pill", 0.44, 0.67, 0.14, 0.06, rot = 12, c = P.white },
		{ "pill", 0.56, 0.67, 0.14, 0.06, rot = -12, c = P.white },
		{ "circle", 0.5, 0.75, 0.08, c = P.line, ol = false },
	},
	one = {
		{ "half", 0.5, 0.79, 0.42, dir = 180, c = P.white },
		{ "circle", 0.5, 0.8, 0.07, c = P.line, ol = false },
	},
}

-- the patch over one eye (the Overseer, who only has one, wears it flipped up)
pieces.eyepatch = {
	two = {
		{ "line", 0.22, 0.47, 0.8, 0.43, 0.025, c = P.line, ol = false },
		{ "rect", 0.395, 0.565, 0.2, 0.17, r = 0.45, c = P.ink },
		{ "circle", 0.395, 0.565, 0.05, c = P.bone, ol = false },
	},
	one = {
		{ "line", 0.22, 0.4, 0.8, 0.4, 0.025, c = P.line, ol = false },
		{ "rect", 0.5, 0.37, 0.18, 0.1, r = 0.45, c = P.ink },
	},
}

pieces.shades = {
	two = {
		{ "line", 0.47, 0.545, 0.53, 0.545, 0.025, c = P.line },
		{ "rect", 0.39, 0.56, 0.2, 0.14, r = 0.35, c = P.ink },
		{ "rect", 0.61, 0.56, 0.2, 0.14, r = 0.35, c = P.ink },
		{ "line", 0.34, 0.53, 0.38, 0.51, 0.02, c = P.white, ol = false },
		{ "line", 0.56, 0.53, 0.6, 0.51, 0.02, c = P.white, ol = false },
	},
	one = {
		{ "rect", 0.5, 0.56, 0.44, 0.16, r = 0.45, c = P.ink },
		{ "line", 0.38, 0.53, 0.44, 0.51, 0.02, c = P.white, ol = false },
	},
}

-- a diving mask and its snorkel
pieces.mask = {
	ops = {
		{ "line", 0.19, 0.56, 0.81, 0.56, 0.035, c = P.ink },
		{ "pill", 0.82, 0.4, 0.06, 0.36, c = P.orange },
		{ "pill", 0.78, 0.6, 0.1, 0.06, c = P.orange },
		{ "rect", 0.5, 0.56, 0.5, 0.25, r = 0.4, c = P.gold },
		{ "rect", 0.5, 0.56, 0.42, 0.18, r = 0.4, c = P.glass, t = 0.45, ol = false },
		{ "line", 0.34, 0.52, 0.4, 0.49, 0.02, c = P.white, ol = false },
	},
}

-- hats --------------------------------------------------------------------------

pieces.bandana = {
	hat = true,
	ops = {
		{ "tri", 0.8, 0.4, 0.14, dir = 60, c = P.red },
		{ "tri", 0.8, 0.42, 0.14, dir = 120, c = P.red },
		{ "half", 0.5, 0.45, 0.6, dir = 0, c = P.red },
		{ "circle", 0.38, 0.33, 0.06, c = P.white, ol = false },
		{ "circle", 0.56, 0.24, 0.06, c = P.white, ol = false },
		{ "circle", 0.64, 0.38, 0.05, c = P.white, ol = false },
		{ "circle", 0.46, 0.4, 0.05, c = P.white, ol = false },
	},
}

pieces.tricorn = {
	hat = true,
	ops = {
		{ "half", 0.5, 0.36, 0.44, dir = 0, c = P.ink },
		{ "pill", 0.5, 0.37, 0.84, 0.15, c = P.ink },
		{ "tri", 0.14, 0.33, 0.16, dir = -50, c = P.ink },
		{ "tri", 0.86, 0.33, 0.16, dir = 50, c = P.ink },
		{ "line", 0.16, 0.37, 0.84, 0.37, 0.025, c = P.gold, ol = false },
		{ "circle", 0.5, 0.25, 0.11, c = P.bone, ol = false },
		{ "rect", 0.5, 0.3, 0.06, 0.04, c = P.bone, ol = false },
		{ "circle", 0.475, 0.245, 0.03, c = P.line, ol = false },
		{ "circle", 0.525, 0.245, 0.03, c = P.line, ol = false },
	},
}

pieces.admiral = {
	hat = true,
	ops = {
		{ "half", 0.5, 0.37, 0.7, dir = 0, c = P.navy },
		{ "pill", 0.5, 0.37, 0.86, 0.12, c = P.navyDark },
		{ "line", 0.18, 0.36, 0.82, 0.36, 0.03, c = P.gold, ol = false },
		{ "star", 0.5, 0.2, 0.13, c = P.gold },
		{ "circle", 0.16, 0.37, 0.07, c = P.gold },
		{ "circle", 0.84, 0.37, 0.07, c = P.gold },
	},
}

pieces.chefhat = {
	hat = true,
	ops = {
		{ "circle", 0.36, 0.18, 0.24, c = P.white },
		{ "circle", 0.64, 0.18, 0.24, c = P.white },
		{ "circle", 0.5, 0.1, 0.28, c = P.white },
		{ "rect", 0.5, 0.33, 0.44, 0.14, r = 0.2, c = P.white },
		{ "line", 0.32, 0.29, 0.68, 0.29, 0.02, c = P.cloud, ol = false },
	},
}

pieces.sailorcap = {
	hat = true,
	ops = {
		{ "half", 0.5, 0.38, 0.46, dir = 0, c = P.white },
		{ "pill", 0.5, 0.38, 0.66, 0.1, c = P.white },
		{ "rect", 0.5, 0.33, 0.44, 0.06, r = 0.3, c = P.navy, ol = false },
		{ "circle", 0.5, 0.15, 0.08, c = P.red },
	},
}

-- a droopy night cap with a bobble
pieces.nightcap = {
	hat = true,
	ops = {
		{ "taper", { { 0.5, 0.34 }, { 0.62, 0.16 }, { 0.84, 0.18 } }, 0.42, 0.06, c = P.navy },
		{ "pill", 0.5, 0.37, 0.62, 0.11, c = P.cream },
		{ "circle", 0.86, 0.22, 0.12, c = P.cream },
		{ "line", 0.46, 0.26, 0.56, 0.2, 0.02, c = P.gold, ol = false },
	},
}

pieces.crown = {
	hat = true,
	ops = {
		{ "rect", 0.5, 0.34, 0.5, 0.11, r = 0.15, c = P.gold },
		{ "tri", 0.31, 0.3, 0.16, dir = 0, c = P.gold },
		{ "tri", 0.5, 0.29, 0.2, dir = 0, c = P.gold },
		{ "tri", 0.69, 0.3, 0.16, dir = 0, c = P.gold },
		{ "circle", 0.5, 0.34, 0.07, c = P.red, ol = false },
		{ "circle", 0.36, 0.34, 0.045, c = P.sea, ol = false },
		{ "circle", 0.64, 0.34, 0.045, c = P.sea, ol = false },
	},
}

pieces.crownGlint = {
	hat = true,
	ops = pieces.crown.ops,
	anim = {
		{ kind = "glint", pivot = { 0.62, 0.2 }, time = 0.7, ops = { { "sparkle", 0.62, 0.2, 0.12, c = P.white } } },
	},
}

-- a striped beanie with a propeller on top
pieces.propeller = {
	hat = true,
	ops = {
		{ "half", 0.5, 0.42, 0.56, dir = 0, c = P.red },
		{ "half", 0.5, 0.42, 0.32, dir = 0, c = P.gold, ol = false },
		{ "half", 0.5, 0.42, 0.12, dir = 0, c = P.red, ol = false },
		{ "pill", 0.5, 0.42, 0.6, 0.06, c = P.navy },
		{ "line", 0.5, 0.14, 0.5, 0.06, 0.03, c = P.ink },
	},
	anim = {
		{
			kind = "spin",
			pivot = { 0.5, 0.06 },
			time = 0.35,
			ops = {
				{ "pill", 0.4, 0.06, 0.2, 0.055, c = P.sea },
				{ "pill", 0.6, 0.06, 0.2, 0.055, c = P.gold },
				{ "circle", 0.5, 0.06, 0.05, c = P.red },
			},
		},
	},
}

-- an octopus sitting on your head, waving
pieces.kraken = {
	hat = true,
	ops = {
		{ "half", 0.5, 0.33, 0.44, dir = 0, c = P.coral },
		{ "circle", 0.5, 0.24, 0.36, c = P.coral },
		{ "circle", 0.42, 0.24, 0.05, c = P.coralDark, ol = false },
		{ "circle", 0.6, 0.18, 0.04, c = P.coralDark, ol = false },
		{ "eyes", 0.5, 0.29, 0.13, 0.09, mood = "happy" },
	},
	anim = {
		{
			kind = "wiggle",
			pivot = { 0.32, 0.34 },
			time = 0.6,
			amount = 14,
			ops = { { "taper", { { 0.32, 0.34 }, { 0.2, 0.44 }, { 0.14, 0.4 } }, 0.08, 0.035, c = P.coral } },
		},
		{
			kind = "wiggle",
			pivot = { 0.68, 0.34 },
			time = 0.6,
			amount = -14,
			delay = 0.3,
			ops = { { "taper", { { 0.68, 0.34 }, { 0.8, 0.44 }, { 0.86, 0.4 } }, 0.08, 0.035, c = P.coral } },
		},
	},
}

-- a little cannon on your head that puffs smoke rings
pieces.cannon = {
	hat = true,
	ops = {
		{ "pill", 0.58, 0.2, 0.44, 0.15, rot = -35, c = P.ink },
		{ "circle", 0.75, 0.08, 0.1, c = P.ink },
		{ "circle", 0.42, 0.33, 0.2, c = P.wood },
		{ "circle", 0.42, 0.33, 0.07, c = P.brown, ol = false },
		{ "pill", 0.5, 0.36, 0.42, 0.08, c = P.brown },
	},
	anim = {
		{ kind = "rise", pivot = { 0.8, 0.0 }, time = 1.4, amount = 0.25, ops = { { "ring", 0.8, 0.0, 0.14, 0.035, c = P.cloud } } },
		{ kind = "rise", pivot = { 0.84, -0.02 }, time = 1.4, amount = 0.25, delay = 0.7, ops = { { "ring", 0.84, -0.02, 0.1, 0.03, c = P.cloud } } },
	},
}

-- around the neck -------------------------------------------------------------------

pieces.bowtie = {
	ops = {
		{ "tri", 0.44, 0.86, 0.16, dir = -90, c = P.red },
		{ "tri", 0.56, 0.86, 0.16, dir = 90, c = P.red },
		{ "circle", 0.5, 0.86, 0.07, c = P.redDark },
	},
}

pieces.neckerchief = {
	ops = {
		{ "tri", 0.5, 0.81, 0.34, dir = 180, c = P.red },
		{ "circle", 0.5, 0.81, 0.07, c = P.redDark },
		{ "circle", 0.44, 0.87, 0.03, c = P.white, ol = false },
		{ "circle", 0.55, 0.89, 0.03, c = P.white, ol = false },
	},
}

pieces.lei = {
	ops = {
		{ "circle", 0.3, 0.82, 0.1, c = P.pink },
		{ "circle", 0.4, 0.86, 0.1, c = P.gold },
		{ "circle", 0.5, 0.875, 0.1, c = P.pink },
		{ "circle", 0.6, 0.86, 0.1, c = P.gold },
		{ "circle", 0.7, 0.82, 0.1, c = P.pink },
	},
}

pieces.pearls = {
	ops = {
		{ "circle", 0.32, 0.8, 0.065, c = P.white },
		{ "circle", 0.39, 0.835, 0.065, c = P.white },
		{ "circle", 0.46, 0.855, 0.065, c = P.white },
		{ "circle", 0.54, 0.855, 0.065, c = P.white },
		{ "circle", 0.61, 0.835, 0.065, c = P.white },
		{ "circle", 0.68, 0.8, 0.065, c = P.white },
		{ "circle", 0.5, 0.9, 0.09, c = P.pink },
	},
}

pieces.goldchain = {
	ops = {
		{ "arc", 0.5, 0.74, 0.4, 0.035, dir = 180, keep = 0.5, c = P.gold },
		{ "circle", 0.5, 0.94, 0.12, c = P.gold },
		{ "text", 0.5, 0.94, 0.1, 0.1, "$", c = P.goldDark, ol = false },
	},
}

-- a red and white life ring round the middle
pieces.lifebuoy = {
	ops = {
		{ "ring", 0.5, 0.84, 0.72, 0.12, c = P.white },
		{ "rect", 0.17, 0.84, 0.08, 0.13, c = P.red, ol = false },
		{ "rect", 0.83, 0.84, 0.08, 0.13, c = P.red, ol = false },
	},
}

pieces.cape = {
	back = true,
	ops = {
		{ "rect", 0.5, 0.68, 0.84, 0.56, r = 0.12, c = P.red },
		{ "rect", 0.5, 0.94, 0.84, 0.06, r = 0.3, c = P.gold },
		{ "circle", 0.2, 0.42, 0.1, c = P.gold },
		{ "circle", 0.8, 0.42, 0.1, c = P.gold },
	},
}

-- in hand ---------------------------------------------------------------------------

pieces.hook = {
	ops = {
		{ "rect", 0.86, 0.72, 0.1, 0.08, r = 0.2, rot = -25, c = P.brown },
		{ "arc", 0.93, 0.8, 0.14, 0.035, dir = 135, keep = 0.62, c = P.steel },
	},
}

pieces.spyglass = {
	ops = {
		{ "pill", 0.88, 0.55, 0.32, 0.09, rot = -55, c = P.gold },
		{ "pill", 0.95, 0.43, 0.14, 0.11, rot = -55, c = P.goldDark },
		{ "line", 0.84, 0.62, 0.9, 0.53, 0.02, c = P.brown, ol = false },
	},
}

pieces.umbrella = {
	ops = {
		{ "line", 0.86, 0.72, 0.86, 0.3, 0.025, c = P.ink },
		{ "half", 0.86, 0.3, 0.42, dir = 0, c = P.sea },
		{ "half", 0.86, 0.3, 0.14, dir = 0, c = P.gold, ol = false },
		{ "arc", 0.82, 0.74, 0.08, 0.02, dir = 180, keep = 0.5, c = P.ink, ol = false },
	},
}

pieces.lantern = {
	ops = {
		{ "line", 0.86, 0.72, 0.9, 0.78, 0.02, c = P.ink },
		{ "rect", 0.92, 0.88, 0.14, 0.16, r = 0.2, c = P.gold },
		{ "rect", 0.92, 0.88, 0.08, 0.1, r = 0.3, c = P.cream, ol = false },
		{ "rect", 0.92, 0.79, 0.1, 0.03, r = 0.3, c = P.ink, ol = false },
	},
	anim = {
		{ kind = "flicker", pivot = { 0.92, 0.88 }, time = 0.25, ops = { { "drop", 0.92, 0.89, 0.03, c = P.orange, ol = false } } },
	},
}

-- a pipe at the corner of your mouth, blowing bubbles
pieces.pipe = {
	two = {
		{ "line", 0.56, 0.74, 0.72, 0.76, 0.03, c = P.brown },
		{ "rect", 0.75, 0.71, 0.08, 0.1, r = 0.25, c = P.wood },
	},
	one = {
		{ "line", 0.56, 0.79, 0.72, 0.8, 0.03, c = P.brown },
		{ "rect", 0.75, 0.76, 0.08, 0.1, r = 0.25, c = P.wood },
	},
	anim = {
		{ kind = "rise", pivot = { 0.76, 0.6 }, time = 1.2, amount = 0.3, ops = { { "ring", 0.76, 0.6, 0.09, 0.02, c = P.sea } } },
		{ kind = "rise", pivot = { 0.8, 0.6 }, time = 1.2, amount = 0.3, delay = 0.4, ops = { { "ring", 0.8, 0.6, 0.06, 0.018, c = P.sea } } },
		{ kind = "rise", pivot = { 0.73, 0.6 }, time = 1.2, amount = 0.3, delay = 0.8, ops = { { "ring", 0.73, 0.6, 0.07, 0.018, c = P.sea } } },
	},
}

-- buddies -------------------------------------------------------------------------

pieces.parrot = {
	ops = {
		{ "pill", 0.9, 0.42, 0.08, 0.2, rot = 20, c = P.sea },
		{ "rect", 0.82, 0.32, 0.16, 0.2, r = 0.45, c = P.red },
		{ "circle", 0.8, 0.22, 0.14, c = P.red },
		{ "tri", 0.74, 0.24, 0.07, dir = -90, c = P.gold },
		{ "eye", 0.8, 0.21, 0.05 },
		{ "pill", 0.86, 0.33, 0.06, 0.12, rot = 15, c = P.gold, ol = false },
	},
}

pieces.ghost = {
	anim = {
		{
			kind = "bob",
			pivot = { 0.94, 0.28 },
			time = 0.9,
			amount = 0.05,
			ops = {
				{ "rect", 0.94, 0.3, 0.18, 0.22, r = 0.45, c = P.white },
				{ "circle", 0.88, 0.41, 0.06, c = P.white },
				{ "circle", 0.94, 0.42, 0.06, c = P.white },
				{ "circle", 1.0, 0.41, 0.06, c = P.white },
				{ "eyes", 0.94, 0.28, 0.07, 0.05 },
				{ "mouth", 0.94, 0.34, 0.04, mood = "o" },
			},
		},
	},
}

-- a little grey cloud raining on you
pieces.raincloud = {
	ops = {
		{ "circle", 0.38, 0.06, 0.18, c = P.cloud },
		{ "circle", 0.62, 0.06, 0.18, c = P.cloud },
		{ "circle", 0.5, 0.0, 0.22, c = P.cloud },
		{ "rect", 0.5, 0.1, 0.38, 0.1, r = 0.45, c = P.cloud },
	},
	anim = {
		{ kind = "fall", pivot = { 0.4, 0.17 }, time = 0.6, amount = 0.12, ops = { { "drop", 0.4, 0.17, 0.02, dir = 0, c = P.sea } } },
		{ kind = "fall", pivot = { 0.5, 0.17 }, time = 0.6, amount = 0.12, delay = 0.2, ops = { { "drop", 0.5, 0.17, 0.02, dir = 0, c = P.sea } } },
		{ kind = "fall", pivot = { 0.6, 0.17 }, time = 0.6, amount = 0.12, delay = 0.4, ops = { { "drop", 0.6, 0.17, 0.02, dir = 0, c = P.sea } } },
	},
}

-- two gulls circling over your head
pieces.gulls = {
	anim = {
		{
			kind = "orbit",
			pivot = { 0.5, 0.06 },
			time = 3,
			amount = 0.24,
			ops = {
				{ "arc", 0.46, 0.08, 0.1, 0.03, dir = 0, keep = 0.42, c = P.white },
				{ "arc", 0.54, 0.08, 0.1, 0.03, dir = 0, keep = 0.42, c = P.white },
			},
		},
		{
			kind = "orbit",
			pivot = { 0.5, 0.06 },
			time = 3,
			amount = 0.24,
			delay = 1.5,
			ops = {
				{ "arc", 0.46, 0.08, 0.1, 0.03, dir = 0, keep = 0.42, c = P.white },
				{ "arc", 0.54, 0.08, 0.1, 0.03, dir = 0, keep = 0.42, c = P.white },
			},
		},
	},
}

---------------------------------------------------------------------------
-- the packs (Shared/Meta/Cosmetics lists them by id; `look.pieces` names these)
---------------------------------------------------------------------------

-- Whether a pack sits on the head (so the character's own headgear comes off).
function AccessoryArt.wearsHat(pieceNames: { string }?): boolean
	for _, name in pieceNames or {} do
		local piece = pieces[name]
		if piece and piece.hat then
			return true
		end
	end
	return false
end

return AccessoryArt
