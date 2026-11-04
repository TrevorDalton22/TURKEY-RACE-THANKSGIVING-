-- Dresses every character as a turkey in their equipped skin: hides the avatar's body and welds on a feathered suit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = require(ReplicatedStorage.Shared.Skins)

local TurkeySuit = {}

-- Body parts each piece host maps to, for R15 and R6.
local HOSTS = {
	Torso = { "UpperTorso", "Torso" },
	Head = { "Head" },
	Wing = { "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" },
}

-- Glitter drifting off the surface of a part (the Golden Turkey).
local function sparkle(part: BasePart, color: Color3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 10
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Parent = part
end

local function attach(host: BasePart, props, offset: CFrame): BasePart
	local p = Instance.new("Part")
	p.Name = "TurkeySuit"
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.CFrame = host.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = p
	weld.Parent = p
	p.Parent = host.Parent
	return p
end

-- Safe to call again on the same character: the old suit is removed first.
local function dress(character: Model, skinId: string?)
	for _, item in character:GetChildren() do
		if item:IsA("Accessory") or item:IsA("Clothing") or item:IsA("ShirtGraphic") or item.Name == "TurkeySuit" then
			item:Destroy()
		end
	end
	local skin = Skins.get(skinId)
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			if part.Name:find("Leg") or part.Name:find("Foot") then
				part.Color = skin.Legs
				part.Transparency = skin.Transparency
			else
				part.Transparency = 1
			end
		end
	end
	local face = character:FindFirstChild("Head") and character.Head:FindFirstChildOfClass("Decal")
	if face then
		face:Destroy()
	end

	for _, piece in Skins.pieces(skin.Id) do
		for _, name in HOSTS[piece.Host] do
			local host = character:FindFirstChild(name)
			if host and host:IsA("BasePart") then
				local part = attach(host, piece.Props, piece.Offset)
				if piece.Sparkle then
					sparkle(part, piece.Sparkle)
				end
			end
		end
	end
end

function TurkeySuit.start()
	local function watch(player: Player)
		local function redress()
			if player.Character and player:HasAppearanceLoaded() then
				dress(player.Character, player:GetAttribute("Skin"))
			end
		end
		player.CharacterAppearanceLoaded:Connect(function(character)
			dress(character, player:GetAttribute("Skin"))
		end)
		player:GetAttributeChangedSignal("Skin"):Connect(redress)
		redress()
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return TurkeySuit
