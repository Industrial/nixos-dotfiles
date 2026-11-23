local MAJOR, MINOR = "idLibSpellTable-1.0", 1
local LibStub = _G.LibStub
if not (LibStub) then
  error(tostring(MAJOR) .. " requires LibStub")
end
local core = LibStub:GetLibrary("idLibSetTable-1.0", true)
if not (core) then
  error(tostring(MAJOR) .. " requires idLibSetTable-1.0")
end
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not (lib) then
  return 
end
core.Install(lib, {
  major = MAJOR,
  member = "SpellInSet"
})
return lib
