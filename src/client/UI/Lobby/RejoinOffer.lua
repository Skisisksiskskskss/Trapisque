--[[
	RejoinOffer
	Back in a lobby after your connection dropped mid-match: your seat is still kept (a
	bot plays it, Config.Rejoin), so the lobby offers to take you back to it.

		RejoinOffer.show(layer, { mode, map, seconds })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Maps = require(Shared.Game.Maps)
local Modes = require(Shared.Game.Modes)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)

local Client = UI.Parent
local Net = require(Client.Net)

local C = Theme.C

local RejoinOffer = {}

function RejoinOffer.show(layer: Instance, offer)
	if type(offer) ~= "table" or (tonumber(offer.seconds) or 0) <= 0 then
		return
	end
	local ends = os.clock() + offer.seconds
	local map = Maps.get(offer.map or "")
	local mode = Modes.get(offer.mode or "")
	local roomW = Widgets.room()
	local content, close = Widgets.modal(layer, {
		title = "Your match is still on!",
		titleWidth = math.min(360, roomW - 60),
		width = math.min(560, roomW),
		height = 290,
	})
	local where = if map then (" on " .. map.name) else ""
	local kind = if mode then (mode.name .. " match") else "match"
	Widgets.label(content, {
		text = "Your connection dropped in the middle of a " .. kind .. where .. ". A bot is keeping your seat warm, so you can jump straight back in.",
		font = "heavy",
		size = 17,
		color = C.textSoft,
		wrap = true,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 70),
	})
	local timer = Widgets.label(content, {
		text = "",
		font = "chunky",
		size = 20,
		color = C.text,
		align = "center",
		sizeUDim = UDim2.new(1, 0, 0, 26),
		position = UDim2.fromOffset(0, 80),
	})
	local done = false
	local conn
	local function finish()
		done = true
		if conn then
			conn:Disconnect()
		end
		close()
	end
	conn = RunService.Heartbeat:Connect(function()
		local left = math.max(0, math.ceil(ends - os.clock()))
		timer.Text = "Your seat is kept for " .. left .. "s"
		if left <= 0 and not done then
			finish()
		end
	end)
	Widgets.button(content, {
		text = "Stay here",
		style = "panel",
		textSize = 20,
		size = UDim2.fromOffset(190, 52),
		anchor = Vector2.new(1, 1),
		position = UDim2.new(0.5, -8, 1, 0),
		onClick = function()
			finish()
			Net.request("rejoin.skip")
		end,
	})
	Widgets.button(content, {
		text = "Back to it",
		icon = "play",
		style = "green",
		textSize = 20,
		size = UDim2.fromOffset(190, 52),
		anchor = Vector2.new(0, 1),
		position = UDim2.new(0.5, 8, 1, 0),
		onClick = function()
			finish()
			local ok, err = Net.request("rejoin.go")
			if not ok then
				Widgets.toast(tostring(err), "info")
			end
		end,
	})
end

return RejoinOffer
