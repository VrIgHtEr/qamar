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
	end, { trace = true })

	-- CLK - clock with period "clock_period_ticks"
	circuit:new_clock("CLK", { period = constants.CLOCK_PERIOD_TICKS })

	circuit:new_edge_detector("ECLK", { trace = true, chain_length = 3 }):_("CLK", "ECLK")
	circuit:new_ms_jk_flipflop("FF"):_("ECLK", 1, "FF", 3):_("ECLK", 2, "FF", 4)

	-- data pin
	circuit:add_component("DATA", 0, 1, function(time)
		return time * 0.5 % constants.CLOCK_PERIOD_TICKS < constants.CLOCK_PERIOD_TICKS / 2 and signal.low
			or signal.high
	end, { trace = true })

	-- connect data pin to jk flip flop
	circuit:new_not("ND"):_("DATA", "ND")
	circuit:_("DATA", "FF", 1)
	circuit:_("ND", "FF", 2)

	for _ = 1, constants.CLOCK_PERIOD_TICKS * 4 do
		circuit:step()
	end
end

return simulation
