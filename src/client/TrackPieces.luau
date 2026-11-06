-- Brings the current map's track pieces to life: item boxes float and spin with a ring orbiting them, burst when
-- someone grabs one and pop back in when they respawn, and each boost pad's chevrons chase the way you race.
-- All of this is only for show, so each client does it for itself and nothing here touches the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TrackPieces = {}

local BOB_HEIGHT, BOB_SPEED, SPIN_SPEED = 0.6, 2, 1.5
local HALO_TILT = CFrame.Angles(math.rad(18), 0, math.rad(8))
local POP_SECONDS = 0.35
local DRAW_DISTANCE = 400 -- don't bother with what's too far off to see moving

local CHEVRON_DIM, CHEVRON_BRIGHT = Color3.fromRGB(150, 55, 15), Color3.fromRGB(255, 225, 90)
local CHASE_SPEED = 2.2
local CHEVRON_STEP = 1 / 20 -- seconds between color changes

local camera = workspace.CurrentCamera

-- A box's pieces can stream in separately, so its state is made once they've all arrived.
local boxes = setmetatable({}, { __mode = "k" })

local function stateOf(box: BasePart)
	local state = boxes[box]
	if state and state.body.Parent and state.glow.Parent and state.halo.Parent then
		return state
	end
	local body, glow, halo = box:FindFirstChild("Body"), box:FindFirstChild("Glow"), box:FindFirstChild("Halo")
	if not (body and glow and halo) then
		return nil
	end
	state = {
		body = body,
		glow = glow,
		halo = halo,
		sizes = { body = body.Size, glow = glow.Size, halo = halo.Size },
		offset = body:GetAttribute("OffsetY") or 0,
		phase = (box.Position.X + box.Position.Z) * 0.13,
		active = true,
		poppedAt = nil,
	}
	boxes[box] = state
	return state
end

local function setShown(state, shown: boolean)
	local transparency = if shown then 0 else 1
	state.body.Transparency = transparency
	state.glow.Transparency = transparency
	state.halo.Transparency = transparency
	local light = state.glow:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = shown
	end
	local sparkles = state.glow:FindFirstChildOfClass("ParticleEmitter")
	if sparkles then
		sparkles.Enabled = shown
	end
end

local function setScale(state, scale: number)
	state.body.Size = state.sizes.body * scale
	state.glow.Size = state.sizes.glow * scale
	state.halo.Size = state.sizes.halo * scale
end

-- Overshoots a little before settling, so a box pops back in.
local function popCurve(t: number): number
	local back = 1.7
	local u = t - 1
	return 1 + (back + 1) * u * u * u + back * u * u
end

local function updateBox(box: BasePart, now: number, cameraAt: Vector3)
	if (box.Position - cameraAt).Magnitude > DRAW_DISTANCE then
		return
	end
	local state = stateOf(box)
	if not state then
		return
	end

	local active = box:GetAttribute("Active") ~= false
	if active ~= state.active then
		state.active = active
		setShown(state, active)
		if active then
			state.poppedAt = now
		else
			local sparkles = state.glow:FindFirstChildOfClass("ParticleEmitter")
			if sparkles then
				sparkles:Emit(30)
			end
		end
	end
	if not active then
		return
	end

	local scale = 1
	if state.poppedAt then
		local t = (now - state.poppedAt) / POP_SECONDS
		if t >= 1 then
			state.poppedAt = nil
		else
			scale = math.max(popCurve(t), 0.01)
		end
		setScale(state, scale)
	end

	local floating = box.CFrame * CFrame.new(0, math.sin(now * BOB_SPEED + state.phase) * BOB_HEIGHT, 0)
	local spun = floating * CFrame.Angles(0, now * SPIN_SPEED + state.phase, 0)
	state.body.CFrame = spun * CFrame.new(0, state.offset * scale, 0)
	state.glow.CFrame = spun
	state.halo.CFrame = floating * HALO_TILT * CFrame.Angles(0, -now * SPIN_SPEED * 1.8, 0)
end

local function updateChevrons(pads: { Instance }, now: number)
	for _, pad in pads do
		for i = 1, 3 do
			local chevron = pad:FindFirstChild("Chevron" .. i) :: BasePart?
			if chevron then
				-- Chevron1 is at the back of the pad, so the light runs forward along it.
				local phase = (now * CHASE_SPEED - (i - 1) / 3) % 1
				chevron.Color = CHEVRON_DIM:Lerp(CHEVRON_BRIGHT, (1 - phase) ^ 2)
			end
		end
	end
end

local function currentMap(): Instance?
	local maps = workspace:FindFirstChild("Maps")
	local name = ReplicatedStorage:GetAttribute("Map")
	if maps and name then
		for _, map in maps:GetChildren() do
			if map:GetAttribute("DisplayName") == name then
				return map
			end
		end
	end
	return nil
end

function TrackPieces.start()
	local map = currentMap()
	ReplicatedStorage:GetAttributeChangedSignal("Map"):Connect(function()
		map = currentMap()
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		camera = workspace.CurrentCamera
	end)

	local chevronsAt = 0
	RunService.RenderStepped:Connect(function()
		-- The maps are far from the lobby, so nothing here is in view unless you're racing.
		if not map or not Players.LocalPlayer:GetAttribute("Racing") then
			return
		end
		local now = os.clock()
		local boxFolder = map:FindFirstChild("ItemBoxes")
		if boxFolder then
			local cameraAt = camera.CFrame.Position
			for _, box in boxFolder:GetChildren() do
				updateBox(box, now, cameraAt)
			end
		end
		if now >= chevronsAt then
			chevronsAt = now + CHEVRON_STEP
			local padFolder = map:FindFirstChild("BoostPads")
			if padFolder then
				updateChevrons(padFolder:GetChildren(), now)
			end
		end
	end)
end

return TrackPieces
