--!strict
-- Server authority for the short jail. A valid police bust sentences the player
-- (JailRules), clears their wanted level with no reward, takes them out of any vehicle and puts
-- them in a cell slot. The server owns the timer: every CheckInterval it releases players whose
-- time is up by respawning them at a civilian spawn (normal spawn protection). No remote can
-- end a sentence. Character resets put the player straight back in the cell.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local JailConfig = require(Shared.Config.JailConfig)
local JailRules = require(Shared.Jail.JailRules)
local CombatRules = require(Shared.Combat.CombatRules)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local WantedService = require(script.Parent.WantedService)
local SpawnService = require(script.Parent.SpawnService)
local WorldService = require(script.Parent.WorldService)

local JailService = {}

local states: { [Player]: JailRules.State } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish(player: Player, state: JailRules.State)
	player:SetAttribute(PlayerAttributes.Jailed, JailRules.isJailed(state))
	player:SetAttribute(PlayerAttributes.JailReleaseAt, state.ReleaseAt or 0)
end

local function slotCFrame(state: JailRules.State): CFrame?
	local slots = WorldService.getJailSlots()
	return slots[state.Slot or 1]
end

-- Moves the player's current character into their cell slot, out of any seat first.
local function placeInCell(player: Player)
	local state = states[player]
	local character = player.Character
	if not state or not JailRules.isJailed(state) or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
	end
	local target = slotCFrame(state)
	if target then
		for _, delay in { 0, 0.3 } do
			task.delay(delay, function()
				if character.Parent and JailService.isJailed(player) then
					character:PivotTo(target)
				end
			end)
		end
	end
end

function JailService.isJailed(player: Player): boolean
	local state = states[player]
	return state ~= nil and JailRules.isJailed(state)
end

-- Gate for restricted actions (vehicle spawning, driving, combat, future robberies).
function JailService.allows(player: Player, action: Types.JailAction): boolean
	local state = states[player]
	return state == nil or JailRules.allows(state, action)
end

-- Called for a police bust. Validates with the shared combat rules (the player must be
-- wanted), refuses duplicates, clears wanted without reward and starts the sentence.
function JailService.jailForBust(player: Player): (boolean, Types.JailError?)
	local state = states[player]
	if not state or player.Parent ~= Players then
		return false, "NotInGame"
	end
	local police: Types.Combatant = { Kind = "NpcPolice", WantedStars = 0, InSafeZone = false, SpawnProtectedUntil = 0 }
	local suspect: Types.Combatant = {
		Kind = "Player",
		UserId = player.UserId,
		WantedStars = WantedService.getStars(player),
		InSafeZone = false,
		SpawnProtectedUntil = 0,
		Jailed = JailRules.isJailed(state),
	}
	local wanted = CombatRules.canHarm(police, suspect, { Now = now(), Action = "Bust" })
	local seconds = JailRules.clampSeconds(JailConfig.Seconds, JailConfig)
	local ok, err = JailRules.sentence(state, now(), seconds, wanted)
	if not ok then
		print(`[Jail] bust of {player.Name} refused: {err}`)
		return false, err
	end
	local occupied: { [number]: boolean } = {}
	for other, otherState in states do
		if other ~= player and otherState.Slot then
			occupied[otherState.Slot] = true
		end
	end
	state.Slot = JailRules.pickSlot(occupied, math.max(1, #WorldService.getJailSlots()))
	WantedService.bust(player)
	publish(player, state)
	placeInCell(player)
	print(`[Jail] {player.Name} jailed for {seconds} s in slot {state.Slot}`)
	return true, nil
end

local function release(player: Player, state: JailRules.State)
	JailRules.release(state)
	publish(player, state)
	print(`[Jail] {player.Name} released`)
	SpawnService.assignSpawn(player)
	player:LoadCharacter()
end

local function onPlayerAdded(player: Player)
	states[player] = JailRules.new()
	publish(player, states[player])
	player.CharacterAdded:Connect(function()
		-- A reset or death mid-sentence lands the new character back in the cell.
		if JailService.isJailed(player) then
			placeInCell(player)
		end
	end)
end

function JailService.init() end

function JailService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		if not states[player] then
			onPlayerAdded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(JailConfig.CheckInterval)
			local t = now()
			for player, state in states do
				if JailRules.dueForRelease(state, t) then
					release(player, state)
				end
			end
		end
	end)
end

return JailService
