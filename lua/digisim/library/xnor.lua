---@class simulation
---@field new_xnor fun(circuit:simulation,name:string,opts:table|nil):simulation

local signal = require("digisim.signal")
local constants = require("digisim.constants")
local ipairs = ipairs
local low = signal.low
local high = signal.high

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
			if constants.NAND_ONLY then
				self:add_component(name, opts)
				local x = name .. ".x"
				self:new_xor(x, { width = width })
				self:c(name, "in", x, "in")
				local n = name .. ".n"
				self:new_not(n)
				self:c(x, "q", n, "a")
				self:c(n, "q", name, "q")
				return self
			else
				return self:add_component(name, opts, function(_, a)
					local ret = false
					for _, x in ipairs(a) do
						if x == high then
							ret = not ret
						end
					end
					return ret and low or high
				end)
			end
		end
	)
end
