---@class simulation
---@field new_instruction_decoder fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_decoder",
		---@param self simulation
		---@param name string
		---@param opts boolean
		function(self, name, opts)
			opts = opts or {}
			opts.names = {
				inputs = { { "in", 32 } },
				outputs = {
					"r",
					"i",
					"s",
					"b",
					"u",
					"j",
					"illegal",
					{ "opcode", 7 },
					{ "rd", 5 },
					{ "funct3", 3 },
					{ "rs1", 5 },
					{ "rs2", 5 },
					{ "funct7", 7 },
					{ "imm", 32 },
				},
			}
			self:add_component(name, opts)
			self:cp(7, name, "in", 1, name, "opcode", 1)
			self:cp(5, name, "in", 8, name, "rd", 1)
			self:cp(3, name, "in", 13, name, "funct3", 1)
			self:cp(5, name, "in", 16, name, "rs1", 1)
			self:cp(5, name, "in", 21, name, "rs2", 1)
			self:cp(7, name, "in", 26, name, "funct7", 1)

			-- decode I immediate
			local immi = name .. ".immi"
			self:new_tristate_buffer(immi, { width = 32 })
			self:c(name, "i", immi, "en")
			self:cp(12, name, "in", 21, immi, "a", 1)
			for i = 13, 32 do
				self:cp(1, name, "in", 32, immi, "a", i)
			end
			self:c(immi, "q", name, "imm")

			-- decode S immediate
			local imms = name .. ".imms"
			self:new_tristate_buffer(imms, { width = 32 })
			self:c(name, "s", imms, "en")
			self:cp(5, name, "in", 8, imms, "a", 1)
			self:cp(7, name, "in", 26, imms, "a", 6)
			for i = 13, 32 do
				self:cp(1, name, "in", 32, imms, "a", i)
			end
			self:c(imms, "q", name, "imm")

			-- decode B immediate
			local immb = name .. ".immb"
			self:new_tristate_buffer(immb, { width = 32 })
			self:c(name, "b", immb, "en")
			self:cp(1, "GND", "q", 1, immb, "a", 1)
			self:cp(4, name, "in", 9, immb, "a", 2)
			self:cp(6, name, "in", 26, immb, "a", 6)
			self:cp(1, name, "in", 8, immb, "a", 12)
			self:cp(1, name, "in", 32, immb, "a", 13)
			for i = 14, 32 do
				self:cp(1, name, "in", 32, immb, "a", i)
			end
			self:c(immb, "q", name, "imm")

			-- decode U immediate
			local immu = name .. ".immu"
			self:new_tristate_buffer(immu, { width = 32 })
			self:c(name, "j", immu, "en")
			self:cp(20, name, "in", 13, immu, "a", 13)
			for i = 1, 12 do
				self:cp(1, "GND", "q", 1, immu, "a", i)
			end

			-- decode J immediate
			local immj = name .. ".immj"
			self:new_tristate_buffer(immj, { width = 32 })
			self:c(name, "j", immj, "en")
			self:cp(1, "GND", "q", 1, immj, "a", 1)
			self:cp(10, name, "in", 22, immj, "a", 2)
			self:cp(1, name, "in", 21, immj, "a", 12)
			self:cp(8, name, "in", 13, immj, "a", 13)
			self:cp(1, name, "in", 32, immj, "a", 21)
			for i = 22, 32 do
				self:cp(1, name, "in", 32, immj, "a", i)
			end

			--check lowest two bits are both 1, indicating this is a 32-bit instruction
			local chk32a = name .. ".c32a"
			self:new_and(chk32a):cp(2, name, "in", 1, chk32a, "in", 1)

			--check next 3 bits, they should not be equal to all 1 for a 32-bit instruction
			local chk32b = name .. ".c32b"
			self:new_nand(chk32b, { width = 3 }):cp(3, name, "in", 3, chk32b, "in", 1)

			--check instruction is 32 bits
			local chk32 = name .. ".c32"
			self:new_and(chk32):cp(1, chk32a, "q", 1, chk32, "in", 1):cp(1, chk32b, "q", 1, chk32, "in", 2)

			--illegal instruction bit
			local ill = name .. ".ill"
			self:new_not(ill)
			self:c(chk32, "q", ill, "a")
			self:c(ill, "q", name, "illegal")

			return self
		end
	)
end
