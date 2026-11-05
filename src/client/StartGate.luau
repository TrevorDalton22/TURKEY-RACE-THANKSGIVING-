-- Swings the starting gate (server/StartGate) open at GO and turns its sign to GO!. The doors only move on
-- this screen; the server takes the gate down a few seconds later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Audio = require(script.Parent.Audio)

local player = Players.LocalPlayer

local StartGate = {}

local OPEN_ANGLE = math.rad(95)
local OPEN_SECONDS = 0.6

local function open(gate: Model)
	-- Every door part's place relative to its door's hinge, so the whole door turns as one.
	local doors = {}
	for _, door in gate:GetChildren() do
		local hinge = door:GetAttribute("Hinge")
		local swing = door:GetAttribute("Swing")
		if door:IsA("Model") and typeof(hinge) == "CFrame" and typeof(swing) == "number" then
			local parts = {}
			for _, p in door:GetDescendants() do
				if p:IsA("BasePart") then
					table.insert(parts, { part = p, offset = hinge:Inverse() * p.CFrame })
				end
			end
			table.insert(doors, { hinge = hinge, swing = swing, parts = parts })
		end
	end

	local beam = gate:FindFirstChild("Sign")
	local front = beam and beam:FindFirstChild("Front")
	local text = front and front:FindFirstChild("Text") :: TextLabel?
	if text then
		text.Text = "GO! GO! GOBBLE!"
		text.TextColor3 = Color3.fromRGB(120, 240, 120)
	end
	if beam and player:GetAttribute("Racing") then
		Audio.play("GateOpen", (beam :: BasePart).Position)
	end

	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - started) / OPEN_SECONDS, 1)
		local angle = OPEN_ANGLE * TweenService:GetValue(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		for _, door in doors do
			local turned = door.hinge * CFrame.Angles(0, angle * door.swing, 0)
			for _, entry in door.parts do
				entry.part.CFrame = turned * entry.offset
			end
		end
		if t >= 1 or not gate.Parent then
			connection:Disconnect()
		end
	end)
end

function StartGate.start()
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		if ReplicatedStorage:GetAttribute("Phase") == "Racing" then
			local gate = workspace:FindFirstChild("StartGate")
			if gate and gate:IsA("Model") then
				open(gate)
			end
		end
	end)
end

return StartGate
