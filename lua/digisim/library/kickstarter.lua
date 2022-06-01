---@class simulation
---@field new_kickstarter fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"kickstarter",
		---@param s simulation
		---@param f string
		---@param opts boolean
		function(s, f, opts)
			opts = opts or {}
			opts.names = {
				inputs = {
					"rst~",
					"rising",
					"falling",
					"clk~",
				},
				outputs = {
					"branch",
					"icomplete",
				},
			}
			s:add_component(f, opts)

			local s0 = f .. ".s0"
			s:new_ms_d_flipflop(s0)
			s:c(f, "rst~", s0, "rst~")
			s:c(f, "rising", s0, "rising")
			s:c(f, "falling", s0, "falling")
			s:c("VCC", "q", s0, "d")

			local bufen = f .. ".bufen"
			s:new_and_bank(bufen):c(f, "clk~", bufen, "a"):c(s0, "q~", bufen, "b")
			local buf = f .. ".buf"
			s:new_tristate_buffer(buf, { width = 2 })
			s:cp(1, "VCC", "q", 1, buf, "a", 1)
			s:cp(1, "VCC", "q", 1, buf, "a", 2)
			s:c(bufen, "q", buf, "en")
			s:cp(1, buf, "q", 1, f, "branch", 1)
			s:cp(1, buf, "q", 2, f, "icomplete", 1)
		end
	)
end
