local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

print(`[TurkeyRace] Server ready ({Config.MaxPlayers}-player races)`)
