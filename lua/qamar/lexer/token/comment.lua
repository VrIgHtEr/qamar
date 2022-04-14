local token, string_token = require("qamar.lexer.types"), require("qamar.lexer.token.string")
local lexer = require("qamar.lexer")

local begin = lexer.begin
local skipws = lexer.skipws
local suspend_skip_ws = lexer.suspend_skip_ws
local spos = lexer.pos
local try_consume_string = lexer.try_consume_string
local resume_skip_ws = lexer.resume_skip_ws
local undo = lexer.undo
local commit = lexer.commit
local peek = lexer.peek
local take = lexer.take
local concat = table.concat
local tcomment = token.comment
local range = require("qamar.util.range")
local T = require("qamar.lexer.token")

---tries to match and consume a lua comment
---@param self lexer
---@return token
return function(self)
	begin(self)
	skipws(self)
	suspend_skip_ws(self)
	local pos = spos(self)
	local comment = try_consume_string(self, "--")
	if not comment then
		resume_skip_ws(self)
		undo(self)
		return nil
	end
	local ret = string_token(self, true)
	if ret then
		ret.type = tcomment
		ret.pos.left = pos
		resume_skip_ws(self)
		commit(self)
		return ret
	end
	ret = {}
	local idx = 0
	while true do
		local c = peek(self)
		if not c or c == "\n" then
			break
		end
		idx = idx + 1
		ret[idx] = take(self)
	end
	commit(self)
	resume_skip_ws(self)
	return T(tcomment, concat(ret), range(pos, spos(self)))
end
