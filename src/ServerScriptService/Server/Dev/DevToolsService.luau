--!strict
-- Studio-only developer tools for solo testing. Outside Studio this service does nothing:
-- its remote folder (ReplicatedStorage.DevRemotes) is never created, so published servers
-- have no dev entry point at all. Every handler re-checks IsStudio as a second guard.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DevCommandRules = require(script.Parent.DevCommandRules)
local WantedService = require(script.Parent.Parent.Services.WantedService)
local JailService = require(script.Parent.Parent.Services.JailService)
local EconomyService = require(script.Parent.Parent.Services.EconomyService)
local DataStoreAdapter = require(script.Parent.Parent.Data.DataStoreAdapter)
local RobberyService = require(script.Parent.Parent.Services.RobberyService)

local DevToolsService = {}

local FOLDER_NAME = "DevRemotes"

function DevToolsService.isEnabled(): boolean
	return RunService:IsStudio()
end

local function run(player: Player, name: unknown, value: unknown): (boolean, string?)
	if not DevToolsService.isEnabled() then
		return false, "Dev tools are disabled outside Studio"
	end
	local command, err = DevCommandRules.parse(name, value)
	if not command then
		return false, err
	end
	if command.Name == "SetHeat" then
		return WantedService.setHeatForTesting(player, command.Value), nil
	elseif command.Name == "SetStars" then
		return WantedService.setHeatForTesting(player, DevCommandRules.heatForStars(command.Value)), nil
	elseif command.Name == "ReportCrime" then
		local ok, crimeErr = WantedService.reportCrime(player, command.Value)
		return ok, crimeErr
	elseif command.Name == "ResetWanted" then
		WantedService.resetWanted(player)
		return true, nil
	elseif command.Name == "SetPoliceSight" then
		WantedService.setPoliceSightForTesting(player, command.Value)
		return true, nil
	elseif command.Name == "SimulateBust" then
		local ok, jailErr = JailService.jailForBust(player)
		return ok, jailErr
	elseif command.Name == "GrantCash" then
		return EconomyService.grant(player, (command :: any).Value, EconomyService.newTransactionId("dev"), "dev grant")
	elseif command.Name == "DeductCash" then
		return EconomyService.deduct(player, (command :: any).Value, EconomyService.newTransactionId("dev"), "dev deduct")
	elseif command.Name == "GrantCashTx" then
		return EconomyService.grant(player, 100, command.Value, "dev grant with fixed tx")
	elseif command.Name == "SetDataStoreFailure" then
		DataStoreAdapter.setSimulatedFailure(command.Value)
		return true, nil
	elseif command.Name == "SaveNow" then
		return EconomyService.saveNowForTesting(player), nil
	elseif command.Name == "ClearRobberyCooldown" then
		RobberyService.clearCooldownsForTesting()
		return true, nil
	elseif command.Name == "SetCashUnavailable" then
		return EconomyService.setUnavailableForTesting(player, (command :: any).Value), nil
	elseif command.Name == "AddLedgerReward" then
		return EconomyService.addLedgerRewardForTesting(player, (command :: any).Value)
	elseif command.Name == "WriteLegacyProfile" then
		return EconomyService.writeLegacyRecordForTesting(player), nil
	elseif command.Name == "TryRobStore" then
		return RobberyService.tryStart(player, "Store1")
	end
	return false, "Unhandled command"
end

function DevToolsService.init()
	if not DevToolsService.isEnabled() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local remote = Instance.new("RemoteFunction")
	remote.Name = "RequestDevCommand"
	remote.OnServerInvoke = run
	remote.Parent = folder
	folder.Parent = ReplicatedStorage
end

function DevToolsService.start() end

return DevToolsService
