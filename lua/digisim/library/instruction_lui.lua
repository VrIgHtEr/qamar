---@class simulation
---@field new_instruction_lui fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_lui",
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
					"clk~",
				},
				outputs = {
					"icomplete",
					"legal",
					"alu_oe",
					"rd",
					"imm_oe",
				},
			}
			s:add_component(f, opts)

			local nopcode = f .. ".nopcode"
			s:new_not(nopcode, { width = 5 }):cp(5, f, "opcode", 3, nopcode, "a", 1)
			local legal = f .. ".legal"
			s:new_and(legal, { width = 7 })
			s:cp(3, f, "opcode", 1, legal, "in", 1)
			s:cp(1, nopcode, "q", 2, legal, "in", 4)
			s:cp(2, f, "opcode", 5, legal, "in", 5)
			s:cp(1, nopcode, "q", 5, legal, "in", 7)

			local legalbufen = f .. ".legalbufen"
			s:new_and_bank(legalbufen):c(f, "clk~", legalbufen, "a"):c(legal, "q", legalbufen, "b")
			local legalbuf = f .. ".legalbuf"
			s
				:new_tristate_buffer(legalbuf)
				:c(legalbufen, "q", legalbuf, "en")
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

			local icompleteen = f .. ".icompleteen"
			s:new_and_bank(icompleteen):c(f, "clk~", icompleteen, "a"):c(trignext, "q", icompleteen, "b")
			local icomplete = f .. ".icomplete"
			s:new_tristate_buffer(icomplete):c(icompleteen, "q", icomplete, "en"):c("VCC", "q", icomplete, "a")
			s:c(icomplete, "q", f, "icomplete")

			local bufen = f .. ".bufen"
			s:new_and_bank(bufen):c(f, "clk~", bufen, "a"):c(activated, "q", bufen, "b")
			local buf = f .. ".buf"
			s:new_tristate_buffer(buf, { width = 3 }):high(buf, "a", 1, 3):c(bufen, "q", buf, "en")
			s:cp(1, buf, "q", 1, f, "alu_oe", 1):cp(1, buf, "q", 2, f, "rd", 1):cp(1, buf, "q", 3, f, "imm_oe", 1)
		end
	)
end
