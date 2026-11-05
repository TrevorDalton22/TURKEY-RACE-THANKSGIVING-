-- The Join Race circle in the lobby, on this screen: a sign above it with the next race, how many have joined
-- and the countdown; a glowing ring that pulses faster as the race gets close; sparkles while a countdown
-- runs; and a chime when you step in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Audio = require(script.Parent.Audio)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local JoinCircle = {}

local MODE_NAMES = { Race = "Race", Elimination = "Don't Get Cooked" }
local GREEN = Color3.fromRGB(110, 235, 120)

local function sign(pad: BasePart): (TextLabel, TextLabel)
	local board = Instance.new("BillboardGui")
	board.Name = "JoinRaceSign"
	board.Adornee = pad
	board.ResetOnSpawn = false
	board.Size = UDim2.new(22, 0, 8, 0) -- in studs, so it reads as part of the lobby
	board.StudsOffsetWorldSpace = Vector3.new(0, 15, 0)
	board.LightInfluence = 0
	board.MaxDistance = 300
	board.Parent = player:WaitForChild("PlayerGui")

	Ui.label(board, {
		Size = UDim2.fromScale(1, 0.45),
		Text = "🏁 JOIN RACE 🏁",
		TextColor3 = GREEN,
		TextStrokeTransparency = 0,
	})
	local status = Ui.label(board, {
		Position = UDim2.fromScale(0, 0.45),
		Size = UDim2.fromScale(1, 0.3),
		TextStrokeTransparency = 0,
	})
	local nextRace = Ui.label(board, {
		Position = UDim2.fromScale(0, 0.75),
		Size = UDim2.fromScale(1, 0.22),
		TextColor3 = Color3.fromRGB(255, 225, 170),
		TextStrokeTransparency = 0,
	})
	return status, nextRace
end

-- Sparkles rising off the whole circle, from a flat invisible part laid over it.
local function sparkles(pad: BasePart): ParticleEmitter
	local area = Instance.new("Part")
	area.Name = "JoinSparkles"
	area.Anchored = true
	area.CanCollide = false
	area.CanQuery = false
	area.CanTouch = false
	area.Transparency = 1
	area.Size = Vector3.new(pad.Size.Z * 0.8, 0.2, pad.Size.Z * 0.8)
	area.CFrame = CFrame.new(pad.Position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(GREEN, Color3.fromRGB(255, 240, 150))
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(1.2, 2)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.Rate = 0
	emitter.Parent = area
	area.Parent = workspace
	return emitter
end

function JoinCircle.start()
	local lobby = workspace:WaitForChild("Lobby")
	local circle = lobby:WaitForChild("JoinCircle", 15)
	local pad = circle and circle:WaitForChild("Pad", 15) :: BasePart?
	if not circle or not pad then
		return
	end
	local ring = circle:FindFirstChild("Ring") :: BasePart?
	local status, nextRace = sign(pad)
	local emitter = sparkles(pad)

	player:GetAttributeChangedSignal("InCircle"):Connect(function()
		if player:GetAttribute("InCircle") then
			Audio.play("Join")
		end
	end)

	RunService.RenderStepped:Connect(function()
		local phase = ReplicatedStorage:GetAttribute("Phase") or "Waiting"
		local remaining = math.max(0, (ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow())
		local joined = ReplicatedStorage:GetAttribute("Joined") or 0
		local inCircle = player:GetAttribute("InCircle") == true
		local mode = MODE_NAMES[ReplicatedStorage:GetAttribute("Mode") or "Race"] or "Race"
		local counting = phase == "Intermission"

		if counting then
			status.Text = `{if inCircle then "✅ You're in!  " else ""}{joined} joined  •  Starts in {math.ceil(remaining)}`
		elseif phase == "Waiting" then
			status.Text = if inCircle then "✅ You're in!" else "Step in to race!"
		elseif phase == "Results" then
			status.Text = "Step in for the next race!"
		else
			status.Text = "Race in progress, step in for the next one!"
		end
		status.TextColor3 = if inCircle then GREEN else Color3.new(1, 1, 1)
		nextRace.Text = `Next: {ReplicatedStorage:GetAttribute("Map") or ""}  •  {mode}`

		emitter.Rate = if counting then 25 else 6
		if ring then
			-- Pulses gently while waiting, quicker once the countdown is on.
			local speed = if counting then 6 else 2.5
			ring.LocalTransparencyModifier = 0.35 * (0.5 + 0.5 * math.sin(os.clock() * speed))
		end
	end)
end

return JoinCircle
