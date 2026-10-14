--!strict
-- Server entry point. Creates the network contract, then boots services in a fixed order.
-- Every service exposes init() (setup, may yield) and start() (connect runtime events).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Services = script.Parent.Services

type Service = { init: () -> (), start: () -> () }

local services: { Service } = {
	require(Services.WorldService) :: any,
	require(Services.PlayerStateService) :: any,
	require(Services.SpawnService) :: any,
	require(Services.EconomyService) :: any,
	require(Services.SafeZoneService) :: any,
	require(Services.JailService) :: any,
	require(Services.WantedService) :: any,
	require(Services.RobberyService) :: any,
	require(Services.DealershipService) :: any,
	require(Services.CombatService) :: any,
	require(Services.PoliceService) :: any,
	require(script.Parent.Dev.DevToolsService) :: any,
	require(Services.VehicleService) :: any,
	require(Services.VehicleValidationService) :: any,
}

Remotes.createAll()
for _, service in services do
	service.init()
end
for _, service in services do
	task.spawn(service.start)
end
Workspace:SetAttribute("ServerReady", true)

-- In Studio, run the unit tests on every playtest unless Workspace.RunTestsOnStart is false.
if RunService:IsStudio() and Workspace:GetAttribute("RunTestsOnStart") ~= false then
	local tests = ServerStorage:FindFirstChild("Tests")
	local runner = tests and tests:FindFirstChild("TestRunner")
	if runner then
		(require :: any)(runner).run(tests)
	end
end
