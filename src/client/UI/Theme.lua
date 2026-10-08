--[[
	Theme
	Trapisque's look: an old treasure map spread on a wooden table, with carved wooden
	cards and brass fittings. Every color and font in the game comes from here.
]]

local Theme = {}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end
Theme.hex = hex

Theme.C = {
	-- table & background
	table = hex("2A1C13"),
	tableLight = hex("3A281B"),
	tablePlank = hex("221710"),
	shadow = hex("120B07"),

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

Theme.Map = {
	blissful = { paper = hex("F3E4C1"), wash = hex("9CCBC8"), washDark = hex("6EA7A6"), accent = hex("3C6E8F") },
	junction = { paper = hex("EBDDBE"), wash = hex("A9A196"), washDark = hex("7E766B"), accent = hex("5A4A3A") },
	slimy = { paper = hex("ECE3BC"), wash = hex("A7B97A"), washDark = hex("7E9455"), accent = hex("4E7A3A") },
}

local nunito = Font.fromEnum(Enum.Font.Nunito)
Theme.Font = {
	Display = Font.fromEnum(Enum.Font.Fondamento), -- map labels, titles: old-map lettering
	Chunky = Font.fromEnum(Enum.Font.LuckiestGuy), -- buttons, numbers: carved-sign lettering
	Body = Font.new(nunito.Family, Enum.FontWeight.Bold),
	BodyHeavy = Font.new(nunito.Family, Enum.FontWeight.ExtraBold),
	BodyRegular = Font.new(nunito.Family, Enum.FontWeight.SemiBold),
}

-- Virtual resolution the UI is designed for (scaled to fit any screen).
Theme.VirtualHeight = 720
Theme.MinVirtualWidth = 1180

-- Colour for a player's name on parchment: VIPs get gold.
function Theme.nameColor(look: { [string]: any }?): Color3
	return if look and look.vip then Theme.C.vip else Theme.C.textDark
end

return Theme
