---@class simulation
---@field new_not function

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"not",
		---@param self simulation
		---@param name string
		---@param opts boolean
		function(self, name, opts)
			opts = opts or {}
			opts.names = { inputs = { "a" }, outputs = { "q" } }
			return self:add_component(name, function(_, a)
				return a == signal.low and signal.high or signal.low
			end, opts)
		end
	)
end
