--[[
	CardStyle
	Layout of the carved wooden cards (fractions of the card's width/height), shared by
	the in-game Cards widget and the offline previewer.
]]

local CardStyle = {}

CardStyle.aspect = 0.72 -- width / height
CardStyle.corner = 0.09 -- corner radius, fraction of width

-- painted category band across the top
CardStyle.band = { y = 0.045, h = 0.13, inset = 0.06 }
-- carved icon in the middle
CardStyle.icon = { cx = 0.5, cy = 0.47, size = 0.6 }
-- paper name strip near the bottom
CardStyle.plate = { x = 0.09, y = 0.77, w = 0.82, h = 0.15 }

-- Wood grain strokes (normalized card space: x across, y down)
CardStyle.grain = {
	{ { 0.14, 0.24 }, { 0.3, 0.27 }, { 0.5, 0.25 }, { 0.7, 0.28 }, { 0.86, 0.26 } },
	{ { 0.1, 0.36 }, { 0.32, 0.34 }, { 0.46, 0.37 }, { 0.66, 0.35 }, { 0.9, 0.37 } },
	{ { 0.1, 0.6 }, { 0.26, 0.62 }, { 0.48, 0.6 }, { 0.68, 0.63 }, { 0.9, 0.61 } },
	{ { 0.14, 0.7 }, { 0.36, 0.69 }, { 0.58, 0.71 }, { 0.86, 0.69 } },
}
CardStyle.knot = { cx = 0.78, cy = 0.66, w = 0.12, h = 0.05 }

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
