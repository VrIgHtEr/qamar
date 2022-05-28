---@class simulation
---@field new_instruction_and fun(circuit:simulation,name:string,opts:table|nil):simulation

local REGISTER_SELECT_WIDTH = 5

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_and",
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
					"r",
					"aluop",
					"sub",
					{ "funct3", 3 },
					{ "rs1", REGISTER_SELECT_WIDTH },
					{ "rs2", REGISTER_SELECT_WIDTH },
					{ "rd", REGISTER_SELECT_WIDTH },
				},
				outputs = {
					"icomplete",
					{ "sela", REGISTER_SELECT_WIDTH },
					{ "selb", REGISTER_SELECT_WIDTH },
					{ "selw", REGISTER_SELECT_WIDTH },
					"alu_oe",
					"alu_notb",
					"alu_cin",
					{ "alu_sel", 2 },
				},
			}
			s:add_component(f, opts)

			local f3 = f .. ".nf3"
			s:new_and(f3, { width = 3 })
			s:c(f, "funct3", f3, "in")
			local cs0 = f .. ".trigger"
			s:new_and(cs0, { width = 4 })
			s:cp(1, f, "isched", 1, cs0, "in", 1)
			s:cp(1, f, "r", 1, cs0, "in", 2)
			s:cp(1, f, "aluop", 1, cs0, "in", 3)
			s:cp(1, f3, "q", 1, cs0, "in", 4)

			local s0 = f .. ".s0"
			s:new_ms_d_flipflop(s0)
			s:c(f, "rst~", s0, "rst~")
			s:c(f, "rising", s0, "rising")
			s:c(f, "falling", s0, "falling")
			s:c(cs0, "q", s0, "d")

			local s1 = f .. ".s1"
			s:new_ms_d_flipflop(s1)
			s:c(f, "rst~", s1, "rst~")
			s:c(f, "rising", s1, "rising")
			s:c(f, "falling", s1, "falling")
			s:c(s0, "q", s1, "d")
			local icomplete = f .. ".icomplete"
			s
				:new_tristate_buffer(icomplete)
				:c("VCC", "q", icomplete, "a")
				:c(s1, "q", icomplete, "en")
				:c(icomplete, "q", f, "icomplete")

			local ctrl = f .. ".ctrl"
			s:new_tristate_buffer(ctrl, { width = REGISTER_SELECT_WIDTH * 3 + 5 })
			s:c(s0, "q", ctrl, "en")
			s:cp(REGISTER_SELECT_WIDTH, ctrl, "q", REGISTER_SELECT_WIDTH * 0 + 1, f, "selw", 1)
			s:cp(REGISTER_SELECT_WIDTH, ctrl, "q", REGISTER_SELECT_WIDTH * 1 + 1, f, "sela", 1)
			s:cp(REGISTER_SELECT_WIDTH, ctrl, "q", REGISTER_SELECT_WIDTH * 2 + 1, f, "selb", 1)
			s:cp(1, ctrl, "q", REGISTER_SELECT_WIDTH * 3 + 1, f, "alu_oe", 1)
			s:cp(1, ctrl, "q", REGISTER_SELECT_WIDTH * 3 + 2, f, "alu_notb", 1)
			s:cp(1, ctrl, "q", REGISTER_SELECT_WIDTH * 3 + 3, f, "alu_cin", 1)
			s:cp(2, ctrl, "q", REGISTER_SELECT_WIDTH * 3 + 4, f, "alu_sel", 1)
			s:cp(REGISTER_SELECT_WIDTH, ctrl, "a", REGISTER_SELECT_WIDTH * 0 + 1, f, "rd", 1)
			s:cp(REGISTER_SELECT_WIDTH, ctrl, "a", REGISTER_SELECT_WIDTH * 1 + 1, f, "rs1", 1)
			s:cp(REGISTER_SELECT_WIDTH, ctrl, "a", REGISTER_SELECT_WIDTH * 2 + 1, f, "rs2", 1)
			s:cp(1, ctrl, "a", REGISTER_SELECT_WIDTH * 3 + 1, "VCC", "q", 1)
			s:cp(1, ctrl, "a", REGISTER_SELECT_WIDTH * 3 + 2, f, "sub", 1)
			s:cp(1, ctrl, "a", REGISTER_SELECT_WIDTH * 3 + 3, f, "sub", 1)
			s:cp(1, ctrl, "a", REGISTER_SELECT_WIDTH * 3 + 4, "VCC", "q", 1)
			s:cp(1, ctrl, "a", REGISTER_SELECT_WIDTH * 3 + 5, "GND", "q", 1)
		end
	)
end
