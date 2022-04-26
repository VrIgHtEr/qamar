---@class node_attrib:node
---@field name string

local token = require("qamar.lexer.types")
local n = require("qamar.parser.types")
local N = require("qamar.parser.node").new
local range = require("qamar.util.range")

local mt = {
	__index = require("qamar.parser.node"),
	---@param self node_attrib
	---@return string
	__tostring = function(self)
		return "<" .. self.name .. ">"
	end,
}

local p = require("qamar.parser")
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tless = token.less
local tname = token.name
local tgreater = token.greater
local nattrib = n.attrib

local M = {}

local function new(pos, nm)
	local ret = N(nattrib, pos, mt)
	ret.name = nm
	return ret
end

M.new = new
M.MT = mt

---try to consume a lua variable attribute
---@param self parser
---@return node_attrib|nil
function M:parser()
	local less = peek(self)
	if not less or less.type ~= tless then
		return
	end
	begintake(self)

	local name = take(self)
	if not name or name.type ~= tname then
		undo(self)
		return
	end

	local greater = take(self)
	if not greater or greater.type ~= tgreater then
		undo(self)
		return
	end

	commit(self)
	return new(range(less.pos.left, greater.pos.right), name.value)
end

return M
