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
				outputs = {
					"isched",
					"lsu_trigin",
					{ "lsu_control", 2 },
					{ "ireg", BITS },
				},
			}
			s:add_component(f, opts)
			local s0 = f .. ".s0"
			s:new_ms_d_flipflop(s0):c(f, "rst~", s0, "rst~"):c(f, "rising", s0, "rising"):c(f, "falling", s0, "falling")
			local s1 = f .. ".s1"
			s:new_ms_d_flipflop(s1):c(f, "rst~", s1, "rst~"):c(f, "rising", s1, "rising"):c(f, "falling", s1, "falling")

			local ntrigout = f .. ".ntrigout"
			s:new_not(ntrigout):c(f, "lsu_trigout", ntrigout, "a")

			local c00 = f .. ".c00"
			s:new_and_bank(c00):c(s0, "q", c00, "a"):c(ntrigout, "q", c00, "b")
			local c0 = f .. ".c0"
			s:new_or_bank(c0):c(f, "trigin", c0, "a"):c(c00, "q", c0, "b"):c(c0, "q", s0, "d")
			local c1 = f .. ".c1"
			s
				:new_and_bank(c1)
				:c(s0, "q", c1, "a")
				:c(f, "lsu_trigout", c1, "b")
				:c(c1, "q", s1, "d")
				:c(c1, "q", f, "isched")

			local cs0 = f .. ".cs0"
			s:new_and_bank(cs0):c(s0, "q", cs0, "a"):c(f, "rising", cs0, "b")

			local ireg = f .. ".ireg"
			s
				:new_ms_d_flipflop_bank(ireg, { width = BITS })
				:c(f, "rst~", ireg, "rst~")
				:c(f, "falling", ireg, "falling")
				:c(cs0, "q", ireg, "rising")
			local iregmux = f .. ".iregmux"
			s
				:new_mux_bank(iregmux, { bits = BITS, width = 1 })
				:c(iregmux, "out", f, "ireg")
				:c(s0, "q", iregmux, "sel")
				:c(f, "d", iregmux, "d1")
				:c(ireg, "q", iregmux, "d0")
				:c(iregmux, "out", ireg, "d")
		end
	)
end
