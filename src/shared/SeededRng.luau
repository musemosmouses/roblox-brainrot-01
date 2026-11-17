-- SeededRng: a deterministic roller for spawn draws, built on Park-Miller.
-- Luau has no bit operators, so the whole generator is one multiply and one
-- modulo per draw, both exact in a double. The same seed replays the same
-- sequence on any machine, which is what keeps every server's conveyor
-- dealing the same characters in the same order.

local SeededRng = {}

local MODULUS = 2147483647
local MULTIPLIER = 48271

-- new builds a roller from a seed. The roller is a plain table of closures
-- over one hidden state, so nothing outside it can poke the sequence.
function SeededRng.new(seed)
	local state = seed % MODULUS
	if state <= 0 then
		state = 17
	end

	local roller = {}

	-- draw deals one float in [0, 1).
	function roller.draw()
		state = (state * MULTIPLIER) % MODULUS
		return state / MODULUS
	end

	-- int deals one whole number in [low, high].
	function roller.int(low, high)
		return low + math.floor(roller.draw() * (high - low + 1))
	end

	-- weighted picks one entry by its weight. entries is an array of
	-- { value = <anything>, weight = <number> }.
	function roller.weighted(entries)
		local total = 0
		for index = 1, #entries do
			total = total + entries[index].weight
		end
		local needle = roller.draw() * total
		for index = 1, #entries do
			needle = needle - entries[index].weight
			if needle <= 0 then
				return entries[index].value
			end
		end
		return entries[#entries].value
	end

	return roller
end

return SeededRng

