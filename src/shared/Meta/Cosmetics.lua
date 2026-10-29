--[[
	Cosmetics
	Everything players can collect from Treasure Chests. Purely visual: nothing here
	changes how a match plays.

	The `look` tables below say how each one is drawn (client/UI/CosmeticArt.lua, and
	PieceArt for finishes), not image ids. Colors are hex strings so this module stays
	plain data.

	category  finish | dice | trail | emote | title | emblem
	rarity    common | rare | epic | legendary | mythic
	source    nil = in chests, "default" = everyone owns it, "vip" / "emotepack" / "captain"
	          = gamepass,
	          "mastery" = earned by levelling up a character (Meta/Progress),
	          "fishing" = earned by filling the fish log (Meta/Fishing)
]]

local Cosmetics = {}

Cosmetics.rarities = {
	{ id = "common", name = "Common", color = "#B8BDC7", glow = "#E3E6EB", order = 1 },
	{ id = "rare", name = "Rare", color = "#2E8FB3", glow = "#9FD4E6", order = 2 },
	{ id = "epic", name = "Epic", color = "#D7263D", glow = "#F09AA4", order = 3 },
	{ id = "legendary", name = "Legendary", color = "#F5B700", glow = "#FFE7A3", order = 4 },
	{ id = "mythic", name = "Mythic", color = "#D94C9C", glow = "#F3A6CF", order = 5 },
}
Cosmetics.rarityById = {}
for _, r in Cosmetics.rarities do
	Cosmetics.rarityById[r.id] = r
end

Cosmetics.categories = {
	{ id = "finish", name = "Finishes", single = "Finish" },
	{ id = "dice", name = "Dice", single = "Dice" },
	{ id = "trail", name = "Trails", single = "Trail" },
	{ id = "emote", name = "Emotes", single = "Emote" },
	{ id = "title", name = "Titles", single = "Title" },
	{ id = "emblem", name = "Emblems", single = "Emblem" },
}

-- How many emotes can be equipped at once (the emote wheel in matches)
Cosmetics.EmoteSlots = 6

local defs = {
	-------------------------------------------------------------------------
	-- Finishes: what your playing piece is made of (the same piece, the same colour:
	-- your character's). look.finish names its art in art/pieces.py.
	-------------------------------------------------------------------------
	{ id = "fin_paint", category = "finish", name = "Painted", rarity = "common", source = "default", look = { finish = "paint" } },
	{ id = "fin_oak", category = "finish", name = "Oak", rarity = "common", look = { finish = "oak" } },
	{ id = "fin_clay", category = "finish", name = "Clay", rarity = "common", look = { finish = "clay" } },
	{ id = "fin_pearl", category = "finish", name = "Pearl", rarity = "common", look = { finish = "pearl" } },
	{ id = "fin_marble", category = "finish", name = "Marble", rarity = "rare", look = { finish = "marble" } },
	{ id = "fin_glass", category = "finish", name = "Sea Glass", rarity = "rare", look = { finish = "glass" } },
	{ id = "fin_porcelain", category = "finish", name = "Porcelain", rarity = "rare", look = { finish = "porcelain" } },
	{ id = "fin_metallic", category = "finish", name = "Metallic", rarity = "epic", look = { finish = "metallic" } },
	{ id = "fin_obsidian", category = "finish", name = "Obsidian", rarity = "epic", look = { finish = "obsidian" } },
	{ id = "fin_gold", category = "finish", name = "Solid Gold", rarity = "legendary", look = { finish = "gold" } },
	{ id = "fin_crystal", category = "finish", name = "Crystal", rarity = "legendary", look = { finish = "crystal" } },
	{ id = "fin_glow", category = "finish", name = "Glowstone", rarity = "mythic", look = { finish = "glow" } },
	{ id = "fin_royal", category = "finish", name = "Royal", rarity = "legendary", source = "vip", look = { finish = "royal" } },
	{ id = "fin_admiralty", category = "finish", name = "Admiralty", rarity = "legendary", source = "captain", look = { finish = "admiralty" } },

	-------------------------------------------------------------------------
	-- Dice: how your die looks when you roll
	-- look: face, face2, pip, edge, gradient, spin
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
		look = { face = "#0B0B12", face2 = "#1A1A2E", pip = "#39FF14", edge = "#39FF14" } },
	{ id = "dice_frost", category = "dice", name = "Frost", rarity = "epic",
		look = { face = "#E0FBFC", face2 = "#98C1D9", pip = "#3D5A80", edge = "#FFFFFF" } },
	{ id = "dice_gold", category = "dice", name = "Golden", rarity = "legendary",
		look = { face = "#FFE066", face2 = "#D4A017", pip = "#5C3D00", edge = "#FFF3B0" } },
	{ id = "dice_doubloon", category = "dice", name = "Golden Doubloon", rarity = "legendary", source = "captain",
		look = { face = "#F5B700", face2 = "#C98F00", pip = "#1C1A24", edge = "#FFE7A3" } },
	{ id = "dice_cosmic", category = "dice", name = "Cosmic", rarity = "mythic",
		look = { gradient = true, face = "#240046", face2 = "#7B2CBF", pip = "#FFFFFF", edge = "#E0AAFF", spin = true } },

	-------------------------------------------------------------------------
	-- Trails: little particles that follow your character as it hops
	-- look: kind (its particles: art/trails.py draws trails/<kind>_<n>), color, color2
	-- (for the plainer particles drawn when the art can't be had)
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
	{ id = "trail_shells", category = "trail", name = "Seashells", rarity = "common",
		look = { kind = "shell", color = "#F7A8B8", color2 = "#F3E2C3" } },
	{ id = "trail_confetti", category = "trail", name = "Confetti", rarity = "common",
		look = { kind = "confetti", color = "#FF5E7A", color2 = "#4FC3FF" } },
	{ id = "trail_feathers", category = "trail", name = "Parrot Feathers", rarity = "rare",
		look = { kind = "feather", color = "#E5383B", color2 = "#2F7FD0" } },
	{ id = "trail_snow", category = "trail", name = "Snowflakes", rarity = "rare",
		look = { kind = "snow", color = "#DDF3FF" } },
	{ id = "trail_blossom", category = "trail", name = "Cherry Blossoms", rarity = "rare",
		look = { kind = "blossom", color = "#FFC2D6" } },
	{ id = "trail_ink", category = "trail", name = "Kraken Ink", rarity = "rare",
		look = { kind = "ink", color = "#3A2E5C" } },
	{ id = "trail_paws", category = "trail", name = "Paw Prints", rarity = "rare",
		look = { kind = "paw", color = "#6B4A32" } },
	{ id = "trail_fireflies", category = "trail", name = "Fireflies", rarity = "epic",
		look = { kind = "firefly", color = "#E8FF7A" } },
	{ id = "trail_shanty", category = "trail", name = "Sea Shanty", rarity = "epic",
		look = { kind = "note", color = "#3B3552" } },
	{ id = "trail_wisps", category = "trail", name = "Ghost Wisps", rarity = "epic",
		look = { kind = "wisp", color = "#F4F7FB", color2 = "#7FD8FF" } },
	{ id = "trail_doubloons", category = "trail", name = "Doubloons", rarity = "legendary",
		look = { kind = "coin", color = "#F5C14B" } },
	{ id = "trail_jewels", category = "trail", name = "Jewels", rarity = "legendary",
		look = { kind = "gem", color = "#E23A4E", color2 = "#3C7FE8" } },
	{ id = "trail_thunder", category = "trail", name = "Thunder", rarity = "legendary",
		look = { kind = "bolt", color = "#FFE14D" } },
	-- landed by filling half the fish log (Meta/Fishing)
	{ id = "trail_school", category = "trail", name = "Fish School", rarity = "legendary", source = "fishing",
		look = { kind = "fishy", color = "#FF9F43", color2 = "#4FA3FF" } },

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
	-- Titles: shown under your name, each on its own plate (CosmeticArt.title draws
	-- look.plate, with the badge look.icon from art/ui.py beside the words). Some come
	-- from chests, some from passes, and the deeds are earned by doing them
	-- (deed = { stat, goal, text }: a lifetime count in your profile's stats).
	-------------------------------------------------------------------------
	{ id = "title_none", category = "title", name = "No Title", rarity = "common", source = "default", look = { text = "", color = "#FFFFFF" } },
	{ id = "title_rookie", category = "title", name = "Landlubber", rarity = "common", look = { text = "Landlubber", color = "#E8D9B5", plate = "scroll", icon = "rules" } },
	{ id = "title_hopper", category = "title", name = "Deckhand", rarity = "common", look = { text = "Deckhand", color = "#C99563", plate = "plank", icon = "anchor" } },
	{ id = "title_setter", category = "title", name = "Bilge Rat", rarity = "common", look = { text = "Bilge Rat", color = "#8A909C", plate = "iron", icon = "barrel" } },
	{ id = "title_lucky", category = "title", name = "Lucky Doubloon", rarity = "rare", look = { text = "Lucky Doubloon", color = "#D9A441", plate = "brass", icon = "coin" } },
	{ id = "title_sneaky", category = "title", name = "Fog Walker", rarity = "rare", look = { text = "Fog Walker", color = "#7CFFC4", plate = "ghost", icon = "ghost" } },
	{ id = "title_frost", category = "title", name = "Frostbeard", rarity = "rare", look = { text = "Frostbeard", color = "#CFEFFF", plate = "ice", icon = "snowflake" } },
	{ id = "title_tamer", category = "title", name = "Grog Tamer", rarity = "epic", look = { text = "Grog Tamer", color = "#3E9F5B", plate = "glass", icon = "bottle" } },
	{ id = "title_siren", category = "title", name = "Siren of the Shoals", rarity = "epic", look = { text = "Siren of the Shoals", color = "#F49AB8", plate = "coral", icon = "shell" } },
	{ id = "title_warlord", category = "title", name = "Scourge of the Seas", rarity = "epic", look = { text = "Scourge of the Seas", color = "#FF8A1C", plate = "flame", icon = "swords" } },
	{ id = "title_legend", category = "title", name = "Dread Pirate", rarity = "legendary", look = { text = "Dread Pirate", color = "#EDE6D3", plate = "bone", icon = "skull" } },
	{ id = "title_royalty", category = "title", name = "Treasure Royalty", rarity = "mythic", look = { text = "Treasure Royalty", color = "#F07CB0", plate = "royal", icon = "crown", rainbow = true } },
	{ id = "title_vip", category = "title", name = "VIP", rarity = "legendary", source = "vip", look = { text = "VIP", color = "#F5B700", plate = "gold", icon = "star" } },
	{ id = "title_captain", category = "title", name = "Captain", rarity = "legendary", source = "captain", look = { text = "Captain", color = "#2B4C7E", plate = "navy", icon = "locker" } },
	-- landed by filling the whole fish log (Meta/Fishing)
	{ id = "title_angler", category = "title", name = "Master Angler", rarity = "legendary", source = "fishing", look = { text = "Master Angler", color = "#4FC3FF", plate = "sea", icon = "hook" } },
	-- deeds
	{ id = "title_seadog", category = "title", name = "Sea Dog", rarity = "common", source = "deed", deed = { stat = "games", goal = 25, text = "Play 25 matches" },
		look = { text = "Sea Dog", color = "#9C8F7E", plate = "driftwood", icon = "settings" } },
	{ id = "title_hunter", category = "title", name = "Treasure Hunter", rarity = "rare", source = "deed", deed = { stat = "wins", goal = 10, text = "Win 10 matches" },
		look = { text = "Treasure Hunter", color = "#C8443A", plate = "ribbon", icon = "compass" } },
	{ id = "title_hoarder", category = "title", name = "Hoarder of Gold", rarity = "epic", source = "deed", deed = { stat = "treasures", goal = 25, text = "Reach the treasure 25 times" },
		look = { text = "Hoarder of Gold", color = "#CD7F45", plate = "bronze", icon = "chest" } },
	{ id = "title_bonker", category = "title", name = "Bonkmaster", rarity = "rare", source = "deed", deed = { stat = "bonks", goal = 50, text = "Bonk 50 rivals" },
		look = { text = "Bonkmaster", color = "#5E9C8A", plate = "verdigris", icon = "cannonball" } },
	{ id = "title_snarer", category = "title", name = "Trap Lord", rarity = "epic", source = "deed", deed = { stat = "gotchas", goal = 25, text = "Catch rivals in your traps 25 times" },
		look = { text = "Trap Lord", color = "#7A3B26", plate = "mahogany", icon = "trap" } },
	{ id = "title_rigger", category = "title", name = "Master Rigger", rarity = "rare", source = "deed", deed = { stat = "placed", goal = 100, text = "Set 100 traps and pieces" },
		look = { text = "Master Rigger", color = "#D9B77A", plate = "map", icon = "party" } },
	{ id = "title_plank", category = "title", name = "Walked the Plank", rarity = "common", source = "deed", deed = { stat = "deaths", goal = 25, text = "Get sent back to the start 25 times" },
		look = { text = "Walked the Plank", color = "#2F8FD0", plate = "tide", icon = "wave" } },
	{ id = "title_admiral", category = "title", name = "Fleet Admiral", rarity = "legendary", source = "deed", deed = { stat = "wins", goal = 50, text = "Win 50 matches" },
		look = { text = "Fleet Admiral", color = "#C9D3E6", plate = "silver", icon = "watch" } },
}

-- Mastery titles: "Mage Fan", "Mage Pro", "Mage Legend"... earned by playing a character
-- (ids match Progress.masteryTitleId)
local masteryColors = {
	mage = "#45C3FF",
	trapper = "#E8893A",
	fire_starter = "#FF4F5E",
	naturalist = "#8BE04E",
	warper = "#9A6BFF",
	overseer = "#FFD23F",
	gambler = "#3FD6C8",
	cannoneer = "#D99A5B",
}
local masteryNames = {
	mage = "Mage",
	trapper = "Trapper",
	fire_starter = "Fire Starter",
	naturalist = "Naturalist",
	warper = "Warper",
	overseer = "Overseer",
	gambler = "Gambler",
	cannoneer = "Cannoneer",
}
for _, charId in { "mage", "trapper", "fire_starter", "naturalist", "warper", "overseer", "gambler", "cannoneer" } do
	for _, tier in { { "fan", "Fan", "rare" }, { "pro", "Pro", "epic" }, { "legend", "Legend", "legendary" } } do
		local text = masteryNames[charId] .. " " .. tier[2]
		table.insert(defs, {
			id = "title_" .. charId .. "_" .. tier[1],
			category = "title",
			name = text,
			rarity = tier[3],
			source = "mastery",
			look = {
				text = text,
				color = masteryColors[charId],
				plate = ({ fan = "scroll", pro = "brass", legend = "gold" })[tier[1]],
				emblem = charId,
				rainbow = tier[1] == "legend" or nil,
			},
		})
	end
end

--[[
	Emblems: the badge that stands for a character on their cards, chips and results (no
	faces: a symbol of theirs). Each character has three, each a different design in a
	different colour scheme, worn per character (your Mage can wear the Golden Moon
	while your Trapper keeps the Bear Trap). Classic is the one everyone has; the Ghost
	Crew is in Treasure Chests; Gilded comes with character mastery
	(Progress.EmblemMastery). art/emblems.py draws them: emblems/<character>_<set>.
]]
Cosmetics.emblemSets = {
	{ id = "classic", name = "Classic", rarity = "common", source = "default" },
	{ id = "ghost", name = "Ghost Crew", rarity = "epic" },
	{ id = "gilded", name = "Gilded", rarity = "legendary", source = "mastery" },
}
-- each emblem's symbol: classic, Ghost Crew, Gilded
local emblemNames = {
	mage = { "Snowflake", "Ghost Crystal", "Golden Moon" },
	trapper = { "Bear Trap", "Ghost Lasso", "Golden Star" },
	fire_starter = { "Flame", "Ghost Match", "Golden Rocket" },
	naturalist = { "Sprout", "Ghost Paw", "Golden Feather" },
	warper = { "Spiral", "Ghost Hourglass", "Golden Comet" },
	overseer = { "Spyglass", "Ghost Eye", "Golden Wheel" },
	gambler = { "Dice", "Ghost Spade", "Golden Chip" },
	cannoneer = { "Cannonball", "Ghost Cannon", "Golden Burst" },
}
for _, charId in { "mage", "trapper", "fire_starter", "naturalist", "warper", "overseer", "gambler", "cannoneer" } do
	for i, set in Cosmetics.emblemSets do
		table.insert(defs, {
			id = "emblem_" .. charId .. "_" .. set.id,
			category = "emblem",
			character = charId,
			set = set.id,
			name = emblemNames[charId][i],
			rarity = set.rarity,
			source = set.source,
			look = { emblem = if set.id == "classic" then charId else (charId .. ":" .. set.id) },
		})
	end
end

-- Season titles: "Season 3 Gold"... for the best rank reached in a ranked season (ids
-- match Progress.seasonTitleId; the Locker only shows the ones you've won)
for season = 1, 24 do
	for _, r in {
		{ "bronze", "Bronze", "common", "#E0874A" },
		{ "silver", "Silver", "rare", "#C9D3E6" },
		{ "gold", "Gold", "epic", "#FFD23F" },
		{ "diamond", "Diamond", "legendary", "#45C3FF" },
		{ "legend", "Legend", "mythic", "#FF6FB8" },
	} do
		local text = "Season " .. season .. " " .. r[2]
		table.insert(defs, {
			id = "title_s" .. season .. "_" .. r[1],
			category = "title",
			name = text,
			rarity = r[3],
			source = "season",
			hidden = true,
			look = {
				text = text,
				color = r[4],
				plate = ({ bronze = "bronze", silver = "silver", gold = "gold", diamond = "ice", legend = "royal" })[r[1]],
				icon = "leaders",
				rainbow = r[1] == "legend" or nil,
			},
		})
	end
end

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
	finish = "fin_paint",
	dice = "dice_ivory",
	trail = "trail_none",
	title = "title_none",
	emotes = { "emote_gg", "emote_nice", "emote_oops" },
}

function Cosmetics.get(id: string)
	return Cosmetics.byId[id]
end

-- The emblem `character` wears in `emblems` ([character] = emblem id; Classic if none).
function Cosmetics.emblemOf(emblems: { [string]: string }?, character: string): string
	local id = emblems and emblems[character]
	local def = id and Cosmetics.byId[id]
	if def and def.category == "emblem" and def.character == character then
		return id :: string
	end
	return "emblem_" .. character .. "_classic"
end

--[[
	Portrait outfits became emblems: each outfit owned is the emblem of the same set
	("outfit_mage_ghost" -> "emblem_mage_ghost"), and what each character wore, what
	they wear now. Returns nothing (no refunds: every outfit has its emblem).
]]
function Cosmetics.migrateOutfits(owned: { [string]: boolean }, equipped: { [string]: any })
	for id in table.clone(owned) do
		local rest = string.match(id, "^outfit_(.+)$")
		if rest then
			owned[id] = nil
			if Cosmetics.byId["emblem_" .. rest] then
				owned["emblem_" .. rest] = true
			end
		end
	end
	if type(equipped.outfits) == "table" then
		equipped.emblems = equipped.emblems or {}
		for character, id in equipped.outfits do
			local rest = type(id) == "string" and string.match(id, "^outfit_(.+)$")
			if rest and Cosmetics.byId["emblem_" .. rest] and equipped.emblems[character] == nil then
				equipped.emblems[character] = "emblem_" .. rest
			end
		end
	end
	equipped.outfits = nil
end

-- The pawn skins that accessories replaced, by rarity: saves that own them get the
-- duplicate refund in Gems instead (DataService).
Cosmetics.retired = {
	pawn_pebble = "common",
	pawn_mint = "common",
	pawn_sunset = "common",
	pawn_ocean = "common",
	pawn_moss = "common",
	pawn_ruby = "rare",
	pawn_emerald = "rare",
	pawn_checker = "rare",
	pawn_candy = "rare",
	pawn_bee = "rare",
	pawn_galaxy = "epic",
	pawn_lava = "epic",
	pawn_frost = "epic",
	pawn_toxic = "epic",
	pawn_gold = "legendary",
	pawn_phoenix = "legendary",
	pawn_void = "legendary",
	pawn_prism = "mythic",
	pawn_crest = "mythic",
}

-- The accessory packs that finishes replaced: the finish each one became, and its
-- rarity (a second pack that became the same finish is paid back as a duplicate of that
-- rarity: DataService).
Cosmetics.retiredPacks = {
	acc_none = { "fin_paint" },
	acc_gentleman = { "fin_oak", "common" },
	acc_deckhand = { "fin_clay", "common" },
	acc_beach = { "fin_pearl", "common" },
	acc_cook = { "fin_oak", "common" },
	acc_captain = { "fin_marble", "rare" },
	acc_parrot = { "fin_glass", "rare" },
	acc_diver = { "fin_porcelain", "rare" },
	acc_lookout = { "fin_marble", "rare" },
	acc_propeller = { "fin_metallic", "epic" },
	acc_gloomy = { "fin_obsidian", "epic" },
	acc_oldsalt = { "fin_metallic", "epic" },
	acc_nightwatch = { "fin_obsidian", "epic" },
	acc_kraken = { "fin_crystal", "legendary" },
	acc_ghost = { "fin_crystal", "legendary" },
	acc_kingpin = { "fin_gold", "legendary" },
	acc_cannon = { "fin_glow", "mythic" },
	acc_gulls = { "fin_glow", "mythic" },
	acc_royal = { "fin_royal" },
	acc_admiralty = { "fin_admiralty" },
}

--[[
	A save's accessory packs become finishes: `owned` loses the packs and gains what they
	became, and the finish worn is the one the worn pack became. A pack that became a
	finish already owned is paid back as a duplicate of its rarity (`refund`: rarity ->
	Gems). Returns the Gems to add.
]]
function Cosmetics.migratePacks(owned: { [string]: boolean }, equipped: { [string]: any }, refund: { [string]: number }): number
	local gems = 0
	for id, to in Cosmetics.retiredPacks do
		if owned[id] then
			owned[id] = nil
			if owned[to[1]] then
				gems += refund[to[2] or ""] or 0
			else
				owned[to[1]] = true
			end
		end
	end
	local worn = Cosmetics.retiredPacks[equipped.accessory or ""]
	if worn then
		equipped.finish = worn[1]
	end
	equipped.accessory = nil
	return gems
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
