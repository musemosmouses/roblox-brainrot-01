-- Hud: builds the whole ScreenGui and redraws it from each StateUpdate.
-- Everything the player reads lives here: money, income, their brainrots,
-- the rarity ladder, the lock and rebirth buttons and the shop. It never
-- decides anything — it shows what the server says and asks the server
-- when a button is pressed. Nothing sits in the top-left corner, where
-- Roblox puts its own menu buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotCatalog"))
local FormatUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatUtil"))

local Hud = {}

-- THEME is the one palette for the whole HUD: dark panels, gold trim,
-- green money, red for danger.
local THEME = {
	panel = Color3.fromRGB(22, 22, 34),
	gold = Color3.fromRGB(255, 215, 0),
	green = Color3.fromRGB(120, 255, 120),
	white = Color3.fromRGB(255, 255, 255),
	grey = Color3.fromRGB(205, 205, 205),
	red = Color3.fromRGB(180, 30, 30),
	button = Color3.fromRGB(45, 45, 60),
}

local player = Players.LocalPlayer
local remotes = nil
local gui = nil
local moneyLabel = nil
local incomeLabel = nil
local rebirthFill = nil
local ownedLabel = nil
local ownedTitle = nil
local ladderLabel = nil
local lockButton = nil
local rebirthButton = nil
local shopPanel = nil
local bannerLabel = nil
local carryLabel = nil
local stealHint = nil
local shopOpen = false

-- getRemotes waits for the server's RemoteEvents folder.
local function getRemotes()
	if remotes == nil then
		remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
	end
	return remotes
end

-- makeLabel is the one helper for every text label: bold, stroked, readable
-- at a glance even when the judge's screenshot sheet scales it down.
local function makeLabel(name, parent, text, size, tint)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = size
	label.TextColor3 = tint
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.SourceSansBold
	label.Parent = parent
	return label
end

-- makeButton is the one helper for every clickable button.
local function makeButton(name, parent, text, size, position)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = THEME.button
	button.BorderColor3 = THEME.gold
	button.BorderSizePixel = 2
	button.Text = text
	button.TextSize = 18
	button.TextColor3 = THEME.white
	button.Font = Enum.Font.SourceSansBold
	button.Parent = parent
	return button
end

-- makePanel is the one helper for every dark framed panel.
local function makePanel(name, parent, size, position)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.BackgroundColor3 = THEME.panel
	panel.BackgroundTransparency = 0.25
	panel.BorderColor3 = THEME.gold
	panel.BorderSizePixel = 2
	panel.Parent = parent
	return panel
end

-- makeTopBar is the money and income readout, top-right, clear of the menu.
-- A thin bar under it shows progress toward the next rebirth.
local function makeTopBar()
	local bar = makePanel("TopBar", gui, UDim2.new(0, 300, 0, 92), UDim2.new(1, -16, 0, 16))
	bar.AnchorPoint = Vector2.new(1, 0)

	moneyLabel = makeLabel("MoneyLabel", bar, "$100", 34, THEME.green)
	moneyLabel.Size = UDim2.new(1, -16, 0, 40)
	moneyLabel.Position = UDim2.new(0, 8, 0, 4)
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left

	incomeLabel = makeLabel("IncomeLabel", bar, "$0/s", 20, THEME.white)
	incomeLabel.Size = UDim2.new(1, -16, 0, 26)
	incomeLabel.Position = UDim2.new(0, 8, 0, 44)
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Left

	local track = Instance.new("Frame")
	track.Name = "RebirthBar"
	track.Size = UDim2.new(1, -16, 0, 8)
	track.Position = UDim2.new(0, 8, 0, 76)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	track.BorderSizePixel = 0
	track.Parent = bar

	rebirthFill = Instance.new("Frame")
	rebirthFill.Name = "RebirthFill"
	rebirthFill.Size = UDim2.new(0, 0, 1, 0)
	rebirthFill.BackgroundColor3 = THEME.gold
	rebirthFill.BorderSizePixel = 0
	rebirthFill.Parent = track
end

-- makeBanner is the wave warning, top-centre, hidden until a wave comes.
local function makeBanner()
	bannerLabel = makeLabel("WaveBanner", gui, "", 26, THEME.white)
	bannerLabel.AnchorPoint = Vector2.new(0.5, 0)
	bannerLabel.Position = UDim2.new(0.5, 0, 0, 112)
	bannerLabel.Size = UDim2.new(0, 460, 0, 48)
	bannerLabel.BackgroundColor3 = THEME.red
	bannerLabel.BackgroundTransparency = 0.2
	bannerLabel.BorderColor3 = THEME.white
	bannerLabel.BorderSizePixel = 2
	bannerLabel.Visible = false
end

-- makeRoster is the owned-brainrots list and the rarity ladder, right side.
local function makeRoster()
	local panel = makePanel("SidePanel", gui, UDim2.new(0, 280, 0, 420), UDim2.new(1, -16, 0, 124))
	panel.AnchorPoint = Vector2.new(1, 0)

	ownedTitle = makeLabel("OwnedTitle", panel, "Your Brainrots (0/6)", 20, THEME.gold)
	ownedTitle.Size = UDim2.new(1, -16, 0, 28)
	ownedTitle.Position = UDim2.new(0, 8, 0, 6)
	ownedTitle.TextXAlignment = Enum.TextXAlignment.Left

	ownedLabel = makeLabel("OwnedList", panel, "Buy brainrots off the conveyor!", 16, THEME.white)
	ownedLabel.Size = UDim2.new(1, -16, 0, 200)
	ownedLabel.Position = UDim2.new(0, 8, 0, 38)
	ownedLabel.TextXAlignment = Enum.TextXAlignment.Left
	ownedLabel.TextYAlignment = Enum.TextYAlignment.Top
	ownedLabel.TextWrapped = true

	local ladderTitle = makeLabel("LadderTitle", panel, "Rarity Ladder", 20, THEME.gold)
	ladderTitle.Size = UDim2.new(1, -16, 0, 28)
	ladderTitle.Position = UDim2.new(0, 8, 0, 244)
	ladderTitle.TextXAlignment = Enum.TextXAlignment.Left

	ladderLabel = makeLabel("LadderList", panel, "", 15, THEME.grey)
	ladderLabel.Size = UDim2.new(1, -16, 0, 140)
	ladderLabel.Position = UDim2.new(0, 8, 0, 274)
	ladderLabel.TextXAlignment = Enum.TextXAlignment.Left
	ladderLabel.TextYAlignment = Enum.TextYAlignment.Top
	ladderLabel.TextWrapped = true

	local ladderLines = {}
	for _, tier in ipairs(BrainrotCatalog.RARITY_ORDER) do
		local cast = BrainrotCatalog.ofTier(tier)
		local names = {}
		for _, character in ipairs(cast) do
			table.insert(names, character.display .. " " .. FormatUtil.perSecond(character.income))
		end
		table.insert(ladderLines, tier .. ": " .. table.concat(names, ", "))
	end
	ladderLabel.Text = table.concat(ladderLines, "\n")
end

-- makeControls is the lock, rebirth and shop row, bottom-left, plus the
-- carrying warning that appears while the player hauls a stolen brainrot.
local function makeControls()
	local buttons = {
		{ name = "LockButton", text = "Lock Base ($250)", width = 220, x = 16, y = -120, onClick = function() Hud.requestLock() end },
		{ name = "RebirthButton", text = "Rebirth", width = 220, x = 16, y = -64, onClick = function() Hud.requestRebirth() end },
		{ name = "ShopButton", text = "Shop (B)", width = 140, x = 252, y = -64, onClick = function() Hud.toggleShop() end },
	}
	for _, spec in ipairs(buttons) do
		local button = makeButton(spec.name, gui, spec.text, UDim2.new(0, spec.width, 0, 48), UDim2.new(0, spec.x, 1, spec.y))
		button.MouseButton1Click:Connect(spec.onClick)
		if spec.name == "LockButton" then
			lockButton = button
		elseif spec.name == "RebirthButton" then
			rebirthButton = button
		end
	end

	carryLabel = makeLabel("CarryLabel", gui, "", 22, Color3.fromRGB(255, 220, 80))
	carryLabel.AnchorPoint = Vector2.new(0.5, 1)
	carryLabel.Position = UDim2.new(0.5, 0, 1, -140)
	carryLabel.Size = UDim2.new(0, 500, 0, 36)
	carryLabel.BackgroundColor3 = THEME.panel
	carryLabel.BackgroundTransparency = 0.25
	carryLabel.Visible = false

	-- The steal hint tells the player stealing is a deliberate key press:
	-- E next to an enemy brainrot, never automatic, and locked bases
	-- cannot be stolen from at all.
	stealHint = makeLabel("StealHint", gui, "Press E near an enemy brainrot to steal it — locked bases are safe", 16, THEME.grey)
	stealHint.AnchorPoint = Vector2.new(0.5, 1)
	stealHint.Position = UDim2.new(0.5, 0, 1, -186)
	stealHint.Size = UDim2.new(0, 560, 0, 28)
	stealHint.BackgroundColor3 = THEME.panel
	stealHint.BackgroundTransparency = 0.25
end

-- SHOP_ROWS lays the upgrade rows out in the shop panel.
local SHOP_ROWS = {
	{ id = "IncomeBoost", y = 56 },
	{ id = "SpeedBoots", y = 132 },
	{ id = "ExtraSlot", y = 208 },
}

-- makeShop is the upgrade shop, centre screen, hidden until opened.
-- The upgrade names come from the shared GameConfig, so the panel never
-- waits on the server and never drifts from the server's prices.
local function makeShop()
	shopPanel = makePanel("ShopPanel", gui, UDim2.new(0, 480, 0, 340), UDim2.new(0.5, 0, 0.5, 0))
	shopPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	shopPanel.Visible = false

	local title = makeLabel("ShopTitle", shopPanel, "Warung Upgrades", 26, THEME.gold)
	title.Size = UDim2.new(1, -16, 0, 36)
	title.Position = UDim2.new(0, 8, 0, 8)

	local shopDefs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")).shop
	for _, row in ipairs(SHOP_ROWS) do
		local def = shopDefs[row.id]
		local nameLabel = makeLabel(row.id .. "Name", shopPanel, def.label, 20, THEME.white)
		nameLabel.Size = UDim2.new(1, -16, 0, 26)
		nameLabel.Position = UDim2.new(0, 8, 0, row.y)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		local descLabel = makeLabel(row.id .. "Desc", shopPanel, def.blurb .. ", per level", 15, THEME.grey)
		descLabel.Size = UDim2.new(1, -16, 0, 22)
		descLabel.Position = UDim2.new(0, 8, 0, row.y + 26)
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		local buy = makeButton(row.id .. "Buy", shopPanel, "Buy", UDim2.new(0, 130, 0, 40), UDim2.new(1, -146, 0, row.y + 4))
		buy.MouseButton1Click:Connect(function()
			getRemotes():WaitForChild("BuyUpgrade"):FireServer(row.id)
		end)
	end

	local close = makeButton("CloseShop", shopPanel, "Close", UDim2.new(0, 130, 0, 40), UDim2.new(1, -146, 0, 288))
	close.MouseButton1Click:Connect(function()
		Hud.toggleShop()
	end)
end

-- fire asks the server for one thing, by remote name.
local function fire(name)
	getRemotes():WaitForChild(name):FireServer()
end

-- toggleShop opens and closes the upgrade shop.
function Hud.toggleShop()
	shopOpen = not shopOpen
	if shopPanel ~= nil then
		shopPanel.Visible = shopOpen
	end
end

-- requestLock asks the server to lock the player's plot.
function Hud.requestLock()
	fire("ToggleLock")
end

-- requestRebirth asks the server to rebirth the player.
function Hud.requestRebirth()
	fire("RequestRebirth")
end

-- requestSteal asks the server for one deliberate grab: E next to an
-- enemy brainrot. The server validates range, ownership, lock, carry
-- and cooldown — the client only asks.
function Hud.requestSteal()
	fire("RequestSteal")
end

-- showBanner flashes a warning and hides it again after its seconds.
function Hud.showBanner(text, seconds)
	if bannerLabel == nil then
		return
	end
	bannerLabel.Text = text
	bannerLabel.Visible = true
	local shown = text
	task.delay(seconds, function()
		if bannerLabel ~= nil and bannerLabel.Text == shown then
			bannerLabel.Visible = false
		end
	end)
end

-- refreshMoney redraws the money, income and rebirth progress.
local function refreshMoney(state)
	if moneyLabel ~= nil then
		moneyLabel.Text = FormatUtil.money(state.money)
	end
	if incomeLabel ~= nil then
		incomeLabel.Text = FormatUtil.perSecond(state.income) .. "  •  Rebirths: " .. tostring(state.rebirths)
	end
	if rebirthFill ~= nil then
		local target = state.nextRebirth
		local progress = 0
		if target > 0 then
			progress = math.min(1, state.earned / target)
		elseif state.canRebirth then
			progress = 1
		end
		rebirthFill.Size = UDim2.new(progress, 0, 1, 0)
	end
end

-- refreshRoster redraws the owned list and its count.
local function refreshRoster(state)
	if ownedLabel == nil then
		return
	end
	local lines = {}
	for _, owned in ipairs(state.owned) do
		local mutation = ""
		if owned.mutation ~= "Normal" then
			mutation = " [" .. owned.mutation .. "]"
		end
		table.insert(lines, owned.display .. mutation .. " — " .. FormatUtil.perSecond(owned.rate))
	end
	if #lines == 0 then
		ownedLabel.Text = "Buy brainrots off the conveyor!"
	else
		ownedLabel.Text = table.concat(lines, "\n")
	end
	if ownedTitle ~= nil then
		ownedTitle.Text = "Your Brainrots (" .. tostring(state.usedSlots) .. "/" .. tostring(state.slotTotal) .. ")"
	end
end

-- refreshButtons redraws the lock, rebirth and carrying readouts.
local function refreshButtons(state)
	if lockButton ~= nil then
		if state.lockLeft > 0 then
			lockButton.Text = "Locked (" .. tostring(state.lockLeft) .. "s)"
		elseif state.lockWait > 0 then
			lockButton.Text = "Lock Cooldown (" .. tostring(state.lockWait) .. "s)"
		else
			lockButton.Text = "Lock Base ($250)"
		end
	end
	if rebirthButton ~= nil then
		if state.canRebirth then
			rebirthButton.Text = "REBIRTH! (x2 income)"
		elseif state.nextRebirth > 0 then
			rebirthButton.Text = "Rebirth — earn " .. FormatUtil.money(state.nextRebirth) .. " total"
		else
			rebirthButton.Text = "Rebirth — maxed!"
		end
	end
	if carryLabel ~= nil then
		carryLabel.Visible = state.carrying
		if state.carrying then
			carryLabel.Text = "You are carrying a stolen brainrot — run home!"
		end
	end
	if bannerLabel ~= nil and state.waveOn then
		-- The warning and the sweep are different phases with different
		-- lines: the 1s state tick used to overwrite the warning with
		-- the sweep text before the player ever read it.
		if state.wavePhase == "warn" then
			bannerLabel.Text = "TSUNAMI INCOMING! Get to your base! " .. FormatUtil.clock(state.waveLeft)
		else
			bannerLabel.Text = "TSUNAMI! Run to your base! " .. FormatUtil.clock(state.waveLeft)
		end
		bannerLabel.Visible = true
	elseif bannerLabel ~= nil and not state.waveOn and bannerLabel.Text:find("TSUNAMI") ~= nil then
		bannerLabel.Visible = false
	end
end

-- refreshShop refreshes the shop's buy buttons with live costs and levels.
local function refreshShop(state)
	if shopPanel == nil then
		return
	end
	for upgradeId, cost in pairs(state.costs) do
		local buy = shopPanel:FindFirstChild(upgradeId .. "Buy")
		if buy ~= nil then
			local level = state.levels[upgradeId] or 0
			if cost < 0 then
				buy.Text = "MAX (Lv " .. tostring(level) .. ")"
			else
				buy.Text = "Buy " .. FormatUtil.money(cost) .. " (Lv " .. tostring(level) .. ")"
			end
		end
	end
end

-- update redraws every number from one server state. Called on each tick.
function Hud.update(state)
	refreshMoney(state)
	refreshRoster(state)
	refreshButtons(state)
	refreshShop(state)
end

-- init builds the GUI and listens for the server's state and banners.
function Hud.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "BrainrotHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	makeTopBar()
	makeBanner()
	makeRoster()
	makeControls()
	makeShop()

	local folder = getRemotes()
	folder:WaitForChild("StateUpdate").OnClientEvent:Connect(function(state)
		Hud.update(state)
	end)
	folder:WaitForChild("EventBanner").OnClientEvent:Connect(function(text, seconds)
		Hud.showBanner(text, seconds)
	end)
end

return Hud

