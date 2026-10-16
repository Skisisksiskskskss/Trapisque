--[[
	Loading
	The one loading screen, from the first frame until the lobby is up: the open sea,
	the title in gold comic lettering, and a treasure map card where a die hops along a
	trail of stepping stones to the X as the game gets ready. Under it: what's happening
	and a tip about the game.

	The game's client script says how far along it is with two attributes on the local
	player (TrapisqueLoad, 0 to 1, and TrapisqueLoadText). At 1 the die runs to the X
	and the screen lifts; sounds and music finish loading behind it.

	Plain frames only: it runs from ReplicatedFirst before any of the game's modules
	exist, so its few colours are copied from Theme.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local SEA = Color3.fromHex("17435F")
local WAVE = Color3.fromHex("1F6A8A")
local LINE = Color3.fromHex("1C1A24")
local CARD = Color3.fromHex("F3E6C8")
local STONE = Color3.fromHex("E0CCA0")
local CREAM = Color3.fromHex("FFF8E7")
local SUN = Color3.fromHex("F5B700")
local CORAL = Color3.fromHex("D7263D")
local SOFT = Color3.fromHex("BFD8E4")
local BROWN = Color3.fromHex("5C4A36")

local TIPS = {
	"Pick one die to move with. The other one charges your Power.",
	"Hidden traps can only be seen by your crew... and the Overseer.",
	"Land right on a rival to bonk them back 2 tiles. BOING!",
	"Rolled doubles? The second die can take you backwards.",
	"Fall far behind and you roll an extra gold die.",
	"Quick lines in the chat are free for everyone. Ahoy!",
	"Hover a die (or tap it) to see exactly where it takes you.",
	"Each character has one colour: it's that player's everywhere.",
}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function round(inst: Instance, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
end

local function ink(inst: Instance, thickness: number, color: Color3?)
	return new("UIStroke", { Color = color or LINE, Thickness = thickness }, inst)
end

local gui = new("ScreenGui", {
	Name = "TrapisqueLoading",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 100,
})
pcall(function()
	gui.ScreenInsets = Enum.ScreenInsets.None
end)

local sea = new("Frame", {
	Name = "Sea",
	BackgroundColor3 = SEA,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, gui)
-- printed wave marks on the sea: two shallow arcs each
for i = 0, 17 do
	local mark = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(((i * 37) % 100) / 100, ((i * 61 + 13) % 100) / 100),
		Size = UDim2.fromScale(0.07, 0.07),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	}, sea)
	for side = 0, 1 do
		local arc = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.25 + side * 0.5, 0.75),
			Size = UDim2.fromScale(0.5, 0.5),
		}, mark)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, arc)
		local st = ink(arc, 3, WAVE)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.419, 0),
				NumberSequenceKeypoint.new(0.42, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, st)
	end
end

-- everything else is laid out on a 900 x 640 stage, scaled to fit the screen
local W, H = 900, 640
local stage = new("Frame", {
	Name = "Stage",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
}, sea)
local fit = new("UIScale", {}, stage)
local function resize()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		fit.Scale = math.min(size.X / W, size.Y / H, 1.5)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)

local title = new("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(W / 2, 108),
	Size = UDim2.fromOffset(760, 120),
	Font = Enum.Font.Bangers,
	Text = "TRAPISQUE",
	TextSize = 100,
	TextColor3 = SUN,
	Rotation = -3,
}, stage)
ink(title, 6)

-- the map card, with a hard ink shadow
local CW, CH = 780, 250
local shadow = new("Frame", {
	Name = "Shadow",
	BackgroundColor3 = LINE,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(W / 2 + 9, 344 + 9),
	Size = UDim2.fromOffset(CW, CH),
}, stage)
round(shadow, 16)
local card = new("Frame", {
	Name = "Map",
	BackgroundColor3 = CARD,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(W / 2, 344),
	Size = UDim2.fromOffset(CW, CH),
}, stage)
round(card, 16)
ink(card, 5)

-- the trail: stepping stones winding left to right, dashes between them, X at the end
local STOPS = 12
local stops: { Vector2 } = {}
for i = 1, STOPS do
	local t = (i - 1) / (STOPS - 1)
	table.insert(stops, Vector2.new(70 + t * 560, 128 + math.sin(t * math.pi * 2.2 + 0.4) * 56))
end
local X_AT = Vector2.new(712, 128 + math.sin(math.pi * 2.2 + 0.5) * 50)
for i = 1, STOPS do
	local a = stops[i]
	local b = if i < STOPS then stops[i + 1] else X_AT
	for k = 1, 2 do
		local p = a:Lerp(b, k / 3)
		local dash = new("Frame", {
			BackgroundColor3 = BROWN,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(p.X, p.Y),
			Size = UDim2.fromOffset(9, 9),
		}, card)
		round(dash, 5)
	end
end
local stones = {}
for i, p in stops do
	local stone = new("Frame", {
		Name = "Stone" .. i,
		BackgroundColor3 = STONE,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(p.X, p.Y),
		Size = UDim2.fromOffset(40, 40),
	}, card)
	round(stone, 11)
	ink(stone, 3)
	stones[i] = stone
end
local xMark = new("Frame", {
	Name = "X",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(X_AT.X, X_AT.Y),
	Size = UDim2.fromOffset(64, 64),
}, card)
for _, angle in { 45, -45 } do
	local bar = new("Frame", {
		BackgroundColor3 = CORAL,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(66, 16),
		Rotation = angle,
	}, xMark)
	round(bar, 6)
	ink(bar, 3)
end
local xScale = new("UIScale", {}, xMark)

-- the piece: a die that hops from stone to stone
local PIPS = {
	{ { 0.5, 0.5 } },
	{ { 0.28, 0.28 }, { 0.72, 0.72 } },
	{ { 0.28, 0.28 }, { 0.5, 0.5 }, { 0.72, 0.72 } },
	{ { 0.28, 0.28 }, { 0.72, 0.28 }, { 0.28, 0.72 }, { 0.72, 0.72 } },
	{ { 0.28, 0.28 }, { 0.72, 0.28 }, { 0.5, 0.5 }, { 0.28, 0.72 }, { 0.72, 0.72 } },
	{ { 0.28, 0.25 }, { 0.72, 0.25 }, { 0.28, 0.5 }, { 0.72, 0.5 }, { 0.28, 0.75 }, { 0.72, 0.75 } },
}
local die = new("Frame", {
	Name = "Die",
	BackgroundColor3 = CREAM,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(46, 46),
	ZIndex = 5,
}, card)
round(die, 10)
ink(die, 4)
local pips = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, die)
local function face(n: number)
	for _, c in pips:GetChildren() do
		c:Destroy()
	end
	for _, at in PIPS[n] do
		local pip = new("Frame", {
			BackgroundColor3 = LINE,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(at[1], at[2]),
			Size = UDim2.fromScale(0.19, 0.19),
			ZIndex = 6,
		}, pips)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pip)
	end
end
face(5)
local function standOn(p: Vector2, lift: number)
	die.Position = UDim2.fromOffset(p.X, p.Y + 6 - lift)
end
standOn(stops[1], 0)
stones[1].BackgroundColor3 = SUN

local status = new("TextLabel", {
	Name = "Status",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(W / 2, 498),
	Size = UDim2.fromOffset(820, 40),
	Font = Enum.Font.Oswald,
	Text = "Setting sail...",
	TextSize = 32,
	TextColor3 = CREAM,
	TextWrapped = true,
}, stage)
local tip = new("TextLabel", {
	Name = "Tip",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(W / 2, 548),
	Size = UDim2.fromOffset(820, 60),
	Font = Enum.Font.Oswald,
	Text = "",
	TextSize = 24,
	TextColor3 = SOFT,
	TextWrapped = true,
}, stage)

gui.Parent = player:WaitForChild("PlayerGui")
resize()
ReplicatedFirst:RemoveDefaultLoadingScreen()

---------------------------------------------------------------------------
-- progress
---------------------------------------------------------------------------

-- how far along: the game says so once its script runs; until then, our own guess
local progress = 0.08
local function target(): number
	local p = player:GetAttribute("TrapisqueLoad")
	if type(p) == "number" then
		return math.clamp(p, 0, 1)
	end
	return progress
end
player:GetAttributeChangedSignal("TrapisqueLoadText"):Connect(function()
	local text = player:GetAttribute("TrapisqueLoadText")
	if type(text) == "string" then
		status.Text = text
	end
end)

local alive = true
task.spawn(function()
	local i = math.random(1, #TIPS)
	while alive do
		tip.Text = "Tip: " .. TIPS[i]
		i = i % #TIPS + 1
		task.wait(4)
	end
end)

-- the die hops toward the stone that matches the progress (and on to the X at the end)
local at = 1
local function hop(from: Vector2, to: Vector2, seconds: number)
	local t0 = os.clock()
	while true do
		local t = math.min(1, (os.clock() - t0) / seconds)
		standOn(from:Lerp(to, t), math.sin(t * math.pi) * 30)
		die.Rotation = (1 - t) * 18
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	die.Rotation = 0
end
local finished = false
task.spawn(function()
	local startedAt = os.clock()
	while alive do
		local goal = target()
		local want = math.floor(goal * (STOPS - 1)) + 1
		if goal >= 1 then
			want = STOPS + 1 -- the X
		end
		if at < want then
			local fast = goal >= 1
			local from = stops[at]
			local to = if at + 1 <= STOPS then stops[at + 1] else X_AT
			face(math.random(1, 6))
			hop(from, to, if fast then 0.11 else 0.2)
			at += 1
			if at <= STOPS then
				stones[at].BackgroundColor3 = SUN
			else
				-- treasure!
				TweenService:Create(xScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.35 }):Play()
				task.wait(0.12)
				TweenService:Create(xScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				finished = true
				return
			end
		else
			-- waiting on the game: creep forward a little on our own before its script starts
			if player:GetAttribute("TrapisqueLoad") == nil then
				progress = math.min(0.3, progress + 0.004)
			end
			if os.clock() - startedAt > 45 and status.Text ~= "" and not string.find(status.Text, "rejoin") then
				status.Text = status.Text .. " (taking a while: try rejoining if it's stuck)"
			end
			task.wait(0.1)
		end
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
if player:GetAttribute("TrapisqueLoad") == nil then
	progress = math.max(progress, 0.3)
end

-- lift once the game is ready and the die has reached the X
while not finished do
	task.wait(0.05)
end
task.wait(0.25)
alive = false
local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
for _, d in gui:GetDescendants() do
	if d:IsA("Frame") then
		TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("TextLabel") then
		TweenService:Create(d, info, { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, info, { Transparency = 1 }):Play()
	end
end
task.wait(0.45)
gui:Destroy()
