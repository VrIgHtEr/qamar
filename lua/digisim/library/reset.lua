---@class simulation
---@field new_reset function

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"reset",
		0,
		1,
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
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
			circuit:add_component(name .. "___component", 0, 1, function(time)
				return time < period and signal.low or signal.high
			end, { trace = opts.trace and true or false })
			circuit:alias_output(name, 1, name .. "___component", 1)
		end
	)
end
