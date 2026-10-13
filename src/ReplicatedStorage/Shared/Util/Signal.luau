--!strict
-- Minimal signal for module-to-module events on one side of the network.
export type Signal = {
	Connect: (self: Signal, handler: (...any) -> ()) -> () -> (),
	Fire: (self: Signal, ...any) -> (),
}

local Signal = {}

function Signal.new(): Signal
	local handlers: { (...any) -> () } = {}
	local self = {}

	function self.Connect(_: any, handler: (...any) -> ()): () -> ()
		table.insert(handlers, handler)
		return function()
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end
	end

	function self.Fire(_: any, ...: any)
		for _, handler in table.clone(handlers) do
			task.spawn(handler, ...)
		end
	end

	return (self :: any) :: Signal
end

return Signal
