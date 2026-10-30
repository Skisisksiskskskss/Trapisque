--[[
	Loading
	The one loading screen, from the first frame until the lobby is up: the logo, a short
	row of board tiles with a die hopping along it to the goal as the game gets ready,
	what's happening, and a tip about the game.

	The game's client script says how far along it is with two attributes on the local
	player (TrapisqueLoad, 0 to 1, and TrapisqueLoadText). At 1 the die reaches the goal
	and the screen lifts; sounds and music finish loading behind it.

	Plain frames only: it runs from ReplicatedFirst before any of the game's modules
	exist, so its few colours and fonts are copied from Theme.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local BG = Color3.fromHex("203646")
local TILE = Color3.fromHex("2C475A")
local DONE = Color3.fromHex("E8643C")
local GOAL = Color3.fromHex("E7B023")
local DIE = Color3.fromHex("FFFFFF")
local PIP = Color3.fromHex("23262D")
local TEXT = Color3.fromHex("F7F5F0")
local SOFT = Color3.fromHex("A9BBC8")

local NUNITO = Font.fromEnum(Enum.Font.Nunito).Family
local LOGO = Font.fromEnum(Enum.Font.FredokaOne)

local TIPS = {
	"Pick one die to move with. The other one charges your Power.",
	"Your hidden traps can only be seen by your team, and by the Overseer.",
	"Land exactly on a rival to bump them back 2 tiles.",
	"Rolled doubles? The second die can take you backwards.",
	"Fall far behind and you roll an extra gold die.",
	"Hover a die, or tap it, to see exactly where it takes you.",
	"Every character has one colour, and it's that player's colour everywhere.",
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

local gui = new("ScreenGui", {
	Name = "TrapisqueLoading",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 100,
})
pcall(function()
	gui.ScreenInsets = Enum.ScreenInsets.None
end)

local backdrop = new("Frame", {
	Name = "Backdrop",
	BackgroundColor3 = BG,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, gui)

-- everything else is laid out on a 900 x 640 stage, scaled to fit the screen
local W, H = 900, 640
local stage = new("Frame", {
	Name = "Stage",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
}, backdrop)
local fit = new("UIScale", {}, stage)
local function resize()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		fit.Scale = math.min(size.X / W, size.Y / H, 1.5)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)

new("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(W / 2, 200),
	Size = UDim2.fromOffset(760, 110),
	FontFace = LOGO,
	Text = "Trapisque",
	TextSize = 96,
	TextColor3 = TEXT,
}, stage)

-- the track: a straight row of tiles, the last one the goal
local STOPS = 9
local GAP = 70
local TRACK_Y = 360
local stops: { Vector2 } = {}
for i = 1, STOPS + 1 do
	table.insert(stops, Vector2.new(W / 2 + (i - 1 - STOPS / 2) * GAP, TRACK_Y))
end
local tiles = {}
for i, p in stops do
	local goal = i == #stops
	local size = if goal then 52 else 44
	local tile = new("Frame", {
		Name = if goal then "Goal" else "Tile" .. i,
		BackgroundColor3 = if goal then GOAL else TILE,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(p.X, p.Y),
		Size = UDim2.fromOffset(size, size),
	}, stage)
	round(tile, 10)
	tiles[i] = tile
end
local goalScale = new("UIScale", {}, tiles[#tiles])

-- the piece: a die that hops from tile to tile
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
	BackgroundColor3 = DIE,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(40, 40),
	ZIndex = 5,
}, stage)
round(die, 9)
local pips = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, die)
local function face(n: number)
	for _, c in pips:GetChildren() do
		c:Destroy()
	end
	for _, at in PIPS[n] do
		local pip = new("Frame", {
			BackgroundColor3 = PIP,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(at[1], at[2]),
			Size = UDim2.fromScale(0.18, 0.18),
			ZIndex = 6,
		}, pips)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pip)
	end
end
face(5)
local function standOn(p: Vector2, lift: number)
	die.Position = UDim2.fromOffset(p.X, p.Y + 20 - lift)
end
standOn(stops[1], 0)
tiles[1].BackgroundColor3 = DONE

local status = new("TextLabel", {
	Name = "Status",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(W / 2, 430),
	Size = UDim2.fromOffset(820, 36),
	FontFace = Font.new(NUNITO, Enum.FontWeight.Bold),
	Text = "Loading...",
	TextSize = 26,
	TextColor3 = TEXT,
	TextWrapped = true,
}, stage)
local tip = new("TextLabel", {
	Name = "Tip",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(W / 2, 474),
	Size = UDim2.fromOffset(700, 60),
	FontFace = Font.new(NUNITO, Enum.FontWeight.SemiBold),
	Text = "",
	TextSize = 20,
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

-- the die hops toward the tile that matches the progress (and on to the goal at the end)
local at = 1
local function hop(from: Vector2, to: Vector2, seconds: number)
	local t0 = os.clock()
	while true do
		local t = math.min(1, (os.clock() - t0) / seconds)
		standOn(from:Lerp(to, t), math.sin(t * math.pi) * 26)
		die.Rotation = (1 - t) * 90
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
			want = STOPS + 1 -- the goal
		end
		if at < want then
			local fast = goal >= 1
			local from = stops[at]
			local to = stops[at + 1]
			face(math.random(1, 6))
			hop(from, to, if fast then 0.11 else 0.2)
			at += 1
			if at <= STOPS then
				tiles[at].BackgroundColor3 = DONE
			else
				TweenService:Create(goalScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.2 }):Play()
				task.wait(0.12)
				TweenService:Create(goalScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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

-- lift once the game is ready and the die has reached the goal
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
	end
end
task.wait(0.45)
gui:Destroy()
