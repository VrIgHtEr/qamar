local digisim = _G['digisim']
local digisim_path = _G['digisim_path']

---@param file string
---@return string|nil
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
    table = table,
    pairs = pairs,
    ipairs = ipairs,
    tostring = tostring,
    type = type,
    error = error,
}

local cache = {}

local function create_env(id, opts)
    if opts == nil then
        opts = {}
    end
    if type(opts) ~= 'table' then
        error 'opts must be a table'
    end
    local env = {
        opts = opts,
        input = function(name, pin_start, pin_end, trace)
            pin_start = pin_start or 0
            pin_end = pin_end or pin_start
            trace = trace and true or false
            if pin_start < 0 or pin_start > 1048576 or pin_end < pin_start or pin_end > 1048576 then
                error 'pin index out of bounds'
            end
            digisim.createport(id, name, true, pin_start, pin_end, trace)
        end,
        output = function(name, pin_start, pin_end, trace)
            pin_start = pin_start or 0
            pin_end = pin_end or pin_start
            trace = trace and true or false
            if pin_start < 0 or pin_start > 1048576 or pin_end < pin_start or pin_end > 1048576 then
                error 'pin index out of bounds'
            end
            digisim.createport(id, name, false, pin_start or 0, pin_end, trace)
        end,
        createcomponent = function(name)
            digisim.createcomponent(id, name)
        end,
        wire = function(a, b)
            digisim.connect(id, a, b)
        end,
        Nand = function(name)
            digisim.components.Nand(id, name)
        end,
    }
    return setmetatable({}, {
        __index = setmetatable(env, {
            __newindex = function()
                error 'writing to global variables is not allowed'
            end,
            __metatable = function() end,
            __index = function(_, index)
                if type(index) == 'string' and index:len() > 0 then
                    local c = index:sub(1, 1):byte()
                    if c >= ('A'):byte() and c <= ('Z'):byte() then
                        local constructor
                        if cache[index] ~= nil then
                            if not cache[index] then
                                return
                            end
                            constructor = cache[index]
                        else
                            local file = read_file(digisim_path .. '/library/' .. index .. '.lua')
                            if file then
                                local success, compiled = pcall(loadstring, file, index)
                                if not success or not compiled then
                                    cache[index] = false
                                    return
                                end
                                constructor = compiled
                                cache[index] = constructor
                            end
                        end
                        return function(name, o)
                            if o == nil then
                                if type(name) == 'table' then
                                    o = name
                                    name = o.name
                                    if name == nil then
                                        name = o[1]
                                    end
                                else
                                    o = {}
                                end
                            end
                            if type(o) ~= 'table' then
                                error 'invalid opts'
                            end
                            if type(name) ~= 'string' then
                                error 'invalid name'
                            end
                            o.name = name
                            local comp = digisim.createcomponent(id, name)
                            local old_fenv = getfenv(constructor)
                            setfenv(constructor, create_env(comp, o))
                            local success, err = pcall(constructor)
                            setfenv(constructor, old_fenv)
                            if not success then
                                error(err)
                            end
                        end
                    end
                end
                return base_env[index]
            end,
        }),
    })
end

local function compile(opts)
    local text = read_file(digisim_path .. '/root.lua')
    if text == nil then
        error 'failed to load root component'
    end
    local constructor = loadstring(text)
    if constructor == nil then
        error 'failed to load root component'
    end
    if opts == nil then
        opts = {}
    end
    if type(opts) ~= 'table' then
        error 'invalid opts'
    end
    opts.name = '.'
    local old_env = getfenv(constructor)
    setfenv(constructor, create_env(digisim.root, opts))
    local ret = { pcall(constructor) }
    setfenv(constructor, old_env)
    if ret[1] then
        table.remove(ret, 1)
        return unpack(ret)
    else
        error(ret[2])
    end
end

compile()
