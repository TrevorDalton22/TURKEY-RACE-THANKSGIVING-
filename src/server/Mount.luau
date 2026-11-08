-- Puts every player on a turkey in their equipped skin. The avatar stays as it is, sitting in the saddle;
-- the turkey is welded under it, and the humanoid stands tall enough (HipHeight) for the turkey's feet
-- to reach the ground.
--
-- The turkey is a model named TurkeyMount in the character, holding a clone of the rigged mesh from
-- shared/TurkeyModel. Clients animate its bones on their own screens (client/Riding), and hats follow the
-- head through JointHead, a hidden part on a Weld named Head whose offset those clients update.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Skins = require(ReplicatedStorage.Shared.Skins)
local TurkeyModel = require(ReplicatedStorage.Shared.TurkeyModel)

local Mount = {}

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

local function hiddenPart(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
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

	local skin = Skins.get(skinId)
	local model = Instance.new("Model")
	model.Name = "TurkeyMount"

	-- The turkey's feet are on the ground under the rider, with the saddle right below them.
	local mesh = TurkeyModel.newMesh(skin.Id)
	mesh.Anchored = false
	weld(root, mesh, CFrame.new(0, -rideHeight, -TurkeyModel.SeatBehind) * TurkeyModel.MeshInGround, "Mount")
	mesh.Parent = model

	local head = hiddenPart("JointHead", Vector3.one * 0.2)
	weld(mesh, head, CFrame.new(), "Head")
	head.Parent = model

	-- Add-ons are placed in ground space; their welds are relative to the mesh.
	local groundToMesh = TurkeyModel.MeshInGround:Inverse()
	for _, piece in Skins.pieces(skin.Id) do
		local part = TurkeyModel.newPiece(piece)
		part.Anchored = false
		weld(if piece.Group == "Head" then head else mesh, part, groundToMesh * piece.CFrame, "Weld")
		part.Parent = model
	end

	if skin.Sparkle then
		local glitter = hiddenPart("Glitter", Vector3.new(6.2, 5.4, 6.8))
		weld(mesh, glitter, groundToMesh * CFrame.new(TurkeyModel.BodyCenter), "Weld")
		TurkeyModel.addSparkle(glitter, skin.Sparkle)
		glitter.Parent = model
	end

	-- VIPs leave a golden ribbon behind their turkey.
	local player = Players:GetPlayerFromCharacter(character)
	if player and player:GetAttribute("Vip") == true then
		local tail = hiddenPart("VipTrail", Vector3.one * 0.2)
		weld(mesh, tail, groundToMesh * CFrame.new(TurkeyModel.BodyCenter + Vector3.new(0, 0, 2.6)), "Weld")
		local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
		top.Position, bottom.Position = Vector3.new(0, 1.3, 0), Vector3.new(0, -1.3, 0)
		top.Parent, bottom.Parent = tail, tail
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = top, bottom
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 212, 80), Color3.fromRGB(255, 244, 200))
		trail.Transparency = NumberSequence.new(0.15, 1)
		trail.WidthScale = NumberSequence.new(1, 0.25)
		trail.Lifetime = 0.45
		trail.MinLength = 0.1
		trail.LightEmission = 0.5
		trail.Parent = tail
		tail.Parent = model
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
		player:GetAttributeChangedSignal("Vip"):Connect(remount) -- for the VIP trail
		remount()
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Mount
