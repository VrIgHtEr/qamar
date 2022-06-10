---@class simulation
---@field new_instruction_load fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_load",
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
					"lu_trigout",
					{ "opcode", 7 },
					{ "funct3", 3 },
				},
				outputs = {
					"icomplete",
					"legal",
					"imm_oe",
					"rs1",
					"rs2",
					"rd",
					"alu_oe",
					"lu_trigin",
					"lu_sext",
					{ "lu_control", 2 },
				},
			}
			s:add_component(f, opts)

			local nopcode = f .. ".nopcode"
			s:new_not(nopcode, { width = 5 }):cp(5, f, "opcode", 3, nopcode, "a", 1)

			local nf3 = f .. ".nf3"
			s:new_not(nf3, { width = 3 }):c(f, "funct3", nf3, "a")

			local is_load = f .. ".is_l"
			s:new_and(is_load, { width = 7 })
			s:cp(2, f, "opcode", 1, is_load, "in", 1)
			s:cp(5, nopcode, "q", 1, is_load, "in", 3)

			local is_not_invalid_funct3 = f .. ".is_not_inv_f3"
			s:new_nand(is_not_invalid_funct3):cp(2, f, "funct3", 1, is_not_invalid_funct3, "in", 1)
			local is_valid_signed_funct3 = f .. ".is_valid_signed_f3"
			s:new_and_bank(is_valid_signed_funct3)
			s:cp(1, nf3, "q", 3, is_valid_signed_funct3, "a", 1)
			s:c(is_not_invalid_funct3, "q", is_valid_signed_funct3, "b")

			local is_valid_load_u = f .. ".is_val_load_u"
			s
				:new_and(is_valid_load_u)
				:cp(1, f, "funct3", 3, is_valid_load_u, "in", 1)
				:cp(1, nf3, "q", 2, is_valid_load_u, "in", 2)

			local is_valid = f .. ".valid"
			s:new_or_bank(is_valid):c(is_valid_signed_funct3, "q", is_valid, "a"):c(is_valid_load_u, "q", is_valid, "b")

			local legal = f .. ".legal"
			s:new_and_bank(legal)
			s:c(is_load, "q", legal, "a")
			s:c(is_valid, "q", legal, "b")

			local legalbuf = f .. ".legalbuf"
			s
				:new_tristate_buffer(legalbuf)
				:c(legal, "q", legalbuf, "en")
				:high(legalbuf, "a")
				:c(legalbuf, "q", f, "legal")

			local visched = f .. ".visched"
			s:new_and(visched):cp(1, f, "isched", 1, visched, "in", 1):cp(1, legal, "q", 1, visched, "in", 2)

			local activated = f .. ".activated"
			s:new_ms_d_flipflop(activated)
			s:c(f, "rst~", activated, "rst~")
			s:c(f, "rising", activated, "rising")
			s:c(f, "falling", activated, "falling")
			s:c(visched, "q", activated, "d")

			local trigloaden = f .. ".loaden"
			s:new_and_bank(trigloaden):c(is_valid, "q", trigloaden, "a"):c(activated, "q", trigloaden, "b")

			local trigload = f .. ".dload"
			s:new_ms_d_flipflop(trigload)
			s:c(f, "rst~", trigload, "rst~")
			s:c(f, "rising", trigload, "rising")
			s:c(f, "falling", trigload, "falling")
			s:c(trigloaden, "q", trigload, "d")

			local wait = f .. ".wait"
			s:new_ms_d_flipflop(wait)
			s:c(f, "rst~", wait, "rst~")
			s:c(f, "rising", wait, "rising")
			s:c(f, "falling", wait, "falling")

			local ntrigout = f .. ".ntrigout"
			s:new_not(ntrigout):c(f, "lu_trigout", ntrigout, "a")
			local cs12 = f .. ".cs12"
			s:new_or_bank(cs12):c(trigload, "q", cs12, "a"):c(wait, "q", cs12, "b")
			local waiten = f .. ".waiten"
			s:new_and_bank(waiten):c(cs12, "q", waiten, "a"):c(ntrigout, "q", waiten, "b")
			s:c(waiten, "q", wait, "d")

			local saveen = f .. ".saveen"
			s:new_and_bank(saveen):c(cs12, "q", saveen, "a"):c(f, "lu_trigout", saveen, "b")

			local save = f .. ".save"
			s:new_ms_d_flipflop(save)
			s:c(f, "rst~", save, "rst~")
			s:c(f, "rising", save, "rising")
			s:c(f, "falling", save, "falling")
			s:c(saveen, "q", save, "d")

			local complete = f .. ".complete"
			s:new_ms_d_flipflop(complete)
			s:c(f, "rst~", complete, "rst~")
			s:c(f, "rising", complete, "rising")
			s:c(f, "falling", complete, "falling")
			s:c(save, "q", complete, "d")

			local halfword = f .. ".halfword"
			s:new_or(halfword):cp(2, f, "funct3", 1, halfword, "in", 1)

			local trigloadbuf = f .. ".trigloadbuf"
			s:new_tristate_buffer(trigloadbuf, { width = 6 })
			s:c(activated, "q", trigloadbuf, "en")
			s
				:high(trigloadbuf, "a", 1, 4)
				:cp(1, halfword, "q", 1, trigloadbuf, "a", 5)
				:cp(1, f, "funct3", 2, trigloadbuf, "a", 6)
			s
				:cp(1, trigloadbuf, "q", 1, f, "rs1", 1)
				:cp(1, trigloadbuf, "q", 2, f, "imm_oe", 1)
				:cp(1, trigloadbuf, "q", 3, f, "alu_oe", 1)
				:cp(1, trigloadbuf, "q", 4, f, "lu_trigin", 1)
				:cp(2, trigloadbuf, "q", 5, f, "lu_control", 1)

			local trigsave = f .. ".trigsave"
			s:new_tristate_buffer(trigsave, { width = 2 })
			s:c(saveen, "q", trigsave, "en")
			s:high(trigsave, "a", 1, 1)
			s:cp(1, nf3, "q", 3, trigsave, "a", 2)
			s:cp(1, trigsave, "q", 1, f, "rd", 1)
			s:cp(1, trigsave, "q", 2, f, "lu_sext", 1)

			local trigcomplete = f .. ".trigcomplete"
			s:new_tristate_buffer(trigcomplete)
			s:c(save, "q", trigcomplete, "en")
			s:high(trigcomplete, "a", 1, 1)
			s:cp(1, trigcomplete, "q", 1, f, "icomplete", 1)
		end
	)
end
