---@class simulation
---@field new_instruction_decoder fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_decoder",
		---@param self simulation
		---@param dec string
		---@param opts boolean
		function(self, dec, opts)
			opts = opts or {}
			opts.names = {
				inputs = {
					{ "in", 32 },
					"rs1_oe",
					"rs2_oe",
					"rd_oe",
					"oe_i",
					"oe_s",
					"oe_b",
					"oe_u",
					"oe_j",
				},
				outputs = {
					{ "opcode", 7 },
					{ "rd", 5 },
					{ "funct3", 3 },
					{ "rs1", 5 },
					{ "rs2", 5 },
					{ "funct7", 7 },
					{ "imm", 32 },
				},
			}
			self:add_component(dec, opts)
			self:cp(7, dec, "in", 1, dec, "opcode", 1)
			self:cp(3, dec, "in", 13, dec, "funct3", 1)
			self:cp(7, dec, "in", 26, dec, "funct7", 1)

			local rs1 = dec .. ".rs1"
			self
				:new_tristate_buffer(rs1, { width = 5 })
				:c(rs1, "q", dec, "rs1")
				:c(dec, "rs1_oe", rs1, "en")
				:cp(5, dec, "in", 16, rs1, "a", 1)
			local rs2 = dec .. ".rs2"
			self
				:new_tristate_buffer(rs2, { width = 5 })
				:c(rs2, "q", dec, "rs2")
				:c(dec, "rs2_oe", rs2, "en")
				:cp(5, dec, "in", 21, rs2, "a", 1)
			local rd = dec .. ".rd"
			self
				:new_tristate_buffer(rd, { width = 5 })
				:c(rd, "q", dec, "rd")
				:c(dec, "rd_oe", rd, "en")
				:cp(5, dec, "in", 8, rd, "a", 1)

			-- decode I immediate
			local immi = dec .. ".immi"
			self:new_tristate_buffer(immi, { width = 32 })
			self:c(dec, "oe_i", immi, "en")
			self:cp(12, dec, "in", 21, immi, "a", 1)
			self:fanout(dec, "in", 32, immi, "a", 13, 20)
			self:c(immi, "q", dec, "imm")

			-- decode S immediate
			local imms = dec .. ".imms"
			self:new_tristate_buffer(imms, { width = 32 })
			self:c(dec, "oe_s", imms, "en")
			self:cp(5, dec, "in", 8, imms, "a", 1)
			self:cp(7, dec, "in", 26, imms, "a", 6)
			self:fanout(dec, "in", 32, imms, "a", 13, 20)
			self:c(imms, "q", dec, "imm")

			-- decode B immediate
			local immb = dec .. ".immb"
			self:new_tristate_buffer(immb, { width = 32 })
			self:c(dec, "oe_b", immb, "en")
			self:low(immb, "a", 1, 1)
			self:cp(4, dec, "in", 9, immb, "a", 2)
			self:cp(6, dec, "in", 26, immb, "a", 6)
			self:cp(1, dec, "in", 8, immb, "a", 12)
			self:cp(1, dec, "in", 32, immb, "a", 13)
			self:fanout(dec, "in", 32, immb, "a", 14, 19)
			self:c(immb, "q", dec, "imm")

			-- decode U immediate
			local immu = dec .. ".immu"
			self:new_tristate_buffer(immu, { width = 32 })
			self:c(dec, "oe_u", immu, "en")
			self:cp(20, dec, "in", 13, immu, "a", 13)
			self:low(immu, "a", 1, 12)
			self:c(immu, "q", dec, "imm")

			-- decode J immediate
			local immj = dec .. ".immj"
			self:new_tristate_buffer(immj, { width = 32 })
			self:c(dec, "oe_j", immj, "en")
			self:low(immj, "a", 1, 1)
			self:cp(10, dec, "in", 22, immj, "a", 2)
			self:cp(1, dec, "in", 21, immj, "a", 12)
			self:cp(8, dec, "in", 13, immj, "a", 13)
			self:cp(1, dec, "in", 32, immj, "a", 21)
			self:fanout(dec, "in", 32, immj, "a", 22, 11)
			self:c(immj, "q", dec, "imm")
			return self
		end
	)
end
