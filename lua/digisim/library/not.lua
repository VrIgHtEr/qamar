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
			opts = opts or { width = 1 }
			local width = opts.width or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			width = math.floor(width)
			if width < 1 then
				error("invalid width")
			end
			opts.names = { inputs = { { "a", width } }, outputs = { { "q", width } } }
			return self:add_component(name, function(_, a)
				if width == 1 then
					return a == signal.low and signal.high or signal.low
				else
					local ret = {}
					for i, x in ipairs(a) do
						ret[i] = x == signal.low and signal.high or signal.low
					end
					return ret
				end
			end, opts)
		end
	)
end
