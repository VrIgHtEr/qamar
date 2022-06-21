---@class simulation
---@field new_program_counter fun(circuit:simulation,name:string,opts:table|nil):simulation

local BITS = 32

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"program_counter",
		---@param s simulation
		---@param f string
		---@param opts boolean
		function(s, f, opts)
			opts = opts or { logname = nil }
			opts.names = {
				inputs = {
					"rst~",
					"rising",
					"falling",
					"branch",
					"icomplete",
					"oe_a",
					{ "a", BITS },
					{ "d", BITS },
				},
				outputs = {
					{ "pc", BITS },
				},
			}
			s:add_component(f, opts)

			local latchor = f .. ".icomporbranch"
			s:new_or_bank(latchor):c(f, "icomplete", latchor, "a"):c(f, "branch", latchor, "b")
			local latch_trigger = f .. ".trigger"
			s:new_and_bank(latch_trigger):c(f, "rising", latch_trigger, "a"):c(latchor, "q", latch_trigger, "b")
			local pc = f .. ".register"
			s
				:new_ms_d_flipflop_bank(pc, { width = BITS, logname = opts.logname })
				:c(f, "rst~", pc, "rst~")
				:c(latch_trigger, "q", pc, "rising")
				:c(f, "falling", pc, "falling")

			local mux = f .. ".mux"
			s:new_mux_bank(mux, { width = 1, bits = BITS })
			s:c(f, "branch", mux, "sel")
			s:c(f, "d", mux, "d1")
			s:cp(2, pc, "q", 1, mux, "d0", 1)
			do
				local padder
				for i = 3, BITS do
					local adder = f .. ".adder" .. (i - 1)
					s:new_half_adder(adder)
					s:cp(1, pc, "q", i, adder, "a", 1)
					s:cp(1, adder, "sum", 1, mux, "d0", i)
					if i == 3 then
						s:high(adder, "b")
					else
						s:c(padder, "carry", adder, "b")
					end
					padder = adder
				end
			end
			s:c(mux, "out", f, "pc")
			s:c(mux, "out", pc, "d")
			local nbranch = f .. ".nbranch"
			s:new_not(nbranch)
			s:c(f, "branch", nbranch, "a")

			local oe = f .. ".oe"
			s:new_and_bank(oe)
			s:c(f, "icomplete", oe, "a")
			s:c(nbranch, "q", oe, "b")

			local bufd = f .. ".bufd"
			s:new_tristate_buffer(bufd, { width = BITS })
			s:c(oe, "q", bufd, "en")
			s:c(mux, "out", bufd, "a")
			s:c(bufd, "q", f, "d")

			local bufa = f .. ".bufa"
			s:new_tristate_buffer(bufa, { width = BITS })
			s:c(f, "oe_a", bufa, "en")
			s:c(pc, "q", bufa, "a")
			s:c(bufa, "q", f, "a")
		end
	)
end
