---@class simulation
---@field new_instruction_branch fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_branch",
		---@param s simulation
		---@param f string
		---@param opts boolean
		function(s, f, opts)
			opts = opts or {}
			opts.names = {
				inputs = {
					"rst~",
					"rising",
					"falling",
					"isched",
					"zero",
					{ "opcode", 7 },
					{ "funct3", 3 },
				},
				outputs = {
					"icomplete",
					"legal",
					"alu_oe",
					"rs1",
					"rs2",
					"imm_oe",
					"alu_notb",
					"alu_cin",
				},
			}
			s:add_component(f, opts)

			local nopcode = f .. ".nopcode"
			s:new_not(nopcode, { width = 5 }):cp(5, f, "opcode", 3, nopcode, "a", 1)
			local brop = f .. ".brop"
			s:new_and(brop, { width = 7 })
			s:cp(2, f, "opcode", 1, brop, "in", 1)
			s:cp(3, nopcode, "q", 1, brop, "in", 3)
			s:cp(2, f, "opcode", 6, brop, "in", 6)

			local nf3 = f .. ".nf3"
			s:new_not(nf3, { width = 3 }):c(f, "funct3", nf3, "a")
			local sl = f .. ".setless"
			s:new_nand(sl):cp(1, nf3, "q", 3, sl, "in", 1):cp(1, f, "funct3", 2, sl, "in", 2)

			local legal = f .. ".legal"
			s:new_and(legal)
			s:cp(1, brop, "q", 1, legal, "in", 1):cp(1, sl, "q", 1, legal, "in", 2)

			local legalbuf = f .. ".legalbuf"
			s
				:new_tristate_buffer(legalbuf)
				:c(legal, "q", legalbuf, "en")
				:c("VCC", "q", legalbuf, "a")
				:c(legalbuf, "q", f, "legal")

			local visched = f .. ".visched"
			s:new_and(visched):cp(1, f, "isched", 1, visched, "in", 1):cp(1, legal, "q", 1, visched, "in", 2)

			local activated = f .. ".activated"
			s:new_ms_d_flipflop(activated)
			s:c(f, "rst~", activated, "rst~")
			s:c(f, "rising", activated, "rising")
			s:c(f, "falling", activated, "falling")
			s:c(visched, "q", activated, "d")
			local trignext = f .. ".trignext"
			s:new_ms_d_flipflop(trignext)
			s:c(f, "rst~", trignext, "rst~")
			s:c(f, "rising", trignext, "rising")
			s:c(f, "falling", trignext, "falling")
			s:c(activated, "q", trignext, "d")

			local test = f .. ".test"
			s:new_tristate_buffer(test, { width = 4 })
			s:c(visched, "q", test, "en")
			s:cp(1, "VCC", "q", 1, test, "a", 1)
			s:cp(1, "VCC", "q", 1, test, "a", 2)
			s:cp(1, "VCC", "q", 1, test, "a", 3)
			s:cp(1, "VCC", "q", 1, test, "a", 4)
			s:cp(1, test, "q", 1, f, "rs1", 1)
			s:cp(1, test, "q", 2, f, "rs2", 1)
			s:cp(1, test, "q", 3, f, "alu_notb", 1)
			s:cp(1, test, "q", 4, f, "alu_cin", 1)

			local icomplete = f .. ".icomplete"
			s:new_tristate_buffer(icomplete):c(trignext, "q", icomplete, "en"):c("VCC", "q", icomplete, "a")
			s:c(icomplete, "q", f, "icomplete")
		end
	)
end
