-- Brings the turkeys to life on this screen: your avatar holds a riding pose, and every turkey's legs run,
-- its body and head bob, its wings flap in the air and dust kicks up behind it. All of it is local
-- animation of the welds server/Mount builds, so nothing here changes the game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Skins = require(ReplicatedStorage.Shared.Skins)

local player = Players.LocalPlayer

local Riding = {}

-- Roblox's own sitting animations.
local SIT_ANIMATION = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://2506281703",
	[Enum.HumanoidRigType.R6] = "rbxassetid://178130996",
}
local GROUPS = { "Body", "Head", "WingL", "WingR", "LegL", "LegR" }

-- Per turkey: its welds, their resting C0, the running cycle and the dust emitter. Weak keys, so
-- turkeys that are replaced or leave are forgotten.
local states: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any

local function stateFor(mount: Model)
	local state = states[mount]
	if state then
		return state
	end
	local welds, rest = {}, {}
	for _, group in GROUPS do
		local joint = mount:FindFirstChild("Joint" .. group)
		local weld = joint and joint:FindFirstChild(group)
		if not weld then
			return nil -- still arriving
		end
		welds[group] = weld
		rest[group] = weld.C0
	end
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, -Skins.FootDepth + 0.3, 1)
	attachment.Parent = mount:FindFirstChild("JointBody")
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(225, 200, 165))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(1, 3)
	dust.SpreadAngle = Vector2.new(50, 50)
	dust.Acceleration = Vector3.new(0, 3, 0)
	dust.Rate = 0
	dust.Parent = attachment
	state = { welds = welds, rest = rest, phase = 0, dust = dust }
	states[mount] = state
	return state
end

local function animate(character: Model, mount: Model, dt: number, now: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local state = root and stateFor(mount)
	if not state then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local airborne = math.abs(velocity.Y) > 4
	local stride = math.clamp(speed / 25, 0, 1)
	state.phase += dt * speed * 0.3
	local phase = state.phase
	local welds, rest = state.welds, state.rest

	-- Legs swing in turn; in the air they tuck back.
	local swing = if airborne then -0.7 else math.sin(phase) * 0.75 * stride
	welds.LegL.C0 = rest.LegL * CFrame.Angles(swing, 0, 0)
	welds.LegR.C0 = rest.LegR * CFrame.Angles(if airborne then swing else -swing, 0, 0)

	-- A bounce on every step, and the head pecks forward with it; standing still, it looks around.
	local bounce = if airborne then 0 else math.abs(math.sin(phase)) * 0.35 * stride
	welds.Body.C0 = rest.Body * CFrame.new(0, bounce, 0)
	if speed > 2 then
		welds.Head.C0 = rest.Head * CFrame.Angles(-math.abs(math.sin(phase)) * 0.25 * stride, 0, 0)
	else
		welds.Head.C0 = rest.Head * CFrame.Angles(math.sin(now * 1.3) * 0.08, math.sin(now * 0.6) * 0.35, 0)
	end

	-- Wings flap hard in the air and flutter while running.
	local flap = if airborne then (math.sin(now * 22) * 0.5 + 0.5) * 1.3 else 0.05 + math.sin(phase * 2) * 0.08 * stride
	welds.WingR.C0 = rest.WingR * CFrame.Angles(0, 0, flap)
	welds.WingL.C0 = rest.WingL * CFrame.Angles(0, 0, -flap)

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
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		if now - lastSitCheck > 0.5 then
			lastSitCheck = now
			keepSitting()
		end
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local mount = character and character:FindFirstChild("TurkeyMount")
			if mount then
				animate(character, mount :: Model, dt, now)
			end
		end
	end)
end

return Riding
