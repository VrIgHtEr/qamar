local digisim = _G['digisim']

---@class zigcomp
---@field id number
local Component = {}
local Component_MT = {
    __index = Component,
}

---@param id number
---@return zigcomp
function Component.new(id)
    if type(id) ~= 'userdata' then
        error 'invalid id'
    end
    return setmetatable({ id = id }, Component_MT)
end

local function read_file(file)
    local osuccess, f = pcall(io.open, file, 'rb')
    if not osuccess or not f then
        return
    end
    local success, content = pcall(f.read, f, '*all')
    if not success or not content then
        return
    end
    f:close()
    return content
end

local base_env = {
    math = math,
    pairs = pairs,
    ipairs = ipairs,
    tostring = tostring,
    print = print,
    type = type,
}

local cache = {}

local function create_env(id)
    local env = {}
    function env.input(name, pin_start, pin_end, trace)
        pin_start = pin_start or 0
        pin_end = pin_end or pin_start
        trace = trace and true or false
        if pin_start < 0 or pin_start > 1048576 or pin_end < pin_start or pin_end > 1048576 then
            error 'pin index out of bounds'
        end
        digisim.createport(id, name, true, pin_start, pin_end, trace)
    end
    function env.output(name, pin_start, pin_end, trace)
        pin_start = pin_start or 0
        pin_end = pin_end or pin_start
        trace = trace and true or false
        if pin_start < 0 or pin_start > 1048576 or pin_end < pin_start or pin_end > 1048576 then
            error 'pin index out of bounds'
        end
        digisim.createport(id, name, false, pin_start or 0, pin_end, trace)
    end
    function env.createcomponent(name)
        digisim.createcomponent(id, name)
    end
    function env.wire(a, b)
        digisim.connect(id, a, b)
    end
    function env.Nand(name)
        digisim.components.Nand(id, name)
    end
    return setmetatable(env, {
        __index = function(_, index)
            if type(index) == 'string' and index:len() > 0 then
                local c = index:sub(1, 1):byte()
                if c >= ('A'):byte() and c <= ('Z'):byte() then
                    local constructor
                    if cache[index] ~= nil then
                        constructor = cache[index]
                    else
                        local file = read_file(digisim_path .. '/library/' .. index .. '.lua')
                        if file then
                            local success, compiled = pcall(loadstring, file, index)
                            if not success or not compiled then
                                return
                            end
                            constructor = compiled
                            cache[index] = constructor
                        end
                    end
                    return function(name, opts)
                        local comp = digisim.createcomponent(id, name)
                        local old_fenv = getfenv(constructor)
                        setfenv(constructor, create_env(comp))
                        local success, err = pcall(constructor, opts)
                        setfenv(constructor, old_fenv)
                        if not success then
                            error(err)
                        end
                    end
                end
            end
            return base_env[index]
        end,
        __newindex = function()
            error 'global variables are not allowed'
        end,
    })
end

function Component:construct(constructor, ...)
    local old_env = getfenv(constructor)
    setfenv(constructor, create_env(self.id))
    local ret = { pcall(constructor, ...) }
    setfenv(constructor, old_env)
    if ret[1] then
        table.remove(ret, 1)
        return unpack(ret)
    else
        error(ret[2])
    end
end

function Component.compile()
    local root = Component.new(digisim.root)
    root:construct(loadstring(read_file(digisim_path .. '/root.lua')))
end

Component.compile()
return Component
