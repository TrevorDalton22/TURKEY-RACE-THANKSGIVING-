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

local function attach(host: BasePart, props, offset: CFrame)
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
				attach(host, piece.Props, piece.Offset)
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
