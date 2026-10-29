--[[
	CombatController: turns input into actions and feeds the HUD.

	M1 is the JJS 4-hit chain: hold or tap to swing; the 4th hit is a neutral
	knockback, an uppercut when you are jumping (or holding jump) and a
	downslam when you are falling. Your client finds what each swing touched
	(so hits match what you see) and the server validates and applies them.
	Everything else (skills, dashes, block, dive, awaken) is predicted here and
	confirmed by the server.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)
local Remotes = require(Shared.Remotes)

local Animator = require(script.Parent.Animator)
local CameraController = require(script.Parent.CameraController)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Keybinds = require(script.Parent.Keybinds)
local KitClient = require(script.Parent.KitClient)
local MovementController = require(script.Parent.MovementController)
local Sounds = require(script.Parent.Sounds)

local CombatController = {}

local player = Players.LocalPlayer

local M1_HIT_SLACK = 0.6 -- extra studs on the hitbox for latency
local PULL_WINDOW = 0.6 -- a hit confirm this soon after a swing pulls you in

local m1Held = false
local m1Step = 0
local m1LastAt = 0
local m1ReadyAt = 0
local m1Token = 0
local blockHeld = false
local blocking = false
local skillReadyAt = { 0, 0, 0, 0 }
local menuToggles: { [string]: () -> () } = {}

local function kit(): Characters.Character
	return Characters.get(player:GetAttribute("Kit"))
end

local function colorId(): number
	return player:GetAttribute("ColorId") or 1
end

local function character(): Model?
	return player.Character
end

local function awakened(): boolean
	local char = character()
	return char ~= nil and char:GetAttribute("Awakened") == true
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

-- M1 chain ---------------------------------------------------------------------------

local function finisherVariant(): string
	if MovementController.isAirborne() then
		return if MovementController.verticalSpeed() < -3 then "Downslam" else "Uppercut"
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		return "Uppercut"
	end
	return "Neutral"
end

-- Characters (players and dummies) whose root is inside the swing's hitbox.
local function swingTargets(includeRagdolled: boolean): { Model }
	local char = character()
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return {}
	end
	local hits = {}
	for _, other in workspace:GetChildren() do
		if other:IsA("Model") and other ~= char then
			local otherRoot = other:FindFirstChild("HumanoidRootPart")
			local otherHumanoid = other:FindFirstChildOfClass("Humanoid")
			if
				otherRoot
				and otherRoot:IsA("BasePart")
				and otherHumanoid
				and otherHumanoid.Health > 0
				and (includeRagdolled or not other:GetAttribute("Ragdolled"))
				and Geometry.inFrontBox(
					root.CFrame,
					Config.M1_REACH,
					Config.M1_HITBOX,
					otherRoot.Position,
					M1_HIT_SLACK
				)
			then
				table.insert(hits, other)
			end
		end
	end
	return hits
end

local function swing()
	local now = os.clock()
	if now < m1ReadyAt or not canAttack() then
		return
	end
	local step = if now - m1LastAt > Config.M1_CHAIN_RESET or m1Step >= 4 then 1 else m1Step + 1
	local variant = if step == 4 then finisherVariant() else "Neutral"
	m1Step = step
	m1LastAt = now
	m1ReadyAt = now + (if step == 4 then Config.M1_CHAIN_COOLDOWN else Config.M1_INTERVAL)
	m1Token += 1
	local token = m1Token

	local weapon = kit().weapon
	MovementController.suppressDive(0.45)
	MovementController.swing(Config.M1_STARTUP + 0.12)
	Animator.play(character(), weapon .. (if step == 4 then variant else "M1_" .. step))
	Remotes.Action:FireServer("M1", step, variant)
	Sounds.play(if step == 4 then "SwingHeavy" else "Swing")
	Fx.swingTrail(character(), colorId(), step == 4)

	task.delay(Config.M1_STARTUP, function()
		-- Getting hit during the windup cancels the swing (JJS trading).
		if token ~= m1Token or not MovementController.canAct() then
			return
		end
		local targets = swingTargets(variant == "Downslam")
		if #targets > 0 then
			Remotes.Action:FireServer("M1Hit", step, targets)
		end
	end)
end

-- Skills -----------------------------------------------------------------------------

local function useSkill(slot: number)
	local now = os.clock()
	local def = kit()
	local skill = def.skills[slot]
	if not skill or now < skillReadyAt[slot] or not canAttack() then
		return
	end
	-- Skills, like swings, always surface you.
	MovementController.suppressDive(0.3)
	local behaviours = KitClient[def.name]
	local payload = behaviours and behaviours[slot]()
	if payload == nil then
		return
	end
	local scale = if awakened() then Config.AWAKEN_COOLDOWN_MULT else 1
	skillReadyAt[slot] = now + skill.cooldown * scale
	Animator.play(character(), skill.animation)
	Remotes.Action:FireServer("Skill", slot, payload)
	Sounds.play("Skill")
end

local function awaken()
	if (player:GetAttribute("Awakening") or 0) < 100 or awakened() or not MovementController.canAct() then
		return
	end
	Remotes.Action:FireServer("Awaken")
	Animator.play(character(), "Awaken")
end

-- HUD data ---------------------------------------------------------------------------

local function slots(): { Hud.Slot }
	local now = os.clock()
	local list: { Hud.Slot } = {}
	for index, skill in kit().skills do
		table.insert(list, {
			key = Keybinds.label("Skill" .. index),
			name = skill.name,
			remaining = math.max(skillReadyAt[index] - now, 0),
			total = skill.cooldown,
		})
	end
	return list
end

local function dashes(): (number, number, number, number)
	return MovementController.getDashCooldowns()
end

local function status(): string?
	if MovementController.isRagdolled() then
		return if (player:GetAttribute("Evasive") or 0) >= 100
			then "RAGDOLLED - " .. Keybinds.label("Dash") .. " TO EVADE"
			else "RAGDOLLED"
	elseif MovementController.isStunned() then
		return "STUNNED"
	elseif blocking then
		return "BLOCKING"
	elseif MovementController.getSurface() == "enemy" then
		return "ENEMY PAINT"
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
	if action == "M1" then
		m1Held = began
		if began then
			swing()
		end
	elseif action == "Dive" then
		MovementController.setDiveHeld(began)
	elseif action == "Block" then
		blockHeld = began
		if not began then
			setBlocking(false)
		end
	elseif began then
		if action == "Skill1" then
			useSkill(1)
		elseif action == "Skill2" then
			useSkill(2)
		elseif action == "Skill3" then
			useSkill(3)
		elseif action == "Skill4" then
			useSkill(4)
		elseif action == "Dash" then
			if MovementController.dash() then
				Fx.localDash(colorId())
			end
		elseif action == "Awaken" then
			awaken()
		elseif action == "Characters" and menuToggles.Characters then
			menuToggles.Characters()
		elseif action == "Settings" and menuToggles.Settings then
			menuToggles.Settings()
		end
	end
end

local function update()
	if blockHeld and not blocking and MovementController.canAct() then
		setBlocking(true)
	elseif blocking and not MovementController.canAct() then
		setBlocking(false)
	end
	if m1Held then
		swing()
	end
end

-- Server feedback ---------------------------------------------------------------------

local function onHitConfirm(damage: number, comboDamage: number, ko: boolean, blocked: boolean)
	Hud.damageCounter(damage, comboDamage, blocked)
	if blocked then
		Sounds.play("Blocked")
		m1ReadyAt = math.max(m1ReadyAt, os.clock() + Config.M1_BLOCKED_ENDLAG)
		return
	end
	Sounds.play("HitConfirm")
	if os.clock() - m1LastAt < PULL_WINDOW then
		MovementController.pull(Config.M1_PULL)
	end
	if ko then
		Sounds.play("KO")
		CameraController.punch(6)
		Fx.impactFrame()
	else
		CameraController.punch(1.2)
	end
end

local function onKnockback(velocity: Vector3, ragdoll: number, stun: number)
	MovementController.applyKnockback(velocity, ragdoll, stun)
	if stun > 0 then
		Animator.stun(character(), stun)
	end
	if ragdoll > 0 then
		CameraController.shake(0.45)
	end
	if stun > 0 or ragdoll > 0 then
		m1Token += 1 -- cancels a swing that was winding up
		setBlocking(false)
	end
end

local function onState(kind: string)
	if kind == "RagdollEnd" then
		MovementController.endRagdoll()
	elseif kind == "Evasive" then
		MovementController.evasiveStep()
		Sounds.play("Evasive")
		Hud.notify("EVADED", "evasive")
	elseif kind == "GuardBroken" then
		setBlocking(false)
		Animator.stun(character(), Config.GUARD_BREAK_STUN)
		Sounds.play("GuardBreak")
		CameraController.shake(0.5)
		Hud.notify("GUARD BROKEN", "guardbreak")
	end
end

local function onNotify(text: string, kind: string?)
	Hud.notify(text, kind)
	if kind == "warning" then
		Sounds.play("Warning")
	elseif kind == "error" then
		Sounds.play("UiClick")
	end
end

-- Lets menus register their open/close toggles ("Characters", "Settings").
function CombatController.setMenuToggle(name: string, callback: () -> ())
	menuToggles[name] = callback
end

function CombatController.init()
	Hud.setProviders(slots, dashes, status)

	UserInputService.InputBegan:Connect(function(input, processed)
		onInput(input, true, processed)
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		onInput(input, false, processed)
	end)
	RunService.Heartbeat:Connect(update)

	player.CharacterAdded:Connect(function()
		m1Step = 0
		m1ReadyAt = 0
		skillReadyAt = { 0, 0, 0, 0 }
		blocking = false
		blockHeld = false
	end)

	Remotes.HitConfirm.OnClientEvent:Connect(onHitConfirm)
	Remotes.Knockback.OnClientEvent:Connect(onKnockback)
	Remotes.State.OnClientEvent:Connect(onState)
	Remotes.Notify.OnClientEvent:Connect(onNotify)
	Remotes.Feed.OnClientEvent:Connect(Hud.feed)
end

return CombatController
