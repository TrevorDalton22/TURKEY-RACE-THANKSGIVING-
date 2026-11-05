-- The winners' podium in the lobby (Workspace.Lobby.Podium, with stands Stand1, Stand2 and Stand3 whose fronts
-- face the audience). After a race the top three are placed on their stands, held still while the podium
-- cutscene plays (client/Cutscene), then let go to ride off whenever they like.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Podium = {}

local held: { Player } = {}

local function stand(place: number): BasePart?
	local lobby = workspace:FindFirstChild("Lobby")
	local podium = lobby and lobby:FindFirstChild("Podium")
	return podium and podium:FindFirstChild("Stand" .. place) :: BasePart?
end

-- Lets go of last race's winners.
function Podium.release()
	for _, player in held do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = false
		end
	end
	table.clear(held)
end

-- players: up to three, in finishing order. Returns the ones placed (all of them, unless the place has no
-- podium or someone has no character).
function Podium.show(players: { Player }): { Player }
	Podium.release()
	for place, player in players do
		local part = stand(place)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if part and root then
			-- The rider's middle sits RideHeight above the turkey's feet.
			local top = part.Position + Vector3.new(0, part.Size.Y / 2 + Config.Movement.RideHeight + 0.05, 0)
			local facing = part.CFrame.LookVector * Vector3.new(1, 0, 1)
			character:PivotTo(CFrame.lookAt(top, top + facing))
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = true
			table.insert(held, player)
		end
	end
	return table.clone(held)
end

return Podium
