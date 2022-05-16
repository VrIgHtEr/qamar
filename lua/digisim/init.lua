local constants = require("digisim.constants")
local simulation = require("digisim.simulation")

local simtime = 100000
local datapath = 32

local vcc = "CONST.VCC"
local gnd = "CONST.GND"

local clk = "CLK"
local rst = "~RST"
local alu = "ALU"
local r0 = "R0"

local subtract = "TEST.SUBTRACT"
local sel1 = "TEST.SEL1"
local sel2 = "TEST.SEL2"
local arnd = "TEST.ARND"
local brnd = "TEST.BRND"
local write = "TEST.WRITE"
local oea = "TEST.OEA"
local oeb = "TEST.OEB"

local sim = simulation.new()

-- constants ----------------------------------------------------------------------------------------
sim:new_vcc(vcc):new_gnd(gnd)

-- reset --------------------------------------------------------------------------------------------
sim:new_reset(rst, { period = constants.STARTUP_TICKS, trace = true })

-- clock --------------------------------------------------------------------------------------------
sim:new_clock_module(clk, { period = constants.CLOCK_PERIOD_TICKS, chain_length = 3, trace = true })

-- alu ----------------------------------------------------------------------------------------------
sim:new_alu(alu, { width = datapath, trace = true }):c(rst, "q", alu, "oe")

-- register -----------------------------------------------------------------------------------------
sim:new_register(r0, { width = datapath, trace = true }):c(alu, "out", r0, "in"):c(rst, "q", r0, "~rst")

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
-- register test signals ----------------------------------------------------------------------------
sim
	:new_clock(oea, { period = constants.CLOCK_PERIOD_TICKS * 2 })
	:c(oea, "q", r0, "oea")
	:new_clock(oeb, { period = constants.CLOCK_PERIOD_TICKS * 4 })
	:c(oeb, "q", r0, "oeb")
	:new_clock(write, { trace = true, period = constants.CLOCK_PERIOD_TICKS * 2 })
	:c(write, "q", r0, "write")
	:c(clk, "rising", r0, "rising")

-----------------------------------------------------------------------------------------------------

local max = 0
while sim.time < simtime do
	local x
	_, x = sim:step()
	max = math.max(max, x)
end
io.stderr:write("max delay: " .. max .. "\n")

return simulation
