--[[
	CardStyle
	Layout of the carved wooden cards (fractions of the card's width/height), shared by
	the in-game Cards widget and the offline previewer.
]]

local CardStyle = {}

CardStyle.aspect = 0.72 -- width / height
CardStyle.corner = 0.09 -- corner radius, fraction of width

-- Everything sits inside the carved frame with the same margin all round:
-- frame inset 0.045 of the width, content inset 0.08 of the width (0.0576 of the height).
CardStyle.frameInset = 0.045
-- painted category band across the top (fractions of width / height)
CardStyle.band = { y = 0.0576, h = 0.13, inset = 0.08 }
-- burned-in symbol, centred between the band and the name strip
CardStyle.icon = { cx = 0.5, cy = 0.4925, size = 0.6 }
-- paper name strip along the bottom
CardStyle.plate = { x = 0.08, y = 0.7974, w = 0.84, h = 0.145 }

-- Wood grain: one long stroke in the open strip above the symbol and one below it
-- (normalized card space: x across, y down), so no grain runs under anything.
CardStyle.grain = {
	{ { 0.12, 0.236 }, { 0.32, 0.226 }, { 0.52, 0.24 }, { 0.72, 0.228 }, { 0.88, 0.236 } },
	{ { 0.12, 0.752 }, { 0.3, 0.762 }, { 0.5, 0.748 }, { 0.7, 0.76 }, { 0.88, 0.752 } },
}

-- Text sizes as a fraction of the card's width: the same on every card, stepping
-- down only when a line doesn't fit (Cards.lua cardText)
CardStyle.text = {
	plate = 0.12,
	title = 0.15,
	tag = 0.06,
	header = 0.06,
	body = 0.078,
	footer = 0.056,
}

-- How each kind of card is played (shown on the back)
CardStyle.useText = {
	place = "Place it on a tile (uses your turn)",
	boost = "Free: arm it before you roll",
	passive = "Works automatically",
	regen = "Free: use any time on your turn",
	anchor = "Free: drop it, recall later",
	moonwalk = "Uses your turn",
	telepathy = "Uses your turn",
	jeopardy = "Uses your turn",
	none = "",
}

-- Wood tones per category (front of the card)
CardStyle.wood = {
	trap = { "#C08852", "#A26B3A" },
	assist = { "#C9925A", "#A97441" },
	neutral = { "#BC8957", "#9B6C42" },
	potion = { "#CD9A60", "#AC7A45" },
	natural = { "#BF8D59", "#9D7046" },
	coin = { "#C9925A", "#A97441" },
	character = { "#C38B53", "#A06A38" },
}

return CardStyle
