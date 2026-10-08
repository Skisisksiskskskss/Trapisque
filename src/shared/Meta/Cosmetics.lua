--[[
	Cosmetics
	Everything players can collect from Treasure Chests. Purely visual: nothing here
	changes how a match plays.

	Every cosmetic is drawn in code from UI shapes (see client/UI/Art.lua), so the
	`look` tables below are drawing instructions, not image ids. Colors are hex strings
	so this module stays plain data.

	category  pawn | dice | trail | emote | title
	rarity    common | rare | epic | legendary | mythic
	source    nil = in chests, "default" = everyone owns it, "vip" / "emotepack" = gamepass
]]

local Cosmetics = {}

Cosmetics.rarities = {
	{ id = "common", name = "Common", color = "#B9C2CF", glow = "#E3E8EF", order = 1 },
	{ id = "rare", name = "Rare", color = "#4FA3FF", glow = "#A9D3FF", order = 2 },
	{ id = "epic", name = "Epic", color = "#B36BFF", glow = "#DDBBFF", order = 3 },
	{ id = "legendary", name = "Legendary", color = "#FFB536", glow = "#FFE2A3", order = 4 },
	{ id = "mythic", name = "Mythic", color = "#FF5FA2", glow = "#FFC2DC", order = 5, rainbow = true },
}
Cosmetics.rarityById = {}
for _, r in Cosmetics.rarities do
	Cosmetics.rarityById[r.id] = r
end

Cosmetics.categories = {
	{ id = "pawn", name = "Pawns", single = "Pawn" },
	{ id = "dice", name = "Dice", single = "Dice" },
	{ id = "trail", name = "Trails", single = "Trail" },
	{ id = "emote", name = "Emotes", single = "Emote" },
	{ id = "title", name = "Titles", single = "Title" },
}

-- How many emotes can be equipped at once (the emote wheel in matches)
Cosmetics.EmoteSlots = 6

local defs = {
	-------------------------------------------------------------------------
	-- Pawns: the token that walks the board for you
	-- look: fill, fill2 (gradient), pattern, accent, glow, spin (animated)
	-------------------------------------------------------------------------
	{ id = "pawn_classic", category = "pawn", name = "Classic", rarity = "common", source = "default",
		look = { fill = "seat", pattern = "ring", accent = "#FFFFFF" } },
	{ id = "pawn_pebble", category = "pawn", name = "Pebble", rarity = "common",
		look = { fill = "#8E9AAF", fill2 = "#5C677D", pattern = "dots", accent = "#C5CCD8" } },
	{ id = "pawn_mint", category = "pawn", name = "Mint Swirl", rarity = "common",
		look = { fill = "#7FE0C4", fill2 = "#E9FFF8", pattern = "stripes", accent = "#FFFFFF" } },
	{ id = "pawn_sunset", category = "pawn", name = "Sunset", rarity = "common",
		look = { gradient = true, fill = "#FF9F59", fill2 = "#FF5E8A", pattern = "split", accent = "#FFE0B8" } },
	{ id = "pawn_ocean", category = "pawn", name = "Ocean", rarity = "common",
		look = { fill = "#2E86DE", fill2 = "#48DBFB", pattern = "wave", accent = "#D6F4FF" } },
	{ id = "pawn_moss", category = "pawn", name = "Mossy", rarity = "common",
		look = { fill = "#6A994E", fill2 = "#A7C957", pattern = "leaf", accent = "#F2E8CF" } },
	{ id = "pawn_ruby", category = "pawn", name = "Ruby", rarity = "rare",
		look = { fill = "#E63946", fill2 = "#8D0801", pattern = "gem", accent = "#FFB3BA", shine = true } },
	{ id = "pawn_emerald", category = "pawn", name = "Emerald", rarity = "rare",
		look = { fill = "#2DC653", fill2 = "#036666", pattern = "gem", accent = "#B7FFD0", shine = true } },
	{ id = "pawn_checker", category = "pawn", name = "Checkmate", rarity = "rare",
		look = { fill = "#F5F5F5", fill2 = "#F5F5F5", pattern = "checker", accent = "#1B1B1E" } },
	{ id = "pawn_candy", category = "pawn", name = "Candy Cane", rarity = "rare",
		look = { fill = "#FFFFFF", fill2 = "#FFE3E3", pattern = "stripes", accent = "#E5383B" } },
	{ id = "pawn_bee", category = "pawn", name = "Bumblebee", rarity = "rare",
		look = { fill = "#FFD60A", fill2 = "#FFC300", pattern = "bands", accent = "#1D1D1D" } },
	{ id = "pawn_galaxy", category = "pawn", name = "Galaxy", rarity = "epic",
		look = { gradient = true, fill = "#3A0CA3", fill2 = "#0B0033", pattern = "stars", accent = "#F1E9FF", spin = true } },
	{ id = "pawn_lava", category = "pawn", name = "Lava Core", rarity = "epic",
		look = { gradient = true, fill = "#FF4800", fill2 = "#6A040F", pattern = "flame", accent = "#FFD166", spin = true, glow = "#FF7B00" } },
	{ id = "pawn_frost", category = "pawn", name = "Frostbite", rarity = "epic",
		look = { fill = "#CAF0F8", fill2 = "#48CAE4", pattern = "snow", accent = "#FFFFFF", glow = "#90E0EF" } },
	{ id = "pawn_toxic", category = "pawn", name = "Toxic Slime", rarity = "epic",
		look = { fill = "#9EF01A", fill2 = "#38B000", pattern = "drip", accent = "#E9FFC2", glow = "#70E000" } },
	{ id = "pawn_gold", category = "pawn", name = "Solid Gold", rarity = "legendary",
		look = { fill = "#FFE066", fill2 = "#C9930C", pattern = "star", accent = "#FFF8D6", shine = true, glow = "#FFD43B" } },
	{ id = "pawn_phoenix", category = "pawn", name = "Phoenix", rarity = "legendary",
		look = { gradient = true, fill = "#FFBE0B", fill2 = "#FB5607", pattern = "wings", accent = "#FFF3B0", spin = true, glow = "#FF8800" } },
	{ id = "pawn_void", category = "pawn", name = "Void Eye", rarity = "legendary",
		look = { fill = "#14001F", fill2 = "#3C096C", pattern = "eye", accent = "#E0AAFF", glow = "#9D4EDD" } },
	{ id = "pawn_prism", category = "pawn", name = "Prismatic", rarity = "mythic",
		look = { gradient = true, fill = "rainbow", pattern = "diamond", accent = "#FFFFFF", spin = true, glow = "#FFFFFF" } },
	{ id = "pawn_crest", category = "pawn", name = "Trapisque Crest", rarity = "mythic",
		look = { fill = "#1B263B", fill2 = "#0D1321", pattern = "chest", accent = "#FFC300", glow = "#FFC300", shine = true } },
	{ id = "pawn_crown", category = "pawn", name = "Royal Crown", rarity = "legendary", source = "vip",
		look = { fill = "#7B2CBF", fill2 = "#3C096C", pattern = "crown", accent = "#FFD60A", glow = "#C77DFF", shine = true } },

	-------------------------------------------------------------------------
	-- Dice: how your die looks when you roll
	-- look: face, face2, pip, edge, glow, spin
	-------------------------------------------------------------------------
	{ id = "dice_ivory", category = "dice", name = "Ivory", rarity = "common", source = "default",
		look = { face = "#FFFDF5", face2 = "#EDE6D3", pip = "#22223B", edge = "#C9BFA5" } },
	{ id = "dice_charcoal", category = "dice", name = "Charcoal", rarity = "common",
		look = { face = "#3D405B", face2 = "#22223B", pip = "#F4F1DE", edge = "#121420" } },
	{ id = "dice_sky", category = "dice", name = "Sky", rarity = "common",
		look = { face = "#A2D2FF", face2 = "#74B3F0", pip = "#FFFFFF", edge = "#4D8BD1" } },
	{ id = "dice_peach", category = "dice", name = "Peach", rarity = "common",
		look = { face = "#FFD6BA", face2 = "#FFB38A", pip = "#7F3C1D", edge = "#E08E5F" } },
	{ id = "dice_ruby", category = "dice", name = "Ruby", rarity = "rare",
		look = { face = "#E5383B", face2 = "#A4161A", pip = "#FFFFFF", edge = "#660708" } },
	{ id = "dice_jade", category = "dice", name = "Jade", rarity = "rare",
		look = { face = "#52B788", face2 = "#2D6A4F", pip = "#F1FAEE", edge = "#1B4332" } },
	{ id = "dice_bone", category = "dice", name = "Old Bone", rarity = "rare",
		look = { face = "#EDE0D4", face2 = "#B08968", pip = "#3E2723", edge = "#7F5539" } },
	{ id = "dice_neon", category = "dice", name = "Neon", rarity = "epic",
		look = { face = "#0B0B12", face2 = "#1A1A2E", pip = "#39FF14", edge = "#39FF14", glow = "#39FF14" } },
	{ id = "dice_frost", category = "dice", name = "Frost", rarity = "epic",
		look = { face = "#E0FBFC", face2 = "#98C1D9", pip = "#3D5A80", edge = "#FFFFFF", glow = "#CAF0F8" } },
	{ id = "dice_gold", category = "dice", name = "Golden", rarity = "legendary",
		look = { face = "#FFE066", face2 = "#D4A017", pip = "#5C3D00", edge = "#FFF3B0", glow = "#FFD43B" } },
	{ id = "dice_cosmic", category = "dice", name = "Cosmic", rarity = "mythic",
		look = { gradient = true, face = "#240046", face2 = "#7B2CBF", pip = "#FFFFFF", edge = "#E0AAFF", glow = "#C77DFF", spin = true } },

	-------------------------------------------------------------------------
	-- Trails: little particles that follow your pawn as it hops
	-- look: kind, color, color2
	-------------------------------------------------------------------------
	{ id = "trail_none", category = "trail", name = "No Trail", rarity = "common", source = "default",
		look = { kind = "none" } },
	{ id = "trail_dust", category = "trail", name = "Dust Puffs", rarity = "common",
		look = { kind = "puff", color = "#D9CBB3" } },
	{ id = "trail_bubbles", category = "trail", name = "Bubbles", rarity = "common",
		look = { kind = "bubble", color = "#9BE7FF" } },
	{ id = "trail_leaves", category = "trail", name = "Falling Leaves", rarity = "rare",
		look = { kind = "leaf", color = "#80B918", color2 = "#F48C06" } },
	{ id = "trail_sparkle", category = "trail", name = "Sparkles", rarity = "rare",
		look = { kind = "sparkle", color = "#FFF3B0" } },
	{ id = "trail_embers", category = "trail", name = "Embers", rarity = "epic",
		look = { kind = "ember", color = "#FF7B00", color2 = "#FFD000" } },
	{ id = "trail_hearts", category = "trail", name = "Hearts", rarity = "epic",
		look = { kind = "heart", color = "#FF4D6D" } },
	{ id = "trail_stars", category = "trail", name = "Shooting Stars", rarity = "legendary",
		look = { kind = "star", color = "#FFE066", color2 = "#FFFFFF" } },
	{ id = "trail_rainbow", category = "trail", name = "Rainbow Road", rarity = "mythic",
		look = { kind = "rainbow", color = "#FFFFFF" } },

	-------------------------------------------------------------------------
	-- Emotes: quick reactions in matches (fixed text, so no chat filtering needed)
	-------------------------------------------------------------------------
	{ id = "emote_gg", category = "emote", name = "GG!", rarity = "common", source = "default", look = { text = "GG!", color = "#6EE7B7" } },
	{ id = "emote_nice", category = "emote", name = "Nice!", rarity = "common", source = "default", look = { text = "Nice!", color = "#93C5FD" } },
	{ id = "emote_oops", category = "emote", name = "Oops!", rarity = "common", source = "default", look = { text = "Oops!", color = "#FCA5A5" } },
	{ id = "emote_hello", category = "emote", name = "Hello!", rarity = "common", look = { text = "Hello!", color = "#FDE68A" } },
	{ id = "emote_lol", category = "emote", name = "LOL", rarity = "common", look = { text = "LOL", color = "#FBCFE8" } },
	{ id = "emote_watch", category = "emote", name = "Watch your step!", rarity = "common", look = { text = "Watch your step!", color = "#FDBA74" } },
	{ id = "emote_thanks", category = "emote", name = "Thanks, teammate!", rarity = "common", look = { text = "Thanks, teammate!", color = "#A7F3D0" } },
	{ id = "emote_trap", category = "emote", name = "It's a trap!", rarity = "rare", look = { text = "It's a trap!", color = "#F87171" } },
	{ id = "emote_ouch", category = "emote", name = "OUCH!", rarity = "rare", look = { text = "OUCH!", color = "#FB7185" } },
	{ id = "emote_lucky", category = "emote", name = "So lucky!", rarity = "rare", look = { text = "So lucky!", color = "#FCD34D" } },
	{ id = "emote_hehe", category = "emote", name = "Hehehe...", rarity = "epic", look = { text = "Hehehe...", color = "#C4B5FD" } },
	{ id = "emote_comeback", category = "emote", name = "Comeback time!", rarity = "epic", look = { text = "Comeback time!", color = "#67E8F9" } },
	{ id = "emote_grog", category = "emote", name = "Grog hungry.", rarity = "legendary", look = { text = "Grog hungry.", color = "#86EFAC" } },
	{ id = "emote_ez", category = "emote", name = "EZ", rarity = "legendary", look = { text = "EZ", color = "#FFD43B" } },
	{ id = "emote_wow", category = "emote", name = "WOW", rarity = "rare", source = "emotepack", look = { text = "WOW", color = "#F0ABFC" } },
	{ id = "emote_rip", category = "emote", name = "RIP", rarity = "rare", source = "emotepack", look = { text = "RIP", color = "#CBD5E1" } },
	{ id = "emote_sorry", category = "emote", name = "Sorry!", rarity = "rare", source = "emotepack", look = { text = "Sorry!", color = "#BAE6FD" } },
	{ id = "emote_wp", category = "emote", name = "Well played!", rarity = "rare", source = "emotepack", look = { text = "Well played!", color = "#BBF7D0" } },
	{ id = "emote_mad", category = "emote", name = "Grrr!", rarity = "rare", source = "emotepack", look = { text = "Grrr!", color = "#FCA5A5" } },
	{ id = "emote_shh", category = "emote", name = "Shhh...", rarity = "rare", source = "emotepack", look = { text = "Shhh...", color = "#DDD6FE" } },

	-------------------------------------------------------------------------
	-- Titles: shown under your name
	-------------------------------------------------------------------------
	{ id = "title_none", category = "title", name = "No Title", rarity = "common", source = "default", look = { text = "", color = "#FFFFFF" } },
	{ id = "title_rookie", category = "title", name = "Rookie Explorer", rarity = "common", look = { text = "Rookie Explorer", color = "#CBD5E1" } },
	{ id = "title_hopper", category = "title", name = "Tile Hopper", rarity = "common", look = { text = "Tile Hopper", color = "#A5F3FC" } },
	{ id = "title_setter", category = "title", name = "Trap Setter", rarity = "common", look = { text = "Trap Setter", color = "#FCA5A5" } },
	{ id = "title_lucky", category = "title", name = "Lucky Roller", rarity = "rare", look = { text = "Lucky Roller", color = "#86EFAC" } },
	{ id = "title_sneaky", category = "title", name = "Sneaky Sneak", rarity = "rare", look = { text = "Sneaky Sneak", color = "#C4B5FD" } },
	{ id = "title_tamer", category = "title", name = "Grog Tamer", rarity = "epic", look = { text = "Grog Tamer", color = "#4ADE80" } },
	{ id = "title_warlord", category = "title", name = "Warlord", rarity = "epic", look = { text = "Warlord", color = "#F97316" } },
	{ id = "title_legend", category = "title", name = "Living Legend", rarity = "legendary", look = { text = "Living Legend", color = "#FACC15" } },
	{ id = "title_royalty", category = "title", name = "Treasure Royalty", rarity = "mythic", look = { text = "Treasure Royalty", color = "#F472B6", rainbow = true } },
	{ id = "title_vip", category = "title", name = "VIP", rarity = "legendary", source = "vip", look = { text = "VIP", color = "#C77DFF" } },
}

Cosmetics.byId = {}
Cosmetics.list = {}
Cosmetics.byCategory = {}
for _, c in Cosmetics.categories do
	Cosmetics.byCategory[c.id] = {}
end
for i, def in defs do
	def.order = i
	assert(Cosmetics.rarityById[def.rarity], "Cosmetics: bad rarity on " .. def.id)
	assert(Cosmetics.byCategory[def.category], "Cosmetics: bad category on " .. def.id)
	assert(Cosmetics.byId[def.id] == nil, "Cosmetics: duplicate id " .. def.id)
	Cosmetics.byId[def.id] = def
	table.insert(Cosmetics.list, def)
	table.insert(Cosmetics.byCategory[def.category], def)
end

Cosmetics.defaults = {
	pawn = "pawn_classic",
	dice = "dice_ivory",
	trail = "trail_none",
	title = "title_none",
	emotes = { "emote_gg", "emote_nice", "emote_oops" },
}

function Cosmetics.get(id: string)
	return Cosmetics.byId[id]
end

-- Items that can drop from chests, grouped by rarity.
function Cosmetics.chestPool()
	local pool = {}
	for _, r in Cosmetics.rarities do
		pool[r.id] = {}
	end
	for _, def in defs do
		if def.source == nil then
			table.insert(pool[def.rarity], def.id)
		end
	end
	return pool
end

-- Ids granted by a source ("default", "vip", "emotepack").
function Cosmetics.fromSource(source: string): { string }
	local out = {}
	for _, def in defs do
		if def.source == source then
			table.insert(out, def.id)
		end
	end
	return out
end

return Cosmetics
