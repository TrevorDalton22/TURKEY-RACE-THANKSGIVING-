-- Map hazards that move on their own. For now: pumpkins rolling down Pumpkin Hill.
--
-- A map opts in with a Hazards folder. Each PumpkinRoll folder in it holds two marker parts on the
-- path, Start and End: pumpkins drop in at Start and roll along the lane to End (either direction),
-- flattening any turkey they run into. How often, how fast and how big is in Config.Hazards.Pumpkin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Track = require(script.Parent.Track)
local PowerUps = require(script.Parent.PowerUps)
local Sfx = require(script.Parent.Sfx)

local settings = Config.Hazards.Pumpkin

local Hazards = {}

local DROP_HEIGHT, DROP_SECONDS, FADE_SECONDS = 8, 0.35, 0.4
local COLORS = { Color3.fromRGB(240, 130, 30), Color3.fromRGB(225, 110, 25), Color3.fromRGB(250, 155, 45) }

local racers = {}
local rollers = {} -- { from, to, sign, nextAt }
local pumpkins = {} -- { model, parts, offsets, s, to, sign, radius, lateral, angle, born, fadeStart?, hit }
local connection: RBXScriptConnection?

local function effectPart(props, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function spawnPumpkin(roller)
	local size = settings.Size
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
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		local offset = root.Position - pos
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude < p.radius + 1.5 and math.abs(offset.Y) < p.radius + 2.5 then
			p.hit[player] = true
			-- Bowled back down the hill, and a little off to the side it was hit on.
			local away = if flat.Magnitude > 0.1 then flat.Unit else rollDir
			local velocity = rollDir * settings.Push + away * 15 + Vector3.new(0, settings.Lift, 0)
			if PowerUps.hit(player, velocity, settings.StunSeconds, "🎃 SQUASHED by a rolling pumpkin!") then
				Sfx.all("PumpkinHit", root.Position)
			end
		end
	end
end

local function update(dt: number)
	local now = os.clock()
	for _, roller in rollers do
		if now >= roller.nextAt then
			roller.nextAt = now + settings.Interval * (0.7 + math.random() * 0.6)
			spawnPumpkin(roller)
		end
	end

	for i = #pumpkins, 1, -1 do
		local p = pumpkins[i]
		if not p.fadeStart and now - p.born >= DROP_SECONDS then
			local step = settings.Speed * dt
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

function Hazards.begin(raceRacers)
	racers = raceRacers
	local folder = Track.Folder:FindFirstChild("Hazards")
	if not folder then
		return
	end
	for _, roll in folder:GetChildren() do
		if roll.Name == "PumpkinRoll" then
			local from = Track.distanceAt(roll.Start.Position)
			local to = Track.distanceAt(roll.End.Position)
			table.insert(rollers, { from = from, to = to, sign = if to >= from then 1 else -1, nextAt = os.clock() })
		end
	end
	if #rollers > 0 then
		connection = RunService.Heartbeat:Connect(update)
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
	table.clear(pumpkins)
	table.clear(rollers)
end

return Hazards
