--[[
	CombatController: turns input into actions and feeds the HUD.

	Inputs are predicted locally (cooldowns, movement, your own shots) and sent
	to the server, which validates them. Server feedback (hit confirms,
	knockback, notifications, the kill feed) is routed to the HUD, camera and
	movement from here.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)
local Remotes = require(Shared.Remotes)

local CameraController = require(script.Parent.CameraController)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Keybinds = require(script.Parent.Keybinds)
local KitClient = require(script.Parent.KitClient)
local MovementController = require(script.Parent.MovementController)
local Sounds = require(script.Parent.Sounds)

local CombatController = {}

local player = Players.LocalPlayer

-- Firing keeps you surfaced this long after the last shot.
local FIRE_SURFACE_TIME = 0.25

local primaryHeld = false
local blockHeld = false
local blocking = false
local nextPrimaryAt = 0
local skillReadyAt = { 0, 0, 0 }
local shotId = 0
local localPaint = Config.TANK_MAX
local onMenuToggle: (() -> ())? = nil

local function kit(): Characters.Character
	return Characters.get(player:GetAttribute("Kit"))
end

local function colorId(): number
	return player:GetAttribute("ColorId") or 1
end

local function setBlocking(value: boolean)
	if blocking == value then
		return
	end
	blocking = value
	MovementController.setBlocking(value)
	Remotes.Action:FireServer("Block", value)
end

local function canAttack(): boolean
	return MovementController.canAct() and not blocking and MovementController.getState() ~= "Dash"
end

local function firePrimary()
	local def = kit().primary
	local now = os.clock()
	if now < nextPrimaryAt or not canAttack() then
		return
	end
	if localPaint < def.cost then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	nextPrimaryAt = now + def.cooldown
	localPaint -= def.cost
	MovementController.suppressDive(FIRE_SURFACE_TIME)

	local look = CameraController.flatLook()
	local origin = root.Position + Vector3.new(0, 1.5, 0) + look * 1.5
	local direction = Geometry.ballisticDirection(origin, CameraController.getAimPoint(), def.speed, def.gravity)
	shotId += 1
	Fx.predictShot(shotId, origin, direction * def.speed, def.gravity, def.lifetime, def.size, colorId())
	Remotes.Action:FireServer("Primary", origin, direction, shotId)
	Sounds.play("Shoot")
end

local function useSkill(slot: number)
	local now = os.clock()
	local def = kit()
	local skill = def.skills[slot]
	if not skill or now < skillReadyAt[slot] or not canAttack() then
		return
	end
	-- Skills, like shots, always surface you.
	MovementController.suppressDive(FIRE_SURFACE_TIME)
	local behaviours = KitClient[def.name]
	local payload = behaviours and behaviours[slot]()
	if payload == nil then
		return
	end
	skillReadyAt[slot] = now + skill.cooldown
	Remotes.Action:FireServer("Skill", slot, payload)
	Sounds.play("Skill")
end

local function dash()
	if MovementController.dash() then
		Fx.localDash(colorId())
	end
end

-- HUD data ---------------------------------------------------------------------------

local function slots(): { Hud.Slot }
	local now = os.clock()
	local def = kit()
	local list: { Hud.Slot } = {
		{
			key = Keybinds.label("Primary"),
			name = def.primary.name,
			remaining = math.max(nextPrimaryAt - now, 0),
			total = def.primary.cooldown,
			active = primaryHeld,
		},
	}
	for index, skill in def.skills do
		table.insert(list, {
			key = skill.key,
			name = skill.name,
			remaining = math.max(skillReadyAt[index] - now, 0),
			total = skill.cooldown,
			active = false,
		})
	end
	local dashLeft, dashTotal = MovementController.getDashCooldown()
	table.insert(
		list,
		{ key = Keybinds.label("Dash"), name = "Dash", remaining = dashLeft, total = dashTotal, active = false }
	)
	table.insert(list, { key = Keybinds.label("Block"), name = "Block", remaining = 0, total = 0, active = blocking })
	table.insert(list, {
		key = Keybinds.label("Dive"),
		name = "Dive",
		remaining = 0,
		total = 0,
		active = MovementController.getForm() ~= "Normal",
	})
	return list
end

local function status(): string?
	if MovementController.isStunned() then
		return "STUNNED"
	elseif blocking then
		return "BLOCKING"
	elseif MovementController.getSurface() == "enemy" then
		return "ENEMY PAINT"
	elseif localPaint < kit().primary.cost then
		return "OUT OF PAINT - DIVE TO REFILL"
	end
	return nil
end

-- Input ---------------------------------------------------------------------------

local function onInput(input: InputObject, began: boolean, processed: boolean)
	local action = Keybinds.match(input)
	if not action then
		return
	end
	-- Releases always go through so nothing gets stuck held down.
	if began and processed then
		return
	end
	if action == "Primary" then
		primaryHeld = began
	elseif action == "Dive" then
		MovementController.setDiveHeld(began)
	elseif action == "Block" then
		blockHeld = began
		if not began then
			setBlocking(false)
		end
	elseif action == "FreeCursor" then
		CameraController.setCursorFree("alt", began)
	elseif began then
		if action == "Skill1" then
			useSkill(1)
		elseif action == "Skill2" then
			useSkill(2)
		elseif action == "Skill3" then
			useSkill(3)
		elseif action == "Dash" then
			dash()
		elseif action == "Leap" then
			MovementController.leap()
		elseif action == "Menu" and onMenuToggle then
			onMenuToggle()
		elseif action == "Help" then
			Hud.toggleHelp()
		end
	end
end

local function update()
	if blockHeld and not blocking and MovementController.canAct() then
		setBlocking(true)
	elseif blocking and not MovementController.canAct() then
		setBlocking(false)
	end
	if primaryHeld then
		firePrimary()
	end
end

-- Server feedback ---------------------------------------------------------------------

local function onHitConfirm(_damage: number, combo: number, ko: boolean)
	Hud.hitmarker(ko)
	Hud.combo(combo)
	Sounds.play("HitConfirm")
	if ko then
		Sounds.play("KO")
		CameraController.punch(6)
	else
		CameraController.punch(1.5)
	end
end

local function onKnockback(velocity: Vector3, ragdoll: number, stun: number)
	MovementController.applyKnockback(velocity, ragdoll, stun)
	if ragdoll > 0 then
		CameraController.shake(0.45)
	end
	if stun > 0 or ragdoll > 0 then
		setBlocking(false)
	end
end

local function onNotify(text: string, kind: string?)
	Hud.notify(text, kind)
	if kind == "guardbreak" then
		Sounds.play("GuardBreak")
		CameraController.shake(0.5)
		setBlocking(false)
	elseif kind == "warning" then
		Sounds.play("Warning")
	elseif kind == "error" then
		Sounds.play("UiClick")
	end
end

function CombatController.setMenuToggle(callback: () -> ())
	onMenuToggle = callback
end

function CombatController.init()
	Hud.setProviders(slots, status)

	UserInputService.InputBegan:Connect(function(input, processed)
		onInput(input, true, processed)
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		onInput(input, false, processed)
	end)
	RunService.Heartbeat:Connect(update)

	-- Trust the server's paint value whenever it changes.
	player:GetAttributeChangedSignal("Paint"):Connect(function()
		localPaint = player:GetAttribute("Paint") or localPaint
	end)
	player.CharacterAdded:Connect(function()
		nextPrimaryAt = 0
		skillReadyAt = { 0, 0, 0 }
		localPaint = Config.TANK_MAX
		blocking = false
		blockHeld = false
	end)

	Remotes.HitConfirm.OnClientEvent:Connect(onHitConfirm)
	Remotes.Knockback.OnClientEvent:Connect(onKnockback)
	Remotes.Notify.OnClientEvent:Connect(onNotify)
	Remotes.Feed.OnClientEvent:Connect(Hud.feed)
end

return CombatController
