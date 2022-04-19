--[[
do
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
		error(tostring(pos) .. ":INVALID_TOKEN: " .. sescape(tok, true))
	end
end
end
]]

local lexer = require("qamar.ffi")
local lexers = {
	lexer.keyword,
	lexer.name,
}
local token = require("qamar.lexer.types")
local spos = lexer.pos
local ipairs = ipairs
local take = lexer.take
local skipws = lexer.skipws
local tcomment = token.comment
local sescape = require("qamar.util.string").escape

---tries to parse the next lua token
---@param self lexer
---@return token|nil
return function(self)
	::restart::
	skipws(self)
	for _, x in ipairs(lexers) do
		local ret = x(self)
		if ret then
			if ret.type == tcomment then
				goto restart
			end
			return ret
		end
	end
	local pos = spos(self)
	local tok = take(self, 30)
	if tok then
		error(tostring(pos) .. ":INVALID_TOKEN: " .. sescape(tok, true))
	end
end
