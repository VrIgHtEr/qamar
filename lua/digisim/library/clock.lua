---@class simulation
---@field new_clock function

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"clock",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or { period = 2 }
			opts.names = { inputs = {}, outputs = { "q" } }
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
			circuit:add_component(name, function(ts)
				ts = ts % period
				return ts < period / 2 and signal.low or signal.high
			end, opts)
		end
	)
end
