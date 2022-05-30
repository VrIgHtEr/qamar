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
					"sela",
					"selb",
					"selw",
					"alu_oe",
					"alu_notb",
					"alu_cin",
					"imm_oe",
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

			local nsub = f .. ".nsub"
			s:new_not(nsub):c(f, "sub", nsub, "a")
			local vsubsel = f .. ".vsubsel"
			s:new_or(vsubsel, { width = 4 })
			s:cp(1, bitwise, "q", 1, vsubsel, "in", 1)
			s:cp(1, sl, "q", 1, vsubsel, "in", 2)
			s:cp(1, xor, "q", 1, vsubsel, "in", 3)
			s:cp(1, sll, "q", 1, vsubsel, "in", 4)
			local vsub = f .. ".vsub"
			s:new_nand(vsub):cp(1, nsub, "q", 1, vsub, "in", 1)
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
		end
	)
end
