---@class simulation
---@field new_register_bank fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"register_bank",
		---@param self simulation
		---@param name string
		---@param opts boolean
		function(self, name, opts)
			opts = opts or { width = 1, selwidth = 1 }
			local width = opts.width or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			width = math.floor(width)
			if width < 1 then
				error("invalid width")
			end
			local selwidth = opts.selwidth or 1
			if type(selwidth) ~= "number" then
				error("invalid selwidth type")
			end
			selwidth = math.floor(selwidth)
			if selwidth < 1 then
				error("invalid selwidth")
			end
			local numregs = math.pow(2, selwidth)
			opts.names = {
				inputs = {
					{ "in", width },
					"rising",
					{ "sela", selwidth },
					{ "selb", selwidth },
					{ "selw", selwidth },
					"~rst",
				},
				outputs = { { "outa", width }, { "outb", width } },
			}
			self:add_component(name, nil, opts)

			local sela = name .. ".sela"
			local selb = name .. ".selb"
			local selw = name .. ".selw"

			self:new_binary_decoder(sela, { width = selwidth })
			self:c(name, "sela", sela, "in")
			self:new_binary_decoder(selb, { width = selwidth })
			self:c(name, "selb", selb, "in")
			self:new_binary_decoder(selw, { width = selwidth })
			self:c(name, "selw", selw, "in")

			local vcc = name .. ".vcc"
			self:new_vcc(vcc)

			local r = name .. ".r"
			for i = 1, numregs do
				local n = r .. (i - 1)
				if i > 1 then
					self:new_register(n, { width = width })
					self:c(name, "outa", n, "outa")
					self:c(name, "outb", n, "outb")
					self:c(name, "~rst", n, "~rst")
					self:cp(1, sela, "q", i, n, "oea", 1)
					self:cp(1, selb, "q", i, n, "oeb", 1)
					self:c(name, "rising", n, "rising")
					self:cp(1, selw, "q", i, n, "write", 1)
					self:c(name, "in", n, "in")
				else
					self:new_register_zero(n, { width = width })
					self:c(name, "outa", n, "outa")
					self:c(name, "outb", n, "outb")
					self:cp(1, sela, "q", i, n, "oea", 1)
					self:cp(1, selb, "q", i, n, "oeb", 1)
				end
			end
			return self
		end
	)
end
