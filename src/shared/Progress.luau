-- Level and pass-tier math, shared so the HUD can show progress from a player's XP attributes.

local Config = require(script.Parent.Config)
local Format = require(script.Parent.Format)
local Season = require(script.Parent.Season)

local Progress = {}

-- XP needed to go from `level` to the next one.
function Progress.xpToNext(level: number): number
	local rules = Config.Progression
	return rules.LevelBase + rules.LevelStep * (level - 1)
end

-- The level for a lifetime XP total, the XP earned into that level, and the XP that level needs.
function Progress.level(xp: number): (number, number, number)
	local level = 1
	local need = Progress.xpToNext(level)
	while xp >= need do
		xp -= need
		level += 1
		need = Progress.xpToNext(level)
	end
	return level, xp, need
end

-- The pass tier for this season's XP (starting on tier 1), and the XP earned toward the next tier.
function Progress.tier(seasonXp: number): (number, number)
	local last = #Season.Rewards
	local tier = math.min(last, seasonXp // Season.XpPerTier + 1)
	local into = if tier == last then Season.XpPerTier else seasonXp % Season.XpPerTier
	return tier, into
end

-- Short text for a pass reward, like "🍂 100" or "⚡ 2x XP 30m".
function Progress.describe(reward, skinName: ((string) -> string)?): string
	if reward.Feathers then
		return `{Format.FEATHER} {reward.Feathers}`
	elseif reward.Boost then
		return if reward.Boost >= 60 and reward.Boost % 60 == 0 then `⚡ 2x XP {reward.Boost // 60}h` else `⚡ 2x XP {reward.Boost}m`
	elseif reward.Skin then
		return `🦃 {if skinName then skinName(reward.Skin) else reward.Skin}`
	end
	return "?"
end

return Progress
