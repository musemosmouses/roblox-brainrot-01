-- BrainrotCatalog: the twelve original characters, the rarity ladder and the mutations.
-- Every character here is invented for this game, a warung shelf of absurd
-- Indonesian memes. Nothing in this cast comes from Steal a Brainrot or any
-- other game.

local SeededRng = require(script.Parent.SeededRng)

local BrainrotCatalog = {}

-- RARITIES, cheapest first. chance is the spawn weight; tint colours the
-- name label and the rarity badge on the character; rank orders the ladder.
BrainrotCatalog.RARITIES = {
	Common = { chance = 45, tint = Color3.fromRGB(130, 205, 95), rank = 1 },
	Rare = { chance = 25, tint = Color3.fromRGB(85, 165, 255), rank = 2 },
	Epic = { chance = 15, tint = Color3.fromRGB(185, 95, 255), rank = 3 },
	Legendary = { chance = 9, tint = Color3.fromRGB(255, 155, 45), rank = 4 },
	Mythic = { chance = 4.5, tint = Color3.fromRGB(255, 65, 85), rank = 5 },
	BrainrotGod = { chance = 1.5, tint = Color3.fromRGB(255, 215, 0), rank = 6 },
}
BrainrotCatalog.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "BrainrotGod" }

-- MUTATIONS multiply a character's income. A Golden Bebek Sakti earns twice
-- what a plain one does, and the label says so.
BrainrotCatalog.MUTATIONS = {
	Normal = { times = 1, chance = 86, tint = Color3.fromRGB(255, 255, 255), tag = "" },
	Golden = { times = 2, chance = 10, tint = Color3.fromRGB(255, 215, 0), tag = "GOLDEN" },
	Diamond = { times = 4, chance = 3, tint = Color3.fromRGB(145, 225, 255), tag = "DIAMOND" },
	Rainbow = { times = 8, chance = 1, tint = Color3.fromRGB(255, 115, 225), tag = "RAINBOW" },
}

-- The cast. cost is what the conveyor charges; income is the plain
-- (unmutated) money per second. tint paints the body and head; size grows
-- the rarer characters so the ladder is visible at a glance; prop names
-- the little accessory BrainrotFactory bolts on.
BrainrotCatalog.CHARACTERS = {
	{
		id = "BebekSakti",
		display = "Bebek Sakti",
		note = "A duck that grants wishes. The wishes are mostly about ducks.",
		tier = "Common",
		income = 3,
		cost = 45,
		tint = Color3.fromRGB(250, 215, 70),
		size = 1.0,
		prop = "Beak",
	},
	{
		id = "SandalJepitTerbang",
		display = "Sandal Jepit Terbang",
		note = "A flip-flop that learned to fly. It never lands. It never explains.",
		tier = "Common",
		income = 5,
		cost = 75,
		tint = Color3.fromRGB(70, 150, 255),
		size = 1.0,
		prop = "Wings",
	},
	{
		id = "EsTehManisRaksasa",
		display = "Es Teh Manis Raksasa",
		note = "A giant glass of sweet iced tea. Sweet enough to buy the warung.",
		tier = "Rare",
		income = 12,
		cost = 180,
		tint = Color3.fromRGB(205, 130, 55),
		size = 1.1,
		prop = "Tea",
	},
	{
		id = "GitarKentang",
		display = "Gitar Kentang",
		note = "A potato with a guitar. The solos are starchy. The crowd goes wild anyway.",
		tier = "Rare",
		income = 20,
		cost = 300,
		tint = Color3.fromRGB(195, 155, 95),
		size = 1.1,
		prop = "Guitar",
	},
	{
		id = "KopiSusuGalaksi",
		display = "Kopi Susu Galaksi",
		note = "Iced coffee milk from another galaxy. It never goes cold. It never goes decaf.",
		tier = "Epic",
		income = 45,
		cost = 675,
		tint = Color3.fromRGB(95, 65, 170),
		size = 1.2,
		prop = "Coffee",
	},
	{
		id = "AyamGeprekAstronot",
		display = "Ayam Geprek Astronot",
		note = "Smashed fried chicken, in orbit. The sambal recipe is classified.",
		tier = "Epic",
		income = 70,
		cost = 1050,
		tint = Color3.fromRGB(235, 235, 245),
		size = 1.2,
		prop = "Bubble",
	},
	{
		id = "NasiGorengSamurai",
		display = "Nasi Goreng Samurai",
		note = "Fried rice, a katana, and a strict code: never burn, never lose, never share.",
		tier = "Legendary",
		income = 150,
		cost = 2250,
		tint = Color3.fromRGB(225, 85, 45),
		size = 1.35,
		prop = "Katana",
	},
	{
		id = "MieAyamTurbo",
		display = "Mie Ayam Turbo",
		note = "Noodles with a jet engine strapped on. Your order arrives before you order it.",
		tier = "Legendary",
		income = 220,
		cost = 3300,
		tint = Color3.fromRGB(250, 195, 45),
		size = 1.35,
		prop = "Spark",
	},
	{
		id = "RendangRaksasa",
		display = "Rendang Raksasa",
		note = "Slow-cooked for four hours. And four centuries. Worth every second.",
		tier = "Mythic",
		income = 450,
		cost = 6750,
		tint = Color3.fromRGB(125, 65, 25),
		size = 1.5,
		prop = "Pot",
	},
	{
		id = "SateKilat",
		display = "Sate Kilat",
		note = "Skewers that flash like lightning. The peanut sauce hums when it rains.",
		tier = "Mythic",
		income = 700,
		cost = 10500,
		tint = Color3.fromRGB(205, 145, 65),
		size = 1.5,
		prop = "Spark",
	},
	{
		id = "KomodoEmas",
		display = "Komodo Emas",
		note = "A komodo made of gold. The island is its bank and the bank is its island.",
		tier = "BrainrotGod",
		income = 1500,
		cost = 22500,
		tint = Color3.fromRGB(250, 195, 10),
		size = 1.7,
		prop = "Crown",
	},
	{
		id = "GarudaPetir",
		display = "Garuda Petir",
		note = "A garuda stitched from storm clouds. Its wings are lightning; its ego is bigger.",
		tier = "BrainrotGod",
		income = 2500,
		cost = 37500,
		tint = Color3.fromRGB(45, 65, 165),
		size = 1.7,
		prop = "Wings",
	},
}

-- BY_ID is a lookup built once at load, so find() never scans the cast.
local BY_ID = {}
for _, character in ipairs(BrainrotCatalog.CHARACTERS) do
	BY_ID[character.id] = character
end

-- find returns the catalog row for an id, or nil.
function BrainrotCatalog.find(id)
	return BY_ID[id]
end

-- ofTier lists the cast of one rung of the ladder, in order.
function BrainrotCatalog.ofTier(tier)
	local list = {}
	for _, character in ipairs(BrainrotCatalog.CHARACTERS) do
		if character.tier == tier then
			table.insert(list, character)
		end
	end
	return list
end

-- tierColor returns the tint of one rung of the ladder.
function BrainrotCatalog.tierColor(tier)
	local data = BrainrotCatalog.RARITIES[tier]
	if data ~= nil then
		return data.tint
	end
	return Color3.fromRGB(255, 255, 255)
end

-- rollOne picks a character with the seeded roller: first the rarity by
-- chance, then one of that rarity's characters at random.
function BrainrotCatalog.rollOne(roller)
	local rarityEntries = {}
	for _, tier in ipairs(BrainrotCatalog.RARITY_ORDER) do
		table.insert(rarityEntries, { value = tier, weight = BrainrotCatalog.RARITIES[tier].chance })
	end
	local tier = roller.weighted(rarityEntries)
	local pool = BrainrotCatalog.ofTier(tier)
	return pool[roller.int(1, #pool)]
end

-- rollMutation picks a mutation with the seeded roller. The entries are
-- sorted by name so the draw order is stable run to run.
function BrainrotCatalog.rollMutation(roller)
	local names = {}
	for name in pairs(BrainrotCatalog.MUTATIONS) do
		table.insert(names, name)
	end
	table.sort(names)
	local entries = {}
	for _, name in ipairs(names) do
		table.insert(entries, { value = name, weight = BrainrotCatalog.MUTATIONS[name].chance })
	end
	return roller.weighted(entries)
end

-- incomeOf is what one character actually earns per second.
function BrainrotCatalog.incomeOf(character, mutation)
	local data = BrainrotCatalog.MUTATIONS[mutation] or BrainrotCatalog.MUTATIONS.Normal
	return character.income * data.times
end

-- newRoller returns a fresh roller for the conveyor's spawn loop.
function BrainrotCatalog.newRoller(seed)
	return SeededRng.new(seed)
end

return BrainrotCatalog

