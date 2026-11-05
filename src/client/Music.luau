-- Background music from shared/Playlists: shuffles through the lobby tracks, crossfades to the race tracks
-- while you race, and dips under the podium cutscene. Plays through the Music sound group, which Settings
-- turns on and off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Playlists = require(ReplicatedStorage.Shared.Playlists)
local Audio = require(script.Parent.Audio)

local player = Players.LocalPlayer

local Music = {}

-- The name of the track playing, and an event that fires with it whenever a new one starts.
Music.Current = nil :: string?
local changed = Instance.new("BindableEvent")
Music.Changed = changed.Event

local FADE = TweenInfo.new(1.5)
-- A track that hasn't loaded after this long is skipped.
local LOAD_TIMEOUT = 10

local playlist = "Lobby"
local queues: { [string]: { Playlists.Track } } = {}
local sound: Sound? = nil
local token = 0
local level = 1 -- 1, or lower while ducked

-- The next track from a playlist: each one plays once, in a shuffled order, before any repeats.
local function nextTrack(name: string): Playlists.Track
	local queue = queues[name]
	if not queue or #queue == 0 then
		queue = table.clone(Playlists[name])
		for i = #queue, 2, -1 do
			local j = math.random(i)
			queue[i], queue[j] = queue[j], queue[i]
		end
		-- Tracks come off the end; don't start the new round with the one that just played.
		if #queue > 1 and queue[#queue].Name == Music.Current then
			queue[1], queue[#queue] = queue[#queue], queue[1]
		end
		queues[name] = queue
	end
	return table.remove(queue) :: Playlists.Track
end

local function fadeOut(old: Sound)
	local tween = TweenService:Create(old, FADE, { Volume = 0 })
	tween.Completed:Once(function()
		old:Destroy()
	end)
	tween:Play()
end

-- Starts the next track of the current playlist, fading out the one before.
local function playNext()
	token += 1
	local mine = token
	if sound then
		fadeOut(sound)
	end
	local track = nextTrack(playlist)
	local s = Instance.new("Sound")
	s.Name = "Music"
	s.SoundId = `rbxassetid://{track.Id}`
	s.Volume = 0
	s.SoundGroup = Audio.Music
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, FADE, { Volume = Playlists.Volume * level }):Play()
	sound = s
	Music.Current = track.Name
	changed:Fire(track.Name)

	s.Ended:Once(function()
		if token == mine then
			playNext()
		end
	end)
	task.delay(LOAD_TIMEOUT, function()
		if token == mine and not s.IsLoaded then
			warn("[TurkeyRace] Skipping a music track that didn't load:", track.Name, track.Id)
			playNext()
		end
	end)
end

function Music.skip()
	playNext()
end

-- Turns the music down (during the podium cutscene, so its fanfare is heard) or back up.
function Music.duck(down: boolean)
	level = if down then 0.25 else 1
	if sound then
		TweenService:Create(sound, TweenInfo.new(0.6), { Volume = Playlists.Volume * level }):Play()
	end
end

function Music.start()
	player:GetAttributeChangedSignal("Racing"):Connect(function()
		local wanted = if player:GetAttribute("Racing") then "Race" else "Lobby"
		if wanted ~= playlist then
			playlist = wanted
			playNext()
		end
	end)
	playNext()
end

return Music
