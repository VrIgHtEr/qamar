#!/bin/luajit

local positions = {
	x1 = { 1, 1, 3, 33 },
	x2 = { 2, 1, 3, 33 },
	x3 = { 3, 1, 3, 33 },
	x4 = { 4, 1, 3, 33 },
	x5 = { 5, 1, 3, 33 },
	x6 = { 6, 1, 3, 33 },
	x7 = { 7, 1, 3, 33 },
	x8 = { 8, 1, 3, 33 },
	x9 = { 9, 1, 3, 33 },
	x10 = { 10, 1, 3, 33 },
	x11 = { 11, 1, 3, 33 },
	x12 = { 12, 1, 3, 33 },
	x13 = { 13, 1, 3, 33 },
	x14 = { 14, 1, 3, 33 },
	x15 = { 15, 1, 3, 33 },
	x16 = { 16, 1, 3, 33 },
	x17 = { 17, 1, 3, 33 },
	x18 = { 18, 1, 3, 33 },
	x19 = { 19, 1, 3, 33 },
	x20 = { 20, 1, 3, 33 },
	x21 = { 21, 1, 3, 33 },
	x22 = { 22, 1, 3, 33 },
	x23 = { 23, 1, 3, 33 },
	x24 = { 24, 1, 3, 33 },
	x25 = { 25, 1, 3, 33 },
	x26 = { 26, 1, 3, 33 },
	x27 = { 27, 1, 3, 33 },
	x28 = { 28, 1, 3, 33 },
	x29 = { 29, 1, 3, 33 },
	x30 = { 30, 1, 3, 33 },
	x31 = { 31, 1, 3, 33 },
	["[TIME]"] = { 1, 39, 5, 11 },
	["PC"] = { 3, 39, 5, 33 },
	["INSTR"] = { 4, 39, 5, 33 },
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
	io.stdout:write("\x1b[?25l\x1b[?1049h\x1b[2J"):flush()
end

local function exit()
	io.stdout:write("\x1b[?25h\x1b[?1049l"):flush()
end

local function printat(pos, name, value)
	io.stdout
		:write(
			"\x1b["
				.. pos[1]
				.. ";"
				.. pos[2]
				.. "H"
				.. tostring(name):rpad(pos[3])
				.. ":"
				.. tostring(value):lpad(pos[4])
		)
		:flush()
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
					local time = tonumber(line:sub(2))
					local pos = positions["[TIME]"]
					printat(pos, "TIME", time)
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
