-- BrainrotFactory: builds a walking brainrot character Model from one catalog entry.
-- Every character shares one skeleton — torso, head, eyes, feet, one
-- accessory, one name label — painted and scaled from the catalog, so the
-- whole cast stays readable at a glance and cheap to spawn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared modules live under ReplicatedStorage, not under ServerScriptService,
-- so they are reached through the service, never through script.Parent.
local BrainrotCatalog = require(ReplicatedStorage.Shared.BrainrotCatalog)
local FormatUtil = require(ReplicatedStorage.Shared.FormatUtil)

local BrainrotFactory = {}

-- part stamps out one anchored, non-colliding piece of a character.
local function part(name, size, tint, shape)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Color = tint
	piece.Shape = shape or Enum.PartType.Block
	piece.Material = Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = true
	piece.CanTouch = true
	return piece
end

-- place puts a piece relative to an anchor CFrame and parents it to the model.
local function place(model, piece, anchor, offset, rotation)
	piece.CFrame = anchor * CFrame.new(offset) * (rotation or CFrame.new())
	piece.Parent = model
	return piece
end

-- PROPS builds one accessory by kind. Each entry gets the model, the torso
-- and head CFrames, the scale and the body tint, and bolts its prop on.
local PROPS = {}

PROPS.Katana = function(model, torsoCf, headCf, scale, tint)
	local blade = part("KatanaBlade", Vector3.new(0.25, 3.2 * scale, 0.7), Color3.fromRGB(220, 220, 230))
	place(model, blade, torsoCf, Vector3.new(1.6 * scale, 0.5 * scale, 0), CFrame.Angles(0, 0, math.rad(-30)))
	local grip = part("KatanaGrip", Vector3.new(0.3, 0.9 * scale, 0.3), Color3.fromRGB(40, 20, 10))
	place(model, grip, torsoCf, Vector3.new(1.05 * scale, -0.9 * scale, 0), CFrame.Angles(0, 0, math.rad(-30)))
end

PROPS.Coffee = function(model, torsoCf, headCf, scale, tint)
	-- A cylinder stands upright with no rotation: its axis is already Y.
	local cup = part("CoffeeCup", Vector3.new(0.9 * scale, 1.1 * scale, 0.9 * scale), Color3.fromRGB(250, 240, 220), Enum.PartType.Cylinder)
	place(model, cup, headCf, Vector3.new(0, 1.2 * scale, 0))
end

PROPS.Bubble = function(model, torsoCf, headCf, scale, tint)
	local dome = part("HelmetDome", Vector3.new(2.6 * scale, 2.6 * scale, 2.6 * scale), Color3.fromRGB(240, 250, 255), Enum.PartType.Ball)
	dome.Transparency = 0.35
	place(model, dome, headCf, Vector3.new(0, 0, 0))
end

PROPS.Tea = function(model, torsoCf, headCf, scale, tint)
	local glass = part("TeaGlass", Vector3.new(1.4 * scale, 2.6 * scale, 1.4 * scale), Color3.fromRGB(230, 150, 60), Enum.PartType.Cylinder)
	glass.Transparency = 0.25
	place(model, glass, torsoCf, Vector3.new(1.8 * scale, 0, 0))
	local straw = part("Straw", Vector3.new(0.2, 1.6 * scale, 0.2), Color3.fromRGB(255, 80, 120))
	place(model, straw, glass.CFrame, Vector3.new(0, 1.6 * scale, 0), CFrame.Angles(0, 0, math.rad(15)))
end

PROPS.Wings = function(model, torsoCf, headCf, scale, tint)
	for _, side in ipairs({ -1, 1 }) do
		local wing = part("Wing", Vector3.new(0.2, 1.6 * scale, 2.4 * scale), Color3.fromRGB(255, 255, 255))
		wing.Transparency = 0.15
		place(model, wing, torsoCf, Vector3.new(side * 1.5 * scale, 0.6 * scale, -0.6 * scale), CFrame.Angles(math.rad(25), 0, side * math.rad(-35)))
	end
end

PROPS.Beak = function(model, torsoCf, headCf, scale, tint)
	local beak = part("Beak", Vector3.new(0.8 * scale, 0.5 * scale, 1.0 * scale), Color3.fromRGB(255, 140, 0), Enum.PartType.Wedge)
	place(model, beak, headCf, Vector3.new(0, -0.2 * scale, 1.1 * scale))
end

PROPS.Guitar = function(model, torsoCf, headCf, scale, tint)
	local body = part("GuitarBody", Vector3.new(1.2 * scale, 1.6 * scale, 0.5), Color3.fromRGB(140, 90, 40), Enum.PartType.Cylinder)
	place(model, body, torsoCf, Vector3.new(1.5 * scale, -0.3 * scale, 0), CFrame.Angles(0, 0, math.rad(90)))
	local neck = part("GuitarNeck", Vector3.new(0.25, 1.8 * scale, 0.25), Color3.fromRGB(90, 60, 30))
	place(model, neck, torsoCf, Vector3.new(1.5 * scale, 1.3 * scale, 0), CFrame.Angles(0, 0, math.rad(-20)))
end

PROPS.Crown = function(model, torsoCf, headCf, scale, tint)
	local crown = part("Crown", Vector3.new(1.4 * scale, 0.7 * scale, 1.4 * scale), Color3.fromRGB(255, 215, 0), Enum.PartType.Cylinder)
	place(model, crown, headCf, Vector3.new(0, 1.3 * scale, 0))
end

PROPS.Spark = function(model, torsoCf, headCf, scale, tint)
	local bolt = part("LightningBolt", Vector3.new(0.3, 2.6 * scale, 0.3), Color3.fromRGB(255, 240, 0))
	place(model, bolt, torsoCf, Vector3.new(1.7 * scale, 0.8 * scale, 0), CFrame.Angles(0, 0, math.rad(35)))
end

PROPS.Pot = function(model, torsoCf, headCf, scale, tint)
	local pot = part("CookingPot", Vector3.new(1.8 * scale, 1.0 * scale, 1.8 * scale), Color3.fromRGB(60, 60, 70), Enum.PartType.Cylinder)
	place(model, pot, headCf, Vector3.new(0, 1.2 * scale, 0))
end

-- hangLabel hangs the readable name, rarity, income and owner over the
-- character. The rate stays on the label after a purchase: the owner gets
-- its own fourth row instead of overwriting the money-per-second.
local function hangLabel(model, character, mutation, rate)
	local mutationData = BrainrotCatalog.MUTATIONS[mutation]
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BrainrotLabel"
	billboard.Size = UDim2.new(0, 240, 0, 108)
	billboard.ExtentsOffsetWorldSpace = Vector3.new(0, 4.4 * character.size, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	-- The Adornee is the character's torso, stated outright instead of
	-- leaning on Roblox's parent-Model default.
	billboard.Adornee = model.PrimaryPart

	local function row(name, text, tint, y, height)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.new(1, 0, 0, height)
		label.Position = UDim2.new(0, 0, 0, y)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = tint
		label.TextStrokeTransparency = 0
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
		label.Parent = billboard
		return label
	end

	row("NameLabel", character.display, Color3.fromRGB(255, 255, 255), 0, 34)
	local tag = mutationData.tag
	if tag ~= "" then
		tag = " " .. tag
	end
	row("RarityLabel", character.tier .. tag, BrainrotCatalog.tierColor(character.tier), 34, 24)
	row("RateLabel", FormatUtil.perSecond(rate), Color3.fromRGB(120, 255, 120), 58, 26)
	row("OwnerLabel", "", Color3.fromRGB(205, 205, 205), 84, 24)

	billboard.Parent = model
	return billboard
end

-- buildOne assembles one character Model at a position, facing +Z.
-- The model is anchored and moved by CFrame only, never by physics.
function BrainrotFactory.buildOne(characterId, mutation, position)
	local character = BrainrotCatalog.find(characterId)
	assert(character ~= nil, "unknown character " .. tostring(characterId))
	local rate = BrainrotCatalog.incomeOf(character, mutation)
	local scale = character.size
	local model = Instance.new("Model")
	model.Name = characterId

	local torso = part("Body", Vector3.new(2.2 * scale, 2.2 * scale, 1.6 * scale), character.tint)
	torso.CFrame = CFrame.new(position) * CFrame.new(0, 1.6 * scale, 0)
	torso.Parent = model
	model.PrimaryPart = torso

	local head = part("Head", Vector3.new(1.7 * scale, 1.5 * scale, 1.5 * scale), character.tint)
	head.CFrame = torso.CFrame * CFrame.new(0, 1.85 * scale, 0)
	head.Parent = model

	for _, side in ipairs({ -1, 1 }) do
		local eye = part("Eye", Vector3.new(0.3, 0.45, 0.2), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
		eye.CFrame = head.CFrame * CFrame.new(side * 0.45 * scale, 0.15 * scale, 0.8 * scale)
		eye.Parent = model
		local foot = part("Foot", Vector3.new(0.8 * scale, 0.5 * scale, 1.1 * scale), Color3.fromRGB(40, 25, 15))
		foot.CFrame = torso.CFrame * CFrame.new(side * 0.55 * scale, -1.3 * scale, 0.2 * scale)
		foot.Parent = model
	end

	local propBuilder = PROPS[character.prop]
	if propBuilder ~= nil then
		propBuilder(model, torso.CFrame, head.CFrame, scale, character.tint)
	end
	hangLabel(model, character, mutation, rate)

	model:SetAttribute("CharacterId", characterId)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Rate", rate)
	model:SetAttribute("Price", character.cost)
	return model
end

-- setSubtext writes the owner line under the name: empty while the
-- brainrot walks the belt for sale, "Owned by <name>" once it lives on
-- a base. The rate row is never touched, so name, rarity and $/s stay
-- readable on a developed base.
function BrainrotFactory.setSubtext(model, text)
	local billboard = model:FindFirstChild("BrainrotLabel")
	if billboard == nil then
		return
	end
	local ownerLabel = billboard:FindFirstChild("OwnerLabel")
	if ownerLabel ~= nil then
		ownerLabel.Text = text
	end
end

return BrainrotFactory

