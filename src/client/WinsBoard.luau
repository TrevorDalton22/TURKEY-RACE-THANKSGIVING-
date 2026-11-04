-- Draws the lobby Wins board (Workspace.Lobby.WinsBoard) from the TopWins list the server publishes.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local WinsBoard = {}

local MEDALS = { "🥇", "🥈", "🥉" }
local ROW = Color3.fromRGB(95, 58, 32)

local function build(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "WinsBoard"
	gui.Adornee = part
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local board = Ui.panel(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0 })
	Ui.label(board, {
		Position = UDim2.new(0, 20, 0.03, 0),
		Size = UDim2.new(1, -40, 0.11, 0),
		Text = "🏆 MOST WINS",
		TextColor3 = Ui.ORANGE,
	})
	local scope = Ui.label(board, {
		Position = UDim2.new(0, 20, 0.14, 0),
		Size = UDim2.new(1, -40, 0.05, 0),
		TextColor3 = Color3.fromRGB(230, 200, 160),
	})

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 20, 0.21, 0)
	list.Size = UDim2.new(1, -40, 0.76, 0)
	list.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local rows = {}
	local size = Config.Leaderboard.Size
	for i = 1, size do
		local row = Ui.panel(list, {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 1 / size, -4),
			BackgroundColor3 = ROW,
			BackgroundTransparency = if i % 2 == 1 then 0.2 else 0.6,
		})
		Ui.label(row, { Position = UDim2.fromScale(0.02, 0.1), Size = UDim2.fromScale(0.12, 0.8), Text = MEDALS[i] or `{i}.` })
		local name = Ui.label(row, {
			Position = UDim2.fromScale(0.16, 0.12),
			Size = UDim2.fromScale(0.58, 0.76),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local wins = Ui.label(row, {
			Position = UDim2.fromScale(0.74, 0.12),
			Size = UDim2.fromScale(0.24, 0.76),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Ui.ORANGE,
		})
		rows[i] = { name = name, wins = wins }
	end

	local function refresh()
		local ok, data = pcall(HttpService.JSONDecode, HttpService, ReplicatedStorage:GetAttribute("TopWins") or "")
		local entries = if ok and data then data.Entries else {}
		scope.Text = if ok and data and data.Global then "All servers" else "This server"
		for i, row in rows do
			local entry = entries[i]
			row.name.Text = if entry then entry.Name else "—"
			row.name.TextColor3 = if entry and entry.Name == player.Name then Ui.ORANGE else Color3.new(1, 1, 1)
			row.wins.Text = if entry then `{entry.Wins} 🏆` else ""
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal("TopWins"):Connect(refresh)
	refresh()
end

function WinsBoard.start()
	-- The board is part of the map, so wait for it to stream in; a map without one just has no board.
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 30)
		local part = lobby and lobby:WaitForChild("WinsBoard", 30)
		if part and part:IsA("BasePart") then
			build(part)
		end
	end)
end

return WinsBoard
