local signal = require("digisim.signal")

---@class trace
---@field identifier string
---@field value signal

---@class vcd
---@field traces table<string,trace>
---@field time number
---@field data string[]
---@field index number
---@field id number[]
local vcd = {}
local MT = {
	__index = vcd,
	__tostring = function(self)
		local lines = {
			"$date",
			"    Date text",
			"$end",
			"$version",
			"    digisim",
			"$end",
			"$comment",
			"$end",
			"$timescale 1ps $end",
			"$scope module logic $end",
		}
		local idx = #lines
		for name, trace in pairs(self.traces) do
			idx, lines[idx + 1] = idx + 1, "$var wire 1 " .. trace.identifier .. " " .. name .. " $end"
		end
		idx, lines[idx + 1] = idx + 1, "$upscope $end"
		idx, lines[idx + 1] = idx + 1, "$enddefinitions $end"
		idx, lines[idx + 1] = idx + 1, "$dumpvars"
		idx, lines[idx + 1] = idx + 1, "$end"
		for i, x in ipairs(self.data) do
			lines[idx + i] = x
		end
		return table.concat(lines, "\n")
	end,
}

function vcd.new()
	local ret = setmetatable({
		time = -1,
		traces = {},
		data = {},
		index = 0,
		id = { 32 },
	}, MT)
	return ret
end

local function next_identifier(self)
	local id = self.id
	id[1] = id[1] + 1
	if id[1] == 127 then
		id[1] = 33
		local carry = true
		for i = 1 + 1, #id do
			id[i] = id[i] + 1
			if id[i] < 127 then
				carry = false
				break
			end
			id[i] = 33
		end
		if carry then
			table.insert(id, 33)
		end
	end
	local ret = {}
	for i, x in ipairs(self.id) do
		ret[i] = string.char(x)
	end
	return table.concat(ret)
end

---@param self vcd
---@param name string
---@return trace
local function new_trace(self, name)
	local ret = {
		identifier = next_identifier(self),
		value = signal.unknown,
	}
	self.traces[name] = ret
	return ret
end

function vcd:trace(name, time, sig)
	local trace = self.traces[name] or new_trace(self, name)
	trace.value = sig
	if time > self.time then
		self.time = time
		self.index = self.index + 1
		self.data[self.index] = "#" .. tostring(time)
	end
	self.index = self.index + 1
	self.data[self.index] = tostring(sig) .. "" .. trace.identifier
end

return vcd
