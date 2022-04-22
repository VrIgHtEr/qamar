local indentstring = "    "
local M
M = {
	err = {
		level = 0,
		write = function(str)
			return io.stderr:write(string.rep(indentstring, M.err.level) .. str)
		end,
		writeln = function(str)
			return M.err.write(str .. "\n")
		end,
		flush = function()
			return io.stderr:flush()
		end,
		indent = function()
			M.err.level = M.err.level + 1
		end,
		dedent = function()
			if M.err.level > 0 then
				M.err.level = M.err.level - 1
			end
		end,
	},
	out = {
		level = 0,
		write = function(str)
			return io.stdout:write(string.rep(indentstring, M.out.indent) .. str)
		end,
		writeln = function(str)
			return M.out.write(str .. "\n")
		end,
		flush = function()
			return io.stdout:flush()
		end,
		indent = function()
			M.out.level = M.out.level + 1
		end,
		dedent = function()
			if M.out.level > 0 then
				M.out.level = M.out.level - 1
			end
		end,
	},
}

return M
