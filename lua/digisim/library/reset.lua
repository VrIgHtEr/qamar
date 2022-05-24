---@class simulation
---@field new_reset fun(circuit:simulation,name:string,opts:table|nil):simulation

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"reset",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or { period = 1 }
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
			local initialized = false
			circuit:add_component(name, opts, function()
				if initialized then
					return signal.high
				end
				initialized = true
				return signal.low, period
			end)
		end
	)
end
