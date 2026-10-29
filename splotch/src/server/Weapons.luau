--[[
	Weapons: builds each character's paint weapon out of parts and welds it to
	the R6 right arm. It sticks out of the hand like a held Roblox tool, so arm
	swings sweep it through big readable arcs. The paint end uses the player's
	color.
]]

local Weapons = {}

local WOOD = Color3.fromRGB(150, 104, 66)
local METAL = Color3.fromRGB(190, 194, 202)
local DARK_METAL = Color3.fromRGB(70, 74, 84)

type PieceSpec = {
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame, -- relative to the right arm
	color: Color3?,
	material: Enum.Material?,
	paint: boolean?,
}

-- Cylinders run along X; these turn one to run along the arm's Z (forward) or X.
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)

local DESIGNS: { [string]: { PieceSpec } } = {
	Brush = {
		{
			name = "Handle",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(2.1, 0.3, 0.3),
			offset = CFrame.new(0, -1, -0.55) * ALONG_Z,
			color = WOOD,
			material = Enum.Material.Wood,
		},
		{
			name = "Ferrule",
			shape = Enum.PartType.Block,
			size = Vector3.new(0.66, 0.38, 0.45),
			offset = CFrame.new(0, -1, -1.78),
			color = METAL,
			material = Enum.Material.Metal,
		},
		{
			name = "Bristles",
			shape = Enum.PartType.Block,
			size = Vector3.new(0.74, 0.44, 0.95),
			offset = CFrame.new(0, -1, -2.45),
			paint = true,
		},
		{
			name = "Drip",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.34, 0.34, 0.34),
			offset = CFrame.new(0.15, -1.2, -2.85),
			paint = true,
		},
	},
	Roller = {
		{
			name = "Handle",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.7, 0.34, 0.34),
			offset = CFrame.new(0, -1, -0.45) * ALONG_Z,
			color = Color3.fromRGB(40, 42, 50),
			material = Enum.Material.SmoothPlastic,
		},
		{
			name = "Rod",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.5, 0.16, 0.16),
			offset = CFrame.new(0, -1, -1.95) * ALONG_Z,
			color = METAL,
			material = Enum.Material.Metal,
		},
		{
			name = "Roller",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(2.8, 1.05, 1.05),
			offset = CFrame.new(0, -1.15, -2.95),
			paint = true,
		},
		{
			name = "CapLeft",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.12, 1.12, 1.12),
			offset = CFrame.new(-1.45, -1.15, -2.95),
			color = DARK_METAL,
			material = Enum.Material.Metal,
		},
		{
			name = "CapRight",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.12, 1.12, 1.12),
			offset = CFrame.new(1.45, -1.15, -2.95),
			color = DARK_METAL,
			material = Enum.Material.Metal,
		},
	},
}

function Weapons.attach(character: Model, weapon: string, paintColor: Color3)
	local arm = character:FindFirstChild("Right Arm")
	local design = DESIGNS[weapon]
	if not arm or not arm:IsA("BasePart") or not design then
		return
	end
	local old = character:FindFirstChild("Weapon")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Weapon"
	for _, spec in design do
		local part = Instance.new("Part")
		part.Name = spec.name
		part.Shape = spec.shape
		part.Size = spec.size
		part.Color = if spec.paint then paintColor else spec.color or METAL
		part.Material = if spec.paint then Enum.Material.SmoothPlastic else spec.material or Enum.Material.SmoothPlastic
		part.Reflectance = if spec.paint then 0.12 else 0
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = true
		part.CFrame = arm.CFrame * spec.offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = arm
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	model.Parent = character
end

return Weapons
