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

-- spin: spin in place around the up axis at this speed instead of tumbling (the Corn Tornado).
local function onKnockback(velocity: Vector3, stun: number, spin: number?)
	local humanoid, root = humanoidAndRoot()
	if not humanoid or not root then
		return
	end
	stunToken += 1
	local token = stunToken
	stunnedUntil = os.clock() + stun
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = if spin then Vector3.new(0, spin, 0) else Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
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

-- The camera starts this far back, so a rider up on their turkey fits in view (players can still zoom).
local START_ZOOM = 18

-- Pulls the camera back to START_ZOOM: raising the minimum zoom pushes it out, and lowering the minimum
-- again leaves it there.
local function zoomOut()
	player.CameraMinZoomDistance = START_ZOOM
	task.delay(0.1, function()
		player.CameraMinZoomDistance = 0.5
	end)
end

-- Swings the camera behind the turkey, keeping the player's zoom, so pressing forward runs down the track
-- whichever way the camera was facing in the lobby.
local function faceForward()
	local _, root = humanoidAndRoot()
	if not root then
		return
	end
	local camera = workspace.CurrentCamera
	local distance = math.clamp((camera.CFrame.Position - camera.Focus.Position).Magnitude, START_ZOOM, 35)
	local look = root.CFrame.LookVector
	camera.CFrame = CFrame.lookAt(root.Position - look * distance + Vector3.new(0, distance * 0.35, 0), root.Position)
end

-- For the touch buttons (client/TouchButtons).
function Controls.setSprint(held: boolean)
	sprintHeld = held
end

function Controls.slide()
	onSlide(nil, Enum.UserInputState.Begin)
end

function Controls.use()
	onUse(nil, Enum.UserInputState.Begin)
end

function Controls.gobble()
	onGobble(nil, Enum.UserInputState.Begin)
end

function Controls.start()
	-- Racers are placed on their start pads just before the countdown; give that a moment to arrive.
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		if ReplicatedStorage:GetAttribute("Phase") == "Countdown" and player:GetAttribute("Racing") then
			task.delay(0.3, faceForward)
		end
	end)

	-- Touch screens get the big buttons from client/TouchButtons instead of ContextActionService's small ones.
	local touchButtons = not UserInputService.TouchEnabled
	ContextActionService:BindAction("TurkeySprint", onSprint, touchButtons, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("TurkeySlide", onSlide, touchButtons, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("TurkeyUse", onUse, touchButtons, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("TurkeyGobble", onGobble, touchButtons, Enum.KeyCode.G, Enum.KeyCode.ButtonY)
	if touchButtons then
		ContextActionService:SetTitle("TurkeySprint", "Sprint")
		ContextActionService:SetTitle("TurkeySlide", "Slide")
		ContextActionService:SetTitle("TurkeyUse", "Use")
		ContextActionService:SetTitle("TurkeyGobble", "Gobble")
	end

	UserInputService.JumpRequest:Connect(onJumpRequest)
	Remotes.Knockback.OnClientEvent:Connect(onKnockback)
	RunService.RenderStepped:Connect(update)
	player.CharacterAdded:Connect(function()
		Controls.Stamina = move.StaminaMax
		stunnedUntil = 0
		task.delay(0.5, zoomOut)
	end)
	if player.Character then
		task.delay(0.5, zoomOut)
	end
end

return Controls
