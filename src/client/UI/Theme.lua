--[[
	Theme
	Trapisque's look: a pirate tabletop game, drawn like its art. Parchment panels framed
	in dark wood over the sea, one warm orange for the thing you should press, and each
	character's colour for its player. Rounded shapes lit from above and outlined in a
	dark shade of their own colour, a darker bottom edge on anything you can press.

	Two fonts: Nunito for everything you read or press, and Fredoka One only for the
	logo and the big moments of a match (YOUR TURN, TREASURE!). Every colour and font
	comes from here; the illustrations (StickerArt, the maps) draw from the same set.

	UI code uses the semantic colours (bg, panel..., text...). Panels are light, so
	`text` is dark; `textLight` is for lettering on the table or on a dark fill. `line`
	is the light border between surfaces; `ink` is the dark outline the illustrations
	keep. The older material names (brass, wood, parchment...) still exist so nothing
	breaks, but point at this palette.
]]

local Util = require(script.Parent.Util)

local Theme = {}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end
Theme.hex = hex

local C = {
	-- the light border between surfaces, the illustrations' outline, and shadows
	line = hex("CDB58C"),
	ink = hex("2A2830"),
	shadow = hex("0E1A24"),

	-- surfaces: the table behind, paper on top
	bg = hex("1D4560"), -- the sea, behind everything
	bgDeep = hex("143247"),
	panel = hex("F6EBD3"), -- panels and dialogs: parchment
	panelDeep = hex("EADBBB"), -- wells, tracks, inputs pressed into a panel
	panelRaised = hex("FFF9EA"), -- rows and tiles sitting on a panel
	panelHi = hex("FFE9BC"), -- hovered or picked rows
	panelEdge = hex("DCC69E"), -- quiet borders between surfaces
	panelLine = hex("E6D4AE"), -- dividers
	frame = hex("5E3F24"), -- the dark wood round a panel
	gilt = hex("C9A14A"), -- the thin gold line inside it
	ribbon = hex("C8443A"), -- panel headings

	-- text (on paper unless it says otherwise)
	text = hex("33261A"),
	textSoft = hex("6B5844"),
	textFaint = hex("9A8770"),
	textOnLight = hex("33261A"),
	textLight = hex("F7F5F0"), -- on the table and on dark fills
	textLightSoft = hex("A9BBC8"),
	white = hex("FFFFFF"),
	black = hex("000000"),
	cream = hex("FFF9EF"),

	-- colours
	coral = hex("D64545"), -- red: danger, traps
	coralDark = hex("A83434"),
	orange = hex("E8643C"), -- the accent: the button that matters
	orangeDark = hex("B94A27"),
	sun = hex("E7B023"), -- gold: treasure, coins, rewards
	sunLight = hex("F4CF6B"),
	sunDark = hex("B88A12"),
	lime = hex("3E9F5B"), -- green
	limeDark = hex("2E7744"),
	sky = hex("3C82C4"), -- blue
	skyDark = hex("2B6299"),
	grape = hex("2F4C6E"), -- navy
	grapeDark = hex("22384F"),
	pink = hex("D35A9C"),
	pinkDark = hex("A43F77"),
	mint = hex("2C9C8F"), -- teal
	mintDark = hex("1F7369"),
	steel = hex("B7BEC8"),
	steelDark = hex("7E8794"),

	-- feedback
	good = hex("3E9F5B"),
	bad = hex("D64545"),
	info = hex("3C82C4"),
	infoSoft = hex("A9CBEA"),
	goodSoft = hex("B5DCC0"),
	badSoft = hex("F2B5B5"),
	mine = hex("FFF1D6"), -- your own row
	dim = hex("0B1620"),
	vip = hex("E7B023"),

	-- the water and the land, for maps and backgrounds
	seaDeep = hex("1E4660"),
	sea = hex("2A5C7A"),
	seaLight = hex("3C7A9C"),
	shallows = hex("7FB9CC"),
	foam = hex("E6F2F3"),
	sand = hex("EBD3A0"),
	sandDark = hex("D2B47A"),
	jungle = hex("4C8A55"),
	jungleDark = hex("3A6B42"),
	rock = hex("8C877E"),
	rockDark = hex("625E57"),
	plank = hex("B98A5A"),
	plankDark = hex("85603C"),
	bone = hex("FFF9EF"),
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
C.textDark = C.text

-- card categories
C.trap = C.coral
C.assist = C.lime
C.neutral = C.grape
C.potion = C.orange
C.natural = C.mint
C.coin = C.sun

Theme.C = C

-- Borders drawn in `line` stay thin, whatever thickness the caller asked for.
Util.border = C.line

-- The characters' colours: a character's colour is its player's colour everywhere
-- (the piece on the board, the name, the Power bar, the feed), so there's one of each
-- character in a match.
Theme.Character = {
	mage = hex("2F7FD0"), -- blue
	trapper = hex("EE8A2E"), -- orange
	fire_starter = hex("D64545"), -- red
	naturalist = hex("3E9F5B"), -- green
	warper = hex("D35A9C"), -- pink
	overseer = hex("E7B023"), -- gold
	gambler = hex("22A094"), -- teal
	cannoneer = hex("93633A"), -- brown
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
	hex("2F4C6E"),
	hex("D64545"),
	hex("2C9C8F"),
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

local nunito = Font.fromEnum(Enum.Font.Nunito)
Theme.Font = {
	Display = Font.fromEnum(Enum.Font.FredokaOne), -- the logo and big match moments only
	Chunky = Font.new(nunito.Family, Enum.FontWeight.ExtraBold), -- buttons, headings, numbers
	Body = Font.new(nunito.Family, Enum.FontWeight.SemiBold),
	BodyHeavy = Font.new(nunito.Family, Enum.FontWeight.Bold),
	BodyRegular = Font.new(nunito.Family, Enum.FontWeight.Regular),
}

-- Colour for a player's name on a panel: VIPs get gold.
function Theme.nameColor(look: { [string]: any }?): Color3
	return if look and look.vip then C.sunDark else C.text
end

return Theme
