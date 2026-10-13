--!strict
-- Single owner of per-player gameplay state. Publishes it as read-only Player attributes
-- (see Shared.Player.PlayerAttributes). Later systems (wanted, combat status) add to it here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local GameplayConfig = require(Shared.Config.GameplayConfig)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)

local PlayerStateService = {}

local function onCharacterAdded(player: Player)
	player:SetAttribute(PlayerAttributes.SpawnProtectedUntil, Workspace:GetServerTimeNow() + GameplayConfig.SpawnProtectionSeconds)
end

local function onPlayerAdded(player: Player)
	local status: Types.PlayerStatus = "Civilian"
	player:SetAttribute(PlayerAttributes.Status, status)
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	if player.Character then
		onCharacterAdded(player)
	end
end

function PlayerStateService.init() end

function PlayerStateService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function PlayerStateService.getStatus(player: Player): Types.PlayerStatus?
	return player:GetAttribute(PlayerAttributes.Status) :: Types.PlayerStatus?
end

function PlayerStateService.isSpawnProtected(player: Player): boolean
	local untilTime = player:GetAttribute(PlayerAttributes.SpawnProtectedUntil)
	return typeof(untilTime) == "number" and Workspace:GetServerTimeNow() < untilTime
end

return PlayerStateService
