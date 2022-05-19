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

			self:add_component(name, opts)
			local n = name .. ".n"
			self:new_not(n):cp(1, name, "in", width, n, "a", 1)
			if width == 1 then
				self:cp(1, n, "q", 1, name, "q", 1)
				self:cp(1, name, "in", 1, name, "q", 2)
			else
				local dec = name .. ".dec"
				self:new_binary_decoder(dec, { width = width - 1 })
				self:cp(width - 1, name, "in", 1, dec, "in", 1)

				local al = name .. ".al"
				local ah = name .. ".ah"
				self:new_and_bank(al, { width = outputs / 2 })
				self:new_and_bank(ah, { width = outputs / 2 })
				self:cp(outputs / 2, al, "q", 1, name, "q", 1)
				self:cp(outputs / 2, ah, "q", 1, name, "q", outputs / 2 + 1)
				for i = 1, outputs / 2 do
					self:cp(1, name, "in", width, ah, "a", i)
					self:cp(1, n, "q", 1, al, "a", i)
					self:cp(1, dec, "q", i, al, "b", i)
					self:cp(1, dec, "q", i, ah, "b", i)
				end
			end

			return self
		end
	)
end
