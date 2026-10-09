--[[
	Pages
	The smaller lobby windows: the gamepass Shop, How to Play and Settings.

		Pages.shop(popupLayer)
		Pages.rules(popupLayer)
		Pages.settings(popupLayer)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Passes = require(Shared.Meta.Passes)
local Characters = require(Shared.Game.Characters)
local Modes = require(Shared.Game.Modes)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C
local hex = Theme.hex

local Pages = {}

local player = Players.LocalPlayer

---------------------------------------------------------------------------
-- Shop (gamepasses)
---------------------------------------------------------------------------

function Pages.shop(layer: Instance): () -> ()
	local maid = Util.maid()
	local content, close = Widgets.modal(layer, {
		title = "Shop",
		titleWidth = 200,
		width = 960,
		height = 560,
		onClose = function()
			maid:clean()
		end,
	})
	task.spawn(Net.request, "shop.refresh")
	Widgets.label(content, {
		text = "Passes never change how a match plays: they're cosmetics and faster collecting.",
		font = "heavy",
		size = 16,
		color = C.inkSoft,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 24),
	})
	local row = Util.frame(content, {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
	})
	Util.list(row, "x", 14, "Center", "Top")

	local cards = {}
	local function render()
		local profile = State.get("profile")
		for _, card in cards do
			card.update(profile)
		end
	end
	local profile = State.get("profile")
	for i, pass in Passes.list do
		if pass.randomItems and profile and profile.restricted then
			continue -- paid random-item boosts are hidden where they're restricted
		end
		local color = hex(string.sub(pass.color, 2))
		local card = Util.new("Frame", {
			Name = pass.key,
			BackgroundColor3 = C.parchmentMid,
			BorderSizePixel = 0,
			Size = UDim2.new(0.25, -12, 1, 0),
			LayoutOrder = i,
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
			color = C.ink,
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
			Icons.make(tick, "check", Icons.flatColors(C.good, C.parchmentMid))
			local text = Widgets.label(line, {
				text = perk,
				font = "body",
				size = 15,
				color = C.textDark,
				wrap = true,
				sizeUDim = UDim2.new(1, -26, 0, 0),
				position = UDim2.fromOffset(26, 0),
			})
			text.AutomaticSize = Enum.AutomaticSize.Y
		end
		local id = Passes.id(pass.key)
		local buy = Widgets.button(card, {
			text = "BUY",
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
					buy:setText("OWNED")
					buy:setEnabled(false)
				elseif id == 0 then
					buy:setText("SOON")
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
		icon = "x_mark",
		title = "The goal",
		text = "Race along the treasure map to the big X. Every time you reach it you bank a treasure and start a new run from the flag. The first player (or team) with every treasure they need wins: 2 in Quick games, 3 in Standard, 5 in Classic.",
	},
	{
		icon = "dice",
		title = "Your turn",
		text = "Roll the die and move, OR play one card instead of rolling. Some cards are free and can be used before you roll: Boosts (Speed Boost, Bounce Pad, Speed Potion), Regeneration and the Time Potion's anchor. Your character's ability is free too, once per turn.",
	},
	{
		icon = "token_trap",
		title = "Tokens",
		text = "Land on a token to spin its wheel. Red Trap tokens give trap cards, green Assist tokens give helpful cards and purple Neutral tokens give tricky ones. A wheel can also land on a coin. The orange Potion Seller sells potions for coins. Once used, a token jumps to a new spot. Landing counts however you get there: a roll, a push from a trap, a Nudge, Telepathy or a swap.",
	},
	{
		icon = "spike",
		title = "Traps",
		text = "Place trap cards on tiles to catch whoever lands there. Spike sends them back to the start, Fire makes them burn, Ice freezes them, Mud and Mudslide push them back, a Wall blocks short moves, a Snare skips their next turn and a Grog eats anyone who can't roll a 4. A Shield in your hand blocks the next trap you trigger.",
	},
	{
		icon = "river_trap",
		title = "Natural traps",
		text = "Every map has its own hazard: rivers end your move on Blissful Tricks (a Bridge gets you across), locked gates hold you on Junction Dungeon (a Key opens them and the gated shortcuts) and slime slows you on Slimy Snares (Boots keep your feet clean).",
	},
	{
		icon = "people",
		title = "Modes",
		text = "In team modes, once you have all your treasures you keep playing to help your team: give them cards and use your ability on the other team. Your laps don't count any more.",
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
	local content, close = Widgets.modal(layer, {
		title = "How to Play",
		titleWidth = 280,
		width = 860,
		height = 600,
	})
	local scroll = Widgets.scroll(content, { gap = 12, hAlign = "Left" })
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
				local ab = if ch.ability then (" Ability, " .. ch.ability.name .. ": " .. ch.ability.text) else ""
				table.insert(lines, ch.name .. ": " .. ch.passive .. ab)
			end
			text = table.concat(lines, "\n\n")
		end
		local block = Util.new("Frame", {
			Name = "Section" .. i,
			BackgroundColor3 = C.parchmentMid,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -16, 0, 0),
			LayoutOrder = i,
			Parent = scroll,
		})
		Util.corner(block, 12)
		Util.stroke(block, C.parchmentEdge, 2)
		Util.pad(block, 14, 12, 14, 14)
		local icon = Util.frame(block, { Size = UDim2.fromOffset(52, 52) })
		Icons.medallion(icon, section.icon, C.woodDark, { Size = UDim2.fromScale(1, 1) })
		Widgets.label(block, {
			text = section.title,
			font = "chunky",
			size = 24,
			color = C.ink,
			sizeUDim = UDim2.new(1, -66, 0, 28),
			position = UDim2.fromOffset(66, 0),
		})
		local body = Widgets.label(block, {
			text = text,
			font = "body",
			size = 17,
			color = C.textDark,
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

function Pages.settings(layer: Instance): () -> ()
	local content, close = Widgets.modal(layer, {
		title = "Settings",
		titleWidth = 240,
		width = 520,
		height = 350,
	})
	local profile = State.get("profile")
	local settings = table.clone(profile and profile.settings or { sfx = true, music = true })
	local list = Util.frame(content, {})
	Util.list(list, "y", 14, "Center", "Top")
	local function row(order: number, label: string, key: string, apply: ((boolean) -> ())?)
		local r = Util.frame(list, { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order })
		Widgets.label(r, {
			text = label,
			font = "heavy",
			size = 19,
			color = C.textDark,
			sizeUDim = UDim2.new(1, -90, 1, 0),
		})
		Widgets.toggle(r, {
			value = settings[key] ~= false,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, 0, 0.5, 0),
			onChange = function(v)
				settings[key] = v
				if apply then
					apply(v)
				end
				Net.request("settings.save", { settings = settings })
			end,
		})
	end
	row(1, "Sound effects", "sfx", function(v)
		Sound.setEnabled(v)
	end)
	row(2, "Music", "music", function(v)
		Sound.setMusicEnabled(v)
	end)
	Widgets.label(list, {
		text = "Trapisque v" .. tostring(State.get("version") or "1.0"),
		font = "body",
		size = 14,
		color = C.inkFaint,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 20),
		layoutOrder = 9,
	})
	return close
end

return Pages
