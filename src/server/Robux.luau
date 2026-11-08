-- Robux purchases. Clients open Roblox's purchase prompts themselves; everything is granted here.
--   Game passes (owned forever): the Harvest Pass premium track, VIP and the Robux skins. Checked on join,
--     and granted the moment one is bought.
--   Developer products (bought again and again): XP boosts, Feather packs and Power-Up Starters. Roblox calls
--     processReceipt until it hears the purchase was granted, so a purchase is only confirmed once it's saved,
--     and each purchase id is remembered so it's never granted twice.
-- Ids come from Config.Robux; anything left at 0 is ignored.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Season = require(ReplicatedStorage.Shared.Season)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Stats = require(script.Parent.Stats)
local Progression = require(script.Parent.Progression)
local Sfx = require(script.Parent.Sfx)

local Remotes = ReplicatedStorage.Remotes
local Decision = Enum.ProductPurchaseDecision

local Robux = {}

-- Developer product id -> what one purchase gives.
local boostMinutes: { [number]: number } = {}
local featherPacks: { [number]: number } = {}
local starterRaces: { [number]: number } = {}
-- Game pass id -> skin id.
local skinPasses: { [number]: string } = {}

local function readConfig()
	for _, map in { boostMinutes, featherPacks, starterRaces, skinPasses } do
		table.clear(map)
	end
	local robux = Config.Robux
	for _, boost in robux.XpBoosts do
		if boost.Id ~= 0 then
			boostMinutes[boost.Id] = boost.Minutes
		end
	end
	for _, pack in robux.FeatherPacks do
		if pack.Id ~= 0 then
			featherPacks[pack.Id] = pack.Feathers
		end
	end
	for _, starter in robux.Starters do
		if starter.Id ~= 0 then
			starterRaces[starter.Id] = starter.Races
		end
	end
	for skinId, passId in robux.Skins do
		if passId ~= 0 and Skins.byId[skinId] then
			skinPasses[passId] = skinId
		end
	end
end

local function notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
	Sfx.to(player, "Purchase")
end

local function grantPass(player: Player, passId: number, justBought: boolean)
	if passId == 0 then
		return
	elseif passId == Config.Robux.PremiumPass then
		Progression.setPremium(player)
		if justBought then
			notify(player, `⭐ {Season.Name} PREMIUM unlocked! Enjoy the rewards!`)
		end
	elseif passId == Config.Robux.VipPass then
		player:SetAttribute("Vip", true)
		if justBought then
			notify(player, `👑 You're a VIP! 2x Feathers from every race, starting now.`)
		end
	elseif skinPasses[passId] then
		local skinId = skinPasses[passId]
		Stats.unlockSkin(player, skinId)
		if justBought then
			Stats.equip(player, skinId)
			notify(player, `🦃 {Skins.byId[skinId].Name} unlocked!`)
		end
	end
end

local function owns(player: Player, passId: number): boolean
	local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	return ok and result == true
end

-- Grants every configured pass the player already owns.
local function checkPasses(player: Player)
	local passes = {}
	for _, passId in { Config.Robux.PremiumPass, Config.Robux.VipPass } do
		if passId ~= 0 then
			table.insert(passes, passId)
		end
	end
	for passId in skinPasses do
		table.insert(passes, passId)
	end
	for _, passId in passes do
		if player.Parent and owns(player, passId) then
			grantPass(player, passId, false)
		end
	end
end

-- Gives what a developer product is for. Returns a function that takes it back (for when the purchase
-- can't be saved) and the message to show, or nil for a product this game doesn't sell.
local function grantProduct(player: Player, productId: number): ((() -> ())?, string?)
	if boostMinutes[productId] then
		local minutes = boostMinutes[productId]
		return Progression.addBoost(player, minutes), `⚡ 2x XP for {minutes} minutes! Go race!`
	elseif featherPacks[productId] then
		local feathers = featherPacks[productId]
		Stats.add(player, feathers, 0)
		return function()
			Stats.add(player, -feathers, 0)
		end, `{Format.FEATHER} +{feathers} Feathers! Spend them in the shop.`
	elseif starterRaces[productId] then
		local races = starterRaces[productId]
		return Stats.addStarters(player, races), `🎁 Your next {races} races start with a power-up in hand!`
	end
	return nil, nil
end

local function sells(productId: number): boolean
	return boostMinutes[productId] ~= nil or featherPacks[productId] ~= nil or starterRaces[productId] ~= nil
end

function Robux.processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not sells(receipt.ProductId) then
		warn("[TurkeyRace] A purchase came in for an unknown product:", receipt.ProductId)
		return Decision.NotProcessedYet
	end
	-- Without their saved data there's nowhere safe to record it; Roblox tries again on their next visit.
	if not player or not Stats.isLoaded(player) then
		return Decision.NotProcessedYet
	end
	if not Stats.addReceipt(player, receipt.PurchaseId) then
		return Decision.PurchaseGranted -- granted before
	end
	local undo, message = grantProduct(player, receipt.ProductId)
	if not Stats.saveNow(player) then
		if undo then
			undo()
		end
		Stats.removeReceipt(player, receipt.PurchaseId)
		return Decision.NotProcessedYet
	end
	notify(player, message or "Thanks for your purchase!")
	return Decision.PurchaseGranted
end

function Robux.start()
	readConfig()
	MarketplaceService.ProcessReceipt = Robux.processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			grantPass(player, passId, true)
		end
	end)
	Stats.onLoaded(checkPasses)
end

return Robux
