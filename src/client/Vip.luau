-- What everyone sees of a VIP (the VIP pass, server/Robux): a gold [VIP] before their chat messages and a
-- crown badge over their head. The server sets the player attribute Vip; the golden trail is server/Mount.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Ui = require(script.Parent.Ui)

local Vip = {}

local TAG = '<font color="#FFCD46">[VIP]</font> '

local function isVip(player: Player?): boolean
	return player ~= nil and player:GetAttribute("Vip") == true
end

-- A small crown and "VIP" over the head of a VIP's character.
local function badge(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("VipBadge")
	if old then
		old:Destroy()
	end
	if not isVip(player) then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "VipBadge"
	board.Size = UDim2.fromOffset(110, 34)
	board.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	board.AlwaysOnTop = false
	board.MaxDistance = 120
	board.LightInfluence = 0
	local holder = Ui.card(board, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(96, 30),
		BackgroundColor3 = Color3.fromRGB(150, 50, 40),
	})
	Ui.icon(holder, "crown", { Position = UDim2.new(0, -6, 0, -10), Size = UDim2.fromOffset(40, 40) })
	Ui.label(holder, { Position = UDim2.new(0, 34, 0, 4), Size = UDim2.new(1, -42, 1, -8), Text = "VIP", TextColor3 = Color3.fromRGB(255, 214, 90) })
	board.Adornee = head
	board.Parent = head
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		badge(player)
	end)
	player:GetAttributeChangedSignal("Vip"):Connect(function()
		badge(player)
	end)
	badge(player)
end

function Vip.start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if isVip(sender) then
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = TAG .. message.PrefixText
			return properties
		end
		return nil
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
end

return Vip
