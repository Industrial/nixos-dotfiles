local MAJOR, MINOR = "idLibSetTable-1.0", 1
local LibStub = _G.LibStub
if not (LibStub) then
  error(tostring(MAJOR) .. " requires LibStub")
end
local core = LibStub:NewLibrary(MAJOR, MINOR)
if not (core) then
  return 
end
local lua_type = _G.type
local tonumber
tonumber = function(v)
  return _G.tonumber(v)
end
local next = _G.next
local EMPTY = { }
core.Install = function(lib, opts)
  if opts == nil then
    opts = { }
  end
  local major = opts.major or MAJOR
  local member = opts.member or "InSet"
  if not (lua_type(lib) == "table") then
    error(tostring(MAJOR) .. ":Install requires a library table", 2)
  end
  lib.domains = lib.domains or { }
  lib.rawSets = lib.rawSets or { }
  lib.cache = lib.cache or { }
  lib.parseCount = lib.parseCount or 0
  lib.manifestData = lib.manifestData or { }
  local decode
  decode = function(set)
    local hit = lib.cache[set]
    if hit then
      return hit
    end
    local raw = lib.rawSets[set]
    if not (raw) then
      return nil
    end
    local out = { }
    for entry in raw:gmatch("[^,]+") do
      local id, value = entry:match("^(%-?%d+):(%-?%d+%.?%d*)$")
      if id then
        out[tonumber(id)] = tonumber(value)
      else
        local bare = entry:match("^(%-?%d+)$")
        if bare then
          out[tonumber(bare)] = 1
        end
      end
    end
    lib.cache[set] = out
    lib.parseCount = lib.parseCount + 1
    return out
  end
  lib.AddData = function(self, domain, revision, data)
    if not (lua_type(domain) == "string" and domain ~= "") then
      error(tostring(major) .. ":AddData requires a domain name", 2)
    end
    if not (lua_type(data) == "table") then
      error(tostring(major) .. ":AddData requires a data table", 2)
    end
    revision = tonumber(revision) or 0
    local existing = lib.domains[domain]
    if existing and existing.revision == revision then
      return false
    end
    if existing then
      for setName in pairs(existing.sets) do
        lib.rawSets[setName] = nil
        lib.cache[setName] = nil
      end
    end
    local sets = { }
    for setName, raw in pairs(data) do
      local _continue_0 = false
      repeat
        if not (lua_type(setName) == "string" and lua_type(raw) == "string") then
          _continue_0 = true
          break
        end
        sets[setName] = raw
        lib.rawSets[setName] = raw
        lib.cache[setName] = nil
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    lib.domains[domain] = {
      revision = revision,
      sets = sets
    }
    return true
  end
  lib.AddManifest = function(self, manifest)
    if not (lua_type(manifest) == "table") then
      return false
    end
    for k, v in pairs(manifest) do
      lib.manifestData[k] = v
    end
    return true
  end
  lib[member] = function(self, id, set)
    if not (lua_type(set) == "string") then
      return nil
    end
    local key = tonumber(id)
    if not (key) then
      return nil
    end
    local decoded = decode(set)
    if not (decoded) then
      return nil
    end
    return decoded[key]
  end
  lib.IterateSet = function(self, set)
    if not (lua_type(set) == "string") then
      return next, EMPTY
    end
    return next, (decode(set) or EMPTY)
  end
  lib.SetsFor = function(self, id)
    local key = tonumber(id)
    local out = { }
    if not (key) then
      return out
    end
    for setName in pairs(lib.rawSets) do
      if decode(setName)[key] ~= nil then
        out[#out + 1] = setName
      end
    end
    table.sort(out)
    return out
  end
  lib.Sets = function(self)
    local out
    do
      local _accum_0 = { }
      local _len_0 = 1
      for setName in pairs(lib.rawSets) do
        _accum_0[_len_0] = setName
        _len_0 = _len_0 + 1
      end
      out = _accum_0
    end
    table.sort(out)
    return out
  end
  lib.Manifest = function(self)
    local out = {
      domains = { }
    }
    for k, v in pairs(lib.manifestData) do
      out[k] = v
    end
    for domain, entry in pairs(lib.domains) do
      local count = 0
      for _ in pairs(entry.sets) do
        count = count + 1
      end
      out.domains[domain] = {
        revision = entry.revision,
        sets = count
      }
    end
    return out
  end
  lib._ResetCache = function(self)
    lib.cache = { }
    lib.parseCount = 0
  end
  return lib
end
return core
