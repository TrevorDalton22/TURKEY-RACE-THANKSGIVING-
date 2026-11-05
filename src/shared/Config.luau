-- Tuning values shared by the server and clients.

local Config = {
	MaxPlayers = 8,
	MinPlayersToStart = 1,

	IntermissionSeconds = 12,
	CountdownSeconds = 3,
	ResultsSeconds = 8,
	RaceTimeLimitSeconds = 150,
	Laps = 2, -- a map can override this with a Laps attribute

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
	-- Dashing and sliding the whole way averages about 55, so only a cheater teleporting ahead goes
	-- faster; they're sent back to the checkpoint they came from.
	MaxPace = 90,

	-- Seconds between gobbles (G key) per player.
	GobbleCooldown = 1.5,

	Movement = {
		WalkSpeed = 18,
		SprintSpeed = 30,
		SlideSpeed = 48,
		SlideSeconds = 0.5,
		SlideCooldown = 2.5,
		StaminaMax = 100,
		StaminaDrain = 30,
		StaminaRegen = 18,
		FlapVelocity = 32,
		FlapsPerJump = 2,
	},

	Chef = {
		StartsAtSeconds = 45, -- a map can override this with a ChefStartsAt attribute
		Speed = 25,
		-- Speeds up when the last turkey gets this far ahead.
		CatchUpSpeed = 40,
		CatchUpDistance = 150,
		SpawnBehind = 120,
		HitRadius = 18,
		HitCooldown = 3,
		StunSeconds = 1.4,
	},

	PowerUps = {
		DrumstickDash = { Name = "Drumstick Dash", Icon = "🍗", Multiplier = 1.6, Seconds = 3 },
		PieLauncher = { Name = "Pie Launcher", Icon = "🥧", Speed = 90, Range = 160, SlowMultiplier = 0.5, SlowSeconds = 2.5 },
		ButterSlide = { Name = "Butter Slide", Icon = "🧈", Lifetime = 12, StunSeconds = 1 },
		-- Knocks every turkey within Radius away from you.
		GobbleBomb = { Name = "Gobble Bomb", Icon = "💥", Radius = 22, Push = 60, Lift = 35, StunSeconds = 1.2 },
		-- Blocks the next hit of any kind (chef included), or runs out after Seconds.
		MashedPotatoShield = { Name = "Potato Shield", Icon = "🥔", Seconds = 10 },
		-- Rolls down the track ahead of you, steering toward turkeys and spinning them around.
		CornTornado = { Name = "Corn Tornado", Icon = "🌪️", Speed = 55, Seconds = 4, HitRadius = 7, SpinSeconds = 1.5, SpinSpeed = 18 },
	},
	ItemBoxRespawnSeconds = 4,

	-- Map hazards.
	Hazards = {
		-- Pumpkins rolling down Pumpkin Hill (Pumpkin Patch Panic). Interval is the average gap between pumpkins.
		Pumpkin = { Interval = 1.4, Speed = 30, Size = 9, Push = 45, Lift = 40, StunSeconds = 1.1 },
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

	-- Robux items. Create each one in the Creator Dashboard after publishing (docs/publishing.md has the
	-- steps and suggested prices), then paste its id here. Anything left at 0 shows as "Coming soon".
	Robux = {
		-- Game passes: bought once, owned forever.
		PremiumPass = 0, -- the premium track of the Harvest Pass
		Skins = { Rainbow = 0, Galaxy = 0, Diamond = 0 }, -- skins marked Robux in shared/Skins
		-- Developer products: can be bought again and again. Each one adds Minutes of 2x XP.
		XpBoosts = {
			{ Id = 0, Minutes = 30 },
			{ Id = 0, Minutes = 120 },
		},
	},

	-- The Wins board in the lobby.
	Leaderboard = {
		Size = 10,
		RefreshSeconds = 60, -- global board; the Studio fallback refreshes every few seconds
	},
}

return Config
