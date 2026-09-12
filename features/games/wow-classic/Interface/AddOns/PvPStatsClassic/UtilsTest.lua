-- UtilsTest.lua
-- Unit tests for utility functions in Utils.lua
--
-- Run outside WoW:  lua UtilsTest.lua Utils.lua
-- Run inside WoW:   /run PSC_RunUtilsTests()

-- ---------------------------------------------------------------------------
-- Standalone bootstrap
-- When running outside WoW, load the real Utils.lua from the path supplied as
-- the first command-line argument (e.g. lua UtilsTest.lua Utils.lua).
-- A built-in shim is used as fallback so the tests still run without it.
-- Inside WoW this whole block is skipped (arg is nil) and the real
-- PSC_IsVersionAtLeast defined by Utils.lua is already available.
-- ---------------------------------------------------------------------------
if arg then
    local utilsPath = arg[1]
    if utilsPath then
        local ok, err = pcall(dofile, utilsPath)
        if not ok then
            print("Warning: could not load '" .. utilsPath .. "': " .. tostring(err))
            print("Falling back to built-in shim.")
        end
    end
end

if not PSC_IsVersionAtLeast then
    error("PSC_IsVersionAtLeast is not defined. Pass Utils.lua as an argument:\n  lua UtilsTest.lua Utils.lua")
end

-- ---------------------------------------------------------------------------
-- Minimal test runner
-- ---------------------------------------------------------------------------
local _passed = 0
local _failed = 0
local _results = {}

local function _assert(description, expected, actual)
    if expected == actual then
        _passed = _passed + 1
        table.insert(_results, "  PASS  " .. description)
    else
        _failed = _failed + 1
        table.insert(_results, "  FAIL  " .. description ..
            "\n         expected=" .. tostring(expected) ..
            "  got=" .. tostring(actual))
    end
end

local function _section(name)
    table.insert(_results, "\n[" .. name .. "]")
end

-- ---------------------------------------------------------------------------
-- Tests for PSC_IsVersionAtLeast(versionStr, minVersion)
-- Returns true when versionStr >= minVersion, false otherwise.
-- lua UtilsTest.lua
-- /run PSC_RunUtilsTests() ingame to execute these tests.
-- ---------------------------------------------------------------------------
local function RunVersionTests()
    _section("Major version comparisons")
    _assert("5.0.0 >= 4.2.1  -> true",  true,  PSC_IsVersionAtLeast("5.0.0",  "4.2.1"))
    _assert("4.0.0 >= 4.2.1  -> false", false, PSC_IsVersionAtLeast("4.0.0",  "4.2.1"))
    _assert("3.9.9 >= 4.0.0  -> false", false, PSC_IsVersionAtLeast("3.9.9",  "4.0.0"))
    _assert("10.0.0 >= 9.9.9 -> true",  true,  PSC_IsVersionAtLeast("10.0.0", "9.9.9"))

    _section("Minor version comparisons (same major)")
    _assert("4.3.0  >= 4.2.1 -> true",  true,  PSC_IsVersionAtLeast("4.3.0",  "4.2.1"))
    _assert("4.3    >= 4.2.1 -> true",  true,  PSC_IsVersionAtLeast("4.3",    "4.2.1"))
    _assert("4.2.1  >= 4.3.0 -> false", false, PSC_IsVersionAtLeast("4.2.1",  "4.3.0"))
    _assert("4.10.0 >= 4.9.0 -> true",  true,  PSC_IsVersionAtLeast("4.10.0", "4.9.0"))
    _assert("4.9.0  >= 4.10  -> false", false, PSC_IsVersionAtLeast("4.9.0",  "4.10"))

    _section("Patch version comparisons (same major.minor)")
    _assert("4.2.1  >= 4.2.1 -> true",  true,  PSC_IsVersionAtLeast("4.2.1",  "4.2.1"))
    _assert("4.2.2  >= 4.2.1 -> true",  true,  PSC_IsVersionAtLeast("4.2.2",  "4.2.1"))
    _assert("4.2.0  >= 4.2.1 -> false", false, PSC_IsVersionAtLeast("4.2.0",  "4.2.1"))
    _assert("4.2.10 >= 4.2.9 -> true",  true,  PSC_IsVersionAtLeast("4.2.10", "4.2.9"))
    _assert("4.2.9  >= 4.2.10-> false", false, PSC_IsVersionAtLeast("4.2.9",  "4.2.10"))

    _section("Missing patch component (treated as 0)")
    _assert("4.2    >= 4.2.0 -> true",  true,  PSC_IsVersionAtLeast("4.2",    "4.2.0"))
    _assert("4.2    >= 4.2.1 -> false", false, PSC_IsVersionAtLeast("4.2",    "4.2.1"))
    _assert("4.2.0  >= 4.2   -> true",  true,  PSC_IsVersionAtLeast("4.2.0",  "4.2"))
    _assert("4.3    >= 4.2   -> true",  true,  PSC_IsVersionAtLeast("4.3",    "4.2"))

    _section("Exact equality")
    _assert("1.0.0  >= 1.0.0 -> true",  true,  PSC_IsVersionAtLeast("1.0.0",  "1.0.0"))
    _assert("0.0.0  >= 0.0.0 -> true",  true,  PSC_IsVersionAtLeast("0.0.0",  "0.0.0"))

    _section("nil / invalid inputs")
    _assert("nil, '4.2.1'   -> false", false, PSC_IsVersionAtLeast(nil,     "4.2.1"))
    _assert("'4.2.1', nil   -> false", false, PSC_IsVersionAtLeast("4.2.1", nil))
    _assert("nil, nil       -> false", false, PSC_IsVersionAtLeast(nil,     nil))

    _section("Real-world addon version scenarios")
    _assert("4.3   >= 4.2.1 (next release check) -> true",  true,  PSC_IsVersionAtLeast("4.3",   "4.2.1"))
    _assert("4.2.1 >= 4.2.1 (exact min)          -> true",  true,  PSC_IsVersionAtLeast("4.2.1", "4.2.1"))
    _assert("4.2   >= 4.2.1 (older client)       -> false", false, PSC_IsVersionAtLeast("4.2",   "4.2.1"))
    _assert("4.1.9 >= 4.2.1 (much older client)  -> false", false, PSC_IsVersionAtLeast("4.1.9", "4.2.1"))
    _assert("5.0   >= 4.2.1 (future version)     -> true",  true,  PSC_IsVersionAtLeast("5.0",   "4.2.1"))
end

-- ---------------------------------------------------------------------------
-- Public entry point (callable from /run in WoW)
-- ---------------------------------------------------------------------------
function PSC_RunUtilsTests()
    _passed  = 0
    _failed  = 0
    _results = {}

    RunVersionTests()

    -- Print results
    local output = "\n===== PSC Utils Tests =====" .. table.concat(_results, "\n")
    output = output .. string.format("\n\n  %d passed,  %d failed\n", _passed, _failed)
    output = output .. "==========================="

    -- Works both in WoW (print -> DEFAULT_CHAT_FRAME) and standalone Lua
    print(output)

    return _failed == 0
end

-- When run as a standalone script, execute immediately.
-- Pass Utils.lua as the first argument to use the real implementation:
--   lua UtilsTest.lua Utils.lua
-- Inside WoW this block is skipped because arg is nil.
if arg then
    local ok = PSC_RunUtilsTests()
    os.exit(ok and 0 or 1)
end
