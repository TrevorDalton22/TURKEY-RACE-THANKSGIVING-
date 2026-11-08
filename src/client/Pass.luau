-- The Harvest Pass window: every tier's free and premium reward, progress toward the next tier, and the
-- button to buy the premium track. Opens from its lobby button, or from a pass skin in the shop.
-- Progress comes from the player attributes Progression publishes (SeasonXp, FreeClaimed, ...).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Season = require(ReplicatedStorage.Shared.Season)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Purchases = require(script.Parent.Purchases)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Pass = {}

local CLAIMED = Color3.fromRGB(55, 135, 65)
local REACHED_LOCKED = Color3.fromRGB(105, 70, 120) -- reached, but needs premium
local NOT_YET = Color3.fromRGB(70, 44, 26)
local EMPTY = Color3.fromRGB(58, 36, 22)
local GOLD = Color3.fromRGB(255, 205, 70)
local GREY = Color3.fromRGB(110, 110, 110)
local COLUMN_WIDTH, COLUMN_GAP = 104, 8

local setOpen: (boolean) -> () = function() end
local refresh: () -> () = function() end
local scrollToCurrent: () -> () = function() end

local function skinName(id: string): string
	local skin = Skins.byId[id]
	return if skin then skin.Name else id
end

local function rewardColor(reward): Color3
	local skin = reward and reward.Skin and Skins.byId[reward.Skin]
	return if skin then Skins.Rarities[skin.Rarity].Color else Color3.new(1, 1, 1)
end

function Pass.open()
	setOpen(true)
	refresh()
	scrollToCurrent()
end

function Pass.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TurkeyPass"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- over the HUD
	gui.Parent = player:WaitForChild("PlayerGui")
	Ui.autoScale(gui)

	local openButton = Ui.menuButton(gui, 2, "ticket", "PASS", Ui.PURPLE)
	local win, body, openWindow = Ui.window(gui, `🎟️ {string.upper(Season.Name)}`, Ui.PURPLE, UDim2.fromScale(0.9, 0.84), Vector2.new(780, 500))
	setOpen = openWindow

	-- Progress toward the next tier, and the premium button.
	local tierLabel = Ui.label(body, {
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(0, 130, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local bar = Ui.card(body, {
		Position = UDim2.new(0, 136, 0, 5),
		Size = UDim2.new(1, -370, 0, 24),
	})
	local fill = Ui.panel(bar, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Ui.ORANGE, BackgroundTransparency = 0 })
	local xpLabel = Ui.label(bar, { Position = UDim2.new(0, 0, 0, 3), Size = UDim2.new(1, 0, 1, -6), ZIndex = 2 })
	local premiumButton = Ui.button(body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 220, 0, 36),
	})

	-- Row labels on the left, then one column per tier.
	local TRACK_TOP = 46
	local rowLabels = Instance.new("Frame")
	rowLabels.BackgroundTransparency = 1
	rowLabels.Position = UDim2.new(0, 0, 0, TRACK_TOP)
	rowLabels.Size = UDim2.new(0, 88, 1, -TRACK_TOP - 34)
	rowLabels.Parent = body
	Ui.label(rowLabels, { Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0.5, -17), Text = "FREE" })
	Ui.label(rowLabels, { Position = UDim2.new(0, 0, 0.5, 17), Size = UDim2.new(1, 0, 0.5, -17), Text = "⭐\nPREMIUM", TextColor3 = GOLD })

	local track = Instance.new("ScrollingFrame")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.BorderSizePixel = 0
	track.Position = UDim2.new(0, 94, 0, TRACK_TOP)
	track.Size = UDim2.new(1, -94, 1, -TRACK_TOP - 30)
	track.CanvasSize = UDim2.new()
	track.AutomaticCanvasSize = Enum.AutomaticSize.X
	track.ScrollingDirection = Enum.ScrollingDirection.X
	track.ScrollBarThickness = 8
	track.ScrollBarImageColor3 = Ui.ORANGE
	track.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, COLUMN_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = track

	local function cell(column: Frame, position: UDim2, reward)
		local frame = Ui.panel(column, {
			Position = position,
			Size = UDim2.new(1, 0, 0.5, -17 - 6),
			BackgroundTransparency = 0,
		})
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Ui.ORANGE
		stroke.Enabled = false
		stroke.Parent = frame
		local text = Ui.label(frame, {
			Position = UDim2.new(0, 6, 0, 6),
			Size = UDim2.new(1, -12, 0.72, -6),
			Text = if reward then Progress.describe(reward, skinName) else "",
			TextColor3 = rewardColor(reward),
			TextWrapped = true,
		})
		-- Keep short rewards ("🍂 75") from blowing up bigger than the rest.
		local maxSize = Instance.new("UITextSizeConstraint")
		maxSize.MaxTextSize = 24
		maxSize.Parent = text
		local status = Ui.label(frame, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -8, 0.24, 0),
		})
		return { frame = frame, stroke = stroke, status = status, reward = reward }
	end

	local columns = {}
	for tier, rewards in Season.Rewards do
		local column = Instance.new("Frame")
		column.Name = `Tier{tier}`
		column.LayoutOrder = tier
		column.BackgroundTransparency = 1
		column.Size = UDim2.new(0, COLUMN_WIDTH, 1, -12)
		column.Parent = track
		local number = Ui.label(column, { Size = UDim2.new(1, 0, 0, 26), Text = tostring(tier) })
		table.insert(columns, {
			number = number,
			free = cell(column, UDim2.new(0, 0, 0, 30), rewards.Free),
			premium = cell(column, UDim2.new(0, 0, 0.5, 17), rewards.Premium),
		})
	end

	Ui.label(body, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 22),
		Text = `Race to earn XP: +{Config.Progression.Xp.Play} for racing, +{Config.Progression.Xp.Finish} for finishing, up to +{Config.Progression.Xp.Places[1]} more for winning`,
		TextColor3 = Color3.fromRGB(255, 225, 190),
	})

	local premiumId = Config.Robux.PremiumPass
	local premiumPrice: Purchases.Price? = nil

	local function paint(c, tier: number, current: number, claimed: number, needsPremium: boolean)
		local frame, status = c.frame, c.status
		c.stroke.Enabled = tier == current
		if not c.reward then
			frame.BackgroundColor3 = EMPTY
			status.Text = ""
		elseif tier <= claimed then
			frame.BackgroundColor3 = CLAIMED
			status.Text = "✓"
		elseif tier <= current and needsPremium then
			frame.BackgroundColor3 = REACHED_LOCKED
			status.Text = "🔒"
		else
			frame.BackgroundColor3 = NOT_YET
			status.Text = if needsPremium then "🔒" else ""
		end
	end

	refresh = function()
		local seasonXp = player:GetAttribute("SeasonXp") or 0
		local tier, into = Progress.tier(seasonXp)
		local premium = player:GetAttribute("PassPremium") == true
		local last = #Season.Rewards
		tierLabel.Text = `Tier {tier} / {last}`
		if tier == last then
			fill.Size = UDim2.fromScale(1, 1)
			xpLabel.Text = "Pass complete! 🎉"
		else
			fill.Size = UDim2.fromScale(into / Season.XpPerTier, 1)
			xpLabel.Text = `{into} / {Season.XpPerTier} XP`
		end
		local freeClaimed = player:GetAttribute("FreeClaimed") or 0
		local premiumClaimed = player:GetAttribute("PremiumClaimed") or 0
		for t, column in columns do
			column.number.TextColor3 = if t == tier then Ui.ORANGE elseif t < tier then Color3.new(1, 1, 1) else Color3.fromRGB(170, 140, 120)
			paint(column.free, t, tier, freeClaimed, false)
			paint(column.premium, t, tier, if premium then premiumClaimed else 0, not premium)
		end
		if premium then
			premiumButton.Text = "⭐ Premium ✓"
			premiumButton.BackgroundColor3 = GOLD
			premiumButton.TextColor3 = Color3.fromRGB(80, 45, 10)
		else
			premiumButton.Text = if premiumId == 0 then "⭐ Premium: coming soon" else `⭐ Get Premium  {Purchases.label(premiumPrice, premiumId)}`
			premiumButton.BackgroundColor3 = if premiumId == 0 then GREY else Purchases.GREEN
			premiumButton.TextColor3 = Color3.new(1, 1, 1)
		end
	end

	scrollToCurrent = function()
		local tier = Progress.tier(player:GetAttribute("SeasonXp") or 0)
		task.defer(function()
			local x = (tier - 1) * (COLUMN_WIDTH + COLUMN_GAP) - track.AbsoluteSize.X / Ui.scaleOf(track) / 2 + COLUMN_WIDTH / 2
			track.CanvasPosition = Vector2.new(math.max(0, x), 0)
		end)
	end

	premiumButton.Activated:Connect(function()
		if player:GetAttribute("PassPremium") ~= true then
			Purchases.buy("GamePass", premiumId)
		end
	end)
	openButton.Activated:Connect(function()
		if win.Visible then
			setOpen(false)
		else
			Pass.open()
		end
	end)

	Purchases.price("GamePass", premiumId, function(price)
		premiumPrice = price
		refresh()
	end)
	for _, name in { "SeasonXp", "FreeClaimed", "PremiumClaimed", "PassPremium" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player:GetAttributeChangedSignal("Racing"):Connect(function()
		local racing = player:GetAttribute("Racing") == true
		openButton.Visible = not racing
		if racing then
			win.Visible = false
		end
	end)
	refresh()
end

return Pass
