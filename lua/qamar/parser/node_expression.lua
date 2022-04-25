local setmetatable = setmetatable
local N = require("qamar.parser.node").new

---@class node_expression:node
---@field precedence number
---@field right_associative boolean
local node_expression = setmetatable({}, { __index = require("qamar.parser.node") })

local MTMT = {
	__index = require("qamar.parser.node"),
}
setmetatable(node_expression, MTMT)

---creates a new node object
---@param type number
---@param pos range
---@param MT table|nil
---@return node_expression
function node_expression.new(type, pos, precedence, right_associative, MT)
	local ret = N(type, pos, MT or node_expression)
	ret.precedence = precedence
	ret.right_associative = right_associative
	return ret
end
return node_expression
