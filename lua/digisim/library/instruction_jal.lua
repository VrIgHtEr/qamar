---@class simulation
---@field new_instruction_jal fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_jal",
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
					{ "opcode", 7 },
					{ "funct3", 3 },
				},
				outputs = {
					"icomplete",
					"legal",
					"pc_oe",
					"b4",
					"alu_oe",
					"rd",
					"imm_oe",
					"branch",
				},
			}
			s:add_component(f, opts)

			local nf3 = f .. ".nf3"
			s:new_nor(nf3, { width = 3 }):c(f, "funct3", nf3, "in")
			local nopcode = f .. ".nopcode"
			s:new_not(nopcode, { width = 5 }):cp(5, f, "opcode", 3, nopcode, "a", 1)

			local legal = f .. ".legal"
			s:new_and(legal, { width = 7 })
			s:cp(4, f, "opcode", 1, legal, "in", 1)
			s:cp(1, nopcode, "q", 3, legal, "in", 5)
			s:cp(2, f, "opcode", 6, legal, "in", 6)

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

			local bufsave = f .. ".bufsave"
			s:new_tristate_buffer(bufsave, { width = 4 })
			s:c(activated, "q", bufsave, "en")
			s:cp(1, "VCC", "q", 1, bufsave, "a", 1)
			s:cp(1, "VCC", "q", 1, bufsave, "a", 2)
			s:cp(1, "VCC", "q", 1, bufsave, "a", 3)
			s:cp(1, "VCC", "q", 1, bufsave, "a", 4)
			s:cp(1, bufsave, "q", 1, f, "pc_oe", 1)
			s:cp(1, bufsave, "q", 2, f, "b4", 1)
			s:cp(1, bufsave, "q", 3, f, "alu_oe", 1)
			s:cp(1, bufsave, "q", 4, f, "rd", 1)

			local bufcomplete = f .. ".bufcomplete"
			s:new_tristate_buffer(bufcomplete, { width = 5 })
			s:c(trignext, "q", bufcomplete, "en")
			s:cp(1, "VCC", "q", 1, bufcomplete, "a", 1)
			s:cp(1, "VCC", "q", 1, bufcomplete, "a", 2)
			s:cp(1, "VCC", "q", 1, bufcomplete, "a", 3)
			s:cp(1, "VCC", "q", 1, bufcomplete, "a", 4)
			s:cp(1, "VCC", "q", 1, bufcomplete, "a", 5)
			s:cp(1, bufcomplete, "q", 1, f, "pc_oe", 1)
			s:cp(1, bufcomplete, "q", 2, f, "imm_oe", 1)
			s:cp(1, bufcomplete, "q", 3, f, "branch", 1)
			s:cp(1, bufcomplete, "q", 4, f, "icomplete", 1)
			s:cp(1, bufcomplete, "q", 5, f, "alu_oe", 1)
		end
	)
end
