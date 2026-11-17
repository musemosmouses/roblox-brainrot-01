-- Conveyor: spawns brainrots, walks them down the belt and sells them to players.
-- A brainrot walks from the spawn end to the despawn end; any player close
-- enough can buy it with its ProximityPrompt. Once bought it walks to a free
-- slot on the buyer's plot and starts earning.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared modules live under ReplicatedStorage, not under ServerScriptService,
-- so they are reached through the service, never through script.Parent.
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local BrainrotCatalog = require(ReplicatedStorage.Shared.BrainrotCatalog)
local FormatUtil = require(ReplicatedStorage.Shared.FormatUtil)
local GameState = require(script.Parent.GameState)
local BrainrotFactory = require(script.Parent.BrainrotFactory)

local Conveyor = {}

local walkers = nil
local roller = BrainrotCatalog.newRoller(GameConfig.spawnSeed)

-- walkersFolder is the Workspace folder every walking brainrot lives in.
function Conveyor.walkersFolder()
	if walkers == nil then
		walkers = Workspace:FindFirstChild("WalkingBrainrots")
		if walkers == nil then
			walkers = Instance.new("Folder")
			walkers.Name = "WalkingBrainrots"
			walkers.Parent = Workspace
		end
	end
	return walkers
end

-- walkerCount is how many brainrots are on the belt right now.
function Conveyor.walkerCount()
	local count = 0
	for _, record in pairs(GameState.brainrots) do
		if record.state == "walking" then
			count = count + 1
		end
	end
	return count
end

-- spawnOne rolls one character and puts it on the belt.
function Conveyor.spawnOne()
	if Conveyor.walkerCount() >= GameConfig.belt.maxWalkers then
		return nil
	end
	local character = BrainrotCatalog.rollOne(roller)
	local mutation = BrainrotCatalog.rollMutation(roller)
	local position = Vector3.new(GameConfig.belt.x, 1, GameConfig.belt.spawnZ)
	local model = BrainrotFactory.buildOne(character.id, mutation, position)
	model.Parent = Conveyor.walkersFolder()
	local record = GameState.track(model, character.id, mutation)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy"
	prompt.ObjectText = character.display .. " — " .. FormatUtil.money(character.cost)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		Conveyor.attemptPurchase(player, model)
	end)
	record.prompt = prompt
	return model
end

-- attemptPurchase sells a walking brainrot to a player: money out, slot in,
-- and the brainrot walks itself to its new home. Every check runs on the server.
function Conveyor.attemptPurchase(player, model)
	local record = GameState.brainrots[model]
	if record == nil or record.state ~= "walking" then
		return false
	end
	local data = GameState.forPlayer(player.UserId)
	if data == nil then
		return false
	end
	-- A visitor with no plot (all 8 taken) can watch but cannot buy.
	if data.plotIndex == 0 then
		return false
	end
	local character = BrainrotCatalog.find(record.characterId)
	if character == nil then
		return false
	end
	-- The prompt already limits range on an honest client, but the
	-- Triggered signal itself can be spoofed, so the server re-checks
	-- the buyer is really standing by the brainrot before charging.
	local primary = model.PrimaryPart
	if primary == nil then
		return false
	end
	local buyerRoot = nil
	if player.Character ~= nil then
		buyerRoot = player.Character:FindFirstChild("HumanoidRootPart")
	end
	if buyerRoot == nil then
		return false
	end
	local maxReach = 14
	if record.prompt ~= nil then
		maxReach = record.prompt.MaxActivationDistance
	end
	if (buyerRoot.Position - primary.Position).Magnitude > maxReach + 2 then
		return false
	end
	if not GameState.charge(data, character.cost) then
		return false
	end
	local slotIndex = GameState.firstOpenSlot(data)
	if slotIndex == nil then
		GameState.credit(data, character.cost)
		return false
	end
	record.state = "toSlot"
	record.owner = player.UserId
	record.plot = data.plotIndex
	record.slot = slotIndex
	record.target = GameState.slotWorldPos(data.plotIndex, slotIndex)
	if record.prompt ~= nil then
		record.prompt:Destroy()
		record.prompt = nil
	end
	BrainrotFactory.setSubtext(model, "Owned by " .. player.DisplayName)
	return true
end

-- walkToward steps a model toward a target at a speed and reports arrival.
local function walkToward(model, target, speed, dt)
	local primary = model.PrimaryPart
	local flat = target - primary.Position
	flat = Vector3.new(flat.X, 0, flat.Z)
	local distance = flat.Magnitude
	if distance < 1.5 then
		return true
	end
	local step = math.min(distance, speed * dt)
	local direction = flat / distance
	local nextPosition = primary.Position + direction * step
	local yaw = math.atan2(direction.X, direction.Z)
	model:PivotTo(CFrame.new(nextPosition) * CFrame.Angles(0, yaw, 0))
	return false
end

-- step advances every brainrot one tick: walkers go down the belt, bought
-- ones head for their slot, and finished ones despawn.
function Conveyor.step(dt)
	local gone = {}
	for model, record in pairs(GameState.brainrots) do
		if record.state == "walking" then
			local primary = model.PrimaryPart
			if primary == nil then
				table.insert(gone, model)
			else
				local nextPosition = primary.Position + Vector3.new(0, 0, GameConfig.belt.walkSpeed * dt)
				model:PivotTo(CFrame.new(nextPosition))
				if nextPosition.Z >= GameConfig.belt.despawnZ then
					table.insert(gone, model)
				end
			end
		elseif record.state == "toSlot" then
			local primary = model.PrimaryPart
			if primary == nil then
				table.insert(gone, model)
			elseif walkToward(model, record.target, GameConfig.belt.walkSpeed * 2, dt) then
				local data = GameState.forPlayer(record.owner)
				if data ~= nil then
					GameState.park(data, model, record.slot)
					-- Park on the floor, not at the slot's ground Y (0):
					-- the torso stands 1.6 * size above the floor top.
					model:PivotTo(CFrame.new(GameState.parkPosition(data.plotIndex, record.slot, record.characterId)))
				else
					table.insert(gone, model)
				end
			end
		end
	end
	for _, model in ipairs(gone) do
		GameState.brainrots[model] = nil
		model:Destroy()
	end
end

-- begin runs the spawn timer and the movement ticker forever.
function Conveyor.begin()
	task.spawn(function()
		while task.wait(GameConfig.belt.spawnEvery) do
			Conveyor.spawnOne()
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			Conveyor.step(now - last)
			last = now
		end
	end)
	-- Seed the belt so the first player sees brainrots at once.
	for _ = 1, 4 do
		Conveyor.spawnOne()
	end
end

return Conveyor

