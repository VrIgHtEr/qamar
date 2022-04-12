local M = {}

local fifos = {}

function M.create_fifo(path)
	if fifos[path] then
		return fifos[path]
	end
	if string.match(path, ".*/err$") then
		return io.stderr
	end
	if string.match(path, ".*/out$") then
		return io.stdout
	end
	if os.execute("mkfifo '" .. path .. "' 2>/dev/null") then
		local ret = io.open(path, "ab")
		if ret then
			fifos[path] = ret
			return ret
		end
	end
end

M.stats = {}

return M
