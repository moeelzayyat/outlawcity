--!strict
-- Studio-only playtest timing (audit 4, P8). Prints the seconds from join to each player's first
-- car, first robbery start and first robbery escape, once per session:
--   [Milestone] <name> FirstCar 6.4s after join
-- Outside Studio mark() does nothing, so published servers log nothing and keep no state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OnboardingRules = require(ReplicatedStorage.Shared.Onboarding.OnboardingRules)

local MilestoneLog = {}

local enabled = RunService:IsStudio()
local states: { [Player]: OnboardingRules.Milestones } = {}

local function track(player: Player)
	if not states[player] then
		states[player] = OnboardingRules.newMilestones(os.clock())
	end
end

function MilestoneLog.mark(player: Player, name: string)
	if not enabled then
		return
	end
	track(player)
	local elapsed = OnboardingRules.markMilestone(states[player], name, os.clock())
	if elapsed then
		print(string.format("[Milestone] %s %s %.1fs after join", player.Name, name, elapsed))
	end
end

if enabled then
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return MilestoneLog
