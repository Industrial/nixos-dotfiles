-- Lua 5.1
-- Converts .luacheckrc globals into .luarc.json
-- No setfenv usage

local function load_luacheckrc(path)
  local chunk, err = loadfile(path)
  if not chunk then
    error(err)
  end

  -- Capture globals before execution
  local before = {}
  for k in pairs(_G) do
    before[k] = true
  end

  chunk()

  -- Capture new globals after execution
  local after = {}
  for k, v in pairs(_G) do
    if not before[k] then
      after[k] = v
    end
  end

  return after
end

local function collect_globals(tbl, out)
  if type(tbl) ~= "table" then return end
  for _, v in ipairs(tbl) do
    if type(v) == "string" then
      out[v] = true
    end
  end
end

local function sorted_keys(set)
  local keys = {}
  for k in pairs(set) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  return keys
end

local function write_luarc_json(globals, path)
  local f = assert(io.open(path, "w"))

  f:write("{\n")
  f:write('  "Lua.diagnostics.globals": [\n')

  for i, name in ipairs(globals) do
    f:write(string.format('    "%s"%s\n', name, i < #globals and "," or ""))
  end

  f:write("  ]\n")
  f:write("}\n")
  f:close()
end

-- ---- main ----

local luacheckrc = arg[1] or ".luacheckrc"
local output = arg[2] or ".luarc.json"

local cfg = load_luacheckrc(luacheckrc)

local globals_set = {}
collect_globals(cfg.globals, globals_set)
collect_globals(cfg.read_globals, globals_set)

local globals = sorted_keys(globals_set)

write_luarc_json(globals, output)

print(string.format(
  "Generated %s with %d globals from %s",
  output, #globals, luacheckrc
))
