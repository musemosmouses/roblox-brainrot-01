-- Remotes: the RemoteEvents the client may call, and the server-side validation for each.
-- The client never decides money, ownership or locks: it asks, the server
-- checks GameState, and the server answers with a fresh state. The state
-- loop also pays income once a second and pushes the HUD's numbers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared modules live under ReplicatedStorage, not under ServerScriptService,
-- so they are reached through the service, never through script.Parent.
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local BrainrotCatalog = require(ReplicatedStorage.Shared.BrainrotCatalog)
local GameState = require(script.Parent.GameState)
local StealSystem = require(script.Parent.StealSystem)

local Remotes = {}

local folder = nil
local stateEvent = nil
local bannerEvent = nil

-- ownedList turns a player's slots into the rows the HUD lists.
local function ownedList(data)
	local owned = {}
	local used = 0
	for _, model in pairs(data.slots) do
		if model ~= nil then
			used = used + 1
			local record = GameState.brainrots[model]
			if record ~= nil then
				local character = BrainrotCatalog.find(record.characterId)
				assert(character ~= nil, "unknown character " .. tostring(record.characterId))
				table.insert(owned, {
					display = character.display,
					tier = character.tier,
					mutation = record.mutation,
					rate = record.rate,
				})
			end
		end
	end
	return owned, used
end

-- priceList is the shop's live prices: -1 where an upgrade is maxed.
local function priceList(data)
	local costs = {}
	for upgradeId, def in pairs(GameConfig.shop) do
		local level = data.levels[upgradeId] or 0
		if level >= def.max then
			costs[upgradeId] = -1
		else
			costs[upgradeId] = GameState.upgradePrice(data, upgradeId)
		end
	end
	return costs
end

-- snapshot is the one table the client ever sees: money, income, plot,
-- locks, upgrades, rebirth progress, the wave, and what it owns.
local function snapshot(data)
	local owned, used = ownedList(data)
	local nextRebirth = GameConfig.rebirth.needed[data.rebirths + 1] or 0
	local wave = GameState.wave or { active = false, left = 0, phase = "idle" }
	return {
		money = math.floor(data.money),
		income = math.floor(GameState.incomePerSecond(data) + 0.5),
		earned = math.floor(data.earned),
		rebirths = data.rebirths,
		plot = data.plotIndex,
		usedSlots = used,
		slotTotal = GameState.slotLimit(data),
		lockLeft = math.ceil(GameState.lockLeft(data)),
		lockWait = math.ceil(GameState.cooldownLeft(data)),
		levels = {
			IncomeBoost = data.levels.IncomeBoost,
			SpeedBoots = data.levels.SpeedBoots,
			ExtraSlot = data.levels.ExtraSlot,
		},
		costs = priceList(data),
		canRebirth = GameState.rebirthReady(data),
		nextRebirth = nextRebirth,
		waveOn = wave.active,
		waveLeft = math.ceil(wave.left),
		wavePhase = wave.phase or "idle",
		owned = owned,
		carrying = StealSystem.hasCarry(data.userId),
	}
end

-- pushTo pushes one player's fresh state to that player alone.
function Remotes.pushTo(player)
	local data = GameState.forPlayer(player.UserId)
	if data == nil or stateEvent == nil then
		return
	end
	stateEvent:FireClient(player, snapshot(data))
end

-- announce shows one warning on every screen at once.
function Remotes.announce(text, seconds)
	if bannerEvent ~= nil then
		bannerEvent:FireAllClients(text, seconds)
	end
end

-- ACTIONS is the four things the client may ask for. Each one validates
-- in GameState first and answers with a fresh state either way.
local ACTIONS = {
	BuyUpgrade = function(player, upgradeId)
		local data = GameState.forPlayer(player.UserId)
		if data ~= nil and typeof(upgradeId) == "string" then
			GameState.buyUpgrade(data, upgradeId)
		end
	end,
	RequestRebirth = function(player)
		local data = GameState.forPlayer(player.UserId)
		if data ~= nil then
			GameState.rebirth(data)
		end
	end,
	ToggleLock = function(player)
		local data = GameState.forPlayer(player.UserId)
		if data ~= nil then
			GameState.lockPlot(data)
		end
	end,
	-- RequestSteal is the E key: one deliberate grab attempt, validated
	-- in StealSystem (range, ownership, lock, carry, cooldown).
	RequestSteal = function(player)
		local data = GameState.forPlayer(player.UserId)
		if data ~= nil then
			StealSystem.grabAttempt(player, data)
		end
	end,
}

local function wireHandlers()
	for name, action in pairs(ACTIONS) do
		folder:WaitForChild(name).OnServerEvent:Connect(function(player, ...)
			action(player, ...)
			Remotes.pushTo(player)
		end)
	end
end

-- start creates the RemoteEvents and wires the handlers. Called once.
function Remotes.start()
	folder = ReplicatedStorage:FindFirstChild("BrainrotRemotes")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "BrainrotRemotes"
		folder.Parent = ReplicatedStorage
	end
	local function getEvent(name)
		local event = folder:FindFirstChild(name)
		if event == nil then
			event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
		return event
	end
	stateEvent = getEvent("StateUpdate")
	bannerEvent = getEvent("EventBanner")
	getEvent("BuyUpgrade")
	getEvent("RequestRebirth")
	getEvent("ToggleLock")
	getEvent("RequestSteal")
	wireHandlers()
end

-- beginTicking pays income once a second and pushes every HUD's numbers.
function Remotes.beginTicking()
	task.spawn(function()
		while true do
			task.wait(GameConfig.economy.tickSeconds)
			GameState.tickIncome()
			for _, player in ipairs(Players:GetPlayers()) do
				Remotes.pushTo(player)
			end
		end
	end)
end

return Remotes

