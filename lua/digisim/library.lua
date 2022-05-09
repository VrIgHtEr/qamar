---@param simulation simulation
return function(simulation)
	require("digisim.library.edge_detector")(simulation)
	require("digisim.library.sr_latch")(simulation)
	require("digisim.library.gated_sr_latch")(simulation)
	require("digisim.library.jk_flipflop")(simulation)
	require("digisim.library.ms_jk_flipflop")(simulation)
end
