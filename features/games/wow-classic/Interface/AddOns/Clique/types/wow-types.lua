---@meta

---@declare-global
---@type fun(t: table): nil
table.wipe = nil

---@declare-global
---@type fun(s: string, t: string): ...
string.split = nil

---WoW's xpcall supports passing arguments to the function (Lua 5.2+ style)
---@param f function
---@param msgh function
---@param ... any
---@return boolean success
---@return any ...
function xpcall(f, msgh, ...) end
