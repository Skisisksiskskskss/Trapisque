--[[
	CameraController: the camera is Roblox's own, with shift lock on Left Shift
	exactly like JJS. This module only adds what the game needs on top:
	aiming (where the mouse points), screen shake through the humanoid's
	CameraOffset (respects the Screen Shake setting), and short FOV punches.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Settings = require(script.Parent.Settings)

local CameraController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local BASE_FOV = 70
local AIM_DISTANCE = 600

local trauma = 0
local fovPunch = 0
local fovBoost = 0

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

function CameraController.shake(amount: number)
	if Settings.get("screenShake") then
		trauma = math.min(trauma + amount, 1)
	end
end

function CameraController.punch(degrees: number)
	fovPunch = math.max(fovPunch, degrees)
end

-- Extra FOV while moving fast (set every frame by movement).
function CameraController.setSpeedBoost(degrees: number)
	fovBoost = degrees
end

-- Horizontal direction the camera faces.
function CameraController.flatLook(): Vector3
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
end

-- Horizontal right vector of the camera.
function CameraController.flatRight(): Vector3
	local right = camera.CFrame.RightVector
	local flat = Vector3.new(right.X, 0, right.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0)
end

-- World point under the mouse (the screen centre in shift lock).
function CameraController.getAimPoint(): Vector3
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	aimParams.FilterDescendantsInstances = {
		player.Character,
		workspace:FindFirstChild("PaintVisuals"),
		workspace:FindFirstChild("Fx"),
		workspace:FindFirstChild("CharacterFx"),
	}
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, aimParams)
	return if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE
end

local function update(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	trauma = math.max(trauma - dt * 1.8, 0)
	if humanoid then
		local power = trauma * trauma
		local t = os.clock() * 30
		humanoid.CameraOffset = Vector3.new(math.noise(t, 0.3), math.noise(t, 5.1), math.noise(t, 9.7)) * power * 1.4
	end
	fovPunch = math.max(fovPunch - dt * 40, 0)
	local target = BASE_FOV + fovBoost - fovPunch
	camera.FieldOfView += (target - camera.FieldOfView) * math.min(dt * 10, 1)
end

function CameraController.init()
	camera.FieldOfView = BASE_FOV
	RunService:BindToRenderStep("SplotchCameraFx", Enum.RenderPriority.Camera.Value - 1, update)
end

return CameraController
