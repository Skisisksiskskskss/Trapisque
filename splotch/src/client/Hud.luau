--[[
	Hud: everything on screen.

	  crosshair + hitmarker + paint meter     centre
	  status (STUNNED / BLOCKING / ...)        under the crosshair
	  health and paint bars                    bottom left
	  hotbar with cooldowns                    bottom centre
	  combo counter                            right
	  kill feed                                top right
	  Washout timer                            top centre
	  big notifications                        upper centre
	  damage vignette                          screen edges
	  controls help (H)                        left

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

local Ui = require(script.Parent.Ui)

export type Slot = {
	key: string,
	name: string,
	remaining: number,
	total: number,
	active: boolean,
}

local Hud = {}

local player = Players.LocalPlayer

local providers: {
	slots: (() -> { Slot })?,
	status: (() -> string?)?,
} = {}

local gui: ScreenGui
local hitmarker: Frame
local hitmarkerLines: { Frame } = {}
local paintMeterFill: Frame
local statusLabel: TextLabel
local healthFill: Frame
local healthText: TextLabel
local paintFill: Frame
local kitLabel: TextLabel
local hotbar: Frame
local slotFrames: { { frame: Frame, key: TextLabel, name: TextLabel, cooldown: Frame, seconds: TextLabel, stroke: UIStroke } } = {}
local comboFrame: Frame
local comboCount: TextLabel
local comboScale: UIScale
local comboHideAt = 0
local feedList: Frame
local cycleLabel: TextLabel
local noticeLabel: TextLabel
local noticeScale: UIScale
local noticeHideAt = 0
local vignette: { Frame } = {}
local vignetteAlpha = 0
local helpPanel: Frame
local hitToken = 0
local feedEntries: { Frame } = {}

local FEED_MAX = 5

local function tween(instance: Instance, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals):Play()
end

-- Construction ----------------------------------------------------------------------

local function buildCrosshair()
	local holder = Ui.create("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local arms = {
		{ UDim2.new(0.5, 0, 0, 4), UDim2.fromOffset(2, 9) },
		{ UDim2.new(0.5, 0, 1, -4), UDim2.fromOffset(2, 9) },
		{ UDim2.new(0, 4, 0.5, 0), UDim2.fromOffset(9, 2) },
		{ UDim2.new(1, -4, 0.5, 0), UDim2.fromOffset(9, 2) },
	}
	for _, arm in arms do
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = arm[1],
			Size = arm[2],
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = holder,
		}, { Ui.stroke(1, Color3.new(0, 0, 0), 0.3) })
	end
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = holder,
	}, { Ui.corner(2) })

	hitmarker = Ui.create("Frame", {
		Name = "Hitmarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = holder,
	})
	for _, corner in { { 0.2, 0.2, 45 }, { 0.8, 0.2, -45 }, { 0.2, 0.8, -45 }, { 0.8, 0.8, 45 } } do
		local line = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(corner[1], corner[2]),
			Size = UDim2.fromOffset(10, 3),
			Rotation = corner[3],
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = hitmarker,
		}, { Ui.stroke(1, Color3.new(0, 0, 0), 0.2) })
		table.insert(hitmarkerLines, line)
	end

	local meter = Ui.create("Frame", {
		Name = "PaintMeter",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.5, 30, 0.5, 0),
		Size = UDim2.fromOffset(6, 54),
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = gui,
	}, { Ui.corner(3) })
	paintMeterFill = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Parent = meter,
	}, { Ui.corner(3) })

	statusLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 34),
		Size = UDim2.fromOffset(240, 20),
		Font = Ui.FONT_HEAVY,
		TextSize = 18,
		Text = "",
		Parent = gui,
	})
	Ui.textStroke(1.5).Parent = statusLabel
end

local function bar(parent: Instance, position: UDim2, size: UDim2): Frame
	local back = Ui.create("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Ui.corner(5) })
	return Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Parent = back,
	}, { Ui.corner(5) })
end

local function buildVitals()
	local panel = Ui.create("Frame", {
		Name = "Vitals",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -24),
		Size = UDim2.fromOffset(320, 78),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = gui,
	}, { Ui.corner(10), Ui.stroke(1.5, Color3.new(1, 1, 1), 0.85) })
	kitLabel = Ui.label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.FONT_HEAVY,
		TextSize = 18,
		Text = "",
		Parent = panel,
	})
	healthText = Ui.label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 15,
		Text = "",
		Parent = panel,
	})
	healthFill = bar(panel, UDim2.fromOffset(14, 32), UDim2.new(1, -28, 0, 16))
	paintFill = bar(panel, UDim2.fromOffset(14, 54), UDim2.new(1, -28, 0, 10))
end

local function buildHotbar()
	hotbar = Ui.create("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(7 * 74, 70),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function slotFrame(index: number)
	local existing = slotFrames[index]
	if existing then
		return existing
	end
	local stroke = Ui.stroke(2, Color3.new(1, 1, 1), 0.8)
	local frame = Ui.create("Frame", {
		LayoutOrder = index,
		Size = UDim2.fromOffset(66, 66),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = hotbar,
	}, { Ui.corner(10), stroke })
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
		Position = UDim2.fromOffset(6, 3),
		Size = UDim2.fromOffset(54, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.FONT_HEAVY,
		TextSize = 15,
		TextColor3 = Ui.ACCENT,
		ZIndex = 3,
		Parent = frame,
	})
	local name = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -6, 0, 26),
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 3,
		Parent = frame,
	})
	local seconds = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(50, 24),
		Font = Ui.FONT_HEAVY,
		TextSize = 22,
		ZIndex = 4,
		Parent = frame,
	})
	Ui.textStroke(1.5).Parent = seconds
	local entry = { frame = frame, key = key, name = name, cooldown = cooldown, seconds = seconds, stroke = stroke }
	slotFrames[index] = entry
	return entry
end

local function buildCombo()
	comboFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -60, 0.45, 0),
		Size = UDim2.fromOffset(180, 90),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	comboScale = Ui.create("UIScale", { Parent = comboFrame })
	comboCount = Ui.label({
		Size = UDim2.new(1, 0, 0, 62),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Ui.FONT_HEAVY,
		TextSize = 60,
		TextColor3 = Ui.ACCENT,
		Text = "",
		Parent = comboFrame,
	})
	Ui.textStroke(2.5).Parent = comboCount
	local caption = Ui.label({
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Ui.FONT_HEAVY,
		TextSize = 22,
		Text = "HITS",
		Parent = comboFrame,
	})
	Ui.textStroke(2).Parent = caption
end

local function buildFeedAndBanners()
	feedList = Ui.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 70),
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

	cycleLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(520, 26),
		Font = Ui.FONT_HEAVY,
		TextSize = 20,
		Text = "",
		Parent = gui,
	})
	Ui.textStroke(1.5).Parent = cycleLabel

	noticeLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 60),
		Font = Ui.FONT_HEAVY,
		TextSize = 44,
		Text = "",
		Visible = false,
		Parent = gui,
	})
	noticeScale = Ui.create("UIScale", { Parent = noticeLabel })
	Ui.textStroke(3).Parent = noticeLabel
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
			BackgroundColor3 = Color3.fromRGB(220, 20, 30),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = gui,
		}, {
			Ui.create("UIGradient", {
				Rotation = edge[3],
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
		table.insert(vignette, frame)
	end
end

local HELP_LINES = {
	"<b>CONTROLS</b>",
	"<font color='#ff8c28'>M1</font>  paint shot (hold)",
	"<font color='#ff8c28'>1 2 3</font>  skills",
	"<font color='#ff8c28'>Q</font>  dash (direction you hold)",
	"<font color='#ff8c28'>F</font>  block (hold)",
	"<font color='#ff8c28'>SHIFT</font>  dive into your paint",
	"<font color='#ff8c28'>SPACE</font>  leap out / jump",
	"<font color='#ff8c28'>M</font>  change character",
	"<font color='#ff8c28'>ALT</font>  free the mouse",
	"<font color='#ff8c28'>H</font>  hide this",
	"",
	"Your paint: swim fast, heal, refill, climb walls.",
	"Enemy paint: slows and hurts you.",
	"Low health = you fly further. Watch the edges!",
}

local function buildHelp()
	helpPanel = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.45, 0),
		Size = UDim2.fromOffset(300, 300),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		Ui.corner(10),
		Ui.create("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
		}),
	})
	Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 15,
		RichText = true,
		TextWrapped = true,
		LineHeight = 1.15,
		Text = table.concat(HELP_LINES, "\n"),
		Parent = helpPanel,
	})
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
		cycleLabel.Text = ""
		return
	end
	local left = endsAt - workspace:GetServerTimeNow()
	if phase == "Warning" then
		cycleLabel.Text = "WASHOUT INCOMING  " .. formatTime(left) .. "  -  GET UNDER A ROOF"
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
		cycleLabel.TextColor3 = Color3.fromRGB(255, 210, 60):Lerp(Color3.fromRGB(255, 255, 255), pulse)
	elseif phase == "Storm" then
		cycleLabel.Text = "WASHOUT  " .. formatTime(left) .. "  -  STAY SHELTERED"
		cycleLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
	else
		cycleLabel.Text = "Washout in " .. formatTime(left)
		cycleLabel.TextColor3 = Ui.MUTED
	end
end

local function refreshVitals()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local color = Palette.color(player:GetAttribute("ColorId"))
	local kit = Characters.get(player:GetAttribute("Kit"))
	kitLabel.Text = string.upper(kit.name)
	kitLabel.TextColor3 = color

	local health, maxHealth = 0, 100
	if humanoid then
		health, maxHealth = humanoid.Health, humanoid.MaxHealth
	end
	local fraction = math.clamp(health / math.max(maxHealth, 1), 0, 1)
	healthFill.Size = UDim2.fromScale(fraction, 1)
	healthFill.BackgroundColor3 = Color3.fromRGB(235, 60, 60):Lerp(Color3.fromRGB(100, 230, 110), fraction)
	healthText.Text = string.format("%d / %d", math.ceil(health), maxHealth)

	local paint = player:GetAttribute("Paint") or 0
	local paintFraction = math.clamp(paint / Config.TANK_MAX, 0, 1)
	paintFill.Size = UDim2.fromScale(paintFraction, 1)
	paintFill.BackgroundColor3 = color
	paintMeterFill.Size = UDim2.fromScale(1, paintFraction)
	local low = paint < kit.primary.cost
	paintMeterFill.BackgroundColor3 = if low and math.sin(os.clock() * 14) > 0 then Color3.fromRGB(255, 60, 60) else color

	-- Persistent red edge pulse when nearly dead.
	local danger = if fraction < 0.3 and health > 0 then (0.3 - fraction) / 0.3 * (0.55 + 0.25 * math.sin(os.clock() * 6)) else 0
	local alpha = math.max(vignetteAlpha, danger)
	for _, edge in vignette do
		edge.BackgroundTransparency = 1 - alpha * 0.75
	end
end

local function refreshHotbar()
	local slots = if providers.slots then providers.slots() else {}
	for index, slot in slots do
		local view = slotFrame(index)
		view.key.Text = slot.key
		view.name.Text = slot.name
		local ratio = if slot.total > 0 then math.clamp(slot.remaining / slot.total, 0, 1) else 0
		view.cooldown.Size = UDim2.fromScale(1, ratio)
		view.seconds.Text = if slot.remaining > 0.05 then string.format("%.1f", slot.remaining) else ""
		view.stroke.Color = if slot.active then Palette.color(player:GetAttribute("ColorId")) else Color3.new(1, 1, 1)
		view.stroke.Transparency = if slot.active then 0 else 0.8
		view.frame.BackgroundTransparency = if slot.remaining > 0.05 then 0.45 else 0.25
	end
	hotbar.Size = UDim2.fromOffset(#slots * 74, 70)
end

local function refresh(dt: number)
	refreshCycle()
	vignetteAlpha = math.max(vignetteAlpha - dt * 2.2, 0)
	refreshVitals()
	refreshHotbar()
	local status = if providers.status then providers.status() else nil
	statusLabel.Text = status or ""

	local now = os.clock()
	if comboFrame.Visible and now > comboHideAt then
		comboFrame.Visible = false
	end
	if noticeLabel.Visible and now > noticeHideAt then
		noticeLabel.Visible = false
	end
end

-- Public API -------------------------------------------------------------------------

function Hud.setProviders(slots: () -> { Slot }, status: () -> string?)
	providers.slots = slots
	providers.status = status
end

function Hud.hitmarker(ko: boolean)
	hitmarker.Visible = true
	hitmarker.Size = UDim2.fromOffset(46, 46)
	for _, line in hitmarkerLines do
		line.BackgroundColor3 = if ko then Color3.fromRGB(255, 60, 50) else Color3.new(1, 1, 1)
	end
	tween(hitmarker, 0.12, { Size = UDim2.fromOffset(32, 32) })
	hitToken += 1
	local token = hitToken
	task.delay(if ko then 0.35 else 0.15, function()
		if hitToken == token then
			hitmarker.Visible = false
		end
	end)
end

function Hud.combo(count: number)
	if count < 2 then
		return
	end
	comboFrame.Visible = true
	comboCount.Text = "x" .. count
	comboScale.Scale = 1.35
	tween(comboScale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	comboHideAt = os.clock() + 2
end

function Hud.hurt(damage: number, heavy: boolean?)
	vignetteAlpha = math.max(vignetteAlpha, math.clamp(damage / 25, 0.25, 0.9) + (if heavy then 0.15 else 0))
end

local NOTICE_COLORS = {
	ko = Color3.fromRGB(255, 140, 40),
	warning = Color3.fromRGB(255, 215, 60),
	storm = Color3.fromRGB(120, 200, 255),
	guardbreak = Color3.fromRGB(255, 80, 80),
	error = Color3.fromRGB(255, 110, 110),
	info = Color3.fromRGB(235, 235, 240),
}

function Hud.notify(text: string, kind: string?)
	noticeLabel.Text = text
	noticeLabel.TextColor3 = NOTICE_COLORS[kind or "info"] or NOTICE_COLORS.info
	noticeLabel.TextSize = if kind == "error" then 26 else 44
	noticeLabel.Visible = true
	noticeScale.Scale = 1.3
	tween(noticeScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	noticeHideAt = os.clock() + (if kind == "error" then 1.5 else 2.4)
end

local feedOrder = 0

function Hud.feed(killerName: string, killerColorId: number, victimName: string, victimColorId: number, verb: string)
	feedOrder += 1
	local parts = {}
	if killerName ~= "" then
		table.insert(parts, string.format("<font color='#%s'><b>%s</b></font>", Ui.hex(Palette.color(killerColorId)), killerName))
	end
	table.insert(parts, verb)
	if victimName ~= "" then
		table.insert(parts, string.format("<font color='#%s'><b>%s</b></font>", Ui.hex(Palette.color(victimColorId)), victimName))
	end
	local entry = Ui.create("Frame", {
		LayoutOrder = -feedOrder,
		Size = UDim2.fromOffset(380, 26),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = feedList,
	}, { Ui.corner(6) })
	local label = Ui.label({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 15,
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

function Hud.toggleHelp(visible: boolean?)
	if visible == nil then
		helpPanel.Visible = not helpPanel.Visible
	else
		helpPanel.Visible = visible
	end
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
	buildCrosshair()
	buildVitals()
	buildHotbar()
	buildCombo()
	buildFeedAndBanners()
	buildHelp()
	task.delay(25, function()
		Hud.toggleHelp(false)
	end)
	RunService.RenderStepped:Connect(refresh)
end

return Hud
