---@class simulation
---@field new_core fun(circuit:simulation,name:string,opts:table|nil):simulation

local BUS_WIDTH = 32
local REGISTER_SELECT_WIDTH = 5
local PERIOD = 256

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"core",
		---@param s simulation
		---@param core string
		---@param opts boolean
		function(s, core, opts)
			opts = opts or { trace = nil, file = nil }
			opts.names = {
				inputs = {
					"alu_nota",
					"alu_notb",
					"alu_cin",
					{ "alu_sel", 2 },
					{ "rd", REGISTER_SELECT_WIDTH },
					{ "rs1", REGISTER_SELECT_WIDTH },
					{ "rs2", REGISTER_SELECT_WIDTH },
					{ "lsu_control", 2 },
					"lsu_sext",
					"lsu_trigin",
					"rst~",
				},
				outputs = { "q" },
			}
			s:add_component(core, opts)

			------------------------------------------------------------------------------
			local clk = core .. ".clock"
			s:new_clock_module(clk, { period = PERIOD, chain_length = 2, trace = opts.trace })
			------------------------------------------------------------------------------
			local buses = core .. ".buses"
			s:add_component(buses, {
				names = {
					inputs = {},
					outputs = {
						{ "a", BUS_WIDTH },
						{ "b", BUS_WIDTH },
						{ "d", BUS_WIDTH },
					},
				},
				trace = opts.trace,
			})
			for i = 1, BUS_WIDTH do
				local a = buses .. ".pulldowns.a" .. (i - 1)
				s:new_pulldown(a):cp(1, a, "q", 1, buses, "a", i)
				local b = buses .. ".pulldowns.b" .. (i - 1)
				s:new_pulldown(b):cp(1, b, "q", 1, buses, "b", i)
				local d = buses .. ".pulldowns.d" .. (i - 1)
				s:new_pulldown(d):cp(1, d, "q", 1, buses, "d", i)
			end
			------------------------------------------------------------------------------
			local alu = core .. ".alu"
			s:new_alu(alu, { width = BUS_WIDTH, trace = opts.trace })
			s:c(core, "alu_nota", alu, "nota")
			s:c(core, "alu_notb", alu, "notb")
			s:c(core, "alu_cin", alu, "cin")
			s:c(core, "alu_sel", alu, "sel")
			s:c(core, "rst~", alu, "oe")
			s:c(buses, "a", alu, "a")
			s:c(buses, "b", alu, "b")
			s:c(alu, "out", buses, "d")
			------------------------------------------------------------------------------
			local registers = core .. ".registers"
			s
				:new_register_bank(
					registers,
					{ width = BUS_WIDTH, selwidth = REGISTER_SELECT_WIDTH, trace = opts.trace }
				)
				:c(core, "rst~", registers, "~rst")
				:c(clk, "rising", registers, "rising")
				:c(buses, "d", registers, "in")
				:c(core, "rs1", registers, "sela")
				:c(core, "rs2", registers, "selb")
				:c(core, "rd", registers, "selw")
				:c(registers, "outa", buses, "a")
				:c(registers, "outb", buses, "b")
			------------------------------------------------------------------------------
			local lsu = core .. ".lsu"
			s
				:new_load_store_unit(lsu, { file = opts.file, trace = opts.trace })
				:c(clk, "rising", lsu, "rising")
				:c(clk, "falling", lsu, "falling")
				:c(buses, "d", lsu, "address")
				:c(core, "lsu_control", lsu, "control")
				:c(core, "lsu_trigin", lsu, "trigin")
				:c(core, "rst~", lsu, "rst~")
				:c(core, "lsu_sext", lsu, "sext")
			------------------------------------------------------------------------------
			local idecode = "IDECODE"
			s:new_instruction_decoder(idecode, { trace = opts.trace })
			s:c(buses, "d", idecode, "in")
		end
	)
end
