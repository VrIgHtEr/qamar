local signal = require("digisim.signal")

---@class simulation
---@field new_tristate_buffer function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"tristate_buffer",
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
			opts.names = { inputs = { { "a", width }, "en" }, outputs = { { "q", width } } }
			local z
			if width == 1 then
				z = signal.z
			else
				z = {}
				for i = 1, width do
					z[i] = signal.z
				end
			end
			return self:add_component(name, function(_, a, en)
				local ret = signal.z
				return signal.low == en and z or a
			end, opts)
		end
	)
end
