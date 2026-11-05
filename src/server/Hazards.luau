-- Map hazards that move or change on their own. A map opts in with a Hazards folder holding any of:
--
--   PumpkinRoll  a folder with two marker parts on the path, Start and End. Pumpkins drop in at Start and
--                roll along the lane to End (either direction), flattening any turkey they run into.
--   Burner       a model that is cool, then glows as a warning, then is hot and throws any turkey standing
--                on it. Its Heat part is the invisible area that burns and carries the flames and light;
--                parts named Glow light up. Attributes: Offset (seconds into the cycle it starts at) and
--                Round (true: only the circle inside Heat burns; otherwise the whole box).
--
-- How often, how fast and how hard is in Config.Hazards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Track = require(script.Parent.Track)
local PowerUps = require(script.Parent.PowerUps)
local Sfx = require(script.Parent.Sfx)

local pumpkinSettings = Config.Hazards.Pumpkin
local burnerSettings = Config.Hazards.Burner

local Hazards = {}

local DROP_HEIGHT, DROP_SECONDS, FADE_SECONDS = 8, 0.35, 0.4
local COLORS = { Color3.fromRGB(240, 130, 30), Color3.fromRGB(225, 110, 25), Color3.fromRGB(250, 155, 45) }
local WARM_COLOR, HOT_COLOR = Color3.fromRGB(190, 75, 30), Color3.fromRGB(255, 75, 20)

local racers = {}
local rollers = {} -- { from, to, sign, nextAt }
local pumpkins = {} -- { model, parts, offsets, s, to, sign, radius, lateral, angle, born, fadeStart?, hit }
local burners = {} -- { heat, glows, offset, round, flames?, light?, state, hit }
local burnersStart = 0
local connection: RBXScriptConnection?

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function effectPart(props, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- Rolling pumpkins ------------------------------------------------------------------------------------

local function spawnPumpkin(roller)
	local size = pumpkinSettings.Size
	local color = COLORS[math.random(#COLORS)]
	local model = Instance.new("Model")
	model.Name = "RollingPumpkin"

	-- A ball with three darker ribs through the stem, so you can see it roll.
	local parts = { effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, Color = color }, model) }
	local offsets = { CFrame.identity }
	local ribColor = color:Lerp(Color3.fromRGB(110, 45, 10), 0.5)
	for i = 0, 2 do
		table.insert(parts, effectPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, size * 1.02, size * 1.02), Color = ribColor }, model))
		table.insert(offsets, CFrame.Angles(0, i * math.pi / 3, 0))
	end
	table.insert(parts, effectPart({ Size = Vector3.new(0.9, 1.8, 0.9), Color = Color3.fromRGB(95, 110, 40) }, model))
	table.insert(offsets, CFrame.new(0, size / 2 + 0.6, 0))
	model.Parent = workspace

	local maxLateral = math.max(0, Track.LaneWidth / 2 - size / 2 - 2)
	table.insert(pumpkins, {
		model = model,
		parts = parts,
		offsets = offsets,
		s = roller.from,
		to = roller.to,
		sign = roller.sign,
		radius = size / 2,
		lateral = (math.random() * 2 - 1) * maxLateral,
		angle = 0,
		born = os.clock(),
		hit = {},
	})
end

-- Moves a pumpkin's parts to where it is now; returns its center and the way it's rolling.
local function place(p, now: number): (Vector3, Vector3)
	local center, pathDir = Track.pointAt(p.s)
	local side = pathDir:Cross(Vector3.yAxis)
	local drop = math.max(0, 1 - (now - p.born) / DROP_SECONDS) * DROP_HEIGHT
	local pos = center + side * p.lateral + Vector3.new(0, p.radius + drop, 0)
	local rollDir = pathDir * p.sign
	-- Turning about the sideways axis, top first, is what rolling forward looks like.
	local base = CFrame.lookAt(pos, pos + rollDir) * CFrame.Angles(-p.angle, 0, 0)
	local cframes = table.create(#p.parts)
	for i, offset in p.offsets do
		cframes[i] = base * offset
	end
	workspace:BulkMoveTo(p.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	return pos, rollDir
end

local function checkHits(p, pos: Vector3, rollDir: Vector3)
	for player, r in racers do
		if p.hit[player] or r.finishTime or r.cooked then
			continue
		end
		local root = rootOf(player)
		if not root then
			continue
		end
		local offset = root.Position - pos
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude < p.radius + 1.5 and math.abs(offset.Y) < p.radius + 2.5 then
			p.hit[player] = true
			-- Bowled back down the hill, and a little off to the side it was hit on.
			local away = if flat.Magnitude > 0.1 then flat.Unit else rollDir
			local velocity = rollDir * pumpkinSettings.Push + away * 15 + Vector3.new(0, pumpkinSettings.Lift, 0)
			if PowerUps.hit(player, velocity, pumpkinSettings.StunSeconds, "🎃 SQUASHED by a rolling pumpkin!") then
				Sfx.all("PumpkinHit", root.Position)
			end
		end
	end
end

local function updatePumpkins(now: number, dt: number)
	for _, roller in rollers do
		if now >= roller.nextAt then
			roller.nextAt = now + pumpkinSettings.Interval * (0.7 + math.random() * 0.6)
			spawnPumpkin(roller)
		end
	end

	for i = #pumpkins, 1, -1 do
		local p = pumpkins[i]
		if not p.fadeStart and now - p.born >= DROP_SECONDS then
			local step = pumpkinSettings.Speed * dt
			p.s += step * p.sign
			p.angle += step / p.radius
			if (p.to - p.s) * p.sign <= 0 then
				p.fadeStart = now
			end
		end
		local pos, rollDir = place(p, now)
		if p.fadeStart then
			local fade = (now - p.fadeStart) / FADE_SECONDS
			if fade >= 1 then
				p.model:Destroy()
				table.remove(pumpkins, i)
				continue
			end
			for _, part in p.parts do
				part.Transparency = fade
			end
		else
			checkHits(p, pos, rollDir)
		end
	end
end

-- Burners ---------------------------------------------------------------------------------------------

local function setBurner(b, state: string)
	if b.state == state then
		return
	end
	b.state = state
	for _, glow in b.glows do
		if state == "Cool" then
			glow.part.Color, glow.part.Material = glow.color, glow.material
		else
			glow.part.Color = if state == "Hot" then HOT_COLOR else WARM_COLOR
			glow.part.Material = Enum.Material.Neon
		end
	end
	if b.flames then
		b.flames.Enabled = state == "Hot"
	end
	if b.light then
		b.light.Enabled = state ~= "Cool"
		b.light.Brightness = if state == "Hot" then 4 else 1.5
	end
	if state == "Hot" then
		table.clear(b.hit)
	end
end

local function burnerState(b, now: number): string
	local t = (now - burnersStart + b.offset) % (burnerSettings.CoolSeconds + burnerSettings.WarnSeconds + burnerSettings.HotSeconds)
	if t < burnerSettings.CoolSeconds then
		return "Cool"
	end
	return if t < burnerSettings.CoolSeconds + burnerSettings.WarnSeconds then "Warm" else "Hot"
end

-- Standing on it (the rider sits RideHeight up), or close enough above it to feel the heat. Jumping clears it.
local function onBurner(b, position: Vector3): boolean
	local rel = b.heat.CFrame:PointToObjectSpace(position)
	local half = b.heat.Size / 2
	if rel.Y < -half.Y - 1 or rel.Y > half.Y + Config.Movement.RideHeight + 1.5 then
		return false
	end
	if b.round then
		return Vector2.new(rel.X, rel.Z).Magnitude < half.X + 1
	end
	return math.abs(rel.X) < half.X + 1 and math.abs(rel.Z) < half.Z + 1
end

local function burn(b, player: Player, root: BasePart)
	b.hit[player] = true
	-- A round burner throws you off the nearest side; a long griddle throws you back the way you came.
	local _, pathDir = Track.pointAt(Track.distanceAt(root.Position))
	local offset = root.Position - b.heat.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local away = if b.round and flat.Magnitude > 0.5 then flat.Unit else -pathDir
	local velocity = away * burnerSettings.Push + Vector3.new(0, burnerSettings.Lift, 0)
	if PowerUps.hit(player, velocity, burnerSettings.StunSeconds, "🔥 HOT HOT HOT! Watch the glowing burners!") then
		Sfx.all("Sizzle", root.Position)
	end
end

local function updateBurners(now: number)
	for _, b in burners do
		setBurner(b, burnerState(b, now))
		if b.state ~= "Hot" then
			continue
		end
		for player, r in racers do
			if b.hit[player] or r.finishTime or r.cooked then
				continue
			end
			local root = rootOf(player)
			if root and onBurner(b, root.Position) then
				burn(b, player, root)
			end
		end
	end
end

local function loadBurner(model: Instance)
	local heat = model:FindFirstChild("Heat") :: BasePart
	local glows = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Glow" then
			table.insert(glows, { part = part, color = part.Color, material = part.Material })
		end
	end
	table.insert(burners, {
		heat = heat,
		glows = glows,
		offset = model:GetAttribute("Offset") or 0,
		round = model:GetAttribute("Round") == true,
		flames = heat:FindFirstChildOfClass("ParticleEmitter"),
		light = heat:FindFirstChildWhichIsA("Light"),
		state = "Cool",
		hit = {},
	})
end

-- Race hooks ------------------------------------------------------------------------------------------

function Hazards.begin(raceRacers)
	racers = raceRacers
	local folder = Track.Folder:FindFirstChild("Hazards")
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		if child.Name == "PumpkinRoll" then
			local from = Track.distanceAt(child.Start.Position)
			local to = Track.distanceAt(child.End.Position)
			table.insert(rollers, { from = from, to = to, sign = if to >= from then 1 else -1, nextAt = os.clock() })
		elseif child.Name == "Burner" then
			loadBurner(child)
		end
	end
	burnersStart = os.clock()
	if #rollers > 0 or #burners > 0 then
		connection = RunService.Heartbeat:Connect(function(dt)
			local now = os.clock()
			updatePumpkins(now, dt)
			updateBurners(now)
		end)
	end
end

function Hazards.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for _, p in pumpkins do
		p.model:Destroy()
	end
	for _, b in burners do
		setBurner(b, "Cool")
	end
	table.clear(pumpkins)
	table.clear(rollers)
	table.clear(burners)
end

return Hazards
