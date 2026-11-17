-- GameState: the single source of truth for every player, plot and coin in the game.
-- Every other server module reads and writes through here, so the economy,
-- the plots and the brainrot registry can never disagree with each other.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared modules live under ReplicatedStorage, not under ServerScriptService,
-- so they are reached through the service, never through script.Parent.
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local BrainrotCatalog = require(ReplicatedStorage.Shared.BrainrotCatalog)

local GameState = {}

-- players maps userId -> player record.
GameState.players = {}
-- brainrots maps a brainrot Model -> its record.
GameState.brainrots = {}
-- plots maps plot index -> userId of its owner, or nil when free.
GameState.plots = {}
GameState.nextId = 1
-- wave is the tsunami's live state for the HUD: active + seconds left +
-- which phase it is in ("idle", "warn" or "sweep"), so the banner can
-- show a different line per phase.
GameState.wave = { active = false, left = 0, phase = "idle" }

-- newPlayer builds a fresh record for a player who just joined.
function GameState.newPlayer(userId, plotIndex)
	return {
		userId = userId,
		plotIndex = plotIndex,
		money = GameConfig.economy.startMoney,
		earned = 0,
		rebirths = 0,
		levels = { IncomeBoost = 0, SpeedBoots = 0, ExtraSlot = 0 },
		lockedUntil = 0,
		lockReadyAt = 0,
		slowedUntil = 0, -- the tsunami sets this; StealSystem slows the player until it passes
		slots = {}, -- slot index -> brainrot Model (or nil)
	}
end

-- takePlot hands the next free plot to a player, or nil when full.
function GameState.takePlot(userId)
	for index = 1, GameConfig.plots.count do
		if GameState.plots[index] == nil then
			GameState.plots[index] = userId
			return index
		end
	end
	return nil
end

-- freePlot frees a plot and every brainrot standing on it. A brainrot
-- currently carried by another player is left alone: destroying it
-- mid-carry would make it vanish from the thief's hands.
function GameState.freePlot(plotIndex)
	GameState.plots[plotIndex] = nil
	for model, record in pairs(GameState.brainrots) do
		if record.plot == plotIndex and record.state ~= "walking" and record.state ~= "carried" then
			GameState.brainrots[model] = nil
			model:Destroy()
		end
	end
end

-- forPlayer returns the record for a player, or nil.
function GameState.forPlayer(userId)
	return GameState.players[userId]
end

-- forPlot returns the record of the player who owns a plot.
function GameState.forPlot(plotIndex)
	local userId = GameState.plots[plotIndex]
	if userId == nil then
		return nil
	end
	return GameState.players[userId]
end

-- credit pays a player (income, refunds). Never goes through charge.
function GameState.credit(data, amount)
	data.money = data.money + amount
	data.earned = data.earned + amount
end

-- charge takes money for a purchase. Returns false when the player is short.
function GameState.charge(data, amount)
	if data.money < amount then
		return false
	end
	data.money = data.money - amount
	return true
end

-- incomeBoost is the permanent multiplier: rebirths and upgrades.
function GameState.incomeBoost(data)
	local boost = GameConfig.rebirth.incomeTimes ^ data.rebirths
	boost = boost * (1 + data.levels.IncomeBoost * GameConfig.shop.IncomeBoost.income)
	return boost
end

-- incomePerSecond is the whole plot's tick: every owned brainrot's rate,
-- times the player's multiplier.
function GameState.incomePerSecond(data)
	local total = 0
	for _, model in pairs(data.slots) do
		if model ~= nil then
			local record = GameState.brainrots[model]
			if record ~= nil then
				total = total + record.rate
			end
		end
	end
	return total * GameState.incomeBoost(data)
end

-- tickIncome pays every player one second of income.
function GameState.tickIncome()
	for _, data in pairs(GameState.players) do
		local income = GameState.incomePerSecond(data)
		if income > 0 then
			GameState.credit(data, income)
		end
	end
end

-- slotLimit is how many brainrots a plot can hold right now.
function GameState.slotLimit(data)
	local limit = GameConfig.plots.startSlots
	limit = limit + data.rebirths * GameConfig.rebirth.bonusSlots
	limit = limit + data.levels.ExtraSlot * GameConfig.shop.ExtraSlot.slots
	return math.min(limit, GameConfig.plots.maxSlots)
end

-- firstOpenSlot returns the first empty slot index, or nil when the plot is full.
function GameState.firstOpenSlot(data)
	local limit = GameState.slotLimit(data)
	for index = 1, limit do
		if data.slots[index] == nil then
			return index
		end
	end
	return nil
end

-- slotWorldPos is the world position of one slot of one plot.
-- Slots sit on a five-by-three grid over the 22-stud floor, so every
-- unlocked slot (up to 14) has its own pad on the floor: no slot shares
-- another's position and none lands outside the base.
function GameState.slotWorldPos(plotIndex, slotIndex)
	local centre = GameConfig.plots.centres[plotIndex]
	local offset = GameConfig.plots.slotOffsets[slotIndex]
	return Vector3.new(centre[1] + offset[1], 0, centre[2] + offset[2])
end

-- parkPosition is where a parked brainrot stands: its slot, on the floor
-- (top y=1) with its torso 1.6 * size above it. A carried model hangs five
-- studs over its thief's head, so its current height is useless here —
-- every park site uses this one rule instead of the model's Y.
function GameState.parkPosition(plotIndex, slotIndex, characterId)
	local size = 1
	local character = BrainrotCatalog.find(characterId)
	if character ~= nil then
		size = character.size
	end
	local ground = GameState.slotWorldPos(plotIndex, slotIndex)
	return Vector3.new(ground.X, 1 + 1.6 * size, ground.Z)
end

-- track records a new brainrot Model and hands it a unique id.
function GameState.track(model, characterId, mutation)
	local character = BrainrotCatalog.find(characterId)
	assert(character ~= nil, "unknown character " .. tostring(characterId))
	local record = {
		id = GameState.nextId,
		model = model,
		characterId = characterId,
		mutation = mutation,
		rate = BrainrotCatalog.incomeOf(character, mutation),
		owner = 0,
		plot = 0,
		slot = 0,
		state = "walking", -- walking | toSlot | owned | carried
		carriedBy = 0,
		fromOwner = 0,
		fromSlot = 0,
	}
	GameState.nextId = GameState.nextId + 1
	GameState.brainrots[model] = record
	return record
end

-- setState moves a brainrot between walking, toSlot, owned, carried.
function GameState.setState(model, state)
	local record = GameState.brainrots[model]
	if record ~= nil then
		record.state = state
	end
end

-- park parks a brainrot on one of its owner's slots.
function GameState.park(data, model, slotIndex)
	data.slots[slotIndex] = model
	local record = GameState.brainrots[model]
	if record ~= nil then
		record.owner = data.userId
		record.plot = data.plotIndex
		record.slot = slotIndex
		record.state = "owned"
	end
end

-- unpark lifts a brainrot out of its slot (stolen, or reclaimed by its owner).
function GameState.unpark(data, model)
	for index, held in pairs(data.slots) do
		if held == model then
			data.slots[index] = nil
			return index
		end
	end
	return 0
end

-- upgradePrice is the price of the next level of one upgrade.
function GameState.upgradePrice(data, upgradeId)
	local def = GameConfig.shop[upgradeId]
	local level = data.levels[upgradeId] or 0
	return def.baseCost * (def.growth ^ level)
end

-- buyUpgrade buys one level when the player can afford it and the cap
-- is not reached. Returns true and the new level, or false and why not.
function GameState.buyUpgrade(data, upgradeId)
	local def = GameConfig.shop[upgradeId]
	if def == nil then
		return false, "unknown upgrade"
	end
	local level = data.levels[upgradeId] or 0
	if level >= def.max then
		return false, "max level"
	end
	local cost = GameState.upgradePrice(data, upgradeId)
	if not GameState.charge(data, cost) then
		return false, "not enough money"
	end
	data.levels[upgradeId] = level + 1
	return true, level + 1
end

-- rebirthReady is true once the player has earned enough in total.
function GameState.rebirthReady(data)
	local next = data.rebirths + 1
	local needed = GameConfig.rebirth.needed[next]
	if needed == nil then
		return false
	end
	return data.earned >= needed
end

-- rebirth resets money and brainrots and grants the permanent multiplier.
-- Returns false when the player has not earned enough yet.
function GameState.rebirth(data)
	if not GameState.rebirthReady(data) then
		return false
	end
	for _, model in pairs(data.slots) do
		if model ~= nil then
			GameState.brainrots[model] = nil
			model:Destroy()
		end
	end
	data.slots = {}
	data.money = GameConfig.economy.startMoney
	data.rebirths = data.rebirths + 1
	return true
end

-- speedFor is the player's current speed: boots, minus the carry slow.
function GameState.speedFor(data, carrying)
	local speed = GameConfig.movement.walkSpeed
	speed = speed + data.levels.SpeedBoots * GameConfig.shop.SpeedBoots.speed
	if carrying then
		speed = speed * GameConfig.theft.carrySlow
	end
	return speed
end

-- lockPlot locks the player's plot for lockSeconds. Returns false when the
-- lock is already up or still cooling down.
function GameState.lockPlot(data)
	local now = os.clock()
	if now < data.lockedUntil then
		return false, "already locked"
	end
	if now < data.lockReadyAt then
		return false, "cooling down"
	end
	if not GameState.charge(data, GameConfig.theft.lockCost) then
		return false, "not enough money"
	end
	data.lockedUntil = now + GameConfig.theft.lockSeconds
	data.lockReadyAt = now + GameConfig.theft.lockSeconds + GameConfig.theft.cooldownSeconds
	return true, GameConfig.theft.lockSeconds
end

-- plotLocked is true while a plot's lock is up.
function GameState.plotLocked(data)
	return os.clock() < data.lockedUntil
end

-- lockLeft is the seconds left on the lock, or 0.
function GameState.lockLeft(data)
	return math.max(0, data.lockedUntil - os.clock())
end

-- cooldownLeft is the seconds until the lock can be bought again.
function GameState.cooldownLeft(data)
	return math.max(0, data.lockReadyAt - os.clock())
end

return GameState

