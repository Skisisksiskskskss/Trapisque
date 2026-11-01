--!strict
-- Builds the ScreenGui, scales it for the device, registers panels and wires server events to the HUD.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Net = require(Shared.Modules.Net)
local UI = script.Parent.Parent.UI
local BrainrotsPanel = require(UI.BrainrotsPanel)
local Hud = require(UI.Hud)
local IndexPanel = require(UI.IndexPanel)
local Kit = require(UI.Kit)
local Panels = require(UI.Panels)
local SettingsPanel = require(UI.SettingsPanel)
local UpgradePanel = require(UI.UpgradePanel)
local EffectsController = require(script.Parent.EffectsController)
local SoundController = require(script.Parent.SoundController)
local StateController = require(script.Parent.StateController)
local WaveController = require(script.Parent.WaveController)
local WorldController = require(script.Parent.WorldController)

local LocalPlayer = Players.LocalPlayer

local UIController = {}

-- Other controllers can intercept menu clicks for panels they own (shop, daily, ...).
local menuHandlers: { [string]: () -> () } = {}

function UIController.OnMenu(name: string, handler: () -> ())
	menuHandlers[name] = handler
end

function UIController.Toast(text: string, kind: string?)
	Hud.Toast(text, kind)
	if kind == "bad" or kind == "warn" then
		SoundController.Play("Error")
	end
end

local function computeScale(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local size = camera.ViewportSize
	return math.clamp(math.min(size.X / 1100, size.Y / 620), 0.55, 1.25)
end

local function applyScale()
	local scale = computeScale()
	Hud.SetScale(scale)
	Panels.SetScale(scale)
end

local function tryCharge()
	if Hud.TryCharge() then
		Net.Event("Charge"):FireServer()
		SoundController.Play("Charge")
	end
end

function UIController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local screen = Kit.new("ScreenGui", {
		Name = "BrainrotUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	Hud.Create(screen)
	Panels.Init(screen)
	UpgradePanel.Register(UIController.Toast)
	BrainrotsPanel.Register(UIController.Toast)
	IndexPanel.Register(UIController.Toast)
	SettingsPanel.Register()

	applyScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end

	Hud.MenuClicked:Connect(function(name)
		SoundController.Play("Click")
		local handler = menuHandlers[name]
		if handler then
			handler()
		else
			Panels.Toggle(name)
		end
	end)
	WorldController.KioskTriggered:Connect(function()
		Panels.Open("Upgrade")
	end)

	Hud.BoostPressed:Connect(function(name)
		local state = StateController.Get()
		local count = state and state.Boosts and state.Boosts[name] or 0
		local handler = menuHandlers["Boost:" .. name]
		if count <= 0 and handler then
			handler()
			return
		end
		local ok, message = Net.Function("UseBoost"):InvokeServer(name)
		UIController.Toast(message, if ok then "good" else "warn")
		if ok then
			SoundController.Play("Upgrade")
		end
	end)
	Hud.RepairOfferPressed:Connect(function()
		local handler = menuHandlers["InstantRepair"]
		if handler then
			handler()
		end
	end)
	Hud.ChargePressed:Connect(tryCharge)
	ContextActionService:BindAction("BrainrotCharge", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			tryCharge()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonX)

	StateController.Changed:Connect(function(state)
		Hud.SetState(state)
		Panels.Refresh(state)
		Hud.SetBadge("Index", IndexPanel.HasClaimable(state))
		local settings = state.Settings or {}
		SoundController.SetMusic(settings.Music ~= false)
		SoundController.SetSfx(settings.Sfx ~= false)
	end)

	Net.Event("Notify").OnClientEvent:Connect(function(text: string, kind: string?)
		UIController.Toast(text, kind)
	end)
	Net.Event("Announce").OnClientEvent:Connect(function(text: string, color: Color3?)
		Hud.Announce(text, color)
		SoundController.Play("Announce")
	end)
	Net.Event("Effect").OnClientEvent:Connect(function(kind: string, payload: { [string]: any })
		if kind == "Collect" then
			local character = LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				EffectsController.FloatText(
					root.Position + Vector3.new(0, 3, 0),
					"+" .. Format.Cash(payload.Amount),
					Kit.Colors.Cash
				)
			end
			SoundController.Play("Collect")
		elseif kind == "TierUp" then
			EffectsController.Confetti(screen)
			Hud.Announce(string.format("🏰 TIER %d: %s!", payload.Tier, payload.Name), Kit.Colors.Yellow)
			SoundController.Play("TierUp")
		elseif kind == "Reward" then
			EffectsController.Confetti(screen)
			Hud.Announce("🎁 " .. tostring(payload.Text), Kit.Colors.Yellow)
			SoundController.Play("Reward")
		elseif kind == "Rebirth" then
			EffectsController.Confetti(screen)
			Hud.Announce(string.format("♻️ REBIRTH %d!", payload.Rebirths), Kit.Colors.Pink)
			SoundController.Play("TierUp")
		end
	end)

	WaveController.LocalIncoming:Connect(function(data)
		Hud.AddIncoming(data)
		if data.Boss then
			Hud.Announce("👑 BOSS BRAINROT INCOMING! CHARGE!", Kit.Colors.Orange)
		end
	end)
	WaveController.LocalResult:Connect(function(result)
		Hud.ResolveIncoming(result)
		if result.Outcome == "Captured" then
			Hud.Announce("✨ BEAMED! ✨", Kit.Colors.Green)
			SoundController.Play("Reward")
		elseif result.Outcome == "DoorBroken" then
			Hud.Announce("💥 DOOR SMASHED! REPAIR IT!", Kit.Colors.Red)
			SoundController.Play("Alarm")
		elseif result.Outcome == "Shielded" then
			Hud.Announce("🛡️ SHIELD SAVED YOU!", Color3.fromRGB(80, 220, 255))
		else
			Hud.Announce("🚪 DOOR HELD!", Kit.Colors.Orange)
		end
	end)

	RunService.Heartbeat:Connect(function()
		Hud.Update(StateController.Info())
	end)
end

return UIController
