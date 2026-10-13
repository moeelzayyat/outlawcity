--!strict
-- Server authority for safe zones. Checks every player's position UPDATE_INTERVAL times per
-- second and publishes the read-only InSafeZone attribute, which CombatRules uses to block
-- player-vs-player harm. Safe zones never touch wanted levels, heat, escapes or NPC police:
-- those systems simply don't read this attribute (police busts ignore it by rule).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local SafeZoneRules = require(Shared.Zones.SafeZoneRules)
local CityLayout = require(script.Parent.Parent.World.CityLayout)

local SafeZoneService = {}

local UPDATE_INTERVAL = 0.25 -- seconds; bounded 4 Hz check for all players
local EXIT_MARGIN = 2 -- studs beyond the edge before a player counts as having left

local zones: { Types.SafeZone } = {}

local function setInside(player: Player, inside: boolean, zoneName: string?)
	if player:GetAttribute(PlayerAttributes.InSafeZone) == inside then
		return
	end
	player:SetAttribute(PlayerAttributes.InSafeZone, inside)
	print(`[SafeZone] {player.Name} {if inside then "entered " .. tostring(zoneName) else "left the safe zone"}`)
end

local function check(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		setInside(player, false, nil)
		return
	end
	local wasInside = player:GetAttribute(PlayerAttributes.InSafeZone) == true
	local inside, name = SafeZoneRules.update(wasInside, zones, root.Position, EXIT_MARGIN)
	setInside(player, inside, name)
end

function SafeZoneService.getZones(): { Types.SafeZone }
	return zones
end

function SafeZoneService.init()
	zones = CityLayout.safeZones()
end

function SafeZoneService.start()
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute(PlayerAttributes.InSafeZone, false)
	end)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(PlayerAttributes.InSafeZone) == nil then
			player:SetAttribute(PlayerAttributes.InSafeZone, false)
		end
	end
	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL)
			for _, player in Players:GetPlayers() do
				check(player)
			end
		end
	end)
end

return SafeZoneService
