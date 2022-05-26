---@class simulation
---@field new_load_store_unit fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"load_store_unit",
		---@param s simulation
		---@param f string
		---@param opts boolean
		function(s, f, opts)
			opts = opts or {}
			opts.names = {
				inputs = {
					{ "address", 32 },
					"clk",
					"trigin",
					"b16",
					"b32",
					"rst~",
				},
				outputs = { "trigout" },
			}
			s:add_component(f, opts)

			local ct = f .. ".ct"
			s:new_and_bank(ct):c(f, "clk", ct, "a"):c(f, "trigin", ct, "b")
			local startclk = f .. ".startclk"
			s:new_and_bank(startclk):c(ct, "q", startclk, "a")
			local started = f .. ".started"
			s:new_nor(started, { width = 4 }):c(started, "q", startclk, "b")

			local control = f .. ".control"
			s:new_ms_d_flipflop_bank(control, { width = 2 })
			s:cp(1, f, "b16", 1, control, "d", 1)
			s:cp(1, f, "b32", 1, control, "d", 2)
			s:c(startclk, "q", control, "clk")
			s:c(f, "rst~", control, "rst~")
			local address = f .. ".address"
			s:new_ms_d_flipflop_bank(address, { width = 32 })
			s:c(f, "address", address, "d")
			s:c(startclk, "q", address, "clk")
			s:c(f, "rst~", address, "rst~")

			local s0 = f .. ".s0"
			s
				:new_ms_d_flipflop(s0)
				:c(startclk, "q", s0, "d")
				:c(f, "clk", s0, "clk")
				:c(f, "rst~", s0, "rst~")
				:cp(1, s0, "q", 1, started, "in", 1)
			local bs0 = f .. ".bs0"
			s:new_and_bank(bs0):c(s0, "q", bs0, "a"):cp(1, control, "q", 1, bs0, "b", 1)
			local s1 = f .. ".s1"
			s
				:new_ms_d_flipflop(s1)
				:c(bs0, "q", s1, "d")
				:c(f, "clk", s1, "clk")
				:c(f, "rst~", s1, "rst~")
				:cp(1, s1, "q", 1, started, "in", 2)
			local bs1 = f .. ".bs1"
			s:new_and_bank(bs1):c(s1, "q", bs1, "a"):cp(1, control, "q", 2, bs1, "b", 1)
			local s2 = f .. ".s2"
			s
				:new_ms_d_flipflop(s2)
				:c(bs1, "q", s2, "d")
				:c(f, "clk", s2, "clk")
				:c(f, "rst~", s2, "rst~")
				:cp(1, s2, "q", 1, started, "in", 3)
			local bs2 = f .. ".bs2"
			s:new_and_bank(bs2):c(s2, "q", bs2, "a"):cp(1, control, "q", 2, bs2, "b", 1)
			local s3 = f .. ".s3"
			s
				:new_ms_d_flipflop(s3)
				:c(bs2, "q", s3, "d")
				:c(f, "clk", s3, "clk")
				:c(f, "rst~", s3, "rst~")
				:cp(1, s3, "q", 1, started, "in", 4)
		end
	)
end
