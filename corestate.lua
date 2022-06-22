#!/bin/luajit

local positions = {
	x0 = { 0, 1, 3, 8, changegroup = "register", alias = "zero", format = "hex" },
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
	["[TIME]"] = { 1, 20, 5, 11, alias = "clock" },
	["PC"] = { 3, 20, 5, 11, changegroup = "i", alias = "pc", format = "decimal" },
	["INSTR"] = { 4, 20, 5, 32, changegroup = "i", alias = "i", format = "risc-v", filter = 0 },
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

local function findalias(n)
	local x = positions[n]
	if not x or not x.alias then
		return n
	end
	return x.alias
end

local band = bit.band
local bor = bit.bor
local rshift = bit.rshift
local lshift = bit.lshift
local arshift = bit.arshift

local function disassemble(i)
	local opcode = band(i, 0x7f)
	local rd = band(0x1f, bit.rshift(i, 7))
	local ui = lshift(rshift(i, 12), 12)
	local f3 = band(7, rshift(i, 12))
	local rs1 = band(0x1f, rshift(i, 15))
	local rs2 = band(0x1f, rshift(i, 20))
	local f7 = rshift(i, 25)

	local immi = arshift(i, 20)

	local immb = bor(
		lshift(arshift(i, 31), 12),
		lshift(band(1, rshift(i, 7)), 11),
		lshift(band(63, rshift(i, 25)), 5),
		lshift(band(15, rshift(i, 25)), 5)
	)

	local imms = bor(lshift(arshift(i, 25), 5), band(31, rshift(i, 7)))

	local immj = bor(0, 0)

	if opcode == 0xf then
		if f3 == 0 then
			return "fence"
		end
	elseif opcode == 0x73 then
		if f7 == 0 and rs1 == 0 and f3 == 0 and rd == 0 then
			if rs2 == 0 then
				return "ecall"
			elseif rs2 == 1 then
				return "ebreak"
			end
		end
	elseif opcode == 0x37 then
		return "lui   " .. findalias("x" .. rd) .. ", " .. ui
	elseif opcode == 0x17 then
		return "auipc " .. findalias("x" .. rd) .. ", " .. ui
	elseif opcode == 0x6f then
		return "jal   " .. findalias("x" .. rd) .. ", " .. immj
	elseif opcode == 0x67 then
		if f3 == 0 then
			return "jalr  " .. findalias("x" .. rd) .. ", " .. immi .. "(" .. findalias("x" .. rs1) .. ")"
		end
	elseif opcode == 0x13 then
		if f3 == 0 then
			return "addi  " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. immi
		elseif f3 == 1 and f7 == 0 then
			return "slli  " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. immi
		elseif f3 == 2 then
			return "slti  " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. immi
		elseif f3 == 3 then
			return "sltiu " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. immi
		elseif f3 == 4 then
			return "xori  " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. immi
		elseif f3 == 5 then
			if f7 == 0 then
				return "srli  " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. immi
			elseif f7 == 0x20 then
				return "srai  " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. bit.band(0x1f, immi)
			end
		elseif f3 == 6 then
			return "ori   " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. immi
		elseif f3 == 7 then
			return "andi  " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. immi
		end
	elseif opcode == 0x33 then
		if f3 == 0 then
			if f7 == 0 then
				return "add   "
					.. findalias("x" .. rd)
					.. ", "
					.. findalias("x" .. rs1)
					.. ", "
					.. findalias("x" .. rs2)
			elseif f7 == 0x20 then
				return "sub   "
					.. findalias("x" .. rd)
					.. ", "
					.. findalias("x" .. rs1)
					.. ", "
					.. findalias("x" .. rs2)
			end
		elseif f3 == 1 and f7 == 0 then
			return "sll   " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2)
		elseif f3 == 2 and f7 == 0 then
			return "slt   " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2)
		elseif f3 == 3 and f7 == 0 then
			return "sltu  " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2)
		elseif f3 == 4 and f7 == 0 then
			return "xor   " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2)
		elseif f3 == 5 then
			if f7 == 0 then
				return "srl   "
					.. findalias("x" .. rd)
					.. ", "
					.. findalias("x" .. rs1)
					.. ", "
					.. findalias("x" .. rs2)
			elseif f7 == 0x20 then
				return "sra   "
					.. findalias("x" .. rd)
					.. ", "
					.. findalias("x" .. rs1)
					.. ", "
					.. findalias("x" .. rs2)
			end
		elseif f3 == 6 and f7 == 0 then
			return "or    " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2)
		elseif f3 == 7 and f7 == 0 then
			return "and   " .. findalias("x" .. rd) .. ", " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2)
		end
	elseif opcode == 0x63 then
		if f3 == 0 then
			return "beq   " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2) .. "," .. immb
		elseif f3 == 1 then
			return "bne   " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2) .. "," .. immb
		elseif f3 == 4 then
			return "blt   " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2) .. "," .. immb
		elseif f3 == 5 then
			return "bge   " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2) .. "," .. immb
		elseif f3 == 6 then
			return "bltu  " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2) .. "," .. immb
		elseif f3 == 7 then
			return "bgeu  " .. findalias("x" .. rs1) .. ", " .. findalias("x" .. rs2) .. "," .. immb
		end
	elseif opcode == 0x03 then
		if f3 == 0 then
			return "lb    " .. findalias("x" .. rd) .. ", " .. immi .. "(" .. findalias("x" .. rs1) .. ")"
		elseif f3 == 1 then
			return "lh    " .. findalias("x" .. rd) .. ", " .. immi .. "(" .. findalias("x" .. rs1) .. ")"
		elseif f3 == 2 then
			return "lw    " .. findalias("x" .. rd) .. ", " .. immi .. "(" .. findalias("x" .. rs1) .. ")"
		elseif f3 == 4 then
			return "lbu   " .. findalias("x" .. rd) .. ", " .. immi .. "(" .. findalias("x" .. rs1) .. ")"
		elseif f3 == 5 then
			return "lhu   " .. findalias("x" .. rd) .. ", " .. immi .. "(" .. findalias("x" .. rs1) .. ")"
		end
	elseif opcode == 0x23 then
		if f3 == 0 then
			return "sb    " .. findalias("x" .. rs2) .. ", " .. imms .. "(" .. findalias("x" .. rs1) .. ")"
		elseif f3 == 1 then
			return "sh    " .. findalias("x" .. rs2) .. ", " .. imms .. "(" .. findalias("x" .. rs1) .. ")"
		elseif f3 == 2 then
			return "sw    " .. findalias("x" .. rs2) .. ", " .. imms .. "(" .. findalias("x" .. rs1) .. ")"
		end
	end
	return ""
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
		elseif pos.format == "risc-v" then
			local i = parsenumber(value)
			if pos.filter ~= nil and i == pos.filter then
				return
			else
				local v = bit.tohex(i):lpad(8, "0")
				local d = disassemble(i):rpad(pos[4] - 12)
				value = (v .. " " .. d):lpad(pos[4])
			end
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
					local time = math.floor(tonumber(line:sub(2)) / 2)
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
