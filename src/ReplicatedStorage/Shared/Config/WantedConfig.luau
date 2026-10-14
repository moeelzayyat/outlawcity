--!strict
-- Wanted-level tuning. Read-only at runtime. The number of stars is the length of
-- StarThresholds: add a 4th and 5th threshold to extend to five stars, no code changes needed.
local Types = require(script.Parent.Parent.Types)

local WantedConfig: Types.WantedConfig = {
	-- Heat needed for 1, 2 and 3 stars (ascending).
	StarThresholds = { 10, 40, 100 },
	-- Heat never exceeds this.
	MaxHeat = 150,
	-- Seconds with no new crime and no police sighting before heat starts to decay ("Evading").
	DecayDelay = 8,
	-- Heat lost per second while evading.
	DecayRate = 6,
	-- Escaping from at least this many stars counts as a successful escape.
	EscapeMinStars = 2,
	-- Criminal reputation for escaping, by peak stars reached during the episode.
	EscapeReputation = { [2] = 10, [3] = 25, [4] = 45, [5] = 70 },
	-- Crime catalogue. Heat per event and a per-player cooldown so one collision or one
	-- burst of speeding cannot fire dozens of times. Detectors arrive with NPC police (3D).
	Crimes = {
		RammingPolice = { Heat = 25, Cooldown = 2 },
		SpeedingNearPolice = { Heat = 6, Cooldown = 5 },
		Evading = { Heat = 4, Cooldown = 3 },
		-- Store robbery alarm: 70 heat lands mid-band in 2 stars (40-100).
		StoreRobbery = { Heat = 70, Cooldown = 0 },
		-- Re-reported each second while holding a store: no extra heat, but no decay either.
		RobberyInProgress = { Heat = 0, Cooldown = 1 },
	},
}

local function deepFreeze(value: any)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in value do
			deepFreeze(child)
		end
		table.freeze(value)
	end
end
deepFreeze(WantedConfig)

return WantedConfig
