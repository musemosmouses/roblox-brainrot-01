-- StealSystem: stealing, carrying, reclaiming and the plot lock that stops it.
-- Stealing is all distance checks on the server, never a client claim: a
-- thief picks a brainrot up by standing next to it and pressing E, carries
-- it home over their head, and the owner takes it back by touching the
-- thief. A locked plot cannot be stolen from at all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared modules live under ReplicatedStorage, not under ServerScriptService,
-- so they are reached through the service, never through script.Parent.
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameState = require(script.Parent.GameState)

local StealSystem = {}

-- carriedBy maps userId -> the record that player is carrying, or nothing.
local carriedBy = {}

-- grabCooldown maps userId -> the clock time before which that player may
-- not grab again. It is set whenever a player loses a carry, so a steal
-- can never ping-pong straight back after a reclaim.

-- carriedOf finds the brainrot one player is carrying, or nil.
function StealSystem.carriedOf(userId)
	return carriedBy[userId]
end

-- hasCarry is true while a player holds a stolen brainrot.
function StealSystem.hasCarry(userId)
	return carriedBy[userId] ~= nil
end

-- sendHome puts a carried brainrot back on its original owner's slot.
-- A thief who loses the carry waits out the grab cooldown first, and when
-- the original slot was refilled meanwhile the brainrot takes the owner's
-- first open slot instead of being destroyed.
function StealSystem.sendHome(record)
	if record.carriedBy ~= 0 then
		grabCooldown[record.carriedBy] = os.clock() + GameConfig.theft.grabCooldownSeconds
		carriedBy[record.carriedBy] = nil
	end
	local owner = GameState.forPlayer(record.fromOwner)
	if owner ~= nil then
		local slotIndex = nil
		if owner.slots[record.fromSlot] == nil then
			slotIndex = record.fromSlot
		else
			slotIndex = GameState.firstOpenSlot(owner)
		end
		if slotIndex ~= nil then
			GameState.park(owner, record.model, slotIndex)
			-- Park on the floor: the carried model hangs over the thief's
			-- head, so its current height would leave it floating.
			record.model:PivotTo(CFrame.new(GameState.parkPosition(owner.plotIndex, slotIndex, record.characterId)))
		else
			GameState.brainrots[record.model] = nil
			record.model:Destroy()
		end
	else
		GameState.brainrots[record.model] = nil
		record.model:Destroy()
	end
	record.carriedBy = 0
end

-- drop makes a player drop what they carry (the wave does this).
function StealSystem.drop(userId)
	local record = carriedBy[userId]
	if record ~= nil then
		StealSystem.sendHome(record)
	end
end

-- rootOf is a player's HumanoidRootPart, or nil.
local function rootOf(player)
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

-- grabAttempt lets a player grab one enemy brainrot by standing next to it
-- and pressing E. It only ever runs on the player's own request — nobody
-- steals by accident — and a thief who just lost a carry must wait out
-- the grab cooldown first. Locked plots are safe, a thief already carrying
-- cannot grab another, and a visitor with no plot of their own cannot
-- steal at all.
function StealSystem.grabAttempt(player, data)
	if data.plotIndex == 0 then
		return
	end
	if carriedBy[player.UserId] ~= nil then
		return
	end
	if os.clock() < (grabCooldown[player.UserId] or 0) then
		return
	end
	local root = rootOf(player)
	if root == nil then
		return
	end
	for model, record in pairs(GameState.brainrots) do
		if record.state == "owned" and record.owner ~= player.UserId then
			local owner = GameState.forPlayer(record.owner)
			if owner ~= nil and not GameState.plotLocked(owner) then
				local primary = model.PrimaryPart
				if primary ~= nil and (primary.Position - root.Position).Magnitude <= GameConfig.theft.grabRange then
					record.fromOwner = record.owner
					record.fromSlot = record.slot
					GameState.unpark(owner, model)
					record.state = "carried"
					record.carriedBy = player.UserId
					carriedBy[player.UserId] = record
					return
				end
			end
		end
	end
end

-- tickCarried moves every carried brainrot above its thief's head, claims
-- it when the thief reaches home, and lets the owner reclaim it by touch.
function StealSystem.tickCarried()
	for userId, record in pairs(carriedBy) do
		local thief = Players:GetPlayerByUserId(userId)
		local thiefRoot = nil
		if thief ~= nil then
			thiefRoot = rootOf(thief)
		end
		if thief == nil or thiefRoot == nil or record.model.Parent == nil then
			StealSystem.sendHome(record)
		else
			local primary = record.model.PrimaryPart
			if primary ~= nil then
				record.model:PivotTo(CFrame.new(thiefRoot.Position + Vector3.new(0, 5, 0)))
			end
			local thiefData = GameState.forPlayer(userId)
			if thiefData == nil or thiefData.plotIndex == 0 then
				StealSystem.sendHome(record)
			else
				local centre = GameConfig.plots.centres[thiefData.plotIndex]
				local home = Vector3.new(centre[1], 0, centre[2])
				if (thiefRoot.Position - home).Magnitude <= GameConfig.theft.homeRange then
					local slotIndex = GameState.firstOpenSlot(thiefData)
					if slotIndex ~= nil then
						carriedBy[userId] = nil
						GameState.park(thiefData, record.model, slotIndex)
						-- Park on the floor: the carried model hangs over the
						-- thief's head, so its current height would float it.
						record.model:PivotTo(CFrame.new(GameState.parkPosition(thiefData.plotIndex, slotIndex, record.characterId)))
						record.carriedBy = 0
					else
						StealSystem.sendHome(record)
					end
				else
					local owner = Players:GetPlayerByUserId(record.fromOwner)
					local ownerRoot = nil
					if owner ~= nil then
						ownerRoot = rootOf(owner)
					end
					if ownerRoot ~= nil and (ownerRoot.Position - thiefRoot.Position).Magnitude <= GameConfig.theft.reclaimRange then
						StealSystem.sendHome(record)
					end
				end
			end
		end
	end
end

-- tickSpeeds sets every player's speed from boots, carrying and the
-- wave slow, so no client ever decides how fast it moves.
function StealSystem.tickSpeeds()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = GameState.forPlayer(player.UserId)
		local character = player.Character
		if data ~= nil and character ~= nil then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid ~= nil then
				local speed = GameState.speedFor(data, carriedBy[player.UserId] ~= nil)
				if os.clock() < (data.slowedUntil or 0) then
					speed = math.min(speed, GameConfig.tsunami.slowSpeed)
				end
				humanoid.WalkSpeed = speed
			end
		end
	end
end

-- begin runs the steal heartbeat: carrying and speeds. Grabbing is never
-- automatic — it only happens when a player presses E (RequestSteal).
function StealSystem.begin()
	task.spawn(function()
		while true do
			task.wait(0.2)
			StealSystem.tickCarried()
			StealSystem.tickSpeeds()
		end
	end)
end

return StealSystem

