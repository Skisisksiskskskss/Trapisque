--!strict
-- Local juice: camera shake, door debris, flashes, particle bursts, floating cash numbers and confetti.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EffectsController = {}

local shakeIntensity = 0
local shakeUntil = 0
local fx: Folder

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

function EffectsController.Shake(intensity: number, duration: number)
	shakeIntensity = math.max(shakeIntensity, intensity)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

function EffectsController.Debris(cf: CFrame, size: Vector3, color: Color3, material: Enum.Material)
	local pieces = 14
	for i = 1, pieces do
		local piece = Instance.new("Part")
		piece.Size = Vector3.new(size.X / 4, size.Y / 5, size.Z) * (0.6 + math.random() * 0.6)
		piece.CFrame = cf
			* CFrame.new((math.random() - 0.5) * size.X, (math.random() - 0.5) * size.Y, 0)
			* CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3)
		piece.Color = color
		piece.Material = material
		piece.CanCollide = true
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = false
		piece.Parent = fx
		local outward = (cf.LookVector * -1 + Vector3.new(
			(math.random() - 0.5) * 1.5,
			0.8 + math.random(),
			(math.random() - 0.5) * 1.5
		)).Unit
		piece.AssemblyLinearVelocity = outward * (35 + math.random() * 30)
		piece.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		task.delay(2 + i * 0.05, function()
			if piece.Parent then
				TweenService:Create(piece, TweenInfo.new(0.6), { Transparency = 1, Size = piece.Size * 0.3 }):Play()
			end
		end)
		Debris:AddItem(piece, 3.2)
	end
	EffectsController.Flash(cf.Position, Color3.fromRGB(255, 200, 120))
end

function EffectsController.Wobble(model: Model)
	local start = model:GetPivot()
	task.spawn(function()
		for i = 1, 8 do
			local offset = (if i % 2 == 0 then 1 else -1) * (9 - i) * 0.05
			model:PivotTo(start * CFrame.new(0, 0, offset) * CFrame.Angles(math.rad(offset * 6), 0, 0))
			task.wait(0.04)
		end
		model:PivotTo(start)
	end)
end

function EffectsController.Flash(position: Vector3, color: Color3)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 2
	ball.Position = position
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Transparency = 0.2
	ball.Parent = fx
	TweenService:Create(
		ball,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 14, Transparency = 1 }
	):Play()
	Debris:AddItem(ball, 0.5)
end

function EffectsController.Burst(position: Vector3, color: Color3)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = fx
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(14, 30)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(45)
	EffectsController.Flash(position, color)
	Debris:AddItem(holder, 2)
end

function EffectsController.FloatText(position: Vector3, text: string, color: Color3)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = fx
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = billboard
	TweenService:Create(
		holder,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = position + Vector3.new(0, 6, 0) }
	):Play()
	TweenService:Create(
		label,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	Debris:AddItem(holder, 1.3)
end

-- 2D confetti across the screen (tier up, rebirth, big rewards).
function EffectsController.Confetti(screen: ScreenGui)
	for _ = 1, 60 do
		local bit = Instance.new("Frame")
		bit.Size = UDim2.fromOffset(math.random(8, 16), math.random(8, 16))
		bit.Position = UDim2.new(math.random(), 0, -0.05, 0)
		bit.BackgroundColor3 = Color3.fromHSV(math.random(), 0.7, 1)
		bit.BorderSizePixel = 0
		bit.Rotation = math.random(0, 360)
		bit.ZIndex = 50
		bit.Parent = screen
		local fall = TweenService:Create(
			bit,
			TweenInfo.new(1.6 + math.random() * 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.new(bit.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
				Rotation = bit.Rotation + math.random(-360, 360),
			}
		)
		fall:Play()
		Debris:AddItem(bit, 3)
	end
end

function EffectsController.Init()
	fx = Instance.new("Folder")
	fx.Name = "LocalFX"
	fx.Parent = Workspace
end

function EffectsController.Start()
	RunService:BindToRenderStep("BrainrotShake", Enum.RenderPriority.Camera.Value + 1, function()
		local clock = os.clock()
		if clock >= shakeUntil then
			shakeIntensity = 0
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local remaining = (shakeUntil - clock)
		local strength = shakeIntensity * math.clamp(remaining * 3, 0, 1)
		camera.CFrame *= CFrame.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
	end)
end

return EffectsController
