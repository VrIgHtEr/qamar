---@class simulation
---@field new_binary_decoder fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"binary_decoder",
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
			local outputs = math.pow(2, width)
			opts.names = { inputs = { { "in", width } }, outputs = { { "q", outputs } } }

			self:add_component(name, nil, opts)
			local n = name .. ".n"
			self:new_not(n):cp(1, name, "in", width, n, "a", 1)
			if width == 1 then
				self:cp(1, n, "q", 1, name, "q", 1)
				self:cp(1, name, "in", 1, name, "q", 2)
			else
				outputs = outputs / 2
				local lo = name .. ".lo"
				local al = name .. ".al"
				self:new_binary_decoder(lo, { width = width - 1 })
				self:cp(width - 1, name, "in", 1, lo, "in", 1)
				self:new_and_bank(al, { width = outputs })
				self:cp(outputs, lo, "q", 1, al, "a", 1)
				self:cp(outputs, al, "q", 1, name, "q", 1)

				local hi = name .. ".hi"
				local ah = name .. ".ah"
				self:new_binary_decoder(hi, { width = width - 1 })
				self:cp(width - 1, name, "in", 1, hi, "in", 1)
				self:new_and_bank(ah, { width = outputs })
				self:cp(outputs, hi, "q", 1, ah, "a", 1)
				self:cp(outputs, ah, "q", 1, name, "q", outputs + 1)

				for i = 1, outputs do
					self:cp(1, n, "q", 1, al, "b", i)
					self:cp(1, name, "in", width, ah, "b", i)
				end
			end

			return self
		end
	)
end
