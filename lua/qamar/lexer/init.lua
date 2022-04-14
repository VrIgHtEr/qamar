local lexer = _G["qamar_lexer"]
local lexers = {
	require("qamar.lexer.token.comment"),
	require("qamar.lexer.token.string"),
	lexer.keyword,
	require("qamar.lexer.token.number"),
	lexer.name,
}
local token = require("qamar.lexer.types")
local spos = lexer.pos
local ipairs = ipairs
local concat = table.concat
local peek = lexer.peek
local begin = lexer.begin
local take = lexer.take
local undo = lexer.undo
local skipws = lexer.skipws
local tcomment = token.comment
local sescape = require("qamar.util.string").escape

---tries to parse the next lua token
---@param self lexer
---@return token|nil
return function(self)
	::restart::
	if peek(self) then
		for _, x in ipairs(lexers) do
			local ret = x(self)
			if ret then
				if ret.type == tcomment then
					goto restart
				end
				return ret
			end
		end
		skipws(self)
		if peek(self) then
			local preview = {}
			begin(self)
			for i = 1, 30 do
				local t = take(self)
				if not t then
					break
				end
				preview[i] = t
			end
			undo(self)
			error(tostring(spos(self)) .. ":INVALID_TOKEN: " .. sescape(concat(preview), true))
		end
	end
end
