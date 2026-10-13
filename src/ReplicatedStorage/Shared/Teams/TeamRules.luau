--!strict
-- Pure team-join rules shared by the server (authority) and the client (button state).
-- Unit-tested in ServerStorage.Tests.TeamRules.spec.
local Types = require(script.Parent.Parent.Types)

local TeamRules = {}

-- counts: players per team id (every team id present, zero allowed).
function TeamRules.canJoin(
	currentTeamId: string?,
	targetTeamId: string,
	counts: { [string]: number },
	maxImbalance: number
): (boolean, Types.JoinTeamError?)
	if counts[targetTeamId] == nil then
		return false, "UnknownTeam"
	end
	if currentTeamId == targetTeamId then
		return false, "AlreadyOnTeam"
	end
	local after = table.clone(counts)
	if currentTeamId and after[currentTeamId] then
		after[currentTeamId] -= 1
	end
	after[targetTeamId] += 1
	for teamId, count in after do
		if teamId ~= targetTeamId and after[targetTeamId] - count > maxImbalance then
			return false, "TeamFull"
		end
	end
	return true, nil
end

return TeamRules
