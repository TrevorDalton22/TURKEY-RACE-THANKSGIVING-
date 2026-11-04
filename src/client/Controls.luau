-- Turkey movement: waddle, sprint on stamina, flap in mid-air, belly slide, and power-up input.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = ReplicatedStorage.Remotes
local move = Config.Movement
local player = Players.LocalPlayer

-- The HUD reads Stamina.
local Controls = { Stamina = move.StaminaMax }

local sprintHeld = false
local exhausted = false
local slideUntil, slideReadyAt = 0, 0
local stunnedUntil = 0
local stunToken = 0
local flapsLeft = move.FlapsPerJump
local lastFlap = 0

local function humanoidAndRoot(): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onSprint(_, state: Enum.UserInputState)
	sprintHeld = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Pass
end

local function onSlide(_, state: Enum.UserInputState)
	local humanoid = humanoidAndRoot()
	local now = os.clock()
	if state == Enum.UserInputState.Begin and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air and now >= slideReadyAt and now >= stunnedUntil then
		slideUntil = now + move.SlideSeconds
		slideReadyAt = now + move.SlideCooldown
	end
	return Enum.ContextActionResult.Sink
end

local function onUse(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		Remotes.UsePowerUp:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

local function onGobble(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		Remotes.Gobble:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

-- Jumping while airborne flaps the wings for an extra hop.
local function onJumpRequest()
	local humanoid, root = humanoidAndRoot()
	local now = os.clock()
	if not humanoid or not root or humanoid.FloorMaterial ~= Enum.Material.Air then
		return
	end
	if flapsLeft > 0 and now - lastFlap > 0.25 and now >= stunnedUntil then
		flapsLeft -= 1
		lastFlap = now
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, move.FlapVelocity, v.Z)
	end
end

local function onKnockback(velocity: Vector3, stun: number)
	local humanoid, root = humanoidAndRoot()
	if not humanoid or not root then
		return
	end
	stunToken += 1
	local token = stunToken
	stunnedUntil = os.clock() + stun
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
	task.delay(stun, function()
		if token == stunToken and humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function update(dt: number)
	local humanoid = humanoidAndRoot()
	if not humanoid then
		return
	end
	local now = os.clock()
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		flapsLeft = move.FlapsPerJump
	end

	-- Running dry forces a short rest before sprinting again.
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	if Controls.Stamina <= 0 then
		exhausted = true
	elseif exhausted and Controls.Stamina >= move.StaminaMax * 0.3 then
		exhausted = false
	end
	local sprinting = sprintHeld and moving and not exhausted
	if sprinting then
		Controls.Stamina = math.max(0, Controls.Stamina - move.StaminaDrain * dt)
	else
		Controls.Stamina = math.min(move.StaminaMax, Controls.Stamina + move.StaminaRegen * dt)
	end

	local speed = if now < slideUntil then move.SlideSpeed elseif sprinting then move.SprintSpeed else move.WalkSpeed
	speed *= player.Character:GetAttribute("SpeedMultiplier") or 1
	if now < stunnedUntil then
		speed = 0
	end
	humanoid.WalkSpeed = speed
end

function Controls.start()
	ContextActionService:BindAction("TurkeySprint", onSprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("TurkeySlide", onSlide, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("TurkeyUse", onUse, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("TurkeyGobble", onGobble, true, Enum.KeyCode.G, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("TurkeySprint", "Sprint")
	ContextActionService:SetTitle("TurkeySlide", "Slide")
	ContextActionService:SetTitle("TurkeyUse", "Use")
	ContextActionService:SetTitle("TurkeyGobble", "Gobble")

	UserInputService.JumpRequest:Connect(onJumpRequest)
	Remotes.Knockback.OnClientEvent:Connect(onKnockback)
	RunService.RenderStepped:Connect(update)
	player.CharacterAdded:Connect(function()
		Controls.Stamina = move.StaminaMax
		stunnedUntil = 0
	end)
end

return Controls
