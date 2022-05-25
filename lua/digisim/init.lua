local constants = require("digisim.constants")
local simulation = require("digisim.simulation")

io.stderr:write("building circuit...\n")
local vcc = "VCC"
local gnd = "GND"

local clk = "CPU.clock"
local rst = "CPU.reset~"
local cu = "CPU.cu"
local alu = "CPU.alu"
local regs = "CPU.registers"
local buses = "CPU.buses"
local memory = "CPU.memory"

local sim = simulation.new()
-- constants ----------------------------------------------------------------------------------------
sim:new_vcc(vcc):new_gnd(gnd)

-- reset --------------------------------------------------------------------------------------------
sim:new_reset(rst, { period = constants.STARTUP_TICKS, trace = true })

-- clock --------------------------------------------------------------------------------------------
sim:new_clock_module(clk, { period = constants.CLOCK_PERIOD_TICKS, chain_length = 2, trace = true })

-- alu ----------------------------------------------------------------------------------------------
sim:new_alu(alu, { width = constants.BUS_WIDTH, trace = true }):c(rst, "q", alu, "oe")

-- registers -----------------------------------------------------------------------------------------
sim
	:new_register_bank(regs, { width = constants.BUS_WIDTH, selwidth = constants.REGISTER_SELECT_WIDTH, trace = true })
	:c(alu, "out", regs, "in")
	:c(clk, "rising", regs, "rising")
	:c(rst, "q", regs, "~rst")
	:c(regs, "outa", alu, "a")
	:c(regs, "outb", alu, "b")

-- buses ---------------------------------------------------------------------------------------------
sim
	:add_component(buses, {
		names = {
			inputs = {},
			outputs = {
				{ "a", constants.BUS_WIDTH },
				{ "b", constants.BUS_WIDTH },
				{ "d", constants.BUS_WIDTH },
			},
		},
		trace = true,
	})
	:c(regs, "in", buses, "d")
	:c(alu, "a", buses, "a")
	:c(alu, "b", buses, "b")
for i = 1, constants.BUS_WIDTH do
	local a = buses .. ".pulldowns.a" .. (i - 1)
	sim:new_pulldown(a):cp(1, a, "q", 1, buses, "a", i)
	local b = buses .. ".pulldowns.b" .. (i - 1)
	sim:new_pulldown(b):cp(1, b, "q", 1, buses, "b", i)
	local d = buses .. ".pulldowns.d" .. (i - 1)
	sim:new_pulldown(d):cp(1, d, "q", 1, buses, "d", i)
end
-- buses ---------------------------------------------------------------------------------------------

sim:new_sram(memory, { width = constants.BUS_WIDTH, data_width = 8, file = "./lua/sram.dat" })

-- program -------------------------------------------------------------------------------------------
local function reg(r)
	local ret = {}
	for i = 1, constants.REGISTER_SELECT_WIDTH do
		ret[i] = math.floor(r / math.pow(2, i - 1)) % 2
	end
	return ret
end

local program = {
	--sela    selb    selw    alu_op   cin na nb
	{ reg(2), reg(0), reg(2), { 0, 0 }, 1, 0, 0 },
	--loop
	{ reg(1), reg(2), reg(3), { 0, 0 }, 0, 0, 0 },
	{ reg(2), reg(0), reg(1), { 0, 0 }, 0, 0, 0 },
	{ reg(3), reg(0), reg(2), { 0, 0 }, 0, 0, 0 },
}
local loopindex = 2
local c = 0

sim:add_component(cu, {
	trace = true,
	names = {
		inputs = {},
		outputs = {
			{ "sela", constants.REGISTER_SELECT_WIDTH },
			{ "selb", constants.REGISTER_SELECT_WIDTH },
			{ "selw", constants.REGISTER_SELECT_WIDTH },
			{ "op", 2 },
			{ "cin", 1 },
			{ "nota", 1 },
			{ "notb", 1 },
		},
	},
}, function()
	c = c + 1
	if c > #program then
		c = loopindex
	end
	local ret = { unpack(program[c]) }
	ret[#ret + 1] = constants.CLOCK_PERIOD_TICKS
	return unpack(ret)
end)
sim
	:c(cu, "op", alu, "sel")
	:c(cu, "cin", alu, "cin")
	:c(cu, "nota", alu, "nota")
	:c(cu, "notb", alu, "notb")
	:c(cu, "sela", regs, "sela")
	:c(cu, "selb", regs, "selb")
	:c(cu, "selw", regs, "selw")

local idecode = "IDECODE"
sim:new_instruction_decoder(idecode)
sim:c(alu, "out", idecode, "in")
-----------------------------------------------------------------------------------------------------
local seq = "SEQ"
sim:new_seq(seq, { width = 8 })
sim:c(rst, "q", seq, "rst~")
sim:c(clk, "rising", seq, "rising")
-----------------------------------------------------------------------------------------------------
local pc = "PC"
sim:new_pc(pc, { width = constants.BUS_WIDTH })
-----------------------------------------------------------------------------------------------------
sim:c(memory, "write", "GND", "q")
sim:c(memory, "oe", "VCC", "q")
sim:c(memory, "address", buses, "d")
-----------------------------------------------------------------------------------------------------
local shift = "SHIFT"
sim:new_barrel_shifter(shift, { width = constants.REGISTER_SELECT_WIDTH })
sim:c(shift, "a", alu, "out")
sim:c(idecode, "rs2", shift, "b")
sim:new_clock("ARITHMETIC", { period = constants.CLOCK_PERIOD_TICKS * 2 }):c("ARITHMETIC", "q", shift, "arithmetic")
sim:new_clock("LEFT", { period = constants.CLOCK_PERIOD_TICKS * 4 }):c("LEFT", "q", shift, "left")
-----------------------------------------------------------------------------------------------------
local d = "D"
sim:new_ms_d_flipflop_bank(d)
sim:c(clk, "q", d, "clk")
sim:c(rst, "q", d, "rst~")
sim:cp(1, alu, "out", 1, d, "d", 1)
-----------------------------------------------------------------------------------------------------

local max = 0
while sim.time < constants.SIM_TIME do
	io.stderr:write("TIME: " .. sim.time .. "\n")
	local x
	_, x = sim:step()
	max = math.max(max, x)
end
io.stderr:write("max delay: " .. max .. "\n")
io.stderr:write("sim time:  " .. sim.time .. "\n")

return simulation
