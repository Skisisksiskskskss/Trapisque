--[[
	CameraController: an over-the-shoulder camera with the mouse locked to the
	centre (permanent "shift lock"), so the crosshair is always where shots go.

	Hold ALT (or open a menu) to free the cursor. The camera pulls in when a wall
	is behind you, and supports screen shake and FOV punches for hit feedback.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)

local CameraController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local PITCH_MIN = math.rad(-80)
local PITCH_MAX = math.rad(70)
local COLLISION_RADIUS = 0.6
local AIM_DISTANCE = 600

local yaw = 0
local pitch = math.rad(-10)
local zoom = Config.CAMERA_DEFAULT_ZOOM
local currentZoom = zoom
local trauma = 0
local fovPunch = 0
local fovBoost = 0
local cursorFreeReasons: { [string]: boolean } = {}

local collisionParams = RaycastParams.new()
collisionParams.FilterType = Enum.RaycastFilterType.Include

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function cursorFree(): boolean
	return next(cursorFreeReasons) ~= nil
end

-- Free the mouse for a reason ("menu", "alt"); lock it again once no reason is left.
function CameraController.setCursorFree(reason: string, free: boolean)
	cursorFreeReasons[reason] = if free then true else nil
end

-- Screen shake, 0..1. Stacks and decays.
function CameraController.shake(amount: number)
	trauma = math.min(trauma + amount, 1)
end

-- Briefly narrows the view for impact.
function CameraController.punch(degrees: number)
	fovPunch = math.max(fovPunch, degrees)
end

-- Extra FOV while moving fast (set every frame by movement).
function CameraController.setSpeedBoost(degrees: number)
	fovBoost = degrees
end

function CameraController.getYaw(): number
	return yaw
end

-- Horizontal look direction of the camera.
function CameraController.flatLook(): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

-- World point under the crosshair (ignores your own character).
function CameraController.getAimPoint(): Vector3
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * AIM_DISTANCE
	aimParams.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("PaintVisuals") }
	local result = workspace:Raycast(origin, direction, aimParams)
	return if result then result.Position else origin + direction
end

local function update(dt: number)
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	if cursorFree() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		local delta = UserInputService:GetMouseDelta()
		yaw -= delta.X * Config.CAMERA_SENSITIVITY
		pitch = math.clamp(pitch - delta.Y * Config.CAMERA_SENSITIVITY, PITCH_MIN, PITCH_MAX)
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	currentZoom += (zoom - currentZoom) * math.min(dt * 12, 1)
	local rotation = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	local focus = root.Position + Vector3.new(0, Config.CAMERA_HEIGHT, 0)
	local offset = rotation:VectorToWorldSpace(Vector3.new(Config.CAMERA_SHOULDER, 0.3, currentZoom))

	local map = workspace:FindFirstChild("Map")
	if map then
		collisionParams.FilterDescendantsInstances = { map }
		local hit = workspace:Spherecast(focus, COLLISION_RADIUS, offset, collisionParams)
		if hit then
			offset = offset.Unit * math.max(hit.Distance - 0.1, 0.5)
		end
	end

	trauma = math.max(trauma - dt * 1.6, 0)
	local shakePower = trauma * trauma
	local t = os.clock() * 28
	local shake = Vector3.new(math.noise(t, 0.1), math.noise(t, 7.3), math.noise(t, 13.7)) * shakePower * 1.2
	local roll = math.noise(t, 21.1) * shakePower * 0.06

	camera.CFrame = CFrame.new(focus + offset + shake) * rotation * CFrame.Angles(0, 0, roll)
	camera.Focus = CFrame.new(focus)

	fovPunch = math.max(fovPunch - dt * 40, 0)
	local targetFov = Config.CAMERA_FOV + fovBoost - fovPunch
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(dt * 10, 1)
end

function CameraController.init()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.CAMERA_FOV

	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom - input.Position.Z * 2, Config.CAMERA_MIN_ZOOM, Config.CAMERA_MAX_ZOOM)
		end
	end)

	-- Face the way the character spawns.
	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root and root:IsA("BasePart") then
			local look = root.CFrame.LookVector
			yaw = math.atan2(-look.X, -look.Z)
		end
	end)

	RunService:BindToRenderStep("SplotchCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
