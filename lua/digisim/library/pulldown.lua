---@class simulation
---@field new_pulldown fun(circuit:simulation,name:string,opts:table|nil):simulation

local signal = require("digisim.signal")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"pulldown",
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
			opts.names = { inputs = {}, outputs = { { "q", width } } }

			local ret = signal.weaklow
			if width > 1 then
				local t = {}
				for i = 1, width do
					t[i] = ret
				end
				ret = t
			end
			return self:add_component(name, opts, function()
				return ret
			end)
		end
	)
end
