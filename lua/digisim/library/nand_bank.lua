---@class simulation
---@field new_nand_bank function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"nand_bank",
		---@param self simulation
		---@param name string
		---@param opts boolean
		function(self, name, opts)
			opts = opts or { width = 1 }
			local width = opts.width or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			width = math.floor(width)
			if width < 2 then
				error("invalid width")
			end
			opts.names = { inputs = { { "a", width }, { "b", width } }, outputs = { { "q", width } } }
			self:add_component(name, nil, opts)
			for i = 1, width do
				local n = name .. ".a" .. (i - 1)
				self:new_nand(n)
				self:cp(1, name, "a", i, n, "in", 1)
				self:cp(1, name, "b", i, n, "in", 2)
				self:cp(1, n, "q", 1, name, "q", i)
			end
			return self
		end
	)
end
