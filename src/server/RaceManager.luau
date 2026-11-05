-- Runs the round loop: wait for players, intermission, countdown, race, results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Track = require(script.Parent.Track)
local Stats = require(script.Parent.Stats)
local Chef = require(script.Parent.Chef)
local PowerUps = require(script.Parent.PowerUps)
local Hazards = require(script.Parent.Hazards)
local Sfx = require(script.Parent.Sfx)

local Remotes = ReplicatedStorage.Remotes

local RaceManager = {}

-- Racer state for the current race, keyed by Player.
-- { lap, nextGate, gateAt (when they passed the last gate), progress, finishTime?, cooked, cookedAt? }
local racers = {}
local raceStart = 0
local round = 0
local laps = Config.Laps -- for the current map

local function setPhase(phase: string, seconds: number?)
	ReplicatedStorage:SetAttribute("Phase", phase)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", if seconds then workspace:GetServerTimeNow() + seconds else 0)
end

local function notify(text: string)
	Remotes.Notify:FireAllClients(text)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function placeOnPath(player: Player, s: number)
	local root = rootOf(player)
	if not root then
		return
	end
	local pos, dir = Track.pointAt(s)
	pos += Vector3.new(0, 4, 0)
	player.Character:PivotTo(CFrame.lookAt(pos, pos + dir))
	root.AssemblyLinearVelocity = Vector3.zero
end

local function sendToLobby(player: Player)
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if player.Character and spawn then
		local offset = Vector3.new(math.random(-8, 8), 4, math.random(-8, 8))
		player.Character:PivotTo(spawn.CFrame + offset)
	end
end

local function lastGate(r): number
	return if r.nextGate == 1 then 0 else Track.Gates[r.nextGate - 1]
end

local function finish(player: Player, r)
	r.finishTime = os.clock() - raceStart
	local count = 0
	for _, other in racers do
		if other.finishTime then
			count += 1
		end
	end
	player:SetAttribute("Finished", true)
	notify(`🏁 {player.DisplayName} finished {Format.ordinal(count)}!`)
	Sfx.gobble(player)
end

local function updateRacer(player: Player, r)
	if r.finishTime or r.cooked then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	if root.Position.Y < Config.FallHeight then
		placeOnPath(player, lastGate(r))
		return
	end

	-- Unwrap the loop distance relative to the last gate so progress never jumps by a lap.
	local length = Track.Length
	local s = Track.distanceAt(root.Position)
	local base = lastGate(r)
	if s < base - length / 2 then
		s += length
	elseif s > base + length / 2 then
		s -= length
	end

	local gate = Track.Gates[r.nextGate]
	if s >= gate and s < gate + 60 then
		local now = os.clock()
		if (gate - base) / math.max(now - r.gateAt, 0.01) > Config.MaxPace then
			placeOnPath(player, base)
			return
		end
		r.gateAt = now
		if r.nextGate == #Track.Gates then
			r.lap += 1
			r.nextGate = 1
			s -= length
			if r.lap >= laps then
				finish(player, r)
			else
				player:SetAttribute("Lap", r.lap + 1)
			end
		else
			r.nextGate += 1
		end
	end
	r.progress = r.lap * length + s
end

-- Finished racers first, then by progress, then cooked racers (cooked later ranks higher).
local function standings()
	local list = {}
	for player, r in racers do
		table.insert(list, { player = player, r = r })
	end
	table.sort(list, function(a, b)
		local ra, rb = a.r, b.r
		if ra.finishTime or rb.finishTime then
			if ra.finishTime and rb.finishTime then
				return ra.finishTime < rb.finishTime
			end
			return ra.finishTime ~= nil
		end
		if ra.cooked ~= rb.cooked then
			return not ra.cooked
		end
		if ra.cooked then
			return ra.cookedAt > rb.cookedAt
		end
		return ra.progress > rb.progress
	end)
	for i, entry in list do
		entry.player:SetAttribute("Place", i)
	end
	return list
end

local function cookLast(list)
	local alive = 0
	for _, entry in list do
		if not entry.r.cooked then
			alive += 1
		end
	end
	if alive <= Config.Elimination.FinalCount then
		return
	end
	for i = #list, 1, -1 do
		local entry = list[i]
		if not entry.r.cooked and not entry.r.finishTime then
			entry.r.cooked = true
			entry.r.cookedAt = os.clock()
			entry.player:SetAttribute("Cooked", true)
			notify(`🔥 {entry.player.DisplayName} got COOKED!`)
			Sfx.all("Cooked")
			sendToLobby(entry.player)
			return
		end
	end
end

local function runRace(mode: string)
	local entrants = {}
	for _, player in Players:GetPlayers() do
		if rootOf(player) and #entrants < Config.MaxPlayers then
			table.insert(entrants, player)
		end
	end
	if #entrants == 0 then
		return
	end

	local _, forward = Track.pointAt(0)
	for i, player in entrants do
		racers[player] = { lap = 0, nextGate = 1, progress = 0, cooked = false }
		local pos = Track.StartPads[i].Position + Vector3.new(0, 3.5, 0)
		player.Character:PivotTo(CFrame.lookAt(pos, pos + forward))
		rootOf(player).Anchored = true
		player:SetAttribute("Racing", true)
		player:SetAttribute("Lap", 1)
		player:SetAttribute("Place", i)
		player:SetAttribute("Finished", false)
		player:SetAttribute("Cooked", false)
	end

	setPhase("Countdown", Config.CountdownSeconds)
	task.wait(Config.CountdownSeconds)
	raceStart = os.clock()
	for player, r in racers do
		r.gateAt = raceStart
		local root = rootOf(player)
		if root then
			root.Anchored = false
		end
	end

	setPhase("Racing", Config.RaceTimeLimitSeconds)
	notify(if mode == "Elimination" then "GO! Last turkey gets COOKED!" else "GO! GO! GOBBLE!")
	PowerUps.begin(racers)
	Hazards.begin(racers)

	local nextCook = raceStart + Config.Elimination.StartSeconds
	local chefAt = Track.Current.ChefStartsAt or Config.Chef.StartsAtSeconds
	local chefOut = false
	while true do
		task.wait(0.1)
		local active = 0
		for player, r in racers do
			if player.Parent == nil then
				racers[player] = nil
				continue
			end
			updateRacer(player, r)
			if not r.finishTime and not r.cooked then
				active += 1
			end
		end
		local list = standings()
		local elapsed = os.clock() - raceStart
		if active == 0 or elapsed >= Config.RaceTimeLimitSeconds then
			break
		end
		if not chefOut and elapsed >= chefAt then
			chefOut = true
			Chef.begin(racers)
		end
		if mode == "Elimination" and os.clock() >= nextCook then
			nextCook += Config.Elimination.IntervalSeconds
			cookLast(list)
		end
	end

	Chef.stop()
	Hazards.stop()
	PowerUps.stop()

	local results = {}
	for place, entry in standings() do
		local player, r = entry.player, entry.r
		local feathers = Config.Rewards.Play
		if r.finishTime then
			feathers += Config.Rewards.Finish + (Config.Rewards.Places[place] or 0)
		end
		Stats.add(player, feathers, if place == 1 and r.finishTime then 1 else 0)
		table.insert(results, {
			Name = player.DisplayName,
			Place = place,
			Time = r.finishTime,
			Status = if r.finishTime then "Finished" elseif r.cooked then "Cooked" else "DNF",
			Feathers = feathers,
		})
	end
	Remotes.Results:FireAllClients(results)
end

local function cleanup()
	for player in racers do
		if player.Parent then
			sendToLobby(player)
			for _, name in { "Racing", "Lap", "Place", "Finished", "Cooked" } do
				player:SetAttribute(name, nil)
			end
		end
	end
	table.clear(racers)
end

function RaceManager.start()
	-- A racer who resets mid-race goes back to their last checkpoint.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			local r = racers[player]
			if r and not r.finishTime and not r.cooked then
				task.wait(0.2)
				placeOnPath(player, lastGate(r))
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	while true do
		setPhase("Waiting")
		while #Players:GetPlayers() < Config.MinPlayersToStart do
			task.wait(1)
		end
		-- Pick the next race before intermission so the lobby can show it. The map changes every race
		-- and the mode after each full rotation of maps, so every map gets played in both modes.
		local map = Track.Maps[round % #Track.Maps + 1]
		local mode = Config.Modes[math.floor(round / #Track.Maps) % #Config.Modes + 1]
		ReplicatedStorage:SetAttribute("Map", map.DisplayName)
		ReplicatedStorage:SetAttribute("Mode", mode)
		setPhase("Intermission", Config.IntermissionSeconds)
		task.wait(Config.IntermissionSeconds)
		if #Players:GetPlayers() < Config.MinPlayersToStart then
			continue
		end

		round += 1
		Track.use(map)
		laps = map.Laps or Config.Laps
		ReplicatedStorage:SetAttribute("Laps", laps)
		runRace(mode)
		setPhase("Results", Config.ResultsSeconds)
		task.wait(Config.ResultsSeconds)
		cleanup()
	end
end

return RaceManager
