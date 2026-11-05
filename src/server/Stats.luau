-- Everything saved about a player, in a DataStore once the place is published:
--   leaderstats  Level, Wins and Feathers (the player list shows these)
--   skins        owned skin ids, published to clients as the attributes Skin (equipped) and OwnedSkins
--   profile      XP, Harvest Pass progress, XP boost time and recent Robux receipts (see Profile);
--                Progression and Robux work with it and publish what clients need
-- Changes are saved a moment later in one go (saveSoon), and when the player leaves.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Season = require(ReplicatedStorage.Shared.Season)
local Skins = require(ReplicatedStorage.Shared.Skins)

local Stats = {}

export type Profile = {
	Xp: number, -- lifetime
	SeasonXp: number, -- this season (Season.Id)
	FreeClaimed: number, -- highest pass tier whose free reward has been granted
	PremiumClaimed: number, -- same for premium rewards
	BoostUntil: number, -- os.time() when the XP boost runs out
	Receipts: { string }, -- recent Robux purchase ids, so no purchase is ever granted twice
}

local store
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore("TurkeyStats_v1")
end)
if not ok then
	warn("[TurkeyRace] Stats won't be saved:", err)
end

-- Only save players whose data loaded, so a failed load never overwrites real progress.
local loaded = {}
-- Players whose load has finished, whether or not it worked.
local ready = {}
-- Owned skin ids per player, as a set.
local owned: { [Player]: { [string]: boolean } } = {}
local profiles: { [Player]: Profile } = {}
local saveQueued = {}
local loadedCallbacks = {}
-- Saves in flight, so a server shutting down can wait for them.
local saving = 0

local TRIES = 3
local SAVE_DELAY = 2
local MAX_RECEIPTS = 50

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

-- Returns whether the data is safely stored.
local function save(player: Player): boolean
	local leaderstats = player:FindFirstChild("leaderstats")
	local profile = profiles[player]
	if not store or not loaded[player] or not leaderstats or not owned[player] or not profile then
		return false
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
		Xp = profile.Xp,
		Season = { Id = Season.Id, Xp = profile.SeasonXp, Free = profile.FreeClaimed, Premium = profile.PremiumClaimed },
		BoostUntil = profile.BoostUntil,
		Receipts = profile.Receipts,
	}
	saving += 1
	local success, saveErr = attempt(store.SetAsync, tostring(player.UserId), data)
	saving -= 1
	if not success then
		warn("[TurkeyRace] Couldn't save stats for", player.Name, saveErr)
	end
	return success
end

local function stat(parent: Instance, name: string)
	local value = Instance.new("IntValue")
	value.Name = name
	value.Parent = parent
	return value
end

local function load(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	stat(leaderstats, "Level").Value = 1
	local wins = stat(leaderstats, "Wins")
	local feathers = stat(leaderstats, "Feathers")
	leaderstats.Parent = player

	owned[player] = { [Skins.Default] = true }
	player:SetAttribute("Skin", Skins.Default)
	publishSkins(player)
	local profile: Profile = { Xp = 0, SeasonXp = 0, FreeClaimed = 0, PremiumClaimed = 0, BoostUntil = 0, Receipts = {} }
	profiles[player] = profile

	if store then
		local success, data = attempt(store.GetAsync, tostring(player.UserId))
		if player.Parent == nil then
			return
		end
		if success then
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
				profile.Xp += data.Xp or 0
				profile.BoostUntil = math.max(profile.BoostUntil, data.BoostUntil or 0)
				profile.Receipts = data.Receipts or {}
				-- A different season id means a new season: pass progress starts over.
				local season = data.Season
				if season and season.Id == Season.Id then
					profile.SeasonXp += season.Xp or 0
					profile.FreeClaimed = math.max(profile.FreeClaimed, season.Free or 0)
					profile.PremiumClaimed = math.max(profile.PremiumClaimed, season.Premium or 0)
				end
			end
		else
			warn("[TurkeyRace] Couldn't load stats for", player.Name, data)
			ReplicatedStorage.Remotes.Notify:FireClient(player, "⚠️ Couldn't load your feathers, so this visit won't be saved. Rejoin to try again!")
		end
	end

	ready[player] = true
	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

-- Calls `callback(player)` once each player's data has finished loading (or failed to).
function Stats.onLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in ready do
		task.spawn(callback, player)
	end
end

-- True once the player's data has finished loading, so it's safe to compare against what was saved.
function Stats.isReady(player: Player): boolean
	return ready[player] == true
end

-- True when the player's data loaded from the DataStore, so their changes can be saved.
function Stats.isLoaded(player: Player): boolean
	return loaded[player] == true
end

function Stats.profile(player: Player): Profile?
	return profiles[player]
end

-- Saves in a couple of seconds, so several changes in a row (a race's Feathers and XP) go out as one write.
function Stats.saveSoon(player: Player)
	if saveQueued[player] then
		return
	end
	saveQueued[player] = true
	task.delay(SAVE_DELAY, function()
		saveQueued[player] = nil
		if player.Parent then
			save(player)
		end
	end)
end

-- Saves right away and returns whether it worked (for Robux purchases, which must be stored before
-- they're confirmed).
function Stats.saveNow(player: Player): boolean
	return save(player)
end

-- Remembers a Robux purchase id; returns false if it was already granted.
function Stats.addReceipt(player: Player, purchaseId: string): boolean
	local profile = profiles[player]
	if not profile or table.find(profile.Receipts, purchaseId) then
		return false
	end
	table.insert(profile.Receipts, purchaseId)
	while #profile.Receipts > MAX_RECEIPTS do
		table.remove(profile.Receipts, 1)
	end
	return true
end

function Stats.removeReceipt(player: Player, purchaseId: string)
	local profile = profiles[player]
	local index = profile and table.find(profile.Receipts, purchaseId)
	if index then
		table.remove(profile.Receipts, index)
	end
end

function Stats.add(player: Player, feathers: number, wins: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	leaderstats.Feathers.Value += feathers
	leaderstats.Wins.Value += wins
	Stats.saveSoon(player)
end

function Stats.setLevel(player: Player, level: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Level.Value = level
	end
end

function Stats.feathers(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	return if leaderstats then leaderstats.Feathers.Value else 0
end

function Stats.owns(player: Player, skinId: string): boolean
	return owned[player] ~= nil and owned[player][skinId] == true
end

-- Gives the player a skin (a pass reward or a Robux purchase).
function Stats.unlockSkin(player: Player, skinId: string)
	if not owned[player] or not Skins.byId[skinId] or owned[player][skinId] then
		return
	end
	owned[player][skinId] = true
	publishSkins(player)
	Stats.saveSoon(player)
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
	Stats.saveSoon(player)
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
		ready[player] = nil
		owned[player] = nil
		profiles[player] = nil
		saveQueued[player] = nil
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
