---@class simulation
---@field new_buffer function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"buffer",
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
			if width < 1 then
				error("invalid width")
			end
			opts.names = { inputs = { { "a", width } }, outputs = { "q" } }
			return self:add_component(name, function(_, a)
				return a
			end, opts)
		end
	)
end
