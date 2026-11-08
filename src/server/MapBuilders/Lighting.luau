-- The game's lighting: a warm fall afternoon. The light is softer and less saturated than the old bright look,
-- with a golden haze in the distance, and the slanting sun brings out the low-poly facets.
-- Lighting lives in the place, not in Rojo; run this from the command bar to apply it, then save the place:
--
--   loadstring(game.ServerScriptService.Server.MapBuilders.Lighting.Source)()

local Lighting = game:GetService("Lighting")

local function child(className: string, name: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = Lighting
	return made
end

local function set(instance: Instance, props)
	for k, v in props do
		instance[k] = v
	end
end

set(Lighting, {
	Brightness = 1.6,
	ExposureCompensation = -0.45,
	-- Mid-afternoon, from the west-northwest: low enough for long shadows, high enough that the dining room's and
	-- kitchen's shadows stop short of the lobby.
	ClockTime = 15.3,
	GeographicLatitude = 8,
	Ambient = Color3.fromRGB(72, 64, 60),
	OutdoorAmbient = Color3.fromRGB(108, 98, 92),
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.3,
	ShadowSoftness = 0.4,
	GlobalShadows = true,
})

-- Natural colors with a little more contrast and a warm tint, instead of boosted saturation.
set(child("ColorCorrectionEffect", "Grade"), {
	Brightness = -0.02,
	Contrast = 0.14,
	Saturation = -0.06,
	TintColor = Color3.fromRGB(255, 240, 224),
	Enabled = true,
})

-- A golden haze in the distance, so the far trees fade warmly instead of to pale blue.
set(child("Atmosphere", "Atmosphere"), {
	Density = 0.36,
	Offset = 0.15,
	Haze = 1,
	Glare = 0.25,
	Color = Color3.fromRGB(235, 222, 205),
	Decay = Color3.fromRGB(190, 150, 115),
})

set(child("BloomEffect", "Bloom"), { Intensity = 0.6, Size = 24, Threshold = 1.8, Enabled = true })
set(child("SunRaysEffect", "SunRays"), { Intensity = 0.06, Spread = 0.2, Enabled = true })

print("Lighting set: late fall afternoon")
return "ok"
