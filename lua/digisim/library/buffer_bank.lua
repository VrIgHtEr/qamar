---@class simulation
---@field new_buffer_bank fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"buffer_bank",
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
			opts.names = { inputs = { { "a", width } }, outputs = { { "q", width } } }
			self:add_component(name, opts)
			for i = 1, width do
				local n = name .. ".a" .. (i - 1)
				self:new_buffer(n)
				self:cp(1, name, "a", i, n, "a", 1)
				self:cp(1, n, "q", 1, name, "q", i)
			end
			return self
		end
	)
end
