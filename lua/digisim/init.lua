local constants = require("digisim.constants")
local signal = require("digisim.signal")
local simulation = require("digisim.simulation")

function print(circuit)
	do
		io.stdout:write(tostring(circuit.trace))
		io.stdout:write("\n")
		return
	end
	local max = 0
	local maxtime = 0
	for k, t in pairs(circuit.trace) do
		if k:sub(1, 1) ~= "[" then
			max = math.max(max, k:len())
			maxtime = math.max(maxtime, t[#t].time)
		end
	end
	maxtime = maxtime + constants.CLOCK_PERIOD_TICKS / 4
	max = max + 2
	local traces = {}
	for k in pairs(circuit.trace) do
		if k:sub(1, 1) ~= "[" then
			table.insert(
				traces,
				table.concat({ k, ": ", string.rep(" ", max - (k:len() + 2)), circuit:get_trace(k, maxtime) })
			)
		end
	end
	max = 0
	for _, x in ipairs(traces) do
		max = math.max(max, x:len())
	end
	max = max + 5

	table.sort(traces)
	local first = true
	local lines = {}
	for _, x in ipairs(traces) do
		if first then
			first = false
		else
			table.insert(lines, "--")
			--			print("--")
		end
		table.insert(lines, "--" .. x)
		--		print(x)
	end

	table.insert(lines, "")
	io.stdout:write(table.concat(lines, "\n"))
	--	vim.api.nvim_buf_set_text(vim.api.nvim_get_current_buf(), -1, 0, -1, 0, lines)
end

do
	--vim.api.nvim_exec("mes clear", true)

	local circuit = simulation.new()

	-- ~RST - inverted reset signal. Only low for the first "startup_ticks" ticks. High otherwise
	circuit:add_component("RST_", 0, 1, function(time)
		return time < constants.STARTUP_TICKS and signal.low or signal.high
	end, true)

	-- CLK - clock with period "clock_period_ticks"
	circuit:add_component("CLK", 0, 1, function(ts)
		ts = ts % constants.CLOCK_PERIOD_TICKS
		return ts < constants.CLOCK_PERIOD_TICKS / 2 and signal.low or signal.high
	end, true)

	circuit:new_edge_detector("ECLK", true):_("CLK", "ECLK")

	-- ~CLK - inverted clock
	circuit:new_not("CLK_"):_("CLK", "CLK_")

	-- CLK_RISING - clock rising edge detector
	circuit
		:new_buffer("clk1")
		:_("CLK", "clk1")
		:new_buffer("clk2")
		:_("clk1", "clk2")
		:new_buffer("clk3")
		:_("clk2", "clk3")
		:new_buffer("clk4")
		:_("clk3", "clk4")
		:new_buffer("clk5")
		:_("clk4", "clk5")
		:new_buffer("clk6")
		:_("clk5", "clk6")
		:new_not("nclk")
		:_("clk6", "nclk")
		:new_and("CLK_RISING", true)
		:_("nclk", "CLK_RISING")
		:_("CLK", "CLK_RISING")

	-- CLK_FALLING - clock falling edge detector
	circuit
		:new_buffer("clk1_")
		:_("CLK_", "clk1_")
		:new_buffer("clk2_")
		:_("clk1_", "clk2_")
		:new_buffer("clk3_")
		:_("clk2_", "clk3_")
		:new_buffer("clk4_")
		:_("clk3_", "clk4_")
		:new_buffer("clk5_")
		:_("clk4_", "clk5_")
		:new_buffer("clk6_")
		:_("clk5_", "clk6_")
		:new_not("nclk_")
		:_("clk6_", "nclk_")
		:new_and("CLK_FALLING", true)
		:_("nclk_", "CLK_FALLING")
		:_("CLK_", "CLK_FALLING")

	-- slave SR latch
	circuit
		:new_nand("Q", true)
		:new_nand("Q_")
		:_("Q", "Q_")
		:_("Q_", "Q")
		:new_nand("S")
		:new_nand("S_")
		:_("S", "Q")
		:_("S_", "Q_")
		:_("CLK_FALLING", "S")
		:_("CLK_FALLING", "S_")

	-- master SR latch
	circuit
		:new_nand("M")
		:new_nand("M_")
		:_("M", "M_")
		:_("M_", "M")
		:_("M", "S")
		:_("M_", "S_")
		:new_nand("C")
		:new_nand("C_")
		:_("C", "M")
		:_("C_", "M_")
		:_("CLK_RISING", "C")
		:_("CLK_RISING", "C_")
		:new_and("J")
		:new_and("K")
		:_("J", "C")
		:_("K", "C_")
		:_("Q", "K")
		:_("Q_", "J")

	-- data pin
	circuit:add_component("DATA", 0, 1, function(time)
		return time * 0.5 % constants.CLOCK_PERIOD_TICKS < constants.CLOCK_PERIOD_TICKS / 2 and signal.low
			or signal.high
	end, true)

	-- connect data pin to jk flip flop
	circuit:new_not("ND"):_("DATA", "ND")
	circuit:_("DATA", "J")
	circuit:_("ND", "K")

	for _ = 1, constants.CLOCK_PERIOD_TICKS * 4 do
		circuit:step()
	end
end

return simulation

--[[
]]
