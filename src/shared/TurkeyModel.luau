-- The rigged turkey everyone rides, modeled in Blender (assets/turkey). It lives in the place at
-- ReplicatedStorage.TurkeyRig:
--   Turkey   one skinned MeshPart with its Bones, standing with its Root bone on the origin and facing -Z.
--   Skins    a SurfaceAppearance per skin, named after its Id. (Scripts can't change a SurfaceAppearance's maps at
--            runtime, so each one is made ahead of time and cloned.)
--
-- "Ground space" below means the turkey standing at the origin: feet on Y = 0, +Y up, -Z forward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = require(script.Parent.Skins)

local TurkeyModel = {}

local rig = ReplicatedStorage:WaitForChild("TurkeyRig", 30)
assert(rig, "[TurkeyRace] ReplicatedStorage.TurkeyRig is missing from this place, so there's no turkey to ride")
local template = rig:WaitForChild("Turkey") :: MeshPart
local looks = rig:WaitForChild("Skins")

-- Where the mesh part sits in ground space.
TurkeyModel.MeshInGround = template.CFrame
-- How far behind the middle of the turkey the saddle is; the rider sits over it.
TurkeyModel.SeatBehind = 0.5
-- The middle of the body, for effects.
TurkeyModel.BodyCenter = Vector3.new(0, 4.3, 0)

-- A new turkey mesh in a skin, anchored and with nothing colliding. flat: textured with just its palette, for
-- ViewportFrames, which don't need the full SurfaceAppearance.
function TurkeyModel.newMesh(skinId: string?, flat: boolean?): MeshPart
	local skin = Skins.get(skinId)
	local mesh = template:Clone()
	if flat then
		mesh.TextureID = `rbxassetid://{skin.Palette}`
	else
		local look = looks:FindFirstChild(skin.Id) or looks:FindFirstChild(Skins.Default)
		look:Clone().Parent = mesh
	end
	mesh.Transparency = skin.Transparency or 0
	return mesh
end

-- A part for one of the add-ons in Skins.pieces (hats and the like), anchored until welded.
function TurkeyModel.newPiece(piece: Skins.Piece): Part
	local p = Instance.new("Part")
	p.Name = "Piece"
	p.Anchored = true
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in piece.Props do
		p[k] = v
	end
	return p
end

-- Glitter drifting off a part's surface (the Golden Turkey and friends).
function TurkeyModel.addSparkle(part: BasePart, color: Color3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 18
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Parent = part
end

return TurkeyModel
