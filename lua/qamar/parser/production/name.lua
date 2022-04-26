---@class node_name:node
---@field value string

local token = require("qamar.lexer.types")
local n = require("qamar.parser.types")
local N = require("qamar.parser.node").new

local mt = {
	__index = require("qamar.parser.node"),
	---@param self node_name
	---@return string
	__tostring = function(self)
		return self.value
	end,
}

local p = require("qamar.parser")
local peek = p.peek
local take = p.take
local tname = token.name
local nname = n.name

local M = {}

---creates a new name node
---@param name string
---@param pos range
---@return node_name
local function new(name, pos)
	local ret = N(nname, pos, mt)
	ret.value = name
	return ret
end
M.new = new
M.MT = mt

---try to consume a lua name
---@param self parser
---@return node_name|nil
function M:parser()
	local tok = peek(self)
	if tok and tok.type == tname then
		take(self)
		return new(tok.value, tok.pos)
	end
end

return M
