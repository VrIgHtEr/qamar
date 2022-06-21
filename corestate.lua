#!/bin/luajit

local positions = {
	x1 = { 1, 1, 3, 8, changegroup = "register", alias = "ra", format = "hex" },
	x2 = { 2, 1, 3, 8, changegroup = "register", alias = "sp", format = "hex" },
	x3 = { 3, 1, 3, 8, changegroup = "register", alias = "gp", format = "hex" },
	x4 = { 4, 1, 3, 8, changegroup = "register", alias = "tp", format = "hex" },
	x5 = { 5, 1, 3, 8, changegroup = "register", alias = "t0", format = "hex" },
	x6 = { 6, 1, 3, 8, changegroup = "register", alias = "t1", format = "hex" },
	x7 = { 7, 1, 3, 8, changegroup = "register", alias = "t2", format = "hex" },
	x8 = { 8, 1, 3, 8, changegroup = "register", alias = "s0", format = "hex" },
	x9 = { 9, 1, 3, 8, changegroup = "register", alias = "s1", format = "hex" },
	x10 = { 10, 1, 3, 8, changegroup = "register", alias = "a0", format = "hex" },
	x11 = { 11, 1, 3, 8, changegroup = "register", alias = "a1", format = "hex" },
	x12 = { 12, 1, 3, 8, changegroup = "register", alias = "a2", format = "hex" },
	x13 = { 13, 1, 3, 8, changegroup = "register", alias = "a3", format = "hex" },
	x14 = { 14, 1, 3, 8, changegroup = "register", alias = "a4", format = "hex" },
	x15 = { 15, 1, 3, 8, changegroup = "register", alias = "a5", format = "hex" },
	x16 = { 16, 1, 3, 8, changegroup = "register", alias = "a6", format = "hex" },
	x17 = { 17, 1, 3, 8, changegroup = "register", alias = "a7", format = "hex" },
	x18 = { 18, 1, 3, 8, changegroup = "register", alias = "s2", format = "hex" },
	x19 = { 19, 1, 3, 8, changegroup = "register", alias = "s3", format = "hex" },
	x20 = { 20, 1, 3, 8, changegroup = "register", alias = "s4", format = "hex" },
	x21 = { 21, 1, 3, 8, changegroup = "register", alias = "s5", format = "hex" },
	x22 = { 22, 1, 3, 8, changegroup = "register", alias = "s6", format = "hex" },
	x23 = { 23, 1, 3, 8, changegroup = "register", alias = "s7", format = "hex" },
	x24 = { 24, 1, 3, 8, changegroup = "register", alias = "s8", format = "hex" },
	x25 = { 25, 1, 3, 8, changegroup = "register", alias = "s9", format = "hex" },
	x26 = { 26, 1, 3, 8, changegroup = "register", alias = "s10", format = "hex" },
	x27 = { 27, 1, 3, 8, changegroup = "register", alias = "s11", format = "hex" },
	x28 = { 28, 1, 3, 8, changegroup = "register", alias = "t3", format = "hex" },
	x29 = { 29, 1, 3, 8, changegroup = "register", alias = "t4", format = "hex" },
	x30 = { 30, 1, 3, 8, changegroup = "register", alias = "t5", format = "hex" },
	x31 = { 31, 1, 3, 8, changegroup = "register", alias = "t6", format = "hex" },
	["[TIME]"] = { 1, 20, 5, 11, alias = "tick" },
	["PC"] = { 3, 20, 5, 11, changegroup = "i", alias = "pc", format = "decimal" },
	["INSTR"] = { 4, 20, 5, 11, changegroup = "i", alias = "i", format = "hex" },
}

function string:rpad(amt, char)
	char = char or " "
	amt = math.floor(amt)
	if amt <= 0 then
		return ""
	end
	while self:len() < amt do
		self = self .. char
	end
	return self
end

function string:lpad(amt, char)
	char = char or " "
	amt = math.floor(amt)
	if amt <= 0 then
		return ""
	end
	while self:len() < amt do
		self = char .. self
	end
	return self
end

local function enter()
	io.stdout:write("\x1b[?25l\x1b[?1049h\x1b[2J")
	io.stdout:flush()
end

local function exit()
	io.stdout:write("\x1b[?25h\x1b[?1049l")
	io.stdout:flush()
end

---@type table<string,table>
local changegroups = {}

local function parsenumber(value)
	local v = bit.tobit(0)
	for i = 0, value:len() do
		local digit = value:sub(i, i)
		v = bit.lshift(v, 1)
		if digit ~= "0" then
			v = bit.bor(v, bit.tobit(1))
		end
	end
	return v
end

local function printat(pos, name, value)
	if pos.alias ~= nil then
		name = pos.alias
	end
	name = name ~= nil and tostring(name) or ""
	if name:len() > 0 then
		name = name:rpad(pos[3])
	end
	value = value ~= nil and tostring(value) or ""
	if value:len() > 0 then
		if pos.format == "decimal" then
			value = tostring(parsenumber(value)):lpad(pos[4])
		elseif pos.format == "hex" then
			local v = bit.tohex(parsenumber(value)):lpad(8, "0")
			value = v:lpad(pos[4])
		else
			value = value:lpad(pos[4])
		end
	end
	local str
	if name:len() == 0 then
		str = value
	elseif value:len() == 0 then
		str = name
	else
		str = name .. ":" .. value
	end
	if pos.changegroup then
		local cg = changegroups[pos.changegroup]
		if cg == nil then
			cg = {}
			changegroups[pos.changegroup] = cg
		end
		if cg.pos and cg.pos ~= pos then
			io.stdout:write("\x1b[37m\x1b[" .. cg.pos[1] .. ";" .. cg.pos[2] .. "H" .. cg.text)
		end
		cg.pos = pos
		cg.text = str
		io.stdout:write("\x1b[31m")
	else
		io.stdout:write("\x1b[37m")
	end
	io.stdout:write("\x1b[" .. pos[1] .. ";" .. pos[2] .. "H" .. str)
	io.stdout:flush()
end

local success, err = pcall(function()
	enter()
	while true do
		local line = io.stdin:read("*line")
		if not line then
			break
		end
		local len = line:len()
		if len > 0 then
			local c1 = line:sub(1, 1)
			if c1 ~= '"' then
				if c1 == "#" then
					local time = tostring(tonumber(line:sub(2)))
					local pos = positions["[TIME]"]
					printat(pos, "[TIME]", time)
				else
					local index = line:find(":")
					if index ~= nil then
						local name = line:sub(1, index - 1)
						local value = line:sub(index + 1)
						if name:sub(1, 1) == "[" then
						else
							local pos = positions[name]
							if pos then
								printat(pos, name, value)
							end
						end
					end
				end
			end
		end
	end
end)
pcall(exit)
if not success then
	io.stdout:write("ERROR: " .. tostring(err) .. "\n")
end
