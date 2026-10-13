--!strict
-- The playable teams and team-switching limits. Read-only at runtime.
local Types = require(script.Parent.Parent.Types)

local TeamConfig = {}

-- Max allowed difference in player count between any two teams after a switch.
TeamConfig.MaxImbalance = 2
-- Seconds a player must wait after a successful team change before changing again.
TeamConfig.SwitchCooldown = 10

local teams: { Types.TeamDefinition } = {
	{
		Id = "Police",
		DisplayName = "Police",
		Description = "Chase down wanted criminals and arrest them.",
		TeamColor = BrickColor.new("Bright blue"),
	},
	{
		Id = "Criminal",
		DisplayName = "Criminals",
		Description = "Break the law, raise your wanted level and escape.",
		TeamColor = BrickColor.new("Bright orange"),
	},
}
for _, team in teams do
	table.freeze(team)
end
table.freeze(teams)

TeamConfig.Teams = teams

function TeamConfig.get(teamId: string): Types.TeamDefinition?
	for _, team in teams do
		if team.Id == teamId then
			return team
		end
	end
	return nil
end

return TeamConfig
