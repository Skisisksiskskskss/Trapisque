--[[
	Theme
	Trapisque's look: a pirate board game, printed simply like a 1970s box (flat colour,
	a short list of inks, cream card stock) and inked like a comic (one heavy dark
	outline around everything, hard shadows, punchy lettering). The table is the open
	sea; panels, cards and buttons are cream card and flat paint on top of it.

	Two fonts: Bangers for anything loud (titles, buttons, numbers, BONK!) and Oswald
	for reading. Every colour and font comes from here; the illustrations (StickerArt,
	the maps) draw from the same inks.

	UI code uses the semantic colours (bg, panel..., text...). Panels are light, so
	`text` is dark ink; `textLight` is for lettering on the sea or on a dark button.
	The older material names (brass, wood, parchment, ink...) still exist so nothing
	breaks, but point at the pirate inks.
]]

local Theme = {}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end
Theme.hex = hex

local C = {
	-- the ink outline and the hard shadow under everything
	line = hex("1C1A24"),
	shadow = hex("1C1A24"),

	-- surfaces: the sea behind, cream card on top
	bg = hex("17435F"), -- the open sea, behind everything
	bgDeep = hex("0F2F44"),
	panel = hex("F3E6C8"), -- panels and dialogs: cream card
	panelDeep = hex("E0CCA0"), -- wells, tracks, inputs pressed into a panel
	panelRaised = hex("FBF4E2"), -- rows and tiles sitting on a panel
	panelHi = hex("FFE7A3"), -- hovered or picked rows
	panelEdge = hex("C9AE7C"), -- quiet borders between surfaces
	panelLine = hex("D8C39A"), -- dividers

	-- text (on cream card unless it says otherwise)
	text = hex("1C1A24"), -- ink
	textSoft = hex("5C4A36"), -- brown ink
	textFaint = hex("8C7A62"),
	textOnLight = hex("1C1A24"),
	textLight = hex("FFF8E7"), -- bone white: on the sea and on dark paint
	textLightSoft = hex("BFD8E4"),
	white = hex("FFFFFF"),
	black = hex("000000"),
	cream = hex("FFF8E7"),

	-- inks
	coral = hex("D7263D"), -- pirate red
	coralDark = hex("9E1B2C"),
	orange = hex("F08A24"),
	orangeDark = hex("B8601A"),
	sun = hex("F5B700"), -- gold
	sunLight = hex("FFD75E"),
	sunDark = hex("C98F00"),
	lime = hex("4FA548"), -- jungle green
	limeDark = hex("357A30"),
	sky = hex("2E8FB3"), -- sea blue
	skyDark = hex("1F6A8A"),
	grape = hex("2B4C7E"), -- navy (no purple anywhere)
	grapeDark = hex("1C3459"),
	pink = hex("D94C9C"),
	pinkDark = hex("A1336F"),
	mint = hex("2A9D8F"), -- teal
	mintDark = hex("1E7068"),
	steel = hex("B8BDC7"),
	steelDark = hex("7D8592"),

	-- feedback
	good = hex("3B9E4A"),
	bad = hex("D7263D"),
	info = hex("2E8FB3"),
	infoSoft = hex("8FD0E6"),
	goodSoft = hex("A6D98F"),
	badSoft = hex("F09AA4"),
	mine = hex("FFE7A3"), -- your own row (with a gold edge)
	dim = hex("0B1E2B"),
	vip = hex("F5B700"),

	-- the sea and the land, for maps and backgrounds
	seaDeep = hex("15405A"),
	sea = hex("1F6A8A"),
	seaLight = hex("2E8FB3"),
	shallows = hex("74C7D9"),
	foam = hex("E8F7F7"),
	sand = hex("F2C879"),
	sandDark = hex("D9A54A"),
	jungle = hex("3E8E41"),
	jungleDark = hex("2B6431"),
	rock = hex("8A8478"),
	rockDark = hex("5E5A52"),
	plank = hex("B87333"),
	plankDark = hex("7A4A1F"),
	bone = hex("FFF8E7"),
}

-- The older material names, pointed at the pirate inks.
C.brass = C.sun
C.brassLight = C.sunLight
C.brassDark = C.sunDark
C.gold = C.sun
C.parchment = C.panel
C.parchmentMid = hex("EBDAB4")
C.parchmentDark = C.panelDeep
C.parchmentEdge = C.panelEdge
C.burn = hex("6E4520")
C.ink = C.line
C.inkSoft = C.textSoft
C.inkFaint = C.textFaint
C.inkRed = C.coralDark
C.inkBlue = C.skyDark
C.inkGreen = C.limeDark
C.wood = C.plank
C.woodLight = hex("D69A5B")
C.woodPale = hex("EBC48F")
C.woodDark = C.plankDark
C.woodDeep = hex("4F2F14")
C.woodGrain = hex("9C5F2A")
C.engrave = hex("4E2E14")
C.engraveLight = hex("F0CB98")
C.table = C.bg
C.tableLight = C.sea
C.tablePlank = C.bgDeep
C.seaInk = C.seaDeep
C.grass = C.lime
C.swamp = hex("4E6E2E")
C.slime = hex("9BCF2E")
C.stone = C.rock
C.stoneDark = C.rockDark
C.iron = C.steelDark
C.textDark = C.line

-- card categories
C.trap = C.coral
C.assist = C.lime
C.neutral = C.grape
C.potion = C.orange
C.natural = C.mint
C.coin = C.sun

Theme.C = C

-- The characters' colours: a character's colour is its player's colour everywhere
-- (the piece on the board, the name, the Power bar, the feed), so there's one of each
-- character in a match.
Theme.Character = {
	mage = hex("1E7FD6"), -- blue
	trapper = hex("F08A24"), -- orange
	fire_starter = hex("D7263D"), -- red
	naturalist = hex("43A047"), -- green
	warper = hex("D94C9C"), -- pink
	overseer = hex("F5B700"), -- gold
	gambler = hex("13A398"), -- teal
	cannoneer = hex("8B5A2B"), -- brown
}
Theme.CharacterName = {
	mage = "Blue",
	trapper = "Orange",
	fire_starter = "Red",
	naturalist = "Green",
	warper = "Pink",
	overseer = "Gold",
	gambler = "Teal",
	cannoneer = "Brown",
}

-- Seat colours (kept for anything that has no character yet): the character order.
Theme.Seat = {
	Theme.Character.fire_starter,
	Theme.Character.mage,
	Theme.Character.naturalist,
	Theme.Character.overseer,
	Theme.Character.warper,
	Theme.Character.trapper,
}
Theme.SeatName = { "Red", "Blue", "Green", "Gold", "Pink", "Orange" }

-- A player's colour: their character's.
function Theme.playerColor(character: string?): Color3
	return character and Theme.Character[character] or C.steelDark
end

-- Who plays each seat in the match on screen, so a seat's colour is its character's
-- (MatchScreen keeps it up to date).
local seatCharacters: { [number]: string } = {}
function Theme.setSeatCharacters(map: { [number]: string }?)
	seatCharacters = map or {}
end

function Theme.seatColor(seat: number?): Color3
	if not seat or seat <= 0 then
		return C.steelDark
	end
	local character = seatCharacters[seat]
	if character and Theme.Character[character] then
		return Theme.Character[character]
	end
	return Theme.Seat[((seat - 1) % 6) + 1]
end

-- Relative luminance (sRGB), for contrast checks.
local function luminance(c: Color3): number
	local function lin(v: number): number
		return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B)
end
Theme.luminance = luminance

-- The colour darkened (same hue) until it reads as lettering on cream card: a gold name
-- becomes ochre, a pink one raspberry. Dark colours come back as they are.
function Theme.inkOf(color: Color3): Color3
	local bg = luminance(C.panel)
	local c = color
	for _ = 1, 24 do
		if (bg + 0.05) / (luminance(c) + 0.05) >= 4.5 then
			return c
		end
		c = c:Lerp(Color3.new(0, 0, 0), 0.08)
	end
	return c
end

-- Ink or bone white, whichever reads on a fill of `color`.
function Theme.textOn(color: Color3): Color3
	return if luminance(color) > 0.33 then C.text else C.textLight
end

-- Teams fly a flag, so team colours stay off the players: navy, red and teal crews.
Theme.Team = {
	hex("2B4C7E"),
	hex("D7263D"),
	hex("2A9D8F"),
}
Theme.TeamName = { "Navy Crew", "Red Crew", "Teal Crew" }

Theme.Category = {
	trap = C.trap,
	assist = C.assist,
	neutral = C.neutral,
	potion = C.potion,
	natural = C.natural,
	coin = C.coin,
}
Theme.CategoryName = {
	trap = "Trap",
	assist = "Assist",
	neutral = "Board piece",
	potion = "Potion",
	natural = "Hazard",
	coin = "Coin",
}

local oswald = Font.fromEnum(Enum.Font.Oswald)
local bangers = Font.fromEnum(Enum.Font.Bangers)
Theme.Font = {
	Display = bangers, -- titles
	Chunky = bangers, -- buttons, numbers
	Body = Font.new(oswald.Family, Enum.FontWeight.Medium),
	BodyHeavy = Font.new(oswald.Family, Enum.FontWeight.SemiBold),
	BodyRegular = Font.new(oswald.Family, Enum.FontWeight.Regular),
}

-- Colour for a player's name on a panel: VIPs get gold.
function Theme.nameColor(look: { [string]: any }?): Color3
	return if look and look.vip then C.sunDark else C.text
end

return Theme
