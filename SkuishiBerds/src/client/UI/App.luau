--[[
	App: the menu shell. Owns the ScreenGuis, navigation between screens,
	the local copy of the player's profile, toasts, and match start/end.

	Layout: every screen lives in a centered column (max 560 px wide), so the
	game is portrait-first on phones and keeps the same shape on PC/console,
	like the original's 600 px playfield.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Signal = require(Shared.Util.Signal)

local Client = script.Parent.Parent
local Net = require(Client.Core.Net)
local Audio = require(Client.Core.Audio)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)
local Backdrop = require(script.Parent.Backdrop)

local App = {}
App.profile = nil :: any
App.ProfileChanged = Signal.new()
App.screens = {}
App.current = nil :: string?
App.match = nil

local player = Players.LocalPlayer

function App.init()
	local playerGui = player:WaitForChild("PlayerGui")

	local back = Instance.new("ScreenGui")
	back.Name = "SkuishiBackdrop"
	back.IgnoreGuiInset = true
	back.ResetOnSpawn = false
	back.DisplayOrder = 0
	back.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	back.Parent = playerGui
	App.backdrop = Backdrop.new(back)

	local gui = Instance.new("ScreenGui")
	gui.Name = "SkuishiUI"
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = playerGui
	App.gui = gui

	local column = Widgets.frame(gui, {
		size = UDim2.fromScale(1, 1),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		name = "Column",
	})
	local max = Instance.new("UISizeConstraint")
	max.MaxSize = Vector2.new(560, math.huge)
	max.Parent = column
	App.column = column

	local toasts = Widgets.frame(gui, {
		size = UDim2.new(0.9, 0, 0, 200),
		position = UDim2.new(0.5, 0, 0, 70),
		anchor = Vector2.new(0.5, 0),
		name = "Toasts",
		z = 200,
	})
	local tmax = Instance.new("UISizeConstraint")
	tmax.MaxSize = Vector2.new(420, 200)
	tmax.Parent = toasts
	Widgets.list(toasts, 6)
	Widgets.setToastHolder(toasts)
	Widgets.clickSound = function()
		Audio.play("ui_click", 1, 0.7)
	end

	-- screens
	local Screens = script.Parent.Screens
	for _, mod in Screens:GetChildren() do
		if mod:IsA("ModuleScript") then
			local ok, screen = pcall(function()
				return require(mod).create(App)
			end)
			if ok and screen then
				screen.frame.Visible = false
				screen.frame.Parent = column
				App.screens[mod.Name] = screen
			else
				warn("[App] screen " .. mod.Name .. " failed: " .. tostring(screen))
			end
		end
	end

	-- profile sync
	Net.on("Profile", function(data)
		App.setProfile(data)
	end)
	Net.on("Discovered", function(name, coins)
		local Events = require(Shared.Config.Events)
		local meta = Events.ByName[name]
		Widgets.toast(string.format("New event: %s  +%d coins", meta and meta.display or name, coins), Theme.Mint)
	end)
	Net.on("Purchased", function(_key, title)
		Widgets.toast("Thanks! Got " .. tostring(title), Theme.Yellow)
		Audio.play("ui_buy", 1, 0.8)
	end)
	Net.on("QueueStatus", function(status)
		local q = App.screens.Queue
		if q and q.setStatus then
			q.setStatus(status)
		end
	end)
	Net.on("MatchStart", function(info)
		App.startMatch(info)
	end)

	task.spawn(function()
		local data = Net.ask("Profile")
		if data then
			App.setProfile(data)
		end
		if data and not data.persistent then
			Widgets.toast("Studio test: progress won't save (enable API access)", Theme.Orange)
		end
		App.tryDaily()
	end)

	Audio.music("title_music")
	App.go("Home")
end

function App.setProfile(data)
	App.profile = data
	if data and data.settings then
		Audio.setVolumes(data.settings.music, data.settings.sfx)
	end
	App.ProfileChanged:Fire(data)
end

function App.go(name: string, args: any?)
	if App.current and App.screens[App.current] then
		local cur = App.screens[App.current]
		cur.frame.Visible = false
		if cur.onHide then
			cur.onHide()
		end
	end
	App.current = name
	local s = App.screens[name]
	if s then
		s.frame.Visible = true
		if s.onShow then
			s.onShow(args)
		end
	end
	App.backdrop:setMenuMode(name ~= "Hud")
	App.backdrop:setQuiet(name ~= "Home")
end

function App.owns(category: string, id: string): boolean
	local p = App.profile
	return p ~= nil and p.owned[category] ~= nil and p.owned[category][id] == true
end

function App.coins(): number
	return if App.profile then App.profile.coins else 0
end

-- Robux purchase prompt for a product key from Config/Products
function App.promptProduct(key: string)
	local id = Products.Ids[key]
	if not id or id == 0 then
		Widgets.toast("Not for sale yet", Theme.Orange)
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

function App.tryDaily()
	local p = App.profile
	if not p then
		return
	end
	local today = math.floor(os.time() / 86400)
	if p.daily and p.daily.day < today then
		local result = Net.ask("Daily")
		if result and result.ok then
			local text = string.format("Daily reward! +%d coins (day %d)", result.coins, result.streak)
			if result.token then
				text ..= " + revive token"
			end
			Widgets.toast(text, Theme.Mint)
			Audio.play("ui_buy", 1.1, 0.8)
		end
	end
end

-- Matches ---------------------------------------------------------------------------------

function App.queue(modeId: string, opts)
	Net.send("Queue", modeId, opts or {})
	local Modes = require(Shared.Config.Modes)
	local mode = Modes[modeId]
	if mode and mode.online and not (opts and opts.couch and modeId == "DUOS") then
		App.go("Queue", { mode = modeId })
	end
end

function App.startMatch(info)
	if App.match then
		App.match:destroy()
		App.match = nil
	end
	App.go("Hud", info)
end

function App.endMatch(summary)
	App.go("Results", summary)
	Audio.music("title_music")
end

return App
