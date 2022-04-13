local types = _G["char_stream"].types
do
	for i, v in ipairs(types) do
		io.write(v .. "\n")
		types[v] = i
	end
end

return types
