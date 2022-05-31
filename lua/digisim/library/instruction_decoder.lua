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
				inputs = { { "in", 32 }, "oe", "rs1_oe", "rs2_oe", "rd_oe" },
				outputs = {
					"i",
					"s",
					"b",
					"u",
					"j",
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

			local pd1 = dec .. ".pd1"
			self:new_pulldown(pd1, { width = 5 }):c(pd1, "q", dec, "rs1")
			local rs1 = dec .. ".rs1"
			self
				:new_tristate_buffer(rs1, { width = 5 })
				:c(rs1, "q", dec, "rs1")
				:c(dec, "rs1_oe", rs1, "en")
				:cp(5, dec, "in", 16, rs1, "a", 1)
			local pd2 = dec .. ".pd2"
			self:new_pulldown(pd2, { width = 5 }):c(pd2, "q", dec, "rs2")
			local rs2 = dec .. ".rs2"
			self
				:new_tristate_buffer(rs2, { width = 5 })
				:c(rs2, "q", dec, "rs2")
				:c(dec, "rs2_oe", rs2, "en")
				:cp(5, dec, "in", 21, rs2, "a", 1)
			local pdd = dec .. ".pdd"
			self:new_pulldown(pdd, { width = 5 }):c(pdd, "q", dec, "rd")
			local rd = dec .. ".rd"
			self
				:new_tristate_buffer(rd, { width = 5 })
				:c(rd, "q", dec, "rd")
				:c(dec, "rd_oe", rd, "en")
				:cp(5, dec, "in", 8, rd, "a", 1)

			-- decode I immediate
			local cimmi = dec .. ".cimmi"
			self:new_and_bank(cimmi)
			self:c(dec, "oe", cimmi, "a")
			self:c(dec, "i", cimmi, "b")
			local immi = dec .. ".immi"
			self:new_tristate_buffer(immi, { width = 32 })
			self:c(cimmi, "q", immi, "en")
			self:cp(12, dec, "in", 21, immi, "a", 1)
			for i = 13, 32 do
				self:cp(1, dec, "in", 32, immi, "a", i)
			end
			self:c(immi, "q", dec, "imm")

			-- decode S immediate
			local cimms = dec .. ".cimms"
			self:new_and_bank(cimms)
			self:c(dec, "oe", cimms, "a")
			self:c(dec, "s", cimms, "b")
			local imms = dec .. ".imms"
			self:new_tristate_buffer(imms, { width = 32 })
			self:c(cimms, "q", imms, "en")
			self:cp(5, dec, "in", 8, imms, "a", 1)
			self:cp(7, dec, "in", 26, imms, "a", 6)
			for i = 13, 32 do
				self:cp(1, dec, "in", 32, imms, "a", i)
			end
			self:c(imms, "q", dec, "imm")

			-- decode B immediate
			local cimmb = dec .. ".cimmb"
			self:new_and_bank(cimmb)
			self:c(dec, "oe", cimmb, "a")
			self:c(dec, "b", cimmb, "b")
			local immb = dec .. ".immb"
			self:new_tristate_buffer(immb, { width = 32 })
			self:c(cimmb, "q", immb, "en")
			self:cp(1, "GND", "q", 1, immb, "a", 1)
			self:cp(4, dec, "in", 9, immb, "a", 2)
			self:cp(6, dec, "in", 26, immb, "a", 6)
			self:cp(1, dec, "in", 8, immb, "a", 12)
			self:cp(1, dec, "in", 32, immb, "a", 13)
			for i = 14, 32 do
				self:cp(1, dec, "in", 32, immb, "a", i)
			end
			self:c(immb, "q", dec, "imm")

			-- decode U immediate
			local cimmu = dec .. ".cimmu"
			self:new_and_bank(cimmu)
			self:c(dec, "oe", cimmu, "a")
			self:c(dec, "u", cimmu, "b")
			local immu = dec .. ".immu"
			self:new_tristate_buffer(immu, { width = 32 })
			self:c(cimmu, "q", immu, "en")
			self:cp(20, dec, "in", 13, immu, "a", 13)
			for i = 1, 12 do
				self:cp(1, "GND", "q", 1, immu, "a", i)
			end
			self:c(immu, "q", dec, "imm")

			-- decode J immediate
			local cimmj = dec .. ".cimmj"
			self:new_and_bank(cimmj)
			self:c(dec, "oe", cimmj, "a")
			self:c(dec, "j", cimmj, "b")
			local immj = dec .. ".immj"
			self:new_tristate_buffer(immj, { width = 32 })
			self:c(cimmj, "q", immj, "en")
			self:cp(1, "GND", "q", 1, immj, "a", 1)
			self:cp(10, dec, "in", 22, immj, "a", 2)
			self:cp(1, dec, "in", 21, immj, "a", 12)
			self:cp(8, dec, "in", 13, immj, "a", 13)
			self:cp(1, dec, "in", 32, immj, "a", 21)
			for i = 22, 32 do
				self:cp(1, dec, "in", 32, immj, "a", i)
			end
			self:c(immj, "q", dec, "imm")

			local n = dec .. "."
			local nec = n .. "inv"
			self:new_not(nec, { width = 32 }):c(dec, "in", nec, "a")

			local mapping = {
				A = 7,
				B = 6,
				C = 5,
				D = 4,
				E = 3,
				F = 2,
				G = 1,
				H = 15,
				I = 14,
				J = 13,
				K = 32,
				L = 31,
				M = 30,
				N = 29,
				O = 28,
				P = 27,
				Q = 26,
			}

			---@param name string
			---@param minterm string
			local function build_minterm(name, minterm)
				local terms = {}
				local idx = 1
				while true do
					local term = minterm:match("[A-Z]'?", idx)
					if not term then
						break
					end
					local l = term:len()
					idx = idx + l
					local varname = term:sub(1, 1)
					local varmap = mapping[varname]
					if not varmap then
						error("mapping not found")
					end
					local inverted = l > 1
					table.insert(terms, {
						inverted and nec or dec,
						inverted and "q" or "in",
						varmap,
					})
				end
				if idx <= minterm:len() then
					error("could not parse entire minterm")
				end
				self:new_and(name, { width = #terms })
				for i, term in ipairs(terms) do
					self:cp(1, name, "in", i, term[1], term[2], term[3])
				end
			end

			---@param name string
			---@param minterms string[]
			local function build_2ll(name, minterms)
				for i, x in ipairs(minterms) do
					build_minterm(name .. i, x)
				end
				self:new_or(name, { width = #minterms })
				for i = 1, #minterms do
					self:cp(1, name .. i, "q", 1, name, "in", i)
				end
			end

			local I = n .. "i"
			build_2ll(I, {
				"A'B'CD'E'FGHK'M'N'O'P'Q'",
				"A'B'CD'E'FGK'L'M'N'O'P'Q'",
				"A'B'CD'E'FGJ'",
				"ABCD'E'FGH'K'L'M'N'O'P'Q'",
				"ABC'D'EFGH'I'J'",
				"A'B'D'E'FGH'J'",
				"ABCD'E'FGI",
				"A'B'CD'E'FGI",
				"A'B'C'D'E'FGI'",
				"ABCD'E'FGJ",
			})
			self:c(I, "q", dec, "i")

			local S = n .. "s"
			build_2ll(S, { "A'BC'D'E'FGH'J'", "A'BC'D'E'FGH'I'" })
			self:c(S, "q", dec, "s")

			local B = n .. "b"
			build_2ll(B, { "ABC'D'E'FGH", "ABC'D'E'FGI'" })
			self:c(B, "q", dec, "b")

			local U = n .. "u"
			build_minterm(U, "A'CD'EFG")
			self:c(U, "q", dec, "u")

			local J = n .. "j"
			build_minterm(J, "ABC'DEFG")
			self:c(J, "q", dec, "j")

			return self
		end
	)
end
