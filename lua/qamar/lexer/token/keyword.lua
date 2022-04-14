local token = require("qamar.lexer.types")

local keywords = require("qamar.lexer.token.keywords")

local lexer = require("qamar.lexer")
local begin = lexer.begin
local skipws = lexer.skipws
local suspend_skip_ws = lexer.suspend_skip_ws
local spos = lexer.pos
local try_consume_string = lexer.try_consume_string
local resume_skip_ws = lexer.resume_skip_ws
local undo = lexer.undo
local commit = lexer.commit
local alphanumeric = lexer.alphanumeric
local ipairs = ipairs
local range = require("qamar.util.range")
local T = require("qamar.lexer.token")

---tries to match and consume a lua keyword
---@param self lexer
---@return string|nil
local function parser(self)
	for _, x in ipairs(keywords) do
		if try_consume_string(self, x) then
			return x
		end
	end
end

---tries to match and consume a lua keyword
---@param self lexer
---@return token|nil
return function(self)
	begin(self)
	skipws(self)
	local pos = spos(self)
	local ret = parser(self)
	if ret then
		begin(self)
		suspend_skip_ws(self)
		local next = alphanumeric(self)
		resume_skip_ws(self)
		undo(self)
		if not next then
			commit(self)
			resume_skip_ws(self)
			return T(token["kw_" .. ret], ret, range(pos, spos(self)))
		end
	end
	undo(self)
end
