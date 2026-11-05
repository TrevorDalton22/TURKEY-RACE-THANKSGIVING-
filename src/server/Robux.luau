-- Robux purchases. Clients open Roblox's purchase prompts themselves; everything is granted here.
--   Game passes (owned forever): the Harvest Pass premium track and the Robux skins. Checked on join,
--     and granted the moment one is bought.
--   Developer products (bought again and again): XP boosts. Roblox calls processReceipt until it hears
--     the purchase was granted, so a purchase is only confirmed once it's saved, and each purchase id
--     is remembered so it's never granted twice.
-- Ids come from Config.Robux; anything left at 0 is ignored.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Season = require(ReplicatedStorage.Shared.Season)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Stats = require(script.Parent.Stats)
local Progression = require(script.Parent.Progression)
local Sfx = require(script.Parent.Sfx)

local Remotes = ReplicatedStorage.Remotes
local Decision = Enum.ProductPurchaseDecision

local Robux = {}

-- Developer product id -> minutes of 2x XP.
local boostMinutes: { [number]: number } = {}
-- Game pass id -> skin id.
local skinPasses: { [number]: string } = {}

local function readConfig()
	table.clear(boostMinutes)
	table.clear(skinPasses)
	for _, boost in Config.Robux.XpBoosts do
		if boost.Id ~= 0 then
			boostMinutes[boost.Id] = boost.Minutes
		end
	end
	for skinId, passId in Config.Robux.Skins do
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
	if passId == Config.Robux.PremiumPass and passId ~= 0 then
		Progression.setPremium(player)
		if justBought then
			notify(player, `⭐ {Season.Name} PREMIUM unlocked! Enjoy the rewards!`)
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
	if Config.Robux.PremiumPass ~= 0 then
		table.insert(passes, Config.Robux.PremiumPass)
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

function Robux.processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local minutes = boostMinutes[receipt.ProductId]
	if not minutes then
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
	local undo = Progression.addBoost(player, minutes)
	if not Stats.saveNow(player) then
		undo()
		Stats.removeReceipt(player, receipt.PurchaseId)
		return Decision.NotProcessedYet
	end
	notify(player, `⚡ 2x XP for {minutes} minutes! Go race!`)
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
