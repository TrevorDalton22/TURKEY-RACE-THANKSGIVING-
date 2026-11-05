-- Makes going fast feel fast: the camera's view widens, wind streaks fly past the edges of the screen
-- and rushing air gets louder, all with your speed. Only on this screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Audio = require(script.Parent.Audio)

local player = Players.LocalPlayer
local move = Config.Movement

local SpeedFx = {}

local BASE_FOV, MAX_FOV = 70, 90
-- Effects start at a trot and are full strong at a dashing slide.
local FROM, TO = move.WalkSpeed, move.SlideSpeed

-- A strip of streaks along one edge of the view. Particles fly from 30 studs ahead toward the camera.
local function streakStrip(size: Vector3): (Part, ParticleEmitter)
	local strip = Instance.new("Part")
	strip.Name = "SpeedStreaks"
	strip.Anchored = true
	strip.CanCollide = false
	strip.CanQuery = false
	strip.CanTouch = false
	strip.CastShadow = false
	strip.Transparency = 1
	strip.Size = size
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Speed = NumberRange.new(130, 160)
	emitter.Lifetime = NumberRange.new(0.18, 0.22)
	emitter.Size = NumberSequence.new(0.07)
	emitter.Squash = NumberSequence.new(3)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	emitter.LightEmission = 0.6
	emitter.LockedToPart = true
	emitter.Rate = 0
	emitter.Parent = strip
	strip.Parent = workspace.CurrentCamera
	return strip, emitter
end

function SpeedFx.start()
	-- Left, right, top and bottom of the view, 30 studs ahead.
	local strips = {}
	for _, spec in {
		{ size = Vector3.new(4, 22, 1), offset = CFrame.new(-17, 0, -30) },
		{ size = Vector3.new(4, 22, 1), offset = CFrame.new(17, 0, -30) },
		{ size = Vector3.new(30, 3, 1), offset = CFrame.new(0, 11, -30) },
		{ size = Vector3.new(30, 3, 1), offset = CFrame.new(0, -11, -30) },
	} do
		local strip, emitter = streakStrip(spec.size)
		table.insert(strips, { part = strip, emitter = emitter, offset = spec.offset })
	end

	local wind = Audio.play("Wind")
	if wind then
		wind.Volume = 0
	end
	local maxWind = Sounds.Wind.Volume or 0.5
	local fov = BASE_FOV

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local speed = 0
		if root then
			local v = root.AssemblyLinearVelocity
			speed = Vector3.new(v.X, 0, v.Z).Magnitude
		end
		local amount = math.clamp((speed - FROM) / (TO - FROM), 0, 1)

		-- Ease the view toward its target so it swells and settles instead of snapping.
		fov += (BASE_FOV + (MAX_FOV - BASE_FOV) * amount - fov) * math.min(1, dt * 6)
		camera.FieldOfView = fov

		for _, strip in strips do
			strip.part.CFrame = camera.CFrame * strip.offset
			strip.emitter.Rate = if amount > 0.15 then amount * 70 else 0
		end
		if wind then
			wind.Volume = maxWind * amount
		end
	end)
end

return SpeedFx
