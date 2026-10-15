-- Dumps everything tools/preview/cards.py needs to draw the sticker cards the way
-- client/UI/Cards.lua builds them: every item and character, the card layout
-- (CardStyle), the card art and mascots (StickerArt) and the palette (Theme).
-- Bundle after tests/preview_skins.luau.
local Items = requireModule("Shared/Game/Items")
local Characters = requireModule("Shared/Game/Characters")
local CardStyle = requireModule("Client/UI/CardStyle")
local StickerArt = requireModule("Client/UI/StickerArt")
local Theme = PreviewTheme()

local items = {}
for _, def in Items.list do
	table.insert(items, {
		id = def.id,
		name = def.name,
		category = def.category,
		use = def.use,
		hidden = def.hidden == true,
		text = def.text,
		price = def.price or 0,
		-- the line on the back and in the card tip (CardStyle.howToPlay)
		how = CardStyle.howToPlay(def),
	})
end
local chars = {}
local mascots = {}
for _, c in Characters.list do
	table.insert(chars, {
		id = c.id,
		name = c.name,
		tagline = c.tagline,
		passiveName = c.passiveName or "Passive",
		passive = c.passive,
		ability = if c.ability then { name = c.ability.name, text = c.ability.text, cost = c.ability.cost } else false,
	})
	mascots[c.id] = StickerArt.mascot(c.id)
end
local style = {}
for k, v in CardStyle do
	if type(v) ~= "function" then
		style[k] = v
	end
end
print(PreviewJson({
	items = items,
	characters = chars,
	style = style,
	art = StickerArt.cards,
	mascots = mascots,
	theme = Theme,
}))
