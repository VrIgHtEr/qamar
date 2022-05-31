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
				},
			}
			s:add_component(f, opts)

			local nopcode = f .. ".nopcode"
			s:new_not(nopcode, { width = 5 }):cp(5, f, "opcode", 3, nopcode, "a", 1)
			local aluop = f .. ".aluop"
			s:new_and(aluop, { width = 6 })
			s:cp(1, nopcode, "q", 1, aluop, "in", 1)
			s:cp(1, nopcode, "q", 2, aluop, "in", 2)
			s:cp(1, f, "opcode", 5, aluop, "in", 3)
			s:cp(1, nopcode, "q", 5, aluop, "in", 4)
			s:cp(2, f, "opcode", 1, aluop, "in", 5)

			local nf3 = f .. ".nf3"
			s:new_not(nf3, { width = 3 }):c(f, "funct3", nf3, "a")
			local arithmetic = f .. ".arithmetic"
			s:new_and(arithmetic):cp(2, nf3, "q", 1, arithmetic, "in", 1)
			local bitwise = f .. ".bitwise"
			s:new_and(bitwise):cp(2, f, "funct3", 2, bitwise, "in", 1)
			local shift = f .. ".shift"
			s:new_and(shift):cp(1, f, "funct3", 1, shift, "in", 1):cp(1, nf3, "q", 2, shift, "in", 2)
			local sl = f .. ".setless"
			s:new_and(sl):cp(1, nf3, "q", 3, sl, "in", 1):cp(1, f, "funct3", 2, sl, "in", 2)

			local add = f .. ".add"
			s:new_and(add):cp(1, nf3, "q", 3, add, "in", 1):cp(1, arithmetic, "q", 1, add, "in", 2)
			local xor = f .. ".xor"
			s:new_and(xor):cp(1, f, "funct3", 3, xor, "in", 1):cp(1, arithmetic, "q", 1, xor, "in", 2)
			local _and = f .. ".and"
			s:new_and(_and):cp(1, f, "funct3", 1, _and, "in", 1):cp(1, bitwise, "q", 1, _and, "in", 2)
			local _or = f .. ".or"
			s:new_and(_or):cp(1, nf3, "q", 1, _or, "in", 1):cp(1, bitwise, "q", 1, _or, "in", 2)
			local sll = f .. ".sll"
			s:new_and(sll):cp(1, nf3, "q", 3, sll, "in", 1):cp(1, shift, "q", 1, sll, "in", 2)
			local srl = f .. ".srl"
			s:new_and(srl):cp(1, f, "funct3", 3, srl, "in", 1):cp(1, shift, "q", 1, srl, "in", 2)

			local nf7 = f .. ".nf7"
			s:new_not(nf7, { width = 7 }):c(f, "funct7", nf7, "a")
			local f7z = f .. ".f7z"
			s:new_and(f7z, { width = 6 })
			s:cp(5, nf7, "q", 1, f7z, "in", 1)
			s:cp(1, nf7, "q", 7, f7z, "in", 6)

			local nshift = f .. ".nshift"
			s:new_not(nshift):c(shift, "q", nshift, "a")
			local ins = f .. ".ins"
			s:new_and_bank(ins):c(nshift, "q", ins, "a"):cp(1, nopcode, "q", 4, ins, "b", 1)
			local nios = f .. ".nios"
			s:new_or_bank(nios):c(shift, "q", nios, "a"):cp(1, f, "opcode", 6, nios, "b", 1)
			local nios7 = f .. ".nios7"
			s:new_and_bank(nios7):c(nios, "q", nios7, "a"):cp(1, f7z, "q", 1, nios7, "b", 1)
			local vf7 = f .. ".vf7"
			s:new_or_bank(vf7):c(ins, "q", vf7, "a"):c(nios7, "q", vf7, "b")

			local vsubsel = f .. ".vsubsel"
			s:new_or(vsubsel, { width = 4 })
			s:cp(1, bitwise, "q", 1, vsubsel, "in", 1)
			s:cp(1, sl, "q", 1, vsubsel, "in", 2)
			s:cp(1, xor, "q", 1, vsubsel, "in", 3)
			s:cp(1, sll, "q", 1, vsubsel, "in", 4)
			local vsub = f .. ".vsub"
			s:new_nand(vsub):cp(1, f, "funct7", 6, vsub, "in", 1):cp(1, vsubsel, "q", 1, vsub, "in", 2)

			local legal = f .. ".legal"
			s:new_and(legal, { width = 3 })
			s
				:cp(1, vsub, "q", 1, legal, "in", 1)
				:cp(1, aluop, "q", 1, legal, "in", 2)
				:cp(1, vf7, "q", 1, legal, "in", 3)

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
			s:new_tristate_buffer(buf, { width = 7 })
			s:c(activated, "q", buf, "en")
			s
				:cp(1, "VCC", "q", 1, buf, "a", 1)
				:cp(1, "VCC", "q", 1, buf, "a", 2)
				:cp(1, "VCC", "q", 1, buf, "a", 3)
				:cp(1, f, "opcode", 6, buf, "a", 4)
				:cp(1, nopcode, "q", 4, buf, "a", 5)
				:cp(1, cin, "q", 1, buf, "a", 6)
				:cp(1, notb, "q", 1, buf, "a", 7)
			s
				:cp(1, buf, "q", 1, f, "alu_oe", 1)
				:cp(1, buf, "q", 2, f, "rd", 1)
				:cp(1, buf, "q", 3, f, "rs1", 1)
				:cp(1, buf, "q", 4, f, "rs2", 1)
				:cp(1, buf, "q", 5, f, "imm_oe", 1)
				:cp(1, buf, "q", 6, f, "alu_cin", 1)
				:cp(1, buf, "q", 7, f, "alu_notb", 1)
		end
	)
end
