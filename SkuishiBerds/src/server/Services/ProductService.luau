--[[
	ProductService: Robux developer products (ProcessReceipt).

	Each receipt is granted exactly once: its PurchaseId is stored in the
	profile before the grant is confirmed, and the profile is saved before
	returning PurchaseGranted.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared.Config.Products)

local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)

local ProductService = {}

local MAX_RECEIPTS = 100

local function grant(d, g)
	if g.coins then
		d.coins += g.coins
	end
	if g.revive then
		d.reviveTokens += g.revive
	end
	if g.birds then
		for _, id in g.birds do
			d.owned.bird[id] = true
		end
	end
	if g.items then
		for _, pair in g.items do
			local category, id = pair[1], pair[2]
			d.owned[category] = d.owned[category] or {}
			d.owned[category][id] = true
		end
	end
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.waitFor(player, 15)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if data.receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = Products.KeyById[info.ProductId]
	local g = key and Products.Grants[key]
	if not g then
		warn("[ProductService] unknown product id " .. tostring(info.ProductId) .. " (check Config/Products.luau)")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	DataService.update(player, function(d)
		d.receipts[purchaseId] = true
		table.insert(d.receiptOrder, purchaseId)
		while #d.receiptOrder > MAX_RECEIPTS do
			local old = table.remove(d.receiptOrder, 1)
			d.receipts[old] = nil
		end
		grant(d, g)
	end)

	if DataService.isPersistent(player) then
		DataService.saveNow(player)
	end

	if g.revive then
		-- if they bought it from the revive prompt, use it right away
		MatchService.reviveFromPurchase(player)
	end

	MatchService.sendTo(player, "Purchased", key, g.title or key)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ProductService.init()
	MarketplaceService.ProcessReceipt = processReceipt
end

return ProductService
