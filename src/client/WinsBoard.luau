-- Draws the Hall of Fame on the lobby board (Workspace.Lobby.WinsBoard) from the TopWins list the server
-- publishes: the top three on gold, silver and bronze plates, then the rest.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local WinsBoard = {}

local MEDALS = { "🥇", "🥈", "🥉" }
local PLATES = { Color3.fromRGB(255, 200, 55), Color3.fromRGB(205, 215, 230), Color3.fromRGB(215, 135, 65) }
local ROW = Color3.fromRGB(95, 58, 32)
local DARK_TEXT = Color3.fromRGB(60, 32, 16)

local function build(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "HallOfFame"
	gui.Adornee = part
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local board = Ui.card(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.WINDOW })
	board.Border.Thickness = 10
	board.Border.Color = Ui.GOLD
	local header = Ui.card(board, {
		Position = UDim2.new(0, 24, 0, 24),
		Size = UDim2.new(1, -48, 0.12, 0),
		BackgroundColor3 = Ui.GOLD,
	})
	local title = Ui.label(header, {
		Position = UDim2.new(0, 16, 0.12, 0),
		Size = UDim2.new(1, -32, 0.76, 0),
		Text = "🏆 HALL OF FAME 🏆",
	})
	title.Outline.Thickness = 4
	local scope = Ui.label(board, {
		Position = UDim2.new(0, 24, 0.17, 0),
		Size = UDim2.new(1, -48, 0.045, 0),
		TextColor3 = Ui.CREAM,
	})

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 28, 0.23, 0)
	list.Size = UDim2.new(1, -56, 0.69, 0)
	list.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	Ui.label(board, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.new(1, -60, 0.045, 0),
		Text = "Win a race to get your name up here!",
		TextColor3 = Color3.fromRGB(255, 215, 150),
	})

	-- The top three rows are bigger, on medal-colored plates.
	local rows = {}
	local size = Config.Leaderboard.Size
	local weights = {}
	local total = 0
	for i = 1, size do
		weights[i] = if i <= 3 then 1.5 else 1
		total += weights[i]
	end
	for i = 1, size do
		local plate = PLATES[i]
		local row = Ui.panel(list, {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, weights[i] / total, -8),
			BackgroundColor3 = plate or ROW,
			BackgroundTransparency = if plate then 0 else (if i % 2 == 0 then 0.1 else 0.45),
		})
		local textColor = if plate then DARK_TEXT else Color3.new(1, 1, 1)
		Ui.label(row, {
			Position = UDim2.fromScale(0.02, 0.12),
			Size = UDim2.fromScale(0.12, 0.76),
			Text = MEDALS[i] or `{i}`,
			TextStrokeTransparency = if plate then 1 else nil,
		})
		local name = Ui.label(row, {
			Position = UDim2.fromScale(0.16, 0.14),
			Size = UDim2.fromScale(0.56, 0.72),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = textColor,
			TextStrokeTransparency = if plate then 1 else nil,
		})
		local wins = Ui.label(row, {
			Position = UDim2.fromScale(0.72, 0.14),
			Size = UDim2.fromScale(0.26, 0.72),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if plate then DARK_TEXT else Ui.GOLD,
			TextStrokeTransparency = if plate then 1 else nil,
		})
		rows[i] = { name = name, wins = wins, color = textColor }
	end

	local function refresh()
		local ok, data = pcall(HttpService.JSONDecode, HttpService, ReplicatedStorage:GetAttribute("TopWins") or "")
		local entries = if ok and data then data.Entries else {}
		scope.Text = if ok and data and data.Global then "Most wins in every server" else "Most wins in this server"
		for i, row in rows do
			local entry = entries[i]
			row.name.Text = if entry then entry.Name else "—"
			-- You stand out in your own row.
			row.name.TextColor3 = if entry and entry.Name == player.Name and i > 3 then Ui.ORANGE else row.color
			row.wins.Text = if entry then `{Format.number(entry.Wins)} {if entry.Wins == 1 then "win" else "wins"}` else ""
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
