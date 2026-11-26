--[[
	Hud: the in-match screen. Arena in the middle, bars above/below.

	Couch on a phone: Player 1 holds the top of the device (the original's
	upside-down top bird), so P1's ability button and info live in the top bar,
	rotated 180 degrees. Player 2 (or the only player) uses the bottom bar.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Birds = require(Shared.Config.Birds)
local Products = require(Shared.Config.Products)
local Abilities = require(Shared.Sim.Abilities)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local MatchClient = require(Client.Game.MatchClient)
local Canvas = require(Client.Render.Canvas)

return {
	create = function(App)
		local frame = Widgets.frame(nil, { name = "Hud" })
		local topBar = Widgets.frame(frame, { size = UDim2.new(1, 0, 0, 58), name = "Top", z = 10 })
		local arenaHolder = Widgets.frame(frame, {
			size = UDim2.new(1, -8, 1, -164),
			position = UDim2.new(0.5, 0, 0, 62),
			anchor = Vector2.new(0.5, 0),
			name = "ArenaHolder",
		})
		local bottomBar = Widgets.frame(
			frame,
			{ size = UDim2.new(1, 0, 0, 98), position = UDim2.new(0, 0, 1, -98), name = "Bottom", z = 10 }
		)

		local status = Widgets.label(topBar, {
			text = "",
			size = UDim2.new(0.6, 0, 0, 34),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			maxText = 24,
			strokeColor = Theme.White,
			strokeThickness = 2,
			z = 11,
		})
		Widgets.button(topBar, {
			text = "X",
			color = Theme.White,
			size = UDim2.fromOffset(46, 46),
			position = UDim2.new(1, -6, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			z = 12,
			onClick = function()
				Widgets.confirm(App.gui, "Leave match?", "Your bird will drop out of this round.", "Leave", function()
					if App.match then
						App.match:leave()
					end
				end)
			end,
		})

		local abilityButtons = {}
		local reviveModal: Frame? = nil
		local conn
		local endConn

		local function makeAbilityButton(parent: Instance, playerIndex: number, rotated: boolean, bird)
			local def = Birds.get(bird.kind)
			-- player 1's (flipped) bar stops short of the leave button in the top-right corner
			local holder = Widgets.frame(parent, {
				size = if rotated then UDim2.new(1, -60, 1, 0) else UDim2.new(1, 0, 1, 0),
				z = 11,
			})
			holder.Rotation = if rotated then 180 else 0
			local btn = Instance.new("TextButton")
			btn.Text = ""
			btn.AutoButtonColor = false
			btn.Size = UDim2.fromOffset(84, 84)
			btn.Position = UDim2.new(1, -12, 0.5, 0)
			btn.AnchorPoint = Vector2.new(1, 0.5)
			btn.BackgroundTransparency = 1
			btn.ZIndex = 12
			btn.Parent = holder
			local cg = Instance.new("CanvasGroup")
			cg.Size = UDim2.fromScale(1, 1)
			cg.BackgroundColor3 = Theme.White
			cg.ZIndex = 12
			Widgets.corner(cg, 42)
			cg.Parent = btn
			local fill = Instance.new("Frame")
			fill.BorderSizePixel = 0
			fill.AnchorPoint = Vector2.new(0, 1)
			fill.Position = UDim2.fromScale(0, 1)
			fill.Size = UDim2.fromScale(1, 0)
			fill.BackgroundColor3 = Theme.Yellow
			fill.ZIndex = 13
			fill.Parent = cg
			local ring = Instance.new("Frame")
			ring.BackgroundTransparency = 1
			ring.Size = UDim2.fromScale(1, 1)
			ring.ZIndex = 15
			Widgets.corner(ring, 42)
			local ringStroke = Widgets.stroke(ring, 4)
			ring.Parent = btn
			Widgets.label(btn, {
				text = def.abilityName,
				size = UDim2.new(0.86, 0, 0.32, 0),
				position = UDim2.fromScale(0.5, 0.42),
				anchor = Vector2.new(0.5, 0.5),
				z = 16,
				maxText = 18,
			})
			local count = Widgets.label(btn, {
				text = "",
				size = UDim2.new(0.6, 0, 0.24, 0),
				position = UDim2.fromScale(0.5, 0.72),
				anchor = Vector2.new(0.5, 0.5),
				font = Theme.FontBody,
				color = Theme.InkSoft,
				z = 16,
				maxText = 14,
			})
			-- the match backdrop is dimmed dark, so bar text is light
			local info = Widgets.label(holder, {
				text = "",
				size = UDim2.new(1, -120, 0, 26),
				position = UDim2.new(0, 12, 0.5, -16),
				anchor = Vector2.new(0, 0.5),
				alignX = Enum.TextXAlignment.Left,
				color = Theme.White,
				strokeColor = Theme.Ink,
				strokeThickness = 2,
				maxText = 22,
				z = 11,
			})
			local sub = Widgets.label(holder, {
				text = "",
				size = UDim2.new(1, -120, 0, 20),
				position = UDim2.new(0, 12, 0.5, 14),
				anchor = Vector2.new(0, 0.5),
				alignX = Enum.TextXAlignment.Left,
				font = Theme.FontBody,
				color = Theme.HudSoft,
				maxText = 15,
				z = 11,
			})
			btn.Activated:Connect(function()
				if App.match then
					App.match:queueInput(playerIndex, "ability")
				end
			end)
			return {
				holder = holder,
				fill = fill,
				ring = ringStroke,
				count = count,
				info = info,
				sub = sub,
				slot = bird.slot,
				color = Canvas.color((App.match and App.match.loadouts[bird.slot] or {}).color or def.defaultColor),
			}
		end

		local function closeRevive()
			if reviveModal then
				reviveModal:Destroy()
				reviveModal = nil
			end
		end

		local function showRevive(match)
			if reviveModal then
				return
			end
			local p = App.profile
			local tokens = if p then p.reviveTokens or 0 else 0
			local shade = Widgets.frame(App.gui, { color = Color3.new(0, 0, 0), alpha = 0.45, z = 250 })
			reviveModal = shade
			local card = Widgets.frame(shade, {
				color = Theme.Paper,
				size = UDim2.new(0.86, 0, 0, 280),
				position = UDim2.fromScale(0.5, 0.5),
				anchor = Vector2.new(0.5, 0.5),
				round = 18,
				stroke = 4,
				z = 251,
			})
			local max = Instance.new("UISizeConstraint")
			max.MaxSize = Vector2.new(420, 300)
			max.Parent = card
			Widgets.label(card, {
				text = "Keep flapping?",
				size = UDim2.new(0.9, 0, 0, 44),
				position = UDim2.new(0.05, 0, 0, 12),
				z = 252,
				maxText = 34,
			})
			local timer = Widgets.label(card, {
				text = "",
				size = UDim2.new(0.9, 0, 0, 26),
				position = UDim2.new(0.05, 0, 0, 58),
				font = Theme.FontBody,
				color = Theme.InkSoft,
				z = 252,
				maxText = 18,
			})
			local y = 96
			if tokens > 0 then
				Widgets.button(card, {
					text = string.format("Use a revive token (%d)", tokens),
					color = Theme.Mint,
					size = UDim2.new(0.9, 0, 0, 52),
					position = UDim2.new(0.05, 0, 0, y),
					z = 253,
					maxText = 20,
					onClick = function()
						match:requestRevive()
					end,
				})
				y += 60
			end
			if Products.isEnabled("Revive") then
				Widgets.button(card, {
					text = "Revive with Robux",
					color = Theme.Yellow,
					size = UDim2.new(0.9, 0, 0, 52),
					position = UDim2.new(0.05, 0, 0, y),
					z = 253,
					maxText = 20,
					onClick = function()
						App.promptProduct("Revive")
					end,
				})
				y += 60
			end
			Widgets.button(card, {
				text = "No thanks",
				color = Theme.White,
				size = UDim2.new(0.9, 0, 0, 46),
				position = UDim2.new(0.05, 0, 0, y),
				z = 253,
				maxText = 18,
				onClick = closeRevive,
			})
			card.Size = UDim2.new(0.86, 0, 0, y + 60)
			shade.Name = "ReviveModal"
			timer.Name = "Timer"
		end

		local function update()
			local match = App.match
			if not match then
				return
			end
			local world = match.world
			-- status line
			local text = match.mode.name
			if match.practice then
				text = "EVENT LAB"
			elseif match.mode.versus then
				local alive = 0
				for _, b in world.birdList do
					if not b.dead then
						alive += 1
					end
				end
				text = alive .. " birds left" .. (if match.suddenDeath then " · SUDDEN DEATH" else "")
			end
			status.Text = text
			-- ability buttons
			for _, ab in abilityButtons do
				local bird = world.birds[ab.slot]
				if bird then
					local cost = Abilities.cost(bird)
					local frac = math.clamp(bird.charge / cost, 0, 1)
					ab.fill.Size = UDim2.fromScale(1, frac)
					ab.fill.BackgroundColor3 = if frac >= 1 then ab.color else Theme.Yellow
					ab.ring.Color = if frac >= 1 and not bird.dead then Theme.Good else Theme.Ink
					ab.count.Text = if bird.dead
						then "out"
						else string.format("%d/%d", math.min(bird.charge, cost), cost)
					ab.info.Text = string.format(
						"%s  ·  %d %s",
						bird.name,
						bird.lives,
						if bird.lives == 1 then "life" else "lives"
					)
					ab.sub.Text = if match.mode.versus then bird.strums .. " strums" else "score " .. world.score
				end
			end
			-- revive offer
			if match.revive then
				showRevive(match)
				if reviveModal then
					local timer = reviveModal:FindFirstChild("Timer", true) :: TextLabel?
					if timer then
						local left = math.max(0, math.ceil((match.revive.deadline - workspace:GetServerTimeNow())))
						timer.Text = "Revive with 2 lives each  ·  " .. left .. "s"
					end
				end
			else
				closeRevive()
			end
		end

		return {
			frame = frame,
			onShow = function(info)
				local settings = App.profile and App.profile.settings or {}
				local match = MatchClient.new(info, arenaHolder, { settings = settings })
				match.view.noShake = settings.shake == false
				App.match = match
				for _, ab in abilityButtons do
					ab.holder:Destroy()
				end
				table.clear(abilityButtons)
				local slots = info.yourSlots or {}
				if #slots >= 2 then
					local b1 = match.world.birds[slots[1]]
					local b2 = match.world.birds[slots[2]]
					table.insert(abilityButtons, makeAbilityButton(topBar, 1, true, b1))
					table.insert(abilityButtons, makeAbilityButton(bottomBar, 2, false, b2))
					status.Visible = false
				else
					local b = slots[1] and match.world.birds[slots[1]]
					if b then
						table.insert(abilityButtons, makeAbilityButton(bottomBar, 1, false, b))
					end
					status.Visible = true
				end
				endConn = match.Ended:Connect(function(summary)
					closeRevive()
					task.delay(if summary then 1.2 else 0, function()
						if App.match == match then
							App.endMatch(summary)
						end
					end)
				end)
				conn = RunService.RenderStepped:Connect(update)
			end,
			onHide = function()
				if conn then
					conn:Disconnect()
				end
				if endConn then
					endConn:Disconnect()
				end
				closeRevive()
				if App.match then
					App.match:destroy()
					App.match = nil
				end
			end,
		}
	end,
}
