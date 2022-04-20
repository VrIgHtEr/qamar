local qamar = {}
local util = require("qamar.util")
local parser = require("qamar.parser")

local function scandir(directory)
	local i, t, popen = 0, {}, io.popen
	local proc = popen('find "' .. directory .. '" -type f -name "*.lua"')
	for filename in proc:lines() do
		i = i + 1
		t[i] = filename
	end
	proc:close()
	return t
end

local dpath = "/home/cedric/qamar"
local odir = dpath
--odir = '/mnt/c/luaparse'
local idir = "/home/cedric/.local/share/nvim"
--idir = "/home/cedric/code/c/qamar/lua"
local cfg = require("qamar.config")
local function stdout(str)
	io.stdout:write((tostring(str or "")) .. "\n")
	--	io.stdout:flush()
end
local function stderr(str)
	io.stderr:write((tostring(str or "")) .. "\n")
	--	io.stderr:flush()
end

local function shuffle(tbl)
	for i = #tbl, 2, -1 do
		local p = math.random(i)
		tbl[i], tbl[p] = tbl[p], tbl[i]
	end
end

local excluded = {
	[[/home/cedric/.local/share/nvim/site/pack/nvim-lua/opt/plenary.nvim/scripts/vararg/rotate.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/neovim/test/functional/fixtures/lua/syntax_error.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/neovim/test/functional/legacy/069_multibyte_formatting_spec.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/test/completion/common.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/grammar/gengc.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/StyLua/tests/inputs-full_moon/goto-as-identifier.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/StyLua/tests/inputs/string-escapes-2.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/StyLua/tests/inputs/excess-parentheses.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/script/core/completion/keyword.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/script/core/completion/completion.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/grammar/strings.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/grammar/tpack.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/grammar/events.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/grammar/utf8.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/grammar/literals.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/format_text/wait_format/comment.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/format_text/wait_format/unicode.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/format_text/wait_format/while.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/format_text/wait_format_should_be/comment.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/format_text/wait_format_should_be/unicode.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/3rd/EmmyLuaCodeStyle/Test/test_script/format_text/wait_format_should_be/while.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/meta/3rd/lovr/library/lovr.data.lua]],
	[[/home/cedric/.local/share/nvim/env/opt/lua-language-server/meta/3rd/lovr/library/lovr.graphics.lua]],
}

for _, x in ipairs(excluded) do
	excluded[x] = true
end

local types = require("qamar.parser.types")
local function tostring_tree(tree)
	return vim.inspect(tree, {
		process = function(item, path)
			local x = path[#path]
			if x ~= "precedence" and x ~= "right_associative" and tostring(x) ~= "inspect.METATABLE" then
				if x == "type" then
					return types[item] or item
				end
				if x == "pos" then
					return item.left.row .. ":" .. item.left.col .. " - " .. item.right.row .. ":" .. item.right.col
				end
				return item
			end
		end,
	})
end

local dstats
local function parse_everything()
	os.execute("rm -rf '" .. odir .. "'")
	local files = scandir(idir)
	--shuffle(files)
	os.execute("mkdir -p '" .. odir .. "'")
	stderr()
	cfg.print("\n")

	local starttime = os.clock()
	local co = coroutine.create(function()
		dstats = {}
		local counter = 0
		local tlen = 0
		local numexcluded = 0
		for _, filename in ipairs(files) do
			if
				not excluded[filename]
				and not filename:match(".*-luau.*")
				and filename:match("^.*/grammar/math[.]lua$")
			then
				stdout("-----------------------------------------------------------------------------------")
				stdout("PARSING FILE " .. (counter + 1) .. ": " .. filename)
				local txt = util.read_file(filename)
				coroutine.yield()
				if txt then
					local success, tree = pcall(parser.parse, txt)
					if success and tree then
						local ok, str
						if cfg.debug_to_string then
							ok, str = pcall(tostring, tree)
						else
							ok, str = true, nil
						end
						if not ok then
							stderr("TOSTRING: " .. filename)
							if str ~= nil then
								stderr(tostring(str))
							end
						else
							counter = counter + 1
							if cfg.debug_to_string then
								local outpath = filename:gsub("^/home/", odir .. "/")
								local idx = 0
								while true do
									local nidx = string.find(outpath, "/", idx + 1)
									if not nidx then
										break
									end
									idx = nidx
								end
								local outdir = string.sub(outpath, 1, idx - 1)
								os.execute("mkdir -p '" .. outdir .. "'")
								util.write_file(outpath, str)
								--[[
								if false then
									print(tostring_tree(tree))
								end
                                ]]
								tlen = tlen + string.len(str)
								stdout(str)
							end
						end
					else
						stderr(filename)
						if tree ~= nil then
							local str = tostring(tree)
							local idx = str:find(": ")
							if idx then
								str = str:sub(idx + 2)
							end
							stderr(str)
							stderr("")
						end
					end
				end
			else
				numexcluded = numexcluded + 1
			end
		end

		stderr("total length: " .. tlen)
		local total = 0
		for _, v in pairs(dstats) do
			total = total + v
		end
		if total > 0 then
			local stats = {}
			for k, v in pairs(dstats) do
				table.insert(stats, { name = k, frequency = v / total })
			end
			table.sort(stats, function(a, b)
				return a.frequency > b.frequency
			end)
			stdout("")
			for _, x in ipairs(stats) do
				stdout(x.name .. ": " .. (x.frequency * 100) .. "%")
			end
		end
		return counter, #files - numexcluded
	end)
	local function step()
		local success, parsed, total = coroutine.resume(co)
		if success then
			local stat = coroutine.status(co)
			if stat == "dead" then
				local time = os.clock() - starttime
				local message = "PARSED "
					.. tostring(parsed)
					.. " OF "
					.. total
					.. " FILES IN "
					.. tostring(time)
					.. " seconds"
				stdout(message)
				stderr(message)
			else
				return step()
			end
		else
			stdout("ERROR: " .. tostring(parsed))
			stderr("ERROR: " .. tostring(parsed))
		end
	end
	step()
end

function qamar.run()
	math.randomseed(os.time())
	parse_everything()
end

return qamar
