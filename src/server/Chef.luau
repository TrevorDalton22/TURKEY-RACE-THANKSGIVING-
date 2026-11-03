-- The giant angry chef: chases the pack along the track and swats turkeys with a frying pan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Track = require(script.Parent.Track)

local Remotes = ReplicatedStorage.Remotes
local settings = Config.Chef

local Chef = {}

local SHOULDER = CFrame.new(9.5, 25, 0)
local IDLE_ANGLE, WINDUP_ANGLE, SLAM_ANGLE = math.rad(130), math.rad(165), math.rad(35)
local WINDUP_TIME, SLAM_TIME, RECOVER_TIME = 0.15, 0.3, 0.9

local model: Model?
local parts, partList = {}, {}
local connection: RBXScriptConnection?

local function add(props, offset: CFrame, onArm: boolean?)
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
	p.Parent = model
	table.insert(parts, { offset = offset, arm = onArm })
	table.insert(partList, p)
end

local function build()
	model = Instance.new("Model")
	model.Name = "Chef"
	table.clear(parts)
	table.clear(partList)

	local white, black = Color3.fromRGB(245, 245, 245), Color3.fromRGB(30, 30, 35)
	local skin, brown = Color3.fromRGB(255, 205, 170), Color3.fromRGB(90, 55, 30)
	local ball, cylinder = Enum.PartType.Ball, Enum.PartType.Cylinder

	for _, x in { -3.5, 3.5 } do
		add({ Size = Vector3.new(5, 12, 5), Color = black }, CFrame.new(x, 6, 0))
	end
	add({ Size = Vector3.new(16, 14, 10), Color = white }, CFrame.new(0, 19, 0))
	add({ Size = Vector3.new(12, 10, 0.5), Color = Color3.fromRGB(230, 225, 215) }, CFrame.new(0, 17, -5.2))
	add({ Size = Vector3.new(3.5, 12, 3.5), Color = white }, CFrame.new(-9.5, 19, 0))
	add({ Shape = ball, Size = Vector3.new(11, 11, 11), Color = skin }, CFrame.new(0, 31.5, 0))
	add({ Shape = cylinder, Size = Vector3.new(8, 9, 9), Color = white }, CFrame.new(0, 40, 0) * CFrame.Angles(0, 0, math.rad(90)))
	add({ Shape = ball, Size = Vector3.new(12, 12, 12), Color = white }, CFrame.new(0, 45, 0))
	for _, side in { -1, 1 } do
		add({ Shape = ball, Size = Vector3.new(1.6, 1.6, 1.6), Color = black }, CFrame.new(side * 2, 32.5, -5))
		-- Brows slope down toward the nose so he looks furious.
		add({ Size = Vector3.new(3.5, 0.8, 0.6), Color = brown }, CFrame.new(side * 2.2, 34.3, -5.2) * CFrame.Angles(0, 0, math.rad(side * 20)))
	end
	add({ Size = Vector3.new(6, 1.5, 1), Color = brown }, CFrame.new(0, 29.8, -5.3))

	-- Arm and frying pan, posed around the shoulder. The arm hangs along -Y before rotation.
	add({ Size = Vector3.new(3.5, 12, 3.5), Color = white }, CFrame.new(0, -6, 0), true)
	add({ Size = Vector3.new(1.2, 5, 1.2), Color = black }, CFrame.new(0, -13, 0), true)
	add({ Shape = cylinder, Size = Vector3.new(1, 12, 12), Color = black, Material = Enum.Material.Metal }, CFrame.new(0, -19, 0) * CFrame.Angles(0, math.rad(90), 0), true)

	model.Parent = workspace
end

local function pose(root: CFrame, armAngle: number)
	local arm = root * SHOULDER * CFrame.Angles(armAngle, 0, 0)
	local cframes = table.create(#parts)
	for i, entry in parts do
		cframes[i] = (if entry.arm then arm else root) * entry.offset
	end
	workspace:BulkMoveTo(partList, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function armAngle(t: number?): number
	if not t or t >= RECOVER_TIME then
		return IDLE_ANGLE + math.sin(os.clock() * 3) * math.rad(8)
	elseif t < WINDUP_TIME then
		return IDLE_ANGLE + (WINDUP_ANGLE - IDLE_ANGLE) * t / WINDUP_TIME
	elseif t < SLAM_TIME then
		return WINDUP_ANGLE + (SLAM_ANGLE - WINDUP_ANGLE) * (t - WINDUP_TIME) / (SLAM_TIME - WINDUP_TIME)
	end
	return SLAM_ANGLE + (IDLE_ANGLE - SLAM_ANGLE) * (t - SLAM_TIME) / (RECOVER_TIME - SLAM_TIME)
end

-- Racers the chef can still hit, with their root parts.
local function targets(racers)
	local list = {}
	for player, r in racers do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and not r.finishTime and not r.cooked then
			table.insert(list, { player = player, r = r, root = root })
		end
	end
	return list
end

local function inReach(center: Vector3, root: BasePart, radius: number): boolean
	local offset = root.Position - center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude < radius and math.abs(offset.Y) < 15
end

function Chef.begin(racers)
	build()
	Remotes.Notify:FireAllClients("👨‍🍳 THE CHEF IS COMING! RUN!")

	-- s is the chef's distance along the loop, on the same scale as racer progress.
	local s = math.huge
	for _, t in targets(racers) do
		s = math.min(s, t.r.progress)
	end
	if s == math.huge then
		s = 0
	end
	s -= settings.SpawnBehind

	local lastHit = {}
	local swingStart: number?
	local hitApplied = false

	connection = RunService.Heartbeat:Connect(function(dt)
		local list = targets(racers)
		local last = math.huge
		for _, t in list do
			last = math.min(last, t.r.progress)
		end
		local speed = if last - s > settings.CatchUpDistance then settings.CatchUpSpeed else settings.Speed
		s += speed * dt

		local pos, dir = Track.pointAt(s)
		local bob = math.abs(math.sin(os.clock() * 6)) * 1.2
		local root = CFrame.lookAt(pos, pos + dir) + Vector3.new(0, bob, 0)
		local reachCenter = pos + dir * 10
		local now = os.clock()

		local swingT = if swingStart then now - swingStart else nil
		if swingT and swingT >= RECOVER_TIME then
			swingStart, swingT = nil, nil
		end
		if not swingStart then
			for _, t in list do
				if inReach(reachCenter, t.root, settings.HitRadius * 1.3) and now - (lastHit[t.player] or 0) > settings.HitCooldown then
					swingStart, swingT, hitApplied = now, 0, false
					break
				end
			end
		end

		if swingT and swingT >= SLAM_TIME and not hitApplied then
			hitApplied = true
			for _, t in list do
				if inReach(reachCenter, t.root, settings.HitRadius) and now - (lastHit[t.player] or 0) > settings.HitCooldown then
					lastHit[t.player] = now
					-- Fling sideways and back so a hit costs time instead of helping.
					local side = dir:Cross(Vector3.yAxis) * (if math.random() < 0.5 then -1 else 1)
					local velocity = side * 45 - dir * 20 + Vector3.new(0, 60, 0)
					Remotes.Knockback:FireClient(t.player, velocity, settings.StunSeconds)
					Remotes.Notify:FireClient(t.player, "🍳 BONK! The chef got you!")
				end
			end
		end

		pose(root, armAngle(swingT))
	end)
end

function Chef.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if model then
		model:Destroy()
		model = nil
	end
end

return Chef
