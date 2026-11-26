--[[
	Robux products. Create each one under Creator Dashboard > (your experience)
	> Monetization > Developer Products, then paste its ID below.
	An ID of 0 hides that product from the shop, so you can launch with only
	some of them.

	Design rules (kept on purpose):
	  * impulse buys only: cosmetics, birds, coin packs, revives. No 2x/VIP.
	  * nothing gives an edge in Versus (birds are sidegrades, revives are
	    Solo/co-op only)
	  * no paid random crates
]]

local Products = {}

Products.Ids = {
	-- coin packs
	Coins_Small = 0, -- suggested R$25
	Coins_Medium = 0, -- suggested R$49
	Coins_Large = 0, -- suggested R$99
	Coins_Huge = 0, -- suggested R$199

	-- keep your run going (Solo / Bot Buddy / Couch Co-op / Duos only)
	Revive = 0, -- suggested R$15

	-- bundle
	StarterPack = 0, -- suggested R$99

	-- bird unlocks (also unlockable with coins)
	Bird_zippy = 0, -- suggested R$49
	Bird_blinky = 0,
	Bird_puffin = 0,
	Bird_pecky = 0,
	Bird_hoot = 0, -- suggested R$69
	Bird_flippy = 0,
	Bird_honk = 0, -- suggested R$79

	-- exclusives (Robux only)
	Color_rainbow = 0, -- suggested R$49
	Color_holo = 0,
	Pattern_galaxy = 0, -- suggested R$59
	Hat_goldcrown = 0, -- suggested R$79
	Hat_dragon = 0,
	Death_firework = 0, -- suggested R$99
	Death_rubberduck = 0,
}

-- What each product grants
Products.Grants = {
	Coins_Small = { coins = 500, title = "Pouch of Coins", desc = "500 coins" },
	Coins_Medium = { coins = 1500, title = "Bag of Coins", desc = "1,500 coins" },
	Coins_Large = { coins = 4000, title = "Chest of Coins", desc = "4,000 coins" },
	Coins_Huge = { coins = 10000, title = "Vault of Coins", desc = "10,000 coins" },
	Revive = { revive = 1, title = "Revive", desc = "Back in the air with 2 lives each" },
	StarterPack = {
		coins = 1500,
		birds = { "zippy" },
		items = { { "hat", "goldcrown" }, { "death", "firework" } },
		title = "Starter Pack",
		desc = "Zippy + Golden Crown + Firework Finale + 1,500 coins",
	},
	Bird_zippy = { birds = { "zippy" }, title = "Zippy" },
	Bird_blinky = { birds = { "blinky" }, title = "Blinky" },
	Bird_puffin = { birds = { "puffin" }, title = "Puff" },
	Bird_pecky = { birds = { "pecky" }, title = "Pecky" },
	Bird_hoot = { birds = { "hoot" }, title = "Hoot" },
	Bird_flippy = { birds = { "flippy" }, title = "Flippy" },
	Bird_honk = { birds = { "honk" }, title = "Honk" },
	Color_rainbow = { items = { { "color", "rainbow" } }, title = "Rainbow" },
	Color_holo = { items = { { "color", "holo" } }, title = "Holo Shimmer" },
	Pattern_galaxy = { items = { { "pattern", "galaxy" } }, title = "Galaxy" },
	Hat_goldcrown = { items = { { "hat", "goldcrown" } }, title = "Golden Crown" },
	Hat_dragon = { items = { { "hat", "dragon" } }, title = "Dragon Horns" },
	Death_firework = { items = { { "death", "firework" } }, title = "Firework Finale" },
	Death_rubberduck = { items = { { "death", "rubberduck" } }, title = "Squeaky Duck" },
}

-- productId -> key (built once)
Products.KeyById = {}
for key, id in Products.Ids do
	if id ~= 0 then
		Products.KeyById[id] = key
	end
end

function Products.isEnabled(key: string): boolean
	return (Products.Ids[key] or 0) ~= 0
end

return Products
