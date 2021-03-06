---@class node_assign:node
---@field target node_varlist
---@field value node_explist

local token = require("qamar.lexer.types")
local n = require("qamar.parser.types")
local tconcat = require("qamar.util.table").tconcat
local sub = string.sub
local trim = require("qamar.util.string").trim

local mt = {
	__index = require("qamar.parser.node"),
	---@param self node_assign
	---@return string
	__tostring = function(self)
		local target = trim(tostring(self.target))
		local idx = 0
		local ret = {}
		if sub(target, 1, 1) == "(" then
			idx = idx + 1
			ret[idx] = ";"
		end
		ret[idx + 1] = self.target
		ret[idx + 2] = "="
		ret[idx + 3] = self.value
		return tconcat(ret)
	end,
}
local varlist = require("qamar.parser.production.varlist").parser
local explist = require("qamar.parser.production.explist").parser

local p = require("qamar.parser")
local take = p.take
local commit = p.commit
local undo = p.undo
local begin = p.begin
local tassignment = token.assignment
local nstat_assign = n.stat_assign
local N = require("qamar.parser.node").new
local range = require("qamar.util.range")

local M = {}

---try to consume a lua assignment statement
---@param self parser
---@return node_assign|nil
function M:parser()
	local target = varlist(self)
	if target then
		local tok = take(self)
		if tok and tok.type == tassignment then
			begin(self)
			local value = explist(self)
			if value then
				commit(self)
				local ret = N(nstat_assign, range(target.pos.left, value.pos.right), mt)
				ret.target = target
				ret.value = value
				return ret
			end
			undo(self)
		end
	end
end

return M
