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
					"sub",
					{ "opcode", 5 },
					{ "funct3", 3 },
				},
				outputs = {
					"icomplete",
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
			s:new_not(nopcode, { width = 5 }):c(f, "opcode", nopcode, "a")
			local aluop = f .. ".aluop"
			s:new_and(aluop, { width = 4 })
			s:cp(1, nopcode, "q", 1, aluop, "in", 1)
			s:cp(1, nopcode, "q", 2, aluop, "in", 2)
			s:cp(1, f, "opcode", 3, aluop, "in", 3)
			s:cp(1, nopcode, "q", 5, aluop, "in", 4)

			local nf3 = f .. ".nf3"
			s:new_not(nf3, { width = 3 }):c(f, "funct3", nf3, "a")
			local arithmetic = f .. ".arithmetic"
			s:new_and(arithmetic):cp(2, nf3, "q", 1, arithmetic, "in", 1)
			local bitwise = f .. ".bitwise"
			s:new_and(bitwise):cp(2, f, "funct3", 2, bitwise, "in", 1)
			local shift = f .. ".shift"
			s:new_and(shift):cp(1, f, "funct3", 1, shift, "in", 1):cp(1, nf3, "q", 1, shift, "in", 2)
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

			local vsubsel = f .. ".vsubsel"
			s:new_or(vsubsel, { width = 4 })
			s:cp(1, bitwise, "q", 1, vsubsel, "in", 1)
			s:cp(1, sl, "q", 1, vsubsel, "in", 2)
			s:cp(1, xor, "q", 1, vsubsel, "in", 3)
			s:cp(1, sll, "q", 1, vsubsel, "in", 4)
			local vsub = f .. ".vsub"
			s:new_nand(vsub):cp(1, f, "sub", 1, vsub, "in", 1):cp(1, vsubsel, "q", 1, vsub, "in", 2)
			local visched = f .. ".visched"
			s:new_and(visched, { width = 3 })
			s
				:cp(1, vsub, "q", 1, visched, "in", 1)
				:cp(1, f, "isched", 1, visched, "in", 2)
				:cp(1, aluop, "q", 1, visched, "in", 3)

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
			s:c(trignext, "q", f, "icomplete")

			local cin = f .. ".cin"
			s:new_and(cin)
			s:cp(1, f, "sub", 1, cin, "in", 1)
			s:cp(1, f, "opcode", 4, cin, "in", 2)
			local notb = f .. ".notb"
			s:new_and(notb)
			s:cp(1, add, "q", 1, notb, "in", 1)
			s:cp(1, cin, "q", 1, notb, "in", 2)

			local buf1 = f .. ".buf1"
			s:new_tristate_buffer(buf1, { width = 7 })
			s:c(activated, "q", buf1, "en")
			s
				:cp(1, "VCC", "q", 1, buf1, "a", 1)
				:cp(1, "VCC", "q", 1, buf1, "a", 2)
				:cp(1, "VCC", "q", 1, buf1, "a", 3)
				:cp(1, f, "opcode", 4, buf1, "a", 4)
				:cp(1, nopcode, "q", 4, buf1, "a", 5)
				:cp(1, cin, "q", 1, buf1, "a", 6)
				:cp(1, notb, "q", 1, buf1, "a", 7)
			s
				:cp(1, buf1, "q", 1, f, "alu_oe", 1)
				:cp(1, buf1, "q", 2, f, "rd", 1)
				:cp(1, buf1, "q", 3, f, "rs1", 1)
				:cp(1, buf1, "q", 4, f, "rs2", 1)
				:cp(1, buf1, "q", 5, f, "imm_oe", 1)
				:cp(1, buf1, "q", 6, f, "alu_cin", 1)
				:cp(1, buf1, "q", 7, f, "alu_notb", 1)
		end
	)
end
