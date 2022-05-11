---@class simulation
---@field new_xor function

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"xor",
		---@param self simulation
		---@param name string
		---@param opts boolean
		function(self, name, opts)
			opts = opts or {}
			opts.names = { inputs = { "a", "b" }, outputs = { "q" } }
			return self:add_component(name, function(_, a, b)
				return (a == signal.high and b == signal.low or a == signal.low and b == signal.high) and signal.high
					or signal.low
			end, opts)
		end
	)
end
