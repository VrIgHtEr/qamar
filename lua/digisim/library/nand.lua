---@class simulation
---@field new_nand fun(circuit:simulation,name:string,opts:table|nil):simulation

local signal = require("digisim.signal")
local low = signal.low
local high = signal.high
local ipairs = ipairs

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"nand",
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
			return self:add_component(name, opts, function(_, a)
				for _, x in ipairs(a) do
					if x ~= high then
						return high
					end
				end
				return low
			end)
		end
	)
end
