--[[
	AccessoryArt
	What characters wear: the pieces of every accessory pack, drawn on the character's
	own sticker canvas (StickerArt.mascot), in the same sticker style (ink outline, flat
	pirate inks). Pure data; CosmeticArt.accessory draws and animates it.

	Where things are on a character (canvas 0..1, see StickerArt's crew): the head is
	centred on (0.5, 0.38), 0.34 across, with the eyes at y 0.36 (x 0.425 and 0.575), the
	nose at (0.52, 0.42) and the mouth at y 0.49; hats sit on y 0.25; the collar is at
	y 0.57; the hands are at (0.25, 0.84) (holding the character's own thing) and
	(0.75, 0.84) (free for accessories); the feet at y 0.93.

	piece = {
		ops,             -- sticker ops
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
	ops = {
		{ "ring", 0.575, 0.36, 0.13, 0.022, c = P.gold },
		{ "line", 0.635, 0.39, 0.66, 0.58, 0.012, c = P.gold, ol = false },
	},
}

pieces.moustache = {
	ops = {
		{ "pill", 0.45, 0.47, 0.12, 0.05, rot = 12, c = P.brown },
		{ "pill", 0.55, 0.47, 0.12, 0.05, rot = -12, c = P.brown },
		{ "circle", 0.39, 0.455, 0.04, c = P.brown },
		{ "circle", 0.61, 0.455, 0.04, c = P.brown },
	},
}

pieces.beard = {
	ops = {
		{ "half", 0.5, 0.48, 0.32, dir = 180, c = P.white },
		{ "pill", 0.45, 0.47, 0.12, 0.05, rot = 10, c = P.white },
		{ "pill", 0.55, 0.47, 0.12, 0.05, rot = -10, c = P.white },
		{ "circle", 0.5, 0.5, 0.05, c = P.line, ol = false },
	},
}

-- the patch over one eye
pieces.eyepatch = {
	ops = {
		{ "line", 0.33, 0.3, 0.67, 0.43, 0.015, c = P.line, ol = false },
		{ "rect", 0.425, 0.365, 0.1, 0.085, r = 0.45, c = P.ink },
	},
}

pieces.shades = {
	ops = {
		{ "line", 0.47, 0.355, 0.53, 0.355, 0.015, c = P.line },
		{ "rect", 0.425, 0.365, 0.11, 0.075, r = 0.35, c = P.ink },
		{ "rect", 0.575, 0.365, 0.11, 0.075, r = 0.35, c = P.ink },
		{ "line", 0.4, 0.35, 0.42, 0.34, 0.012, c = P.white, ol = false },
	},
}

-- a diving mask and its snorkel
pieces.mask = {
	ops = {
		{ "line", 0.33, 0.36, 0.67, 0.36, 0.02, c = P.ink },
		{ "pill", 0.69, 0.3, 0.035, 0.2, c = P.orange },
		{ "pill", 0.63, 0.47, 0.08, 0.035, c = P.orange },
		{ "rect", 0.5, 0.36, 0.3, 0.13, r = 0.4, c = P.gold },
		{ "rect", 0.5, 0.36, 0.25, 0.09, r = 0.4, c = P.glass, t = 0.45, ol = false },
	},
}

-- hats --------------------------------------------------------------------------

pieces.bandana = {
	hat = true,
	ops = {
		{ "tri", 0.7, 0.27, 0.1, dir = 70, c = P.red },
		{ "tri", 0.7, 0.29, 0.1, dir = 120, c = P.red },
		{ "half", 0.5, 0.29, 0.37, dir = 0, c = P.red },
		{ "circle", 0.41, 0.25, 0.045, c = P.white, ol = false },
		{ "circle", 0.55, 0.2, 0.045, c = P.white, ol = false },
		{ "circle", 0.6, 0.27, 0.04, c = P.white, ol = false },
	},
}

pieces.tricorn = {
	hat = true,
	ops = {
		{ "half", 0.5, 0.245, 0.34, dir = 0, c = P.ink },
		{ "pill", 0.5, 0.245, 0.62, 0.1, c = P.ink },
		{ "tri", 0.22, 0.22, 0.12, dir = -50, c = P.ink },
		{ "tri", 0.78, 0.22, 0.12, dir = 50, c = P.ink },
		{ "circle", 0.5, 0.17, 0.08, c = P.bone, ol = false },
		{ "circle", 0.48, 0.165, 0.02, c = P.line, ol = false },
		{ "circle", 0.52, 0.165, 0.02, c = P.line, ol = false },
	},
}

pieces.admiral = {
	hat = true,
	ops = {
		{ "half", 0.5, 0.255, 0.52, dir = 0, c = P.navy },
		{ "pill", 0.5, 0.255, 0.64, 0.08, c = P.navyDark },
		{ "line", 0.2, 0.25, 0.8, 0.25, 0.02, c = P.gold, ol = false },
		{ "star", 0.5, 0.14, 0.09, c = P.gold },
		{ "circle", 0.19, 0.255, 0.05, c = P.gold },
		{ "circle", 0.81, 0.255, 0.05, c = P.gold },
	},
}

pieces.chefhat = {
	hat = true,
	ops = {
		{ "circle", 0.4, 0.12, 0.18, c = P.white },
		{ "circle", 0.6, 0.12, 0.18, c = P.white },
		{ "circle", 0.5, 0.06, 0.2, c = P.white },
		{ "rect", 0.5, 0.23, 0.32, 0.1, r = 0.2, c = P.white },
		{ "line", 0.36, 0.2, 0.64, 0.2, 0.012, c = P.cloud, ol = false },
	},
}

pieces.sailorcap = {
	hat = true,
	ops = {
		{ "half", 0.5, 0.265, 0.34, dir = 0, c = P.white },
		{ "pill", 0.5, 0.265, 0.46, 0.06, c = P.white },
		{ "rect", 0.5, 0.235, 0.32, 0.04, r = 0.3, c = P.navy, ol = false },
		{ "circle", 0.5, 0.1, 0.06, c = P.red },
	},
}

-- a droopy night cap with a bobble
pieces.nightcap = {
	hat = true,
	ops = {
		{ "taper", { { 0.5, 0.25 }, { 0.6, 0.11 }, { 0.78, 0.12 } }, 0.32, 0.05, c = P.navy },
		{ "pill", 0.5, 0.265, 0.42, 0.07, c = P.cream },
		{ "circle", 0.8, 0.15, 0.09, c = P.cream },
		{ "line", 0.47, 0.2, 0.55, 0.15, 0.015, c = P.gold, ol = false },
	},
}

pieces.crown = {
	hat = true,
	ops = {
		{ "rect", 0.5, 0.25, 0.34, 0.08, r = 0.15, c = P.gold },
		{ "tri", 0.37, 0.22, 0.11, dir = 0, c = P.gold },
		{ "tri", 0.5, 0.21, 0.14, dir = 0, c = P.gold },
		{ "tri", 0.63, 0.22, 0.11, dir = 0, c = P.gold },
		{ "circle", 0.5, 0.25, 0.05, c = P.red, ol = false },
		{ "circle", 0.4, 0.25, 0.035, c = P.sea, ol = false },
		{ "circle", 0.6, 0.25, 0.035, c = P.sea, ol = false },
	},
}

pieces.crownGlint = {
	hat = true,
	ops = pieces.crown.ops,
	anim = {
		{ kind = "glint", pivot = { 0.6, 0.13 }, time = 0.7, ops = { { "star", 0.6, 0.13, 0.07, c = P.white } } },
	},
}

-- a striped beanie with a propeller on top
pieces.propeller = {
	hat = true,
	ops = {
		{ "half", 0.5, 0.285, 0.38, dir = 0, c = P.red },
		{ "half", 0.5, 0.285, 0.22, dir = 0, c = P.gold, ol = false },
		{ "half", 0.5, 0.285, 0.08, dir = 0, c = P.red, ol = false },
		{ "pill", 0.5, 0.285, 0.42, 0.05, c = P.navy },
		{ "line", 0.5, 0.12, 0.5, 0.06, 0.02, c = P.ink },
	},
	anim = {
		{
			kind = "spin",
			pivot = { 0.5, 0.06 },
			time = 0.35,
			ops = {
				{ "pill", 0.43, 0.06, 0.15, 0.04, c = P.sea },
				{ "pill", 0.57, 0.06, 0.15, 0.04, c = P.gold },
				{ "circle", 0.5, 0.06, 0.035, c = P.red },
			},
		},
	},
}

-- an octopus sitting on your head, waving
pieces.kraken = {
	hat = true,
	ops = {
		{ "half", 0.5, 0.27, 0.34, dir = 0, c = P.coral },
		{ "circle", 0.5, 0.18, 0.26, c = P.coral },
		{ "circle", 0.44, 0.16, 0.035, c = P.coralDark, ol = false },
		{ "circle", 0.58, 0.12, 0.03, c = P.coralDark, ol = false },
		{ "dots", 0.5, 0.22, 0.08, 0.03, mood = "happy" },
	},
	anim = {
		{
			kind = "wiggle",
			pivot = { 0.36, 0.27 },
			time = 0.6,
			amount = 14,
			ops = { { "taper", { { 0.36, 0.27 }, { 0.26, 0.35 }, { 0.22, 0.31 } }, 0.06, 0.025, c = P.coral } },
		},
		{
			kind = "wiggle",
			pivot = { 0.64, 0.27 },
			time = 0.6,
			amount = -14,
			delay = 0.3,
			ops = { { "taper", { { 0.64, 0.27 }, { 0.74, 0.35 }, { 0.78, 0.31 } }, 0.06, 0.025, c = P.coral } },
		},
	},
}

-- a little cannon on your head that puffs smoke rings
pieces.cannon = {
	hat = true,
	ops = {
		{ "pill", 0.57, 0.15, 0.32, 0.11, rot = -35, c = P.ink },
		{ "circle", 0.69, 0.06, 0.08, c = P.ink },
		{ "circle", 0.45, 0.24, 0.15, c = P.wood },
		{ "circle", 0.45, 0.24, 0.05, c = P.brown, ol = false },
		{ "pill", 0.5, 0.27, 0.34, 0.06, c = P.brown },
	},
	anim = {
		{ kind = "rise", pivot = { 0.74, -0.02 }, time = 1.4, amount = 0.22, ops = { { "ring", 0.74, -0.02, 0.11, 0.028, c = P.cloud } } },
		{ kind = "rise", pivot = { 0.77, -0.04 }, time = 1.4, amount = 0.22, delay = 0.7, ops = { { "ring", 0.77, -0.04, 0.08, 0.024, c = P.cloud } } },
	},
}

-- around the neck -------------------------------------------------------------------

pieces.bowtie = {
	ops = {
		{ "tri", 0.455, 0.585, 0.11, dir = -90, c = P.red },
		{ "tri", 0.545, 0.585, 0.11, dir = 90, c = P.red },
		{ "circle", 0.5, 0.585, 0.05, c = P.redDark },
	},
}

pieces.neckerchief = {
	ops = {
		{ "tri", 0.5, 0.57, 0.24, dir = 180, c = P.red },
		{ "circle", 0.5, 0.57, 0.05, c = P.redDark },
		{ "circle", 0.46, 0.61, 0.02, c = P.white, ol = false },
		{ "circle", 0.53, 0.62, 0.02, c = P.white, ol = false },
	},
}

pieces.lei = {
	ops = {
		{ "circle", 0.35, 0.57, 0.07, c = P.pink },
		{ "circle", 0.42, 0.6, 0.07, c = P.gold },
		{ "circle", 0.5, 0.61, 0.07, c = P.pink },
		{ "circle", 0.58, 0.6, 0.07, c = P.gold },
		{ "circle", 0.65, 0.57, 0.07, c = P.pink },
	},
}

pieces.pearls = {
	ops = {
		{ "circle", 0.37, 0.57, 0.045, c = P.white },
		{ "circle", 0.42, 0.595, 0.045, c = P.white },
		{ "circle", 0.475, 0.61, 0.045, c = P.white },
		{ "circle", 0.525, 0.61, 0.045, c = P.white },
		{ "circle", 0.58, 0.595, 0.045, c = P.white },
		{ "circle", 0.63, 0.57, 0.045, c = P.white },
		{ "circle", 0.5, 0.645, 0.06, c = P.pink },
	},
}

pieces.goldchain = {
	ops = {
		{ "arc", 0.5, 0.5, 0.28, 0.022, dir = 180, keep = 0.5, c = P.gold },
		{ "circle", 0.5, 0.66, 0.09, c = P.gold },
		{ "circle", 0.5, 0.66, 0.04, c = P.goldDark, ol = false },
	},
}

-- a red and white life ring round the middle
pieces.lifebuoy = {
	ops = {
		{ "ring", 0.5, 0.78, 0.54, 0.09, c = P.white },
		{ "rect", 0.25, 0.78, 0.06, 0.1, c = P.red, ol = false },
		{ "rect", 0.75, 0.78, 0.06, 0.1, c = P.red, ol = false },
	},
}

pieces.cape = {
	back = true,
	ops = {
		{ "rect", 0.5, 0.73, 0.6, 0.42, r = 0.12, c = P.red },
		{ "rect", 0.5, 0.93, 0.6, 0.05, r = 0.3, c = P.gold },
		{ "circle", 0.35, 0.57, 0.07, c = P.gold },
		{ "circle", 0.65, 0.57, 0.07, c = P.gold },
	},
}

-- in the free (right) hand ---------------------------------------------------------

pieces.hook = {
	ops = {
		{ "rect", 0.75, 0.84, 0.1, 0.08, r = 0.2, c = P.brown },
		{ "arc", 0.78, 0.93, 0.12, 0.03, dir = 135, keep = 0.62, c = P.steel },
	},
}

pieces.spyglass = {
	ops = {
		{ "pill", 0.82, 0.72, 0.07, 0.26, rot = -25, c = P.gold },
		{ "pill", 0.86, 0.6, 0.09, 0.08, rot = -25, c = P.goldDark },
		{ "circle", 0.75, 0.84, 0.1, c = "#E0B48A" },
	},
}

pieces.umbrella = {
	ops = {
		{ "line", 0.78, 0.86, 0.78, 0.36, 0.022, c = P.ink },
		{ "half", 0.78, 0.36, 0.36, dir = 0, c = P.sea },
		{ "half", 0.78, 0.36, 0.12, dir = 0, c = P.gold, ol = false },
	},
}

pieces.lantern = {
	ops = {
		{ "line", 0.76, 0.86, 0.8, 0.9, 0.015, c = P.ink },
		{ "rect", 0.82, 0.96, 0.1, 0.12, r = 0.2, c = P.gold },
		{ "rect", 0.82, 0.96, 0.055, 0.075, r = 0.3, c = P.cream, ol = false },
		{ "rect", 0.82, 0.9, 0.07, 0.02, r = 0.3, c = P.ink, ol = false },
	},
	anim = {
		{ kind = "flicker", pivot = { 0.82, 0.96 }, time = 0.25, ops = { { "drop", 0.82, 0.965, 0.022, c = P.orange, ol = false } } },
	},
}

-- a pipe at the corner of your mouth, blowing bubbles
pieces.pipe = {
	ops = {
		{ "line", 0.55, 0.495, 0.65, 0.5, 0.02, c = P.brown },
		{ "rect", 0.67, 0.475, 0.055, 0.07, r = 0.25, c = P.wood },
	},
	anim = {
		{ kind = "rise", pivot = { 0.68, 0.38 }, time = 1.2, amount = 0.26, ops = { { "ring", 0.68, 0.38, 0.065, 0.015, c = P.sea } } },
		{ kind = "rise", pivot = { 0.72, 0.38 }, time = 1.2, amount = 0.26, delay = 0.4, ops = { { "ring", 0.72, 0.38, 0.045, 0.013, c = P.sea } } },
		{ kind = "rise", pivot = { 0.65, 0.38 }, time = 1.2, amount = 0.26, delay = 0.8, ops = { { "ring", 0.65, 0.38, 0.05, 0.013, c = P.sea } } },
	},
}

-- buddies -------------------------------------------------------------------------

-- a parrot on your shoulder
pieces.parrot = {
	ops = {
		{ "pill", 0.82, 0.56, 0.06, 0.16, rot = 20, c = P.sea },
		{ "rect", 0.75, 0.48, 0.12, 0.15, r = 0.45, c = P.red },
		{ "circle", 0.73, 0.4, 0.11, c = P.red },
		{ "tri", 0.68, 0.415, 0.055, dir = -90, c = P.gold },
		{ "circle", 0.725, 0.39, 0.03, c = P.line, ol = false },
		{ "pill", 0.78, 0.5, 0.045, 0.09, rot = 15, c = P.gold, ol = false },
	},
}

pieces.ghost = {
	anim = {
		{
			kind = "bob",
			pivot = { 0.9, 0.3 },
			time = 0.9,
			amount = 0.05,
			ops = {
				{ "rect", 0.9, 0.32, 0.16, 0.2, r = 0.45, c = P.white },
				{ "circle", 0.85, 0.42, 0.055, c = P.white },
				{ "circle", 0.9, 0.43, 0.055, c = P.white },
				{ "circle", 0.95, 0.42, 0.055, c = P.white },
				{ "circle", 0.875, 0.3, 0.025, c = P.line, ol = false },
				{ "circle", 0.925, 0.3, 0.025, c = P.line, ol = false },
				{ "mouth", 0.9, 0.35, 0.035, mood = "o" },
			},
		},
	},
}

-- a little grey cloud raining on you
pieces.raincloud = {
	ops = {
		{ "circle", 0.4, -0.02, 0.16, c = P.cloud },
		{ "circle", 0.6, -0.02, 0.16, c = P.cloud },
		{ "circle", 0.5, -0.07, 0.2, c = P.cloud },
		{ "rect", 0.5, 0.02, 0.34, 0.09, r = 0.45, c = P.cloud },
	},
	anim = {
		{ kind = "fall", pivot = { 0.42, 0.08 }, time = 0.6, amount = 0.1, ops = { { "drop", 0.42, 0.08, 0.016, dir = 0, c = P.sea } } },
		{ kind = "fall", pivot = { 0.5, 0.08 }, time = 0.6, amount = 0.1, delay = 0.2, ops = { { "drop", 0.5, 0.08, 0.016, dir = 0, c = P.sea } } },
		{ kind = "fall", pivot = { 0.58, 0.08 }, time = 0.6, amount = 0.1, delay = 0.4, ops = { { "drop", 0.58, 0.08, 0.016, dir = 0, c = P.sea } } },
	},
}

-- two gulls circling over your head
pieces.gulls = {
	anim = {
		{
			kind = "orbit",
			pivot = { 0.5, 0.02 },
			time = 3,
			amount = 0.22,
			ops = {
				{ "arc", 0.465, 0.04, 0.08, 0.022, dir = 0, keep = 0.42, c = P.white },
				{ "arc", 0.535, 0.04, 0.08, 0.022, dir = 0, keep = 0.42, c = P.white },
			},
		},
		{
			kind = "orbit",
			pivot = { 0.5, 0.02 },
			time = 3,
			amount = 0.22,
			delay = 1.5,
			ops = {
				{ "arc", 0.465, 0.04, 0.08, 0.022, dir = 0, keep = 0.42, c = P.white },
				{ "arc", 0.535, 0.04, 0.08, 0.022, dir = 0, keep = 0.42, c = P.white },
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
