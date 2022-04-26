---@class node_funcbody:node
---@field parameters node_parlist
---@field body node_block

local token = require("qamar.lexer.types")
local n = require("qamar.parser.types")
local tconcat = require("qamar.util.table").tconcat
local tinsert = require("qamar.util.table").tinsert

local parlist = require("qamar.parser.production.parlist").parser
local block = require("qamar.parser.production.block").parser

local mt = {
	__index = require("qamar.parser.node"),
	---@param self node_funcbody
	---@return string
	__tostring = function(self)
		local ret = { "(" }
		if self.parameters then
			tinsert(ret, self.parameters)
		end
		tinsert(ret, ")", self.body, "end")
		return tconcat(ret)
	end,
}

local p = require("qamar.parser")
local peek = p.peek
local take = p.take
local commit = p.commit
local undo = p.undo
local begintake = p.begintake
local tlparen = token.lparen
local trparen = token.rparen
local tkw_end = token.kw_end
local nfuncbody = n.funcbody
local N = require("qamar.parser.node").new
local range = require("qamar.util.range")

local M = {}

---create a new funcbody node
---@param pos range
---@param pars node_parlist|nil
---@param body node_block
---@return node_funcbody
local function new(pos, pars, body)
	local ret = N(nfuncbody, pos, mt)
	ret.parameters = pars
	ret.body = body
	return ret
end

M.new = new
M.MT = mt

---try to consume a lua function body
---@param self parser
---@return node_funcbody|nil
function M:parser()
	local lparen = peek(self)
	if lparen and lparen.type == tlparen then
		begintake(self)
		local pars = parlist(self)
		local tok = take(self)
		if tok and tok.type == trparen then
			local body = block(self)
			if body then
				tok = take(self)
				if tok and tok.type == tkw_end then
					commit(self)
					return new(range(lparen.pos.left, tok.pos.right), pars, body)
				end
			end
		end
		undo(self)
	end
end

return M
