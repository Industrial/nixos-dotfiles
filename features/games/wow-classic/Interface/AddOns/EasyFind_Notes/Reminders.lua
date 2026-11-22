local _, notesNS = ...
local ns = EasyFind and EasyFind._ns
if not (ns and notesNS.UI) then return end

-- Reminders: a note holds any number, each a moment (at) and how it comes
-- round again (rep: day, week, month, year, or chosen weekdays). A due one
-- says so in chat; a repeating one moves on to its next time.
local R = {}
notesNS.Reminders = R

local L, Utils = ns.L, ns.Utils
local date, time, tremove, tsort = date, time, table.remove, table.sort
local sformat, smatch, mmin = string.format, string.match, math.min

local WEEKDAYS = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }
local MONTHS = { "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER",
                 "OCTOBER", "NOVEMBER", "DECEMBER" }
local function Weekday(w) return _G["WEEKDAY_" .. WEEKDAYS[w]] or WEEKDAYS[w]:sub(1, 1) .. WEEKDAYS[w]:sub(2):lower() end
local function Month(m) return _G["MONTH_" .. MONTHS[m]] or MONTHS[m]:sub(1, 1) .. MONTHS[m]:sub(2):lower() end
R.Weekday = Weekday

-- The repeats, in the menu's order.
R.REPEATS = {
    { value = nil, label = "NOTES_REPEAT_ONCE" },
    { value = "day", label = "NOTES_REPEAT_DAY" },
    { value = "week", label = "NOTES_REPEAT_WEEK" },
    { value = "month", label = "NOTES_REPEAT_MONTH" },
    { value = "year", label = "NOTES_REPEAT_YEAR" },
    { value = "days", label = "NOTES_REPEAT_DAYS" },
}

-- A note's reminders, soonest first; an older single one folded in.
function R.List(note)
    local list = note.reminders
    if type(list) ~= "table" then
        list = {}
        note.reminders = list
    end
    if note.reminderAt then
        list[#list + 1] = { at = note.reminderAt }
        note.reminderAt = nil
    end
    return list
end

local function Soonest(a, b) return a.at < b.at end

function R.Add(note, at, rep, days)
    local list = R.List(note)
    list[#list + 1] = { at = at, rep = rep, days = days, day = date("*t", at).day }
    tsort(list, Soonest)
    note.updated = time()
end

function R.Remove(note, r)
    local list = R.List(note)
    for i = #list, 1, -1 do
        if list[i] == r then tremove(list, i) end
    end
    note.updated = time()
end

local function DaysIn(year, month)
    return date("*t", time({ year = year, month = month + 1, day = 0, hour = 12 })).day
end

-- The next time after `now` a repeating reminder comes round at its own
-- time of day; a monthly one on its own day, or its month's last when the
-- month is shorter.
function R.Next(r, now)
    local t = date("*t", r.at)
    t.isdst = nil
    for _ = 1, 3700 do
        if r.rep == "day" or r.rep == "days" then
            t.day = t.day + 1
        elseif r.rep == "week" then
            t.day = t.day + 7
        elseif r.rep == "month" then
            t.month = t.month + 1
            if t.month > 12 then t.month, t.year = 1, t.year + 1 end
            t.day = mmin(r.day or t.day, DaysIn(t.year, t.month))
        elseif r.rep == "year" then
            t.year = t.year + 1
            t.day = mmin(r.day or t.day, DaysIn(t.year, t.month))
        else
            return nil
        end
        local at = time(t)
        t = date("*t", at)
        t.isdst = nil
        if at > now and (r.rep ~= "days" or (r.days and r.days[t.wday])) then return at end
    end
end

-- Due reminders: each said in chat once, a repeating one moved on.
function R.CheckDue(notes, now)
    for i = 1, #notes do
        local note = notes[i]
        local list = (note.reminders or note.reminderAt) and R.List(note)
        if list then
            for j = #list, 1, -1 do
                local r = list[j]
                if r.at <= now then
                    EasyFind:Print(sformat(L["NOTES_REMINDER_FMT"], notesNS.NoteTitle(note)))
                    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN) end
                    r.at = R.Next(r, now)
                    if not r.at then tremove(list, j) end
                end
            end
            tsort(list, Soonest)
        end
    end
end

-- The game's clock style: 24-hour, or 12-hour with its AM and PM.
function R.Clock(hour, min)
    if GetCVarBool and GetCVarBool("timeMgrUseMilitaryTime") then return sformat("%02d:%02d", hour, min) end
    local h = hour % 12
    return sformat("%d:%02d %s", h == 0 and 12 or h, min,
        hour < 12 and (_G.TIMEMANAGER_AM or "AM") or (_G.TIMEMANAGER_PM or "PM"))
end

function R.When(at, now)
    local t, n = date("*t", at), date("*t", now)
    local clock = R.Clock(t.hour, t.min)
    local tomorrow = date("*t", now + 86400)
    if t.year == n.year and t.yday == n.yday then return sformat(L["NOTES_REMIND_TODAY_FMT"], clock) end
    if t.year == tomorrow.year and t.yday == tomorrow.yday then return sformat(L["NOTES_REMIND_TOMORROW_FMT"], clock) end
    local day = sformat(L["NOTES_REMIND_DATE_FMT"], Weekday(t.wday), t.day, Month(t.month))
    if t.year ~= n.year then day = day .. " " .. t.year end
    return day .. ", " .. clock
end

function R.RepeatLabel(rep, days)
    if rep == "days" then
        local names = {}
        for w = 1, 7 do
            if days and days[w] then names[#names + 1] = Weekday(w) end
        end
        return #names > 0 and table.concat(names, ", ") or L["NOTES_REPEAT_DAYS"]
    end
    for _, o in ipairs(R.REPEATS) do
        if o.value == rep then return L[o.label] end
    end
end

function R.Label(r, now)
    local when = R.When(r.at, now)
    if not r.rep then return when end
    return sformat(L["NOTES_REMIND_REPEATS_FMT"], when, R.RepeatLabel(r.rep, r.days))
end

-- The Remind me flyout: the note's reminders, each with its X, then the
-- quick picks, a custom time, and Clear all when there are several.
function R.MenuRows(note)
    local rows, now = {}, time()
    local list = R.List(note)
    for _, r in ipairs(list) do
        rows[#rows + 1] = { text = R.Label(r, now), remove = function() R.Remove(note, r) end }
    end
    if #list > 0 then rows[#rows + 1] = { isSeparator = true } end
    local function Quick(label, seconds)
        rows[#rows + 1] = { text = L[label], keepOpen = true, onClick = function() R.Add(note, time() + seconds) end }
    end
    Quick("NOTES_REMIND_1H", 3600)
    Quick("NOTES_REMIND_4H", 4 * 3600)
    Quick("NOTES_REMIND_TOMORROW", 24 * 3600)
    Quick("NOTES_REMIND_3D", 3 * 24 * 3600)
    Quick("NOTES_REMIND_1W", 7 * 24 * 3600)
    rows[#rows + 1] = { text = L["NOTES_REMIND_CUSTOM"], onClick = function() R.ShowCustom(note) end }
    if #list > 1 then
        rows[#rows + 1] = { isSeparator = true }
        rows[#rows + 1] = { text = L["NOTES_REMIND_CLEAR_ALL"], keepOpen = true, onClick = function()
            wipe(list)
            note.updated = time()
        end }
    end
    return rows
end

-- A typed time of day: 18:30, 6:30, 6:30pm, 6pm or 18; the game's own AM
-- and PM words read too, as R.Clock writes them.
function R.ParseClock(text)
    local s = (text or ""):lower()
    local am, pm = (_G.TIMEMANAGER_AM or "AM"):lower(), (_G.TIMEMANAGER_PM or "PM"):lower()
    s = s:gsub(pm:gsub("%p", "%%%0"), "p"):gsub(am:gsub("%p", "%%%0"), "a"):gsub("%s", "")
    local h, m, half = smatch(s, "^(%d%d?):?(%d?%d?)([ap]?)m?$")
    h, m = tonumber(h), tonumber(m ~= "" and m or "0")
    if not (h and m) or m > 59 then return nil end
    if half == "p" and h < 12 then h = h + 12 elseif half == "a" and h == 12 then h = 0 end
    if h > 23 then return nil end
    return h, m
end

-- The custom time: a date stepped by day or month, a typed time and how it
-- repeats, over the Notes window.
function R.ShowCustom(note)
    local host = notesNS.UI._notes and notesNS.UI._notes.frame
    if not host then return end
    local p = R.custom
    if not p then
        p = CreateFrame("Frame", nil, host)
        p:SetSize(310, 172)
        p:SetPoint("CENTER")
        p:SetFrameLevel(host:GetFrameLevel() + 20)
        p:EnableMouse(true)
        ns.StyleMenuPanel(p)
        p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -12)
        p.title:SetText(L["NOTES_REMIND_ME"])
        local function Label(text, y)
            local fs = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y)
            fs:SetText(text)
            return fs
        end
        local function Step(label, x, y, fn)
            local b = CreateFrame("Button", nil, p)
            notesNS.StyleSubtleButton(b, label, 26, 20)
            b:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
            b:SetScript("OnClick", fn)
            return b
        end
        Label(L["NOTES_REMIND_DATE"], -42)
        local function Shift(days, months)
            local t = date("*t", p.at)
            t.isdst = nil
            if months ~= 0 then
                t.month = t.month + months
                t.day = mmin(t.day, DaysIn(t.year + math.floor((t.month - 1) / 12), (t.month - 1) % 12 + 1))
            end
            t.day = t.day + days
            p.at = time(t)
            p.Refresh()
        end
        Step("<<", 84, -38, function() Shift(0, -1) end)
        Step("<", 112, -38, function() Shift(-1, 0) end)
        Step(">", 254, -38, function() Shift(1, 0) end)
        Step(">>", 282, -38, function() Shift(0, 1) end)
        p.dateText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        p.dateText:SetPoint("LEFT", p, "TOPLEFT", 140, -48)
        p.dateText:SetPoint("RIGHT", p, "TOPLEFT", 252, -48)
        Label(L["NOTES_REMIND_TIME"], -72)
        local shell = CreateFrame("Frame", nil, p)
        shell:SetSize(110, 22)
        shell:SetPoint("TOPLEFT", p, "TOPLEFT", 112, -67)
        ns.CreateRingedWell(shell, 6)
        ns.PaintInputWell(shell)
        p.shell = shell
        p.timeBox = CreateFrame("EditBox", nil, shell)
        ns.Utils.ReleaseFocusOnOutsideClick(p.timeBox)
        p.timeBox:SetPoint("TOPLEFT", shell, "TOPLEFT", 8, 0)
        p.timeBox:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -8, 0)
        p.timeBox:SetAutoFocus(false)
        p.timeBox:SetFontObject("GameFontHighlightSmall")
        p.timeBox:SetMaxLetters(10)
        Label(L["NOTES_REMIND_REPEAT"], -102)
        p.repeatBtn = CreateFrame("Button", nil, p)
        notesNS.StyleSubtleButton(p.repeatBtn, "", 184, 22)
        p.repeatBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 112, -97)
        p.repeatBtn:SetScript("OnClick", function(self) R.PickRepeat(p, self) end)
        p.ok = CreateFrame("Button", nil, p)
        notesNS.StyleAccentButton(p.ok, _G.OKAY or "OK")
        p.ok:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -14, 12)
        p.cancel = CreateFrame("Button", nil, p)
        notesNS.StyleSubtleButton(p.cancel, _G.CANCEL or "Cancel", 70, 22)
        p.cancel:SetPoint("RIGHT", p.ok, "LEFT", -6, 0)
        local function Close() p:Hide() end
        p.cancel:SetScript("OnClick", Close)
        p.timeBox:SetScript("OnEscapePressed", Close)
        p.timeBox:SetScript("OnEnterPressed", function() p.ok:Click() end)
        p.timeBox:SetScript("OnTextChanged", function() ns.PaintInputWell(shell) end)
        p.ok:SetScript("OnClick", function()
            local h, m = R.ParseClock(p.timeBox:GetText())
            if not h then
                ns.PaintInputWell(shell, ns.INPUT_ERROR_FILL)
                return
            end
            local t = date("*t", p.at)
            t.hour, t.min, t.sec, t.isdst = h, m, 0, nil
            local at, now = time(t), time()
            local r = { at = at, rep = p.rep, days = p.days, day = t.day }
            if p.rep == "days" and not (p.days and next(p.days)) then return end
            if at <= now or (p.rep == "days" and not p.days[t.wday]) then r.at = R.Next(r, now) end
            if not r.at then
                ns.PaintInputWell(shell, ns.INPUT_ERROR_FILL)
                return
            end
            R.Add(p.note, r.at, p.rep, p.days)
            Close()
        end)
        function p.Refresh()
            local t = date("*t", p.at)
            p.dateText:SetText(sformat(L["NOTES_REMIND_DATE_FMT"], Weekday(t.wday), t.day, Month(t.month)) .. " " .. t.year)
            p.repeatBtn.text:SetText(R.RepeatLabel(p.rep, p.days))
        end
        R.custom = p
    end
    p.note, p.rep, p.days = note, nil, nil
    -- Today at the next full hour.
    local t = date("*t", time() + 3600)
    t.min, t.sec, t.isdst = 0, 0, nil
    p.at = time(t)
    p.timeBox:SetText(R.Clock(t.hour, 0))
    ns.PaintInputWell(p.shell)
    p.Refresh()
    p:Show()
    p.timeBox:SetFocus()
    p.timeBox:HighlightText()
end

-- How the custom time repeats; chosen days list the weekdays to tick.
function R.PickRepeat(p, owner)
    local defs = {}
    for _, o in ipairs(R.REPEATS) do
        defs[#defs + 1] = { kind = "radio", label = L[o.label], value = o.value or "once",
            get = function() return p.rep or "once" end,
            set = function(v)
                p.rep = v ~= "once" and v or nil
                if p.rep == "days" then
                    p.days = p.days or { [date("*t", p.at).wday] = true }
                    Utils.SafeAfter(0, function() R.PickRepeat(p, owner) end)
                end
                p.Refresh()
            end }
    end
    if p.rep == "days" then
        defs[#defs + 1] = { kind = "separator" }
        for w = 1, 7 do
            defs[#defs + 1] = { kind = "check", label = Weekday(w),
                get = function() return p.days[w] == true end,
                set = function(v)
                    p.days[w] = v or nil
                    p.Refresh()
                end }
        end
    end
    ns.ShowTogglePopup("EasyNotesRepeatPick", owner, defs, {})
end
