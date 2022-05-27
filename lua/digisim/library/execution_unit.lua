---@class simulation
---@field new_execution_unit fun(circuit:simulation,name:string,opts:table|nil):simulation

local BITS = 32

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"execution_unit",
		---@param s simulation
		---@param f string
		---@param opts boolean
		function(s, f, opts)
			opts = opts or {}
			opts.names = {
				inputs = {
					{ "d", BITS },
					"trigin",
					"rising",
					"falling",
					"rst~",
					"lsu_trigout",
				},
				outputs = {},
			}
			s:add_component(f, opts)
			local s0 = f .. ".s0"
			s:new_ms_d_flipflop(s0)
			local s1 = f .. ".s1"
			s:new_ms_d_flipflop(s1)

			local ntrigout = f .. ".ntrigout"
			s:new_not(ntrigout):c(f, "lsu_trigout", ntrigout, "a")

			local c00 = f .. ".c00"
			s:new_and_bank(c00):c(s0, "q", c00, "a"):c(ntrigout, "q", c00, "b")
			local c0 = f .. ".c0"
			s:new_or_bank(c0):c(f, "trigin", c0, "a"):c(c00, "q", c0, "b")
			local c1 = f .. ".c1"
			s:new_and_bank(c1):c(s0, "q", c1, "a"):c(f, "lsu_trigout", c1, "b")

			local ireg = f .. ".ireg"
			s:new_ms_d_flipflop_bank(ireg, { width = BITS })
		end
	)
end
