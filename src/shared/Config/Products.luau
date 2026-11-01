--!strict
-- Gamepasses and developer products. After creating them in the Creator Dashboard, paste each numeric id into
-- Id below (README.md lists exact names, prices and descriptions). Price is only a display fallback: the shop
-- shows the live Robux price from MarketplaceService once an id is set.

export type Pass = {
	Key: string,
	Id: number,
	Name: string,
	Price: number,
	Icon: string,
	Description: string,
}

export type Product = {
	Key: string,
	Id: number,
	Name: string,
	Price: number,
	Icon: string,
	Description: string,
	Category: string, -- "Boost" | "Cash" | "Server" | "Hidden"
	Random: boolean, -- paid random item: odds must be shown, hidden where restricted
}

local passes: { Pass } = {
	{
		Key = "VIP",
		Id = 0,
		Name = "VIP",
		Price = 249,
		Icon = "👑",
		Description = "+25% cash, +10% luck, VIP name tag and a free Overcharge every day",
	},
	{
		Key = "DoubleCash",
		Id = 0,
		Name = "2x Cash",
		Price = 399,
		Icon = "💸",
		Description = "Double all cash from your brainrots, forever",
	},
	{
		Key = "AutoCollect",
		Id = 0,
		Name = "Auto Collect",
		Price = 149,
		Icon = "🧲",
		Description = "Cash goes straight to your wallet - no pads to touch",
	},
	{
		Key = "DoubleWave",
		Id = 0,
		Name = "Double Wave",
		Price = 499,
		Icon = "👯",
		Description = "TWO brainrots march to your base every wave",
	},
	{
		Key = "SuperCrystal",
		Id = 0,
		Name = "Super Crystal",
		Price = 299,
		Icon = "💎",
		Description = "+25% crystal power forever",
	},
	{
		Key = "Fortress",
		Id = 0,
		Name = "Fortress Door",
		Price = 199,
		Icon = "🏰",
		Description = "+50% door strength and 2x faster repairs",
	},
}

local products: { Product } = {
	{
		Key = "Overcharge1",
		Id = 0,
		Name = "Overcharge",
		Price = 19,
		Icon = "⚡",
		Description = "+50% crystal power for one wave",
		Category = "Boost",
		Random = false,
	},
	{
		Key = "Overcharge5",
		Id = 0,
		Name = "Overcharge x5",
		Price = 79,
		Icon = "⚡",
		Description = "5 Overcharges (+50% crystal power each)",
		Category = "Boost",
		Random = false,
	},
	{
		Key = "IronDoor",
		Id = 0,
		Name = "Iron Door",
		Price = 35,
		Icon = "🛡️",
		Description = "Your door can't break for 5 minutes",
		Category = "Boost",
		Random = false,
	},
	{
		Key = "LuckyWave",
		Id = 0,
		Name = "Lucky Wave",
		Price = 49,
		Icon = "🍀",
		Description = "Your next brainrot is from your top rarity or better and is guaranteed to be beamed",
		Category = "Boost",
		Random = true,
	},
	{
		Key = "InstantRepair",
		Id = 0,
		Name = "Instant Repair",
		Price = 15,
		Icon = "🔧",
		Description = "Fix your broken door right now",
		Category = "Hidden",
		Random = false,
	},
	{
		Key = "ServerLuck",
		Id = 0,
		Name = "Server Luck",
		Price = 99,
		Icon = "🍀",
		Description = "2x luck for EVERYONE in the server for 15 minutes (your name is announced)",
		Category = "Server",
		Random = false,
	},
	{
		Key = "CashSmall",
		Id = 0,
		Name = "Cash Bag",
		Price = 29,
		Icon = "💵",
		Description = "15 minutes of your income",
		Category = "Cash",
		Random = false,
	},
	{
		Key = "CashMedium",
		Id = 0,
		Name = "Cash Stack",
		Price = 99,
		Icon = "💰",
		Description = "1 hour of your income",
		Category = "Cash",
		Random = false,
	},
	{
		Key = "CashLarge",
		Id = 0,
		Name = "Cash Vault",
		Price = 299,
		Icon = "🏦",
		Description = "5 hours of your income",
		Category = "Cash",
		Random = false,
	},
	{
		Key = "DoubleOffline",
		Id = 0,
		Name = "Double Offline Cash",
		Price = 29,
		Icon = "🌙",
		Description = "Doubles the cash your brainrots made while you were away",
		Category = "Hidden",
		Random = false,
	},
}

-- Cash pack sizes: seconds of current income and the minimum amount.
local cashPacks: { [string]: { Seconds: number, Floor: number } } = {
	CashSmall = { Seconds = 15 * 60, Floor = 5000 },
	CashMedium = { Seconds = 60 * 60, Floor = 25000 },
	CashLarge = { Seconds = 5 * 60 * 60, Floor = 150000 },
}

local passByKey: { [string]: Pass } = {}
local passById: { [number]: Pass } = {}
for _, pass in passes do
	passByKey[pass.Key] = pass
	if pass.Id ~= 0 then
		passById[pass.Id] = pass
	end
end

local productByKey: { [string]: Product } = {}
local productById: { [number]: Product } = {}
for _, product in products do
	productByKey[product.Key] = product
	if product.Id ~= 0 then
		productById[product.Id] = product
	end
end

local Products = {
	Passes = passes,
	Products = products,
	PassByKey = passByKey,
	PassById = passById,
	ProductByKey = productByKey,
	ProductById = productById,
	CashPacks = cashPacks,
	-- Optional: your Roblox group id. Members get a daily bonus; 0 disables the group reward.
	GroupId = 0,
}

return Products
