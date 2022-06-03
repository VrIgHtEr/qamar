---@class simulation
---@field new_instruction_op fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_op",
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
					{ "funct7", 7 },
					{ "opcode", 7 },
					{ "funct3", 3 },
				},
				outputs = {
					"icomplete",
					"legal",
					"alu_oe",
					"rd",
					"rs1",
					"rs2",
					"imm_oe",
					"alu_notb",
					"alu_cin",
					{ "alu_sel", 3 },
				},
			}
			s:add_component(f, opts)

			local nopcode = f .. ".nopcode"
			s:new_not(nopcode, { width = 5 }):cp(5, f, "opcode", 3, nopcode, "a", 1)
			local nf3 = f .. ".nf3"
			s:new_not(nf3, { width = 3 }):c(f, "funct3", nf3, "a")
			local nf7 = f .. ".nf7"
			s:new_not(nf7, { width = 7 }):c(f, "funct7", nf7, "a")

			local aluop = f .. ".aluop"
			s:new_and(aluop, { width = 6 })
			s:cp(2, f, "opcode", 1, aluop, "in", 1)
			s:cp(2, nopcode, "q", 1, aluop, "in", 3)
			s:cp(1, f, "opcode", 5, aluop, "in", 5)
			s:cp(1, nopcode, "q", 5, aluop, "in", 6)

			local f7z = f .. ".f7z"
			s:new_and(f7z, { width = 6 }):cp(5, f, "funct7", 1, f7z, "in", 1):cp(1, f, "funct7", 7, f7z, "in", 6)

			local shift = f .. ".shift"
			s:new_and(shift):cp(1, f, "funct3", 1, shift, "in", 1):cp(1, nf3, "q", 2, shift, "in", 2)
			local nshift = f .. ".nshift"
			s:new_not(nshift):c(shift, "q", nshift, "a")

			local immshift = f .. ".immshift"
			s:new_and_bank(immshift):cp(1, nopcode, "q", 4, immshift, "a", 1):c(shift, "q", immshift, "b")
			local immshiftnimm = f .. ".immshiftnimm"
			s:new_or_bank(immshiftnimm):cp(1, f, "opcode", 6, immshiftnimm, "a", 1):c(immshift, "q", immshiftnimm, "b")
			local immshiftnimmf7z = f .. ".immshiftnimmf7z"
			s:new_and_bank(immshiftnimmf7z):c(f7z, "q", immshiftnimmf7z, "a"):c(immshiftnimm, "q", immshiftnimmf7z, "b")
			local immnshift = f .. ".immnshift"
			s:new_and_bank(immnshift):cp(1, nopcode, "q", 4, immnshift, "a", 1):c(nshift, "q", immnshift, "b")
			local vf7z = f .. ".vf7z"
			s:new_and_bank(vf7z):c(immnshift, "q", vf7z, "a"):c(immshiftnimmf7z, "q", vf7z, "b")

			local add = f .. ".add"
			s:new_and(add, { width = 3 }):c(nf3, "q", add, "in")
			local sr = f .. ".sr"
			s:new_and_bank(sr):c(shift, "q", sr, "a"):cp(1, f, "funct3", 3, sr, "b", 1)

			local srnshift = f .. ".srnshift"
			s:new_or_bank(srnshift):c(sr, "q", srnshift, "a"):c(nshift, "q", srnshift, "b")
			local sradd = f .. ".sradd"
			s:new_or_bank(sradd):c(sr, "q", sradd, "a"):c(add, "q", sradd, "b")
			local immsrnshift = f .. ".immsrnshift"
			s:new_and_bank(immsrnshift):cp(1, nopcode, "q", 4, immsrnshift, "a", 1):c(srnshift, "q", immsrnshift, "b")
			local nimmsradd = f .. ".nimmsradd"
			s:new_and_bank(nimmsradd):cp(1, f, "opcode", 6, nimmsradd, "a", 1):c(sradd, "q", nimmsradd, "b")
			local asub = f .. ".asub"
			s:new_or_bank(asub):c(immsrnshift, "q", asub, "a"):c(nimmsradd, "q", asub, "b")
			local nasub = f .. ".nasub"
			s:new_not(nasub):c(asub, "q", nasub, "a")

			local subnasub = f .. ".subnasub"
			s:new_and_bank(subnasub):c(nasub, "q", subnasub, "a"):cp(1, nf7, "q", 6, subnasub, "b", 1)
			local vsub = f .. ".vsub"
			s:new_or_bank(vsub):c(asub, "q", vsub, "a"):c(subnasub, "q", vsub, "b")

			local legal = f .. ".legal"
			s:new_and(legal, { width = 3 })
			s
				:cp(1, vf7z, "q", 1, legal, "in", 1)
				:cp(1, vsub, "q", 1, legal, "in", 2)
				:cp(1, aluop, "q", 1, legal, "in", 3)

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

			local icomplete = f .. ".icomplete"
			s:new_tristate_buffer(icomplete):c(trignext, "q", icomplete, "en"):c("VCC", "q", icomplete, "a")
			s:c(icomplete, "q", f, "icomplete")

			local srl = f .. ".srl"
			s:new_and_bank(srl):c(sr, "q", srl, "a"):cp(1, f, "funct7", 6, srl, "b", 1)
			local cina = f .. ".cina"
			s:new_and(cina)
			s:cp(1, f, "funct7", 6, cina, "in", 1)
			s:cp(1, f, "opcode", 6, cina, "in", 2)
			local cinb = f .. ".cinb"
			s:new_and(cinb)
			s:cp(1, f, "funct7", 6, cinb, "in", 1)
			s:cp(1, srl, "q", 1, cinb, "in", 2)
			local cin = f .. ".cin"
			s:new_or(cin)
			s:cp(1, cina, "q", 1, cin, "in", 1)
			s:cp(1, cinb, "q", 1, cin, "in", 2)
			local notb = f .. ".notb"
			s:new_and(notb)
			s:cp(1, add, "q", 1, notb, "in", 1)
			s:cp(1, cin, "q", 1, notb, "in", 2)

			local buf = f .. ".buf"
			s:new_tristate_buffer(buf, { width = 10 })
			s:c(activated, "q", buf, "en")
			s
				:cp(1, "VCC", "q", 1, buf, "a", 1)
				:cp(1, "VCC", "q", 1, buf, "a", 2)
				:cp(1, "VCC", "q", 1, buf, "a", 3)
				:cp(1, f, "opcode", 6, buf, "a", 4)
				:cp(1, nopcode, "q", 4, buf, "a", 5)
				:cp(1, cin, "q", 1, buf, "a", 6)
				:cp(1, notb, "q", 1, buf, "a", 7)
				:cp(3, f, "funct3", 1, buf, "a", 8)
			s
				:cp(1, buf, "q", 1, f, "alu_oe", 1)
				:cp(1, buf, "q", 2, f, "rd", 1)
				:cp(1, buf, "q", 3, f, "rs1", 1)
				:cp(1, buf, "q", 4, f, "rs2", 1)
				:cp(1, buf, "q", 5, f, "imm_oe", 1)
				:cp(1, buf, "q", 6, f, "alu_cin", 1)
				:cp(1, buf, "q", 7, f, "alu_notb", 1)
				:cp(3, buf, "q", 8, f, "alu_sel", 1)
		end
	)
end
