--!strict
-- Local world behaviour: lets the owner walk through their own door, adds owner-only prompts (repair, upgrade
-- kiosk) and raid prompts on other bases, spins crystals, animates idle brainrots and shows crystal/door stats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Modules.Format)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local LocalPlayer = Players.LocalPlayer

local WorldController = {}

WorldController.KioskTriggered = Signal.new() :: Signal.Signal<()>

type CrystalEntry = { Core: BasePart, Base: CFrame, Phase: number }
type BrainrotEntry = { Model: Model, Root: BasePart, Base: CFrame, Phase: number, Rainbow: { BasePart }? }

local crystals: { [Instance]: CrystalEntry } = {}
local brainrots: { [Model]: BrainrotEntry } = {}
local stealPrompts: { [Model]: ProximityPrompt } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function myPlot(): number?
	local value = LocalPlayer:GetAttribute("Plot")
	return if type(value) == "number" then value else nil
end

local function isMine(folder: Instance): boolean
	return folder:GetAttribute("PlotIndex") == myPlot()
end

local function setupStatsBillboard(folder: Instance, core: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CrystalStats"
	billboard.Size = UDim2.fromOffset(200, 64)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	billboard.MaxDistance = 260
	billboard.LightInfluence = 0
	billboard.Parent = core
	local name = Instance.new("TextLabel")
	name.Name = "Owner"
	name.Size = UDim2.new(1, 0, 0.4, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0
	name.Parent = billboard
	local stats = Instance.new("TextLabel")
	stats.Name = "Stats"
	stats.Position = UDim2.fromScale(0, 0.42)
	stats.Size = UDim2.new(1, 0, 0.58, 0)
	stats.BackgroundTransparency = 1
	stats.Font = Enum.Font.FredokaOne
	stats.TextScaled = true
	stats.TextColor3 = Color3.fromRGB(150, 220, 255)
	stats.TextStrokeTransparency = 0
	stats.Parent = billboard
	local function refresh()
		local ownerName = folder:GetAttribute("OwnerName")
		name.Text = if type(ownerName) == "string" then ownerName else ""
		local crystal = (folder:GetAttribute("CrystalPower") :: number?) or 0
		local door = (folder:GetAttribute("DoorStrength") :: number?) or 0
		stats.Text = string.format("💎 %s   🚪 %s", Format.Short(crystal), Format.Short(door))
	end
	refresh()
	folder:GetAttributeChangedSignal("CrystalPower"):Connect(refresh)
	folder:GetAttributeChangedSignal("DoorStrength"):Connect(refresh)
	folder:GetAttributeChangedSignal("OwnerName"):Connect(refresh)
end

local function setupOwnerPrompts(base: Instance)
	if base:GetAttribute("LocalOwnerSetup") then
		return
	end
	base:SetAttribute("LocalOwnerSetup", true)
	local door = base:FindFirstChild("Door")
	local panel = door and door:FindFirstChild("Panel") :: BasePart?
	if panel then
		-- Owner walks straight through their own door (collision is only disabled in this client's physics).
		panel.CanCollide = false
		panel:GetPropertyChangedSignal("CanCollide"):Connect(function()
			if panel.CanCollide then
				panel.CanCollide = false
			end
		end)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RepairPrompt"
		prompt.ActionText = "Repair Door"
		prompt.ObjectText = "Your Door"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Enabled = false
		prompt.Parent = panel
		prompt.Triggered:Connect(function()
			Net.Event("Repair"):FireServer()
		end)
		task.spawn(function()
			while prompt.Parent do
				local folder = base.Parent
				local brokenUntil = folder and (folder:GetAttribute("DoorBrokenUntil") :: number?) or 0
				prompt.Enabled = brokenUntil > now()
				task.wait(0.25)
			end
		end)
	end
	local kiosk = base:FindFirstChild("Kiosk") :: BasePart?
	if kiosk then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Upgrade"
		prompt.ObjectText = "Base"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = kiosk
		prompt.Triggered:Connect(function()
			WorldController.KioskTriggered:Fire()
		end)
	end
end

local function updateStealPrompt(model: Model)
	local prompt = stealPrompts[model]
	if not prompt then
		return
	end
	local plotIndex = model:GetAttribute("PlotIndex")
	local plots = Workspace:FindFirstChild("Plots")
	local folder = plots and type(plotIndex) == "number" and plots:FindFirstChild("Plot" .. plotIndex)
	local open = folder ~= nil and folder:GetAttribute("DoorOpen") == true
	local immuneUntil = (model:GetAttribute("StealImmuneUntil") :: number?) or 0
	prompt.Enabled = open and os.time() >= immuneUntil and LocalPlayer:GetAttribute("Carrying") ~= true
end

local function trackBrainrot(model: Model)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local rainbow: { BasePart }? = nil
	if model:GetAttribute("Rainbow") then
		local list = {}
		for _, child in model:GetDescendants() do
			if child:IsA("BasePart") and child ~= root and not child:GetAttribute("KeepColor") then
				table.insert(list, child)
			end
		end
		rainbow = list
	end
	brainrots[model] = { Model = model, Root = root, Base = root.CFrame, Phase = math.random() * 10, Rainbow = rainbow }
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			brainrots[model] = nil
			stealPrompts[model] = nil
		end
	end)
	if model:GetAttribute("OwnerId") ~= LocalPlayer.UserId then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.ActionText = "STEAL"
		prompt.ObjectText = model.Name
		prompt.HoldDuration = GameConfig.StealHoldDuration
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = root
		prompt.Triggered:Connect(function()
			Net.Event("Steal"):FireServer(model:GetAttribute("PlotIndex"), model:GetAttribute("Slot"))
		end)
		stealPrompts[model] = prompt
		updateStealPrompt(model)
	end
end

local function watchBase(folder: Instance, base: Instance)
	local crystal = base:WaitForChild("Crystal", 10)
	local core = crystal and crystal:WaitForChild("Core", 10) :: BasePart?
	if core then
		crystals[base] = { Core = core, Base = core.CFrame, Phase = math.random() * 10 }
		setupStatsBillboard(folder, core)
	end
	if isMine(folder) then
		setupOwnerPrompts(base)
	end
	local function onChild(child: Instance)
		if child:IsA("Model") and child:GetAttribute("Uid") ~= nil then
			trackBrainrot(child)
		end
	end
	for _, child in base:GetChildren() do
		onChild(child)
	end
	base.ChildAdded:Connect(onChild)
	base.AncestryChanged:Connect(function()
		if not base:IsDescendantOf(Workspace) then
			crystals[base] = nil
		end
	end)
end

local function watchPlot(folder: Instance)
	folder.ChildAdded:Connect(function(child)
		if child.Name == "Base" then
			task.defer(watchBase, folder, child)
		end
	end)
	local existing = folder:FindFirstChild("Base")
	if existing then
		task.spawn(watchBase, folder, existing)
	end
	folder:GetAttributeChangedSignal("DoorOpen"):Connect(function()
		for model in stealPrompts do
			if model:GetAttribute("PlotIndex") == folder:GetAttribute("PlotIndex") then
				updateStealPrompt(model)
			end
		end
	end)
end

local function update()
	local t = os.clock()
	for _, entry in crystals do
		entry.Core.CFrame = entry.Base
			* CFrame.new(0, math.sin(t * 1.5 + entry.Phase) * 0.6, 0)
			* CFrame.Angles(0, t * 0.7 + entry.Phase, 0)
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPos = camera.CFrame.Position
	local animated = 0
	for _, entry in brainrots do
		if animated > 90 then
			break
		end
		if (entry.Base.Position - cameraPos).Magnitude < 110 then
			animated += 1
			local phase = t * 2.2 + entry.Phase
			entry.Root.CFrame = entry.Base
				* CFrame.new(0, math.abs(math.sin(phase)) * 0.3, 0)
				* CFrame.Angles(0, math.sin(phase * 0.5) * 0.12, math.sin(phase) * 0.04)
			local rainbow = entry.Rainbow
			if rainbow then
				for i, part in rainbow do
					part.Color = Color3.fromHSV((t * 0.25 + i * 0.07) % 1, 0.75, 1)
				end
			end
		end
	end
end

function WorldController.Start()
	local plots = Workspace:WaitForChild("Plots")
	for _, folder in plots:GetChildren() do
		watchPlot(folder)
	end
	plots.ChildAdded:Connect(watchPlot)
	LocalPlayer:GetAttributeChangedSignal("Plot"):Connect(function()
		local index = myPlot()
		local folder = index and plots:FindFirstChild("Plot" .. index)
		local base = folder and folder:FindFirstChild("Base")
		if base then
			setupOwnerPrompts(base)
		end
	end)
	LocalPlayer:GetAttributeChangedSignal("Carrying"):Connect(function()
		for model in stealPrompts do
			updateStealPrompt(model)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for model in stealPrompts do
				updateStealPrompt(model)
			end
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return WorldController
