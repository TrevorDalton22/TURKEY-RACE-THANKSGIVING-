-- The battle pass. Everyone starts on tier 1, and every XpPerTier XP earned this season unlocks the
-- next tier. Each tier has a reward for everyone (Free, optional) and one for players who own the
-- premium track (Premium, Config.Robux.PremiumPass). Rewards are granted as soon as a tier unlocks;
-- buying premium later grants every premium reward already reached.
--
-- A reward is one of:
--   { Feathers = 100 }
--   { Skin = "Harvest" }   a skin marked Pass in shared/Skins
--   { Boost = 30 }         minutes of 2x XP
--
-- Changing Id starts a new season: everyone's pass progress starts over (levels and skins are kept).

local Season = {
	Id = "Harvest2026",
	Name = "Harvest Pass",
	XpPerTier = 120,
	Rewards = {
		{ Free = { Feathers = 50 }, Premium = { Skin = "Cranberry" } },
		{ Premium = { Feathers = 100 } },
		{ Free = { Feathers = 50 }, Premium = { Boost = 30 } },
		{ Premium = { Feathers = 100 } },
		{ Free = { Feathers = 100 }, Premium = { Feathers = 150 } },
		{ Premium = { Boost = 30 } },
		{ Free = { Feathers = 75 }, Premium = { Feathers = 150 } },
		{ Free = { Skin = "Harvest" }, Premium = { Feathers = 200 } },
		{ Premium = { Feathers = 150 } },
		{ Free = { Feathers = 100 }, Premium = { Boost = 30 } },
		{ Premium = { Feathers = 200 } },
		{ Free = { Feathers = 100 }, Premium = { Skin = "Pie" } },
		{ Premium = { Feathers = 200 } },
		{ Free = { Boost = 30 }, Premium = { Feathers = 200 } },
		{ Free = { Feathers = 150 }, Premium = { Feathers = 250 } },
		{ Premium = { Boost = 60 } },
		{ Free = { Feathers = 100 }, Premium = { Feathers = 250 } },
		{ Premium = { Feathers = 250 } },
		{ Free = { Feathers = 150 }, Premium = { Feathers = 300 } },
		{ Free = { Skin = "Pumpkin" }, Premium = { Feathers = 300 } },
		{ Premium = { Boost = 60 } },
		{ Free = { Feathers = 150 }, Premium = { Feathers = 300 } },
		{ Premium = { Feathers = 300 } },
		{ Free = { Feathers = 200 }, Premium = { Feathers = 350 } },
		{ Free = { Boost = 30 }, Premium = { Feathers = 400 } },
		{ Premium = { Feathers = 400 } },
		{ Free = { Feathers = 200 }, Premium = { Feathers = 450 } },
		{ Premium = { Feathers = 500 } },
		{ Free = { Feathers = 250 }, Premium = { Feathers = 500 } },
		{ Free = { Feathers = 300 }, Premium = { Skin = "Feast" } },
	},
}

return Season
