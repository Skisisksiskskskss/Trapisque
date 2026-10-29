--[[
	Weather: how the Washout looks and sounds. The sky darkens during the
	warning, then rain, fog and wind noise roll in for the storm.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(script.Parent.Sounds)

local Weather = {}

type Look = { lighting: { [string]: any }, atmosphere: { [string]: any } }

local LOOKS: { [string]: Look } = {
	Dry = {
		lighting = { Brightness = 2.6, ClockTime = 14.5, OutdoorAmbient = Color3.fromRGB(140, 140, 153) },
		atmosphere = { Density = 0.28, Haze = 1.2, Color = Color3.fromRGB(199, 209, 230) },
	},
	Warning = {
		lighting = { Brightness = 1.6, ClockTime = 16.8, OutdoorAmbient = Color3.fromRGB(110, 110, 130) },
		atmosphere = { Density = 0.4, Haze = 2.2, Color = Color3.fromRGB(150, 160, 185) },
	},
	Storm = {
		lighting = { Brightness = 0.9, ClockTime = 17.6, OutdoorAmbient = Color3.fromRGB(80, 90, 115) },
		atmosphere = { Density = 0.55, Haze = 3.5, Color = Color3.fromRGB(100, 115, 145) },
	},
}

local rainPart: Part
local rain: ParticleEmitter
local stormSound: Sound?

local function apply(phase: string)
	local look = LOOKS[phase] or LOOKS.Dry
	local info = TweenInfo.new(if phase == "Dry" then 6 else 4, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, look.lighting):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, look.atmosphere):Play()
	end

	rain.Enabled = phase == "Storm"
	if phase == "Storm" and not stormSound then
		local sound = Sounds.create("Storm")
		if sound then
			sound.Looped = true
			sound.Parent = SoundService
			sound:Play()
			stormSound = sound
		end
	elseif phase ~= "Storm" and stormSound then
		stormSound:Destroy()
		stormSound = nil
	end
end

function Weather.init()
	rainPart = Instance.new("Part")
	rainPart.Name = "RainEmitter"
	rainPart.Size = Vector3.new(140, 1, 140)
	rainPart.Transparency = 1
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.Parent = workspace

	rain = Instance.new("ParticleEmitter")
	rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 215, 255))
	rain.LightEmission = 0.2
	rain.Transparency = NumberSequence.new(0.35)
	rain.Size = NumberSequence.new(0.18)
	rain.Squash = NumberSequence.new(3)
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Speed = NumberRange.new(110, 130)
	rain.Lifetime = NumberRange.new(0.7, 0.9)
	rain.Rate = 900
	rain.Shape = Enum.ParticleEmitterShape.Box
	rain.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	rain.Enabled = false
	rain.Parent = rainPart

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local wind = workspace:GetAttribute("Wind")
		local slant = if typeof(wind) == "Vector3" then wind * 25 else Vector3.zero
		rainPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 40, 0) - slant)
		rain.Acceleration = slant * 2
	end)

	workspace:GetAttributeChangedSignal("Phase"):Connect(function()
		apply(workspace:GetAttribute("Phase") or "Dry")
	end)
	apply(workspace:GetAttribute("Phase") or "Dry")
end

return Weather
