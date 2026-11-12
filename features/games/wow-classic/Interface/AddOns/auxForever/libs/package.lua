local _, addon_table = ...

local _G, setfenv, setmetatable = _G, setfenv, setmetatable
local environments, interfaces = {}, {}
local require, create_module, pass, empty, environment_mt

local function module(_, name)
    local defined = not not environments[name]
    if not defined then
        create_module(name)
    end
    setfenv(2, environments[name])
    return defined
end

setmetatable(addon_table, { __call = module })

function pass() end

empty = setmetatable({}, { __metatable=false, __newindex=pass })

-- Forever: look up compatibility shims (compat.lua) before falling back to _G
local compat = {}
addon_table.compat = compat
environment_mt = { __index = function(_, k)
    local v = compat[k]
    if v == nil then
        v = _G[k]
    end
    return v
end }

function require(name)
    if not interfaces[name] then
        create_module(name)
    end
    return interfaces[name]
end

function create_module(name)
	local environment = setmetatable({ pass = pass, empty = empty, require = require }, environment_mt)
	local exports = {}
	environment.M = setmetatable({}, {
		__metatable = false,
		__newindex = function(_, k, v)
			environment[k], exports[k] = v, v
		end,
	})
	environment._M = environment
	environments[name] = environment
	interfaces[name] = setmetatable({}, { __metatable = false, __index = exports, __newindex = pass })
end
