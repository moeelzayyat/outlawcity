--!strict
-- Pure safe-zone geometry. Unit-tested in ServerStorage.Tests.SafeZoneRules.spec.
local Types = require(script.Parent.Parent.Types)

local SafeZoneRules = {}

-- True when `point` is inside `zone`, optionally grown by `margin` studs on every side.
function SafeZoneRules.contains(zone: Types.SafeZone, point: Vector3, margin: number?): boolean
	local m = margin or 0
	return point.X >= zone.Min.X - m
		and point.X <= zone.Max.X + m
		and point.Y >= zone.Min.Y - m
		and point.Y <= zone.Max.Y + m
		and point.Z >= zone.Min.Z - m
		and point.Z <= zone.Max.Z + m
end

-- Name of the first zone containing `point`, or nil.
function SafeZoneRules.zoneAt(zones: { Types.SafeZone }, point: Vector3, margin: number?): string?
	for _, zone in zones do
		if SafeZoneRules.contains(zone, point, margin) then
			return zone.Name
		end
	end
	return nil
end

-- Next inside/outside state with hysteresis: entering needs the point inside a zone; leaving
-- needs it more than `exitMargin` studs outside, so standing on the edge doesn't flicker.
function SafeZoneRules.update(wasInside: boolean, zones: { Types.SafeZone }, point: Vector3, exitMargin: number): (boolean, string?)
	local name = SafeZoneRules.zoneAt(zones, point, if wasInside then exitMargin else 0)
	return name ~= nil, name
end

return SafeZoneRules
