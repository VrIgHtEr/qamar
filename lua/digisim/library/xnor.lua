---@class simulation
---@field new_xnor fun(circuit:simulation,name:string,opts:table|nil):simulation

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"xnor",
		---@param self simulation
		---@param name string
		---@param opts boolean
		function(self, name, opts)
			opts = opts or { width = 2 }
			local width = opts.width or 2
			if type(width) ~= "number" then
				error("invalid width type")
			end
			width = math.floor(width)
			if width < 2 then
				error("invalid width")
			end
			opts.names = { inputs = { { "in", width } }, outputs = { "q" } }
			return self:add_component(name, function(_, a)
				local ret = false
				for _, x in ipairs(a) do
					if x == signal.high then
						ret = not ret
					end
				end
				return ret and signal.low or signal.high
			end, opts)
		end
	)
end
