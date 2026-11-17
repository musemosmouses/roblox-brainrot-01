-- WaveEvent: the tsunami that sweeps the map and forces every player to dash home.
-- Every few minutes the game warns, then a wall of water crosses the map
-- from west to east. A player it catches is shoved along with it, drops
-- whatever they were carrying, and walks slowly for a few seconds. The
-- wave's status lives in GameState so the HUD can show it without a
-- require cycle.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared modules live under ReplicatedStorage, not under ServerScriptService,
-- so they are reached through the service, never through script.Parent.
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameState = require(script.Parent.GameState)
local StealSystem = require(script.Parent.StealSystem)

local WaveEvent = {}

local wall = nil
-- onBanner is set by init.server to the Remotes broadcast function.
WaveEvent.onBanner = nil

-- buildWall creates the water wall once and keeps it hidden until a sweep.
local function buildWall()
	if wall == nil then
		wall = Instance.new("Part")
		wall.Name = "TsunamiWave"
		wall.Size = Vector3.new(16, 30, 280)
		wall.Color = Color3.fromRGB(0, 110, 255)
		wall.Material = Enum.Material.Neon
		wall.Transparency = 1
		wall.Anchored = true
		wall.CanCollide = false
		wall.CanQuery = false
		wall.CanTouch = false
		wall.Position = Vector3.new(-160, 15, 0)
		wall.Parent = Workspace
	end
	return wall
end

-- announce sends a banner to every client when the callback is wired.
local function announce(text, seconds)
	if WaveEvent.onBanner ~= nil then
		WaveEvent.onBanner(text, seconds)
	end
end

-- isOnOwnPlot is true while the player's character stands inside their own
-- base plot: the plot floor is 22 studs across, so home is a safe zone
-- from the wave. A player with no plot is never home.
local function isOnOwnPlot(player, root)
	local data = GameState.forPlayer(player.UserId)
	if data == nil or data.plotIndex == nil or data.plotIndex == 0 then
		return false
	end
	local centre = GameConfig.plots.centres[data.plotIndex]
	if centre == nil then
		return false
	end
	local half = GameConfig.plots.floorSize / 2
	return math.abs(root.Position.X - centre[1]) <= half
		and math.abs(root.Position.Z - centre[2]) <= half
end

-- punish is what the wave does to one caught player: shove, drop, slow.
local function punish(player)
	local character = player.Character
	if character == nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end
	if isOnOwnPlot(player, root) then
		return
	end
	root.CFrame = root.CFrame + Vector3.new(GameConfig.tsunami.shoveStuds, 0, 0)
	StealSystem.drop(player.UserId)
	local data = GameState.forPlayer(player.UserId)
	if data ~= nil then
		data.slowedUntil = os.clock() + GameConfig.tsunami.slowSeconds
	end
end

-- sweep runs one crossing, west to east, catching players in its path.
local function sweep()
	local wallPart = buildWall()
	wallPart.Transparency = 0.45
	GameState.wave = { active = true, left = GameConfig.tsunami.sweepSeconds, phase = "sweep" }
	announce("TSUNAMI! Run home!", GameConfig.tsunami.sweepSeconds)
	local caught = {}
	local fromX = -160
	local toX = 160
	local steps = GameConfig.tsunami.sweepSeconds * 10
	for step = 0, steps do
		local progress = step / steps
		local x = fromX + (toX - fromX) * progress
		wallPart.Position = Vector3.new(x, 15, 0)
		GameState.wave.left = GameConfig.tsunami.sweepSeconds * (1 - progress)
		for _, player in ipairs(Players:GetPlayers()) do
			if caught[player.UserId] == nil then
				local character = player.Character
				if character ~= nil then
					local root = character:FindFirstChild("HumanoidRootPart")
					if root ~= nil and math.abs(root.Position.X - x) <= GameConfig.tsunami.halfWidth then
						caught[player.UserId] = true
						punish(player)
					end
				end
			end
		end
		task.wait(0.1)
	end
	wallPart.Transparency = 1
	GameState.wave = { active = false, left = 0, phase = "idle" }
end

-- warn counts the warning down, one second at a time, then hands over to the sweep.
local function warn()
	GameState.wave = { active = true, left = GameConfig.tsunami.warnSeconds, phase = "warn" }
	announce("TSUNAMI INCOMING! Get to your base!", GameConfig.tsunami.warnSeconds)
	for second = GameConfig.tsunami.warnSeconds, 1, -1 do
		GameState.wave.left = second
		task.wait(1)
	end
end

-- begin warns, then sweeps, then waits for the next wave, forever.
function WaveEvent.begin()
	buildWall()
	GameState.wave = { active = false, left = 0, phase = "idle" }
	task.spawn(function()
		while true do
			task.wait(GameConfig.tsunami.everySeconds)
			warn()
			sweep()
		end
	end)
end

return WaveEvent

