--[[
	Hud: everything on screen, laid out like a battlegrounds game.

	  menu buttons (Settings, Characters)        top left
	  Washout timer                              top centre
	  kill feed                                  top right
	  big callouts (KOs, warnings)               upper centre
	  combo damage counter                       right
	  name, health, awakening and evasive bars   bottom centre
	  skill hotbar + dash cooldowns              bottom centre
	  status (STUNNED / BLOCKING / ...)          above the bars
	  damage vignette                            screen edges

	Gameplay modules feed it through setProviders and the event functions
	below; the Hud never reaches into them.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)

local Keybinds = require(script.Parent.Keybinds)
local Settings = require(script.Parent.Settings)
local Ui = require(script.Parent.Ui)

export type Slot = {
	key: string,
	name: string,
	remaining: number,
	total: number,
}

local Hud = {}

local player = Players.LocalPlayer

local BAR_WIDTH = 440
local SLOT_WIDTH = 104
local SLOT_GAP = 6
local COMBO_FADE = 2.5
local FEED_MAX = 5

local providers: {
	slots: (() -> { Slot })?,
	dashes: (() -> (number, number, number, number))?,
	status: (() -> string?)?,
} =
	{}

local gui: ScreenGui
local nameLabel: TextLabel
local healthText: TextLabel
local healthFill: Frame
local healthLag: Frame
local awakenFill: Frame
local awakenLabel: TextLabel
local evasiveFill: Frame
local statusLabel: TextLabel
local hotbar: Frame
local slotViews: { { frame: Frame, key: TextLabel, name: TextLabel, cooldown: Frame, seconds: TextLabel } } = {}
local dashViews: { { fill: Frame, label: TextLabel } } = {}
local comboFrame: Frame
local comboTotal: TextLabel
local comboLast: TextLabel
local comboScale: UIScale
local comboHideAt = 0
local feedList: Frame
local feedEntries: { Frame } = {}
local feedOrder = 0
local cyclePill: Frame
local cycleLabel: TextLabel
local notice: Frame
local noticeLabel: TextLabel
local noticeBacking: Frame
local noticeScale: UIScale
local noticeHideAt = 0
local hintLabel: TextLabel
local vignette: { Frame } = {}
local vignetteAlpha = 0
local shownHealth = 1
local menuCallbacks: { [string]: () -> () } = {}

local function tween(instance: Instance, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals)
		:Play()
end

local function myColor(): Color3
	return Palette.color(player:GetAttribute("ColorId"))
end

-- Construction ----------------------------------------------------------------------

local function bar(parent: Instance, y: number, height: number, color: Color3): (Frame, Frame)
	local back = Ui.create("Frame", {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Color3.fromRGB(6, 6, 9),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	}, { Ui.corner(2) })
	local fill = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = back,
	}, { Ui.corner(2), Ui.sheen() })
	return back, fill
end

local function buildVitals()
	local cluster = Ui.create("Frame", {
		Name = "Vitals",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -86),
		Size = UDim2.fromOffset(BAR_WIDTH, 62),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	nameLabel = Ui.label({
		Size = UDim2.new(0.6, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.FONT_TAG,
		TextSize = 20,
		Text = "",
		Parent = cluster,
	})
	Ui.textStroke(1.5).Parent = nameLabel
	healthText = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Size = UDim2.new(0.4, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Ui.FONT_NUMBERS,
		TextSize = 22,
		Text = "",
		Parent = cluster,
	})
	Ui.textStroke(1.5).Parent = healthText

	local healthBack
	healthBack, healthFill = bar(cluster, 26, 16, Color3.fromRGB(240, 240, 244))
	-- A pale "damage lag" bar that drains behind the real one.
	healthLag = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 110, 90),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = healthBack,
	}, { Ui.corner(2) })
	Ui.stroke(1, Color3.new(1, 1, 1), 0.8).Parent = healthBack

	local _awakenBack
	_awakenBack, awakenFill = bar(cluster, 46, 7, Ui.ACCENT)
	awakenLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 64, 0, 49),
		Size = UDim2.fromOffset(60, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.FONT_NUMBERS,
		TextSize = 16,
		TextColor3 = Ui.ACCENT,
		Text = "",
		Parent = cluster,
	})
	Ui.textStroke(1.2).Parent = awakenLabel

	local _evasiveBack
	_evasiveBack, evasiveFill = bar(cluster, 56, 5, Ui.EVASIVE)

	statusLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.new(1, 0, 0, 20),
		Font = Ui.FONT,
		TextSize = 18,
		TextColor3 = Ui.DANGER,
		Text = "",
		Parent = cluster,
	})
	Ui.textStroke(1.5).Parent = statusLabel
end

local function buildHotbar()
	hotbar = Ui.create("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(4 * (SLOT_WIDTH + SLOT_GAP) + 70, 56),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, SLOT_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Dash cooldown pips sit at the end of the hotbar.
	local dashBox = Ui.create("Frame", {
		LayoutOrder = 99,
		Size = UDim2.fromOffset(64, 56),
		BackgroundTransparency = 1,
		Parent = hotbar,
	})
	for index, name in { "FRONT", "SIDE" } do
		local pill = Ui.create("Frame", {
			Position = UDim2.fromOffset(0, (index - 1) * 29),
			Size = UDim2.fromOffset(64, 25),
			BackgroundColor3 = Ui.PANEL,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = dashBox,
		}, { Ui.corner(4), Ui.stroke() })
		local fill = Ui.create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			Parent = pill,
		})
		local label = Ui.label({
			Size = UDim2.fromScale(1, 1),
			Font = Ui.FONT,
			TextSize = 13,
			Text = name,
			ZIndex = 2,
			Parent = pill,
		})
		table.insert(dashViews, { fill = fill, label = label })
	end
end

local function slotView(index: number)
	local existing = slotViews[index]
	if existing then
		return existing
	end
	local frame = Ui.create("Frame", {
		LayoutOrder = index,
		Size = UDim2.fromOffset(SLOT_WIDTH, 52),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = hotbar,
	}, { Ui.corner(4), Ui.stroke() })
	local cooldown = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	})
	local key = Ui.label({
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.fromOffset(30, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.FONT_NUMBERS,
		TextSize = 16,
		TextColor3 = Ui.MUTED,
		ZIndex = 3,
		Parent = frame,
	})
	local name = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -8, 0, 30),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextSize = 15,
		ZIndex = 3,
		Parent = frame,
	})
	local seconds = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(60, 28),
		Font = Ui.FONT_NUMBERS,
		TextSize = 26,
		ZIndex = 4,
		Parent = frame,
	})
	Ui.textStroke(1.5).Parent = seconds
	local view = { frame = frame, key = key, name = name, cooldown = cooldown, seconds = seconds }
	slotViews[index] = view
	return view
end

local function buildCombo()
	comboFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.52, 0),
		Size = UDim2.fromOffset(200, 100),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	comboScale = Ui.create("UIScale", { Parent = comboFrame })
	comboLast = Ui.label({
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Ui.FONT_NUMBERS,
		TextSize = 26,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "",
		Parent = comboFrame,
	})
	Ui.textStroke(1.5).Parent = comboLast
	comboTotal = Ui.label({
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 64),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Ui.FONT_NUMBERS,
		TextSize = 64,
		TextColor3 = Color3.fromRGB(255, 70, 60),
		Text = "",
		Parent = comboFrame,
	})
	Ui.textStroke(2.5).Parent = comboTotal
end

local function buildTop()
	-- Menu buttons, top left (below Roblox's own buttons).
	local menu = Ui.create("Frame", {
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.fromOffset(330, 34),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, entry in { { "Settings", "SETTINGS" }, { "Characters", "CHARACTERS" } } do
		local button = Ui.create("TextButton", {
			LayoutOrder = order,
			Size = UDim2.fromOffset(150, 32),
			BackgroundColor3 = Ui.PANEL,
			BackgroundTransparency = 0.3,
			AutoButtonColor = true,
			Font = Ui.FONT,
			TextSize = 16,
			TextColor3 = Ui.TEXT,
			Text = entry[2],
			Parent = menu,
		}, { Ui.corner(4), Ui.stroke() })
		button.Activated:Connect(function()
			local callback = menuCallbacks[entry[1]]
			if callback then
				callback()
			end
		end)
	end
	hintLabel = Ui.label({
		Position = UDim2.fromOffset(16, 102),
		Size = UDim2.fromOffset(460, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 15,
		TextColor3 = Ui.MUTED,
		TextStrokeTransparency = 0.5,
		Text = "",
		Parent = gui,
	})

	-- Washout timer pill, top centre.
	cyclePill = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(250, 26),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = gui,
	}, { Ui.corner(13), Ui.stroke() })
	cycleLabel = Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextSize = 16,
		Text = "",
		Parent = cyclePill,
	})

	-- Kill feed, top right.
	feedList = Ui.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 64),
		Size = UDim2.fromOffset(380, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Callouts: graffiti text on a tilted paint sticker.
	notice = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.27),
		Size = UDim2.fromOffset(640, 70),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	noticeScale = Ui.create("UIScale", { Parent = notice })
	noticeBacking = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0.78, 0),
		Rotation = -2.5,
		BackgroundColor3 = Ui.ACCENT,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Parent = notice,
	}, { Ui.corner(14) })
	noticeLabel = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Rotation = -2.5,
		Font = Ui.FONT_TAG,
		TextSize = 40,
		Text = "",
		ZIndex = 2,
		Parent = notice,
	})
	Ui.textStroke(2.5).Parent = noticeLabel
end

local function buildVignette()
	local edges = {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.18), 90 },
		{ UDim2.fromScale(0, 0.82), UDim2.fromScale(1, 0.18), -90 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(0.14, 1), 0 },
		{ UDim2.fromScale(0.86, 0), UDim2.fromScale(0.14, 1), 180 },
	}
	for _, edge in edges do
		local frame = Ui.create("Frame", {
			Position = edge[1],
			Size = edge[2],
			BackgroundColor3 = Color3.fromRGB(200, 15, 25),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = gui,
		}, {
			Ui.create("UIGradient", {
				Rotation = edge[3],
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		table.insert(vignette, frame)
	end
end

-- Per-frame refresh ------------------------------------------------------------------

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function refreshCycle()
	local phase = workspace:GetAttribute("Phase")
	local endsAt = workspace:GetAttribute("PhaseEndsAt")
	if typeof(phase) ~= "string" or typeof(endsAt) ~= "number" then
		cyclePill.Visible = false
		return
	end
	cyclePill.Visible = true
	local left = endsAt - workspace:GetServerTimeNow()
	if phase == "Warning" then
		cycleLabel.Text = "WASHOUT IN " .. formatTime(left) .. "  ·  GET UNDER A ROOF"
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
		cycleLabel.TextColor3 = Ui.ACCENT:Lerp(Color3.new(1, 1, 1), pulse)
		cyclePill.Size = UDim2.fromOffset(330, 26)
	elseif phase == "Storm" then
		cycleLabel.Text = "WASHOUT  ·  " .. formatTime(left) .. "  ·  STAY SHELTERED"
		cycleLabel.TextColor3 = Color3.fromRGB(130, 200, 255)
		cyclePill.Size = UDim2.fromOffset(330, 26)
	else
		cycleLabel.Text = "WASHOUT IN " .. formatTime(left)
		cycleLabel.TextColor3 = Ui.MUTED
		cyclePill.Size = UDim2.fromOffset(200, 26)
	end
end

local function refreshVitals(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local kit = Characters.get(player:GetAttribute("Kit"))
	local color = myColor()
	nameLabel.Text = string.upper(kit.name)
	nameLabel.TextColor3 = color

	local health, maxHealth = 0, 100
	if humanoid then
		health, maxHealth = humanoid.Health, humanoid.MaxHealth
	end
	local fraction = math.clamp(health / math.max(maxHealth, 1), 0, 1)
	healthFill.Size = UDim2.fromScale(fraction, 1)
	healthFill.BackgroundColor3 = if fraction < 0.3
		then Ui.DANGER
		else Color3.fromRGB(240, 240, 244):Lerp(Color3.fromRGB(255, 220, 120), 1 - fraction)
	shownHealth = if shownHealth > fraction then math.max(shownHealth - dt * 0.5, fraction) else fraction
	healthLag.Size = UDim2.fromScale(shownHealth, 1)
	healthText.Text = string.format("%d", math.ceil(health))

	local awakening = (player:GetAttribute("Awakening") or 0) / 100
	local awakenEnds = player:GetAttribute("AwakenEnds") or 0
	local awakenLeft = awakenEnds - workspace:GetServerTimeNow()
	if awakenLeft > 0 then
		awakenFill.Size = UDim2.fromScale(math.clamp(awakenLeft / Config.AWAKEN_DURATION, 0, 1), 1)
		awakenFill.BackgroundColor3 = color
		awakenLabel.Text = "AWAKENED"
		awakenLabel.TextColor3 = color
	else
		awakenFill.Size = UDim2.fromScale(math.clamp(awakening, 0, 1), 1)
		awakenFill.BackgroundColor3 = Ui.ACCENT
		local ready = awakening >= 1
		awakenLabel.Text = if ready then "[" .. Keybinds.label("Awaken") .. "] AWAKEN" else ""
		awakenLabel.TextColor3 = Ui.ACCENT:Lerp(Color3.new(1, 1, 1), 0.5 + 0.5 * math.sin(os.clock() * 7))
	end
	local evasive = (player:GetAttribute("Evasive") or 0) / 100
	evasiveFill.Size = UDim2.fromScale(math.clamp(evasive, 0, 1), 1)
	evasiveFill.BackgroundColor3 = if evasive >= 1 then Color3.fromRGB(110, 160, 255) else Ui.EVASIVE

	-- Persistent red edge pulse when nearly dead.
	local danger = if fraction < 0.3 and health > 0
		then (0.3 - fraction) / 0.3 * (0.55 + 0.25 * math.sin(os.clock() * 6))
		else 0
	local alpha = math.max(vignetteAlpha, danger)
	for _, edge in vignette do
		edge.BackgroundTransparency = 1 - alpha * 0.7
	end
end

local function refreshHotbar()
	local slots = if providers.slots then providers.slots() else {}
	for index, slot in slots do
		local view = slotView(index)
		view.key.Text = slot.key
		view.name.Text = string.upper(slot.name)
		local ratio = if slot.total > 0 then math.clamp(slot.remaining / slot.total, 0, 1) else 0
		view.cooldown.Size = UDim2.fromScale(1, ratio)
		view.seconds.Text = if slot.remaining > 0.05 then string.format("%.1f", slot.remaining) else ""
		view.name.TextTransparency = if slot.remaining > 0.05 then 0.45 else 0
	end
	if providers.dashes then
		local frontLeft, frontTotal, sideLeft, sideTotal = providers.dashes()
		for index, pair in { { frontLeft, frontTotal }, { sideLeft, sideTotal } } do
			local view = dashViews[index]
			local ready = pair[1] <= 0.05
			view.fill.Size = UDim2.fromScale(if ready then 1 else 1 - pair[1] / pair[2], 1)
			view.fill.BackgroundTransparency = if ready then 0.75 else 0.88
			view.label.TextTransparency = if ready then 0 else 0.5
		end
	end
end

local function refresh(dt: number)
	refreshCycle()
	vignetteAlpha = math.max(vignetteAlpha - dt * 2.2, 0)
	refreshVitals(dt)
	refreshHotbar()
	statusLabel.Text = if providers.status then providers.status() or "" else ""

	local now = os.clock()
	if comboFrame.Visible and now > comboHideAt then
		comboFrame.Visible = false
	end
	if notice.Visible and now > noticeHideAt then
		notice.Visible = false
	end
end

-- Public API -------------------------------------------------------------------------

function Hud.setProviders(slots: () -> { Slot }, dashes: () -> (number, number, number, number), status: () -> string?)
	providers.slots = slots
	providers.dashes = dashes
	providers.status = status
end

-- Hooks up the top-left menu buttons ("Settings", "Characters").
function Hud.setMenuCallback(name: string, callback: () -> ())
	menuCallbacks[name] = callback
end

-- The JJS-style damage counter: total of the current combo, last hit above.
function Hud.damageCounter(damage: number, comboDamage: number, blocked: boolean)
	if not Settings.get("damageCounter") then
		return
	end
	comboFrame.Visible = true
	comboLast.Text = if blocked then "BLOCKED" else "+" .. damage
	comboLast.TextColor3 = if blocked then Color3.fromRGB(150, 200, 255) else Color3.new(1, 1, 1)
	comboTotal.Text = comboDamage .. " DMG"
	comboScale.Scale = 1.25
	tween(comboScale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	comboHideAt = os.clock() + COMBO_FADE
end

function Hud.hurt(damage: number, heavy: boolean?)
	vignetteAlpha = math.max(vignetteAlpha, math.clamp(damage / 25, 0.25, 0.9) + (if heavy then 0.15 else 0))
end

local NOTICE_COLORS = {
	ko = Color3.fromRGB(255, 72, 72),
	warning = Color3.fromRGB(255, 196, 64),
	storm = Color3.fromRGB(80, 150, 255),
	guardbreak = Color3.fromRGB(255, 110, 60),
	evasive = Color3.fromRGB(70, 110, 230),
	error = Color3.fromRGB(90, 90, 100),
	info = Color3.fromRGB(60, 60, 70),
}

function Hud.notify(text: string, kind: string?)
	local small = kind == "error" or kind == "evasive"
	noticeLabel.Text = text
	noticeLabel.TextSize = if small then 26 else 40
	noticeBacking.BackgroundColor3 = NOTICE_COLORS[kind or "info"] or NOTICE_COLORS.info
	noticeBacking.Size = UDim2.new(if small then 0.5 else 0.8, 0, 0.78, 0)
	notice.Visible = true
	noticeScale.Scale = 1.35
	tween(noticeScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	noticeHideAt = os.clock() + (if small then 1.2 else 2.4)
end

function Hud.feed(killerName: string, killerColorId: number, victimName: string, victimColorId: number, verb: string)
	feedOrder += 1
	local parts = {}
	if killerName ~= "" then
		table.insert(
			parts,
			string.format("<font color='#%s'><b>%s</b></font>", Ui.hex(Palette.color(killerColorId)), killerName)
		)
	end
	table.insert(parts, verb)
	if victimName ~= "" then
		table.insert(
			parts,
			string.format("<font color='#%s'><b>%s</b></font>", Ui.hex(Palette.color(victimColorId)), victimName)
		)
	end
	local entry = Ui.create("Frame", {
		LayoutOrder = -feedOrder,
		Size = UDim2.fromOffset(380, 26),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = feedList,
	}, { Ui.corner(4) })
	local label = Ui.label({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 16,
		RichText = true,
		Text = table.concat(parts, " "),
		Parent = entry,
	})
	table.insert(feedEntries, entry)
	if #feedEntries > FEED_MAX then
		table.remove(feedEntries, 1):Destroy()
	end
	task.delay(6, function()
		if entry.Parent then
			tween(entry, 0.4, { BackgroundTransparency = 1 })
			tween(label, 0.4, { TextTransparency = 1 })
			task.delay(0.45, function()
				local index = table.find(feedEntries, entry)
				if index then
					table.remove(feedEntries, index)
				end
				entry:Destroy()
			end)
		end
	end)
end

function Hud.init()
	gui = Ui.create("ScreenGui", {
		Name = "SplotchHud",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildVignette()
	buildVitals()
	buildHotbar()
	buildCombo()
	buildTop()

	local function hint()
		hintLabel.Text = string.format(
			"[%s] settings & controls  ·  [%s] characters  ·  Left Shift: shift lock",
			Keybinds.label("Settings"),
			Keybinds.label("Characters")
		)
	end
	hint()
	Keybinds.onChanged(hint)
	task.delay(30, function()
		tween(hintLabel, 1, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)

	RunService.RenderStepped:Connect(refresh)
end

return Hud
