local token = require("qamar.lexer.types")

local lexer = require("qamar.ffi")
local begin = lexer.begin
local skipws = lexer.skipws
local suspend_skip_ws = lexer.suspend_skip_ws
local spos = lexer.pos
local resume_skip_ws = lexer.resume_skip_ws
local undo = lexer.undo
local commit = lexer.commit
local numeric = lexer.numeric
local peek = lexer.peek
local take = lexer.take
local try_consume_string = lexer.try_consume_string
local sbyte = string.byte
local slower = string.lower
local concat = table.concat
local tnumber = token.number
local range = require("qamar.util.range")
local T = require("qamar.lexer.token")

---tries to consume either '0x' or '0X'
---@param self lexer
---@return string|nil
local function hex_start_parser(self)
	return try_consume_string(self, "0x") or try_consume_string(self, "0X")
end

---tries to consume a hex digit
---@param self lexer
---@return string|nil
local function hex_digit_parser(self)
	local tok = peek(self)
	if tok then
		local b = sbyte(tok)
		if b >= 48 and b <= 57 or b >= 97 and b <= 102 or b >= 65 and b <= 70 then
			return take(self)
		end
	end
end

---tries to consume either 'p' or 'P'
---@param self lexer
---@return string|nil
local function hex_exponent_parser(self)
	local tok = peek(self)
	if tok and (tok == "p" or tok == "P") then
		return take(self)
	end
end

---tries to consume either 'e' or 'E'
---@param self lexer
---@return string|nil
local function decimal_exponent_parser(self)
	local tok = peek(self)
	if tok and (tok == "e" or tok == "E") then
		return take(self)
	end
end

---tries to consume either '-' or '+'
---@param self lexer
---@return string|nil
local function sign_parser(self)
	local tok = peek(self)
	if tok and (tok == "-" or tok == "+") then
		return take(self)
	end
end

---tries to consume a lua number
---@param self lexer
---@return token|nil
return function(self)
	begin(self)
	skipws(self)
	suspend_skip_ws(self)
	local function fail()
		resume_skip_ws(self)
		undo(self)
	end
	local pos = spos(self)
	local val = hex_start_parser(self)
	local ret = {}
	local idx = 0
	local digitparser, exponentparser
	if val then
		idx = idx + 1
		ret[idx] = slower(val)
		digitparser, exponentparser = hex_digit_parser, hex_exponent_parser
	else
		digitparser, exponentparser = numeric, decimal_exponent_parser
	end

	val = digitparser(self)
	if not val then
		return fail()
	end
	while val ~= nil do
		idx = idx + 1
		ret[idx] = slower(val)
		val = digitparser(self)
	end

	val = try_consume_string(self, ".")
	if val then
		idx = idx + 1
		ret[idx] = val
		val = digitparser(self)
		if not val then
			return fail()
		end
		while val ~= nil do
			idx = idx + 1
			ret[idx] = slower(val)
			val = digitparser(self)
		end
	end

	val = exponentparser(self)
	if val then
		idx = idx + 1
		ret[idx] = val
		local sign = sign_parser(self)
		val = numeric(self)
		if sign and not val then
			return fail()
		end
		while val ~= nil do
			idx = idx + 1
			ret[idx] = slower(val)
			val = digitparser(self)
		end
	end

	resume_skip_ws(self)
	commit(self)
	return T(tnumber, concat(ret), range(pos, spos(self)))
end
