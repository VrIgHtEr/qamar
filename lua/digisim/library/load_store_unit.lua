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
					"rising",
					"falling",
					"trigin",
					"b16",
					"b32",
					"rst~",
				},
				outputs = { "trigout" },
			}
			s:add_component(f, opts)

			local trig = f .. ".trig"
			local s0 = f .. ".s0"
			local s1 = f .. ".s1"
			local s2 = f .. ".s2"
			local s3 = f .. ".s3"
			local control = f .. ".control"
			local address = f .. ".address"

			do
				local ct = f .. ".ct"
				s:new_and_bank(ct):c(f, "rising", ct, "a"):c(f, "trigin", ct, "b")
				local startclk = f .. ".startclk"
				s:new_and_bank(startclk):c(ct, "q", startclk, "a")
				local nstarted = f .. ".nstarted"
				s:new_nor(nstarted, { width = 4 })
				local nstartedorfinished = f .. ".nstartedorfinished"
				s
					:new_or_bank(nstartedorfinished)
					:c(nstarted, "q", nstartedorfinished, "a")
					:c(f, "trigout", nstartedorfinished, "b")
					:c(nstartedorfinished, "q", startclk, "b")
				s:new_and_bank(trig):c(f, "trigin", trig, "a"):c(nstartedorfinished, "q", trig, "b")

				s:new_ms_d_flipflop_bank(control, { width = 2 })
				s:cp(1, f, "b16", 1, control, "d", 1)
				s:cp(1, f, "b32", 1, control, "d", 2)
				s:c(startclk, "q", control, "rising")
				s:c(f, "falling", control, "falling")
				s:c(f, "rst~", control, "rst~")
				s:new_ms_d_flipflop_bank(address, { width = 32 })
				s:c(f, "address", address, "d")
				s:c(startclk, "q", address, "rising")
				s:c(f, "falling", address, "falling")
				s:c(f, "rst~", address, "rst~")

				local f8 = f .. ".f8"
				s:new_and(f8):cp(2, control, "q~", 1, f8, "in", 1)
				local f16 = f .. ".f16"
				s:new_and(f16):cp(1, control, "q", 1, f16, "in", 1):cp(1, control, "q~", 2, f16, "in", 2)
				local f32 = f .. ".f32"
				s:new_and(f32):cp(2, control, "q", 1, f32, "in", 1)
				s
					:new_ms_d_flipflop(s0)
					:c(trig, "q", s0, "d")
					:c(f, "rising", s0, "rising")
					:c(f, "falling", s0, "falling")
					:c(f, "rst~", s0, "rst~")
					:cp(1, s0, "q", 1, nstarted, "in", 1)
				local bs0 = f .. ".bs0"
				s:new_and_bank(bs0):c(s0, "q", bs0, "a"):cp(1, control, "q", 1, bs0, "b", 1)
				s
					:new_ms_d_flipflop(s1)
					:c(bs0, "q", s1, "d")
					:c(f, "rising", s1, "rising")
					:c(f, "falling", s1, "falling")
					:c(f, "rst~", s1, "rst~")
					:cp(1, s1, "q", 1, nstarted, "in", 2)
				local bs1 = f .. ".bs1"
				s:new_and_bank(bs1):c(s1, "q", bs1, "a"):cp(1, control, "q", 2, bs1, "b", 1)
				s
					:new_ms_d_flipflop(s2)
					:c(bs1, "q", s2, "d")
					:c(f, "rising", s2, "rising")
					:c(f, "falling", s2, "falling")
					:c(f, "rst~", s2, "rst~")
					:cp(1, s2, "q", 1, nstarted, "in", 3)
				local bs2 = f .. ".bs2"
				s:new_and_bank(bs2):c(s2, "q", bs2, "a"):cp(1, control, "q", 2, bs2, "b", 1)
				s
					:new_ms_d_flipflop(s3)
					:c(bs2, "q", s3, "d")
					:c(f, "rising", s3, "rising")
					:c(f, "falling", s3, "falling")
					:c(f, "rst~", s3, "rst~")
					:cp(1, s3, "q", 1, nstarted, "in", 4)

				local trigout = f .. ".trigout"
				s:new_or(trigout, { width = 3 }):c(trigout, "q", f, "trigout")
				local trigout0 = trigout .. 0
				s
					:new_and_bank(trigout0)
					:cp(1, trigout0, "q", 1, trigout, "in", 1)
					:c(s0, "q", trigout0, "a")
					:c(f8, "q", trigout0, "b")
				local trigout1 = trigout .. 1
				s
					:new_and_bank(trigout1)
					:cp(1, trigout1, "q", 1, trigout, "in", 2)
					:c(s1, "q", trigout1, "a")
					:c(f16, "q", trigout1, "b")
				local trigout3 = trigout .. 3
				s
					:new_and_bank(trigout3)
					:cp(1, trigout3, "q", 1, trigout, "in", 3)
					:c(s3, "q", trigout3, "a")
					:c(f32, "q", trigout3, "b")
			end
		end
	)
end
