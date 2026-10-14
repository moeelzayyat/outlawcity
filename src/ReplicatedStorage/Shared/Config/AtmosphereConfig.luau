--!strict
-- City atmosphere Batch 1 (docs/CITY_ATMOSPHERE_AUDIO_AUDIT.md: P-A, P-C, P-F). Presentation only:
-- applied on each client, never on the server, so the place's own Lighting stays as it was and
-- turning a flag off restores the old look on the next join. Each flag works on its own.
local AtmosphereConfig = {
	Flags = {
		Lighting = true, -- P-A lighting preset
		PoliceLights = true, -- P-C flashing light bar + one flashing light on the police unit
		Siren = false, -- P-C siren: stays off until the owner approves an exact sound asset id
	},
	SirenSoundId = nil :: string?, -- e.g. "rbxassetid://<approved id>"; required for the siren to play

	-- P-A: values applied to Lighting on the client.
	Lighting = {
		ClockTime = 16.5,
		Ambient = Color3.fromRGB(80, 80, 90),
		OutdoorAmbient = Color3.fromRGB(120, 115, 110),
		AtmosphereDensity = 0.32,
		AtmosphereHaze = 1,
		AtmosphereGlare = 0.2,
		BloomIntensity = 0.4,
		ColorCorrectionContrast = 0.08,
		ColorCorrectionSaturation = 0.12,
	},
	-- The place's values before Batch 1 (measured 2026-10-14), kept for the record and rollback.
	OriginalLighting = {
		ClockTime = 14.5,
		Ambient = Color3.fromRGB(70, 70, 70),
		OutdoorAmbient = Color3.fromRGB(70, 70, 70),
		AtmosphereDensity = 0.30,
		AtmosphereHaze = 0,
		AtmosphereGlare = 0,
		BloomIntensity = 1,
	},

	-- P-C
	PoliceFolderName = "NpcVehicles",
	PoliceUnitName = "PoliceUnit",
	FlashInterval = 0.25, -- seconds per red/blue phase
	DimTransparency = 0.65, -- the light bar half that is "off" in a phase
	PoliceLightRange = 14,
	PoliceLightBrightness = 2,
	SirenRollOffMaxDistance = 250,
	SirenVolume = 0.6,
}

local function deepFreeze(value: any)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in value do
			deepFreeze(child)
		end
		table.freeze(value)
	end
end
deepFreeze(AtmosphereConfig)

return AtmosphereConfig
