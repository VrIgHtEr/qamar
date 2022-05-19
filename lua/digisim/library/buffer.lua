---@class simulation
---@field new_buffer fun(circuit:simulation,name:string,opts:table|nil):simulation

local constants = require("digisim.constants")

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"buffer",
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
				s:add_component(n, opts)
				for i = 1, width do
					local a = n .. ".a" .. (i - 1)
					local b = n .. ".b" .. (i - 1)
					s:new_not(a, { width = width })
					s:new_not(b, { width = width })
					s:c(n, "a", a, "a")
					s:c(a, "q", b, "a")
					s:c(b, "q", n, "q")
				end
				return s
			else
				return s:add_component(n, opts, function(_, a)
					return a
				end)
			end
		end
	)
end
