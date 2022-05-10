---@class simulation
---@field new_buffer function

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"buffer",
		---@param self simulation
		---@param name string
		---@param opts boolean
		function(self, name, opts)
			opts = opts or {}
			opts.names = { inputs = { "a" }, outputs = { "q" } }
			return self:add_component(name, 1, 1, function(_, a)
				return a == signal.low and signal.low or signal.high
			end, opts)
		end
	)
end
