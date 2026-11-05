-- Robux prices and purchase prompts for the shop and pass windows. The server grants what's bought.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Purchases = {}

Purchases.GREEN = Color3.fromRGB(0, 170, 105) -- Robux buttons

export type Kind = "GamePass" | "Product"
-- A price in Robux, or false when the item can't be bought (not set up yet, or not for sale).
export type Price = number | false

local prices: { [string]: Price } = {}
local waiting: { [string]: { (Price) -> () } } = {}

-- Calls back with the item's price. Prices are looked up once and remembered.
function Purchases.price(kind: Kind, id: number, callback: (Price) -> ())
	if id == 0 then
		callback(false)
		return
	end
	local key = `{kind}{id}`
	if prices[key] ~= nil then
		callback(prices[key])
		return
	end
	if waiting[key] then
		table.insert(waiting[key], callback)
		return
	end
	waiting[key] = { callback }
	task.spawn(function()
		local infoType = if kind == "GamePass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		local price: Price = if ok and info and info.IsForSale ~= false and info.PriceInRobux then info.PriceInRobux else false
		prices[key] = price
		local callbacks = waiting[key]
		waiting[key] = nil
		for _, cb in callbacks do
			cb(price)
		end
	end)
end

function Purchases.buy(kind: Kind, id: number)
	if id == 0 then
		return
	end
	if kind == "GamePass" then
		MarketplaceService:PromptGamePassPurchase(player, id)
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

-- Button text for a Robux item: its price, "..." while that loads (nil), or why it can't be bought.
function Purchases.label(price: Price?, id: number): string
	if id == 0 then
		return "Coming soon"
	elseif price == nil then
		return "..."
	elseif price == false then
		return "Not for sale"
	end
	return `R$ {price}`
end

return Purchases
