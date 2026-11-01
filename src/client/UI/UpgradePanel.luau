--!strict
-- Upgrade panel: Crystal (catch power), Door (raid defence), Base Tier (new theme + pedestals) and Rebirth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Themes = require(Shared.Config.Themes)
local Format = require(Shared.Modules.Format)
local Net = require(Shared.Modules.Net)
local Kit = require(script.Parent.Kit)
local Panels = require(script.Parent.Panels)

local UpgradePanel = {}

type Card = {
	Frame: Frame,
	Level: TextLabel,
	Stat: TextLabel,
	Button: TextButton,
}

local function makeCard(
	parent: Instance,
	order: number,
	icon: string,
	title: string,
	color: Color3,
	onClick: () -> ()
): Card
	local frame = Kit.panelFrame({
		Name = title,
		LayoutOrder = order,
		Size = UDim2.new(1 / 3, -8, 1, 0),
		BackgroundColor3 = Kit.darken(color, 0.55),
		Parent = parent,
	})
	Kit.label({
		Text = icon,
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.fromOffset(0, 8),
		MaxTextSize = 48,
		Parent = frame,
	})
	Kit.label({
		Text = title,
		Size = UDim2.new(1, -12, 0, 30),
		Position = UDim2.fromOffset(6, 62),
		TextColor3 = color,
		MaxTextSize = 28,
		Parent = frame,
	})
	local level = Kit.label({
		Text = "Lv 1",
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.fromOffset(6, 94),
		MaxTextSize = 22,
		Parent = frame,
	})
	local stat = Kit.label({
		Text = "",
		Size = UDim2.new(1, -12, 0, 48),
		Position = UDim2.fromOffset(6, 122),
		TextColor3 = Kit.Colors.Muted,
		MaxTextSize = 20,
		TextWrapped = true,
		Parent = frame,
	})
	local button = Kit.button({
		Text = "$0",
		Color = color,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 54),
		TextSize = 26,
		Parent = frame,
		OnClick = onClick,
	})
	return { Frame = frame, Level = level, Stat = stat, Button = button }
end

function UpgradePanel.Register(toast: (string, string?) -> ())
	Panels.Register("Upgrade", "⬆️ Upgrade Your Base", Vector2.new(760, 470), function(content)
		local row = Kit.new("Frame", {
			Size = UDim2.new(1, 0, 1, -76),
			BackgroundTransparency = 1,
			Parent = content,
		})
		Kit.list(Enum.FillDirection.Horizontal, 12).Parent = row

		local function request(kind: string)
			local ok, message = Net.Function("Upgrade"):InvokeServer(kind)
			toast(message, if ok then "good" else "warn")
		end

		local crystal = makeCard(row, 1, "💎", "Crystal", Kit.Colors.Blue, function()
			request("Crystal")
		end)
		local door = makeCard(row, 2, "🚪", "Door", Kit.Colors.Orange, function()
			request("Door")
		end)
		local tier = makeCard(row, 3, "🏰", "Base Tier", Kit.Colors.Purple, function()
			request("Tier")
		end)

		local rebirthBar = Kit.panelFrame({
			Name = "Rebirth",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundColor3 = Color3.fromRGB(70, 30, 80),
			Parent = content,
		})
		local rebirthText = Kit.label({
			Text = "",
			Size = UDim2.new(0.66, -12, 1, -12),
			Position = UDim2.fromOffset(10, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			TextWrapped = true,
			Parent = rebirthBar,
		})
		local rebirthButton = Kit.button({
			Text = "♻️ REBIRTH",
			Color = Kit.Colors.Pink,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0.33, -8, 1, -14),
			TextSize = 26,
			Parent = rebirthBar,
			OnClick = function()
				local ok, message = Net.Function("Rebirth"):InvokeServer()
				toast(message, if ok then "good" else "warn")
			end,
		})

		local function refresh(state: { [string]: any })
			local tierNow: number = state.Tier
			local maxLevel = Economy.MaxLevelForTier(tierNow)
			local passes = state.Passes or {}
			local mult = 1 + (state.Rebirths or 0) * Economy.RebirthPowerBonus

			local crystalMult = mult * (if passes.SuperCrystal then 1.25 else 1)
			crystal.Level.Text = string.format("Lv %d / %d", state.CrystalLevel, maxLevel)
			if state.CrystalLevel >= maxLevel then
				crystal.Stat.Text = string.format("💎 %s\nMAXED for this tier", Format.Short(state.CrystalPower))
				crystal.Button.Text = "MAX"
				Kit.setButtonColor(crystal.Button, Kit.Colors.Grey)
			else
				local nextPower = Economy.CrystalPower(state.CrystalLevel + 1, crystalMult)
				local cost = Economy.CrystalCost(state.CrystalLevel)
				crystal.Stat.Text = string.format(
					"💎 %s → %s\nBeam stronger brainrots",
					Format.Short(state.CrystalPower),
					Format.Short(nextPower)
				)
				crystal.Button.Text = Format.Cash(cost)
				Kit.setButtonColor(crystal.Button, if state.Cash >= cost then Kit.Colors.Green else Kit.Colors.Grey)
			end

			local doorMult = mult * (if passes.Fortress then 1.5 else 1)
			door.Level.Text = string.format("Lv %d / %d", state.DoorLevel, maxLevel)
			if state.DoorLevel >= maxLevel then
				door.Stat.Text = string.format("🚪 %s\nMAXED for this tier", Format.Short(state.DoorStrength))
				door.Button.Text = "MAX"
				Kit.setButtonColor(door.Button, Kit.Colors.Grey)
			else
				local nextStrength = Economy.DoorStrength(state.DoorLevel + 1, doorMult)
				local cost = Economy.DoorCost(state.DoorLevel)
				door.Stat.Text = string.format(
					"🚪 %s → %s\nStops raids",
					Format.Short(state.DoorStrength),
					Format.Short(nextStrength)
				)
				door.Button.Text = Format.Cash(cost)
				Kit.setButtonColor(door.Button, if state.Cash >= cost then Kit.Colors.Green else Kit.Colors.Grey)
			end

			local theme = Themes.Get(tierNow)
			tier.Level.Text = string.format("Tier %d · %s", tierNow, theme.Name)
			if tierNow >= Economy.MaxTier then
				tier.Stat.Text = "MAX TIER!\nRebirth for more power"
				tier.Button.Text = "MAX"
				Kit.setButtonColor(tier.Button, Kit.Colors.Grey)
			else
				local nextTheme = Themes.Get(tierNow + 1)
				local cost = Economy.TierCost(tierNow)
				local ready = Economy.CanTierUp(tierNow, state.CrystalLevel)
				tier.Stat.Text = if ready
					then string.format(
						"→ %s\n%d pedestals + rarer brainrots",
						nextTheme.Name,
						Economy.Slots(tierNow + 1)
					)
					else string.format("Max your crystal\n(Lv %d) to unlock", maxLevel)
				tier.Button.Text = if ready then Format.Cash(cost) else "🔒"
				Kit.setButtonColor(
					tier.Button,
					if ready and state.Cash >= cost then Kit.Colors.Green else Kit.Colors.Grey
				)
			end

			local canRebirth = Economy.CanRebirth(tierNow, state.CrystalLevel, state.Cash, state.Rebirths or 0)
			rebirthText.Text = string.format(
				"♻️ Rebirth %d → +%d%% cash, +%d%% power, keep your brainrots! Needs Tier %d, max crystal, %s",
				(state.Rebirths or 0) + 1,
				math.floor(Economy.RebirthCashBonus * 100),
				math.floor(Economy.RebirthPowerBonus * 100),
				Economy.MaxTier,
				Format.Cash(Economy.RebirthCost(state.Rebirths or 0))
			)
			Kit.setButtonColor(rebirthButton, if canRebirth then Kit.Colors.Pink else Kit.Colors.Grey)
		end

		return { Refresh = refresh }
	end)
end

return UpgradePanel
