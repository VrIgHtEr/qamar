local token, string_token = require("qamar.tokenizer.types"), require("qamar.tokenizer.token.string")

local begin = char_stream.begin
local skipws = char_stream.skipws
local suspend_skip_ws = char_stream.suspend_skip_ws
local spos = char_stream.pos
local try_consume_string = char_stream.try_consume_string
local resume_skip_ws = char_stream.resume_skip_ws
local undo = char_stream.undo
local commit = char_stream.commit
local peek = char_stream.peek
local take = char_stream.take
local concat = table.concat
local tcomment = token.comment
local range = require("qamar.util.range")
local T = require("qamar.tokenizer.token")

---tries to match and consume a lua comment
---@param self char_stream
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
