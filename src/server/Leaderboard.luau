-- Ranks turkeys by Wins for the lobby board. Once the place is published it uses an OrderedDataStore,
-- so the board is global; in Studio (no DataStores) it ranks the players in this server instead.
-- The result goes to clients as JSON in the ReplicatedStorage attribute TopWins: { Global, Entries = { {Name, Wins} } }.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Leaderboard = {}

local store
pcall(function()
	store = DataStoreService:GetOrderedDataStore("TurkeyWins_v1")
end)

-- Wins last written per player, so unchanged totals aren't written again.
local written: { [Player]: number } = {}
local names: { [number]: string } = {}

local function winsOf(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	return if leaderstats then leaderstats.Wins.Value else 0
end

-- Wins only go up, so keeping the larger value means a failed stats load can never lower a record.
local function record(player: Player)
	local wins = winsOf(player)
	if not store or wins <= (written[player] or 0) then
		return
	end
	local ok, err = pcall(store.UpdateAsync, store, tostring(player.UserId), function(old)
		return math.max(old or 0, wins)
	end)
	if ok then
		written[player] = wins
	else
		warn("[TurkeyRace] Couldn't record wins for", player.Name, err)
	end
end

local function nameOf(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.Name
	end
	if not names[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		if not ok then
			return "Turkey"
		end
		names[userId] = name
	end
	return names[userId]
end

local function serverTop()
	local entries = {}
	for _, player in Players:GetPlayers() do
		table.insert(entries, { Name = player.Name, Wins = winsOf(player) })
	end
	table.sort(entries, function(a, b)
		return a.Wins > b.Wins
	end)
	while #entries > Config.Leaderboard.Size do
		table.remove(entries)
	end
	return entries
end

-- Returns the top entries and whether they're global.
local function fetchTop()
	if store then
		local ok, page = pcall(function()
			return store:GetSortedAsync(false, Config.Leaderboard.Size):GetCurrentPage()
		end)
		if ok then
			local entries = {}
			for _, entry in page do
				local userId = tonumber(entry.key)
				if userId then
					table.insert(entries, { Name = nameOf(userId), Wins = entry.value })
				end
			end
			return entries, true
		end
		warn("[TurkeyRace] Couldn't read the Wins leaderboard:", page)
	end
	return serverTop(), false
end

function Leaderboard.start()
	Players.PlayerRemoving:Connect(function(player)
		record(player)
		written[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			record(player)
		end
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				record(player)
			end
			local entries, global = fetchTop()
			ReplicatedStorage:SetAttribute("TopWins", HttpService:JSONEncode({ Global = global, Entries = entries }))
			task.wait(if global then Config.Leaderboard.RefreshSeconds else 5)
		end
	end)
end

return Leaderboard
