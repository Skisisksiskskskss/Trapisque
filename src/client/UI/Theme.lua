--[[
	Theme
	Trapisque's look: candy stickers on a night-purple table. Everything has the same
	thick dark outline and a hard shadow, colours are bright and flat, and lettering is
	chunky with an outline. Two fonts only: Luckiest Guy for anything loud (titles,
	buttons, numbers) and Nunito for reading. Every colour and font comes from here; the
	illustrations (StickerArt) draw from the same palette.

	UI code uses the semantic colours (bg, panel..., text...). The older material names
	(brass, wood, parchment, ink...) still exist so nothing breaks, but they now point
	at the candy palette.
]]

local Theme = {}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end
Theme.hex = hex

local C = {
	-- the sticker outline and the hard shadow under everything
	line = hex("1B1030"),
	shadow = hex("0E0819"),

	-- surfaces, deepest to highest
	bg = hex("1F1438"), -- behind everything
	bgDeep = hex("140C24"),
	panel = hex("2B1D4D"), -- panels and dialogs
	panelDeep = hex("1A1131"), -- wells, tracks, inputs set into a panel
	panelRaised = hex("3A2866"), -- rows and tiles sitting on a panel
	panelHi = hex("4C3780"), -- hovered or picked rows
	panelEdge = hex("5E479A"), -- quiet borders between surfaces
	panelLine = hex("42306E"), -- dividers

	-- text
	text = hex("FFF4E2"), -- cream
	textSoft = hex("CBBDF0"), -- lavender
	textFaint = hex("8C7CB8"),
	textOnLight = hex("1B1030"), -- on sun, lime, cream...
	white = hex("FFFFFF"),
	black = hex("000000"),
	cream = hex("FFF4E2"),

	-- candy
	coral = hex("FF4F5E"),
	coralDark = hex("C9303F"),
	orange = hex("FF9A3C"),
	orangeDark = hex("D9661A"),
	sun = hex("FFD23F"),
	sunLight = hex("FFE88A"),
	sunDark = hex("E0A81C"),
	lime = hex("8BE04E"),
	limeDark = hex("4FAE2A"),
	sky = hex("45C3FF"),
	skyDark = hex("1E8FD6"),
	grape = hex("9A6BFF"),
	grapeDark = hex("6B3FD6"),
	pink = hex("FF6FB8"),
	pinkDark = hex("D9408C"),
	mint = hex("3BE0B5"),
	mintDark = hex("1FA884"),
	steel = hex("C9D3E6"),
	steelDark = hex("8792AD"),

	-- feedback
	good = hex("6BD94A"),
	bad = hex("FF4F5E"),
	info = hex("45A6FF"),
	infoSoft = hex("8FD3FF"),
	goodSoft = hex("A6EE7E"),
	badSoft = hex("FF8C96"),
	mine = hex("4A3A12"), -- your own row (with a sun edge)
	dim = hex("0B0616"),
	vip = hex("FFD23F"),
}

-- The older material names, re-pointed at the candy palette.
C.brass = C.sun
C.brassLight = C.sunLight
C.brassDark = C.sunDark
C.gold = C.sun
C.parchment = C.cream
C.parchmentMid = hex("F3E2C4")
C.parchmentDark = hex("E3CBA0")
C.parchmentEdge = hex("C7A472")
C.burn = hex("6E4520")
C.ink = C.line
C.inkSoft = hex("4C3780")
C.inkFaint = hex("8C7CB8")
C.inkRed = C.coralDark
C.inkBlue = C.skyDark
C.inkGreen = C.limeDark
C.wood = hex("C98A4B")
C.woodLight = hex("E0A86A")
C.woodPale = hex("F2CC94")
C.woodDark = hex("8E5726")
C.woodDeep = hex("5C3818")
C.woodGrain = hex("A86E35")
C.engrave = hex("4E2E14")
C.engraveLight = hex("F0CB98")
C.table = C.bg
C.tableLight = C.panel
C.tablePlank = C.bgDeep
C.sea = hex("3FA7F5")
C.seaDeep = hex("1F6FC4")
C.seaInk = hex("164E8F")
C.grass = C.lime
C.swamp = hex("4E7A2E")
C.slime = hex("A6E83A")
C.stone = hex("9C95B8")
C.stoneDark = hex("6B6390")
C.iron = C.steelDark
C.textDark = C.line
C.textLight = C.cream

-- card categories
C.trap = C.coral
C.assist = C.lime
C.neutral = C.grape
C.potion = C.orange
C.natural = C.mint
C.coin = C.sun

Theme.C = C

-- Seat colors identify each player on the board (the ring under their pawn).
Theme.Seat = {
	hex("FF4F5E"), -- red
	hex("45A6FF"), -- blue
	hex("6BD94A"), -- green
	hex("FFC93C"), -- yellow
	hex("A879FF"), -- purple
	hex("FF8F3C"), -- orange
}
Theme.SeatName = { "Red", "Blue", "Green", "Gold", "Purple", "Orange" }

Theme.Team = {
	hex("FF4F5E"),
	hex("45A6FF"),
	hex("6BD94A"),
}
Theme.TeamName = { "Red Team", "Blue Team", "Green Team" }

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

-- Each character's colour (their mascot's body).
Theme.Character = {
	mage = hex("45C3FF"),
	trapper = hex("E8893A"),
	fire_starter = hex("FF4F5E"),
	naturalist = hex("8BE04E"),
	warper = hex("9A6BFF"),
	overseer = hex("FFD23F"),
}

local nunito = Font.fromEnum(Enum.Font.Nunito)
local luckiest = Font.fromEnum(Enum.Font.LuckiestGuy)
Theme.Font = {
	Display = luckiest, -- titles
	Chunky = luckiest, -- buttons, numbers
	Body = Font.new(nunito.Family, Enum.FontWeight.Bold),
	BodyHeavy = Font.new(nunito.Family, Enum.FontWeight.ExtraBold),
	BodyRegular = Font.new(nunito.Family, Enum.FontWeight.SemiBold),
}

-- Colour for a player's name on a panel: VIPs get gold.
function Theme.nameColor(look: { [string]: any }?): Color3
	return if look and look.vip then C.sun else C.text
end

return Theme
