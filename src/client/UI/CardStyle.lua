--[[
	CardStyle
	Layout of Trapisque's sticker cards (fractions of the card's width/height), shared by
	the in-game Cards widget and the offline previewer.

	A card is a candy-coloured slab in its category's colour with the dark outline, the
	category name across the top, the illustration in a cream window with a sunburst
	behind it, and the name in outlined lettering along the bottom.
]]

local CardStyle = {}

CardStyle.aspect = 0.72 -- width / height
CardStyle.corner = 0.1 -- corner radius, fraction of width
CardStyle.outline = 0.035 -- the dark outline, fraction of width
CardStyle.lip = 0.035 -- the darker edge under the card (its thickness), fraction of height

-- category name along the top (fractions of width / height)
CardStyle.tag = { y = 0.075, h = 0.075 }
-- the cream window the art sits in
CardStyle.window = { x = 0.08, y = 0.13, w = 0.84, h = 0.6, corner = 0.12 }
-- the art itself, centred in the window (size: fraction of the card's width)
CardStyle.icon = { cx = 0.5, cy = 0.43, size = 0.7 }
-- the name along the bottom
CardStyle.name = { y = 0.845, h = 0.12 }
-- sunburst rays behind the art
CardStyle.rays = 10

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
