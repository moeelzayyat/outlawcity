--!strict
-- Server authority for teams: creates the Police and Criminal teams and validates join requests.
-- New players start Neutral and pick a side through the team selection UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Remotes = require(Shared.Net.Remotes)
local TeamConfig = require(Shared.Config.TeamConfig)
local TeamRules = require(Shared.Teams.TeamRules)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local TeamService = {}

local MAX_TEAM_ID_LENGTH = 32

local teamById: { [string]: Team } = {}
local switchLimiter = RateLimiter.new(TeamConfig.SwitchCooldown)

local function getCounts(): { [string]: number }
	local counts = {}
	for id, team in teamById do
		counts[id] = #team:GetPlayers()
	end
	return counts
end

function TeamService.getTeamId(player: Player): Types.TeamId?
	local team = player.Team
	if player.Neutral or not team then
		return nil
	end
	for id, candidate in teamById do
		if candidate == team then
			return id :: Types.TeamId
		end
	end
	return nil
end

-- Validates and applies a team change. Also used by Studio-only dev tools.
function TeamService.joinTeam(player: Player, teamId: string): (boolean, Types.JoinTeamError?)
	local team = teamById[teamId]
	if not team then
		return false, "UnknownTeam"
	end
	local ok, err = TeamRules.canJoin(TeamService.getTeamId(player), teamId, getCounts(), TeamConfig.MaxImbalance)
	if not ok then
		return false, err
	end
	if not switchLimiter:tryConsume(player.UserId) then
		return false, "Cooldown"
	end
	player.Team = team
	player.Neutral = false
	return true, nil
end

function TeamService.init()
	for _, definition in TeamConfig.Teams do
		local team = Teams:FindFirstChild(definition.Id) :: Team?
		if not team then
			local created = Instance.new("Team")
			created.Name = definition.Id
			team = created
		end
		assert(team, "unreachable")
		team.TeamColor = definition.TeamColor
		team.AutoAssignable = false
		team.Parent = Teams
		teamById[definition.Id] = team
	end

	Remotes.getFunction("RequestJoinTeam").OnServerInvoke = function(player: Player, teamId: unknown)
		if typeof(teamId) ~= "string" or #teamId == 0 or #teamId > MAX_TEAM_ID_LENGTH then
			return false, "BadRequest"
		end
		return TeamService.joinTeam(player, teamId)
	end
end

function TeamService.start()
	local function onPlayerAdded(player: Player)
		player.Neutral = true
		player.Team = nil
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		if not player.Team then
			onPlayerAdded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		switchLimiter:reset(player.UserId)
	end)
end

return TeamService
