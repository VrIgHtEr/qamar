---@class simulation
---@field new_or function

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"or",
		---@param self simulation
		---@param name string
		---@param opts boolean
		function(self, name, opts)
			return self:add_component(name, 2, 1, function(_, a, b)
				return (a == signal.high or b == signal.high) and signal.high or signal.low
			end, opts)
		end
	)
end
