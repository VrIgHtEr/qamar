local M = {}
local string = require("qamar.util.string")
local ascii = string.byte

local function isnum(tok)
	local byte = ascii(tok)
	return byte >= 48 and byte <= 57
end

local function isalphanum(tok)
	local byte = ascii(tok)
	return byte >= 97 and byte <= 122 or byte >= 65 and byte <= 90 or byte >= 48 and byte <= 57 or byte == 95
end

local concat = table.concat
local sub = string.sub
local len = string.len
local tostring = tostring
local setmetatable = setmetatable
local trim = string.trim

M.tconcat = function(self)
	local prevalpha, prevdigit = false, false
	local ret = {}
	local i = 0
	for _, x in ipairs(self) do
		x = trim(tostring(x))
		if x ~= "" then
			local c = sub(x, 1, 1)
			local alpha = isalphanum(c)
			local num = isnum(c)
			if ((prevalpha or prevdigit) and (alpha or num)) or (prevdigit and c == ".") then
				i = i + 1
				ret[i] = " "
			end
			i = i + 1
			ret[i] = x
			c = sub(x, len(x))
			prevalpha = isalphanum(c)
			prevdigit = isnum(c)
		end
	end
	return concat(ret)
end

M.tinsert = function(tbl, ...)
	local idx = #tbl
	local args = { ... }
	for i = 1, #args do
		idx = idx + 1
		tbl[idx] = args[i]
	end
	return tbl
end

return setmetatable(M, { __index = table })
