---@class simulation
---@field new_instruction_store fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_store",
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
					{ "funct3", 3 },
				},
				outputs = {
					"icomplete",
					"legal",
				},
			}
			s:add_component(f, opts)

			local nopcode = f .. ".nopcode"
			s:new_not(nopcode, { width = 5 }):cp(5, f, "opcode", 3, nopcode, "a", 1)
			local nf3 = f .. ".nf3"
			s:new_not(nf3, { width = 3 }):c(f, "funct3", nf3, "a")
			local vnf3 = f .. ".vnf3"
			s:new_nand(vnf3):cp(2, f, "funct3", 1, vnf3, "in", 1)
			local legal = f .. ".legal"
			s:new_and(legal, { width = 9 })
			s:cp(2, f, "opcode", 1, legal, "in", 1)
			s:cp(3, nopcode, "q", 1, legal, "in", 3)
			s:cp(1, f, "opcode", 6, legal, "in", 6)
			s:cp(1, nopcode, "q", 5, legal, "in", 7)
			s:cp(1, nf3, "q", 3, legal, "in", 8)
			s:cp(1, vnf3, "q", 1, legal, "in", 9)

			local legalbuf = f .. ".legalbuf"
			s
				:new_tristate_buffer(legalbuf)
				:c(legal, "q", legalbuf, "en")
				:high(legalbuf, "a")
				:c(legalbuf, "q", f, "legal")

			local visched = f .. ".visched"
			s:new_and(visched):cp(1, f, "isched", 1, visched, "in", 1):cp(1, legal, "q", 1, visched, "in", 2)

			local activated = f .. ".activated"
			s:new_ms_d_flipflop(activated)
			s:c(f, "rst~", activated, "rst~")
			s:c(f, "rising", activated, "rising")
			s:c(f, "falling", activated, "falling")
			s:c(visched, "q", activated, "d")

			local icomplete = f .. ".icomplete"
			s:new_tristate_buffer(icomplete):c(activated, "q", icomplete, "en"):high(icomplete, "a")
			s:c(icomplete, "q", f, "icomplete")
		end
	)
end
