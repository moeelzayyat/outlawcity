--!strict
-- Chooses where each civilian (re)spawns: a random free spawn around the plaza, set as the
-- player's RespawnLocation before every spawn. Server-only; clients never pick spawns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GameplayConfig = require(Shared.Config.GameplayConfig)
local SpawnRules = require(Shared.Player.SpawnRules)
local WorldService = require(script.Parent.WorldService)

local SpawnService = {}

local rng = Random.new()

local function occupiedPositions(except: Player): { Vector3 }
	local positions = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if other ~= except and root and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if vehicles then
		for _, vehicle in vehicles:GetChildren() do
			if vehicle:IsA("Model") and vehicle.PrimaryPart then
				table.insert(positions, vehicle.PrimaryPart.Position)
			end
		end
	end
	return positions
end

-- Picks and assigns the player's next spawn. Returns the chosen SpawnLocation.
function SpawnService.assignSpawn(player: Player): SpawnLocation?
	local spawns = WorldService.getCivilianSpawns()
	if #spawns == 0 then
		return nil
	end
	local candidates = {}
	for index, spawn in spawns do
		candidates[index] = spawn.Position
	end
	local index = SpawnRules.pickSpawn(candidates, occupiedPositions(player), GameplayConfig.SpawnClearance, rng)
	player.RespawnLocation = spawns[index]
	return spawns[index]
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			SpawnService.assignSpawn(player)
		end)
	end
end

local function onPlayerAdded(player: Player)
	SpawnService.assignSpawn(player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end

function SpawnService.init() end

function SpawnService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return SpawnService
