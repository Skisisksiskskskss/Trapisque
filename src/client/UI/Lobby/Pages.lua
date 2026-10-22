--[[
	Pages
	The smaller lobby windows: the Shop (today's deals for Gems, free Gems for joining
	the group, the gamepasses), How to Play and Settings (volumes, the chat's voices and
	bubbles, your voice, and the staff panel for staff).

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
local Progress = require(Shared.Meta.Progress)
local Voices = require(Shared.Meta.Voices)
local Cosmetics = require(Shared.Meta.Cosmetics)
local Config = require(Shared.Config)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local VolumeRows = require(UI.VolumeRows)
local CosmeticArt = require(UI.CosmeticArt)
local LeaderboardPanel = require(script.Parent.LeaderboardPanel)
local StaffPanel = require(UI.StaffPanel)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Voice = require(Client.Voice)

local C = Theme.C
local hex = Theme.hex

local Pages = {}

local player = Players.LocalPlayer

---------------------------------------------------------------------------
-- Shop (gamepasses)
---------------------------------------------------------------------------

function Pages.shop(layer: Instance): () -> ()
	local maid = Util.maid()
	local roomW, roomH, narrow = Widgets.room()
	local content, close = Widgets.modal(layer, {
		title = "Shop",
		titleWidth = 200,
		width = math.min(960, roomW),
		height = math.min(560, roomH),
		onClose = function()
			maid:clean()
		end,
	})
	task.spawn(Net.request, "shop.refresh")
	Widgets.label(content, {
		text = "Today's deals change every day. Passes never change how a match plays.",
		font = "heavy",
		size = if narrow then 13 else 16,
		color = C.textSoft,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, if narrow then 34 else 24),
	})
	-- four across on a wide screen (scrolling down to the rest), one or two on a phone
	local top = if narrow then 42 else 34
	local cols = if not narrow then 4 elseif roomW >= 560 then 2 else 1
	local row = Widgets.scroll(content, {
		position = UDim2.fromOffset(0, top),
		size = UDim2.new(1, 0, 1, -top),
		grid = UDim2.new(1 / cols, -14 * (cols - 1) / cols - 4, 0, 400),
		gap = 14,
		padding = 4,
	})

	local cards = {}
	local function render()
		local profile = State.get("profile")
		for _, card in cards do
			card.update(profile)
		end
	end
	local profile = State.get("profile")
	-- today's deals: cosmetics for Gems, no random rolls
	for i, deal in (profile and profile.deals and profile.deals.items) or {} do
		local def = Cosmetics.get(deal.id)
		if def then
			local rarity = Cosmetics.rarityById[def.rarity]
			local color = if rarity then hex(string.sub(rarity.color, 2)) else C.sun
			local card = Util.new("Frame", {
				Name = "Deal_" .. deal.id,
				BackgroundColor3 = C.panelRaised,
				BorderSizePixel = 0,
				LayoutOrder = i,
				Parent = row,
			})
			Util.corner(card, 14)
			Util.stroke(card, color, 3)
			Widgets.badge(card, { text = "Today's deal", color = color, height = 24, textSize = 13, position = UDim2.fromOffset(10, 10) })
			CosmeticArt.preview(card, deal.id, nil, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 44),
				Size = UDim2.fromOffset(150, 150),
			})
			Widgets.label(card, {
				text = def.name,
				font = "chunky",
				size = 24,
				color = C.text,
				align = "center",
				scaled = true,
				sizeUDim = UDim2.new(1, -20, 0, 30),
				position = UDim2.fromOffset(10, 206),
			})
			Widgets.label(card, {
				text = (if rarity then rarity.name else def.rarity) .. " " .. string.lower(def.category),
				font = "heavy",
				size = 15,
				color = color,
				align = "center",
				sizeUDim = UDim2.new(1, -20, 0, 20),
				position = UDim2.fromOffset(10, 238),
			})
			local buy = Widgets.button(card, {
				text = Util.commas(deal.price) .. " Gems",
				icon = "gem",
				style = "brass",
				textSize = 18,
				size = UDim2.new(1, -28, 0, 50),
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -14),
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
		local card = Util.new("Frame", {
			Name = "Community",
			BackgroundColor3 = C.panelRaised,
			BorderSizePixel = 0,
			LayoutOrder = 5,
			Parent = row,
		})
		Util.corner(card, 14)
		Util.stroke(card, C.mint, 3)
		local icon = Util.frame(card, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(86, 86) })
		Icons.medallion(icon, "people", C.mint, { Size = UDim2.fromScale(1, 1) })
		Widgets.label(card, {
			text = "Free " .. Config.Community.Gems .. " Gems",
			font = "chunky",
			size = 26,
			color = C.text,
			align = "center",
			scaled = true,
			sizeUDim = UDim2.new(1, -20, 0, 32),
			position = UDim2.fromOffset(10, 108),
		})
		Widgets.label(card, {
			text = "Like the game (the thumbs up on its page) and join our Roblox group, then claim your Gems. Once per player.",
			font = "body",
			size = 15,
			color = C.text,
			wrap = true,
			align = "center",
			sizeUDim = UDim2.new(1, -28, 0, 110),
			position = UDim2.fromOffset(14, 146),
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
			style = "blue",
			textSize = 17,
			size = UDim2.new(1, -28, 0, 46),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -72),
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
			size = UDim2.new(1, -28, 0, 46),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -14),
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
	for i, pass in Passes.list do
		if pass.randomItems and profile and profile.restricted then
			continue -- paid random-item boosts are hidden where they're restricted
		end
		local color = hex(string.sub(pass.color, 2))
		local card = Util.new("Frame", {
			Name = pass.key,
			BackgroundColor3 = C.panelRaised,
			BorderSizePixel = 0,
			Size = UDim2.new(0.25, -12, 1, 0),
			LayoutOrder = 10 + i,
			Parent = row,
		})
		Util.corner(card, 14)
		Util.stroke(card, color, 3)
		local icon = Util.frame(card, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(86, 86),
		})
		Icons.medallion(icon, pass.icon, color, { Size = UDim2.fromScale(1, 1) })
		Widgets.label(card, {
			text = pass.name,
			font = "chunky",
			size = 26,
			color = C.text,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 32),
			position = UDim2.fromOffset(0, 108),
		})
		local perks = Util.frame(card, {
			Position = UDim2.fromOffset(14, 146),
			Size = UDim2.new(1, -28, 1, -220),
		})
		Util.list(perks, "y", 8, "Left", "Top")
		for j, perk in pass.perks do
			local line = Util.frame(perks, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = j })
			local tick = Util.frame(line, { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(0, 2) })
			Icons.make(tick, "check", Icons.flatColors(C.good, C.panelRaised))
			local text = Widgets.label(line, {
				text = perk,
				font = "body",
				size = 15,
				color = C.text,
				wrap = true,
				sizeUDim = UDim2.new(1, -26, 0, 0),
				position = UDim2.fromOffset(26, 0),
			})
			text.AutomaticSize = Enum.AutomaticSize.Y
		end
		local id = Passes.id(pass.key)
		local buy = Widgets.button(card, {
			text = "Buy",
			icon = "bag",
			style = "green",
			textSize = 20,
			size = UDim2.new(1, -28, 0, 50),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -14),
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
		-- show the Robux price once Roblox tells us
		if id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
				end)
				if ok and info and info.PriceInRobux and buy.root.Parent then
					buy:setText("R$ " .. tostring(info.PriceInRobux))
				end
			end)
		end
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
		text = "Your two dice are rolled for you. Pick one to move with: the OTHER die charges your Power bar. Rolled doubles? Three ways to go: forwards with the first die, BACKWARDS with the second (grab a token you just passed, or bonk someone right behind you), or the TOTAL of both (that charges no Power).\n\nBefore you move you may play ONE card, and use your ability if your Power bar is full. Hover a die (tap it on a phone) to see exactly where it takes you and what happens there.",
	},
	{
		icon = "dice",
		title = "The underdog",
		text = "Fall clearly behind everyone (8 tiles or more, and every treasure counts as a whole lap, so banking one and starting again from the flag never makes you last) and you're the underdog: you roll an extra GOLD die on your turn. Move with whichever die you like; the gold one never charges Power. It's marked on your name.",
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
		text = "Every map has its own hazard. Rivers stop you on Blissful Tricks (a Bridge carries you across), locked gates stop you on Junction Dungeon (a Key opens them and the gated shortcuts), and slime pools eat 5 of your steps on Slimy Snares (Boots get you through).\n\nOn Haunted Hollow two ghosts drift down the trail every round: walk into one and you stop and jump back a tile (a Lantern shines it away). On Mount Kaboom lava streams stop you (a Fire Cloak carries you across), and every 3 rounds the volcano erupts: anyone standing in a stream is scorched.",
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
		text = "Blitz is a quick race to ONE treasure. In team modes your treasures add up, your traps never catch teammates, you can't bonk them, and you can give a teammate a card (it's your card for the turn). The Weekly Event changes every Thursday.\n\nWhile someone else takes their turn, tap the fishing rod in the board's corner to fish: wait for the bite, then reel it in fast. Fill your fish log, and now and then you'll hook a gold coin.",
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
		title = "How to Play",
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
		style = "green",
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
				if m.isEvent then
					local event = Progress.currentEvent()
					table.insert(lines, m.name .. " (this week: " .. event.name .. "): " .. event.blurb)
				else
					table.insert(lines, m.name .. ": " .. m.blurb)
				end
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

-- The voice your chat bubbles speak in: your character's, or (Voice Pack) any of them.
local function voiceRow(list: Instance, order: number)
	local profile = State.get("profile")
	local current = profile and profile.settings and profile.settings.voice or "auto"
	local hasPack = State.hasPass("VoicePack")
	Widgets.label(list, {
		text = if hasPack then "Your voice" else "Your voice (pick any with the Voice Pack)",
		font = "heavy",
		size = 18,
		color = C.text,
		sizeUDim = UDim2.new(1, 0, 0, 24),
		layoutOrder = order,
	})
	local grid = Util.frame(list, { Name = "Voices", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order + 1 })
	Util.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 38),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})
	local chips = {}
	local function paint()
		for id, b in chips do
			b:setStyle(if id == current then "brass" else "panel")
		end
	end
	for i, v in Voices.list do
		local locked = v.id ~= "auto" and not hasPack
		chips[v.id] = Widgets.button(grid, {
			text = v.name,
			icon = if locked then "lock" else nil,
			style = "panel",
			textSize = 15,
			font = "heavy",
			depth = 3,
			layoutOrder = i,
			onClick = function()
				local character = profile and profile.character
				Voice.sample(Voices.resolve(v.id, character))
				if locked then
					Widgets.toast("That's a Voice Pack voice. Get it in the Shop!", "info")
					return
				end
				current = v.id
				paint()
				saveSetting("voice", v.id)
			end,
		})
	end
	paint()
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
	toggleRow(list, "Read chat out loud", "voices", 3)
	toggleRow(list, "Chat bubbles over players", "bubbles", 4)
	voiceRow(list, 5)
	if staff == "owner" then
		unlockAllRow(list, 7)
	end
	if staff then
		Widgets.button(list, {
			text = if staff == "owner" then "Owner panel" else "Admin panel",
			icon = "crown",
			style = "brass",
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
		title = "Top Players",
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
