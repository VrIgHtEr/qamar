local token = require("qamar.tokenizer.types")
local alpha = char_stream.alpha
local keywords = require("qamar.tokenizer.token.keywords")

local begin = char_stream.begin
local skipws = char_stream.skipws
local suspend_skip_ws = char_stream.suspend_skip_ws
local spos = char_stream.pos
local resume_skip_ws = char_stream.resume_skip_ws
local undo = char_stream.undo
local commit = char_stream.commit
local alphanumeric = char_stream.alphanumeric
local concat = table.concat
local tname = token.name
local range = require("qamar.util.range")
local T = require("qamar.tokenizer.token")

---tries to match and consume a lua name
---@param self char_stream
---@return token|nil
return function(self)
	begin(self)
	skipws(self)
	local pos = spos(self)
	suspend_skip_ws(self)
	local ret = {}
	local idx = 0
	local t = alpha(self)
	if t == nil then
		undo(self)
		resume_skip_ws(self)
		return nil
	end
	while true do
		idx = idx + 1
		ret[idx] = t
		t = alphanumeric(self)
		if t == nil then
			break
		end
	end
	ret = concat(ret)
	if keywords[ret] then
		undo(self)
		resume_skip_ws(self)
		return nil
	end
	commit(self)
	resume_skip_ws(self)
	return T(tname, ret, range(pos, spos(self)))
end
