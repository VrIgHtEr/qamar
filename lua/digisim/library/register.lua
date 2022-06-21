---@class simulation
---@field new_register fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"register",
		---@param self simulation
		---@param name string
		---@param opts boolean
		function(self, name, opts)
			opts = opts or { width = 1, logname = nil }
			local width = opts.width or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			width = math.floor(width)
			if width < 1 then
				error("invalid width")
			end
			opts.names = {
				inputs = { { "in", width }, "rising", "write", "oea", "oeb", "~rst" },
				outputs = { { "outa", width }, { "outb", width } },
			}
			self:add_component(name, opts)

			local write = name .. ".wa"
			self:new_and(write):cp(1, name, "rising", 1, write, "in", 1):cp(1, name, "write", 1, write, "in", 2)

			local oa = name .. ".bufa"
			local ob = name .. ".bufb"
			self:new_tristate_buffer(oa, { width = width }):c(oa, "q", name, "outa"):c(name, "oea", oa, "en")
			self:new_tristate_buffer(ob, { width = width }):c(ob, "q", name, "outb"):c(name, "oeb", ob, "en")

			if opts.logname ~= nil then
				local logger = name .. ".logger"
				self
					:add_component(logger, { names = { inputs = { { "value", width } } } }, function(_, input)
						self.log[opts.logname] = input
					end)
					:c(oa, "a", logger, "value")
			end

			for i = 1, width do
				local b = name .. ".bits.b" .. (i - 1)
				local s = b .. ".s"
				local r = b .. ".r"
				local gs = b .. ".gs"
				local gr = b .. ".gr"
				local dn = b .. ".n"
				local rs = b .. ".rs"
				local rr = b .. ".rr"
				local rst = b .. ".rst"

				self:new_not(rst):c(name, "~rst", rst, "a")

				-- create latch nand gates
				self:new_nand(s)
				self:new_nand(r)

				--connect output bit
				self:cp(1, s, "q", 1, oa, "a", i)
				self:cp(1, s, "q", 1, ob, "a", i)

				--cross connect nand gates
				self:cp(1, s, "q", 1, r, "in", 1)
				self:cp(1, r, "q", 1, s, "in", 1)

				--create clock gating and gates
				self:new_nand(gs)
				self:new_nand(gr)

				--connect clock to clock gating
				self:cp(1, write, "q", 1, gs, "in", 1)
				self:cp(1, write, "q", 1, gr, "in", 1)

				--connect clock gating to latch through reset logic
				self:new_or(rs)
				self:cp(1, rst, "q", 1, rs, "in", 1)
				self:cp(1, gs, "q", 1, rs, "in", 2)
				self:cp(1, rs, "q", 1, s, "in", 2)
				self:new_and(rr)
				self:cp(1, name, "~rst", 1, rr, "in", 1)
				self:cp(1, gr, "q", 1, rr, "in", 2)
				self:cp(1, rr, "q", 1, r, "in", 2)

				--create data inverter
				self:new_not(dn)

				--connect data to data inverter
				self:cp(1, name, "in", i, dn, "a", 1)

				--connect set and reset signals
				self:cp(1, dn, "q", 1, gr, "in", 2)
				self:cp(1, name, "in", i, gs, "in", 2)
			end

			return self
		end
	)
end
