---@class simulation
---@field new_nand function

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"nand",
		---@param self simulation
		---@param name string
		---@param opts boolean
		function(self, name, opts)
			return self:add_component(name, 2, 1, function(_, a, b)
				return (a == signal.high and b == signal.high) and signal.low or signal.high
			end, opts)
		end
	)
end
