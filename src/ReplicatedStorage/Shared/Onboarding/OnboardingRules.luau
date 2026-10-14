--!strict
-- Pure helpers for the new-player guidance (audit 4 onboarding batch): spawn shortcut, markers,
-- escape hint, store cooldown text, Muscle progress and milestone timing. Display only; the
-- server stays the authority for everything these describe. Unit-tested in
-- ServerStorage.Tests.OnboardingRules.spec.
local OnboardingRules = {}

export type PanelLayout = { Y: number, Width: number, Height: number, TitleSize: number, DetailSize: number }
export type Milestones = { JoinedAt: number, Done: { [string]: number } }

-- P1 (audit condition 1): what the Spawn Car button does, and with which car. `owned` comes from
-- the OwnedVehicles display attribute; while it is empty (data not loaded yet, or unavailable)
-- only the starter cars count, because the server always accepts those. One candidate spawns
-- that car, whatever was selected before (so a stale selection is never sent); several open the
-- garage; none sends nothing.
function OnboardingRules.spawnChoice(owned: { string }, starters: { string }): ("Spawn" | "Choose" | "None", string?)
	local candidates = if #owned > 0 then owned else starters
	if #candidates == 0 then
		return "None", nil
	elseif #candidates == 1 then
		return "Spawn", candidates[1]
	end
	return "Choose", nil
end

-- P3 (audit condition 2): the tip steps aside only for a robbery that is actually running.
function OnboardingRules.isActiveRobbery(phase: any): boolean
	return phase == "Holding" or phase == "Escaping"
end

-- P2: a marker shows between the hide distance (you're already there) and the max distance.
function OnboardingRules.markerVisible(distance: number, config: { MarkerMaxDistance: number, MarkerHideDistance: number }): boolean
	return distance == distance and distance >= config.MarkerHideDistance and distance <= config.MarkerMaxDistance
end

function OnboardingRules.formatDistance(distance: number): string
	return `{math.floor(distance / 10 + 0.5) * 10} studs`
end

-- "m:ss" for a positive number of seconds (rounded up, so 0:00 only when it's open).
function OnboardingRules.formatClock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- P5: the store marker's status line. cooldownUntil is server time (nil/-inf = never robbed).
function OnboardingRules.storeStatus(cooldownUntil: number?, busy: boolean, now: number): string
	if busy then
		return "Being robbed"
	end
	if type(cooldownUntil) == "number" and cooldownUntil > now then
		return `Reopens in {OnboardingRules.formatClock(cooldownUntil - now)}`
	end
	return "Open: rob the register"
end

-- P4: the escape panel's second line. Matches WantedRules: heat only decays after DecayDelay
-- seconds with no police sighting and no new crime, and the escape counts when the stars are gone.
function OnboardingRules.escapeHint(evading: boolean, stars: number): string
	if evading and stars > 0 then
		return "Stars fading: stay out of police sight until they're gone"
	end
	return "Break line of sight, then stay hidden until your stars are gone"
end

-- P6: successful robberies still needed to afford `price` from `cash`.
function OnboardingRules.robberiesNeeded(cash: number, price: number, reward: number): number
	if not (reward > 0) or cash >= price then
		return 0
	end
	return math.ceil((price - cash) / reward)
end

function OnboardingRules.progressText(name: string, cash: number, price: number, reward: number, money: (number) -> string): string
	local needed = OnboardingRules.robberiesNeeded(cash, price, reward)
	if needed == 0 then
		return `You can afford the {name}!`
	end
	return `{name}: {money(math.max(0, cash))} of {money(price)}. About {needed} more successful {if needed == 1 then "robbery" else "robberies"}.`
end

-- P7: compact panel on short (phone landscape) screens.
function OnboardingRules.robberyPanelLayout(screenHeight: number, config: { CompactScreenHeight: number, CompactPanel: PanelLayout, FullPanel: PanelLayout }): PanelLayout
	return if screenHeight < config.CompactScreenHeight then config.CompactPanel else config.FullPanel
end

-- P8: milestone timing, each milestone recorded once per session.
function OnboardingRules.newMilestones(joinedAt: number): Milestones
	return { JoinedAt = joinedAt, Done = {} }
end

-- Returns seconds since join the first time `name` is marked, else nil.
function OnboardingRules.markMilestone(state: Milestones, name: string, now: number): number?
	if state.Done[name] ~= nil then
		return nil
	end
	local elapsed = math.max(0, now - state.JoinedAt)
	state.Done[name] = elapsed
	return elapsed
end

return OnboardingRules
