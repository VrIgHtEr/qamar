---@class simulation
---@field new_not fun(circuit:simulation,name:string,opts:table|nil):simulation

local signal = require("digisim.signal")
local constants = require("digisim.constants")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"not",
		---@param s simulation
		---@param n string
		---@param opts boolean
		function(s, n, opts)
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
			if constants.NAND_ONLY then
				s:add_component(n, nil, opts)
				for i = 1, width do
					local x = n .. ".i" .. (i - 1)
					s:new_nand(x)
					s:cp(1, x, "in", 1, x, "in", 2)
					s:cp(1, n, "a", i, x, "in", 1)
					s:cp(1, x, "q", 1, n, "q", i)
				end
				return s
			else
				return s:add_component(n, function(_, a)
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
		end
	)
end
