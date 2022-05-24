---@class simulation
---@field new_nor fun(circuit:simulation,name:string,opts:table|nil):simulation

local signal = require("digisim.signal")
local high = signal.high
local low = signal.low
local constants = require("digisim.constants")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"nor",
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
				local o = name .. ".i"
				self:new_or(o, { width = width })
				self:c(name, "in", o, "in")

				local n = name .. ".n"
				self:new_not(n):c(o, "q", n, "a"):c(n, "q", name, "q")
				return self
			else
				return self:add_component(name, opts, function(_, a)
					for _, x in ipairs(a) do
						if x == high then
							return low
						end
					end
					return high
				end)
			end
		end
	)
end
