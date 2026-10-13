--!strict
-- Team selection screen. Opens automatically while the player is Neutral and can be reopened
-- with the Team button. The server decides; this screen only previews rules and shows results.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Remotes = require(Shared.Net.Remotes)
local TeamConfig = require(Shared.Config.TeamConfig)
local TeamRules = require(Shared.Teams.TeamRules)

local TeamSelectController = {}

local ERROR_TEXT: { [string]: string } = {
	TeamFull = "That team is full right now. Try the other side.",
	Cooldown = `You can switch teams once every {TeamConfig.SwitchCooldown} seconds.`,
	AlreadyOnTeam = "You're already on that team.",
	UnknownTeam = "That team doesn't exist.",
	BadRequest = "Request rejected.",
	NetworkError = "Could not reach the server.",
}
local PANEL_COLOR = Color3.fromRGB(20, 22, 28)
local CARD_COLOR = Color3.fromRGB(34, 37, 46)

local player = Players.LocalPlayer

type Card = { definition: Types.TeamDefinition, count: TextLabel, join: TextButton }

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, name: string, value: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = value
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function getTeam(teamId: string): Team?
	return Teams:FindFirstChild(teamId) :: Team?
end

local function currentTeamId(): string?
	if player.Neutral or not player.Team then
		return nil
	end
	return player.Team.Name
end

local function getCounts(): { [string]: number }
	local counts = {}
	for _, definition in TeamConfig.Teams do
		local team = getTeam(definition.Id)
		counts[definition.Id] = if team then #team:GetPlayers() else 0
	end
	return counts
end

function TeamSelectController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TeamSelect"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local teamButton = Instance.new("TextButton")
	teamButton.Name = "TeamButton"
	teamButton.Size = UDim2.fromOffset(160, 44)
	-- Sits left of the Spawn Car button in the top-centre row (player list owns the top right).
	teamButton.Position = UDim2.new(0.5, -84, 0, 8)
	teamButton.AnchorPoint = Vector2.new(0.5, 0)
	teamButton.BackgroundColor3 = Color3.fromRGB(60, 60, 72)
	teamButton.TextColor3 = Color3.new(1, 1, 1)
	teamButton.Font = Enum.Font.GothamBold
	teamButton.TextSize = 16
	teamButton.Parent = gui
	corner(teamButton, 10)

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.Active = true
	overlay.Visible = false
	overlay.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.85)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.Parent = overlay
	corner(panel, 14)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(640, 340)
	sizeLimit.Parent = panel

	text(panel, "Title", "Choose your side", UDim2.new(1, -100, 0, 40), UDim2.fromOffset(50, 6), 24)
	local status = text(panel, "Status", "", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 1, -34), 14)
	status.TextColor3 = Color3.fromRGB(255, 190, 80)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "X"
	close.Size = UDim2.fromOffset(44, 44)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.AnchorPoint = Vector2.new(1, 0)
	close.BackgroundColor3 = CARD_COLOR
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.Parent = panel
	corner(close, 10)

	local cards: { Card } = {}
	local pending = false

	local function refresh()
		local current = currentTeamId()
		local counts = getCounts()
		local currentDefinition = current and TeamConfig.get(current)
		teamButton.Text = if currentDefinition then `Team: {currentDefinition.DisplayName}` else "Choose Team"
		close.Visible = current ~= nil
		for _, card in cards do
			local id = card.definition.Id
			local count = counts[id] or 0
			card.count.Text = `{count} player{if count == 1 then "" else "s"}`
			local allowed, err = TeamRules.canJoin(current, id, counts, TeamConfig.MaxImbalance)
			if current == id then
				card.join.Text = "Current team"
			elseif not allowed and err == "TeamFull" then
				card.join.Text = "Full"
			else
				card.join.Text = if pending then "Joining..." else "Join"
			end
			card.join.AutoButtonColor = allowed and not pending
			card.join.BackgroundTransparency = if allowed and not pending then 0 else 0.5
		end
	end

	local function setOpen(open: boolean)
		overlay.Visible = open
		status.Text = ""
		refresh()
	end

	local function requestJoin(teamId: string)
		if pending or currentTeamId() == teamId then
			return
		end
		pending = true
		status.Text = ""
		refresh()
		task.spawn(function()
			local called, ok, err = pcall(function()
				return Remotes.getFunction("RequestJoinTeam"):InvokeServer(teamId)
			end)
			pending = false
			if called and ok == true then
				setOpen(false)
			else
				status.Text = ERROR_TEXT[if called then tostring(err) else "NetworkError"] or "Could not join that team."
				refresh()
			end
		end)
	end

	for index, definition in TeamConfig.Teams do
		local card = Instance.new("Frame")
		card.Name = definition.Id
		card.Size = UDim2.new(0.5, -18, 1, -92)
		card.Position = UDim2.new((index - 1) * 0.5, if index == 1 then 12 else 6, 0, 52)
		card.BackgroundColor3 = CARD_COLOR
		card.Parent = panel
		corner(card, 12)
		local stripe = Instance.new("Frame")
		stripe.Name = "Stripe"
		stripe.Size = UDim2.new(1, 0, 0, 6)
		stripe.BackgroundColor3 = definition.TeamColor.Color
		stripe.BorderSizePixel = 0
		stripe.Parent = card

		local name = text(card, "TeamName", definition.DisplayName, UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 10), 22)
		name.TextColor3 = definition.TeamColor.Color
		local description = text(card, "Description", definition.Description, UDim2.new(1, -16, 1, -112), UDim2.fromOffset(8, 42), 14)
		description.Font = Enum.Font.Gotham
		description.TextYAlignment = Enum.TextYAlignment.Top
		local count = text(card, "Count", "", UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 1, -72), 14)
		count.TextColor3 = Color3.fromRGB(190, 190, 200)

		local join = Instance.new("TextButton")
		join.Name = "Join"
		join.Size = UDim2.new(1, -16, 0, 44)
		join.Position = UDim2.new(0, 8, 1, -50)
		join.BackgroundColor3 = definition.TeamColor.Color
		join.TextColor3 = Color3.new(1, 1, 1)
		join.Font = Enum.Font.GothamBold
		join.TextSize = 18
		join.Parent = card
		corner(join, 10)
		join.Activated:Connect(function()
			requestJoin(definition.Id)
		end)

		table.insert(cards, { definition = definition, count = count, join = join })
		local team = Teams:WaitForChild(definition.Id, 10) :: Team?
		if team then
			team.PlayerAdded:Connect(refresh)
			team.PlayerRemoved:Connect(refresh)
		end
	end

	teamButton.Activated:Connect(function()
		setOpen(not overlay.Visible)
	end)
	close.Activated:Connect(function()
		if currentTeamId() then
			setOpen(false)
		end
	end)
	player:GetPropertyChangedSignal("Team"):Connect(refresh)
	player:GetPropertyChangedSignal("Neutral"):Connect(refresh)

	setOpen(currentTeamId() == nil)
end

return TeamSelectController
