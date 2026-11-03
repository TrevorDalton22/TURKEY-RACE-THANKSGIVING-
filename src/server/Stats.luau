-- Leaderstats (Feathers, Wins), saved to a DataStore when the place is published.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Stats = {}

local store
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore("TurkeyStats_v1")
end)
if not ok then
	warn("[TurkeyRace] Stats won't be saved:", err)
end

-- Only save players whose data loaded, so a failed load never overwrites real progress.
local loaded = {}

local function save(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not store or not loaded[player] or not leaderstats then
		return
	end
	local data = { Feathers = leaderstats.Feathers.Value, Wins = leaderstats.Wins.Value }
	local success, saveErr = pcall(store.SetAsync, store, tostring(player.UserId), data)
	if not success then
		warn("[TurkeyRace] Couldn't save stats for", player.Name, saveErr)
	end
end

local function load(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local feathers = Instance.new("IntValue")
	feathers.Name = "Feathers"
	feathers.Parent = leaderstats
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = leaderstats
	leaderstats.Parent = player

	if not store then
		return
	end
	local success, data = pcall(store.GetAsync, store, tostring(player.UserId))
	if success then
		loaded[player] = true
		if data then
			feathers.Value = data.Feathers or 0
			wins.Value = data.Wins or 0
		end
	else
		warn("[TurkeyRace] Couldn't load stats for", player.Name, data)
	end
end

function Stats.add(player: Player, feathers: number, wins: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	leaderstats.Feathers.Value += feathers
	leaderstats.Wins.Value += wins
	task.spawn(save, player)
end

function Stats.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)
end

return Stats
