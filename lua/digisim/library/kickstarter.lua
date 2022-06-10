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
			s:high(s0, "d")

			local buf = f .. ".buf"
			s:new_tristate_buffer(buf, { width = 2 })
			s:high(buf, "a", 1, 2)
			s:c(s0, "q~", buf, "en")
			s:cp(1, buf, "q", 1, f, "branch", 1)
			s:cp(1, buf, "q", 2, f, "icomplete", 1)
		end
	)
end
