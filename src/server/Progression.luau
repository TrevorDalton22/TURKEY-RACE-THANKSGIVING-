-- XP, levels and the Harvest Pass. RaceManager hands out XP after each race (doubled while an XP boost
-- runs); level-ups and new pass tiers are announced, and pass rewards are granted the moment their tier
-- unlocks. Robux calls in when someone buys the premium track or an XP boost.
--
-- What clients need goes out as player attributes:
--   Level, LevelXp, LevelXpNeeded   lifetime level and progress toward the next one
--   SeasonXp                        XP this season (shared/Progress turns it into a pass tier)
--   FreeClaimed, PremiumClaimed     highest tier whose free / premium reward has been granted
--   PassPremium                     owns the premium track
--   BoostUntil                      os.time() the XP boost runs out (0 when there's none)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Season = require(ReplicatedStorage.Shared.Season)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Stats = require(script.Parent.Stats)
local Sfx = require(script.Parent.Sfx)

local Remotes = ReplicatedStorage.Remotes

local Progression = {}

local premium: { [Player]: boolean } = {}

local function skinName(id: string): string
	local skin = Skins.byId[id]
	return if skin then skin.Name else id
end

local function publish(player: Player)
	local profile = Stats.profile(player)
	if not profile then
		return
	end
	local level, into, need = Progress.level(profile.Xp)
	Stats.setLevel(player, level)
	player:SetAttribute("Level", level)
	player:SetAttribute("LevelXp", into)
	player:SetAttribute("LevelXpNeeded", need)
	player:SetAttribute("SeasonXp", profile.SeasonXp)
	player:SetAttribute("FreeClaimed", profile.FreeClaimed)
	player:SetAttribute("PremiumClaimed", profile.PremiumClaimed)
	player:SetAttribute("PassPremium", premium[player] == true)
	player:SetAttribute("BoostUntil", profile.BoostUntil)
end

local function boosted(profile: Stats.Profile): boolean
	return profile.BoostUntil > os.time()
end

-- Adds `minutes` of 2x XP, on top of any boost already running. Returns a function that takes it back.
function Progression.addBoost(player: Player, minutes: number): () -> ()
	local profile = Stats.profile(player)
	if not profile then
		return function() end
	end
	local before = profile.BoostUntil
	profile.BoostUntil = math.max(before, os.time()) + minutes * 60
	publish(player)
	Stats.saveSoon(player)
	return function()
		profile.BoostUntil = before
		publish(player)
	end
end

local function grant(player: Player, reward)
	if reward.Feathers then
		Stats.add(player, reward.Feathers, 0)
	elseif reward.Skin then
		Stats.unlockSkin(player, reward.Skin)
	elseif reward.Boost then
		Progression.addBoost(player, reward.Boost)
	end
end

-- Grants every pass reward the player has reached but not received yet. Returns what was granted.
local function catchUp(player: Player): { string }
	local profile = Stats.profile(player)
	if not profile or not Stats.isReady(player) then
		-- Wait for the saved data, or rewards already granted in an earlier visit would be granted again.
		return {}
	end
	local granted = {}
	local tier = Progress.tier(profile.SeasonXp)
	for t = profile.FreeClaimed + 1, tier do
		local reward = Season.Rewards[t].Free
		if reward then
			grant(player, reward)
			table.insert(granted, Progress.describe(reward, skinName))
		end
	end
	profile.FreeClaimed = math.max(profile.FreeClaimed, tier)
	if premium[player] then
		for t = profile.PremiumClaimed + 1, tier do
			local reward = Season.Rewards[t].Premium
			if reward then
				grant(player, reward)
				table.insert(granted, Progress.describe(reward, skinName))
			end
		end
		profile.PremiumClaimed = math.max(profile.PremiumClaimed, tier)
	end
	return granted
end

-- Gives the player XP for a race and returns how much they got (after any boost).
function Progression.award(player: Player, baseXp: number): number
	local profile = Stats.profile(player)
	if not profile then
		return 0
	end
	local xp = if boosted(profile) then baseXp * Config.Progression.BoostMultiplier else baseXp
	local oldLevel = Progress.level(profile.Xp)
	local oldTier = Progress.tier(profile.SeasonXp)
	profile.Xp += xp
	profile.SeasonXp += xp
	local newLevel = Progress.level(profile.Xp)
	local newTier = Progress.tier(profile.SeasonXp)
	catchUp(player)
	publish(player)
	Stats.saveSoon(player)

	local news = {}
	if newLevel > oldLevel then
		table.insert(news, `⭐ LEVEL {newLevel}!`)
	end
	if newTier > oldTier then
		table.insert(news, `🎟️ {Season.Name} tier {newTier}!`)
	end
	if #news > 0 then
		-- After the results have had a moment on screen.
		task.delay(1.5, function()
			if player.Parent then
				Remotes.Notify:FireClient(player, table.concat(news, "   "))
				Sfx.to(player, "Purchase")
			end
		end)
	end
	return xp
end

-- Unlocks the premium track (bought, or found already owned on join) and grants the premium rewards
-- for every tier already reached.
function Progression.setPremium(player: Player)
	if premium[player] then
		return
	end
	premium[player] = true
	catchUp(player)
	publish(player)
	Stats.saveSoon(player)
end

function Progression.start()
	Stats.onLoaded(function(player)
		-- Tier 1's free reward is a welcome gift, and a new season's rewards start here too.
		local granted = catchUp(player)
		publish(player)
		if #granted > 0 then
			Stats.saveSoon(player)
			task.delay(3, function()
				if player.Parent then
					Remotes.Notify:FireClient(player, `🎁 {Season.Name} reward: {table.concat(granted, ", ")}`)
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		premium[player] = nil
	end)
end

return Progression
