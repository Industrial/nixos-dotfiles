local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not (ns and ns.Calculator) then return end

local Calculator = ns.Calculator
local Utils = ns.Utils
local L = ns.L

local pairs = Utils.pairs
local sfind, slower = Utils.sfind, Utils.slower
local tconcat = Utils.tconcat
local sformat = Utils.sformat



local CALC_NAME = L["UITREE_CALCULATOR"]

Calculator._calculator = {
    PATH = { CALC_NAME },
    LAUNCHER = {
        name = CALC_NAME,
        nameLower = "calculator",
        category = CALC_NAME,
        path = { CALC_NAME },
        noPin = true,


        noLearn = true,
        calculatorLauncher = true,
        keywords = { "calculator", "calc", "math" },
    },
    FUNCTIONS = {
        abs = true, acos = true, acosd = true, asin = true, asind = true,
        atan = true, atan2 = true, atand = true, ceil = true, cos = true,
        cosd = true, cosh = true, cot = true, cotd = true, csc = true,
        cscd = true, exp = true, factorial = true, floor = true, ln = true,
        log = true, max = true, min = true, mod = true, pow = true, round = true,
        sec = true, secd = true, sin = true, sind = true, sinh = true,
        sqrt = true, tan = true, tand = true, tanh = true,
    },
}

function Calculator._calculator.IsFinite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

function Calculator._calculator.ToRadians(value)
    return value * math.pi / 180
end

function Calculator._calculator.ToDegrees(value)
    return value * 180 / math.pi
end

function Calculator._calculator.Round(value)
    if value >= 0 then return math.floor(value + 0.5) end
    return math.ceil(value - 0.5)
end

function Calculator._calculator.Factorial(value)
    if value < 0 or value ~= math.floor(value) or value > 170 then return nil end
    local result = 1
    for i = 2, value do result = result * i end
    return result
end

function Calculator._calculator.Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 then
        return math.atan(y / x) - math.pi
    elseif y > 0 then
        return math.pi / 2
    elseif y < 0 then
        return -math.pi / 2
    end
    return nil
end

function Calculator._calculator.Sinh(value)
    if math.sinh then return math.sinh(value) end
    return (math.exp(value) - math.exp(-value)) / 2
end

function Calculator._calculator.Cosh(value)
    if math.cosh then return math.cosh(value) end
    return (math.exp(value) + math.exp(-value)) / 2
end

function Calculator._calculator.Tanh(value)
    if math.tanh then return math.tanh(value) end
    local pos = math.exp(value)
    local neg = math.exp(-value)
    return (pos - neg) / (pos + neg)
end

function Calculator._calculator.ApplyFunction(name, args)
    local argc = #args
    local a, b = args[1], args[2]
    local c = Calculator._calculator

    if name == "abs" then
        if argc ~= 1 then return nil end
        return math.abs(a)
    elseif name == "sqrt" then
        if argc ~= 1 or a < 0 then return nil end
        return math.sqrt(a)
    elseif name == "floor" then
        if argc ~= 1 then return nil end
        return math.floor(a)
    elseif name == "ceil" then
        if argc ~= 1 then return nil end
        return math.ceil(a)
    elseif name == "round" then
        if argc ~= 1 then return nil end
        return c.Round(a)
    elseif name == "ln" then
        if argc ~= 1 or a <= 0 then return nil end
        return math.log(a)
    elseif name == "log" then
        if argc == 1 then
            if a <= 0 then return nil end
            return math.log(a) / math.log(10)
        elseif argc == 2 then
            if a <= 0 or a == 1 or b <= 0 then return nil end
            return math.log(b) / math.log(a)
        end
        return nil
    elseif name == "exp" then
        if argc ~= 1 then return nil end
        return math.exp(a)
    elseif name == "pow" then
        if argc ~= 2 then return nil end
        return math.pow(a, b)
    elseif name == "mod" then
        if argc ~= 2 or b == 0 then return nil end
        return math.fmod(a, b)
    elseif name == "factorial" then
        if argc ~= 1 then return nil end
        return c.Factorial(a)
    elseif name == "min" then
        if argc < 1 then return nil end
        local result = a
        for i = 2, argc do if args[i] < result then result = args[i] end end
        return result
    elseif name == "max" then
        if argc < 1 then return nil end
        local result = a
        for i = 2, argc do if args[i] > result then result = args[i] end end
        return result
    elseif name == "sin" then
        if argc ~= 1 then return nil end
        return math.sin(a)
    elseif name == "cos" then
        if argc ~= 1 then return nil end
        return math.cos(a)
    elseif name == "tan" then
        if argc ~= 1 then return nil end
        return math.tan(a)
    elseif name == "sind" then
        if argc ~= 1 then return nil end
        return math.sin(c.ToRadians(a))
    elseif name == "cosd" then
        if argc ~= 1 then return nil end
        return math.cos(c.ToRadians(a))
    elseif name == "tand" then
        if argc ~= 1 then return nil end
        return math.tan(c.ToRadians(a))
    elseif name == "asin" then
        if argc ~= 1 or a < -1 or a > 1 then return nil end
        return math.asin(a)
    elseif name == "acos" then
        if argc ~= 1 or a < -1 or a > 1 then return nil end
        return math.acos(a)
    elseif name == "atan" then
        if argc == 1 then return math.atan(a) end
        if argc == 2 then return c.Atan2(a, b) end
        return nil
    elseif name == "asind" then
        if argc ~= 1 or a < -1 or a > 1 then return nil end
        return c.ToDegrees(math.asin(a))
    elseif name == "acosd" then
        if argc ~= 1 or a < -1 or a > 1 then return nil end
        return c.ToDegrees(math.acos(a))
    elseif name == "atand" then
        if argc == 1 then return c.ToDegrees(math.atan(a)) end
        if argc == 2 then
            local v = c.Atan2(a, b)
            return v and c.ToDegrees(v) or nil
        end
        return nil
    elseif name == "atan2" then
        if argc ~= 2 then return nil end
        return c.Atan2(a, b)
    elseif name == "sinh" then
        if argc ~= 1 then return nil end
        return c.Sinh(a)
    elseif name == "cosh" then
        if argc ~= 1 then return nil end
        return c.Cosh(a)
    elseif name == "tanh" then
        if argc ~= 1 then return nil end
        return c.Tanh(a)
    elseif name == "sec" then
        if argc ~= 1 then return nil end
        local v = math.cos(a)
        if v == 0 then return nil end
        return 1 / v
    elseif name == "csc" then
        if argc ~= 1 then return nil end
        local v = math.sin(a)
        if v == 0 then return nil end
        return 1 / v
    elseif name == "cot" then
        if argc ~= 1 then return nil end
        local v = math.tan(a)
        if v == 0 then return nil end
        return 1 / v
    elseif name == "secd" then
        if argc ~= 1 then return nil end
        local v = math.cos(c.ToRadians(a))
        if v == 0 then return nil end
        return 1 / v
    elseif name == "cscd" then
        if argc ~= 1 then return nil end
        local v = math.sin(c.ToRadians(a))
        if v == 0 then return nil end
        return 1 / v
    elseif name == "cotd" then
        if argc ~= 1 then return nil end
        local v = math.tan(c.ToRadians(a))
        if v == 0 then return nil end
        return 1 / v
    end
    return nil
end






local MONEY_WORD_UNITS = {
    gold = { 10000, 3 }, silver = { 100, 2 }, copper = { 1, 1 },
    g = { 10000, 3 }, s = { 100, 2 }, c = { 1, 1 },
}

local function MatchMoneyUnit(text, i)
    local run = text:match("^%a+", i)
    if not run then return nil end
    local unit = MONEY_WORD_UNITS[slower(run)]
    if not unit then return nil end
    return unit[1], unit[2], i + #run
end

function Calculator._calculator.LooksLikeInput(raw)
    local text = raw and strtrim(raw) or ""
    if text == "" or #text > 96 then return false end

    local lower = slower(text)
    if lower == "pi" or lower == "tau" then return true end



    if sfind(lower, "%d[gsc]%f[%A]") or sfind(lower, "%dgold%f[%A]")
        or sfind(lower, "%dsilver%f[%A]") or sfind(lower, "%dcopper%f[%A]") then
        return true
    end

    local hasNumber = sfind(lower, "%d") ~= nil
    local hasConstant = sfind(lower, "%f[%a]pi%f[%A]") ~= nil
        or sfind(lower, "%f[%a]tau%f[%A]") ~= nil
        or sfind(lower, "%f[%a]e%f[%A]") ~= nil
    if not hasNumber and not hasConstant then return false end

    if sfind(lower, "[%+%-%*/%^%%%!%(%)%,]") then return true end
    if hasNumber and (sfind(lower, "%d%s*%a") or sfind(lower, "%d%s*%(")
        or sfind(lower, "%)%s*%d") or sfind(lower, "%)%s*%a")
        or sfind(lower, "%)%s*%(")) then
        return true
    end

    for name in pairs(Calculator._calculator.FUNCTIONS) do
        if sfind(lower, "%f[%a]" .. name .. "%f[%A]") then return true end
    end
    return false
end

function Calculator._calculator.Tokenize(text)
    local tokens = {}
    local i, n = 1, #text

    while i <= n do
        local ch = text:sub(i, i)
        if ch:match("%s") then
            i = i + 1
        elseif ch == "," then
            local prev = i > 1 and text:sub(i - 1, i - 1) or ""
            local nextCh = i < n and text:sub(i + 1, i + 1) or ""
            if prev:match("%d") and nextCh:match("%d") then
                i = i + 1
            else
                tokens[#tokens + 1] = { type = "op", value = "," }
                i = i + 1
            end
        elseif ch:match("%d") or ch == "." then
            local parts = {}
            local sawDigit, sawDot = false, false
            while i <= n do
                ch = text:sub(i, i)
                if ch:match("%d") then
                    sawDigit = true
                    parts[#parts + 1] = ch
                    i = i + 1
                elseif ch == "." and not sawDot then
                    sawDot = true
                    parts[#parts + 1] = ch
                    i = i + 1
                elseif ch == "," then
                    local nextCh = i < n and text:sub(i + 1, i + 1) or ""
                    if nextCh:match("%d") then i = i + 1 else break end
                else
                    break
                end
            end
            if not sawDigit then return nil end

            if i <= n and text:sub(i, i):lower() == "e" then
                local expStart = i
                local expParts = { "e" }
                i = i + 1
                ch = i <= n and text:sub(i, i) or ""
                if ch == "+" or ch == "-" then
                    expParts[#expParts + 1] = ch
                    i = i + 1
                end
                local expDigits = false
                while i <= n do
                    ch = text:sub(i, i)
                    if not ch:match("%d") then break end
                    expDigits = true
                    expParts[#expParts + 1] = ch
                    i = i + 1
                end
                if expDigits then
                    for pi = 1, #expParts do parts[#parts + 1] = expParts[pi] end
                else
                    i = expStart
                end
            end

            local value = tonumber(tconcat(parts))
            if not value then return nil end







            local unitMult, unitRank, afterUnit = MatchMoneyUnit(text, i)
            if unitMult then
                local total = value * unitMult
                local lastRank = unitRank
                i = afterUnit
                while lastRank > 1 do
                    local j = i
                    while j <= n and text:sub(j, j):match("%s") do j = j + 1 end
                    local numStr = text:match("^%d+%.?%d*", j)
                    if not numStr then break end
                    local segMult, segRank, segAfter = MatchMoneyUnit(text, j + #numStr)
                    if not segMult or segRank >= lastRank then break end
                    total = total + tonumber(numStr) * segMult
                    lastRank = segRank
                    i = segAfter
                end
                tokens.money = true
                tokens[#tokens + 1] = { type = "number", value = total }
            else
                tokens[#tokens + 1] = { type = "number", value = value }
            end
        elseif ch:match("%a") then
            local start = i
            repeat
                i = i + 1
                ch = i <= n and text:sub(i, i) or ""
            until ch == "" or not ch:match("[%a_]")
            local ident = slower(text:sub(start, i - 1))
            if ident == "atan" and i <= n and text:sub(i, i) == "2" then
                ident = "atan2"
                i = i + 1
            end
            tokens[#tokens + 1] = { type = "ident", value = ident }
        elseif ch == "+" or ch == "-" or ch == "*" or ch == "/"
            or ch == "^" or ch == "%" or ch == "!" or ch == "(" or ch == ")" then
            tokens[#tokens + 1] = { type = "op", value = ch }
            i = i + 1
        else
            return nil
        end
    end

    tokens[#tokens + 1] = { type = "eof" }
    return tokens
end

function Calculator._calculator.Parse(tokens)
    local pos = 1
    local c = Calculator._calculator
    local parseExpression, parseAdd, parseMul, parseUnary, parsePower, parsePostfix, parsePrimary

    local function fail()
        error("calculator parse failed", 0)
    end

    local function current()
        return tokens[pos]
    end

    local function acceptOp(op)
        local tok = current()
        if tok and tok.type == "op" and tok.value == op then
            pos = pos + 1
            return true
        end
        return false
    end

    local function isImplicitStart(tok)
        if not tok then return false end
        if tok.type == "number" then return true end
        if tok.type == "op" and tok.value == "(" then return true end
        if tok.type == "ident" then
            return tok.value ~= "deg" and tok.value ~= "degree" and tok.value ~= "degrees"
                and tok.value ~= "rad" and tok.value ~= "radian" and tok.value ~= "radians"
                and tok.value ~= "mod" and tok.value ~= "x" and tok.value ~= "times"
        end
        return false
    end

    parseExpression = function()
        return parseAdd()
    end

    parseAdd = function()
        local left = parseMul()
        while true do
            if acceptOp("+") then
                left = left + parseMul()
            elseif acceptOp("-") then
                left = left - parseMul()
            else
                return left
            end
        end
    end

    parseMul = function()
        local left = parseUnary()
        while true do
            local tok = current()
            if acceptOp("*") then
                left = left * parseUnary()
            elseif acceptOp("/") then
                local right = parseUnary()
                if right == 0 then fail() end
                left = left / right
            elseif tok and tok.type == "ident"
                and (tok.value == "mod" or tok.value == "x" or tok.value == "times") then
                pos = pos + 1
                local right = parseUnary()
                if tok.value == "mod" then
                    if right == 0 then fail() end
                    left = math.fmod(left, right)
                else
                    left = left * right
                end
            elseif isImplicitStart(tok) then
                left = left * parseUnary()
            else
                return left
            end
        end
    end

    parseUnary = function()
        if acceptOp("+") then return parseUnary() end
        if acceptOp("-") then return -parseUnary() end

        local tok = current()
        if tok and tok.type == "ident" and c.FUNCTIONS[tok.value] then
            local name = tok.value
            pos = pos + 1
            local args = {}
            if acceptOp("(") then
                if not acceptOp(")") then
                    repeat
                        args[#args + 1] = parseExpression()
                    until not acceptOp(",")
                    if not acceptOp(")") then fail() end
                end
            else
                args[1] = parseUnary()
            end
            local value = c.ApplyFunction(name, args)
            if value == nil or not c.IsFinite(value) then fail() end
            return value
        end

        return parsePower()
    end

    parsePower = function()
        local left = parsePostfix()
        if acceptOp("^") then
            left = math.pow(left, parseUnary())
            if not c.IsFinite(left) then fail() end
        end
        return left
    end

    parsePostfix = function()
        local value = parsePrimary()
        while true do
            local tok = current()
            if acceptOp("!") then
                value = c.Factorial(value)
                if value == nil then fail() end
            elseif acceptOp("%") then
                value = value / 100
            elseif tok and tok.type == "ident"
                and (tok.value == "deg" or tok.value == "degree" or tok.value == "degrees") then
                pos = pos + 1
                value = c.ToRadians(value)
            elseif tok and tok.type == "ident"
                and (tok.value == "rad" or tok.value == "radian" or tok.value == "radians") then
                pos = pos + 1
            else
                return value
            end
            if not c.IsFinite(value) then fail() end
        end
    end

    parsePrimary = function()
        local tok = current()
        if not tok then fail() end
        if tok.type == "number" then
            pos = pos + 1
            return tok.value
        elseif tok.type == "ident" then
            pos = pos + 1
            if tok.value == "pi" then
                return math.pi
            elseif tok.value == "tau" then
                return math.pi * 2
            elseif tok.value == "e" then
                return math.exp(1)
            end
            fail()
        elseif acceptOp("(") then
            local value = parseExpression()
            if not acceptOp(")") then fail() end
            return value
        end
        fail()
    end

    local value = parseExpression()
    local tok = current()
    if not tok or tok.type ~= "eof" then fail() end
    if not c.IsFinite(value) then fail() end
    return value
end

function Calculator._calculator.Format(value)
    if math.abs(value) < 0.000000000001 then value = 0 end
    local nearest = Calculator._calculator.Round(value)
    if math.abs(value - nearest) < 0.0000000001 then
        return tostring(nearest)
    end
    return sformat("%.12g", value)
end







local COIN_ICONS = {
    "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t",
    "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
    "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t",
}



function Calculator._calculator.FormatMoney(value, icons)
    local c = Calculator._calculator
    local sign = value < 0 and "-" or ""
    local copper = c.Round(math.abs(value))
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperPart = copper % 100
    local gSym = icons and COIN_ICONS[3] or _G["GOLD_AMOUNT_SYMBOL"] or "g"
    local sSym = icons and COIN_ICONS[2] or _G["SILVER_AMOUNT_SYMBOL"] or "s"
    local cSym = icons and COIN_ICONS[1] or _G["COPPER_AMOUNT_SYMBOL"] or "c"
    local parts = {}
    if gold > 0 then



        local sep = _G["LARGE_NUMBER_SEPERATOR"] or ","
        local goldStr = tostring(gold)
        local grouped = goldStr:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
        grouped = grouped:gsub("^" .. sep:gsub("%p", "%%%0"), "")
        parts[#parts + 1] = grouped .. gSym
    end
    if silver > 0 then parts[#parts + 1] = silver .. sSym end
    if copperPart > 0 or #parts == 0 then parts[#parts + 1] = copperPart .. cSym end
    return sign .. tconcat(parts, " ")
end

function Calculator:EvaluateCalculatorExpression(raw)
    local c = Calculator._calculator
    if not c.LooksLikeInput(raw) then return nil end
    local expression = strtrim(raw)
    local tokens = c.Tokenize(expression)
    if not tokens then return nil end

    local ok, value = pcall(c.Parse, tokens)
    if not ok or not c.IsFinite(value) then return nil end

    local result = tokens.money and c.FormatMoney(value) or c.Format(value)


    local resultShown, expressionShown
    if tokens.money then
        resultShown = c.FormatMoney(value, true)
        expressionShown = expression:gsub("(%d)(%a+)", function(digit, run)
            local unit = MONEY_WORD_UNITS[slower(run)]
            if unit then return digit .. COIN_ICONS[unit[2]] end
        end)
    end
    return {
        name = expression,
        nameLower = slower(expression),
        category = "Calculator",
        path = c.PATH,
        noPin = true,


        noLearn = true,
        calculatorExpression = expression,
        calculatorResult = result,
        calculatorValue = value,
        calculatorMoney = tokens.money or nil,
        calculatorResultShown = resultShown,
        calculatorExpressionShown = expressionShown,
    }
end

function Calculator:GetCalculatorLauncherMatch(raw)
    raw = slower(strtrim(raw or ""))
    if raw == "" then return nil end
    local launcher = Calculator._calculator.LAUNCHER
    if sfind("calculator", raw, 1, true) == 1
       or sfind("calc", raw, 1, true) == 1
       or raw == "math" then
        return launcher
    end
    return nil
end
