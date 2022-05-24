---@class simulation
---@field new_and fun(circuit:simulation,name:string,opts:table|nil):simulation

local signal = require("digisim.signal")
local constants = require("digisim.constants")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"and",
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
			if constants.NAND_ONLY then
				self:add_component(name, opts)
				local n = name .. ".n"
				local i = name .. ".i"
				self
					:new_nand(n, { width = width })
					:c(name, "in", n, "in")
					:new_not(i)
					:c(n, "q", i, "a")
					:c(i, "q", name, "q")
				return self
			else
				return self:add_component(name, opts, function(_, a)
					for _, x in ipairs(a) do
						if x ~= signal.high then
							return signal.low
						end
					end
					return signal.high
				end)
			end
		end
	)
end
