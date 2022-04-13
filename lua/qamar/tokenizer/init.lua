local tokenizers = {
	require("qamar.tokenizer.token.comment"),
	require("qamar.tokenizer.token.name"),
	require("qamar.tokenizer.token.keyword"),
	require("qamar.tokenizer.token.number"),
	require("qamar.tokenizer.token.string"),
	require("qamar.tokenizer.token.symbol"),
}
local token = require("qamar.tokenizer.types")
local spos = char_stream.pos
local ipairs = ipairs
local concat = table.concat
local peek = char_stream.peek
local begin = char_stream.begin
local take = char_stream.take
local undo = char_stream.undo
local skipws = char_stream.skipws
local tcomment = token.comment
local sescape = require("qamar.util.string").escape

---tries to parse the next lua token
---@param self char_stream
---@return token|nil
return function(self)
	::restart::
	if peek(self) then
		for _, x in ipairs(tokenizers) do
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
