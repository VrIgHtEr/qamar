local constants = require("digisim.constants")
local simulation = require("digisim.simulation")
local vcd = require("digisim.vcd")

io.stderr:write('"building circuit...\n')

local sim = simulation.new()

local rst = "RESET"
sim:new_reset(rst, { period = 192 })

local core = "CPU"
sim:new_core(core, { trace = true, file = "./lua/sram.dat" })
sim:c(rst, "q", core, "rst~")

-----------------------------------------------------------------------------------------------------

local max = 0
local edge = 0

local plog = {}
while sim.time < constants.SIM_TIME do
	--io.stderr:write("TIME: " .. sim.time .. "\n")
	local x
	_, x = sim:step()
	local strings = {}
	for name, value in pairs(sim.log) do
		if type(value) == "number" then
			if plog[name] == nil or value ~= plog[name] then
				table.insert(strings.name .. ":" .. vcd.sigstr(value))
				plog[name] = value
			end
		else
			local same = true
			if not plog[name] then
				same = false
			else
				local pval = plog[name]
				for i, val in ipairs(value) do
					if val ~= pval[i] then
						same = false
						break
					end
				end
			end
			if not same then
				local pieces = { name, ":" }
				for i = 1, #value do
					table.insert(pieces, vcd.sigstr(value[#value - i + 1]))
				end
				table.insert(strings, table.concat(pieces))
			end
			plog[name] = value
		end
	end
	io.stderr:write("#")
	io.stderr:write(edge)
	io.stderr:write("\n")
	edge = edge + 1
	if #strings > 0 then
		io.stderr:write(table.concat(strings, "\n"))
		io.stderr:write("\n")
		io.stderr:flush()
	end
	max = math.max(max, x)
end
io.stderr:write('"max delay: ' .. max .. "\n")
io.stderr:write('"sim time:  ' .. sim.time .. "\n")

return simulation
