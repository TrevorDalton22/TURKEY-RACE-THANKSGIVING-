-- Puts every player on a turkey in their equipped skin. The avatar stays as it is, sitting in the saddle;
-- the turkey is welded under it, and the humanoid stands tall enough (HipHeight) for the turkey's feet
-- to reach the ground.
--
-- The turkey is a model named TurkeyMount in the character. Each group in Skins.Joints has a hidden
-- joint part (Joint<Group>) attached by a Weld named after the group: Body hangs under the root part,
-- the others hang off the body at their pivots. The visible pieces are welded to their group's joint,
-- so clients can animate the turkey just by turning those welds (client/Riding).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Skins = require(ReplicatedStorage.Shared.Skins)

local Mount = {}

-- Glitter drifting off the surface of a part (the Golden Turkey and friends).
local function sparkle(part: BasePart, color: Color3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 14
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Parent = part
end

local function newPart(name: string, props): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	return p
end

-- part1 sits at part0 * c0.
local function weld(part0: BasePart, part1: BasePart, c0: CFrame, name: string): Weld
	local w = Instance.new("Weld")
	w.Name = name
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.Parent = part1
	return w
end

-- Safe to call again on the same character: the old turkey is replaced.
local function mount(character: Model, skinId: string?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local old = character:FindFirstChild("TurkeyMount")
	if old then
		old:Destroy()
	end

	local rideHeight = Config.Movement.RideHeight
	-- R15 measures HipHeight from the ground to the bottom of the root part; R6 adds it to its usual 3 studs.
	humanoid.HipHeight = if humanoid.RigType == Enum.HumanoidRigType.R15 then rideHeight - root.Size.Y / 2 else rideHeight - 3
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Config.Movement.JumpHeight

	local model = Instance.new("Model")
	model.Name = "TurkeyMount"
	local joints: { [string]: BasePart } = {}
	for group in Skins.Joints do
		joints[group] = newPart("Joint" .. group, { Size = Vector3.one * 0.2, Transparency = 1 })
	end
	weld(root, joints.Body, CFrame.new(0, Skins.FootDepth - rideHeight, 0), "Body")
	for group, pivot in Skins.Joints do
		if group ~= "Body" then
			weld(joints.Body, joints[group], pivot, group)
		end
	end
	for _, joint in joints do
		joint.Parent = model
	end

	for _, piece in Skins.pieces(skinId) do
		local part = newPart("Piece", piece.Props)
		if piece.Mesh == "Sphere" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		weld(joints[piece.Group], part, Skins.Joints[piece.Group]:Inverse() * piece.Offset, "Weld")
		if piece.Sparkle then
			sparkle(part, piece.Sparkle)
		end
		part.Parent = model
	end
	model.Parent = character
end

function Mount.start()
	local function watch(player: Player)
		local function remount()
			if player.Character and player:HasAppearanceLoaded() then
				mount(player.Character, player:GetAttribute("Skin"))
			end
		end
		-- After the avatar loads, since loading its body scales resets HipHeight.
		player.CharacterAppearanceLoaded:Connect(function(character)
			mount(character, player:GetAttribute("Skin"))
		end)
		player:GetAttributeChangedSignal("Skin"):Connect(remount)
		remount()
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Mount
