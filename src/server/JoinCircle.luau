-- The Join Race circle in the lobby (Workspace.Lobby.JoinCircle, whose Pad is a flat cylinder): keeps track
-- of who's standing in it. RaceManager starts the countdown when someone steps in and races whoever is in it
-- when the countdown runs out. Publishes the player attribute InCircle and the ReplicatedStorage attribute
-- Joined (how many are in).
--
-- Without a circle in the place, everyone in the lobby counts as joined, so races still run.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JoinCircle = {}

local pad: BasePart? = nil
local inside: { Player } = {}

-- How far above the pad a rider's middle can be and still count (riders sit well above the ground).
local MAX_HEIGHT = 20

local function isInside(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if not pad then
		return true
	end
	local offset = root.Position - pad.Position
	-- The pad is a cylinder lying on its side (its length points up), so Size.Z is its diameter.
	return Vector2.new(offset.X, offset.Z).Magnitude <= pad.Size.Z / 2 and offset.Y > -2 and offset.Y < MAX_HEIGHT
end

-- Everyone in the circle right now.
function JoinCircle.players(): { Player }
	return table.clone(inside)
end

function JoinCircle.count(): number
	return #inside
end

function JoinCircle.start()
	local lobby = workspace:FindFirstChild("Lobby")
	local circle = lobby and lobby:FindFirstChild("JoinCircle")
	pad = circle and circle:FindFirstChild("Pad") :: BasePart?
	if not pad then
		warn("[TurkeyRace] There's no Workspace.Lobby.JoinCircle.Pad, so everyone in the lobby joins every race")
	end

	task.spawn(function()
		while true do
			local list = {}
			for _, player in Players:GetPlayers() do
				-- Racers are on the track; turkeys cooked in Elimination wait in the lobby until the race ends.
				local joined = not player:GetAttribute("Racing") and isInside(player)
				if joined then
					table.insert(list, player)
				end
				if player:GetAttribute("InCircle") ~= (joined or nil) then
					player:SetAttribute("InCircle", joined or nil)
				end
			end
			inside = list
			if ReplicatedStorage:GetAttribute("Joined") ~= #list then
				ReplicatedStorage:SetAttribute("Joined", #list)
			end
			task.wait(0.2)
		end
	end)
end

return JoinCircle
