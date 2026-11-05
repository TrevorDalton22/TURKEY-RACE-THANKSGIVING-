-- Lights up your next checkpoint arch (server/Arches) with a pulsing green glow while you race, and chimes and
-- flashes as you ride through each one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Audio = require(script.Parent.Audio)

local player = Players.LocalPlayer

local Checkpoints = {}

local lit: { BasePart } = {}
local litAt = 0

local function arch(index: number): Model?
	for _, map in workspace:WaitForChild("Maps"):GetChildren() do
		if map:GetAttribute("DisplayName") == ReplicatedStorage:GetAttribute("Map") then
			local arches = map:FindFirstChild("Arches")
			return arches and arches:FindFirstChild("Arch" .. index) :: Model?
		end
	end
	return nil
end

local function glowParts(index: number): { BasePart }
	local found = arch(index)
	local glow = found and found:FindFirstChild("Glow")
	local parts = {}
	if glow then
		for _, p in glow:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(parts, p)
			end
		end
	end
	return parts
end

local function setLit(parts: { BasePart })
	for _, p in lit do
		p.Transparency = 1
	end
	lit = parts
	litAt = os.clock()
end

-- A quick bright flash on an arch you just rode through.
local function flash(index: number)
	local parts = glowParts(index)
	for _, p in parts do
		p.Transparency = 0
	end
	task.delay(0.35, function()
		for _, p in parts do
			if not table.find(lit, p) then
				p.Transparency = 1
			end
		end
	end)
end

function Checkpoints.start()
	local last: number? = nil
	player:GetAttributeChangedSignal("NextGate"):Connect(function()
		local nextGate = player:GetAttribute("NextGate")
		if typeof(nextGate) ~= "number" or not player:GetAttribute("Racing") then
			setLit({})
			last = nil
			return
		end
		-- Moving on from a checkpoint (not the start of the race).
		if last and nextGate ~= last then
			Audio.play("Checkpoint")
			flash(last)
		end
		last = nextGate
		setLit(glowParts(nextGate))
	end)
	player:GetAttributeChangedSignal("Racing"):Connect(function()
		if not player:GetAttribute("Racing") then
			setLit({})
			last = nil
		end
	end)

	RunService.RenderStepped:Connect(function()
		local pulse = 0.5 + 0.5 * math.sin((os.clock() - litAt) * 6)
		for _, p in lit do
			p.Transparency = 0.55 * pulse
		end
	end)
end

return Checkpoints
