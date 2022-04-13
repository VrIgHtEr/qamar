local types = _G["char_stream"].types
for i, v in ipairs(types) do
	types[v] = i
end
return types
