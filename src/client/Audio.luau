-- Plays the sounds in shared/Sounds: ones the server asks for, countdown beeps and the finish cheer.
-- Every sound effect plays through the Effects sound group and the music (client/Music) through the Music
-- group, so Settings can turn each one off.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local Audio = {}

local function group(name: string): SoundGroup
	local soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = name
	soundGroup.Parent = SoundService
	return soundGroup
end
Audio.Effects = group("TurkeyEffects")
Audio.Music = group("TurkeyMusic")

local templates: { [string]: Sound } = {}

local function makeTemplates()
	local folder = Instance.new("Folder")
	folder.Name = "TurkeySounds"
	for name, def in Sounds do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = if typeof(def.Id) == "string" then def.Id else `rbxassetid://{def.Id}`
		sound.Volume = def.Volume or 0.6
		sound.PlaybackSpeed = def.Speed or 1
		sound.Looped = def.Looped == true
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = def.Range or 200
		sound.SoundGroup = Audio.Effects
		sound.Parent = folder
		templates[name] = sound
	end
	folder.Parent = SoundService
	-- Load them up front so the first bonk isn't late.
	task.spawn(ContentProvider.PreloadAsync, ContentProvider, folder:GetChildren())
end

-- where: nil plays flat (same volume everywhere), a Vector3 plays from that spot,
-- and a part plays from the part and follows it.
function Audio.play(name: string, where: (Vector3 | Instance)?): Sound?
	local template = templates[name]
	if not template then
		return nil
	end
	local sound = template:Clone()
	local cleanup: Instance = sound
	if typeof(where) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.Parent = workspace.Terrain
		attachment.WorldPosition = where
		sound.Parent = attachment
		cleanup = attachment
	elseif typeof(where) == "Instance" then
		sound.Parent = where
	else
		sound.Parent = SoundService
	end
	sound:Play()
	if not sound.Looped then
		sound.Ended:Once(function()
			cleanup:Destroy()
		end)
		Debris:AddItem(cleanup, 15) -- in case it never ends, e.g. its part was destroyed
	end
	return sound
end

function Audio.start()
	makeTemplates()

	-- The server sends a part plus its position, so a part that hasn't streamed in still plays at the right spot.
	Remotes.Sound.OnClientEvent:Connect(function(name: string, where, fallback)
		Audio.play(name, if where ~= nil then where else fallback)
	end)

	-- A beep on each countdown number, then GO.
	local lastCount: number? = nil
	RunService.Heartbeat:Connect(function()
		if ReplicatedStorage:GetAttribute("Phase") == "Countdown" and player:GetAttribute("Racing") then
			local remaining = (ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow()
			local count = math.ceil(remaining)
			if count >= 1 and count ~= lastCount then
				lastCount = count
				Audio.play("Beep")
			end
		else
			lastCount = nil
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		if ReplicatedStorage:GetAttribute("Phase") == "Racing" and player:GetAttribute("Racing") then
			Audio.play("Go")
		end
	end)
	player:GetAttributeChangedSignal("Finished"):Connect(function()
		if player:GetAttribute("Finished") then
			Audio.play("Cheer")
		end
	end)
end

return Audio
