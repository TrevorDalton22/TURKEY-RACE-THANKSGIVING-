-- Asks clients to play a sound from shared/Sounds, and handles the gobble button.
-- where: nil (heard flat by everyone), a Vector3, or a part the sound follows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = ReplicatedStorage.Remotes

local Sfx = {}

local lastGobble: { [Player]: number } = {}

-- A part that hasn't streamed in to a client arrives as nil, so its position goes along as a fallback.
local function args(where: (Vector3 | BasePart)?)
	if typeof(where) == "Instance" then
		return where, where.Position
	end
	return where, nil
end

function Sfx.all(name: string, where: (Vector3 | BasePart)?)
	Remotes.Sound:FireAllClients(name, args(where))
end

function Sfx.to(player: Player, name: string, where: (Vector3 | BasePart)?)
	Remotes.Sound:FireClient(player, name, args(where))
end

function Sfx.gobble(player: Player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		Sfx.all("Gobble", root)
	end
end

function Sfx.start()
	Remotes.Gobble.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastGobble[player] or 0) >= Config.GobbleCooldown then
			lastGobble[player] = now
			Sfx.gobble(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastGobble[player] = nil
	end)
end

return Sfx
