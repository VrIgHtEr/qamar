---@class simulation
---@field new_clock function

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"clock",
		0,
		1,
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			local period = opts.period
			if period == nil then
				period = 2
			end
			if type(period) ~= "number" then
				error("invalid clock period type")
			end
			if period < 2 then
				error("clock period too small")
			end
			-- CLK - clock with period "clock_period_ticks"
			circuit:add_component(name .. "___component", 0, 1, function(ts)
				ts = ts % period
				return ts < period / 2 and signal.low or signal.high
			end, { opts.trace and true or false })
			circuit:alias_output(name, 1, name .. "___component", 1)
		end
	)
end
