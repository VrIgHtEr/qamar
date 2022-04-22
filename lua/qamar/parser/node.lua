local setmetatable = setmetatable

---@class node
---@field pos range
---@field type number
local node = {}

---creates a new node object
---@param type number
---@param pos range
---@param MT table|nil
---@return node
function node.new(type, pos, MT)
	return setmetatable({ type = type, pos = pos }, MT or node)
end
return node
