-- init.server: the server bootstrap for Brainrot Warung.
-- It starts the remotes, hands each joining player a plot, and starts the
-- four loops: the conveyor, the stealing, the tsunami and the income tick.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local GameState = require(script.Parent.GameState)
local Conveyor = require(script.Parent.Conveyor)
local StealSystem = require(script.Parent.StealSystem)
local WaveEvent = require(script.Parent.WaveEvent)
local Remotes = require(script.Parent.Remotes)

-- labelPlot writes the owner's name on one plot's sign board.
local function labelPlot(plotIndex, text)
	local plot = Workspace:FindFirstChild("Base" .. tostring(plotIndex))
	if plot == nil then
		return
	end
	local sign = plot:FindFirstChild("Sign")
	if sign == nil then
		return
	end
	local gui = sign:FindFirstChild("SignGui")
	if gui == nil then
		return
	end
	local label = gui:FindFirstChild("OwnerLabel")
	if label ~= nil then
		label.Text = text
	end
end

-- welcome gives a joining player money, a plot and a sign with their name
-- on it. A ninth player gets no plot and plays as a visitor.
local function welcome(player)
	local plotIndex = GameState.takePlot(player.UserId) or 0
	local data = GameState.newPlayer(player.UserId, plotIndex)
	GameState.players[player.UserId] = data
	if plotIndex > 0 then
		labelPlot(plotIndex, player.DisplayName .. "'s Base")
	end
	task.wait(1)
	Remotes.pushTo(player)
end

-- goodbye returns anything they were carrying, frees their plot and clears
-- their sign for the next player.
local function goodbye(player)
	local data = GameState.forPlayer(player.UserId)
	StealSystem.drop(player.UserId)
	if data ~= nil and data.plotIndex > 0 then
		local plotIndex = data.plotIndex
		GameState.freePlot(plotIndex)
		labelPlot(plotIndex, "Empty Base")
	end
	GameState.players[player.UserId] = nil
end

Remotes.start()
WaveEvent.onBanner = Remotes.announce

Players.PlayerAdded:Connect(welcome)
Players.PlayerRemoving:Connect(goodbye)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(welcome, player)
end

Conveyor.begin()
StealSystem.begin()
WaveEvent.begin()
Remotes.beginTicking()

print("Brainrot Warung is live: conveyor, stealing, tsunami and income running.")

