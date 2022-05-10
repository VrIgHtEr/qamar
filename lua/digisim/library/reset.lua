---@class simulation
---@field new_reset function

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"reset",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts.names = { inputs = {}, outputs = { "q" } }
			local period = opts.period
			if period == nil then
				period = 1
			end
			if type(period) ~= "number" then
				error("invalid reset period type")
			end
			if period < 1 then
				error("reset period too small")
			end
			circuit:add_component(name, 0, 1, function(time)
				return time < period and signal.low or signal.high
			end, opts)
		end
	)
end
