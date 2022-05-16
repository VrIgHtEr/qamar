local constants = require("digisim.constants")
local simulation = require("digisim.simulation")

local simtime = 20000
local datapath = 3
local reg_sel_width = 1

local vcc = "CONST.VCC"
local gnd = "CONST.GND"

local clk = "CLK"
local rst = "~RST"
local alu = "ALU"
local regs = "REGS"

local subtract = "TEST.SUBTRACT"
local sel1 = "TEST.SEL1"
local sel2 = "TEST.SEL2"
local arnd = "TEST.ARND"
local brnd = "TEST.BRND"
local write = "TEST.WRITE"

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

-- alu test signals ---------------------------------------------------------------------------------
sim
	:new_random(arnd, { trace = true, width = datapath, period = constants.CLOCK_PERIOD_TICKS })
	:cp(datapath, arnd, "q", 1, alu, "a", 1)
	:new_random(brnd, { trace = true, width = datapath, period = constants.CLOCK_PERIOD_TICKS })
	:cp(datapath, brnd, "q", 1, alu, "b", 1)
	:new_clock(subtract, { period = constants.CLOCK_PERIOD_TICKS, trace = true })
	:c(subtract, "q", alu, "cin")
	:c(gnd, "q", alu, "nota")
	:c(subtract, "q", alu, "notb")
	:new_clock(sel1, { period = constants.CLOCK_PERIOD_TICKS * 2, trace = true })
	:cp(1, sel1, "q", 1, alu, "sel", 1)
	:new_clock(sel2, { period = constants.CLOCK_PERIOD_TICKS * 4, trace = true })
	:cp(1, sel2, "q", 1, alu, "sel", 2)

local testdec = "DEC"

sim:new_binary_decoder(testdec, { width = reg_sel_width })

local sela = "TEST.SELA"
local selb = "TEST.SELB"
local selw = "TEST.SELW"
-- register test signals ----------------------------------------------------------------------------
sim
	:new_clock(write, { trace = true, period = constants.CLOCK_PERIOD_TICKS * 2 })
	:c(write, "q", regs, "write")
	:new_random(sela, { width = reg_sel_width, period = constants.CLOCK_PERIOD_TICKS })
	:c(sela, "q", regs, "sela")
	:c(sela, "q", testdec, "in")
	:new_random(selb, { width = reg_sel_width, period = constants.CLOCK_PERIOD_TICKS })
	:c(selb, "q", regs, "selb")
	:new_random(selw, { width = reg_sel_width, period = constants.CLOCK_PERIOD_TICKS })
	:c(selw, "q", regs, "selw")
-----------------------------------------------------------------------------------------------------
local signal = require("digisim.signal")
local ta = "TA"
local tb = "TB"
sim:add_component(ta, function()
	return signal.weakhigh
end, { names = { outputs = { "q" } } })
sim:add_component(tb, function()
	return signal.weaklow
end, { names = { outputs = { "q" } } })
sim:c(ta, "q", tb, "q")

local max = 0
while sim.time < simtime do
	local x
	_, x = sim:step()
	max = math.max(max, x)
end
io.stderr:write("max delay: " .. max .. "\n")
io.stderr:write("sim time:  " .. sim.time .. "\n")

return simulation
