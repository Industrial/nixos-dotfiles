-- Boss portrait pool.
-- On the Forever client a creature portrait is drawn as a solid black square
-- until its model has loaded, and that square is painted over every window,
-- whatever its layer. So a portrait is never requested on a texture that is
-- on screen: each one is rendered on a holding frame parked off-screen, and
-- only moved into the journal once loaded. Moving a finished portrait does
-- not make the client draw it again.
--
-- rtvcap (2.0.9, a player's report on Discord, 15 Nov 2026: in Ragefire
-- Chasm the game window flipped between full screen and windowed every
-- second, graphics resets without end; the game's gx.log: "OutOfMemory:
-- AllocDescriptors Failed", "RTV view create failed", "Device context was
-- lost", 115 times): every live portrait is a render target the graphics
-- card keeps, and the pool kept every one for the whole session, a spare
-- copy of most of them too: some 125 after logging in, 340 once every page
-- had been opened. The game has only so many render target slots; when they
-- ran out, the graphics device was lost, and each time it was made again
-- every kept portrait was drawn again and ran out again. Now:
--   - at most PORTRAIT_LIVE_MAX portraits at once, on screen or kept;
--   - one not on screen any more is kept for a quick way back, the
--     PORTRAIT_IDLE_KEEP last ones only; the oldest are let go (the texture
--     cleared, which frees its render target, and reused);
--   - a spare copy only while well under the cap;
--   - closing the journal keeps only a few; a loading screen lets go of all
--     those not on screen.
-- softhost (2.0.9): a row that is hidden (another page is open) still held
-- its portrait, so enough hidden rows could use up the whole cap and a new
-- page got none. Now a portrait on a host that is not on screen can be
-- taken: handed straight to a host on screen that shows the same creature,
-- or let go to make room. A host that lost its portrait this way (or found
-- no room) gets it by itself once it is on screen and there is room.
-- idlepool (2.0.9): that is checked twice a second only while a waiting
-- host is on screen; nothing runs while the journal is closed. The check
-- starts again when a waiting host's frame is shown, and whenever a
-- portrait is asked for or handed back (a page being drawn).
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

FDJ.PORTRAIT_LOAD_SECONDS = 3
FDJ.PORTRAIT_LIVE_MAX = 48   -- portraits rendered at once (on screen + kept)
FDJ.PORTRAIT_IDLE_KEEP = 16  -- kept off screen for a quick way back
FDJ.PORTRAIT_SPARE_ROOM = 24 -- spare copies only below this many

local pool = {}      -- displayID -> { texture, ... }
local free = {}      -- textures with no portrait, to be reused
local live = 0       -- textures holding a rendered portrait
local staging
-- Hosts that want a portrait and have none (host.fdjWant: the display).
local starved = setmetatable({}, { __mode = "k" })
local ticker = CreateFrame("Frame")
ticker:Hide()
local tickSince = 0
-- Look at the waiting hosts again, soon.
local function Wake()
    if next(starved) == nil then return end
    if tickSince < 0.4 then tickSince = 0.4 end
    ticker:Show()
end

local function Staging()
    if not staging then
        staging = CreateFrame("Frame", nil, UIParent)
        staging:SetSize(64, 64)
        -- Well outside the right edge of the screen. ultrawide (2.0.11): far
        -- past it, not 400. On an ultra-wide monitor the game's UI can be
        -- kept to the middle of the screen (UIParent narrower than the
        -- screen), and 400 past UIParent's edge was still on screen there:
        -- a boss portrait sat in the top right corner and could not be
        -- clicked away (valeriu, Discord #general, 11 Nov 2026).
        staging:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", 10000, 0)
        staging:Show()
    end
    return staging
end

local function Park(tex)
    tex:SetParent(Staging())
    tex:ClearAllPoints()
    tex:SetAllPoints(staging)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:Show()
end

local function Now() return GetTime and GetTime() or 0 end
-- The order portraits were last used in (a count, not the time: many are
-- handed back in the same frame), so the oldest kept one is let go first.
local useCount = 0
local function Used(tex) useCount = useCount + 1 tex.fdjUsedAt = useCount end

-- Is this host on screen (itself and everything it sits in shown)?
local function Visible(region)
    if not region or not region.IsVisible then return false end
    local ok, shown = pcall(region.IsVisible, region)
    return (ok and shown) and true or false
end

-- This host waits for its portrait (host.fdjWant).
local function Starve(host)
    if not host or host.fdjWant == nil then return end
    starved[host] = true
    -- idlepool: its frame coming on screen is when to look again
    local parent = host.GetParent and host:GetParent()
    if parent and not parent.fdjPortraitWake and parent.HookScript then
        if pcall(parent.HookScript, parent, "OnShow", Wake) then parent.fdjPortraitWake = true end
    end
    ticker:Show()
end

-- Take a portrait off its host. The host still wants it and gets it back
-- by itself when it is on screen again (Starve).
local function Detach(tex)
    local host = tex.fdjHost
    if not host then return end
    tex.fdjHost = nil
    if host.fdjPooled == tex then
        host.fdjPooled = nil
        Starve(host)
    end
end

-- Let go of a portrait: its render target freed, the texture reused.
local function Evict(tex)
    Detach(tex)
    local list = tex.fdjDisplayID and pool[tex.fdjDisplayID]
    if list then
        for i = #list, 1, -1 do
            if list[i] == tex then table.remove(list, i) break end
        end
        if #list == 0 then pool[tex.fdjDisplayID] = nil end
    end
    pcall(tex.SetTexture, tex, nil)
    if tex.SetDesaturated then pcall(tex.SetDesaturated, tex, false) end -- (the tracker greys killed bosses)
    tex:Hide()
    tex.fdjDisplayID, tex.fdjReadyAt, tex.fdjHost, tex.fdjUsedAt = nil, nil, nil, nil
    live = math.max(0, live - 1)
    free[#free + 1] = tex
end

-- The kept portrait (on no host) left the longest ago, and how many are kept.
local function OldestIdle()
    local oldest, count
    count = 0
    for _, list in pairs(pool) do
        for _, tex in ipairs(list) do
            if not tex.fdjHost then
                count = count + 1
                if not oldest or (tex.fdjUsedAt or 0) < (oldest.fdjUsedAt or 0) then oldest = tex end
            end
        end
    end
    return oldest, count
end

-- The portrait on a host that is not on screen, used the longest ago.
local function OldestHidden()
    local oldest
    for _, list in pairs(pool) do
        for _, tex in ipairs(list) do
            local host = tex.fdjHost
            if host and (not oldest or (tex.fdjUsedAt or 0) < (oldest.fdjUsedAt or 0)) and not Visible(host) then
                oldest = tex
            end
        end
    end
    return oldest
end

-- Keep at most `keep` portraits that are on no host.
local function TrimIdle(keep)
    for _ = 1, 200 do
        local oldest, count = OldestIdle()
        if not oldest or count <= keep then return end
        Evict(oldest)
    end
end
FDJ.TrimPortraits = function(keep) TrimIdle(math.max(0, tonumber(keep) or 0)) end

-- Room for one more rendered portrait? Lets go of the oldest kept one if
-- needed, else of the oldest one on a host that is not on screen.
local function MakeRoom()
    local max = FDJ.PORTRAIT_LIVE_MAX or 48
    if live < max then return true end
    local victim = (OldestIdle()) or OldestHidden()
    if victim then Evict(victim) end
    return live < max
end

-- Put the host's pooled portrait where the host is, if it has finished loading.
local function Place(host)
    local tex = host.fdjPooled
    if not tex then return end
    if Now() < (tex.fdjReadyAt or 0) then return end
    local parent = host:GetParent()
    if not parent then return end
    tex:SetParent(parent)
    tex:ClearAllPoints()
    tex:SetAllPoints(host)
    local layer, sub = host:GetDrawLayer()
    if layer then tex:SetDrawLayer(layer, sub or 0) end
    tex:SetTexCoord(host:GetTexCoord())
    tex:SetAlpha(1)
    -- (grey like its host: the Dungeon Tracker greys a killed boss)
    if tex.SetDesaturated and host.IsDesaturated then
        local ok, grey = pcall(host.IsDesaturated, host)
        pcall(tex.SetDesaturated, tex, (ok and grey) and true or false)
    end
    tex:SetShown(host:IsShown())
end

-- Render one more copy of a portrait on the holding frame. Returns the
-- texture; or nil and "none" when the client has no portrait for that
-- display ID, nil and "full" when PORTRAIT_LIVE_MAX portraits are all on
-- screen.
local function CreatePooled(displayID, list)
    if not MakeRoom() then return nil, "full" end
    local tex = table.remove(free) or Staging():CreateTexture(nil, "ARTWORK")
    Park(tex)
    -- loginlag (2.0.8): counted, so the login warm-up can pace itself
    FDJ.portraitRenders = (FDJ.portraitRenders or 0) + 1
    local ok = pcall(SetPortraitTextureFromCreatureDisplayID, tex, displayID)
    local shown = ok and tex:GetTexture() or nil
    if shown == nil or shown == 0 or shown == "" then
        pcall(tex.SetTexture, tex, nil)
        tex:Hide()
        free[#free + 1] = tex
        return nil, "none"
    end
    live = live + 1
    tex.fdjDisplayID = displayID
    tex.fdjReadyAt = Now() + (FDJ.PORTRAIT_LOAD_SECONDS or 0)
    Used(tex)
    list[#list + 1] = tex
    return tex
end

-- The same boss is shown in several places at once (the list row, the large
-- portrait beside the loot, a map pin). Keep one finished copy spare, so the
-- next place that needs it gets it at once instead of waiting for a fresh
-- copy to load. rtvcap (2.0.9): only while well under the cap.
local function EnsureSpare(displayID, list)
    -- loginlag (2.0.8): the login warm-up renders each portrait once, no spare
    -- (a page that shows it later makes its spare then)
    if FDJ.portraitNoSpare then return end
    if live >= (FDJ.PORTRAIT_SPARE_ROOM or 24) then return end
    for _, candidate in ipairs(list) do
        if not candidate.fdjHost then return end
    end
    CreatePooled(displayID, list)
end

function FDJ.ReleasePortrait(host)
    if not host then return end
    host.fdjWant, host.fdjWantAt = nil, nil
    starved[host] = nil
    local tex = host.fdjPooled
    if not tex then return end
    host.fdjPooled = nil
    tex.fdjHost = nil
    Used(tex)
    Park(tex)
    TrimIdle(FDJ.PORTRAIT_IDLE_KEEP or 16)
    Wake() -- (room for a host that waits)
end

-- rtvcap (2.0.9): the journal closed: its pages' portraits are handed back
-- (every page asks for its portraits again when the journal opens; one that
-- doesn't gets it back by itself, see softhost), and of all those on no host
-- only `keep` are kept: the last page's first, so opening the journal again
-- on it is instant. Only those inside `root` and not on screen; the Dungeon
-- Tracker's and the Run Log's stay.
FDJ.ReleaseHiddenPortraits = function(root, keep)
    if not root then return end
    local drop = {}
    for _, list in pairs(pool) do
        for _, tex in ipairs(list) do
            local host = tex.fdjHost
            if host and not Visible(host) then
                local p, inside = host, false
                for _ = 1, 25 do
                    p = p.GetParent and p:GetParent() or nil
                    if not p then break end
                    if p == root then inside = true break end
                end
                if inside then drop[#drop + 1] = tex end
            end
        end
    end
    for _, tex in ipairs(drop) do
        Detach(tex)
        Used(tex)
        Park(tex)
    end
    TrimIdle(math.max(0, tonumber(keep) or 0))
end

-- How many portraits are rendered now (on screen + kept), for the tests;
-- and how many are kept on no host, sit on a host that is not on screen,
-- how many hosts wait for one, and whether the half-second check runs.
FDJ.PortraitsLive = function() return live end
FDJ.PortraitStats = function()
    local _, idle = OldestIdle()
    local hidden, waiting = 0, 0
    for _, list in pairs(pool) do
        for _, tex in ipairs(list) do
            if tex.fdjHost and not Visible(tex.fdjHost) then hidden = hidden + 1 end
        end
    end
    for host in pairs(starved) do
        if host.fdjWant ~= nil and not host.fdjPooled then waiting = waiting + 1 end
    end
    return live, idle, hidden, waiting, (ticker:IsShown() and true or false)
end

-- Show the portrait for displayID in place of `host` (a texture slot in the
-- journal). Returns false when the client has no portrait for that ID, or
-- when the cap is reached with every portrait on screen (the host then gets
-- it by itself once there is room).
local function Acquire(host, displayID)
    if type(displayID) ~= "number" or displayID <= 0 then return false end
    if type(SetPortraitTextureFromCreatureDisplayID) ~= "function" then return false end

    local current = host.fdjPooled
    if current and current.fdjDisplayID == displayID then
        host.fdjWant, host.fdjWantAt = displayID, Now()
        starved[host] = nil
        Used(current)
        Place(host)
        return true
    end
    -- what it shows now is handed back (kept for a quick way back)
    if current then
        host.fdjPooled = nil
        current.fdjHost = nil
        Used(current)
        Park(current)
    end

    local list = pool[displayID]
    if not list then list = {} pool[displayID] = list end
    local tex
    for _, candidate in ipairs(list) do
        if not candidate.fdjHost then tex = candidate break end
    end
    if not tex then
        -- softhost: a copy on a host that is not on screen is taken over as
        -- it is (no new render, shown at once)
        for _, candidate in ipairs(list) do
            local other = candidate.fdjHost
            if other and other ~= host and not Visible(other) then
                Detach(candidate)
                tex = candidate
                break
            end
        end
    end
    local why
    if not tex then tex, why = CreatePooled(displayID, list) end
    if not tex then
        if #list == 0 then pool[displayID] = nil end
        local now = Now()
        if why == "full" then
            -- every portrait is on screen: this host waits for room. Of the
            -- looks tried for it in one go (a boss's own, then the journal's
            -- other sources) the first is the one it waits for; what it
            -- waited for before (another creature) is forgotten.
            if host.fdjWant == nil or host.fdjWantAt ~= now then host.fdjWant = displayID end
            host.fdjWantAt = now
            Starve(host)
        elseif host.fdjWantAt ~= now then
            -- the game has no portrait for this look, and what the host
            -- waited for before is not what it shows now: nothing to wait for
            host.fdjWant, host.fdjWantAt = nil, nil
            starved[host] = nil
        end
        if current then TrimIdle(FDJ.PORTRAIT_IDLE_KEEP or 16) end
        return false
    end

    host.fdjWant, host.fdjWantAt = displayID, Now()
    starved[host] = nil
    tex.fdjHost = host
    Used(tex)
    host.fdjPooled = tex
    host:SetTexture(nil)
    EnsureSpare(displayID, list)
    if current then TrimIdle(FDJ.PORTRAIT_IDLE_KEEP or 16) end

    local wait = (tex.fdjReadyAt or 0) - Now()
    if wait > 0 and C_Timer and C_Timer.After then
        C_Timer.After(wait + 0.05, function()
            if host.fdjPooled == tex then pcall(Place, host) end
        end)
    else
        tex.fdjReadyAt = 0
        Place(host)
    end
    return true
end
FDJ.AcquirePortrait = function(host, displayID)
    local shown = Acquire(host, displayID)
    Wake() -- (a page is being drawn: a host that waits may be on screen now)
    return shown
end

-- softhost (2.0.9): twice a second, while a host that waits for its portrait
-- is on screen: it gets it as soon as there is room. idlepool: the check
-- stops when none of them is on screen (see Wake for when it starts again).
do
    local waiting = {} -- (reused: nothing made anew each time)
    ticker:SetScript("OnUpdate", function(self, elapsed)
        tickSince = tickSince + (elapsed or 0)
        if tickSince < 0.5 then return end
        tickSince = 0
        local count = 0
        for host in pairs(starved) do
            count = count + 1
            waiting[count] = host
        end
        local onScreen = 0
        for i = 1, count do
            local host = waiting[i]
            waiting[i] = nil
            local want = host.fdjWant
            if want == nil or host.fdjPooled then
                starved[host] = nil
            elseif Visible(host) then
                local ok, got = pcall(Acquire, host, want)
                if not ok then
                    starved[host] = nil -- (never again and again after an error)
                elseif not got and starved[host] then
                    onScreen = onScreen + 1
                end
            end
        end
        if onScreen == 0 then self:Hide() end
    end)
end

-- rtvcap (2.0.9): before a loading screen, let go of every portrait that is
-- not on screen (they are drawn again, a few at most, when next needed).
do
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("PLAYER_LEAVING_WORLD")
    watch:SetScript("OnEvent", function()
        local hidden = {}
        for _, list in pairs(pool) do
            for _, tex in ipairs(list) do
                if tex.fdjHost and not Visible(tex.fdjHost) then hidden[#hidden + 1] = tex end
            end
        end
        for _, tex in ipairs(hidden) do
            Detach(tex)
            Used(tex)
            Park(tex)
        end
        pcall(TrimIdle, 0)
    end)
end
