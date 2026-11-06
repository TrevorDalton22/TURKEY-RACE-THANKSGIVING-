-- Boost pads: riding over one gives a short burst of speed. Each map has a BoostPads folder of invisible anchor parts,
-- lying on the track and facing the way you race, with the visible pieces inside them (client/TrackPieces animates
-- those). Jumping high enough clears a pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Track = require(script.Parent.Track)
local PowerUps = require(script.Parent.PowerUps)
local Sfx = require(script.Parent.Sfx)

local settings = Config.BoostPad

local BoostPads = {}

local racers = {}
local boostedAt = {} -- [player] = when their last boost started, so they can't stack
local connection: RBXScriptConnection?

local function onPad(pad: BasePart, position: Vector3): boolean
	local relative = pad.CFrame:PointToObjectSpace(position)
	local half = pad.Size / 2
	return math.abs(relative.X) < half.X + 1
		and math.abs(relative.Z) < half.Z + 1
		and relative.Y > 0
		and relative.Y < Config.Movement.RideHeight + settings.Reach
end

local function step()
	local now = os.clock()
	for player, r in racers do
		if r.finishTime or r.cooked or now - (boostedAt[player] or 0) < settings.Seconds then
			continue
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		for _, pad in Track.BoostPads do
			if onPad(pad, root.Position) then
				boostedAt[player] = now
				PowerUps.speedUp(player, settings.Multiplier, settings.Seconds)
				Sfx.all("Dash", root)
				break
			end
		end
	end
end

function BoostPads.begin(raceRacers)
	racers = raceRacers
	connection = RunService.Heartbeat:Connect(step)
end

function BoostPads.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	table.clear(boostedAt)
end

return BoostPads
