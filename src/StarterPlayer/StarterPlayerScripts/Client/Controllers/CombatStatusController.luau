--!strict
-- Peaceful / Combat toggle in the top-centre button row. Shows the server's status, the
-- cooldown before Peaceful is allowed, and a lock while wanted. The server decides; this
-- button only sends RequestSetCombatStatus and shows why a request was refused.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)

local CombatStatusController = {}

local PEACEFUL_COLOR = Color3.fromRGB(40, 150, 90)
local COMBAT_COLOR = Color3.fromRGB(190, 45, 45)
local MESSAGE_SECONDS = 2
local REFUSAL_TEXT: { [string]: string } = {
	Wanted = "Locked: wanted",
	Cooldown = "Wait for cooldown",
	RateLimited = "Too fast",
	InvalidStatus = "Rejected",
	AlreadyInStatus = "No change",
	NotInGame = "Not ready",
	NetworkError = "No connection",
	Jailed = "Not in jail",
}

local player = Players.LocalPlayer

function CombatStatusController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatStatus"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "CombatButton"
	button.Size = UDim2.fromOffset(160, 44)
	button.AnchorPoint = Vector2.new(0.5, 0)
	-- Left of the Spawn Car button in the top-centre row.
	button.Position = UDim2.new(0.5, -84, 0, 8)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	local message: string? = nil
	local messageToken = 0
	local pending = false

	local function render()
		local status = player:GetAttribute(PlayerAttributes.CombatStatus)
		local combat = status == "Combat"
		button.BackgroundColor3 = if combat then COMBAT_COLOR else PEACEFUL_COLOR
		if message then
			button.Text = message
			return
		end
		if not combat then
			local wanted = player:GetAttribute(PlayerAttributes.WantedLevel)
			button.Text = if type(wanted) == "number" and wanted > 0 then "PEACEFUL (wanted!)" else "PEACEFUL"
			return
		end
		local wanted = player:GetAttribute(PlayerAttributes.WantedLevel)
		if type(wanted) == "number" and wanted > 0 then
			button.Text = "COMBAT (locked)"
			return
		end
		local untilTime = player:GetAttribute(PlayerAttributes.CombatCooldownUntil)
		local remaining = if type(untilTime) == "number" then untilTime - Workspace:GetServerTimeNow() else 0
		button.Text = if remaining > 0 then `COMBAT {math.ceil(remaining)}s` else "COMBAT"
	end

	local function flash(text: string)
		messageToken += 1
		local token = messageToken
		message = text
		render()
		task.delay(MESSAGE_SECONDS, function()
			if token == messageToken then
				message = nil
				render()
			end
		end)
	end

	button.Activated:Connect(function()
		if pending then
			return
		end
		pending = true
		local target = if player:GetAttribute(PlayerAttributes.CombatStatus) == "Combat" then "Peaceful" else "Combat"
		task.spawn(function()
			local called, ok, err = pcall(function()
				return Remotes.getFunction("RequestSetCombatStatus"):InvokeServer(target)
			end)
			pending = false
			if not called then
				flash(REFUSAL_TEXT.NetworkError)
			elseif ok ~= true then
				flash(REFUSAL_TEXT[tostring(err)] or "Rejected")
			else
				render()
			end
		end)
	end)

	for _, name in { PlayerAttributes.CombatStatus, PlayerAttributes.CombatCooldownUntil, PlayerAttributes.WantedLevel } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	-- Cheap once-a-frame refresh keeps the cooldown countdown live.
	RunService.Heartbeat:Connect(render)
	render()
end

return CombatStatusController
