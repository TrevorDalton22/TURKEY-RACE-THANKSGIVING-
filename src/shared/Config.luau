-- Tuning values shared by the server and clients.

-- Robux item ids. An id belongs to one experience, so each copy of the game has its own set, picked by
-- game.GameId: the real game, and the private work copy, where Studio's test purchases are free.
-- docs/publishing.md has the items, prices and how to create them. Anything at 0 shows as "Coming soon".
local NO_IDS = {
	PremiumPass = 0,
	VipPass = 0,
	Skins = { Rainbow = 0, Galaxy = 0, Diamond = 0 },
	XpBoosts = { 0, 0 }, -- 30 minutes, 2 hours
	FeatherPacks = { 0, 0, 0 }, -- 300, 1,000, 3,000
	Starters = { 0, 0 }, -- 5 races, 15 races
	FeastFrenzy = 0,
	HarvestBundle = 0,
}
local ROBUX_IDS = {
	-- 🦃 TURKEY RACE! [DON'T GET COOKED!], the real game (place 84232605874844)
	[10774782857] = NO_IDS,
	-- The private work copy (place 111513837896037), created 2026-11-08
	[10774869273] = {
		PremiumPass = 2075236088,
		VipPass = 2075986033,
		Skins = { Rainbow = 2075374030, Galaxy = 2075296128, Diamond = 2075644054 },
		XpBoosts = { 3729564029, 3729564096 },
		FeatherPacks = { 3729564102, 3729564108, 3729564115 },
		Starters = { 3729564121, 3729564127 },
		FeastFrenzy = 3730272928, -- created 2026-11-10
		HarvestBundle = 3730272938,
	},
}
local ids = ROBUX_IDS[game.GameId] or NO_IDS

local Config = {
	MaxPlayers = 8,

	-- Racers join by standing in the Join Race circle in the lobby (Workspace.Lobby.JoinCircle). The
	-- countdown starts once MinPlayersToStart are in it, starts over if they all step out, and races
	-- whoever is in it when it runs out.
	MinPlayersToStart = 1,
	IntermissionSeconds = 15,
	QuickStartSeconds = 5, -- when everyone in the server is in the circle, the countdown skips ahead to this
	CountdownSeconds = 3,
	GateSeconds = 4, -- the starting gate is taken down this long after GO
	RaceTimeLimitSeconds = 150,
	-- After a race: the podium cutscene (PodiumSeconds), then the results board, ResultsSeconds in all.
	PodiumSeconds = 8,
	ResultsSeconds = 14,
	Laps = 3, -- a map can override this with a Laps attribute

	-- The map changes every race; the mode changes after every map has been played,
	-- so each map gets both modes.
	Modes = { "Race", "Elimination" },
	Elimination = {
		StartSeconds = 20,
		IntervalSeconds = 12,
		FinalCount = 3, -- eliminations stop when this many turkeys are left
	},

	-- Racers below this height fell off the table and respawn at their last checkpoint.
	FallHeight = 25,

	-- Fastest average speed (studs a second) a turkey can cover the track between two checkpoints.
	-- Galloping, sliding and dashing the whole way averages about 120, so only a cheater teleporting
	-- ahead goes faster; they're sent back to the checkpoint they came from.
	MaxPace = 190,

	-- Seconds between gobbles (G key) per player.
	GobbleCooldown = 1.5,

	-- Everyone rides a turkey. Speeds are studs a second: trotting, galloping (sprint, uses stamina)
	-- and the belly-slide burst.
	Movement = {
		-- How high the middle of the rider's body is above the ground. The sitting pose drops their hips about a stud
		-- below that, onto the saddle, whose seat tops out 7.4 studs up (assets/turkey).
		RideHeight = 8.6,
		JumpHeight = 8,
		WalkSpeed = 45,
		SprintSpeed = 68,
		SlideSpeed = 98,
		SlideSeconds = 0.5,
		SlideCooldown = 2.5,
		StaminaMax = 100,
		StaminaDrain = 25,
		StaminaRegen = 22,
		FlapVelocity = 34,
		FlapsPerJump = 2,
	},

	-- The chef stands in the middle of the map and throws food at the turkeys.
	Chef = {
		StartsAtSeconds = 8, -- seconds after GO; a map can override this with a ChefStartsAt attribute
		-- Seconds between throws, shortened by CrowdSpeedup for each racer after the first.
		ThrowSeconds = 2.6,
		CrowdSpeedup = 0.2,
		MinThrowSeconds = 1.2,
		-- Food flies at ThrowSpeed (studs a second), within these limits, so the circle always gives time to dodge.
		ThrowSpeed = 130,
		MinFlightSeconds = 1,
		MaxFlightSeconds = 1.6,
		ArcHeight = 35,
		SplatSeconds = 1.6,
		Foods = {
			{ Name = "Tomato", Weight = 5, Radius = 9, Push = 35, Lift = 35, StunSeconds = 0.8, Sound = "Splat", Message = "🍅 SPLAT! The chef got you with a tomato!" },
			{ Name = "Pie", Weight = 3, Radius = 12, Push = 30, Lift = 40, StunSeconds = 1, Sound = "Splat", Message = "🥧 SPLAT! A pie from the chef!" },
			{ Name = "Pan", Weight = 2, Radius = 8, Push = 50, Lift = 55, StunSeconds = 1.4, Sound = "Bonk", Message = "🍳 BONK! The chef threw a frying pan!" },
		},
	},

	PowerUps = {
		DrumstickDash = { Name = "Drumstick Dash", Icon = "🍗", Multiplier = 1.4, Seconds = 3 },
		PieLauncher = { Name = "Pie Launcher", Icon = "🥧", Speed = 190, Range = 300, SlowMultiplier = 0.5, SlowSeconds = 2.5 },
		ButterSlide = { Name = "Butter Slide", Icon = "🧈", Lifetime = 12, StunSeconds = 1 },
		-- Knocks every turkey within Radius away from you.
		GobbleBomb = { Name = "Gobble Bomb", Icon = "💥", Radius = 26, Push = 70, Lift = 35, StunSeconds = 1.2 },
		-- Blocks the next hit of any kind (chef included), or runs out after Seconds.
		MashedPotatoShield = { Name = "Potato Shield", Icon = "🥔", Seconds = 10 },
		-- Rolls down the track ahead of you, steering toward turkeys and spinning them around.
		CornTornado = { Name = "Corn Tornado", Icon = "🌪️", Speed = 120, Seconds = 4, HitRadius = 8, SpinSeconds = 1.5, SpinSpeed = 18 },
	},
	ItemBoxRespawnSeconds = 4,
	ItemBoxPickupRadius = 9, -- studs from the box's middle to the rider's

	-- Riding over a boost pad. Reach is how far above the saddle still counts, so a good jump clears one.
	BoostPad = { Multiplier = 1.5, Seconds = 1.5, Reach = 6 },

	-- Map hazards.
	Hazards = {
		-- Pumpkins rolling down Pumpkin Hill (Pumpkin Patch Panic). Interval is the average gap between pumpkins.
		Pumpkin = { Interval = 1.2, Speed = 50, Size = 9, Push = 45, Lift = 40, StunSeconds = 1.1 },
		-- Stove burners and the griddle (Escape the Oven): each is cool, then glows as a warning, then is hot
		-- and throws any turkey standing on it. Burners start at different points in the cycle.
		Burner = { CoolSeconds = 3, WarnSeconds = 1, HotSeconds = 2, Push = 25, Lift = 50, StunSeconds = 0.7 },
	},

	-- Feathers awarded at the end of a race.
	Rewards = {
		Play = 5,
		Finish = 10,
		Places = { 25, 15, 10 },
	},

	-- XP, awarded at the end of a race alongside Feathers. It raises your level (which never resets)
	-- and your Harvest Pass tier (shared/Season).
	Progression = {
		Xp = { Play = 25, Finish = 25, Places = { 50, 30, 20 } },
		-- XP to go from level L to L + 1 is LevelBase + LevelStep * (L - 1).
		LevelBase = 100,
		LevelStep = 25,
		BoostMultiplier = 2, -- while an XP boost is running
	},

	-- Robux items, with this experience's ids (see ROBUX_IDS above). Anything at 0 shows as "Coming soon".
	Robux = {
		-- Game passes: bought once, owned forever.
		PremiumPass = ids.PremiumPass, -- the premium track of the Harvest Pass
		VipPass = ids.VipPass, -- see Vip below
		Skins = ids.Skins, -- skins marked Robux in shared/Skins
		-- Developer products: can be bought again and again.
		XpBoosts = { -- each adds Minutes of 2x XP
			{ Id = ids.XpBoosts[1], Minutes = 30 },
			{ Id = ids.XpBoosts[2], Minutes = 120 },
		},
		FeatherPacks = { -- Tag is a ribbon on the shop card
			{ Id = ids.FeatherPacks[1], Feathers = 300 },
			{ Id = ids.FeatherPacks[2], Feathers = 1000, Tag = "POPULAR" },
			{ Id = ids.FeatherPacks[3], Feathers = 3000, Tag = "BEST VALUE" },
		},
		Starters = { -- each adds Races that start with a power-up in hand (never the Drumstick Dash)
			{ Id = ids.Starters[1], Races = 5 },
			{ Id = ids.Starters[2], Races = 15 },
		},
		-- The whole server earns Multiplier x Feathers from races for Minutes; buying more adds more time.
		FeastFrenzy = { Id = ids.FeastFrenzy, Minutes = 15, Multiplier = 2 },
		-- A skin, Feathers and Power-Up Starters together. Anyone who already has the skin gets FeathersIfOwned more
		-- Feathers instead. WorthRobux is what the parts cost bought separately, shown crossed out: 1,000 Feathers
		-- R$ 75, 5 Starters R$ 39, and the skin's 750 Feathers about R$ 56.
		HarvestBundle = { Id = ids.HarvestBundle, Skin = "Chef", Feathers = 1000, Starters = 5, FeathersIfOwned = 750, WorthRobux = 170 },
	},

	-- What the VIP pass gives, besides a VIP tag in chat and over your turkey and a golden trail.
	Vip = {
		FeatherMultiplier = 2, -- on the Feathers from every race
	},

	-- The Wins board in the lobby.
	Leaderboard = {
		Size = 10,
		RefreshSeconds = 60, -- global board; the Studio fallback refreshes every few seconds
	},
}

return Config
