-- Item boxes and the six power-ups: Drumstick Dash, Pie Launcher, Butter Slide,
-- Gobble Bomb, Mashed Potato Shield and Corn Tornado.
-- Every attack goes through PowerUps.hit, so a potato shield can block anything, the chef included.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Track = require(script.Parent.Track)
local Sfx = require(script.Parent.Sfx)

local Remotes = ReplicatedStorage.Remotes
local defs = Config.PowerUps
local KINDS = { "DrumstickDash", "PieLauncher", "ButterSlide", "GobbleBomb", "MashedPotatoShield", "CornTornado" }

-- Tornadoes stay on the table: the strips are 70 studs wide.
local TORNADO_LATERAL_LIMIT = 30
local TORNADO_STEER_SPEED = 30

local PowerUps = {}

local racers = {}
local connections = {}
local pies = {} -- { part, dir, traveled, owner, target? }
local butters = {} -- { part, owner, placedAt }
local tornadoes = {} -- { model, parts, ringCount, s, lateral, angle, expires, owner, caught }
local shields = {} -- [player] = { part, expires }
local effects = {} -- [character] = { [id] = multiplier }
local nextEffectId = 0

local function rootOf(player: Player): BasePart?
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function activeRoot(player: Player): BasePart?
	local r = racers[player]
	if not r or r.finishTime or r.cooked then
		return nil
	end
	return rootOf(player)
end

local function refreshSpeed(character: Model)
	local product = 1
	for _, multiplier in effects[character] or {} do
		product *= multiplier
	end
	character:SetAttribute("SpeedMultiplier", product)
end

-- Timed speed change. Each effect removes only itself, so overlapping effects stack correctly.
local function applySpeed(player: Player, multiplier: number, seconds: number)
	local character = player.Character
	if not character then
		return
	end
	nextEffectId += 1
	local id = nextEffectId
	effects[character] = effects[character] or {}
	effects[character][id] = multiplier
	refreshSpeed(character)
	task.delay(seconds, function()
		local list = effects[character]
		if list and list[id] then
			list[id] = nil
			refreshSpeed(character)
		end
	end)
end

local function removeShield(player: Player)
	local shield = shields[player]
	if shield then
		shield.part:Destroy()
		shields[player] = nil
	end
end

-- Lands an attack unless a potato shield soaks it up. Returns whether it landed.
-- spin: a yaw speed to spin in place instead of tumbling.
function PowerUps.hit(player: Player, velocity: Vector3, stun: number, message: string, spin: number?): boolean
	local shield = shields[player]
	if shield and shield.part.Parent then
		removeShield(player)
		Remotes.Notify:FireClient(player, "🥔 Your potato shield blocked it!")
		local root = rootOf(player)
		if root then
			Sfx.all("ShieldPop", root.Position)
		end
		return false
	end
	Remotes.Knockback:FireClient(player, velocity, stun, spin)
	Remotes.Notify:FireClient(player, message)
	return true
end

local function setBox(box: BasePart, active: boolean)
	box:SetAttribute("Active", active)
	box.Transparency = if active then 0.15 else 1
	box:FindFirstChildOfClass("BillboardGui").Enabled = active
end

local function floorBelow(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Track }
	local hit = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), params)
	return if hit then hit.Position else Vector3.new(position.X, Track.SurfaceY, position.Z)
end

-- An anchored, non-colliding effect part.
local function effectPart(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	return p
end

local use = {}

function use.DrumstickDash(player: Player, root: BasePart)
	local def = defs.DrumstickDash
	applySpeed(player, def.Multiplier, def.Seconds)
	Remotes.Notify:FireClient(player, "🍗 DRUMSTICK DASH!")
	Sfx.all("Dash", root)
end

function use.PieLauncher(player: Player, root: BasePart)
	local look = root.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z).Unit

	-- Lock on to the closest racer roughly in front, if there is one.
	local target, best = nil, defs.PieLauncher.Range
	for other in racers do
		local otherRoot = other ~= player and activeRoot(other)
		if otherRoot then
			local offset = otherRoot.Position - root.Position
			if offset.Magnitude < best and offset.Unit:Dot(dir) > 0.6 then
				target, best = other, offset.Magnitude
			end
		end
	end

	local pie = effectPart({
		Name = "Pie",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 3, 3),
		Color = Color3.fromRGB(215, 150, 70),
		CFrame = CFrame.new(root.Position + dir * 4 + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	pie.Parent = workspace
	table.insert(pies, { part = pie, dir = dir, traveled = 0, owner = player, target = target })
	Sfx.all("Throw", root.Position)
end

function use.ButterSlide(player: Player, root: BasePart)
	local look = root.CFrame.LookVector
	local spot = floorBelow(root.Position - Vector3.new(look.X, 0, look.Z).Unit * 6)
	local butter = effectPart({
		Name = "Butter",
		Size = Vector3.new(4, 1, 3),
		Color = Color3.fromRGB(255, 230, 110),
		Position = spot + Vector3.new(0, 0.5, 0),
	})
	butter.Parent = workspace
	table.insert(butters, { part = butter, owner = player, placedAt = os.clock() })
end

function use.GobbleBomb(player: Player, root: BasePart)
	local def = defs.GobbleBomb
	for other in racers do
		local otherRoot = other ~= player and activeRoot(other)
		if otherRoot then
			local offset = otherRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude < def.Radius and math.abs(offset.Y) < 10 then
				local away = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
				PowerUps.hit(other, away * def.Push + Vector3.new(0, def.Lift, 0), def.StunSeconds, `💥 {player.DisplayName}'s GOBBLE BOMB!`)
			end
		end
	end

	-- A shockwave that grows to the blast radius and fades.
	local wave = effectPart({
		Name = "GobbleWave",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		Color = Color3.fromRGB(255, 150, 40),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		Position = root.Position,
	})
	wave.Parent = workspace
	TweenService:Create(wave, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * def.Radius * 2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(wave, 0.5)

	Remotes.Notify:FireClient(player, "💥 GOBBLE BOMB!")
	Sfx.all("Boom", root.Position)
	Sfx.gobble(player)
end

function use.MashedPotatoShield(player: Player, root: BasePart)
	removeShield(player)
	local bubble = effectPart({
		Name = "PotatoShield",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 10,
		Color = Color3.fromRGB(245, 235, 195),
		Transparency = 0.55,
		Anchored = false,
		Massless = true,
		CFrame = root.CFrame + Vector3.new(0, 1, 0),
	})
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bubble
	weld.Parent = bubble
	bubble.Parent = player.Character
	shields[player] = { part = bubble, expires = os.clock() + defs.MashedPotatoShield.Seconds }
	Remotes.Notify:FireClient(player, "🥔 Potato shield! It blocks the next hit")
	Sfx.all("ShieldUp", root)
end

local function placeTornado(t, pos: Vector3)
	local cframes = table.create(#t.parts)
	for i = 1, t.ringCount do
		-- Each ring sways a little out of step with the others, so the funnel looks like it's twisting.
		local sway = Vector3.new(math.sin(t.angle * 0.7 + i), 0, math.cos(t.angle * 0.7 + i)) * 0.5
		cframes[i] = CFrame.new(pos + sway + Vector3.new(0, 0.9 + (i - 1) * 1.8, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	end
	local kernelCount = #t.parts - t.ringCount
	for j = 1, kernelCount do
		local a = t.angle + j * (math.pi * 2 / kernelCount)
		local height = 1 + (j % 4) * 2
		local radius = 1.5 + height * 0.45
		cframes[t.ringCount + j] = CFrame.new(pos + Vector3.new(math.cos(a) * radius, height, math.sin(a) * radius))
	end
	workspace:BulkMoveTo(t.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function use.CornTornado(player: Player, root: BasePart)
	local def = defs.CornTornado
	local s = Track.distanceAt(root.Position)
	local center, dir = Track.pointAt(s)
	local side = dir:Cross(Vector3.yAxis)

	local model = Instance.new("Model")
	model.Name = "CornTornado"
	local parts = {}
	-- A funnel of husk-green and corn-yellow rings, widest at the top...
	for i = 1, 5 do
		local width = 2 + i * 1.5
		table.insert(parts, effectPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.8, width, width),
			Color = if i % 2 == 0 then Color3.fromRGB(245, 210, 70) else Color3.fromRGB(130, 175, 70),
			Transparency = 0.3,
		}))
	end
	-- ...with kernels whirling around it.
	for _ = 1, 8 do
		table.insert(parts, effectPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			Color = Color3.fromRGB(255, 220, 60),
		}))
	end
	for _, part in parts do
		part.Parent = model
	end

	local t = {
		model = model,
		parts = parts,
		ringCount = 5,
		s = s + 10,
		lateral = math.clamp((root.Position - center):Dot(side), -TORNADO_LATERAL_LIMIT, TORNADO_LATERAL_LIMIT),
		angle = 0,
		expires = os.clock() + def.Seconds,
		owner = player,
		caught = {},
	}
	model.Parent = workspace
	local startCenter, startDir = Track.pointAt(t.s)
	placeTornado(t, startCenter + startDir:Cross(Vector3.yAxis) * t.lateral)
	table.insert(tornadoes, t)

	Remotes.Notify:FireClient(player, "🌪️ CORN TORNADO!")
	Sfx.all("Tornado", parts[1])
end

local function updateBoxes()
	for player in racers do
		local root = activeRoot(player)
		if root and (player:GetAttribute("PowerUp") or "") == "" then
			for _, box in Track.ItemBoxes do
				if box:GetAttribute("Active") and (box.Position - root.Position).Magnitude < 6 then
					local kind = KINDS[math.random(#KINDS)]
					player:SetAttribute("PowerUp", kind)
					Remotes.Notify:FireClient(player, `{defs[kind].Icon} Got {defs[kind].Name}! Press E`)
					Sfx.to(player, "Pickup")
					setBox(box, false)
					task.delay(Config.ItemBoxRespawnSeconds, setBox, box, true)
					break
				end
			end
		end
	end
end

local function updatePies(dt: number)
	local def = defs.PieLauncher
	for i = #pies, 1, -1 do
		local pie = pies[i]
		local targetRoot = pie.target and activeRoot(pie.target)
		if targetRoot then
			local toTarget = targetRoot.Position - pie.part.Position
			pie.dir = (pie.dir + Vector3.new(toTarget.X, 0, toTarget.Z).Unit * dt * 3).Unit
		end
		local step = def.Speed * dt
		pie.traveled += step
		pie.part.CFrame += pie.dir * step

		local victim = nil
		for other in racers do
			local otherRoot = other ~= pie.owner and activeRoot(other)
			if otherRoot and (otherRoot.Position - pie.part.Position).Magnitude < 5 then
				victim = other
				break
			end
		end
		if victim then
			if PowerUps.hit(victim, pie.dir * 10 + Vector3.new(0, 25, 0), 0.4, "🥧 SPLAT! Pie to the face!") then
				applySpeed(victim, def.SlowMultiplier, def.SlowSeconds)
				Remotes.Notify:FireClient(pie.owner, `🥧 Direct hit on {victim.DisplayName}!`)
			else
				Remotes.Notify:FireClient(pie.owner, `🥔 {victim.DisplayName}'s shield blocked your pie!`)
			end
			Sfx.all("Splat", pie.part.Position)
		end
		if victim or pie.traveled > def.Range then
			pie.part:Destroy()
			table.remove(pies, i)
		end
	end
end

local function updateButters()
	local def = defs.ButterSlide
	local now = os.clock()
	for i = #butters, 1, -1 do
		local butter = butters[i]
		local slipped = false
		for player in racers do
			local root = activeRoot(player)
			-- The owner gets a moment to waddle clear of their own butter.
			if root and (player ~= butter.owner or now - butter.placedAt > 1.5) then
				local offset = root.Position - butter.part.Position
				if Vector3.new(offset.X, 0, offset.Z).Magnitude < 4.5 and math.abs(offset.Y) < 5 then
					local angle = math.random() * math.pi * 2
					local spin = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 30 + Vector3.new(0, 20, 0)
					if PowerUps.hit(player, spin, def.StunSeconds, "🧈 Slipped on butter!") then
						Sfx.all("Slip", root.Position)
					end
					slipped = true
					break
				end
			end
		end
		if slipped or now - butter.placedAt > def.Lifetime then
			butter.part:Destroy()
			table.remove(butters, i)
		end
	end
end

local function updateTornadoes(dt: number)
	local def = defs.CornTornado
	local now = os.clock()
	for i = #tornadoes, 1, -1 do
		local t = tornadoes[i]
		t.s += def.Speed * dt
		t.angle += dt * 10
		local center, dir = Track.pointAt(t.s)
		local side = dir:Cross(Vector3.yAxis)
		local pos = center + side * t.lateral

		-- Drift sideways toward the nearest turkey ahead that it hasn't caught yet.
		local target, bestDistance = nil, 60
		for other in racers do
			local otherRoot = other ~= t.owner and not t.caught[other] and activeRoot(other)
			if otherRoot then
				local offset = otherRoot.Position - pos
				if offset:Dot(dir) > -4 and offset.Magnitude < bestDistance then
					target, bestDistance = otherRoot, offset.Magnitude
				end
			end
		end
		if target then
			local want = math.clamp((target.Position - center):Dot(side), -TORNADO_LATERAL_LIMIT, TORNADO_LATERAL_LIMIT)
			local step = TORNADO_STEER_SPEED * dt
			t.lateral += math.clamp(want - t.lateral, -step, step)
			pos = center + side * t.lateral
		end
		placeTornado(t, pos)

		for other in racers do
			local otherRoot = other ~= t.owner and not t.caught[other] and activeRoot(other)
			if otherRoot then
				local offset = otherRoot.Position - pos
				if Vector3.new(offset.X, 0, offset.Z).Magnitude < def.HitRadius and offset.Y > -3 and offset.Y < 12 then
					t.caught[other] = true
					if PowerUps.hit(other, Vector3.new(0, 22, 0), def.SpinSeconds, "🌪️ Caught in a CORN TORNADO!", def.SpinSpeed) then
						Sfx.all("Spin", otherRoot.Position)
					end
				end
			end
		end

		if now > t.expires then
			t.model:Destroy()
			table.remove(tornadoes, i)
		end
	end
end

local function updateShields()
	local now = os.clock()
	for player, shield in shields do
		if now > shield.expires or shield.part.Parent == nil then
			removeShield(player)
			if player.Parent and now > shield.expires then
				Remotes.Notify:FireClient(player, "🥔 Your potato shield wore off")
			end
		end
	end
end

function PowerUps.begin(raceRacers)
	racers = raceRacers
	for _, box in Track.ItemBoxes do
		setBox(box, true)
	end
	table.insert(connections, Remotes.UsePowerUp.OnServerEvent:Connect(function(player)
		local kind = player:GetAttribute("PowerUp")
		local root = activeRoot(player)
		if root and kind and use[kind] then
			player:SetAttribute("PowerUp", "")
			use[kind](player, root)
		end
	end))
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		updateBoxes()
		updatePies(dt)
		updateButters()
		updateTornadoes(dt)
		updateShields()
	end))
end

function PowerUps.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, list in { pies, butters } do
		for _, entry in list do
			entry.part:Destroy()
		end
		table.clear(list)
	end
	for _, t in tornadoes do
		t.model:Destroy()
	end
	table.clear(tornadoes)
	for player in shields do
		removeShield(player)
	end
	for character in effects do
		character:SetAttribute("SpeedMultiplier", nil)
	end
	table.clear(effects)
	for player in racers do
		player:SetAttribute("PowerUp", nil)
	end
end

return PowerUps
