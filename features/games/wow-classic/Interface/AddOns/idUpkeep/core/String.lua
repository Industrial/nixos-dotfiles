local String
do
  local _class_0
  local _base_0 = { }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "String"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.trim = function(s)
    return (s or ""):match("^%s*(.-)%s*$" or "")
  end
  self.match_path_pattern = function(path, pattern)
    if pattern == path then
      return true
    end
    local escaped = pattern:gsub("%.", "%%.")
    escaped = escaped:gsub("%*", "[^%%.]*")
    escaped = "^" .. escaped .. "$"
    return (path:match(escaped)) ~= nil
  end
  self.tokenize = function(input)
    local tokens, current, in_quotes, quote_char = { }, "", false, nil
    for i = 1, #input do
      local char = input:sub(i, i)
      if in_quotes then
        if char == quote_char then
          in_quotes, quote_char = false, nil
        else
          current = current .. char
        end
      else
        if char == '"' or char == "'" then
          in_quotes, quote_char = true, char
        elseif char == " " or char == "\t" then
          if #current > 0 then
            table.insert(tokens, current)
            current = ""
          end
        else
          current = current .. char
        end
      end
    end
    if #current > 0 then
      table.insert(tokens, current)
    end
    return tokens
  end
  String = _class_0
end
_G.idUpkeep_String = String
return String
