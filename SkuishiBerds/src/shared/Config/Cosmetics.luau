--[[
	Cosmetics catalog. Prices are in coins (earned by playing). Items marked
	robuxOnly are exclusives sold through developer products (see Products.luau);
	everything else is earnable, and Robux is only ever a shortcut.

	Colors / patterns / hats are the exact lists from the original game.
	Death animations are new (the original only had the splat).
]]

local Cosmetics = {}

export type Item = {
	id: string,
	name: string,
	price: number,
	robuxOnly: boolean?,
	productKey: string?,
	desc: string?,
	color: string?,
}

local function c(id: string, name: string, price: number): Item
	return { id = id, name = name, price = price }
end

-- 42 original colors (+2 exclusives). Free starter set first.
Cosmetics.Colors = {
	c("#ffb3ba", "Pink", 0),
	c("#a8e6cf", "Mint", 0),
	c("#bae1ff", "Blue", 0),
	c("#ffffba", "Yellow", 0),
	c("#d4b5ff", "Purple", 0),
	c("#ffdfba", "Orange", 0),
	c("#ff9a9e", "Coral", 0),
	c("#84fab0", "Teal", 0),
	c("#c9b6e4", "Lavender", 0),
	c("#ffd1a9", "Peach", 0),
	c("#ff007f", "Hot Pink", 60),
	c("#aaff00", "Lime Green", 60),
	c("#00ffff", "Cyan", 60),
	c("#964b00", "Brown", 60),
	c("#ff0000", "Red", 60),
	c("#ffff00", "Bright Yellow", 60),
	c("#000000", "Black", 90),
	c("#00ff00", "Green", 60),
	c("#000080", "Navy", 75),
	c("#ff00ff", "Magenta", 75),
	c("#ffd700", "Gold", 150),
	c("#c0c0c0", "Silver", 120),
	c("#ff6f91", "Rose", 50),
	c("#87ceeb", "Sky", 50),
	c("#7fe7d7", "Seafoam", 50),
	c("#c3cde6", "Periwinkle", 50),
	c("#ffcc33", "Mustard", 50),
	c("#b22222", "Brick", 50),
	c("#708238", "Olive", 50),
	c("#708090", "Slate", 50),
	c("#4b0082", "Indigo", 75),
	c("#007ba7", "Cerulean", 75),
	c("#ffb6c1", "Candy", 50),
	c("#66d9cc", "Minty Teal", 50),
	c("#ffb07c", "Apricot", 50),
	c("#f7cac9", "Blush", 50),
	c("#228b22", "Forest", 75),
	c("#191970", "Midnight", 90),
	c("#ff77ff", "Bubblegum", 60),
	c("#fff5e1", "Cream", 60),
	c("#333333", "Charcoal", 75),
	c("#9ee6c6", "Mint Choco", 60),
	{ id = "rainbow", name = "Rainbow (animated)", price = 0, robuxOnly = true, productKey = "Color_rainbow" },
	{ id = "holo", name = "Holo Shimmer", price = 0, robuxOnly = true, productKey = "Color_holo" },
}

-- 18 original patterns (+1 exclusive)
Cosmetics.Patterns = {
	c("solid", "Solid", 0),
	c("spots", "Spots", 0),
	c("stripes", "Stripes", 0),
	c("stars", "Stars", 120),
	c("scales", "Scales", 150),
	c("hexagons", "Hexagons", 150),
	c("diamonds", "Diamonds", 120),
	c("camo", "Camo", 180),
	c("hearts", "Hearts", 120),
	c("mosaic", "Mosaic", 200),
	c("zigzag", "Zigzag", 120),
	c("waves", "Waves", 120),
	c("target", "Target", 100),
	c("dots", "Dots", 100),
	c("checkered", "Checkered", 150),
	c("confetti", "Confetti", 180),
	c("swirls", "Swirls", 200),
	c("triangles", "Triangles", 150),
	{ id = "galaxy", name = "Galaxy", price = 0, robuxOnly = true, productKey = "Pattern_galaxy" },
}

-- 47 original hats (+2 exclusives)
Cosmetics.Hats = {
	c("none", "None", 0),
	c("propeller", "Propeller", 0),
	c("crown", "Crown", 400),
	c("beanie", "Beanie", 0),
	c("fez", "Fez", 150),
	c("wizard", "Wizard", 300),
	c("tophat", "Top Hat", 250),
	c("pirate", "Pirate", 300),
	c("cowboy", "Cowboy", 250),
	c("bunny", "Bunny", 200),
	c("antlers", "Antlers", 250),
	c("halo", "Halo", 350),
	c("santa", "Santa", 200),
	c("visor", "Visor", 150),
	c("paperboat", "Paper Boat", 0),
	c("flower", "Flower", 150),
	c("chef", "Chef", 200),
	c("space", "Space Helmet", 400),
	c("samurai", "Samurai", 450),
	c("beret", "Beret", 150),
	c("viking", "Viking", 350),
	c("bearears", "Bear Ears", 150),
	c("headphones", "Headphones", 250),
	c("bucket", "Bucket", 150),
	c("crest", "Crest", 200),
	c("bandana", "Bandana", 150),
	c("scuba", "Scuba", 300),
	c("goggles", "Goggles", 200),
	c("saturn", "Saturn", 500),
	c("fedora", "Fedora", 250),
	c("lantern", "Lantern", 300),
	c("paperplane", "Paper Plane", 250),
	c("mechanic", "Mechanic Cap", 200),
	c("bamboo", "Bamboo Hat", 250),
	c("neonvisor", "Neon Visor", 350),
	c("flowercrown", "Flower Crown", 300),
	c("devil", "Devil Horns", 300),
	c("astro", "Astro Helm", 450),
	c("fishbowl", "Fish Bowl", 400),
	c("tv", "TV Head", 500),
	c("cone", "Cone", 150),
	c("sprout", "Sprout", 100),
	c("plunger", "Plunger", 200),
	c("brainjar", "Brain Jar", 600),
	{ id = "goldcrown", name = "Golden Crown", price = 0, robuxOnly = true, productKey = "Hat_goldcrown" },
	{ id = "dragon", name = "Dragon Horns", price = 0, robuxOnly = true, productKey = "Hat_dragon" },
}

-- Death animations (new): what happens when your last heart pops
Cosmetics.Deaths = {
	{ id = "splat", name = "Splat", price = 0, desc = "The classic paint splat, hat and all." },
	{ id = "confetti", name = "Confetti Pop", price = 250, desc = "Burst into a party." },
	{ id = "feathers", name = "Feather Burst", price = 250, desc = "A puff of floaty feathers." },
	{ id = "scribble", name = "Scribble Out", price = 350, desc = "Crossed out with angry pencil scribbles." },
	{ id = "eraser", name = "Erased", price = 400, desc = "Rubbed off the page, crumbs included." },
	{ id = "ghost", name = "Ghost Float", price = 400, desc = "Your ghost drifts up with a little halo." },
	{ id = "balloon", name = "Balloon Pop", price = 300, desc = "Inflates... inflates... POP." },
	{ id = "pixel", name = "Pixel Shatter", price = 450, desc = "Breaks into chunky pixels." },
	{ id = "paperplane", name = "Paper Plane", price = 500, desc = "Folds itself up and flies away." },
	{ id = "blackhole", name = "Implode", price = 600, desc = "Collapses into a tiny black hole." },
	{ id = "glitch", name = "Glitch Out", price = 550, desc = "RGB-splits out of existence." },
	{ id = "melt", name = "Melt", price = 350, desc = "Drips down the page." },
	{ id = "stars", name = "Starburst", price = 450, desc = "A ring of shooting stars." },
	{ id = "firework", name = "Firework Finale", price = 0, robuxOnly = true, productKey = "Death_firework", desc = "Launches up and explodes in color." },
	{ id = "rubberduck", name = "Squeaky Duck", price = 0, robuxOnly = true, productKey = "Death_rubberduck", desc = "Turns into a rubber duck. Squeak." },
} :: { Item }

Cosmetics.Categories = {
	color = Cosmetics.Colors,
	pattern = Cosmetics.Patterns,
	hat = Cosmetics.Hats,
	death = Cosmetics.Deaths,
}

Cosmetics.ById = {}
for category, list in Cosmetics.Categories do
	local map = {}
	for i, item in list do
		item.order = i
		map[item.id] = item
	end
	Cosmetics.ById[category] = map
end

function Cosmetics.get(category: string, id: string): Item?
	local map = Cosmetics.ById[category]
	return map and map[id]
end

function Cosmetics.isFree(category: string, id: string): boolean
	local item = Cosmetics.get(category, id)
	return item ~= nil and item.price == 0 and not item.robuxOnly
end

-- Default looks: the original's pink top bird and mint bottom bird
Cosmetics.DefaultLoadout = {
	bird = "berd",
	color = "#ffb3ba",
	pattern = "solid",
	patternColor = "#ffffff",
	patternAlpha = 0.6,
	hat = "none",
	death = "splat",
}

Cosmetics.DefaultLoadout2 = {
	bird = "berd",
	color = "#a8e6cf",
	pattern = "solid",
	patternColor = "#ffffff",
	patternAlpha = 0.6,
	hat = "none",
	death = "splat",
}

return Cosmetics
