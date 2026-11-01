--!strict
-- Client side of raids: knockback flop when bonked, bat swing, bonk stars, and a glowing guide beam home while
-- carrying a stolen brainrot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local EffectsController = require(script.Parent.EffectsController)
local SoundController = require(script.Parent.SoundController)

local LocalPlayer = Players.LocalPlayer

local RaidController = {}

local guideBeam: Beam? = nil
local guideTarget: Attachment? = nil

local function rootPart(): BasePart?
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onKnockback(velocity: Vector3)
	local character = LocalPlayer.Character
	local root = rootPart()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-4, 4), math.random(-8, 8))
	EffectsController.Shake(0.7, 0.35)
	task.delay(0.8, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function hookTool(tool: Tool)
	if tool.Name ~= "Bonk Bat" or tool:GetAttribute("LocalHooked") then
		return
	end
	tool:SetAttribute("LocalHooked", true)
	local rest = tool.Grip
	tool.Activated:Connect(function()
		local swing = rest * CFrame.Angles(math.rad(-80), 0, 0)
		tool.Grip = swing
		task.delay(0.12, function()
			if tool.Parent then
				tool.Grip = rest
			end
		end)
		SoundController.Play("Bonk")
	end)
end

local function updateGuide()
	local carrying = LocalPlayer:GetAttribute("Carrying") == true
	if guideBeam then
		guideBeam:Destroy()
		guideBeam = nil
	end
	if guideTarget then
		guideTarget:Destroy()
		guideTarget = nil
	end
	if not carrying then
		return
	end
	local root = rootPart()
	local plotIndex = LocalPlayer:GetAttribute("Plot")
	local plots = Workspace:FindFirstChild("Plots")
	local folder = plots and type(plotIndex) == "number" and plots:FindFirstChild("Plot" .. plotIndex)
	local base = folder and folder:FindFirstChild("Base")
	local spawn = base and base:FindFirstChild("SpawnPoint") :: BasePart?
	if not root or not spawn then
		return
	end
	local from = Instance.new("Attachment")
	from.Name = "GuideFrom"
	from.Parent = root
	local to = Instance.new("Attachment")
	to.Name = "GuideTo"
	to.Position = Vector3.new(0, 3, 0)
	to.Parent = spawn
	local beam = Instance.new("Beam")
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(120, 255, 140))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
	beam.TextureSpeed = 2
	beam.Parent = root
	guideBeam = beam
	guideTarget = to
	from.Destroying:Connect(function()
		if guideTarget == to then
			to:Destroy()
		end
	end)
end

function RaidController.Start()
	Net.Event("Knockback").OnClientEvent:Connect(onKnockback)
	Net.Event("Effect").OnClientEvent:Connect(function(kind: string, payload: { [string]: any })
		if kind == "Bonk" and typeof(payload.Position) == "Vector3" then
			EffectsController.Burst(payload.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 230, 80))
			EffectsController.FloatText(payload.Position + Vector3.new(0, 4, 0), "BONK!", Color3.fromRGB(255, 230, 80))
			SoundController.Play("Bonk", payload.Position)
		elseif kind == "Return" and typeof(payload.From) == "Vector3" then
			EffectsController.Flash(payload.From, Color3.fromRGB(120, 200, 255))
		elseif kind == "Alarm" then
			SoundController.Play("Alarm")
			EffectsController.Shake(0.5, 0.4)
		elseif kind == "Stolen" then
			SoundController.Play("Steal")
		end
	end)
	local function onCharacter(character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				hookTool(child)
			end
		end)
	end
	LocalPlayer.CharacterAdded:Connect(onCharacter)
	if LocalPlayer.Character then
		onCharacter(LocalPlayer.Character)
	end
	LocalPlayer:GetAttributeChangedSignal("Carrying"):Connect(updateGuide)
end

return RaidController
