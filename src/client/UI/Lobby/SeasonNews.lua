--[[
	SeasonNews
	The first time you're back after a ranked season ended: the rank you finished it on
	(your best in it), what that paid (Gems, a chest, a season title) and the trophies you
	carry into the new one.

		SeasonNews.show(layer, news)   -- profile.seasonNews (DataService seasonRollover)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progress = require(Shared.Meta.Progress)

local UI = script.Parent.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)
local Widgets = require(UI.Widgets)
local CosmeticArt = require(UI.CosmeticArt)

local Client = UI.Parent
local Net = require(Client.Net)
local Sound = require(Client.Sound)

local C = Theme.C

local SeasonNews = {}

local CHEST_NAME = { explorer = "Explorer Chest", royal = "Royal Chest" }

function SeasonNews.show(layer: Instance, news)
	if type(news) ~= "table" then
		return
	end
	local rank = nil
	for _, r in Progress.ranks do
		if r.id == news.rank then
			rank = r
		end
	end
	rank = rank or Progress.ranks[1]
	local color = Color3.fromHex(string.sub(rank.color, 2))
	local roomW = Widgets.room()
	local content, close = Widgets.modal(layer, {
		title = "Season " .. tostring(news.season) .. " is over!",
		titleWidth = math.min(340, roomW - 60),
		width = math.min(520, roomW),
		height = 400,
		onClose = function()
			Net.request("season.seen")
		end,
	})
	Sound.play("reveal")
	local medal = Util.frame(content, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(86, 86),
	})
	Icons.medallion(medal, "crown", color, { Size = UDim2.fromScale(1, 1) })
	Util.popIn(medal, 0.4, 0.3)
	Widgets.label(content, {
		text = "You finished " .. rank.name .. "!",
		font = "chunky",
		size = 26,
		color = C.text,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 32),
		position = UDim2.fromOffset(0, 92),
	})
	-- what it paid
	local lines = {}
	if (news.gems or 0) > 0 then
		table.insert(lines, "+" .. tostring(news.gems) .. " Gems")
	end
	if news.chest then
		table.insert(lines, "a free " .. (CHEST_NAME[news.chest] or "chest"))
	end
	Widgets.label(content, {
		text = if #lines > 0 then table.concat(lines, "  ·  ") else "Reach Bronze next season for a reward!",
		font = "heavy",
		size = 17,
		color = if #lines > 0 then C.sunDark else C.textSoft,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 24),
		position = UDim2.fromOffset(0, 128),
	})
	if news.title then
		Widgets.label(content, {
			text = "New title to wear:",
			font = "body",
			size = 14,
			color = C.textSoft,
			align = "center",
			sizeUDim = UDim2.new(1, 0, 0, 18),
			position = UDim2.fromOffset(0, 160),
		})
		local holder = Util.frame(content, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 180),
			Size = UDim2.fromOffset(260, 30),
		})
		CosmeticArt.title(holder, news.title, nil, 16)
	end
	Widgets.label(content, {
		text = "Your trophies carry into Season " .. tostring((news.season or 0) + 1) .. " at half: "
			.. Util.commas(news.trophiesBefore or 0) .. " to " .. Util.commas(news.trophies or 0) .. ".",
		font = "body",
		size = 14,
		color = C.textSoft,
		align = "center",
		wrap = true,
		sizeUDim = UDim2.new(1, 0, 0, 36),
		position = UDim2.fromOffset(0, 220),
	})
	Widgets.button(content, {
		text = "Onward!",
		icon = "play",
		style = "green",
		textSize = 22,
		size = UDim2.fromOffset(220, 52),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, 0),
		onClick = close,
	})
end

return SeasonNews
