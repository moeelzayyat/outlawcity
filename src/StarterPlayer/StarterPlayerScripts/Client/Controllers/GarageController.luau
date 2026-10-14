--!strict
-- Garage window: lists the vehicles the server says this player owns (OwnedVehicles
-- attribute) and spawns the chosen one. The server re-checks ownership on every spawn
-- request, so this list is display only. V (or DPad up) spawns the last chosen car.
-- Spawn Car spawns directly while the player owns one car; the window opens only with a choice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.Player.PlayerAttributes)
local OnboardingRules = require(ReplicatedStorage.Shared.Onboarding.OnboardingRules)
local VehicleController = require(script.Parent.VehicleController)
local UiKit = require(script.Parent.UiKit)

local GarageController = {}

local player = Players.LocalPlayer
local selected = VehicleConfig.DefaultVehicleId
local panel: Frame? = nil
local rebuild: () -> () = function() end

function GarageController.getSelected(): string
	return selected
end

function GarageController.spawnSelected()
	VehicleController.requestSpawn(selected)
end

-- The Spawn Car button (P1): one owned car spawns straight away (and becomes the selection, so
-- a stale earlier pick is never sent), 2+ open the garage, none sends nothing.
function GarageController.spawnOrChoose()
	local action, vehicleId = OnboardingRules.spawnChoice(UiKit.ownedVehicles(player), EconomyConfig.StarterVehicles)
	if action == "Spawn" and vehicleId then
		selected = vehicleId
		if panel then
			panel.Visible = false
		end
		VehicleController.requestSpawn(vehicleId)
	elseif action == "Choose" then
		GarageController.toggle()
	end
end

function GarageController.toggle()
	if panel then
		panel.Visible = not panel.Visible
		if panel.Visible then
			rebuild()
		end
	end
end

function GarageController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GarageGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")

	local window = UiKit.panel(gui, "Garage", 300)
	panel = window
	UiKit.text(window, "Title", "GARAGE", UDim2.new(1, -60, 0, 36), UDim2.fromOffset(12, 8), 22, Color3.fromRGB(255, 200, 70)).TextXAlignment = Enum.TextXAlignment.Left
	local close = UiKit.button(window, "Close", "X", UDim2.fromOffset(44, 44), UDim2.new(1, -52, 0, 6), Color3.fromRGB(70, 70, 80))
	close.Activated:Connect(function()
		window.Visible = false
	end)
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, 56)
	list.Size = UDim2.new(1, -24, 1, -64)
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	rebuild = function()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local ids = UiKit.ownedVehicles(player)
		for order, id in ids do
			local stats = VehicleConfig.get(id)
			if stats then
				local row = UiKit.button(list, id, `{stats.DisplayName}{if id == selected then "  ✓" else ""}`, UDim2.new(1, 0, 0, 48), UDim2.new(), stats.BodyColor)
				row.LayoutOrder = order
				row.TextSize = 18
				row.Activated:Connect(function()
					selected = id
					window.Visible = false
					VehicleController.requestSpawn(id)
				end)
			end
		end
		window.Size = UDim2.fromOffset(300, 64 + #ids * 56)
	end
	player:GetAttributeChangedSignal(PlayerAttributes.OwnedVehicles):Connect(function()
		if not table.find(UiKit.ownedVehicles(player), selected) then
			selected = VehicleConfig.DefaultVehicleId
		end
		if window.Visible then
			rebuild()
		end
	end)
end

return GarageController
