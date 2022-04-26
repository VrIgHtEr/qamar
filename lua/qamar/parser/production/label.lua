---@class node_label:node
---@field name string

local token = require("qamar.lexer.types")
local n = require("qamar.parser.types")
local N = require("qamar.parser.node").new
local range = require("qamar.util.range")

local mt = {
	__index = require("qamar.parser.node"),
	---@param self node_label
	---@return string
	__tostring = function(self)
		return "::" .. self.name .. "::"
	end,
}

local name = require("qamar.parser.production.name").parser

local p = require("qamar.parser")
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tdoublecolon = token.doublecolon
local nlabel = n.label

local M = {}

---creates a new label node
---@param pos range
---@param nm string
---@return node_label
local function new(pos, nm)
	local ret = N(nlabel, pos, mt)
	ret.name = nm
	return ret
end

M.new = new
M.MT = mt

---try to consume a lua label
---@param self parser
---@return node_label|nil
function M:parser()
	local left = peek(self)
	if not left or left.type ~= tdoublecolon then
		return
	end
	begintake(self)

	local nam = name(self)
	if not nam then
		undo(self)
		return
	end

	local right = take(self)
	if not right or right.type ~= tdoublecolon then
		undo(self)
		return
	end

	commit(self)
	return new(range(left.pos.left, right.pos.right), nam.value)
end

return M
