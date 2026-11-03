-- Tuning values shared by the server and clients.

local Config = {
	MaxPlayers = 8,
	MinPlayersToStart = 1,

	IntermissionSeconds = 15,
	RaceTimeLimitSeconds = 120,

	-- The chef chase starts near the end of each race.
	ChefStartsAtSeconds = 75,

	-- Feathers awarded at the end of a race.
	Rewards = {
		Finish = 10,
		Win = 25,
	},
}

return Config
