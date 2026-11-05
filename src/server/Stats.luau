-- Leaderstats (Feathers, Wins) and owned skins, saved to a DataStore when the place is published.
-- Clients read skins from player attributes: Skin (equipped id) and OwnedSkins ("Classic,Cool").

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = require(ReplicatedStorage.Shared.Skins)

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
-- Owned skin ids per player, as a set.
local owned: { [Player]: { [string]: boolean } } = {}
-- Saves in flight, so a server shutting down can wait for them.
local saving = 0

local TRIES = 3

-- Calls a DataStore method, trying again after a short wait if Roblox's servers hiccup.
local function attempt(method, ...): (boolean, any)
	local ok, result
	for try = 1, TRIES do
		ok, result = pcall(method, store, ...)
		if ok or try == TRIES then
			break
		end
		task.wait(try * 2)
	end
	return ok, result
end

local function publishSkins(player: Player)
	local ids = {}
	for _, skin in Skins.List do
		if owned[player][skin.Id] then
			table.insert(ids, skin.Id)
		end
	end
	player:SetAttribute("OwnedSkins", table.concat(ids, ","))
end

local function save(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not store or not loaded[player] or not leaderstats or not owned[player] then
		return
	end
	local skins = {}
	for id in owned[player] do
		table.insert(skins, id)
	end
	local data = {
		Feathers = leaderstats.Feathers.Value,
		Wins = leaderstats.Wins.Value,
		Skins = skins,
		Equipped = player:GetAttribute("Skin"),
	}
	saving += 1
	local success, saveErr = attempt(store.SetAsync, tostring(player.UserId), data)
	saving -= 1
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

	owned[player] = { [Skins.Default] = true }
	player:SetAttribute("Skin", Skins.Default)
	publishSkins(player)

	if not store then
		return
	end
	local success, data = attempt(store.GetAsync, tostring(player.UserId))
	if player.Parent == nil then
		return
	end
	if not success then
		warn("[TurkeyRace] Couldn't load stats for", player.Name, data)
		ReplicatedStorage.Remotes.Notify:FireClient(player, "⚠️ Couldn't load your feathers, so this visit won't be saved. Rejoin to try again!")
		return
	end
	loaded[player] = true
	if data then
		-- Added rather than set, so anything earned while the load was in flight is kept.
		feathers.Value += data.Feathers or 0
		wins.Value += data.Wins or 0
		for _, id in data.Skins or {} do
			if Skins.byId[id] then
				owned[player][id] = true
			end
		end
		if data.Equipped and owned[player][data.Equipped] then
			player:SetAttribute("Skin", data.Equipped)
		end
		publishSkins(player)
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

function Stats.feathers(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	return if leaderstats then leaderstats.Feathers.Value else 0
end

function Stats.owns(player: Player, skinId: string): boolean
	return owned[player] ~= nil and owned[player][skinId] == true
end

-- Spends the Feathers and unlocks the skin. The caller checks the price first.
function Stats.buySkin(player: Player, skinId: string, price: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats or not owned[player] then
		return
	end
	leaderstats.Feathers.Value -= price
	owned[player][skinId] = true
	publishSkins(player)
	task.spawn(save, player)
end

function Stats.equip(player: Player, skinId: string)
	player:SetAttribute("Skin", skinId)
end

function Stats.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
		owned[player] = nil
	end)
	-- Roblox gives a closing server up to 30 seconds; save everyone at once and wait for every save to land.
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(save, player)
		end
		while saving > 0 do
			task.wait(0.1)
		end
	end)
end

return Stats
