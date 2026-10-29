--[[
	CharacterVisuals: how every character looks on this client.

	* Diving players turn invisible and become a paint blob (camouflaged in
	  their own paint). Your own form is applied instantly; others come from the
	  server's "Form" attribute.
	* Blocking players get a force-field bubble.
	* Other players get an overhead name and health bar (hidden while diving).
	* flash() gives the white hit flash on the paint outline.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Palette = require(Shared.Palette)

local MovementController = require(script.Parent.MovementController)

local CharacterVisuals = {}

local localPlayer = Players.LocalPlayer

type Entry = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	blob: Part,
	blobMesh: SpecialMesh,
	bubble: Part,
	nameplate: BillboardGui?,
	healthFill: Frame?,
	hidden: boolean,
	saved: { [Instance]: number },
}

local entries: { [Model]: Entry } = {}
local fxFolder: Folder
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local FLASH_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function colorOf(entry: Entry): Color3
	return Palette.color(entry.character:GetAttribute("ColorId") or entry.player:GetAttribute("ColorId"))
end

local function formOf(entry: Entry): string
	if entry.player == localPlayer then
		return MovementController.getForm()
	end
	return entry.character:GetAttribute("Form") or "Normal"
end

local function setHidden(entry: Entry, hidden: boolean)
	if entry.hidden == hidden then
		return
	end
	entry.hidden = hidden
	if hidden then
		for _, item in entry.character:GetDescendants() do
			if item:IsA("BasePart") or item:IsA("Decal") then
				entry.saved[item] = item.Transparency
				item.Transparency = 1
			end
		end
	else
		for item, transparency in entry.saved do
			if item.Parent then
				(item :: any).Transparency = transparency
			end
		end
		entry.saved = {}
	end
	local outline = entry.character:FindFirstChild("PaintOutline")
	if outline and outline:IsA("Highlight") then
		outline.Enabled = not hidden
	end
	if entry.nameplate then
		entry.nameplate.Enabled = not hidden
	end
end

local function makeNameplate(entry: Entry)
	local head = entry.character:FindFirstChild("Head")
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Adornee = if head and head:IsA("BasePart") then head else entry.root
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 18)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 15
	name.Text = entry.player.DisplayName
	name.TextColor3 = colorOf(entry)
	name.TextStrokeTransparency = 0.4
	name.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0.15, 0, 0, 22)
	back.Size = UDim2.new(0.7, 0, 0, 7)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 235, 120)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	gui.Parent = fxFolder
	entry.nameplate = gui
	entry.healthFill = fill
end

local function track(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or not humanoid:IsA("Humanoid") or not root:IsA("BasePart") then
		return
	end

	local blob = Instance.new("Part")
	blob.Name = "SwimBlob"
	blob.Size = Vector3.one
	blob.Anchored = true
	blob.CanCollide = false
	blob.CanQuery = false
	blob.CanTouch = false
	blob.CastShadow = false
	blob.Material = Enum.Material.SmoothPlastic
	blob.Reflectance = 0.15
	blob.Transparency = 1
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = blob
	blob.Parent = fxFolder

	local bubble = Instance.new("Part")
	bubble.Name = "BlockBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.one * 7.5
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.CastShadow = false
	bubble.Material = Enum.Material.ForceField
	bubble.Transparency = 1
	bubble.Parent = fxFolder

	local entry: Entry = {
		player = player,
		character = character,
		humanoid = humanoid,
		root = root,
		blob = blob,
		blobMesh = mesh,
		bubble = bubble,
		nameplate = nil,
		healthFill = nil,
		hidden = false,
		saved = {},
	}
	entries[character] = entry
	if player ~= localPlayer then
		makeNameplate(entry)
	end

	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then
			entries[character] = nil
			blob:Destroy()
			bubble:Destroy()
			if entry.nameplate then
				entry.nameplate:Destroy()
			end
		end
	end)
end

local function updateEntry(entry: Entry)
	local form = formOf(entry)
	local alive = entry.humanoid.Health > 0
	local diving = alive and form ~= "Normal"
	setHidden(entry, diving)

	local color = colorOf(entry)
	local root = entry.root
	if diving then
		entry.blob.Color = color
		entry.blob.Transparency = if entry.player == localPlayer then 0.1 else 0.3
		local speed = root.AssemblyLinearVelocity.Magnitude
		local stretch = math.min(speed / 12, 2.5)
		if form == "WallSwim" then
			entry.blobMesh.Scale = Vector3.new(3.6, 0.8, 4 + stretch)
			entry.blob.CFrame = root.CFrame * CFrame.new(0, 0, -0.8) * CFrame.Angles(math.rad(90), 0, 0)
		else
			entry.blobMesh.Scale = Vector3.new(3.6, 0.8, 4 + stretch)
			local ground = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), groundParams)
			local position = if ground then ground.Position + Vector3.new(0, 0.3, 0) else root.Position
			entry.blob.CFrame = CFrame.new(position) * root.CFrame.Rotation
		end
	else
		entry.blob.Transparency = 1
	end

	local blocking = alive and entry.character:GetAttribute("Blocking") == true
	if blocking then
		entry.bubble.Color = color
		entry.bubble.Transparency = 0
		entry.bubble.CFrame = CFrame.new(root.Position)
	else
		entry.bubble.Transparency = 1
	end

	if entry.healthFill then
		local fraction = math.clamp(entry.humanoid.Health / math.max(entry.humanoid.MaxHealth, 1), 0, 1)
		entry.healthFill.Size = UDim2.fromScale(fraction, 1)
		entry.healthFill.BackgroundColor3 = Color3.fromRGB(235, 70, 70):Lerp(Color3.fromRGB(110, 235, 120), fraction)
	end
end

-- White flash on a character that just got hit.
function CharacterVisuals.flash(character: Model?, heavy: boolean?)
	if not character then
		return
	end
	local outline = character:FindFirstChild("PaintOutline")
	if not outline or not outline:IsA("Highlight") then
		return
	end
	outline.FillColor = if heavy then Color3.fromRGB(255, 240, 200) else Color3.fromRGB(255, 255, 255)
	outline.FillTransparency = if heavy then 0 else 0.25
	TweenService:Create(outline, FLASH_TWEEN, { FillTransparency = 1 }):Play()
end

function CharacterVisuals.init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "CharacterFx"
	fxFolder.Parent = workspace
	groundParams.FilterDescendantsInstances = { workspace:WaitForChild("Map") }

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			track(player, character)
		end)
		if player.Character then
			task.spawn(track, player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	RunService.RenderStepped:Connect(function()
		for _, entry in entries do
			updateEntry(entry)
		end
	end)
end

return CharacterVisuals
