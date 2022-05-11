local constants = require("digisim.constants")
local signal = require("digisim.signal")
local simulation = require("digisim.simulation")

do
	local circuit = simulation.new()

	circuit:new_clock("CLK", { period = constants.CLOCK_PERIOD_TICKS, trace = true })

	circuit:new_clock("DATA", { period = constants.CLOCK_PERIOD_TICKS * 2, trace = true })
	circuit:new_reset("RST_", { period = constants.STARTUP_TICKS, trace = true })
	circuit:new_edge_detector("ECLK", { chain_length = 4, trace = true }):c("CLK", "q", "ECLK", "clk")
	circuit
		:new_ms_jk_flipflop("FF", { trace = true })
		:c("ECLK", "rising", "FF", "clock_rising")
		:c("ECLK", "falling", "FF", "clock_falling")

	circuit:new_not("ND", { trace = true }):c("DATA", "q", "ND", "a")
	circuit:c("DATA", "q", "FF", "j")
	circuit:c("ND", "q", "FF", "k")

	local adder_width = 32
	circuit:new_n_bit_adder("adder", { width = adder_width, trace = true })
	local function create_random_input(name)
		local value = signal.low
		local last = 0
		circuit
			:add_component(name, function(time)
				time = math.floor(time / constants.CLOCK_PERIOD_TICKS)
				if time ~= last then
					last = time
					value = math.random(0, 1)
				end
				return value
			end, { trace = true, names = { outputs = { "q" } } })
			:c(name, "q", "adder", name)
	end
	for i = 0, adder_width - 1 do
		create_random_input("a" .. i)
		create_random_input("b" .. i)
	end

	circuit:new_clock("C", { period = constants.CLOCK_PERIOD_TICKS, trace = true }):c("C", "q", "adder", "cin")

	circuit:new_mux("A", { width = 8, trace = true })

	local max = 0
	for _ = 1, constants.CLOCK_PERIOD_TICKS * 1024 do
		local x
		_, x = circuit:step()
		max = math.max(max, x)
	end
	io.stderr:write("max delay: " .. max .. "\n")
end

return simulation
