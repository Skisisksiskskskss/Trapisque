--[[
	Theme
	Trapisque's look: an old treasure map spread on a dark wooden table at night, lit
	by lanterns. Panels are dark walnut with brass inlay, text is warm cream, cards are
	carved wood. Every color and font in the game comes from here.

	UI code uses the semantic colours (bg, panel..., text...). The material colours
	(parchment, ink, wood...) are for things that really are paper, ink or wood: the
	map, the cards, the dice.
]]

local Theme = {}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end
Theme.hex = hex

Theme.C = {
	-- the dark UI: surfaces from deepest to highest, then text on them
	bg = hex("140F0B"), -- behind everything
	panel = hex("2A2119"), -- panels and dialogs (dark walnut)
	panelDeep = hex("1C1612"), -- wells, plates, inputs: set into a panel
	panelRaised = hex("372B21"), -- rows and tiles sitting on a panel
	panelHi = hex("46372A"), -- hovered or picked rows
	panelEdge = hex("5C4736"), -- borders between surfaces
	panelLine = hex("3E3026"), -- quiet dividers
	text = hex("F3E8D2"), -- warm cream
	textSoft = hex("C9B89C"),
	textFaint = hex("8F7F69"),
	textOnLight = hex("3A2414"), -- on brass, parchment, light wood
	infoSoft = hex("8DBDEB"), -- levels, links: blue that reads on a dark panel
	goodSoft = hex("8CD07A"),
	badSoft = hex("F08A80"),
	mine = hex("3A2F1B"), -- your own row (with a brass edge)

	-- table & background
	table = hex("1A130E"),
	tableLight = hex("241A13"),
	tablePlank = hex("120D0A"),
	shadow = hex("080504"),

	-- parchment (maps, panels, card backs)
	parchment = hex("F3E4C1"),
	parchmentMid = hex("E8D2A2"),
	parchmentDark = hex("D2B27A"),
	parchmentEdge = hex("A97C45"),
	burn = hex("6B4423"),

	-- ink
	ink = hex("4A3020"),
	inkSoft = hex("7B5B3E"),
	inkFaint = hex("A88B66"),
	inkRed = hex("B5372B"),
	inkBlue = hex("3C6E8F"),
	inkGreen = hex("4E7A3A"),

	-- wood (cards, buttons, tiles)
	wood = hex("B57D46"),
	woodLight = hex("D4A06A"),
	woodPale = hex("E6C18F"),
	woodDark = hex("80522A"),
	woodDeep = hex("5C3818"),
	woodGrain = hex("94612F"),
	engrave = hex("4E2E14"),
	engraveLight = hex("F0CB98"),

	-- brass & gold
	brass = hex("E3B04B"),
	brassLight = hex("FFE39A"),
	brassDark = hex("9E7425"),
	gold = hex("FFC93C"),

	-- map water & nature
	sea = hex("9CCBC8"),
	seaDeep = hex("6EA7A6"),
	seaInk = hex("4F8C8A"),
	grass = hex("A9C27A"),
	swamp = hex("8FA46A"),
	slime = hex("8BD448"),
	stone = hex("9C958A"),
	stoneDark = hex("6D665C"),
	iron = hex("5B6168"),

	-- card categories
	trap = hex("C2513B"),
	assist = hex("5E9A3C"),
	neutral = hex("7A61A8"),
	potion = hex("D98C1F"),
	natural = hex("3F8C7E"),
	coin = hex("F2C14E"),

	-- UI feedback
	good = hex("5BB36A"),
	bad = hex("D9534F"),
	info = hex("4C8DC9"),
	white = hex("FFFFFF"),
	black = hex("000000"),
	textDark = hex("3A2414"),
	textLight = hex("FFF5DE"),
	dim = hex("0B0704"),
	vip = hex("8C6414"), -- VIP names: a deep gold that still reads on parchment
}

-- Seat colors identify each player on the board (ring around their pawn).
Theme.Seat = {
	hex("E35D5D"), -- red
	hex("4E8FDB"), -- blue
	hex("5DB866"), -- green
	hex("EDBB36"), -- yellow
	hex("A56CDB"), -- purple
	hex("F0883A"), -- orange
}
Theme.SeatName = { "Red", "Blue", "Green", "Gold", "Purple", "Orange" }

Theme.Team = {
	hex("E35D5D"),
	hex("4E8FDB"),
	hex("5DB866"),
}
Theme.TeamName = { "Red Team", "Blue Team", "Green Team" }

Theme.Category = {
	trap = Theme.C.trap,
	assist = Theme.C.assist,
	neutral = Theme.C.neutral,
	potion = Theme.C.potion,
	natural = Theme.C.natural,
	coin = Theme.C.coin,
}
Theme.CategoryName = {
	trap = "Trap",
	assist = "Assist",
	neutral = "Neutral",
	potion = "Potion",
	natural = "Natural Trap",
	coin = "Coin",
}

Theme.Character = {
	mage = hex("5876D6"),
	trapper = hex("A86B39"),
	fire_starter = hex("E2622B"),
	naturalist = hex("4E9A47"),
	warper = hex("8B57CC"),
	overseer = hex("CDA42A"),
}

local nunito = Font.fromEnum(Enum.Font.Nunito)
Theme.Font = {
	Display = Font.fromEnum(Enum.Font.Fondamento), -- map labels, titles: old-map lettering
	Chunky = Font.fromEnum(Enum.Font.LuckiestGuy), -- buttons, numbers: carved-sign lettering
	Body = Font.new(nunito.Family, Enum.FontWeight.Bold),
	BodyHeavy = Font.new(nunito.Family, Enum.FontWeight.ExtraBold),
	BodyRegular = Font.new(nunito.Family, Enum.FontWeight.SemiBold),
}

-- Colour for a player's name on a panel: VIPs get gold.
function Theme.nameColor(look: { [string]: any }?): Color3
	return if look and look.vip then Theme.C.gold else Theme.C.text
end

return Theme
