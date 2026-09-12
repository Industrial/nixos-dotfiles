--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
--
--  In-game changelog. The authoritative, user-facing changelog lives in
--  this table (CHANGELOG.md is a static pointer here). Entries are ordered
--  newest-first; the top entry's version drives the version-aware auto-show.
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

-- Changelog content is intentionally NOT localized: it's authored per release
-- in English and we don't maintain translations for it.

-- A sticky note shown above every version entry. Use this for guidance that
-- stays relevant across releases (current setup gotchas, install advice).
addon.changelogPinned = {
    title = "Important — please read!!",
    paragraphs = {
        "First and foremost, thank you all for your patience. After a very frustrating week Clique should be back and fully functional. In the 12.0.7 patch Blizzard introduced some code that was probably well-intentioned, but broke core unit frame and click-casting behaviour. As addon authors tried to fix these problems, in some cases those fixes ended up fighting with each other.",
        "The big change in Clique is that it now fully takes control of the frames that it manages. This means that if you want the default left-click (target) and right-click (menu) behaviour, you need to bind them in Clique or add those frames to the denylist. These actions are bound like this by default, but you may have removed them at some point.",
    },
}

-- Each entry may set `autoShow = false` to be listed in the changelog without
-- triggering the version-aware auto-show after an update. Absent defaults to
-- true. Auto-show fires for the newest auto-show-eligible version the player
-- hasn't seen yet (see ShouldAutoShowChangelog).
addon.changelog = {
    {
        version  = "5.0.13",
        date     = "2026-07-23",
        autoShow = false,
        items = {
            "Update TOC for Classic Era 1.15.9.",
        },
    },
    {
        version  = "5.0.12",
        date     = "2026-07-22",
        autoShow = false,
        items = {
            "Add a macro-based dispatch mode, as an alternative to click.",
        },
    },
    {
        version = "5.0.11",
        date    = "2026-07-08",
        items = {
            "Fixed menu binding not including the \"Move Frame\" sub-menu on Classic Era.",
        },
    },
    {
        version = "5.0.10",
        date    = "2026-07-04",
        items = {
            "Fixed bindings on raid and party pet frames casting on the pet's owner instead of the pet.",
        },
    },
    {
        version = "5.0.9",
        date    = "2026-06-26",
        items = {
            "Fixed key bindings on unit frames always triggering on key release, ignoring the Down/Up/Both \"Trigger bindings on\" setting. They now fire on the edge you've chosen, the same as click bindings.",
        },
    },
    {
        version  = "5.0.8",
        date     = "2026-06-25",
        autoShow = false,
        items = {
            "Fixed issues on the 12.1.0 PTR caused by removed globals: the account macro limit is now read from the new Constants table, with a fallback for older clients.",
        },
    },
    {
        version = "5.0.7",
        date    = "2026-06-23",
        items = {
            "Fixed unit frames with modified actions (shift-right-click, etc.): Clique now overwrites those attributes when configured to, instead of relying on wildcards. This means your modified-click bindings apply reliably on frames that set their own.",
        },
    },
    {
        version = "5.0.6",
        date    = "2026-06-22",
        items = {
            "Fixed the in-game changelog and What's New page not appearing on Classic Era, Burning Crusade, Wrath, Cataclysm, and Mists of Pandaria.",
        },
    },
    {
        version = "5.0.5",
        date    = "2026-06-22",
        items = {
            "Added this in-game changelog, shown automatically after an update. You can turn off the automatic display with the checkbox at the bottom of this page.",
        },
    },
    {
        version = "5.0.4",
        date    = "2026-06-22",
        items = {
            "Target and menu actions should now work reliably, if you don't have them just create new bindings for them as you prefer.",
            "Overriding default Blizzard frame actions should work better now, Clique is more aggressive in managing registered frames.",
            "Options have been moved into the main config window, so you no longer have to flip back and forth.",
            "A warning now shows if you have changed the Blizzard click-casting defaults for target/menu. These MUST be left at the default, otherwise weird things will happen with your clicks.",
            "A warning now shows if you have 'Self Cast' set to 'Key' and you're using that key in a binding.",
            "Added support for pet spells in the action window.",
            "Numerous other bug fixes and improvements.",
        },
    },
}

addon.changelogKnownIssues = {
    title = "Known issues",
    items = {
        "You can no longer unbind the target and menu actions in Blizzard's click-casting, and they must be left at the default left-click and right-click. Reset them to default, and then make your changes in Clique. This is not an issue we can fix, we just acknowledge it here for clarity.",
        "Frames that load or change their unit while you're in combat may not get bindings applied until combat ends.",
    },
}

function addon:GetLatestChangelogVersion()
    local latest = self.changelog[1]
    return latest and latest.version
end

-- The newest version that should trigger the auto-show. Entries flagged
-- `autoShow = false` are skipped, so a release can ship a changelog entry
-- without re-prompting players. Entries are newest-first, so the first
-- eligible one is the newest.
function addon:GetLatestAutoShowChangelogVersion()
    for _, entry in ipairs(self.changelog) do
        if entry.autoShow ~= false then
            return entry.version
        end
    end
end

-- Compare two simple X.Y.Z version strings; returns true if `a` is strictly
-- newer than `b`. A nil/absent `b` is treated as older than everything (so a
-- player who has never seen the changelog always counts as behind).
function addon:IsVersionNewer(a, b)
    if not a then return false end
    if not b then return true end

    local ai, bi = 1, 1
    while true do
        local an = tonumber(a:match("^(%d+)", ai)) or 0
        local bn = tonumber(b:match("^(%d+)", bi)) or 0
        if an ~= bn then
            return an > bn
        end

        ai = a:find(".", ai, true)
        bi = b:find(".", bi, true)
        if not ai and not bi then
            return false
        end
        ai = (ai or #a) + 1
        bi = (bi or #b) + 1
    end
end

local VERSION_COLOR = "|cffffd200"  -- gold
local DATE_COLOR    = "|cff808080"  -- gray
local PINNED_COLOR  = "|cffff5555"  -- red, for the sticky "Important" note
local HEADING_COLOR = "|cff66bbff"  -- light blue
local TEXT_COLOR    = "|cffffffff"  -- white
local BULLET_COLOR  = "|cffd0d0d0"  -- light gray

function addon:BuildChangelogText()
    local lines = {}

    local function block(color, title, paragraphs, bullets)
        table.insert(lines, color and ("%s%s|r"):format(color, title) or title)
        for _, p in ipairs(paragraphs or {}) do
            table.insert(lines, TEXT_COLOR .. p .. "|r")
            -- Blank line between paragraphs for readability (bullets stay tight)
            table.insert(lines, "")
        end
        for _, item in ipairs(bullets or {}) do
            table.insert(lines, ("%s- %s|r"):format(BULLET_COLOR, item))
        end
        table.insert(lines, "")
    end

    local pinned = self.changelogPinned
    if pinned then
        block(PINNED_COLOR, pinned.title, pinned.paragraphs)
    end

    for _, entry in ipairs(self.changelog) do
        local header = ("%s%s|r  %s%s|r"):format(
            VERSION_COLOR, ("Version %s"):format(entry.version),
            DATE_COLOR, entry.date or "")
        block(nil, header, nil, entry.items)
    end

    local known = self.changelogKnownIssues
    if known then
        block(HEADING_COLOR, known.title, nil, known.items)
    end

    return table.concat(lines, "\n")
end

function addon:ShouldAutoShowChangelog()
    local g = self.globalSettings
    if not g or g.changelogDoNotShow then
        return false
    end
    return self:IsVersionNewer(self:GetLatestAutoShowChangelogVersion(), g.lastSeenChangelogVersion)
end
