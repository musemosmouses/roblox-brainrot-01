-- GameConfig: every tuning number for Brainrot Warung, grouped by system.
-- Nothing here talks to the network or the clock; the game reads these
-- numbers and nothing else decides its balance. The belt, the plots and the
-- spawn plaza live in default.project.json at the same coordinates, so the
-- code and the place always agree.

local GameConfig = {}

-- economy: what a new player starts with, and how often income ticks.
GameConfig.economy = {
	startMoney = 100,
	tickSeconds = 1,
}

-- belt: the conveyor down the middle of the map. Brainrots appear at
-- spawnZ, stroll toward despawnZ, and are gone past it.
GameConfig.belt = {
	x = 0,
	spawnZ = -100,
	despawnZ = 100,
	walkSpeed = 6, -- studs per second
	spawnEvery = 4, -- seconds between spawns
	maxWalkers = 14,
}

-- plots: 8 base plots, 4 on each side of the belt. Players claim them in
-- this order when they join. centres are {x, z} pairs; slot offsets are
-- {dx, dz} from the plot centre, five rows of three. A slot holds exactly
-- one brainrot.
GameConfig.plots = {
	count = 8,
	centres = {
		{ -32, -75 },
		{ -32, -25 },
		{ -32, 25 },
		{ -32, 75 },
		{ 32, -75 },
		{ 32, -25 },
		{ 32, 25 },
		{ 32, 75 },
	},
	floorSize = 22,
	-- slotOffsets is the five-by-three grid every base parks on: three
	-- columns (dx -6, 0, 6) by five rows (dz -8, -4, 0, 4, 8), so all 14
	-- slots sit on the 22-stud floor, each on its own pad.
	slotOffsets = {
		{ -6, -8 },
		{ 0, -8 },
		{ 6, -8 },
		{ -6, -4 },
		{ 0, -4 },
		{ 6, -4 },
		{ -6, 0 },
		{ 0, 0 },
		{ 6, 0 },
		{ -6, 4 },
		{ 0, 4 },
		{ 6, 4 },
		{ -6, 8 },
		{ 0, 8 },
	},
	startSlots = 6,
	maxSlots = 14,
}

-- theft: the lock costs money, holds for lockSeconds, then needs a cooldown
-- before it can be bought again. Carrying a stolen brainrot slows the thief.
-- A thief who loses a carry (reclaim, wave, no free slot) waits
-- grabCooldownSeconds before they can grab again, so a steal can never
-- ping-pong back the instant it is reclaimed.
GameConfig.theft = {
	lockCost = 250,
	lockSeconds = 60,
	cooldownSeconds = 120,
	carrySlow = 0.75,
	grabRange = 5,
	reclaimRange = 5,
	homeRange = 12,
	grabCooldownSeconds = 5,
}

-- tsunami: it warns, then a wall of water sweeps the map along X. A player
-- it catches is shoved back, drops what they carry and walks slowly.
GameConfig.tsunami = {
	everySeconds = 180,
	warnSeconds = 10,
	sweepSeconds = 12,
	halfWidth = 8,
	shoveStuds = 15,
	slowSeconds = 3,
	slowSpeed = 8,
}

-- movement: the base walk speed before boots and slows.
GameConfig.movement = {
	walkSpeed = 16,
}

-- rebirth: each rebirth resets money and brainrots but doubles all income
-- forever and adds two base slots. The ladder is the long-term goal.
GameConfig.rebirth = {
	needed = { 10000, 100000, 1000000, 10000000, 100000000 },
	incomeTimes = 2,
	bonusSlots = 2,
}

-- shop: upgrades bought with money. Each has a level cap and a cost that
-- doubles per level.
GameConfig.shop = {
	IncomeBoost = { label = "Income Boost", blurb = "+25% money per second", baseCost = 1000, growth = 2, max = 3, income = 0.25 },
	SpeedBoots = { label = "Speed Boots", blurb = "+4 walk speed", baseCost = 500, growth = 2, max = 2, speed = 4 },
	ExtraSlot = { label = "Extra Slot", blurb = "+1 brainrot slot on your base", baseCost = 2500, growth = 2, max = 3, slots = 1 },
}

-- spawnPoint: where new players appear, above the plaza at the south end.
GameConfig.spawnPoint = Vector3.new(0, 2, 140)

-- spawnSeed: the deterministic seed for the spawn roller. Same seed, same
-- sequence of rarities and mutations for every server that starts the game.
GameConfig.spawnSeed = 1337

return GameConfig

