local token = require("qamar.lexer.types")
local symbols = {
	["+"] = token.plus,
	["-"] = token.dash,
	["*"] = token.asterisk,
	["/"] = token.slash,
	["%"] = token.percent,
	["^"] = token.caret,
	["#"] = token.hash,
	["&"] = token.ampersand,
	["~"] = token.tilde,
	["|"] = token.pipe,
	["<<"] = token.lshift,
	[">>"] = token.rshift,
	["//"] = token.doubleslash,
	["=="] = token.equal,
	["~="] = token.notequal,
	["<="] = token.lessequal,
	[">="] = token.greaterequal,
	["<"] = token.less,
	[">"] = token.greater,
	["="] = token.assignment,
	["("] = token.lparen,
	[")"] = token.rparen,
	["{"] = token.lbrace,
	["}"] = token.rbrace,
	["["] = token.lbracket,
	["]"] = token.rbracket,
	["::"] = token.doublecolon,
	[";"] = token.semicolon,
	[":"] = token.colon,
	[","] = token.comma,
	["."] = token.dot,
	[".."] = token.doubledot,
	["..."] = token.tripledot,
}
local lexer = require("qamar.ffi")

local t = {}
do
	local pairs = pairs
	local slen = string.len
	local tsort = table.sort
	local i = 0
	for k, _ in pairs(symbols) do
		i = i + 1
		t[i] = k
	end
	tsort(t, function(a, b)
		local al, bl = slen(a), slen(b)
		if al ~= bl then
			return al > bl
		end
		return a < b
	end)
end

local begin = lexer.begin
local skipws = lexer.skipws
local spos = lexer.pos
local undo = lexer.undo
local commit = lexer.commit
local try_consume_string = lexer.try_consume_string
local ipairs = ipairs
local range = require("qamar.util.range")
local T = require("qamar.lexer.token")

---tries to consume a lua symbol token
---@param self lexer
---@return string|nil
local function parser(self)
	for _, x in ipairs(t) do
		if try_consume_string(self, x) then
			return x
		end
	end
end

---tries to consume a lua symbol token
---@param self lexer
---@return token
return function(self)
	begin(self)
	skipws(self)
	local pos = spos(self)
	local ret = parser(self)
	if ret then
		commit(self)
		return T(symbols[ret], ret, range(pos, spos(self)))
	end
	undo(self)
end
