--[[
	CardStyle
	Layout of Trapisque's cards (fractions of the card's width/height), shared by the
	in-game Cards widget and the offline previewer.

	A card is white card stock with a band of its category's colour across the top
	holding its name, the illustration on a light tint of that colour, and what kind of
	card it is in small letters along the bottom. A thin edge of darker stock shows
	under it.
]]

local CardStyle = {}

CardStyle.aspect = 0.72 -- width / height
CardStyle.corner = 0.08 -- corner radius, fraction of width
CardStyle.outline = 0.02 -- the border in the category's colour, fraction of width
CardStyle.lip = 0.025 -- the darker edge under the card (its thickness), fraction of height

-- the coloured band with the name (fractions of height)
CardStyle.band = { h = 0.19 }
-- the name in the band
CardStyle.name = { y = 0.095, h = 0.12 }
-- the tinted window the art sits in
CardStyle.window = { x = 0.07, y = 0.235, w = 0.86, h = 0.6, corner = 0.1 }
-- the art itself, centred in the window (size: fraction of the card's width)
CardStyle.icon = { cx = 0.5, cy = 0.535, size = 0.66 }
-- the kind of card, along the bottom
CardStyle.tag = { y = 0.915, h = 0.06 }

-- Text sizes as a fraction of the card's width: the same on every card, stepping
-- down only when a line doesn't fit (Cards.lua cardText)
CardStyle.text = {
	name = 0.14,
	tag = 0.075,
	title = 0.15,
	header = 0.065,
	body = 0.08,
	footer = 0.06,
}

-- How each kind of card is played (shown on the back and in the card tip)
CardStyle.useText = {
	place = "Place it within 5 tiles of you",
	hide = "Hide it within 5 tiles of you",
	boost = "Play it, then pick your die",
	passive = "Works by itself from your hand",
	juice = "Play it to fill your Power",
	reroll = "Play it to roll again",
	compass = "Play it, then set a die",
	steal = "Play it on your turn",
	anchor = "Drop it now, warp back later",
	telepathy = "Play it on your turn",
	jeopardy = "Play it on your turn",
	xray = "Play it on your turn",
	none = "",
}

-- The line for a card: hidden traps say "Hide", everything else uses its kind.
function CardStyle.howToPlay(def): string
	if def.price then
		return def.price .. (if def.price == 1 then " coin" else " coins") .. " at the Potion Seller"
	end
	if def.use == "place" and def.hidden then
		return CardStyle.useText.hide
	end
	return CardStyle.useText[def.use] or ""
end

return CardStyle
