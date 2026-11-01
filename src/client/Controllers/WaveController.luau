--!strict
-- Renders every wave brainrot and escaped brainrot locally from server timings: emerge from the portal, march
-- to the door, crystal beam struggle, then capture (sucked into the crystal) or the door smash + escape lap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Config.Brainrots)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local BrainrotBuilder = require(Shared.Modules.BrainrotBuilder)
local Format = require(Shared.Modules.Format)
local MapGeometry = require(Shared.Modules.MapGeometry)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)
local EffectsController = require(script.Parent.EffectsController)
local SoundController = require(script.Parent.SoundController)

local LocalPlayer = Players.LocalPlayer

local WaveController = {}

WaveController.LocalIncoming = Signal.new() :: Signal.Signal<{ [string]: any }>
WaveController.LocalResult = Signal.new() :: Signal.Signal<{ [string]: any }>

local WAVE_SCALE = 1.3

type Walker = {
	Data: { [string]: any },
	Model: Model,
	Root: BasePart,
	Height: number,
	Mode: string, -- "Walk" | "Capture" | "Smash" | "Escape" | "Done"
	ModeStart: number,
	Beam: Beam?,
	Target: Attachment?,
	CaptureFrom: CFrame?,
	CapturePlot: number?,
	Heading: CFrame?,
}

local walkers: { [number]: Walker } = {}
local escapes: { [number]: Walker } = {}
local fxFolder: Folder

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function plotFolder(index: number): Instance?
	local plots = Workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. index)
end

local function crystalAttachment(index: number): (Attachment?, Color3)
	local folder = plotFolder(index)
	local base = folder and folder:FindFirstChild("Base")
	local crystal = base and base:FindFirstChild("Crystal")
	local core = crystal and crystal:FindFirstChild("Core")
	local attachment = core and core:FindFirstChild("BeamOrigin") :: Attachment?
	local light = core and core:FindFirstChildOfClass("PointLight")
	return attachment, if light then light.Color else Color3.fromRGB(150, 220, 255)
end

local function doorModel(index: number): Model?
	local folder = plotFolder(index)
	local base = folder and folder:FindFirstChild("Base")
	return base and base:FindFirstChild("Door") :: Model?
end

local function makeTag(model: Model, root: BasePart, data: { [string]: any }, height: number, escaped: boolean)
	local def = Brainrots.Get(data.BrainrotId)
	local rarity = Rarities.Get(if def then def.Rarity else 1)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Tag"
	billboard.Size = UDim2.fromOffset(220, 90)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height + 2.2, 0)
	billboard.MaxDistance = 220
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	billboard.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = billboard
	local function line(text: string, color: Color3, order: number, h: number)
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.Size = UDim2.new(1, 0, h, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeTransparency = 0
		label.Text = text
		label.Parent = billboard
	end
	if escaped then
		line("ESCAPED!", Color3.fromRGB(255, 90, 90), 0, 0.2)
	elseif data.Boss then
		line("👑 BOSS 👑", Color3.fromRGB(255, 120, 60), 0, 0.22)
	end
	local tags = {}
	if data.Size ~= "Normal" then
		table.insert(tags, string.upper(data.Size))
	end
	if data.Mutation ~= "None" then
		table.insert(tags, string.upper(data.Mutation))
	end
	table.insert(tags, string.upper(rarity.Name))
	line(table.concat(tags, " · "), rarity.Color, 1, 0.2)
	line(if def then def.Name else "???", Color3.new(1, 1, 1), 2, 0.3)
	line("⚡ " .. Format.Short(data.Power), Color3.fromRGB(255, 230, 90), 3, 0.28)
	if data.UserId == LocalPlayer.UserId and not escaped then
		billboard.AlwaysOnTop = true
		line("▼ YOURS ▼", Color3.fromRGB(120, 255, 140), 4, 0.18)
	end
	model:SetAttribute("TagHeight", height)
end

local function spawnModel(data: { [string]: any }, escaped: boolean): (Model, BasePart, number)
	local scale = Sizes.Get(data.Size).Scale * WAVE_SCALE
	local model = BrainrotBuilder.Build(data.BrainrotId, { Mutation = data.Mutation, Scale = scale })
	local root = model.PrimaryPart :: BasePart
	local height = (model:GetAttribute("Height") :: number?) or 5
	makeTag(model, root, data, height, escaped)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BeamTarget"
	attachment.Position = Vector3.new(0, height * 0.55, 0)
	attachment.Parent = root
	model.Parent = fxFolder
	return model, root, height
end

local function startBeam(walker: Walker, plotIndex: number)
	local origin, color = crystalAttachment(plotIndex)
	local target = walker.Root:FindFirstChild("BeamTarget") :: Attachment?
	if not origin or not target then
		return
	end
	local beam = Instance.new("Beam")
	beam.Attachment0 = origin
	beam.Attachment1 = target
	beam.Width0 = 1.6
	beam.Width1 = 3.2
	beam.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Transparency = NumberSequence.new(0.05)
	beam.Parent = walker.Root
	walker.Beam = beam
end

local function stopBeam(walker: Walker)
	if walker.Beam then
		walker.Beam:Destroy()
		walker.Beam = nil
	end
end

local function destroyWalker(walker: Walker)
	walker.Mode = "Done"
	stopBeam(walker)
	walker.Model:Destroy()
end

local function smashDoor(plotIndex: number, broken: boolean)
	local door = doorModel(plotIndex)
	local panel = door and door:FindFirstChild("Panel") :: BasePart?
	if not panel then
		return
	end
	if broken then
		EffectsController.Debris(panel.CFrame, panel.Size, panel.Color, panel.Material)
		SoundController.Play("DoorBreak", panel.Position)
	else
		if door then
			EffectsController.Wobble(door)
		end
		SoundController.Play("DoorBlock", panel.Position)
	end
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (root.Position - panel.Position).Magnitude < 80 then
		EffectsController.Shake(if broken then 0.9 else 0.4, 0.45)
	end
end

local function onWaveStart(entries: { { [string]: any } }, stampede: boolean)
	for _, data in entries do
		local model, root, height = spawnModel(data, false)
		local walker: Walker = {
			Data = data,
			Model = model,
			Root = root,
			Height = height,
			Mode = "Walk",
			ModeStart = data.Start,
			Beam = nil,
			Target = nil,
			CaptureFrom = nil,
			CapturePlot = nil,
			Heading = nil,
		}
		walkers[data.Id] = walker
		model:PivotTo(CFrame.new(0, -50, 0))
		if data.UserId == LocalPlayer.UserId then
			WaveController.LocalIncoming:Fire(data)
		end
	end
	SoundController.Play(if stampede then "Stampede" else "WaveHorn")
end

local function onWaveResult(result: { [string]: any })
	local walker = walkers[result.Id]
	if walker then
		local outcome = result.Outcome
		walker.ModeStart = now()
		if outcome == "Captured" then
			walker.Mode = "Capture"
			walker.CaptureFrom = walker.Root.CFrame
			walker.CapturePlot = result.Plot
			if not walker.Beam then
				startBeam(walker, result.Plot)
			end
			SoundController.Play("Capture", walker.Root.Position)
		else
			walker.Mode = "Smash"
			walker.CaptureFrom = walker.Root.CFrame
			stopBeam(walker)
			EffectsController.Flash(
				walker.Root.Position + Vector3.new(0, walker.Height * 0.5, 0),
				Color3.fromRGB(255, 70, 70)
			)
			local broken = outcome == "DoorBroken" or outcome == "Shielded"
			task.delay(0.4, function()
				smashDoor(result.Plot, broken)
			end)
		end
	end
	if walker and walker.Data.UserId == LocalPlayer.UserId then
		WaveController.LocalResult:Fire(result)
	end
end

local function onEscapeStart(data: { [string]: any })
	local model, root, height = spawnModel(data, true)
	local walker: Walker = {
		Data = data,
		Model = model,
		Root = root,
		Height = height,
		Mode = "Escape",
		ModeStart = data.Start,
		Beam = nil,
		Target = nil,
		CaptureFrom = nil,
		CapturePlot = nil,
		Heading = nil,
	}
	escapes[data.Id] = walker
	model:PivotTo(CFrame.new(MapGeometry.RingPosition(data.Angle, data.Radius)))
	-- Clean up the wave walker that is handing over to this escape.
	for id, wave in walkers do
		if wave.Data.Plot == data.FromPlot and wave.Mode == "Smash" then
			destroyWalker(wave)
			walkers[id] = nil
		end
	end
	task.delay(math.max(0, data.Start + data.LapTime + 6 - now()), function()
		local current = escapes[data.Id]
		if current and current.Mode ~= "Done" then
			destroyWalker(current)
			escapes[data.Id] = nil
		end
	end)
end

local function onEscapeEnd(escapeId: number, plotIndex: number, _time: number)
	local walker = escapes[escapeId]
	if not walker then
		return
	end
	walker.ModeStart = now()
	walker.CaptureFrom = walker.Root.CFrame
	if plotIndex > 0 then
		walker.Mode = "Capture"
		walker.CapturePlot = plotIndex
		startBeam(walker, plotIndex)
		SoundController.Play("Capture", walker.Root.Position)
	else
		walker.Mode = "Sink"
	end
end

local function waddle(t: number, speed: number): (number, number)
	local phase = t * speed
	return math.abs(math.sin(phase)) * 0.45, math.sin(phase) * math.rad(9)
end

local function update()
	local t = now()
	for id, walker in walkers do
		local data = walker.Data
		local mode = walker.Mode
		if mode == "Walk" then
			local edge = MapGeometry.PortalEdge(data.Plot)
			local stop = MapGeometry.StopPosition(data.Plot)
			local dir = (stop - edge).Unit
			local heading = CFrame.lookAt(Vector3.zero, dir)
			if t < data.Start then
				walker.Model:PivotTo(CFrame.new(edge - Vector3.new(0, walker.Height + 2, 0)) * heading.Rotation)
			elseif t < data.Start + GameConfig.EmergeTime then
				local alpha = (t - data.Start) / GameConfig.EmergeTime
				local eased = 1 - (1 - alpha) ^ 3
				local y = -walker.Height - 1 + (walker.Height + 1.3) * eased
				walker.Model:PivotTo(
					CFrame.new(edge + Vector3.new(0, y, 0))
						* heading.Rotation
						* CFrame.Angles(0, alpha * math.pi * 2, 0)
				)
			elseif t < data.Arrive then
				local alpha = (t - data.Start - GameConfig.EmergeTime)
					/ (data.Arrive - data.Start - GameConfig.EmergeTime)
				local pos = edge:Lerp(stop, alpha)
				local bob, sway = waddle(t, 9)
				walker.Model:PivotTo(
					CFrame.new(pos + Vector3.new(0, bob, 0)) * heading.Rotation * CFrame.Angles(0, 0, sway)
				)
			else
				if not walker.Beam and t < data.Resolve then
					startBeam(walker, data.Plot)
				end
				local shake = math.sin(t * 40) * 0.12
				walker.Model:PivotTo(
					CFrame.new(stop + Vector3.new(shake, math.abs(math.sin(t * 13)) * 0.3, 0))
						* heading.Rotation
						* CFrame.Angles(0, 0, math.sin(t * 25) * 0.08)
				)
				if walker.Beam then
					walker.Beam.CurveSize0 = math.sin(t * 17) * 2
					walker.Beam.CurveSize1 = math.cos(t * 13) * 2
					walker.Beam.Width1 = 3 + math.sin(t * 30) * 0.8
				end
				if t > data.Resolve + 4 then
					destroyWalker(walker)
					walkers[id] = nil
				end
			end
		elseif mode == "Capture" then
			local origin = crystalAttachment(walker.CapturePlot or data.Plot)
			local from = walker.CaptureFrom or walker.Root.CFrame
			local alpha = math.clamp((t - walker.ModeStart) / 1.0, 0, 1)
			if origin and alpha < 1 then
				local eased = alpha * alpha
				local target = origin.WorldPosition - Vector3.new(0, walker.Height * 0.3 * (1 - eased), 0)
				local pos = from.Position:Lerp(target, eased) + Vector3.new(0, math.sin(alpha * math.pi) * 6, 0)
				walker.Model:PivotTo(CFrame.new(pos) * from.Rotation * CFrame.Angles(0, alpha * math.pi * 6, 0))
				walker.Model:ScaleTo(math.max(0.05, 1 - eased * 0.95))
			else
				if origin then
					EffectsController.Burst(
						origin.WorldPosition,
						Rarities.Get((Brainrots.Get(data.BrainrotId) or Brainrots.List[1]).Rarity).Color
					)
				end
				destroyWalker(walker)
				walkers[id] = nil
			end
		elseif mode == "Smash" then
			local from = walker.CaptureFrom or walker.Root.CFrame
			local door = MapGeometry.DoorPosition(data.Plot)
			local alpha = math.clamp((t - walker.ModeStart) / 0.4, 0, 1)
			local pos = from.Position:Lerp(Vector3.new(door.X, from.Position.Y, door.Z), alpha * 0.55)
			walker.Model:PivotTo(CFrame.new(pos) * from.Rotation * CFrame.Angles(math.rad(-15) * alpha, 0, 0))
			if t - walker.ModeStart > 4 then
				destroyWalker(walker)
				walkers[id] = nil
			end
		end
	end

	for id, walker in escapes do
		local data = walker.Data
		if walker.Mode == "Escape" then
			local elapsed = math.max(0, t - data.Start)
			local angle = data.Angle + data.Dir * data.Speed * elapsed / data.Radius
			local pos = MapGeometry.RingPosition(angle, data.Radius)
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * data.Dir
			local bob, sway = waddle(t, 14)
			walker.Model:PivotTo(CFrame.lookAt(pos, pos + tangent) * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, sway))
		elseif walker.Mode == "Capture" then
			local origin = crystalAttachment(walker.CapturePlot or 1)
			local from = walker.CaptureFrom or walker.Root.CFrame
			local alpha = math.clamp((t - walker.ModeStart) / 1.0, 0, 1)
			if origin and alpha < 1 then
				local eased = alpha * alpha
				local pos = from.Position:Lerp(origin.WorldPosition, eased)
					+ Vector3.new(0, math.sin(alpha * math.pi) * 6, 0)
				walker.Model:PivotTo(CFrame.new(pos) * from.Rotation * CFrame.Angles(0, alpha * math.pi * 6, 0))
				walker.Model:ScaleTo(math.max(0.05, 1 - eased * 0.95))
			else
				if origin then
					EffectsController.Burst(origin.WorldPosition, Color3.fromRGB(255, 255, 255))
				end
				destroyWalker(walker)
				escapes[id] = nil
			end
		elseif walker.Mode == "Sink" then
			local from = walker.CaptureFrom or walker.Root.CFrame
			local alpha = math.clamp((t - walker.ModeStart) / 2.5, 0, 1)
			local center = Vector3.new(0, 0.3 - alpha * 8, 0)
			local pos = from.Position:Lerp(center, alpha)
			walker.Model:PivotTo(CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0) + Vector3.new(0.01, 0, 0)))
			if alpha >= 1 then
				destroyWalker(walker)
				escapes[id] = nil
			end
		end
	end
end

function WaveController.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "WaveFX"
	fxFolder.Parent = Workspace
end

function WaveController.Start()
	Net.Event("WaveStart").OnClientEvent:Connect(onWaveStart)
	Net.Event("WaveResult").OnClientEvent:Connect(onWaveResult)
	Net.Event("EscapeStart").OnClientEvent:Connect(onEscapeStart)
	Net.Event("EscapeEnd").OnClientEvent:Connect(onEscapeEnd)
	RunService.RenderStepped:Connect(update)
end

return WaveController
