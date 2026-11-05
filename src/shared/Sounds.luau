-- Every sound in the game, by name. Change an Id here to swap that sound everywhere.
-- Number ids are Creator Store audio; the (PSE) ones are Pro Sound Effects and the music is APM,
-- both licensed by Roblox for any experience. Text ids are files that ship with Roblox itself.
--   Volume: 0..1   Speed: playback speed (also raises pitch)   Range: how far away it can be heard

export type Def = { Id: number | string, Volume: number?, Speed: number?, Range: number?, Looped: boolean? }

local Sounds: { [string]: Def } = {
	-- Turkeys
	Gobble = { Id = 188831155, Volume = 0.9, Range = 120 },
	Cheer = { Id = 117750774203463, Volume = 0.5 },
	Cooked = { Id = 106226416967678, Volume = 0.6 },

	-- Race start: a beep on 3, 2 and 1, then the same beep higher for GO (PSE)
	Beep = { Id = 9125530803, Volume = 0.5 },
	Go = { Id = 9125530803, Volume = 0.7, Speed = 1.5 },

	-- The chef: roar when he appears (PSE), bonk when the pan lands
	ChefRoar = { Id = 9113980319, Volume = 0.7 },
	Bonk = { Id = 3765689841, Volume = 1, Range = 250 },

	-- Power-ups
	Pickup = { Id = 9125540237, Volume = 0.6 }, -- PSE
	Dash = { Id = 9114158497, Volume = 0.6, Speed = 1.4 }, -- PSE
	Throw = { Id = 9114158497, Volume = 0.6 }, -- PSE
	Splat = { Id = 12222152, Volume = 1 }, -- Roblox
	Slip = { Id = 136774133309136, Volume = 0.9 },
	Boom = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.7 }, -- Gobble Bomb
	ShieldUp = { Id = 12222152, Volume = 0.8, Speed = 0.6 }, -- the splat, slowed into a squish
	ShieldPop = { Id = 12222152, Volume = 1, Speed = 1.4 },
	Tornado = { Id = 9114158497, Volume = 0.8, Speed = 0.55, Range = 150 }, -- PSE whoosh, slowed into wind
	Spin = { Id = 136774133309136, Volume = 0.9, Speed = 0.8 },

	-- Rushing air while riding fast; SpeedFx turns it up with speed (Volume is the loudest it gets)
	Wind = { Id = 74693111419814, Volume = 0.5, Looped = true },

	-- Map hazards
	PumpkinHit = { Id = 3765689841, Volume = 0.9, Speed = 0.6, Range = 200 }, -- the bonk, lower and duller
	Sizzle = { Id = 9119165650, Volume = 0.8, Range = 150 }, -- PSE, a hot burner

	-- Shop
	Purchase = { Id = 120891770644830, Volume = 0.6 },

	-- "The Ramblers' String Band Special" (APM)
	Music = { Id = 1840556856, Volume = 0.3, Looped = true },
}

return Sounds
