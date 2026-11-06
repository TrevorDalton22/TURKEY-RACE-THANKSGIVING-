-- Brings the turkeys to life on this screen: your avatar holds a riding pose, and every turkey's bones run,
-- bob, peck and flap. The legs run with the turkey's speed, the neck pecks and the snood and wattle wobble, the eyes
-- wander in different directions, the wings flap in the air, and the tail fan folds back as it speeds up so it
-- doesn't block the camera. Gobbling opens the beak. All of it is local animation of the rig from
-- shared/TurkeyModel, so nothing here changes the game.
--
-- Each pose below is a rotation in the mesh's own axes (-Z forward, +Y up, -X the turkey's left), so it reads the
-- same whichever way a bone happens to point. In those axes, around X a positive angle swings a leg forward and
-- tips the head back, and around Z a positive angle raises something on the right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local Riding = {}

-- Roblox's own sitting animations.
local SIT_ANIMATION = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://2506281703",
	[Enum.HumanoidRigType.R6] = "rbxassetid://178130996",
}
local BONES = {
	"Root", "Body", "Neck", "Head", "Eye_L", "Eye_R", "Beak_Lower", "Snood", "Wattle", "Wing_L", "Wing_R", "Tail",
	"Thigh_L", "Shank_L", "Foot_L", "Thigh_R", "Shank_R", "Foot_R",
}
-- The tail's big feathers, and how far each sits from the middle of the fan.
local FEATHERS = 11
local FEATHER_SPREAD = math.rad(16.8)
-- Turkeys further from the camera than this aren't worth animating.
local ANIMATE_DISTANCE = 220

local sin, cos, abs, clamp, max = math.sin, math.cos, math.abs, math.clamp, math.max
local angles = CFrame.Angles

-- Per turkey: its bones with their resting poses, the running cycle and the dust emitter. Weak keys, so turkeys
-- that are replaced or leave are forgotten.
local states: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any
-- When a player's turkey was last told to gobble.
local gobbles: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function entryFor(mesh: BasePart, name: string)
	local bone = mesh:FindFirstChild(name, true)
	if not bone or not bone:IsA("Bone") then
		return nil
	end
	-- WorldCFrame is always the resting pose, whatever the bone's Transform is.
	local rest = mesh.CFrame:ToObjectSpace(bone.WorldCFrame)
	return { bone = bone, rest = rest.Rotation, inverse = rest.Rotation:Inverse(), pivot = rest.Position }
end

local function stateFor(mount: Model)
	local mesh = mount:FindFirstChild("Turkey") :: BasePart?
	if not mesh then
		return nil
	end
	local state = states[mount]
	if state and state.mesh == mesh then
		return state
	end
	local bones, feathers = {}, {}
	for _, name in BONES do
		bones[name] = entryFor(mesh, name)
		if not bones[name] then
			return nil -- still arriving
		end
	end
	for i = 1, FEATHERS do
		feathers[i] = entryFor(mesh, string.format("TailFeather_%02d", i))
		if not feathers[i] then
			return nil
		end
	end

	local attachment = Instance.new("Attachment")
	attachment.Position = bones.Root.pivot + Vector3.new(0, 0.4, 1)
	attachment.Parent = mesh
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(225, 200, 165))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3.2) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(1, 3)
	dust.SpreadAngle = Vector2.new(50, 50)
	dust.Acceleration = Vector3.new(0, 3, 0)
	dust.Rate = 0
	dust.Parent = attachment

	local head = mount:FindFirstChild("JointHead")
	state = {
		mesh = mesh,
		bones = bones,
		feathers = feathers,
		dust = dust,
		headWeld = head and head:FindFirstChild("Head"),
		phase = 0,
		fold = 0,
		featherFold = -1,
		seed = (#mount:GetFullName() % 7) * 1.3,
	}
	states[mount] = state
	return state
end

-- Poses a bone: q is a rotation in the mesh's axes, offset a move in them.
local function pose(entry, q: CFrame, offset: Vector3?)
	local transform = entry.inverse * q * entry.rest
	if offset then
		transform = CFrame.new(entry.inverse:VectorToWorldSpace(offset)) * transform
	end
	entry.bone.Transform = transform
end

-- The same rotation as a move of the whole mesh, for working out where the head ended up.
local function around(pivot: Vector3, q: CFrame): CFrame
	return CFrame.new(pivot) * q * CFrame.new(-pivot)
end

local function animate(mount: Model, state, velocity: Vector3, dt: number, now: number)
	local bones = state.bones
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local airborne = abs(velocity.Y) > 4
	local stride = clamp(speed / 30, 0, 1)
	local still = 1 - stride
	state.phase += dt * speed * 0.24
	local p = state.phase
	local t = now + state.seed

	-- Legs: each swings forward with its knee bent, then pushes back straight, with the foot kept fairly level.
	local function leg(thigh, shank, foot, phase: number)
		if airborne then
			pose(thigh, angles(0.95, 0, 0))
			pose(shank, angles(-1.35, 0, 0))
			pose(foot, angles(0.5, 0, 0))
		else
			local swing = sin(phase) * 0.85 * stride
			local bend = -(0.15 + 1.0 * max(0, cos(phase))) * stride
			pose(thigh, angles(swing, 0, 0))
			pose(shank, angles(bend, 0, 0))
			pose(foot, angles(-(swing + bend) * 0.75, 0, 0))
		end
	end
	leg(bones.Thigh_L, bones.Shank_L, bones.Foot_L, p)
	leg(bones.Thigh_R, bones.Shank_R, bones.Foot_R, p + math.pi)

	-- A bounce on every step, a waddle from side to side, and a lean into the run.
	local bob = if airborne then 0 else abs(sin(p)) * 0.28 * stride
	local breathe = sin(t * 1.7) * 0.012 * still
	local bodyTurn = angles(-0.07 * stride + (if airborne then -0.1 else 0) + breathe, 0, sin(p) * 0.06 * stride)
	pose(bones.Body, bodyTurn, Vector3.new(0, bob, 0))

	-- The neck pecks forward twice a stride; the head rights itself, and looks around when standing still.
	local gobbling = now < (gobbles[mount] or 0)
	local neckAngle = -0.1 * stride - abs(sin(p)) * 0.2 * stride + sin(t * 1.7) * 0.02 * still
	if gobbling then
		neckAngle -= 0.25 + sin(now * 30) * 0.08
	end
	local neckTurn = angles(neckAngle, 0, 0)
	pose(bones.Neck, neckTurn)
	local headTurn = angles(-neckAngle * 0.7 + sin(t * 1.3) * 0.07 * still, sin(t * 0.6) * 0.4 * still, sin(p * 0.5) * 0.06 * stride)
	pose(bones.Head, headTurn)

	-- Googly eyes, each wandering its own way.
	local wobble = 0.05 + 0.2 * stride
	pose(bones.Eye_L, angles(sin(p * 1.9 + t * 1.1) * wobble, sin(p * 1.3 + t * 0.7) * wobble, 0))
	pose(bones.Eye_R, angles(sin(p * 1.5 + t * 0.9 + 2) * wobble, sin(p * 2.1 + t * 1.3 + 1) * wobble, 0))

	-- The beak chatters at a run and opens wide to gobble.
	local jaw = if gobbling then 0.3 + abs(sin(now * 26)) * 0.4 else max(0, sin(p * 2)) * 0.16 * stride
	pose(bones.Beak_Lower, angles(-jaw, 0, 0))

	-- The floppy bits lag behind everything else.
	pose(bones.Snood, angles(sin(p * 2 + 1) * 0.35 * stride + sin(t * 2) * 0.03, 0, sin(p + 1) * 0.28 * stride))
	pose(bones.Wattle, angles(sin(p * 2 + 2) * 0.3 * stride + sin(t * 2.3) * 0.03, 0, sin(p + 2) * 0.22 * stride))

	-- Wings flap hard in the air and flutter at a run.
	local flap = if airborne then (sin(now * 22) * 0.5 + 0.5) * 1.15 else 0.08 * stride + sin(p * 2) * 0.2 * stride
	pose(bones.Wing_L, angles(0, -flap * 0.7, -flap))
	pose(bones.Wing_R, angles(0, flap * 0.7, flap))

	-- The fan stands proud when slow, and folds back and narrows at speed.
	state.fold += (clamp((speed - 14) / 22, 0, 1) - state.fold) * math.min(1, dt * 6)
	pose(bones.Tail, angles(state.fold * 1.05 + sin(t * 1.1) * 0.015 * still, sin(p) * 0.07 * stride, 0))
	if abs(state.fold - state.featherFold) > 0.003 then
		state.featherFold = state.fold
		local closing = state.fold * 0.55
		for i, feather in state.feathers do
			pose(feather, angles(0, 0, -(i - (FEATHERS + 1) / 2) * FEATHER_SPREAD * closing))
		end
	end

	-- Hats follow the head.
	if state.headWeld then
		state.headWeld.C0 = CFrame.new(0, bob, 0)
			* around(bones.Body.pivot, bodyTurn)
			* around(bones.Neck.pivot, neckTurn)
			* around(bones.Head.pivot, headTurn)
	end

	state.dust.Rate = if airborne or speed < 20 then 0 else speed * 0.6
end

-- Holds your avatar in a sitting pose; it plays above the walking animations, and Roblox shares it with
-- everyone else. Roblox's own animation script stops every animation when it starts up (just after the
-- character spawns), so the pose is started again whenever it isn't playing.
local sitTrack: AnimationTrack? = nil
local sitAnimator: Animator? = nil
local lastSitCheck = 0

local function keepSitting()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or not character:IsDescendantOf(workspace) then
		return
	end
	if sitTrack and sitTrack.IsPlaying and sitAnimator == animator then
		return
	end
	if sitTrack then
		sitTrack:Destroy()
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = SIT_ANIMATION[humanoid.RigType]
	sitAnimator = animator
	sitTrack = animator:LoadAnimation(animation)
	sitTrack.Priority = Enum.AnimationPriority.Action4
	sitTrack.Looped = true
	sitTrack:Play(0.2)
end

function Riding.start()
	-- A gobble arrives as a sound played on the gobbling turkey's rider.
	Remotes.Sound.OnClientEvent:Connect(function(name: string, where)
		if name == "Gobble" and typeof(where) == "Instance" then
			local mount = where.Parent and where.Parent:FindFirstChild("TurkeyMount")
			if mount then
				gobbles[mount] = os.clock() + 0.7
			end
		end
	end)

	-- After Roblox's animation step, which resets every bone in a character, and before this frame's physics;
	-- what's set here is what the next render draws.
	RunService.PreSimulation:Connect(function(dt)
		local now = os.clock()
		if now - lastSitCheck > 0.5 then
			lastSitCheck = now
			keepSitting()
		end
		local camera = workspace.CurrentCamera.CFrame.Position
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local mount = character and character:FindFirstChild("TurkeyMount")
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if mount and root and (root.Position - camera).Magnitude < ANIMATE_DISTANCE then
				local state = stateFor(mount :: Model)
				if state then
					animate(mount :: Model, state, root.AssemblyLinearVelocity, dt, now)
				end
			end
		end
	end)
end

return Riding
