-- The giant angry chef. He stands in the middle of the map (its ChefSpot part) for the whole race, and once he
-- starts he throws food at the turkeys. A glowing circle marks where each throw will land, aimed at where its
-- target is heading, so keeping an eye out and swerving dodges it.
--
-- Chef.enter puts him on his spot; Chef.begin starts the throwing; Chef.stop clears everything away.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local TrackProps = require(ReplicatedStorage.Shared.TrackProps)
local Track = require(script.Parent.Track)
local Sfx = require(script.Parent.Sfx)
local PowerUps = require(script.Parent.PowerUps)

local Remotes = ReplicatedStorage.Remotes
local settings = Config.Chef

local Chef = {}

-- Where his throwing arm joins his body, from his feet, and how far down it his hand is.
local SHOULDER = CFrame.new(14.25, 37.5, 0)
local ARM_LENGTH = 24

-- The throwing arm's angle: 0 hangs down, 90 degrees points forward, past 180 is back behind his head.
local IDLE_ANGLE, WINDUP_ANGLE, RELEASE_ANGLE, FOLLOW_ANGLE = math.rad(35), math.rad(215), math.rad(110), math.rad(55)
local WINDUP_TIME, RELEASE_TIME, RECOVER_TIME = 0.5, 0.68, 1.15
local TURN_SPEED = math.rad(220)

local model: Model?
local parts, partList = {}, {}
local connection: RBXScriptConnection?
local racers = {}
local throwing = false
local spot = CFrame.identity
local facing = 0
local lastThrownAt = {} -- [player] = when he last threw at them
local nextThrowAt = 0
local windup = nil -- { food, target, startedAt }
local flying = {} -- { food, from, to, arc, startedAt, flight, spin, disc, fill }
local effects: Folder? -- the food, circles and splats

local function effectPart(props, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- The chef's model ----------------------------------------------------------------------------------------------

-- Two meshes from assets/lowpoly: his body, whose origin is his feet with his front facing -Z, and his throwing arm,
-- whose origin is its shoulder, hanging along -Y. Each has an Offset attribute: how far its middle is from its origin.
local function add(name: string, group: string?)
	local mesh = TrackProps.new(name)
	mesh.Parent = model
	table.insert(parts, { offset = CFrame.new(mesh:GetAttribute("Offset")), group = group })
	table.insert(partList, mesh)
end

local function build()
	model = Instance.new("Model")
	model.Name = "Chef"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	table.clear(parts)
	table.clear(partList)
	add("Chef_Body")
	add("Chef_Arm", "arm")
	model.Parent = workspace
end

local function pose(root: CFrame, armAngle: number)
	local arm = root * SHOULDER * CFrame.Angles(armAngle, 0, 0)
	local cframes = table.create(#parts)
	for i, entry in parts do
		cframes[i] = (if entry.group == "arm" then arm else root) * entry.offset
	end
	workspace:BulkMoveTo(partList, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	return arm * CFrame.new(0, -ARM_LENGTH, 0)
end

-- How far through a throw his arm is, by time since the windup began.
local function armAngle(t: number?): number
	if not t or t >= RECOVER_TIME then
		return IDLE_ANGLE + math.sin(os.clock() * 2.5) * math.rad(5)
	elseif t < WINDUP_TIME then
		return IDLE_ANGLE + (WINDUP_ANGLE - IDLE_ANGLE) * (t / WINDUP_TIME) ^ 0.6
	elseif t < RELEASE_TIME then
		return WINDUP_ANGLE + (FOLLOW_ANGLE - WINDUP_ANGLE) * (t - WINDUP_TIME) / (RELEASE_TIME - WINDUP_TIME)
	end
	return FOLLOW_ANGLE + (IDLE_ANGLE - FOLLOW_ANGLE) * (t - RELEASE_TIME) / (RECOVER_TIME - RELEASE_TIME)
end

-- The food -------------------------------------------------------------------------------------------------------

-- Each food's model in TrackProps, and the color of the mark it leaves.
local LOOKS = {
	Tomato = { Mesh = "Tomato", Splat = Color3.fromRGB(225, 45, 35) },
	Pie = { Mesh = "Pie", Splat = Color3.fromRGB(235, 130, 50) },
	Pan = { Mesh = "FryingPan", Splat = Color3.fromRGB(255, 250, 235) },
}

local function pickFood()
	local total = 0
	for _, def in settings.Foods do
		total += def.Weight
	end
	local roll = math.random() * total
	for _, def in settings.Foods do
		roll -= def.Weight
		if roll <= 0 then
			return def
		end
	end
	return settings.Foods[1]
end

local function newFood()
	local def = pickFood()
	local look = LOOKS[def.Name]
	local food = Instance.new("Model")
	food.Name = def.Name
	local mesh = TrackProps.new(look.Mesh)
	mesh.Parent = food
	food.PrimaryPart = mesh
	food.Parent = effects
	return { def = def, model = food, splat = look.Splat }
end

-- The racers he can still throw at, with their root parts.
local function targets()
	local list = {}
	for player, r in racers do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and not r.finishTime and not r.cooked then
			table.insert(list, { player = player, root = root })
		end
	end
	return list
end

-- Whoever has gone longest without a throw at them, so nobody gets picked on.
local function pickTarget(list)
	local best, bestAt = nil, math.huge
	for _, t in list do
		local at = (lastThrownAt[t.player] or 0) + math.random() * 0.01
		if at < bestAt then
			best, bestAt = t, at
		end
	end
	return best
end

-- Where a turkey will be after `seconds` if it keeps going: on the racing surface, and inside the lane.
local function landingSpot(root: BasePart, seconds: number): Vector3
	local velocity = root.AssemblyLinearVelocity
	local ahead = root.Position + Vector3.new(velocity.X, 0, velocity.Z) * seconds
	local center, dir = Track.pointAt(Track.distanceAt(ahead))
	local side = dir:Cross(Vector3.yAxis)
	local limit = math.max(0, Track.LaneWidth / 2 - 4)
	return center + side * math.clamp((ahead - center):Dot(side), -limit, limit)
end

-- A flat disc lying on the track.
local function disc(position: Vector3, diameter: number, props): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(0.25, diameter, diameter)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return effectPart(props, effects)
end

local function release(food, target)
	lastThrownAt[target.player] = os.clock()
	local from = food.model:GetPivot().Position
	local flat = Vector3.new(target.root.Position.X - from.X, 0, target.root.Position.Z - from.Z).Magnitude
	local flight = math.clamp(flat / settings.ThrowSpeed, settings.MinFlightSeconds, settings.MaxFlightSeconds)
	local to = landingSpot(target.root, flight)
	local diameter = food.def.Radius * 2

	-- The outer circle shows how far the splash reaches; the inner one fills it as the food comes down.
	local outline = disc(to + Vector3.new(0, 0.3, 0), diameter, { Name = "LandingZone", Color = Color3.fromRGB(255, 90, 40), Material = Enum.Material.Neon, Transparency = 0.55 })
	local fill = disc(to + Vector3.new(0, 0.42, 0), 0.5, { Name = "LandingFill", Color = Color3.fromRGB(255, 225, 60), Material = Enum.Material.Neon, Transparency = 0.25 })
	TweenService:Create(fill, TweenInfo.new(flight, Enum.EasingStyle.Linear), { Size = Vector3.new(0.25, diameter, diameter) }):Play()

	table.insert(flying, {
		food = food,
		from = from,
		to = to,
		arc = settings.ArcHeight + flat * 0.12,
		startedAt = os.clock(),
		flight = flight,
		spin = Vector3.new(math.random() * 8 - 4, math.random() * 8 - 4, math.random() * 8 - 4),
		outline = outline,
		fill = fill,
	})
	Sfx.all("Throw", from)
end

local function splat(throw)
	local to, def = throw.to, throw.food.def
	throw.food.model:Destroy()
	throw.outline:Destroy()
	throw.fill:Destroy()

	-- A splat that sits on the track for a moment, with bits flying off it.
	local mark = disc(to + Vector3.new(0, 0.3, 0), def.Radius * 1.5, { Name = "Splat", Color = throw.food.splat })
	TweenService:Create(mark, TweenInfo.new(settings.SplatSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(mark, settings.SplatSeconds + 0.1)
	local bits = Instance.new("ParticleEmitter")
	bits.Color = ColorSequence.new(throw.food.splat)
	bits.Size = NumberSequence.new(1.6, 0.4)
	bits.Lifetime = NumberRange.new(0.35, 0.7)
	bits.Speed = NumberRange.new(25, 45)
	bits.SpreadAngle = Vector2.new(70, 70)
	bits.Acceleration = Vector3.new(0, -90, 0)
	bits.Rate = 160
	bits.EmissionDirection = Enum.NormalId.Right -- straight up, since the disc lies on its side
	bits.Parent = mark
	task.delay(0.15, function()
		bits.Enabled = false
	end)
	Sfx.all(def.Sound, to)

	for _, t in targets() do
		local offset = t.root.Position - to
		local flat = Vector3.new(offset.X, 0, offset.Z)
		-- The rider sits RideHeight above the track.
		if flat.Magnitude < def.Radius + 1.5 and math.abs(offset.Y - Config.Movement.RideHeight) < 10 then
			local away = if flat.Magnitude > 0.5 then flat.Unit else -t.root.CFrame.LookVector
			PowerUps.hit(t.player, away * def.Push + Vector3.new(0, def.Lift, 0), def.StunSeconds, def.Message)
		end
	end
end

local function updateFlying(now: number)
	for i = #flying, 1, -1 do
		local throw = flying[i]
		local t = (now - throw.startedAt) / throw.flight
		if t >= 1 then
			splat(throw)
			table.remove(flying, i)
		else
			local pos = throw.from:Lerp(throw.to, t) + Vector3.new(0, throw.arc * 4 * t * (1 - t), 0)
			local age = now - throw.startedAt
			throw.food.model:PivotTo(CFrame.new(pos) * CFrame.Angles(throw.spin.X * age, throw.spin.Y * age, throw.spin.Z * age))
		end
	end
end

local function startWindup(now: number, list)
	local target = pickTarget(list)
	if target then
		windup = { food = newFood(), target = target, startedAt = now, released = false }
		local interval = settings.ThrowSeconds - settings.CrowdSpeedup * (#list - 1)
		nextThrowAt = now + math.max(interval, settings.MinThrowSeconds)
	end
end

-- What he's looking toward: the turkey he's throwing at, or else the nearest one.
local function lookTarget(list, position: Vector3): Vector3?
	if windup and not windup.released and windup.target.root.Parent then
		return windup.target.root.Position
	end
	local best, bestDistance = nil, math.huge
	for _, t in list do
		local distance = (t.root.Position - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = t.root.Position, distance
		end
	end
	return best
end

local function step(dt: number)
	local now = os.clock()
	local list = targets()

	local position = spot.Position
	local look = lookTarget(list, position)
	if look then
		local want = math.atan2(-(look.X - position.X), -(look.Z - position.Z))
		local diff = (want - facing + math.pi) % (math.pi * 2) - math.pi
		facing += math.clamp(diff, -TURN_SPEED * dt, TURN_SPEED * dt)
	end
	local bob = math.abs(math.sin(now * 2.5)) * 0.8
	local root = CFrame.new(position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, facing, 0)

	if throwing and not windup and now >= nextThrowAt then
		startWindup(now, list)
	end
	local t = if windup then now - windup.startedAt else nil
	local hand = pose(root, armAngle(t))

	if windup and not windup.released then
		windup.food.model:PivotTo(hand)
		if t >= (WINDUP_TIME + RELEASE_TIME) / 2 then
			windup.released = true
			if windup.target.root.Parent then
				release(windup.food, windup.target)
			else
				windup.food.model:Destroy()
			end
		end
	elseif windup and t >= RECOVER_TIME then
		windup = nil
	end
	updateFlying(now)
end

-- Race hooks ------------------------------------------------------------------------------------------------------

-- Puts him on the current map's spot, watching the turkeys line up.
function Chef.enter(raceRacers)
	Chef.stop()
	racers = raceRacers
	spot = Track.Current.ChefSpot
	facing = select(2, spot:ToOrientation())
	effects = Instance.new("Folder")
	effects.Name = "ChefThrows"
	effects.Parent = workspace
	build()
	step(0) -- onto his spot before anyone sees him at the world's origin
	connection = RunService.Heartbeat:Connect(step)
end

function Chef.begin()
	throwing = true
	nextThrowAt = os.clock()
	Remotes.Notify:FireAllClients("👨‍🍳 THE CHEF IS THROWING FOOD! Watch for the circles!")
	Sfx.all("ChefRoar")
end

function Chef.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	throwing = false
	windup = nil
	table.clear(flying)
	table.clear(lastThrownAt)
	if effects then
		effects:Destroy()
		effects = nil
	end
	if model then
		model:Destroy()
		model = nil
	end
end

return Chef
