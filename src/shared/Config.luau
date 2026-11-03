-- Tuning values shared by the server and clients.

local Config = {
	MaxPlayers = 8,
	MinPlayersToStart = 1,

	IntermissionSeconds = 12,
	CountdownSeconds = 3,
	ResultsSeconds = 8,
	RaceTimeLimitSeconds = 150,
	Laps = 2,

	-- Modes alternate each round so both can be playtested.
	Modes = { "Race", "Elimination" },
	Elimination = {
		StartSeconds = 20,
		IntervalSeconds = 12,
		FinalCount = 3, -- eliminations stop when this many turkeys are left
	},

	-- Racers below this height fell off the table and respawn at their last checkpoint.
	FallHeight = 25,

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
		StartsAtSeconds = 45,
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
	},
	ItemBoxRespawnSeconds = 4,

	-- Feathers awarded at the end of a race.
	Rewards = {
		Play = 5,
		Finish = 10,
		Places = { 25, 15, 10 },
	},
}

return Config
