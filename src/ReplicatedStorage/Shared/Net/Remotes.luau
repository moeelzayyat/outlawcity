--!strict
-- Network contract. Every RemoteEvent / RemoteFunction is declared here and nowhere else.
-- The server creates them once at boot; clients only look them up.
-- Naming: client -> server requests start with "Request"; server -> client pushes will start with "On".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local WAIT_TIMEOUT = 30

local Remotes = {}

Remotes.Definitions = table.freeze({
	-- (vehicleId: string) -> (ok: boolean, err: Types.SpawnError?)
	RequestSpawnVehicle = "RemoteFunction",
	-- () -> (); server unseats the caller if they are in a vehicle driver seat
	RequestExitVehicle = "RemoteEvent",
	-- server -> client: (kind: Types.WantedNoticeKind, payload: { Stars?, FromStars?, Reputation? })
	OnWantedNotice = "RemoteEvent",
	-- (target: "Peaceful" | "Combat") -> (ok: boolean, err: Types.CombatSwitchError?, secondsUntilPeacefulAllowed: number)
	RequestSetCombatStatus = "RemoteFunction",
	-- client -> server: (vehicleId) -> (ok, err: PurchaseError?). Price and ownership are server-side.
	RequestPurchaseVehicle = "RemoteFunction",
	-- server -> client: (kind: "Rejected" | "Started" | "Escape" | "Failed" | "Paid" | "PayoutFailed", payload)
	OnRobberyNotice = "RemoteEvent",
} :: { [string]: string })

function Remotes.createAll(): Folder
	assert(RunService:IsServer(), "Remotes.createAll is server-only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
	if not folder then
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end
	assert(folder, "unreachable")
	for name, className in Remotes.Definitions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className :: any)
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder
end

local function get(name: string, className: string): Instance
	assert(Remotes.Definitions[name] == className, `Unknown remote {name} ({className})`)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
	assert(folder, "Remotes folder missing")
	local remote = folder:WaitForChild(name, WAIT_TIMEOUT)
	assert(remote, `Remote {name} missing`)
	return remote
end

function Remotes.getEvent(name: string): RemoteEvent
	return get(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.getFunction(name: string): RemoteFunction
	return get(name, "RemoteFunction") :: RemoteFunction
end

return Remotes
