--!strict
-- Always-on HUD: cash, wave timer, incoming brainrot card + CHARGE button, boosts, menu, door alarm, toasts and
-- server announcements. Layout is mobile-first: big touch targets, nothing under the thumbstick or jump button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Config.Brainrots)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local BrainrotBuilder = require(Shared.Modules.BrainrotBuilder)
local Format = require(Shared.Modules.Format)
local Signal = require(Shared.Modules.Signal)
local Kit = require(script.Parent.Kit)

local LocalPlayer = Players.LocalPlayer

local Hud = {}

Hud.MenuClicked = Signal.new() :: Signal.Signal<string>
Hud.ChargePressed = Signal.new() :: Signal.Signal<()>
Hud.BoostPressed = Signal.new() :: Signal.Signal<string>
Hud.RepairOfferPressed = Signal.new() :: Signal.Signal<()>

local screen: ScreenGui
local scaled: { UIScale } = {}

-- Elements
local cashLabel: TextLabel
local incomeLabel: TextLabel
local waveTitle: TextLabel
local waveTimer: TextLabel
local wavePill: Frame
local eventBanner: Frame
local eventLabel: TextLabel
local incomingCard: Frame
local incomingName: TextLabel
local incomingTags: TextLabel
local incomingPower: TextLabel
local incomingCrystal: TextLabel
local incomingBarFill: Frame
local incomingHint: TextLabel
local incomingViewport: Frame
local chargeButton: TextButton
local chargeRing: Frame
local chargeLabel: TextLabel
local boostBar: Frame
local boostButtons: { [string]: TextButton } = {}
local doorAlert: Frame
local doorAlertLabel: TextLabel
local toastHolder: Frame
local announceLabel: TextLabel
local menuButtons: { [string]: TextButton } = {}
local giftButton: TextButton

local state: { [string]: any }? = nil
local incoming: { { [string]: any } } = {}
local predictedCharge = 0
local lastTap = 0
local announceToken = 0

local function addScale(gui: GuiObject): UIScale
	local s = Kit.new("UIScale", { Parent = gui })
	table.insert(scaled, s)
	return s
end

function Hud.SetScale(value: number)
	for _, s in scaled do
		s.Scale = value
	end
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function pill(props: Kit.Props): Frame
	local frame = Kit.panelFrame(props)
	Kit.gradient(Kit.Colors.PanelLight, Kit.Colors.Panel).Parent = frame
	return frame
end

local function buildTop()
	local cashPill = pill({
		Name = "Cash",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(270, 70),
		Parent = screen,
	})
	addScale(cashPill)
	cashLabel = Kit.label({
		Name = "Amount",
		Text = "$0",
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.fromOffset(8, 2),
		TextColor3 = Kit.Colors.Cash,
		MaxTextSize = 42,
		Parent = cashPill,
	})
	incomeLabel = Kit.label({
		Name = "Income",
		Text = "+$0/s",
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 46),
		TextColor3 = Kit.Colors.Muted,
		MaxTextSize = 20,
		Parent = cashPill,
	})

	wavePill = pill({
		Name = "Wave",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(210, 70),
		Parent = screen,
	})
	addScale(wavePill)
	waveTitle = Kit.label({
		Text = "🌊 NEXT WAVE",
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.fromOffset(6, 6),
		TextColor3 = Kit.Colors.Blue,
		MaxTextSize = 24,
		Parent = wavePill,
	})
	waveTimer = Kit.label({
		Text = "0:50",
		Size = UDim2.new(1, -12, 0, 34),
		Position = UDim2.fromOffset(6, 30),
		MaxTextSize = 34,
		Parent = wavePill,
	})

	eventBanner = pill({
		Name = "Event",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 82),
		Size = UDim2.fromOffset(360, 40),
		Visible = false,
		Parent = screen,
	})
	addScale(eventBanner)
	eventLabel = Kit.label({
		Text = "",
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromOffset(6, 3),
		TextColor3 = Kit.Colors.Yellow,
		MaxTextSize = 26,
		Parent = eventBanner,
	})
end

local MENU = {
	{ Name = "Upgrade", Icon = "⬆️", Color = Kit.Colors.Green },
	{ Name = "Shop", Icon = "🛒", Color = Kit.Colors.Yellow },
	{ Name = "Brainrots", Icon = "🎒", Color = Kit.Colors.Blue },
	{ Name = "Index", Icon = "📖", Color = Kit.Colors.Purple },
	{ Name = "Daily", Icon = "📅", Color = Kit.Colors.Pink },
	{ Name = "Codes", Icon = "🎟️", Color = Kit.Colors.Orange },
	{ Name = "Settings", Icon = "⚙️", Color = Kit.Colors.Grey },
}

local function buildMenu()
	local menu = Kit.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.42, 0),
		Size = UDim2.fromOffset(150, 420),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	addScale(menu)
	local grid = Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(68, 68),
		CellPadding = UDim2.fromOffset(8, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = menu,
	})
	grid.FillDirectionMaxCells = 2
	for i, item in MENU do
		local button = Kit.button({
			Name = item.Name,
			Text = item.Icon,
			Color = item.Color,
			LayoutOrder = i,
			TextSize = 34,
			Parent = menu,
			OnClick = function()
				Hud.MenuClicked:Fire(item.Name)
			end,
		})
		Kit.label({
			Name = "Caption",
			Text = item.Name,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 6),
			Size = UDim2.new(1, 6, 0, 18),
			MaxTextSize = 16,
			Parent = button,
		})
		local badge = Kit.new("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Kit.Colors.Red,
			Visible = false,
			Parent = button,
		}, { Kit.corner(11), Kit.stroke(2) })
		Kit.label({ Text = "!", Size = UDim2.fromScale(1, 1), MaxTextSize = 18, Parent = badge })
		menuButtons[item.Name] = button
	end

	giftButton = Kit.button({
		Name = "Gift",
		Text = "🎁 Gift in 0:00",
		Color = Kit.Colors.Pink,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 8, 0, 58),
		Size = UDim2.fromOffset(170, 44),
		TextSize = 22,
		Parent = screen,
		OnClick = function()
			Hud.MenuClicked:Fire("Gifts")
		end,
	})
	addScale(giftButton)
end

function Hud.SetBadge(name: string, visible: boolean)
	local button = menuButtons[name]
	local badge = button and button:FindFirstChild("Badge") :: Frame?
	if badge then
		badge.Visible = visible
	end
end

function Hud.SetGiftText(text: string, ready: boolean)
	giftButton.Text = text
	Kit.setButtonColor(giftButton, if ready then Kit.Colors.Green else Kit.Colors.Pink)
end

local function buildIncoming()
	incomingCard = pill({
		Name = "Incoming",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 84),
		Size = UDim2.fromOffset(300, 176),
		Visible = false,
		Parent = screen,
	})
	addScale(incomingCard)
	incomingViewport = Kit.new("Frame", {
		Name = "Preview",
		Size = UDim2.fromOffset(96, 96),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.fromRGB(20, 18, 40),
		Parent = incomingCard,
	}, { Kit.corner(12) })
	incomingTags = Kit.label({
		Text = "",
		Size = UDim2.new(1, -112, 0, 20),
		Position = UDim2.fromOffset(106, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = incomingCard,
	})
	incomingName = Kit.label({
		Text = "",
		Size = UDim2.new(1, -112, 0, 30),
		Position = UDim2.fromOffset(106, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Parent = incomingCard,
	})
	incomingPower = Kit.label({
		Text = "⚡ 0",
		Size = UDim2.new(0.5, -60, 0, 26),
		Position = UDim2.fromOffset(106, 62),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Kit.Colors.Yellow,
		MaxTextSize = 24,
		Parent = incomingCard,
	})
	incomingCrystal = Kit.label({
		Text = "💎 0",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0.5, -50, 0, 26),
		Position = UDim2.new(1, -8, 0, 62),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Kit.Colors.Blue,
		MaxTextSize = 24,
		Parent = incomingCard,
	})
	local bar = Kit.new("Frame", {
		Name = "Bar",
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.fromOffset(8, 108),
		BackgroundColor3 = Color3.fromRGB(20, 18, 40),
		Parent = incomingCard,
	}, { Kit.corner(12), Kit.stroke(2) })
	incomingBarFill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = Kit.Colors.Green,
		Parent = bar,
	}, { Kit.corner(12) })
	Kit.new("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 4, 1, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bar,
	})
	incomingHint = Kit.label({
		Text = "TAP CHARGE!",
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 138),
		TextColor3 = Kit.Colors.Yellow,
		MaxTextSize = 26,
		Parent = incomingCard,
	})
end

local function buildCharge()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	chargeButton = Kit.new("TextButton", {
		Name = "Charge",
		AnchorPoint = Vector2.new(1, 1),
		Position = if touch then UDim2.new(1, -24, 1, -170) else UDim2.new(1, -30, 1, -30),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Parent = screen,
	}, {
		Kit.corner(75),
		Kit.stroke(5),
		Kit.gradient(Color3.fromRGB(120, 230, 255), Color3.fromRGB(40, 110, 230)),
	})
	addScale(chargeButton)
	Kit.bouncy(chargeButton)
	chargeRing = Kit.new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.12, 1.12),
		BackgroundTransparency = 1,
		Parent = chargeButton,
	}, { Kit.corner(90), Kit.stroke(6, Kit.Colors.Yellow) })
	chargeLabel = Kit.label({
		Text = "⚡\nCHARGE",
		Size = UDim2.fromScale(0.85, 0.7),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		MaxTextSize = 32,
		Parent = chargeButton,
	})
	local keyHint = Kit.label({
		Name = "KeyHint",
		Text = if UserInputService.GamepadEnabled then "[R2]" else "[F]",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(80, 22),
		MaxTextSize = 20,
		TextColor3 = Kit.Colors.Muted,
		Visible = not touch,
		Parent = chargeButton,
	})
	keyHint.Visible = not touch
	chargeButton.Activated:Connect(function()
		Hud.ChargePressed:Fire()
	end)

	boostBar = Kit.new("Frame", {
		Name = "Boosts",
		AnchorPoint = Vector2.new(1, 1),
		Position = if touch then UDim2.new(1, -190, 1, -170) else UDim2.new(1, -196, 1, -30),
		Size = UDim2.fromOffset(240, 70),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	addScale(boostBar)
	Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom).Parent =
		boostBar
	for i, boost in
		{
			{ Name = "Overcharge", Icon = "⚡+", Color = Kit.Colors.Blue },
			{ Name = "IronDoor", Icon = "🛡️", Color = Kit.Colors.Grey },
			{ Name = "LuckyWave", Icon = "🍀", Color = Kit.Colors.Green },
		}
	do
		local button = Kit.button({
			Name = boost.Name,
			Text = boost.Icon,
			Color = boost.Color,
			Size = UDim2.fromOffset(66, 66),
			LayoutOrder = i,
			TextSize = 30,
			Parent = boostBar,
			OnClick = function()
				Hud.BoostPressed:Fire(boost.Name)
			end,
		})
		local count = Kit.new("Frame", {
			Name = "Count",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 6, 0, -6),
			Size = UDim2.fromOffset(28, 24),
			BackgroundColor3 = Kit.Colors.Red,
			Parent = button,
		}, { Kit.corner(10), Kit.stroke(2) })
		Kit.label({ Name = "Text", Text = "0", Size = UDim2.fromScale(1, 1), MaxTextSize = 18, Parent = count })
		boostButtons[boost.Name] = button
	end
end

local function buildAlerts()
	doorAlert = Kit.panelFrame({
		Name = "DoorAlert",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.fromOffset(440, 96),
		BackgroundColor3 = Color3.fromRGB(150, 25, 35),
		Visible = false,
		Parent = screen,
	})
	addScale(doorAlert)
	doorAlertLabel = Kit.label({
		Text = "🚨 DOOR BROKEN 0:40",
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 6),
		MaxTextSize = 32,
		Parent = doorAlert,
	})
	Kit.label({
		Text = "Go to your door and hold REPAIR!",
		Size = UDim2.new(0.6, -12, 0, 40),
		Position = UDim2.fromOffset(8, 46),
		TextColor3 = Color3.fromRGB(255, 220, 220),
		MaxTextSize = 20,
		Parent = doorAlert,
	})
	Kit.button({
		Name = "InstantRepair",
		Text = "🔧 Fix Now",
		Color = Kit.Colors.Green,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 44),
		Size = UDim2.new(0.4, -8, 0, 44),
		TextSize = 22,
		Parent = doorAlert,
		OnClick = function()
			Hud.RepairOfferPressed:Fire()
		end,
	})

	toastHolder = Kit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(520, 240),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	addScale(toastHolder)
	Kit.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom).Parent =
		toastHolder

	announceLabel = Kit.label({
		Name = "Announce",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		Size = UDim2.new(0.8, 0, 0, 52),
		MaxTextSize = 44,
		TextTransparency = 1,
		Parent = screen,
	})
	addScale(announceLabel)
end

function Hud.Create(gui: ScreenGui)
	screen = gui
	buildTop()
	buildMenu()
	buildIncoming()
	buildCharge()
	buildAlerts()
end

local TOAST_COLORS: { [string]: Color3 } = {
	info = Kit.Colors.Blue,
	good = Kit.Colors.Green,
	bad = Kit.Colors.Red,
	warn = Kit.Colors.Orange,
	new = Kit.Colors.Pink,
	shield = Color3.fromRGB(60, 210, 230),
	reward = Kit.Colors.Yellow,
}

function Hud.Toast(text: string, kind: string?)
	local color = TOAST_COLORS[kind or "info"] or Kit.Colors.Blue
	local toast = Kit.panelFrame({
		Size = UDim2.fromOffset(500, 44),
		BackgroundColor3 = Kit.darken(color, 0.35),
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = toastHolder,
	})
	Kit.label({
		Text = text,
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		MaxTextSize = 22,
		Parent = toast,
	})
	Kit.popIn(toast)
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 4 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	task.delay(4, function()
		if toast.Parent then
			Kit.tween(toast, 0.3, { BackgroundTransparency = 1 })
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

function Hud.Announce(text: string, color: Color3?)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = text
	announceLabel.TextColor3 = color or Kit.Colors.Yellow
	announceLabel.TextTransparency = 0
	local stroke = announceLabel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	Kit.popIn(announceLabel)
	task.delay(3.5, function()
		if token == announceToken then
			Kit.tween(announceLabel, 0.5, { TextTransparency = 1 })
			if stroke then
				Kit.tween(stroke, 0.5, { Transparency = 1 })
			end
		end
	end)
end

function Hud.ScreenGui(): ScreenGui
	return screen
end

function Hud.ChargeButton(): GuiButton
	return chargeButton
end

function Hud.MenuButton(name: string): GuiButton?
	return menuButtons[name]
end

function Hud.BoostButton(name: string): GuiButton?
	return boostButtons[name]
end

local function setIncomingPreview(data: { [string]: any })
	for _, child in incomingViewport:GetChildren() do
		if child:IsA("ViewportFrame") then
			child:Destroy()
		end
	end
	local model = BrainrotBuilder.Build(data.BrainrotId, { Mutation = data.Mutation, Effects = false })
	local viewport = Kit.viewport(model, UDim2.fromScale(1, 1))
	viewport.Parent = incomingViewport
end

function Hud.AddIncoming(data: { [string]: any })
	table.insert(incoming, data)
	table.sort(incoming, function(a, b)
		return a.Resolve < b.Resolve
	end)
	if #incoming == 1 then
		predictedCharge = 0
	end
	local first = incoming[1]
	if first == data then
		setIncomingPreview(data)
	end
end

function Hud.ResolveIncoming(result: { [string]: any })
	for i, data in incoming do
		if data.Id == result.Id then
			table.remove(incoming, i)
			break
		end
	end
	if #incoming == 0 then
		predictedCharge = 0
	else
		setIncomingPreview(incoming[1])
	end
end

-- Local prediction so the bar reacts instantly; the server applies the same rule authoritatively.
function Hud.TryCharge(): boolean
	local first = incoming[1]
	local t = now()
	if not first or t < first.Start or t > first.Resolve - 0.1 then
		return false
	end
	local clock = os.clock()
	if clock - lastTap < GameConfig.ChargeMinTapInterval then
		return false
	end
	lastTap = clock
	predictedCharge = math.min(GameConfig.ChargeMax, predictedCharge + GameConfig.ChargePerTap)
	Kit.tween(chargeRing, 0.05, { Size = UDim2.fromScale(1.25, 1.25) })
	task.delay(0.06, function()
		Kit.tween(chargeRing, 0.15, { Size = UDim2.fromScale(1.12, 1.12) })
	end)
	return true
end

function Hud.HasIncoming(): boolean
	return #incoming > 0
end

function Hud.SetState(newState: { [string]: any })
	state = newState
	cashLabel.Text = Format.Cash(newState.Cash)
	incomeLabel.Text = "+" .. Format.Cash(newState.Income or 0) .. "/s"
	for name, button in boostButtons do
		local count = (newState.Boosts and newState.Boosts[name]) or 0
		local countFrame = button:FindFirstChild("Count")
		local text = countFrame and countFrame:FindFirstChild("Text") :: TextLabel?
		if text then
			text.Text = if count > 0 then tostring(count) else "+"
		end
		if countFrame and countFrame:IsA("Frame") then
			countFrame.BackgroundColor3 = if count > 0 then Kit.Colors.Red else Kit.Colors.Green
		end
	end
	local over = boostButtons.Overcharge
	if over then
		local stroke = over:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if newState.Overcharge then Kit.Colors.Yellow else Kit.Colors.Stroke
			stroke.Thickness = if newState.Overcharge then 5 else 3
		end
	end
end

local function updateIncoming()
	local first = incoming[1]
	local current = state
	if not first or not current then
		incomingCard.Visible = false
		chargeLabel.Text = "⚡\nCHARGE"
		chargeButton.Visible = false
		return
	end
	chargeButton.Visible = true
	incomingCard.Visible = true
	local def = Brainrots.Get(first.BrainrotId)
	local rarity = Rarities.Get(if def then def.Rarity else 1)
	local tags = { string.upper(rarity.Name) }
	if first.Size ~= "Normal" then
		table.insert(tags, 1, string.upper(first.Size))
	end
	if first.Mutation ~= "None" then
		table.insert(tags, 1, string.upper(first.Mutation))
	end
	if first.Boss then
		table.insert(tags, 1, "👑 BOSS")
	end
	incomingTags.Text = table.concat(tags, " · ")
	incomingTags.TextColor3 = rarity.Color
	incomingName.Text = if def then def.Name else "???"
	local over = if current.Overcharge then 0.5 else 0
	local crystal = (current.CrystalPower or 0) * (1 + predictedCharge + over)
	local power = first.Power
	incomingPower.Text = "⚡ " .. Format.Short(power)
	incomingCrystal.Text = "💎 " .. Format.Short(crystal)
	local ratio = crystal / math.max(power, 1)
	incomingBarFill.Size = UDim2.fromScale(math.clamp(ratio / 2, 0.02, 1), 1)
	local winning = first.Guaranteed or ratio >= 1
	incomingBarFill.BackgroundColor3 = if winning
		then Kit.Colors.Green
		else (if ratio > 0.75 then Kit.Colors.Orange else Kit.Colors.Red)
	local t = now()
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 10)
	if first.Guaranteed then
		incomingHint.Text = "✨ GUARANTEED BEAM ✨"
		incomingHint.TextColor3 = Kit.Colors.Green
	elseif winning then
		incomingHint.Text = "YOU'LL BEAM IT! ✅"
		incomingHint.TextColor3 = Kit.Colors.Green
	elseif predictedCharge >= GameConfig.ChargeMax - 0.001 then
		incomingHint.Text = if current.Overcharge then "TOO STRONG! 😱" else "USE OVERCHARGE ⚡+"
		incomingHint.TextColor3 = Kit.Colors.Red
	else
		incomingHint.Text = "TAP CHARGE FAST!"
		incomingHint.TextColor3 = Kit.Colors.Yellow:Lerp(Kit.Colors.Red, pulse)
	end
	local active = t >= first.Start and t <= first.Resolve - 0.1
	chargeLabel.Text = if active
		then string.format("⚡\n+%d%%", math.floor(predictedCharge * 100 + 0.5))
		else "⚡\nGET READY"
	chargeRing.Rotation = (os.clock() * 120) % 360
	local overButton = boostButtons.Overcharge
	if overButton then
		local scale = overButton:FindFirstChildOfClass("UIScale")
		if scale and not winning and not current.Overcharge then
			scale.Scale = 1 + 0.08 * pulse
		elseif scale then
			scale.Scale = 1
		end
	end
end

local function updateWave(info: { [string]: any })
	local t = now()
	if #incoming > 0 then
		waveTitle.Text = "🚨 INCOMING!"
		waveTitle.TextColor3 = Kit.Colors.Red
		local first = incoming[1]
		waveTimer.Text = if t < first.Arrive then "Arrives " .. Format.Clock(first.Arrive - t) else "BEAMING!"
		return
	end
	local stampede = info.StampedeNextWave
	waveTitle.Text = if stampede then "🐘 STAMPEDE IN" else "🌊 NEXT WAVE"
	waveTitle.TextColor3 = if stampede then Kit.Colors.Orange else Kit.Colors.Blue
	local remaining = (info.NextWaveAt or 0) - t
	waveTimer.Text = Format.Clock(math.max(0, remaining))
end

local function updateEvent(info: { [string]: any })
	local t = now()
	local text = ""
	if info.ActiveEvent and info.ActiveEvent ~= "" and (info.EventEndsAt or 0) > t then
		local names: { [string]: string } = {
			GoldenHour = "✨ GOLDEN HOUR",
			RainbowRain = "🌈 RAINBOW RAIN",
			CashRush = "💸 2X CASH RUSH",
			LuckyHour = "🍀 LUCKY HOUR",
		}
		text = (names[info.ActiveEvent] or info.ActiveEvent) .. " · " .. Format.Clock(info.EventEndsAt - t)
	elseif (info.ServerLuckUntil or 0) > os.time() then
		text = string.format(
			"🍀 SERVER LUCK x2 by %s · %s",
			info.ServerLuckBy or "?",
			Format.Clock(info.ServerLuckUntil - os.time())
		)
	elseif info.WeekendBoost then
		text = "🎉 WEEKEND 2X CASH!"
	end
	eventBanner.Visible = text ~= ""
	eventLabel.Text = text
end

local function updateDoor()
	local plotIndex = LocalPlayer:GetAttribute("Plot")
	local plots = Workspace:FindFirstChild("Plots")
	local folder = plots and type(plotIndex) == "number" and plots:FindFirstChild("Plot" .. plotIndex)
	if not folder then
		doorAlert.Visible = false
		return
	end
	local brokenUntil = (folder:GetAttribute("DoorBrokenUntil") :: number?) or 0
	local remaining = brokenUntil - now()
	if remaining > 0 then
		doorAlert.Visible = true
		local shielded = folder:GetAttribute("Shielded") == true
		doorAlertLabel.Text =
			string.format("%s DOOR BROKEN %s", if shielded then "🛡️" else "🚨", Format.Clock(remaining))
		doorAlert.BackgroundColor3 = if shielded
			then Color3.fromRGB(30, 110, 140)
			else Color3.fromRGB(150 + 40 * math.sin(os.clock() * 8), 25, 35)
	else
		doorAlert.Visible = false
	end
end

function Hud.Update(info: { [string]: any })
	updateIncoming()
	updateWave(info)
	updateEvent(info)
	updateDoor()
end

return Hud
