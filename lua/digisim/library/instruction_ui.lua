---@class simulation
---@field new_instruction_ui fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_ui",
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
				},
				outputs = {
					"icomplete",
					"legal",
					"alu_oe",
					"rd",
					"imm_oe",
					"pc_oe",
				},
			}
			s:add_component(f, opts)

			local nopcode = f .. ".nopcode"
			s:new_not(nopcode, { width = 5 }):cp(5, f, "opcode", 3, nopcode, "a", 1)
			local legal = f .. ".legal"
			s:new_and(legal, { width = 6 })
			s:cp(3, f, "opcode", 1, legal, "in", 1)
			s:cp(1, nopcode, "q", 2, legal, "in", 4)
			s:cp(1, f, "opcode", 5, legal, "in", 5)
			s:cp(1, nopcode, "q", 5, legal, "in", 6)

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

			local buf = f .. ".buf"
			s
				:new_tristate_buffer(buf, { width = 4 })
				:high(buf, "a", 1, 3)
				:cp(1, nopcode, "q", 4, buf, "a", 4)
				:c(activated, "q", buf, "en")
			s
				:cp(1, buf, "q", 1, f, "alu_oe", 1)
				:cp(1, buf, "q", 2, f, "rd", 1)
				:cp(1, buf, "q", 3, f, "imm_oe", 1)
				:cp(1, buf, "q", 4, f, "pc_oe", 1)
		end
	)
end
