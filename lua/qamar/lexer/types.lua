local types = require("qamar.ffi").types
for i, v in ipairs(types) do
	types[v] = i
end
return types
