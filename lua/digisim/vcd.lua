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
}

function vcd.new()
	local ret = setmetatable({
		time = -1,
		traces = {},
		data = {},
		index = 0,
		id = { 32 },
		state = 0,
	}, MT)
	return ret
end

function vcd.sigstr(sig)
	return sig == signal.low and "0" or sig == signal.high and "1" or sig == signal.z and "z" or "x"
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
local function new_trace(self, name, bits)
	if self.state == 0 then
		io.stdout:write([[
$date
Date text
$end
$version
digisim
$end
$comment
$end
$timescale 10ns $end
]])
		self.state = 1
	end
	if self.state ~= 1 then
		error("cannot add new trace after starting trace: " .. name)
	end
	local ret = {
		identifier = next_identifier(self),
		value = signal.unknown,
	}

	local pieces = {}
	local pidx = 0
	while true do
		local idx = name:find("[.]", pidx + 1)
		if not idx then
			local piece = name:sub(pidx + 1)
			if piece:len() == 0 then
				error("invalid module name")
			end
			table.insert(pieces, piece)
			break
		end
		local piece = name:sub(pidx + 1, idx - 1)
		if piece:len() == 0 then
			error("invalid module name")
		end
		table.insert(pieces, piece)
		pidx = idx
	end

	if #pieces < 2 then
		error("not enough pieces")
	end
	for i = 1, #pieces - 1 do
		io.stdout:write("$scope module " .. pieces[i] .. " $end\n")
	end
	io.stdout:write("$var wire " .. bits .. " " .. ret.identifier .. " " .. pieces[#pieces] .. " $end\n")
	for _ = 1, #pieces - 1 do
		io.stdout:write("$upscope $end\n")
	end
	self.traces[name] = ret
	return ret
end

function vcd:get(name, bits)
	return self.traces[name] or new_trace(self, name, bits)
end

function vcd:trace(name, time, sig)
	if self.state == 1 then
		self.state = 2
		io.stdout:write([[
$enddefinitions $end
$dumpvars
$end
]])
	end
	local trace = self:get(name)
	trace.value = sig
	if time > self.time then
		self.time = time
		self.index = self.index + 1
		io.stdout:write("#" .. tostring(time) .. "\n")
	end
	self.index = self.index + 1
	io.stdout:write(tostring(sig) .. trace.identifier .. "\n")
end

return vcd
