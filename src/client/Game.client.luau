-- Game.client: the client bootstrap for Brainrot Warung.
-- It builds the HUD and binds the keys: L locks the plot, R rebirths,
-- B opens the shop, E steals a nearby enemy brainrot. Movement stays on
-- the default controls (WASD and the arrow keys); these binds use
-- ContextActionService so they never fight the camera for a key.

local ContextActionService = game:GetService("ContextActionService")

local Hud = require(script.Parent.Hud)

Hud.init()

-- KEYBINDS maps one key to one HUD action, bound by name below.
local KEYBINDS = {
	{ action = "WarungLock", key = Enum.KeyCode.L, run = function() Hud.requestLock() end },
	{ action = "WarungRebirth", key = Enum.KeyCode.R, run = function() Hud.requestRebirth() end },
	{ action = "WarungShop", key = Enum.KeyCode.B, run = function() Hud.toggleShop() end },
	{ action = "WarungSteal", key = Enum.KeyCode.E, run = function() Hud.requestSteal() end },
}

for _, bind in ipairs(KEYBINDS) do
	ContextActionService:BindAction(bind.action, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			bind.run()
		end
		return Enum.ContextActionResult.Sink
	end, false, bind.key)
end

