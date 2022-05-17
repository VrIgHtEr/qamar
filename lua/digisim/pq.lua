---@class pq
local pq = { count = nil }
local MT = { __index = pq }

---@return pq
function pq.new()
	local ret = setmetatable({
		count = 0,
	}, MT)
	return ret
end

function pq:peek()
	if self.count > 0 then
		return self[1]
	end
end

---@param self pq
---@param index number
local function float(self, index)
	local p = math.floor(index / 2)
	while p > 1 do
		if self[index][1] >= self[p][1] then
			break
		end
		self[index], self[p] = self[p], self[index]
		index = p
		p = math.floor(index / 2)
	end
end

---@param self pq
---@param index number
local function sink(self, index)
	local max = math.floor(self.count / 2)
	while index <= max do
		local c = index * 2
		if c < self.count and self[c + 1][1] < self[c][1] then
			c = c + 1
		end
		if self[c][1] >= self[index][1] then
			break
		end
		self[c], self[index] = self[index], self[c]
		index = c
	end
end

function pq:push(priority, value)
	if value ~= nil then
		self.count = self.count + 1
		self[self.count] = { priority, value }
		self.count = self.count + 1
		float(self, self.count)
	end
end

function pq:pop()
	if self.count > 0 then
		local ret = self[1]
		self[1] = self[self.count]
		self[self.count] = nil
		self.count = self.count - 1
		sink(self, 1)
		return ret
	end
end

return pq
