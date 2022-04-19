local lexer = require("qamar.ffi")
local spos = lexer.pos
local take = lexer.take
local sescape = require("qamar.util.string").escape
local tkn = lexer.token

---tries to parse the next lua token
---@param self lexer
---@return token|nil
return function(self)
	local ret = tkn(self)
	if ret then
		return ret
	end
	local pos = spos(self)
	local tok = take(self, 30)
	if tok then
		error(tostring(pos) .. ":INVALID_TOKEN:" .. sescape(tok, true))
	end
end
