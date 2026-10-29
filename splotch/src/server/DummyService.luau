--[[
	DummyService: training dummies so combos can be practised alone. Every map
	part tagged "DummySpot" gets one; spots with a Blocking attribute get a
	dummy that always blocks. Dummies are combatants like players (State,
	ragdolls, hits) but the server simulates them, and they respawn on death.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local CombatService = require(script.Parent.CombatService)
local PlayerService = require(script.Parent.PlayerService)
local State = require(script.Parent.State)
local World = require(script.Parent.World)

local DummyService = {}

local SPOT_TAG = "DummySpot"
local RESPAWN = 3

local function dummyDescription(blocking: boolean): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local body = if blocking then Color3.fromRGB(120, 140, 170) else Color3.fromRGB(205, 190, 160)
	description.HeadColor = body
	description.TorsoColor = body
	description.LeftArmColor = body
	description.RightArmColor = body
	description.LeftLegColor = body
	description.RightLegColor = body
	return description
end

local function spawnDummy(spot: BasePart)
	local blocking = spot:GetAttribute("Blocking") == true
	local model = PlayerService.buildR6(dummyDescription(blocking))
	if not model then
		return
	end
	model.Name = if blocking then "Blocking Dummy" else "Training Dummy"
	local st = State.create(model, 0)
	PlayerService.prepareCharacter(model, 0, "Tagger")
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	if blocking then
		st.blocking = true
		model:SetAttribute("Blocking", true)
		model:SetAttribute("AlwaysBlock", true)
	end
	CollectionService:AddTag(model, World.DUMMY_TAG)

	model:PivotTo(spot.CFrame * CFrame.new(0, 3.3, 0))
	model.Parent = workspace
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root:SetNetworkOwner(nil)
	end

	humanoid.Died:Connect(function()
		CombatService.onDied(model)
		task.delay(RESPAWN, function()
			State.remove(model)
			model:Destroy()
			spawnDummy(spot)
		end)
	end)
end

-- Blocking dummies raise their guard again once a guard break wears off.
local function reblock()
	local now = os.clock()
	for _, dummy in CollectionService:GetTagged(World.DUMMY_TAG) do
		local st = State.get(dummy)
		if st and dummy:GetAttribute("AlwaysBlock") and not st.blocking then
			if now >= st.stunUntil and not CombatService.isRagdolled(st) then
				st.blocking = true
				dummy:SetAttribute("Blocking", true)
			end
		end
	end
end

function DummyService.init()
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		if spot:IsA("BasePart") then
			task.spawn(spawnDummy, spot)
		end
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.25 then
			elapsed = 0
			reblock()
		end
	end)
end

return DummyService
