local token = require("qamar.lexer.types")
local lexer = _G["qamar_lexer"]
local alpha = lexer.alpha
local keywords = require("qamar.lexer.token.keywords")

local begin = lexer.begin
local skipws = lexer.skipws
local suspend_skip_ws = lexer.suspend_skip_ws
local spos = lexer.pos
local resume_skip_ws = lexer.resume_skip_ws
local undo = lexer.undo
local commit = lexer.commit
local alphanumeric = lexer.alphanumeric
local concat = table.concat
local tname = token.name
local range = require("qamar.util.range")
local T = require("qamar.lexer.token")

---tries to match and consume a lua name
---@param self lexer
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
