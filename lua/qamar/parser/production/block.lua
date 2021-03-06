---@class node_block:node

local n = require("qamar.parser.types")
local tconcat = require("qamar.util.table").tconcat
local tinsert = require("qamar.util.table").tinsert
local ipairs = ipairs
local range = require("qamar.util.range")
local N = require("qamar.parser.node").new

local mt = {
	__index = require("qamar.parser.node"),
	__tostring = function(self)
		local ret = {}
		for _, x in ipairs(self) do
			tinsert(ret, x)
		end
		return tconcat(ret)
	end,
}

local p = require("qamar.parser")
local spos = p.pos
local st, rst
st = function(self)
	st = require("qamar.parser.production.stat").parser
	return st(self)
end
rst = function(self)
	rst = require("qamar.parser.production.retstat").parser
	return rst(self)
end
local nblock = n.block

local M = {}

local function new()
	return N(nblock, nil, mt)
end

M.new = new
M.MT = mt

---consumes a lua block
---@param self parser
---@return node_block
function M:parser()
	local ret = new()
	local idx = 0
	while true do
		local stat = st(self)
		if not stat then
			break
		end
		idx = idx + 1
		ret[idx] = stat
	end
	local retstat = rst(self)
	if retstat then
		idx = idx + 1
		ret[idx] = retstat
	end

	ret.pos = idx == 0 and range(spos(self), spos(self)) or range(ret[1].pos.left, ret[idx].pos.right)
	return ret
end

return M
