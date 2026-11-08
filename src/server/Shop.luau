-- Answers shop requests from clients: buying skins with Feathers and equipping owned ones.
-- Every check happens here, so a client can't buy what it can't afford.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Featured = require(ReplicatedStorage.Shared.Featured)
local Format = require(ReplicatedStorage.Shared.Format)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Stats = require(script.Parent.Stats)

local Shop = {}

local function handle(player: Player, action: unknown, skinId: unknown): (boolean, string)
	if typeof(skinId) ~= "string" or not Skins.byId[skinId] then
		return false, "That skin doesn't exist"
	end
	local skin = Skins.byId[skinId]

	if action == "Equip" then
		if not Stats.owns(player, skinId) then
			return false, "You don't own that skin yet"
		end
		Stats.equip(player, skinId)
		return true, `Now wearing {skin.Name}!`
	elseif action == "Buy" then
		if Stats.owns(player, skinId) then
			return false, "You already own that skin"
		end
		local source = Skins.source(skin)
		if source == "Robux" then
			return false, "That skin is bought with Robux"
		elseif source == "Pass" then
			return false, "That skin is a Harvest Pass reward"
		end
		-- The skin of the day is cheaper.
		local price = Featured.price(skin, os.time())
		local missing = price - Stats.feathers(player)
		if missing > 0 then
			return false, `You need {missing} more {Format.FEATHER}`
		end
		Stats.buySkin(player, skinId, price)
		Stats.equip(player, skinId)
		return true, `Bought {skin.Name}! 🦃`
	end
	return false, "Unknown request"
end

function Shop.start()
	ReplicatedStorage.Remotes.Shop.OnServerInvoke = handle
end

return Shop
