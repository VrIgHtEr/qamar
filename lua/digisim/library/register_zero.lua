---@class simulation
---@field new_register_zero fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"register_zero",
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
			opts.names = {
				inputs = { "oea", "oeb" },
				outputs = { { "outa", width }, { "outb", width } },
			}
			self:add_component(name, nil, opts)

			local oa = name .. ".bufa"
			local ob = name .. ".bufb"
			self:new_tristate_buffer(oa, { width = width }):c(oa, "q", name, "outa"):c(name, "oea", oa, "en")
			self:new_tristate_buffer(ob, { width = width }):c(ob, "q", name, "outb"):c(name, "oeb", ob, "en")

			local gnd = name .. ".gnd"
			self:new_gnd(gnd)
			for i = 1, width do
				self:cp(1, gnd, "q", 1, oa, "a", i)
				self:cp(1, gnd, "q", 1, ob, "a", i)
			end

			return self
		end
	)
end
