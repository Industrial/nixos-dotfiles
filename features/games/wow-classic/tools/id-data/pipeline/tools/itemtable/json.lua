local M = { }
local ESCAPES = {
  ['"'] = '\\"',
  ["\\"] = "\\\\",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t"
}
local escape
escape = function(s)
  return (s:gsub('[%c"\\]', function(c)
    return ESCAPES[c] or ("\\u%04x"):format(c:byte())
  end))
end
local number
number = function(n)
  if n ~= n or n == math.huge or n == -math.huge then
    error("cannot encode non-finite number in JSON")
  end
  if n == math.floor(n) and math.abs(n) < 2 ^ 53 then
    return ("%d"):format(n)
  else
    return ("%.14g"):format(n)
  end
end
local isArray
isArray = function(t)
  local n = 0
  for k in pairs(t) do
    if not (type(k) == "number") then
      return false
    end
    n = n + 1
  end
  return n == #t
end
local encodeValue
local encodeTable
encodeTable = function(t, indent, level)
  local pad = indent and ("\n" .. indent:rep(level + 1)) or ""
  local endPad = indent and ("\n" .. indent:rep(level)) or ""
  local sep = indent and ("," .. pad) or ","
  if isArray(t) then
    if #t == 0 then
      return "[]"
    end
    local parts
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #t do
        local v = t[_index_0]
        _accum_0[_len_0] = encodeValue(v, indent, level + 1)
        _len_0 = _len_0 + 1
      end
      parts = _accum_0
    end
    return "[" .. pad .. table.concat(parts, sep) .. endPad .. "]"
  end
  local keys
  do
    local _accum_0 = { }
    local _len_0 = 1
    for k in pairs(t) do
      _accum_0[_len_0] = tostring(k)
      _len_0 = _len_0 + 1
    end
    keys = _accum_0
  end
  if #keys == 0 then
    return "{}"
  end
  table.sort(keys)
  local parts
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #keys do
      local k = keys[_index_0]
      _accum_0[_len_0] = ('"%s":%s%s'):format(escape(k), (indent and " " or ""), encodeValue(t[k], indent, level + 1))
      _len_0 = _len_0 + 1
    end
    parts = _accum_0
  end
  return "{" .. pad .. table.concat(parts, sep) .. endPad .. "}"
end
encodeValue = function(v, indent, level)
  local t = type(v)
  if v == nil then
    return "null"
  end
  if t == "boolean" then
    return tostring(v)
  end
  if t == "number" then
    return number(v)
  end
  if t == "string" then
    return '"' .. escape(v) .. '"'
  end
  if t == "table" then
    return encodeTable(v, indent, level)
  end
  return error("cannot encode " .. t .. " in JSON")
end
M.encode = function(value, pretty)
  return encodeValue(value, (pretty and "  " or nil), 0)
end
local parseValue
local skipSpace
skipSpace = function(s, i)
  while i <= #s and s:sub(i, i):match("%s") do
    i = i + 1
  end
  return i
end
local parseString
parseString = function(s, i)
  if not (s:sub(i, i) == '"') then
    error("expected string at " .. tostring(i))
  end
  i = i + 1
  local out = { }
  while i <= #s do
    local c = s:sub(i, i)
    if c == '"' then
      return table.concat(out), i + 1
    elseif c == "\\" then
      local esc = s:sub(i + 1, i + 1)
      local _exp_0 = esc
      if "n" == _exp_0 then
        out[#out + 1] = "\n"
      elseif "t" == _exp_0 then
        out[#out + 1] = "\t"
      elseif "r" == _exp_0 then
        out[#out + 1] = "\r"
      elseif "b" == _exp_0 then
        out[#out + 1] = "\b"
      elseif "f" == _exp_0 then
        out[#out + 1] = "\f"
      elseif "u" == _exp_0 then
        out[#out + 1] = string.char(tonumber(s:sub(i + 2, i + 5), 16) % 256)
        i = i + 4
      else
        out[#out + 1] = esc
      end
      i = i + 2
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return error("unterminated string")
end
parseValue = function(s, i)
  i = skipSpace(s, i)
  local c = s:sub(i, i)
  local _exp_0 = c
  if '"' == _exp_0 then
    return parseString(s, i)
  elseif "{" == _exp_0 then
    local obj = { }
    i = skipSpace(s, i + 1)
    if s:sub(i, i) == "}" then
      return obj, i + 1
    end
    while true do
      local key, next_i = parseString(s, skipSpace(s, i))
      i = skipSpace(s, next_i)
      if not (s:sub(i, i) == ":") then
        error("expected : at " .. tostring(i))
      end
      local value, after = parseValue(s, i + 1)
      obj[key] = value
      i = skipSpace(s, after)
      if s:sub(i, i) == "," then
        i = i + 1
      else
        if not (s:sub(i, i) == "}") then
          error("expected , or } at " .. tostring(i))
        end
        return obj, i + 1
      end
    end
  elseif "[" == _exp_0 then
    local arr = { }
    i = skipSpace(s, i + 1)
    if s:sub(i, i) == "]" then
      return arr, i + 1
    end
    while true do
      local value, after = parseValue(s, i)
      arr[#arr + 1] = value
      i = skipSpace(s, after)
      if s:sub(i, i) == "," then
        i = i + 1
      else
        if not (s:sub(i, i) == "]") then
          error("expected , or ] at " .. tostring(i))
        end
        return arr, i + 1
      end
    end
  else
    if s:sub(i, i + 3) == "true" then
      return true, i + 4
    end
    if s:sub(i, i + 4) == "false" then
      return false, i + 5
    end
    if s:sub(i, i + 3) == "null" then
      return nil, i + 4
    end
    local numText = s:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", i)
    if not (numText and numText ~= "") then
      error(("unexpected character %q at %d"):format(c, i))
    end
    return tonumber(numText), i + #numText
  end
end
M.decode = function(text)
  if not (type(text) == "string") then
    return nil, "not a string"
  end
  local ok, value = pcall(function()
    return (parseValue(text, 1))
  end)
  if not (ok) then
    return nil, tostring(value)
  end
  return value
end
M.decodeFile = function(path)
  local fh = io.open(path, "r")
  if not (fh) then
    return nil, ("cannot open %s"):format(path)
  end
  local text = fh:read("*a")
  fh:close()
  return M.decode(text)
end
return M
