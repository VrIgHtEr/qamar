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
					"lt",
					{ "opcode", 7 },
					{ "funct3", 3 },
				},
				outputs = {
					"icomplete",
					"legal",
					"alu_oe",
					"alu_u",
					"rs1",
					"rs2",
					"imm_oe",
					"alu_notb",
					"alu_cin",
					"pc_oe",
					"branch",
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
			local legalf3 = f .. ".legalf3"
			s:new_nand(legalf3):cp(1, nf3, "q", 3, legalf3, "in", 1):cp(1, f, "funct3", 2, legalf3, "in", 2)

			local eq = f .. ".eq"
			s:new_and(eq):cp(1, nf3, "q", 3, eq, "in", 1):cp(1, nf3, "q", 2, eq, "in", 2)

			local unsigned = f .. ".u"
			s:new_and(unsigned):cp(1, f, "funct3", 3, unsigned, "in", 1):cp(1, f, "funct3", 2, unsigned, "in", 2)

			local signed = f .. ".s"
			s:new_and(signed):cp(1, f, "funct3", 3, signed, "in", 1):cp(1, f, "funct3", 2, signed, "in", 2)

			local legal = f .. ".legal"
			s:new_and(legal)
			s:cp(1, brop, "q", 1, legal, "in", 1):cp(1, legalf3, "q", 1, legal, "in", 2)

			local legalbuf = f .. ".legalbuf"
			s
				:new_tristate_buffer(legalbuf)
				:c(legal, "q", legalbuf, "en")
				:high(legalbuf, "a")
				:c(legalbuf, "q", f, "legal")

			local visched = f .. ".visched"
			s:new_and(visched):cp(1, f, "isched", 1, visched, "in", 1):cp(1, legal, "q", 1, visched, "in", 2)

			local beq = f .. ".beq"
			s:new_and_bank(beq):c(eq, "q", beq, "a"):c(f, "zero", beq, "b")
			local neq = f .. ".neq"
			s:new_not(neq):c(eq, "q", neq, "a")
			local blt = f .. ".blt"
			s:new_and_bank(blt):c(neq, "q", blt, "a"):c(f, "lt", blt, "b")
			local branch = f .. ".branch"
			s:new_or(branch)
			s:cp(1, beq, "q", 1, branch, "in", 1)
			s:cp(1, blt, "q", 1, branch, "in", 2)

			local decision = f .. ".decision"
			s:new_xor(decision):cp(1, f, "funct3", 2, decision, "in", 1):cp(1, branch, "q", 1, decision, "in", 2)

			local brlatchclk = f .. ".brlatchclk"
			s:new_and_bank(brlatchclk):c(visched, "q", brlatchclk, "a"):c(f, "rising", brlatchclk, "b")
			local brlatch = f .. ".brlatch"
			s:new_ms_d_flipflop(brlatch)
			s:c(f, "rst~", brlatch, "rst~")
			s:c(brlatchclk, "q", brlatch, "rising")
			s:c(f, "falling", brlatch, "falling")
			s:c(decision, "q", brlatch, "d")

			local test = f .. ".test"
			s:new_tristate_buffer(test, { width = 5 })
			s:c(visched, "q", test, "en")
			s:high(test, "a", 1, 4)
			s:cp(1, unsigned, "q", 1, test, "a", 5)
			s:cp(1, test, "q", 1, f, "rs1", 1)
			s:cp(1, test, "q", 2, f, "rs2", 1)
			s:cp(1, test, "q", 3, f, "alu_notb", 1)
			s:cp(1, test, "q", 4, f, "alu_cin", 1)
			s:cp(1, test, "q", 5, f, "alu_u", 1)

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

			local actionen = f .. ".actionen"
			s
				:new_and(actionen, { width = 2 })
				:cp(1, trignext, "q", 1, actionen, "in", 1)
				:cp(1, brlatch, "q", 1, actionen, "in", 2)
			local action = f .. ".action"
			s:new_tristate_buffer(action, { width = 4 })
			s:c(actionen, "q", action, "en")
			s:high(action, "a", 1, 4)
			s:cp(1, action, "q", 1, f, "alu_oe", 1)
			s:cp(1, action, "q", 2, f, "imm_oe", 1)
			s:cp(1, action, "q", 3, f, "pc_oe", 1)
			s:cp(1, action, "q", 4, f, "branch", 1)

			local icompletebuf = f .. ".icompletebuf"
			s:new_tristate_buffer(icompletebuf):c(trignext, "q", icompletebuf, "en"):high(icompletebuf, "a")
			s:c(icompletebuf, "q", f, "icomplete")
		end
	)
end
