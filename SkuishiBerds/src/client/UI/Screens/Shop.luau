--[[
	Shop: Robux products (only the ones with an ID set in Config/Products show
	up). Coins are spent directly on items in Birds & Looks.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Images = require(Shared.Config.Images)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)

local ORDER = {
	"StarterPack",
	"Coins_Small",
	"Coins_Medium",
	"Coins_Large",
	"Coins_Huge",
	"Revive",
	"Death_firework",
	"Hat_goldcrown",
	"Color_rainbow",
	"Pattern_galaxy",
	"Hat_dragon",
	"Death_rubberduck",
	"Color_holo",
	"Bird_zippy",
	"Bird_blinky",
	"Bird_puffin",
	"Bird_pecky",
	"Bird_hoot",
	"Bird_flippy",
	"Bird_honk",
}

local priceCache: { [number]: number } = {}

local function priceOf(id: number): number?
	if priceCache[id] then
		return priceCache[id]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
	end)
	if ok and info and info.PriceInRobux then
		priceCache[id] = info.PriceInRobux
		return info.PriceInRobux
	end
	return nil
end

return {
	create = function(App)
		local frame = Widgets.frame(nil, { name = "Shop" })
		Widgets.pad(frame, 10)
		Widgets.header(frame, "Shop", function()
			App.go("Home")
		end)
		local balance = Widgets.label(frame, {
			text = "",
			size = UDim2.new(1, 0, 0, 28),
			position = UDim2.new(0, 0, 0, 66),
			font = Theme.FontBody,
			maxText = 20,
		})
		if Images.ShopBanner ~= "" then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.new(1, 0, 0, 90)
			img.Position = UDim2.new(0, 0, 0, 96)
			img.ScaleType = Enum.ScaleType.Fit
			img.Image = Images.ShopBanner
			img.Parent = frame
		end
		local top = if Images.ShopBanner ~= "" then 192 else 100
		local scroll = Widgets.scroll(frame, { size = UDim2.new(1, 0, 1, -top), position = UDim2.new(0, 0, 0, top) })
		Widgets.pad(scroll, 6)

		local function render()
			for _, c in scroll:GetChildren() do
				c:Destroy()
			end
			Widgets.pad(scroll, 6)
			Widgets.list(scroll, 10)
			local p = App.profile
			local shown = 0
			for i, key in ORDER do
				local id = Products.Ids[key]
				local grant = Products.Grants[key]
				if id and id ~= 0 and grant then
					-- hide things you already own
					local owned = false
					if grant.birds and p then
						owned = p.owned.bird[grant.birds[1]] == true
					elseif grant.items and #grant.items == 1 and p then
						local cat, itemId = grant.items[1][1], grant.items[1][2]
						owned = p.owned[cat] and p.owned[cat][itemId] == true
					end
					if not owned then
						shown += 1
						local card = Widgets.frame(scroll, {
							color = if key == "StarterPack" then Theme.Yellow else Theme.White,
							size = UDim2.new(1, -8, 0, 84),
							round = 16,
							stroke = 3,
							order = i,
						})
						Widgets.label(card, {
							text = grant.title or key,
							size = UDim2.new(0.6, 0, 0, 30),
							position = UDim2.new(0, 14, 0, 10),
							alignX = Enum.TextXAlignment.Left,
							maxText = 24,
						})
						Widgets.label(card, {
							text = grant.desc
								or (if key:sub(1, 5) == "Bird_" then "Unlock this bird" else "Exclusive cosmetic"),
							size = UDim2.new(0.6, 0, 0, 22),
							position = UDim2.new(0, 14, 0, 44),
							font = Theme.FontBody,
							color = Theme.InkSoft,
							alignX = Enum.TextXAlignment.Left,
							maxText = 15,
						})
						local btn = Widgets.button(card, {
							text = "R$ ...",
							color = Theme.Mint,
							size = UDim2.new(0.3, 0, 0, 56),
							position = UDim2.new(1, -12, 0.5, 0),
							anchor = Vector2.new(1, 0.5),
							maxText = 24,
							onClick = function()
								App.promptProduct(key)
							end,
						})
						task.spawn(function()
							local price = priceOf(id)
							if price and btn.Parent then
								Widgets.setText(btn, "R$ " .. price)
							end
						end)
					end
				end
			end
			if shown == 0 then
				-- players see a friendly note; the setup hint only shows in Studio
				local text = "The Robux shop opens soon!\nEarn coins by playing and spend them in Birds & Looks."
				if RunService:IsStudio() then
					text ..= "\n\n(Studio: add product IDs in Shared/Config/Products.luau)"
				end
				Widgets.label(scroll, {
					text = text,
					size = UDim2.new(1, -10, 0, 110),
					font = Theme.FontBody,
					color = Theme.InkSoft,
					maxText = 18,
				})
			end
		end

		App.ProfileChanged:Connect(function(p)
			if p then
				balance.Text = string.format("%d coins  ·  %d revive token(s)", p.coins, p.reviveTokens or 0)
			end
			if App.current == "Shop" then
				render()
			end
		end)

		return {
			frame = frame,
			onShow = function()
				local p = App.profile
				if p then
					balance.Text = string.format("%d coins  ·  %d revive token(s)", p.coins, p.reviveTokens or 0)
				end
				render()
			end,
		}
	end,
}
