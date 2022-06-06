---@class simulation
---@field new_instruction_jalr fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_jalr",
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
					{ "d", 32 },
				},
				outputs = {
					"icomplete",
					"legal",
					"pc_oe",
					"b4",
					"alu_oe",
					"rd",
					"rs1",
					"imm_oe",
					"branch",
				},
			}
			s:add_component(f, opts)

			local nopcode = f .. ".nopcode"
			s:new_not(nopcode, { width = 5 }):cp(5, f, "opcode", 3, nopcode, "a", 1)
			local nf3 = f .. ".nf3"
			s:new_nor(nf3, { width = 3 }):c(f, "funct3", nf3, "in")

			local legal = f .. ".legal"
			s:new_and(legal, { width = 8 })
			s:cp(3, f, "opcode", 1, legal, "in", 1)
			s:cp(2, nopcode, "q", 2, legal, "in", 4)
			s:cp(2, f, "opcode", 6, legal, "in", 6)
			s:cp(1, nf3, "q", 1, legal, "in", 8)

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

			local tempregen = f .. ".tempregen"
			s:new_and_bank(tempregen):c(activated, "q", tempregen, "a"):c(f, "rising", tempregen, "b")
			local tempreg = f .. ".tempreg"
			s:new_ms_d_flipflop_bank(tempreg, { width = 32 })
			s:c(f, "rst~", tempreg, "rst~")
			s:c(tempregen, "q", tempreg, "rising")
			s:c(f, "falling", tempreg, "falling")
			s:c(f, "d", tempreg, "d")

			local tempsavebuf = f .. ".tempsavebuf"
			s:new_tristate_buffer(tempsavebuf, { width = 3 })
			s:c(activated, "q", tempsavebuf, "en")
			s:cp(1, "VCC", "q", 1, tempsavebuf, "a", 1)
			s:cp(1, "VCC", "q", 1, tempsavebuf, "a", 2)
			s:cp(1, "VCC", "q", 1, tempsavebuf, "a", 3)
			s:cp(1, tempsavebuf, "q", 1, f, "pc_oe", 1)
			s:cp(1, tempsavebuf, "q", 2, f, "b4", 1)
			s:cp(1, tempsavebuf, "q", 3, f, "alu_oe", 1)

			local upc = f .. ".upc"
			s:new_ms_d_flipflop(upc)
			s:c(f, "rst~", upc, "rst~")
			s:c(f, "rising", upc, "rising")
			s:c(f, "falling", upc, "falling")
			s:c(activated, "q", upc, "d")

			local upcbuf = f .. ".upcbuf"
			s:new_tristate_buffer(upcbuf, { width = 4 })
			s:c(upc, "q", upcbuf, "en")
			s:cp(1, "VCC", "q", 1, upcbuf, "a", 1)
			s:cp(1, "VCC", "q", 1, upcbuf, "a", 2)
			s:cp(1, "VCC", "q", 1, upcbuf, "a", 3)
			s:cp(1, "VCC", "q", 1, upcbuf, "a", 4)
			s:cp(1, upcbuf, "q", 1, f, "pc_oe", 1)
			s:cp(1, upcbuf, "q", 2, f, "rs1", 1)
			s:cp(1, upcbuf, "q", 3, f, "branch", 1)
			s:cp(1, upcbuf, "q", 4, f, "alu_oe", 1)

			local save = f .. ".save"
			s:new_ms_d_flipflop(save)
			s:c(f, "rst~", save, "rst~")
			s:c(f, "rising", save, "rising")
			s:c(f, "falling", save, "falling")
			s:c(upc, "q", save, "d")

			local savebuf = f .. ".savebuf"
			s:new_tristate_buffer(savebuf, { width = 33 })
			s:c(save, "q", savebuf, "en")
			s:cp(1, "VCC", "q", 1, savebuf, "a", 1)
			s:cp(32, f, "d", 1, savebuf, "a", 2)
			s:cp(1, savebuf, "q", 1, f, "rd", 1)
			s:cp(32, savebuf, "q", 2, f, "d", 1)

			local complete = f .. ".complete"
			s:new_ms_d_flipflop(complete)
			s:c(f, "rst~", complete, "rst~")
			s:c(f, "rising", complete, "rising")
			s:c(f, "falling", complete, "falling")
			s:c(save, "q", complete, "d")

			local completebuf = f .. ".completebuf"
			s:new_tristate_buffer(completebuf, { width = 5 })
			s:c(complete, "q", completebuf, "en")
			s:cp(1, "VCC", "q", 1, completebuf, "a", 1)
			s:cp(1, "VCC", "q", 1, completebuf, "a", 2)
			s:cp(1, "VCC", "q", 1, completebuf, "a", 3)
			s:cp(1, "VCC", "q", 1, completebuf, "a", 4)
			s:cp(1, "VCC", "q", 1, completebuf, "a", 5)
			s:cp(1, completebuf, "q", 1, f, "pc_oe", 1)
			s:cp(1, completebuf, "q", 2, f, "imm_oe", 1)
			s:cp(1, completebuf, "q", 3, f, "alu_oe", 1)
			s:cp(1, completebuf, "q", 4, f, "branch", 1)
			s:cp(1, completebuf, "q", 5, f, "icomplete", 1)
		end
	)
end
