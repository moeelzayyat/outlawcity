--!strict
-- Tiny assertion helpers for the unit tests.
local Assert = {}

function Assert.equal(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(`{message or "equal"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function Assert.near(actual: number, expected: number, epsilon: number, message: string?)
	if math.abs(actual - expected) > epsilon then
		error(`{message or "near"}: expected {expected} ± {epsilon}, got {actual}`, 2)
	end
end

function Assert.truthy(value: any, message: string?)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

function Assert.throws(fn: () -> (), message: string?)
	if pcall(fn) then
		error(message or "expected an error", 2)
	end
end

return Assert
