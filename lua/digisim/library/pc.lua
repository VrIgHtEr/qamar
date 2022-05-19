---@class simulation
---@field new_pc fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"pc",
		---@param sim simulation
		---@param pc string
		---@param opts boolean
		function(sim, pc, opts)
			opts = opts or { width = 1, loop = false }
			local width = opts.width or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			if width < 1 then
				error("invalid width")
			end
			opts.names = {
				inputs = {
					{ "bus", width },
					"dir",
				},
				outputs = {},
			}
			sim:add_component(pc, opts)

			local ndir = pc .. ".ndir"
			sim:new_not(ndir):c(pc, "dir", ndir, "a")

			return sim
		end
	)
end
