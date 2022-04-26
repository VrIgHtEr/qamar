---@class node_vararg:node

local token = require("qamar.lexer.types")
local n = require("qamar.parser.types")

local mt = {
	__index = require("qamar.parser.node"),
	__tostring = function()
		return "..."
	end,
}

local p = require("qamar.parser")
local peek = p.peek
local take = p.take
local ttripledot = token.tripledot
local nvararg = n.vararg
local N = require("qamar.parser.node").new

local M = {}
local function new(pos)
	return N(nvararg, pos, mt)
end
M.new = new
M.MT = mt

---try to consume a vararg token
---@param self parser
---@return node_vararg|nil
function M:parser()
	local tok = peek(self)
	if tok and tok.type == ttripledot then
		take(self)
		return new(tok.pos)
	end
end

return M
