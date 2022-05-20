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

			local dec = name .. ".dec"
			self:add_component(dec, { names = { outputs = { { "q", 15 } } } })
			self:cp(1, name, "in", 7, dec, "q", 1)
			self:cp(1, name, "in", 6, dec, "q", 2)
			self:cp(1, name, "in", 5, dec, "q", 3)
			self:cp(1, name, "in", 4, dec, "q", 4)
			self:cp(1, name, "in", 3, dec, "q", 5)
			self:cp(1, name, "in", 15, dec, "q", 6)
			self:cp(1, name, "in", 14, dec, "q", 7)
			self:cp(1, name, "in", 13, dec, "q", 8)
			self:cp(1, name, "in", 32, dec, "q", 9)
			self:cp(1, name, "in", 31, dec, "q", 10)
			self:cp(1, name, "in", 30, dec, "q", 11)
			self:cp(1, name, "in", 29, dec, "q", 12)
			self:cp(1, name, "in", 28, dec, "q", 13)
			self:cp(1, name, "in", 27, dec, "q", 14)
			self:cp(1, name, "in", 26, dec, "q", 15)

			local nec = name .. ".nec"
			self:new_not(nec, { width = 15 }):c(dec, "q", nec, "a")

			--j = d1d2n3d4d5
			local n = name .. "."
			local d1d2 = n .. "d1d2"
			self:new_and(d1d2):cp(1, dec, "q", 1, d1d2, "in", 1):cp(1, dec, "q", 2, d1d2, "in", 2)
			local d4d5 = n .. "d4d5"
			self:new_and(d4d5):cp(1, dec, "q", 4, d4d5, "in", 1):cp(1, dec, "q", 5, d4d5, "in", 2)
			local d1d2n3 = n .. "d1d2n3"
			self:new_and(d1d2n3):cp(1, d1d2, "q", 1, d1d2n3, "in", 1):cp(1, nec, "q", 3, d1d2n3, "in", 2)
			local d1d2n3d4d5 = n .. "d1d2n3d4d5"
			self:new_and(d1d2n3d4d5):cp(1, d1d2n3, "q", 1, d1d2n3d4d5, "in", 1):cp(1, d4d5, "q", 1, d1d2n3d4d5, "in", 2)

			--J
			self:c(d1d2n3d4d5, "q", name, "j")
			--

			--u = n4n1d3d5
			local n4n1 = n .. "n4n1"
			self:new_and(n4n1):cp(1, nec, "q", 4, n4n1, "in", 1):cp(1, nec, "q", 1, n4n1, "in", 2)
			local d3d5 = n .. "d3d5"
			self:new_and(d3d5):cp(1, dec, "q", 3, d3d5, "in", 1):cp(1, dec, "q", 5, d3d5, "in", 2)
			local n4n1d3d5 = n .. "n4n1d3d5"
			self:new_and(n4n1d3d5):cp(1, n4n1, "q", 1, n4n1d3d5, "in", 1):cp(1, d3d5, "q", 1, n4n1d3d5, "in", 2)

			-- U
			self:c(n4n1d3d5, "q", name, "u")
			--

			--b = n4n5d2n3d1(d6 + n7)
			local c_d_ = n .. "c_d_"
			self:new_and(c_d_):cp(1, nec, "q", 3, c_d_, "in", 1):cp(1, nec, "q", 4, c_d_, "in", 2)
			local abc_d_ = n .. "abc_d_"
			self:new_and(abc_d_):cp(1, d1d2, "q", 1, abc_d_, "in", 1):cp(1, c_d_, "q", 1, abc_d_, "in", 2)
			local abc_d_e_ = n .. "abc_d_e_"
			self:new_and(abc_d_e_):cp(1, abc_d_, "q", 1, abc_d_e_, "in", 1):cp(1, nec, "q", 5, abc_d_e_, "in", 2)
			local fPg_ = n .. "fPg_"
			self:new_or(fPg_):cp(1, dec, "q", 6, fPg_, "in", 1):cp(1, nec, "q", 7, fPg_, "in", 2)
			local B = n .. "B"
			self:new_and(B):cp(1, abc_d_e_, "q", 1, B, "in", 1):cp(1, fPg_, "q", 1, B, "in", 2)

			--B
			self:c(B, "q", name, "b")
			--

			--s = n4n1d2n3d5n6(n8 + n7)
			local d2n3 = n .. "d2n3"
			self:new_and(d2n3):cp(1, dec, "q", 2, d2n3, "in", 1):cp(1, nec, "q", 3, d2n3, "in", 2)
			local d5n6 = n .. "d5n6"
			self:new_and(d5n6):cp(1, dec, "q", 5, d5n6, "in", 1):cp(1, nec, "q", 6, d5n6, "in", 2)
			local n4n1d2n3 = n .. "n4n1d2n3"
			self:new_and(n4n1d2n3):cp(1, n4n1, "q", 1, n4n1d2n3, "in", 1):cp(1, d5n6, "q", 1, n4n1d2n3, "in", 2)
			local n4n1d2n3d5n6 = n .. "n4n1d2n3d5n6"
			self
				:new_and(n4n1d2n3d5n6)
				:cp(1, n4n1d2n3, "q", 1, n4n1d2n3d5n6, "in", 1)
				:cp(1, d5n6, "q", 1, n4n1d2n3d5n6, "in", 2)
			local n8xn7 = n .. "n8xn7"
			self:new_or(n8xn7):cp(1, nec, "q", 8, n8xn7, "in", 1):cp(1, nec, "q", 7, n8xn7, "in", 2)
			local S = n .. "S"
			self:new_and(S):cp(1, n4n1d2n3d5n6, "q", 1, S, "in", 1):cp(1, n8xn7, "q", 1, S, "in", 2)
			self:c(S, "q", name, "s")

			--[[
--r = n4n1n5d3n11n12n13n14n15(d2(n6n9n10 + n7(n6d8d9+ n9n10)) + n7n9(d2n6n8 + d8(d6 + n10)))
--i = n4(n1n5(n2(d3(n8 + d7) + n6n8 + n3n7)) + d1d2n3d5n6n7n8)
            --]]
			return self
		end
	)
end
