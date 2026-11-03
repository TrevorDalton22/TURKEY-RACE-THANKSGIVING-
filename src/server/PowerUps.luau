-- Item boxes and the three power-ups: Drumstick Dash, Pie Launcher and Butter Slide.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Track = require(script.Parent.Track)

local Remotes = ReplicatedStorage.Remotes
local defs = Config.PowerUps
local KINDS = { "DrumstickDash", "PieLauncher", "ButterSlide" }

local PowerUps = {}

local racers = {}
local connections = {}
local pies = {} -- { part, dir, traveled, owner, target? }
local butters = {} -- { part, owner, placedAt }
local effects = {} -- [character] = { [id] = multiplier }
local nextEffectId = 0

local function activeRoot(player: Player): BasePart?
	local r = racers[player]
	if not r or r.finishTime or r.cooked then
		return nil
	end
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
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

local function knock(player: Player, velocity: Vector3, stun: number, message: string)
	Remotes.Knockback:FireClient(player, velocity, stun)
	Remotes.Notify:FireClient(player, message)
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

local use = {}

function use.DrumstickDash(player: Player)
	local def = defs.DrumstickDash
	applySpeed(player, def.Multiplier, def.Seconds)
	Remotes.Notify:FireClient(player, "🍗 DRUMSTICK DASH!")
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

	local pie = Instance.new("Part")
	pie.Name = "Pie"
	pie.Shape = Enum.PartType.Cylinder
	pie.Size = Vector3.new(0.8, 3, 3)
	pie.Color = Color3.fromRGB(215, 150, 70)
	pie.Anchored = true
	pie.CanCollide = false
	pie.CanQuery = false
	pie.CFrame = CFrame.new(root.Position + dir * 4 + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pie.Parent = workspace
	table.insert(pies, { part = pie, dir = dir, traveled = 0, owner = player, target = target })
end

function use.ButterSlide(player: Player, root: BasePart)
	local look = root.CFrame.LookVector
	local spot = floorBelow(root.Position - Vector3.new(look.X, 0, look.Z).Unit * 6)
	local butter = Instance.new("Part")
	butter.Name = "Butter"
	butter.Size = Vector3.new(4, 1, 3)
	butter.Color = Color3.fromRGB(255, 230, 110)
	butter.Material = Enum.Material.SmoothPlastic
	butter.Anchored = true
	butter.CanCollide = false
	butter.CanQuery = false
	butter.Position = spot + Vector3.new(0, 0.5, 0)
	butter.Parent = workspace
	table.insert(butters, { part = butter, owner = player, placedAt = os.clock() })
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

		local hit = nil
		for other in racers do
			local otherRoot = other ~= pie.owner and activeRoot(other)
			if otherRoot and (otherRoot.Position - pie.part.Position).Magnitude < 5 then
				hit = other
				break
			end
		end
		if hit then
			applySpeed(hit, def.SlowMultiplier, def.SlowSeconds)
			knock(hit, pie.dir * 10 + Vector3.new(0, 25, 0), 0.4, "🥧 SPLAT! Pie to the face!")
			Remotes.Notify:FireClient(pie.owner, `🥧 Direct hit on {hit.DisplayName}!`)
		end
		if hit or pie.traveled > def.Range then
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
					knock(player, spin, def.StunSeconds, "🧈 Slipped on butter!")
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
	for character in effects do
		character:SetAttribute("SpeedMultiplier", nil)
	end
	table.clear(effects)
	for player in racers do
		player:SetAttribute("PowerUp", nil)
	end
end

return PowerUps
