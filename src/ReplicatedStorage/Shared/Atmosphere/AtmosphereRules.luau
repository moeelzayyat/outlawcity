--!strict
-- Pure helpers for atmosphere Batch 1 (unit-tested in ServerStorage.Tests.AtmosphereRules.spec).
local AtmosphereRules = {}

-- Which light bar side is lit at time `t` (seconds): 1 or 2, alternating every `interval`.
function AtmosphereRules.flashPhase(t: number, interval: number): number
	if not (interval > 0) or t ~= t then
		return 1
	end
	return if math.floor(t / interval) % 2 == 0 then 1 else 2
end

-- Which live bar is lit for a phase: none without bars; a single bar blinks (lit in phase 1,
-- dark in phase 2); with two or more the phase picks the bar.
function AtmosphereRules.litIndex(phase: number, barCount: number): number?
	if barCount <= 0 then
		return nil
	elseif barCount == 1 then
		return if phase == 1 then 1 else nil
	end
	return math.clamp(phase, 1, barCount)
end

-- The siren may play only with its flag on AND an approved sound id set.
function AtmosphereRules.sirenEnabled(flags: { Siren: boolean }, soundId: string?): boolean
	return flags.Siren == true and type(soundId) == "string" and soundId:match("^rbxassetid://%d+$") ~= nil
end

-- A model is the police unit we decorate (by name, inside the NPC vehicle folder).
function AtmosphereRules.isPoliceUnit(name: string, parentName: string?, config: { PoliceFolderName: string, PoliceUnitName: string }): boolean
	return name == config.PoliceUnitName and parentName == config.PoliceFolderName
end

return AtmosphereRules
