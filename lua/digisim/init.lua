local constants = require("digisim.constants")
local simulation = require("digisim.simulation")

local simtime = 100000
local datapath = 32
local reg_sel_width = 5

local vcc = "VCC"
local gnd = "GND"

local clk = "CPU.clock"
local rst = "CPU.reset~"
local alu = "CPU.alu"
local regs = "CPU.registers"

local buses = "CPU.buses"

local sim = simulation.new()
-- constants ----------------------------------------------------------------------------------------
sim:new_vcc(vcc):new_gnd(gnd)

-- reset --------------------------------------------------------------------------------------------
sim:new_reset(rst, { period = constants.STARTUP_TICKS, trace = true })

-- clock --------------------------------------------------------------------------------------------
sim:new_clock_module(clk, { period = constants.CLOCK_PERIOD_TICKS, chain_length = 3, trace = true })

-- alu ----------------------------------------------------------------------------------------------
sim:new_alu(alu, { width = datapath, trace = true }):c(rst, "q", alu, "oe")

-- registers -----------------------------------------------------------------------------------------
sim
	:new_register_bank(regs, { width = datapath, selwidth = reg_sel_width, trace = true })
	:c(alu, "out", regs, "in")
	:c(clk, "rising", regs, "rising")
	:c(rst, "q", regs, "~rst")
	:c(regs, "outa", alu, "a")
	:c(regs, "outb", alu, "b")

-- buses ---------------------------------------------------------------------------------------------
sim
	:add_component(buses, nil, {
		names = { inputs = {}, outputs = {
			{ "a", datapath },
			{ "b", datapath },
			{ "d", datapath },
		} },
		trace = true,
	})
	:c(regs, "in", buses, "d")
	:c(alu, "a", buses, "a")
	:c(alu, "b", buses, "b")

local function reg(r)
	local ret = {}
	for i = 1, reg_sel_width do
		ret[i] = math.floor(r / math.pow(2, i - 1)) % 2
	end
	return ret
end

-- program -------------------------------------------------------------------------------------------
local program = {
	--sela    selb    selw    alu_op   cin na nb
	{ reg(2), reg(0), reg(2), { 0, 0 }, 1, 0, 0 },
	--loop
	{ reg(1), reg(2), reg(3), { 0, 0 }, 0, 0, 0 },
	{ reg(2), reg(0), reg(1), { 0, 0 }, 0, 0, 0 },
	{ reg(3), reg(0), reg(2), { 0, 0 }, 0, 0, 0 },
}
local loopindex = 2
local looplength = 3

local prog = "PROGRAM"
sim:add_component(prog, function(time)
	local c = math.floor(time / constants.CLOCK_PERIOD_TICKS) + 1
	if c >= loopindex then
		c = (c - loopindex) % looplength + loopindex
	end
	return unpack(program[c])
end, {
	trace = true,
	names = {
		inputs = {},
		outputs = {
			{ "sela", reg_sel_width },
			{ "selb", reg_sel_width },
			{ "selw", reg_sel_width },
			{ "op", 2 },
			{ "cin", 1 },
			{ "nota", 1 },
			{ "notb", 1 },
		},
	},
})

sim
	:c(prog, "op", alu, "sel")
	:c(prog, "cin", alu, "cin")
	:c(prog, "nota", alu, "nota")
	:c(prog, "notb", alu, "notb")
	:c(prog, "sela", regs, "sela")
	:c(prog, "selb", regs, "selb")
	:c(prog, "selw", regs, "selw")

-----------------------------------------------------------------------------------------------------

local max = 0
while sim.time < simtime do
	local x
	_, x = sim:step()
	max = math.max(max, x)
end
io.stderr:write("max delay: " .. max .. "\n")
io.stderr:write("sim time:  " .. sim.time .. "\n")

return simulation
