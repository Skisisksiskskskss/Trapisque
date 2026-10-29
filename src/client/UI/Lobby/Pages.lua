--[[
	Pages
	The smaller lobby windows: the Shop (today's deals for Gems, free Gems for joining
	the group, the gamepasses), How to Play and Settings (volumes, chat bubbles, and the
	staff panel for staff).

		Pages.shop(popupLayer)
		Pages.rules(popupLayer)
		Pages.settings(popupLayer)
		Pages.leaderboard(popupLayer)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Passes = require(Shared.Meta.Passes)
local Characters = require(Shared.Game.Characters)
local Modes = require(Shared.Game.Modes)
local Cosmetics = require(Shared.Meta.Cosmetics)
local Config = require(Shared.Config)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Art = require(UI.Art)
local Widgets = require(UI.Widgets)
local VolumeRows = require(UI.VolumeRows)
local CosmeticArt = require(UI.CosmeticArt)
local LeaderboardPanel = require(script.Parent.LeaderboardPanel)
local StaffPanel = require(UI.StaffPanel)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)

local C = Theme.C
local hex = Theme.hex

local Pages = {}

local player = Players.LocalPlayer

---------------------------------------------------------------------------
-- Shop (gamepasses)
---------------------------------------------------------------------------

-- A card in the Shop: parchment framed in a dark shade of its colour, with a window
-- of that colour across its top (lit from above, a soft shine behind its picture).
local function shopCard(parent: Instance, name: string, color: Color3, order: number, bandH: number): (Frame, Frame)
	local card = Util.new("Frame", {
		Name = name,
		BackgroundColor3 = C.panelRaised,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	})
	Util.corner(card, 16)
	Widgets.lit(card, C.panelRaised, 0.06)
	Util.new("UIStroke", { Color = Util.shade(color, -0.5), Thickness = 3, Parent = card })
	local band = Util.new("Frame", {
		Name = "Band",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(7, 7),
		Size = UDim2.new(1, -14, 0, bandH),
		Parent = card,
	})
	Util.corner(band, 11)
	Widgets.lit(band, color, 0.22)
	Util.new("UIStroke", { Color = Util.shade(color, -0.4), Thickness = 2, Parent = band })
	-- a soft shine behind the picture
	local shine = Art.image(band, "ground/soft", {
		Name = "Shine",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.9, 1.3),
	})
	local img = shine and shine:FindFirstChild("Image") :: ImageLabel?
	if img then
		img.ImageColor3 = Color3.new(1, 1, 1)
		img.ImageTransparency = 0.45
	end
	return card, band
end

-- A picture from the art, centred in a frame (the code-drawn medallion if it hasn't loaded).
local function shopPicture(parent: Instance, picture: string?, icon: string, color: Color3, size: number, y: number?)
	local holder = Util.frame(parent, {
		Name = "Picture",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y or 0.55),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 3,
	})
	if not (picture and Art.image(holder, picture, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })) then
		Icons.medallion(holder, icon, color, { Size = UDim2.fromScale(1, 1) })
	end
	return holder
end

-- A heading between the Shop's sections.
local function shopHeading(parent: Instance, text: string, note: string?, order: number)
	local f = Util.frame(parent, { Name = "Heading_" .. text, Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order })
	Widgets.label(f, {
		text = text,
		font = "display",
		size = 26,
		color = C.text,
		sizeUDim = UDim2.new(0, 0, 1, 0),
	}).AutomaticSize = Enum.AutomaticSize.X
	if note then
		Widgets.label(f, {
			text = note,
			font = "heavy",
			size = 14,
			color = C.textSoft,
			align = "right",
			sizeUDim = UDim2.new(1, 0, 1, 0),
		})
	end
	local rule = Util.frame(f, { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2) })
	rule.BackgroundTransparency = 0
	rule.BackgroundColor3 = C.panelEdge
end

-- A section's grid of cards, as tall as its rows.
local function shopGrid(parent: Instance, name: string, cols: number, cellH: number, order: number): Frame
	local grid = Util.frame(parent, {
		Name = name,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})
	Util.new("UIGridLayout", {
		-- (a few pixels short of the row, or Roblox can wrap a cell early)
		CellSize = UDim2.new(1 / cols, -12 * (cols - 1) / cols - 4, 0, cellH),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent = grid,
	})
	return grid
end

-- Ask Roblox for a pass's or product's price and show it on its button.
local function showPrice(button, id: number, kind: Enum.InfoType)
	if id == 0 then
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, kind)
		end)
		if ok and info and info.PriceInRobux and button.root.Parent then
			button:setText("R$ " .. tostring(info.PriceInRobux))
		end
	end)
end

-- where a pile of gems sits in its card, for each size of pack: { x, y, size }
local PILES = {
	{ { 0.5, 0.55, 0.62 } },
	{ { 0.38, 0.6, 0.5 }, { 0.62, 0.5, 0.56 } },
	{ { 0.3, 0.62, 0.44 }, { 0.7, 0.62, 0.44 }, { 0.5, 0.46, 0.56 } },
	{ { 0.24, 0.66, 0.38 }, { 0.76, 0.66, 0.38 }, { 0.38, 0.48, 0.44 }, { 0.62, 0.48, 0.44 }, { 0.5, 0.62, 0.5 } },
	{ { 0.5, 0.5, 0.74, "ui/chest" }, { 0.24, 0.7, 0.36 }, { 0.76, 0.7, 0.36 }, { 0.5, 0.74, 0.4 } },
}

function Pages.shop(layer: Instance): () -> ()
	local maid = Util.maid()
	local roomW, roomH, narrow = Widgets.room()
	local width = math.min(980, roomW)
	local content, close = Widgets.modal(layer, {
		title = "Shop",
		titleWidth = 200,
		width = width,
		height = math.min(600, roomH),
		onClose = function()
			maid:clean()
		end,
	})
	task.spawn(Net.request, "shop.refresh")
	local list = Widgets.scroll(content, { gap = 14, padding = 4, hAlign = "Left" })
	local inner = width - 60
	local cols = math.max(1, math.min(4, math.floor(inner / 215)))
	local packCols = math.max(1, math.min(5, math.floor(inner / 170)))

	local cards = {}
	local function render()
		local profile = State.get("profile")
		for _, card in cards do
			card.update(profile)
		end
	end
	local profile = State.get("profile")
	local restricted = profile ~= nil and profile.restricted == true

	-- today's deals: cosmetics for Gems, no random rolls (and the free Gems for the group)
	shopHeading(list, "Today's deals", if narrow then nil else "New every day, for Gems", 1)
	local deals = shopGrid(list, "Deals", cols, 300, 2)
	for i, deal in (profile and profile.deals and profile.deals.items) or {} do
		local def = Cosmetics.get(deal.id)
		if def then
			local rarity = Cosmetics.rarityById[def.rarity]
			local color = if rarity then hex(string.sub(rarity.color, 2)) else C.sun
			local card, band = shopCard(deals, "Deal_" .. deal.id, color, i, 140)
			CosmeticArt.preview(band, deal.id, nil, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(124, 124),
				ZIndex = 3,
			})
			Widgets.label(card, {
				text = def.name,
				font = "chunky",
				size = 22,
				color = C.text,
				align = "center",
				scaled = true,
				sizeUDim = UDim2.new(1, -20, 0, 28),
				position = UDim2.fromOffset(10, 156),
			})
			Widgets.label(card, {
				text = (if rarity then rarity.name else def.rarity) .. " " .. string.lower(def.category),
				font = "heavy",
				size = 15,
				color = Util.shade(color, -0.25),
				align = "center",
				sizeUDim = UDim2.new(1, -20, 0, 20),
				position = UDim2.fromOffset(10, 186),
			})
			local buy = Widgets.button(card, {
				text = Util.commas(deal.price) .. " Gems",
				icon = "gem",
				style = "brass",
				textSize = 18,
				size = UDim2.new(1, -24, 0, 48),
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -12),
				onClick = function()
					local ok, err = Net.request("shop.deal", { id = deal.id })
					if ok then
						Widgets.toast("It's yours: " .. def.name .. "! Wear it from the LOCKER.", "reward")
					else
						Widgets.toast(tostring(err), "error")
					end
				end,
			})
			table.insert(cards, {
				update = function(p)
					local owned = p ~= nil and table.find(p.owned or {}, deal.id) ~= nil
					if owned then
						buy:setText("Owned")
						buy:setEnabled(false)
					end
				end,
			})
		end
	end
	-- free Gems for joining the group (and liking the game)
	if profile and not profile.groupReward then
		local card, band = shopCard(deals, "Community", C.mint, 5, 110)
		shopPicture(band, "ui/party", "people", C.mint, 84)
		Widgets.label(card, {
			text = "Free " .. Config.Community.Gems .. " Gems",
			font = "chunky",
			size = 22,
			color = C.text,
			align = "center",
			scaled = true,
			sizeUDim = UDim2.new(1, -20, 0, 28),
			position = UDim2.fromOffset(10, 124),
		})
		Widgets.label(card, {
			text = "Like the game and join our group, then claim. Once per player.",
			font = "body",
			size = 14,
			color = C.textSoft,
			wrap = true,
			align = "center",
			sizeUDim = UDim2.new(1, -24, 0, 40),
			position = UDim2.fromOffset(12, 154),
		})
		local function groupId(): number
			local id = Config.Community.GroupId or 0
			if id == 0 and game.CreatorType == Enum.CreatorType.Group then
				id = game.CreatorId
			end
			return id
		end
		Widgets.button(card, {
			text = "Join group",
			icon = "people",
			style = "panel",
			textSize = 16,
			size = UDim2.new(1, -24, 0, 42),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -64),
			onClick = function()
				local id = groupId()
				if id == 0 then
					Widgets.toast("There's no group to join yet.", "info")
					return
				end
				local ok = pcall(function()
					(game:GetService("GroupService") :: any):PromptJoinAsync(id)
				end)
				if not ok then
					Widgets.toast("Search for the game's group on Roblox and join it there, then claim!", "info")
				end
			end,
		})
		Widgets.button(card, {
			text = "Claim",
			icon = "gem",
			style = "green",
			textSize = 18,
			size = UDim2.new(1, -24, 0, 44),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -12),
			onClick = function()
				local ok, data = Net.request("community.claim")
				if ok then
					Widgets.toast("Welcome to the crew! +" .. tostring(data and data.gems or Config.Community.Gems) .. " Gems", "reward")
					card:Destroy()
				else
					Widgets.toast(tostring(data), "info")
				end
			end,
		})
	end

	-- Gems for Robux (not where paid random items are restricted: Gems open chests)
	if not restricted then
		shopHeading(list, "Gems", if narrow then nil else "Spend them on chests and deals", 3)
		local packs = shopGrid(list, "GemPacks", packCols, 236, 4)
		local base = Passes.gemPacks[1].gems / Passes.gemPacks[1].robux
		for i, pack in Passes.gemPacks do
			local color = hex("3FA7F5")
			local card, band = shopCard(packs, pack.key, color, i, 112)
			for _, g in PILES[pack.pile] or PILES[1] do
				local d = 100 * g[3]
				local holder = Util.frame(band, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(g[1], g[2]),
					Size = UDim2.fromOffset(d, d),
					ZIndex = 3,
				})
				if not Art.image(holder, g[4] or "ui/gem", { Size = UDim2.fromScale(1, 1), ZIndex = 3 }) then
					Icons.medallion(holder, "gem", color, { Size = UDim2.fromScale(1, 1) })
				end
			end
			if pack.badge then
				Widgets.badge(card, { text = pack.badge, color = C.orange, height = 24, textSize = 13, anchor = Vector2.new(1, 0), position = UDim2.new(1, -4, 0, -6), z = 12 })
			end
			Widgets.label(card, {
				text = Util.commas(pack.gems) .. " Gems",
				font = "chunky",
				size = 22,
				color = C.text,
				align = "center",
				sizeUDim = UDim2.new(1, -12, 0, 28),
				position = UDim2.fromOffset(6, 124),
			})
			local extra = math.floor((pack.gems / pack.robux) / base * 100 + 0.5) - 100
			Widgets.label(card, {
				text = if extra > 0 then ("+" .. extra .. "% extra") else "",
				font = "heavy",
				size = 14,
				color = C.good,
				align = "center",
				sizeUDim = UDim2.new(1, -12, 0, 18),
				position = UDim2.fromOffset(6, 152),
			})
			local id = Passes.productId(pack.key)
			local buy = Widgets.button(card, {
				text = if id == 0 then "Soon" else "Buy",
				style = "green",
				textSize = 18,
				size = UDim2.new(1, -20, 0, 46),
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -10),
				disabled = id == 0,
				onClick = function()
					local ok = pcall(function()
						MarketplaceService:PromptProductPurchase(player, id)
					end)
					if not ok then
						Widgets.toast("The Roblox store didn't open. Try again in a moment.", "error")
					end
				end,
			})
			showPrice(buy, id, Enum.InfoType.Product)
		end
	end

	-- the passes
	shopHeading(list, "Passes", if narrow then nil else "Yours for good. None change how a match plays.", 5)
	local passes = shopGrid(list, "Passes", cols, 370, 6)
	for i, pass in Passes.list do
		if pass.randomItems and restricted then
			continue -- paid random items (chests, chest odds) are hidden where they're restricted
		end
		local color = hex(string.sub(pass.color, 2))
		local card, band = shopCard(passes, pass.key, color, i, 118)
		shopPicture(band, pass.picture, pass.icon, color, 96)
		if pass.badge then
			Widgets.badge(card, { text = pass.badge, color = C.orange, height = 24, textSize = 13, anchor = Vector2.new(1, 0), position = UDim2.new(1, -4, 0, -6), z = 12 })
		end
		Widgets.label(card, {
			text = pass.name,
			font = "display",
			size = 24,
			color = C.text,
			align = "center",
			scaled = true,
			sizeUDim = UDim2.new(1, -16, 0, 30),
			position = UDim2.fromOffset(8, 132),
		})
		local perks = Util.frame(card, {
			Position = UDim2.fromOffset(14, 170),
			Size = UDim2.new(1, -28, 1, -240),
		})
		Util.list(perks, "y", 7, "Left", "Top")
		for j, perk in pass.perks do
			local line = Util.frame(perks, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = j })
			local tick = Util.frame(line, { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(0, 2) })
			Icons.make(tick, "check", Icons.flatColors(C.good, C.panelRaised))
			local text = Widgets.label(line, {
				text = perk,
				font = "body",
				size = 14,
				color = C.text,
				wrap = true,
				sizeUDim = UDim2.new(1, -22, 0, 0),
				position = UDim2.fromOffset(22, 0),
			})
			text.AutomaticSize = Enum.AutomaticSize.Y
		end
		local id = Passes.id(pass.key)
		local buy = Widgets.button(card, {
			text = "Buy",
			style = "green",
			textSize = 20,
			size = UDim2.new(1, -24, 0, 50),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -12),
			onClick = function()
				if id == 0 then
					return
				end
				local ok = pcall(function()
					MarketplaceService:PromptGamePassPurchase(player, id)
				end)
				if not ok then
					Widgets.toast("The Roblox store didn't open. Try again in a moment.", "error")
				end
			end,
		})
		showPrice(buy, id, Enum.InfoType.GamePass)
		table.insert(cards, {
			update = function(p)
				local owned = p ~= nil and table.find(p.passes or {}, pass.key) ~= nil
				if owned then
					buy:setText("Owned")
					buy:setEnabled(false)
				elseif id == 0 then
					buy:setText("Soon")
					buy:setEnabled(false)
				end
			end,
		})
	end
	maid:add(State.watch("profile", render))
	render()
	return close
end

---------------------------------------------------------------------------
-- How to play
---------------------------------------------------------------------------

local RULES = {
	{
		icon = "chest",
		title = "The goal",
		text = "Race along the path to the treasure chest. Every time you reach it you bank a treasure (and 2 coins) and start a new run from the flag. First to 2 treasures wins a Quick game (3 in Standard, 4 in Classic). In team modes your team's treasures add up.",
	},
	{
		icon = "dice",
		title = "Your turn",
		text = "Your two dice are rolled for you. Pick one to move with, and the other die charges your Power bar. Rolled doubles? Three ways to go: forwards with the first die, backwards with the second (grab a token you just passed, or bonk someone right behind you), or the total of both (that charges no Power).\n\nBefore you move you may play one card, and use your ability if your Power bar is full. Hover a die (tap it on a phone) to see exactly where it takes you and what happens there.",
	},
	{
		icon = "dice",
		title = "The underdog",
		text = "Fall clearly behind everyone (8 tiles or more, and every treasure counts as a whole lap, so banking one and starting again from the flag never makes you last) and you're the underdog: you roll an extra GOLD die on your turn. Move with whichever die you like; the gold one never charges Power. It's marked on your name.",
	},
	{
		icon = "wanted",
		title = "Wanted",
		text = "From the end of round 2, whoever is way out in front (4 tiles or more ahead of every rival, a whole lap for every treasure) gets a WANTED poster: a price of 3 coins on their head. It goes up by a coin every round they stay ahead, and with every rival they bonk or catch in a trap.\n\nBonk the Wanted or catch them in your trap to claim it: the coins, and one of their cards. At 8 coins they're MOST WANTED: their hidden traps are out in the open, and so is every trap they hide after that. And if the Wanted reaches the treasure with the poster still up, they got away: the coins are theirs.",
	},
	{
		icon = "bolt",
		title = "Power",
		text = "Every character has a Power bar as long as their ability costs. The die you don't move with fills it, a hidden trap of yours catching someone adds 2, and a Regeneration card fills it up. When it's full, use your ability: then it starts again from empty. Frozen players charge no Power.",
	},
	{
		icon = "spike",
		title = "Hidden traps",
		text = "Trap cards are hidden: only your team can see them (and the Overseer). Hide one within 5 tiles of you, then think about where your rivals will land. When someone steps on it: GOTCHA! You get a coin and 2 Power. You can keep 3 out (the Trapper 4).\n\nSpike and Grog send them back to the start, Fire burns them and Ice freezes them for 2 turns, a Snare makes them roll 4+ next turn or lose it, Mudslide and Banana Peel push them back. A Wall is out in the open: only moves of 5 or more get past it. A Shield in your hand blocks one trap or bonk.",
	},
	{
		icon = "star",
		title = "Bonks",
		text = "Land on a rival with your own move: BOING! They fly back 2 tiles and you bounce 1 forward. The Fire Starter's bonks set rivals on fire too. No bonks on the Start or between teammates.",
	},
	{
		icon = "token_trap",
		title = "Tokens",
		text = "Land on a token to spin its wheel. Red Trap tokens give traps, green Assist tokens give helpful cards and navy Board Piece tokens give teleporters, shifting sands and other pieces. A wheel can also land on a coin. The orange Potion Seller sells potions for coins. Once used, a token jumps to a new spot. You hold up to 5 cards.",
	},
	{
		icon = "river_trap",
		title = "Hazards",
		text = "Every map has its own hazard. Rivers stop you on Blissful Tricks (a Bridge carries you across), locked gates stop you on Junction Dungeon (a Key opens them and the gated shortcuts), and slime pools eat 5 of your steps on Slimy Snares (Boots get you through).\n\nOn Haunted Hollow two ghosts drift down the trail every round: walk into one and you stop and jump back a tile (a Lantern shines it away). On Mount Kaboom lava streams stop you (a Fire Cloak carries you across), and every 3 rounds the volcano erupts: anyone standing in a stream is scorched.\n\nOn Frostbite Floes thin ice cracks under whoever lands on it, and cracked ice gives way under the next one to step on it: they fall in, Frozen, and slip back a tile (Ice Skates glide you across). On Kraken's Reach a tentacle rises a few tiles ahead of the leader and slams down when the round ends: anyone on or beside its mark is dragged back 3 (a Harpoon fends it off). On Clockwork Cove two drawbridges go up in turns (a Grappling Hook swings you over) and tip anyone on them back 2 as they rise, and a round ended on a cog carries you to the other one: 10 tiles on, or 10 back.",
	},
	{
		icon = "map",
		title = "Reading the board",
		text = "Each player is their character, standing on its tile in its own colour (that colour is the player's everywhere). Tokens are the coloured discs. A board piece shows its picture on a disc in its owner's colour. Your team's hidden traps show see-through, rimmed in the owner's colour: rivals can't see them. Frozen players are in a block of ice, burning ones are on fire and snared ones are snoozing.",
	},
	{
		icon = "info",
		title = "Controls",
		text = "PC: hover a die to see where it goes, click to move (or press Q, W, E). 1 to 5 play your cards, Space uses your ability, Esc cancels, Enter confirms, + and - zoom, F shows the whole board, Tab shows the scores and T opens the chat. Drag to look around and scroll to zoom.\n\nPhone or tablet: tap a die to see where it goes, tap it again to move. Tap a card to read it and use its buttons, or drag it onto the board. Drag to look around and pinch to zoom.",
	},
	{
		icon = "people",
		title = "Modes",
		text = "Blitz is a quick race to a single treasure. In team modes your treasures add up, your traps never catch teammates, you can't bonk them, and you can give a teammate a card (it's your card for the turn). In Party mode, every treasure brings a new rule, replacing the last one.\n\nWhile someone else takes their turn, tap the fishing rod in the board's corner to fish. Don't pull on a nibble: wait for the real bite, then reel it in fast. Every map has its own fish, and now and then you'll hook a gold coin.",
		modes = true,
	},
	{
		icon = "mage",
		title = "Characters",
		text = "",
		characters = true,
	},
}

function Pages.rules(layer: Instance): () -> ()
	local roomW, roomH = Widgets.room()
	local content, close = Widgets.modal(layer, {
		title = "How to play",
		titleWidth = 280,
		width = math.min(860, roomW),
		height = math.min(600, roomH),
	})
	local scroll = Widgets.scroll(content, { gap = 12, hAlign = "Left" })
	-- learn by playing: the guided match, any time
	local guided = Util.new("Frame", {
		Name = "Guided",
		BackgroundColor3 = C.mine,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 0, 74),
		LayoutOrder = 0,
		Parent = scroll,
	})
	Util.corner(guided, 12)
	Util.stroke(guided, C.sun, 3)
	Widgets.label(guided, {
		text = "Rather learn by playing? Take the 3-minute guided match.",
		font = "heavy",
		size = 17,
		color = C.text,
		wrap = true,
		sizeUDim = UDim2.new(1, -230, 1, 0),
		position = UDim2.fromOffset(16, 0),
	})
	Widgets.button(guided, {
		text = "Guided match",
		icon = "play",
		style = "brass",
		textSize = 17,
		size = UDim2.fromOffset(200, 50),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, 0.5, 0),
		onClick = function()
			local ok, err = Net.request("match.tutorial")
			if ok then
				close()
			else
				Widgets.toast(tostring(err), "error")
			end
		end,
	})
	for i, section in RULES do
		local text = section.text
		if section.modes then
			local lines = {}
			for _, m in Modes.list do
				table.insert(lines, m.name .. ": " .. m.blurb)
			end
			text = table.concat(lines, "\n") .. "\n\n" .. section.text
		elseif section.characters then
			local lines = {}
			for _, ch in Characters.list do
				local ab = if ch.ability then ("\n" .. ch.ability.name .. " (" .. ch.ability.cost .. " Power): " .. ch.ability.text) else ""
				table.insert(lines, ch.name .. ". " .. (ch.passiveName or "Passive") .. ": " .. ch.passive .. ab)
			end
			text = table.concat(lines, "\n\n")
		end
		local block = Util.new("Frame", {
			Name = "Section" .. i,
			BackgroundColor3 = C.panelRaised,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -16, 0, 0),
			LayoutOrder = i,
			Parent = scroll,
		})
		Util.corner(block, 12)
		Util.stroke(block, C.line, 2.5)
		Util.pad(block, 14, 12, 14, 14)
		local icon = Util.frame(block, { Size = UDim2.fromOffset(52, 52) })
		Icons.medallion(icon, section.icon, C.sun, { Size = UDim2.fromScale(1, 1) })
		Widgets.label(block, {
			text = section.title,
			font = "chunky",
			size = 24,
			color = C.sun,
			outline = C.line,
			sizeUDim = UDim2.new(1, -66, 0, 28),
			position = UDim2.fromOffset(66, 0),
		})
		local body = Widgets.label(block, {
			text = text,
			font = "body",
			size = 17,
			color = C.text,
			wrap = true,
			valign = "top",
			sizeUDim = UDim2.new(1, -66, 0, 0),
			position = UDim2.fromOffset(66, 32),
		})
		body.AutomaticSize = Enum.AutomaticSize.Y
	end
	return close
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local function saveSetting(key: string, value: any)
	local profile = State.get("profile")
	local settings = table.clone(profile and profile.settings or {})
	settings[key] = value
	if profile then
		profile.settings = settings
		State.set("profile", profile)
	end
	task.spawn(Net.request, "settings.save", { settings = settings })
end

local function toggleRow(list: Instance, label: string, key: string, order: number)
	local profile = State.get("profile")
	local row = Util.frame(list, { Name = key, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order })
	Widgets.label(row, {
		text = label,
		font = "heavy",
		size = 18,
		color = C.text,
		sizeUDim = UDim2.new(1, -90, 1, 0),
	})
	Widgets.toggle(row, {
		value = not (profile and profile.settings and profile.settings[key] == false),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.fromScale(1, 0.5),
		onChange = function(v)
			saveSetting(key, v)
		end,
	})
end

-- The owner's unlock-all switch: every character, cosmetic and gold base, just for them,
-- without touching their real progress; off again, they're back to what they've earned.
local function unlockAllRow(list: Instance, order: number)
	local profile = State.get("profile")
	local row = Util.frame(list, { Name = "UnlockAll", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order })
	Widgets.label(row, {
		text = "Unlock everything (owner)",
		font = "heavy",
		size = 18,
		color = C.text,
		sizeUDim = UDim2.new(1, -90, 1, 0),
	})
	local toggle
	toggle = Widgets.toggle(row, {
		value = profile ~= nil and profile.unlockAll == true,
		anchor = Vector2.new(1, 0.5),
		position = UDim2.fromScale(1, 0.5),
		onChange = function(v)
			local ok, err = Net.request("owner.unlockAll", { on = v })
			if ok then
				Widgets.toast(if v then "Everything's unlocked for you. Switch it off to go back to your own progress." else "Back to your own progress.", "info")
			else
				Widgets.toast(tostring(err), "error")
				toggle:set(not v, true)
			end
		end,
	})
	local note = Widgets.label(list, {
		text = "Every character, cosmetic and gold base, just for you. Your real progress stays as it is.",
		font = "body",
		size = 14,
		color = C.textSoft,
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 0),
		layoutOrder = order,
	})
	note.AutomaticSize = Enum.AutomaticSize.Y
end

function Pages.settings(layer: Instance): () -> ()
	local staff = State.get("staff")
	local content, close = Widgets.modal(layer, {
		title = "Settings",
		titleWidth = 240,
		width = 560,
		height = if staff == "owner" then 770 elseif staff then 690 else 620,
	})
	local list = Widgets.scroll(content, { gap = 12, padding = 4 })
	VolumeRows.build(list, 1)
	toggleRow(list, "Chat bubbles over players", "bubbles", 4)
	if staff == "owner" then
		unlockAllRow(list, 7)
	end
	if staff then
		Widgets.button(list, {
			text = if staff == "owner" then "Owner panel" else "Admin panel",
			icon = "crown",
			style = "panel",
			textSize = 20,
			size = UDim2.fromOffset(280, 50),
			layoutOrder = 8,
			onClick = function()
				close()
				StaffPanel.open(layer)
			end,
		})
	end
	Widgets.label(list, {
		text = "Trapisque v" .. tostring(State.get("version") or "1.0"),
		font = "body",
		size = 14,
		color = C.textFaint,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 20),
		layoutOrder = 9,
	})
	return close
end

---------------------------------------------------------------------------
-- Leaderboard (screens without room for the Top Players column)
---------------------------------------------------------------------------

function Pages.leaderboard(layer: Instance): () -> ()
	local panel = nil
	local roomW, roomH = Widgets.room()
	local content, close = Widgets.modal(layer, {
		title = "Top players",
		titleWidth = 240,
		width = math.min(520, roomW),
		height = math.min(600, roomH),
		onClose = function()
			-- the modal takes the panel with it; just stop any load still on its way
			if panel then
				panel.alive = false
			end
		end,
	})
	panel = LeaderboardPanel.new(content, { title = false })
	return close
end

return Pages
