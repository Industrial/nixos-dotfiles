







local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not (ns and ns.ShowMe) or select(2, ...).stale then return end

local ShowMe = ns.ShowMe
local L = ns.L
local UIParent = UIParent
local Minimap = Minimap






local function CalculatorRow()
    local menu = ns.AppsMenu
    local dd = menu and menu.dropdown
    local rows = dd and dd.rows
    if not rows then return nil end
    local first
    for i = 1, #rows do
        local row = rows[i]
        if row:IsShown() and row.app then
            first = first or row
            if row.app.extensionID == "calculator" then return row end
        end
    end
    return first
end



local function MinimapDropPoint()
    if not (Minimap and Minimap:IsShown()) then return nil end
    local cx, cy = Minimap:GetCenter()
    if not cx then return nil end
    local k = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
    cx, cy = cx * k, cy * k
    local r = (Minimap:GetWidth() / 2) * k + 12
    local a = math.rad(205)
    return cx + math.cos(a) * r, cy + math.sin(a) * r
end




local function MicroMenuDropPoint()
    local bar = _G.MicroMenu
    if not (bar and bar:IsShown()) then return nil end
    local shown = {}
    for _, child in ipairs({ bar:GetChildren() }) do
        if child.layoutIndex and child:IsShown() and child:GetLeft() then shown[#shown + 1] = child end
    end
    table.sort(shown, function(a, b) return a.layoutIndex < b.layoutIndex end)
    local target = shown[6] or shown[#shown]
    if not target then return nil end
    local k = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local _, cy = target:GetCenter()
    return target:GetLeft() * k, cy * k
end

local function Ext() return ns.ExtensionButtons end

ShowMe:Register("extensionButtons", {
    prepare = function(api)
        api.barWasVisible = ShowMe.BarVisible()
        api.app = nil
        api.appID = nil
        api.btn = nil
    end,

    steps = {
        {

            run = function(api, done)
                if not ShowMe.BarVisible() and ns.Search and ns.Search.Show then
                    ns.Search:Show()
                end
                api.After(0.7, done)
            end,
        },
        {

            run = function(api, done)
                local btn = ns.AppsMenu and ns.AppsMenu.button
                api.MoveToFrame(btn, 0.8, function()
                    api.Click(function()
                        if btn and btn.Click then btn:Click() end
                        api.After(0.6, done)
                    end)
                end)
            end,
        },
        {

            run = function(api, done)
                local row = CalculatorRow()
                if not (row and Ext()) then done(); return end
                api.app = row.app
                api.appID = ns.ApplicationEntryID and ns.ApplicationEntryID(row.app)
                api.MoveToFrame(row, 0.7, function()
                    api.VirtualMouse(true)
                    api.Press()
                    api.After(0.2, function()
                        if ns.AppsMenu.dropdown then ns.AppsMenu.dropdown:Hide() end
                        Ext():BeginDragFromMenu(api.app)
                        api.Say(L["SHOWME_SAY_DRAG_OUT"], 1.4)
                        local tx = UIParent:GetWidth() * 0.5
                        local ty = UIParent:GetHeight() * 0.62
                        api.MoveTo(tx, ty, 1.0, function()
                            api.Release()
                            api.After(0.5, function()
                                api.btn = api.appID and Ext():FindButtonFor(api.appID) or nil
                                done()
                            end)
                        end)
                    end)
                end)
            end,
        },
        {

            run = function(api, done)
                local tx, ty = MinimapDropPoint()
                if not (api.btn and tx) then done(); return end
                api.MoveToFrame(api.btn, 0.6, function()
                    api.Press()
                    Ext():BeginVirtualDrag(api.btn)
                    api.Say(L["SHOWME_SAY_MINIMAP"], 1.6)
                    api.MoveTo(tx, ty, 1.0, function()
                        api.Release()
                        api.After(0.8, done)
                    end)
                end)
            end,
        },
        {

            run = function(api, done)
                local tx, ty = MicroMenuDropPoint()
                if not (api.btn and tx) then done(); return end
                api.MoveToFrame(api.btn, 0.6, function()
                    api.Press()
                    Ext():BeginVirtualDrag(api.btn)
                    api.Say(L["SHOWME_SAY_MICRO"], 1.6)
                    api.MoveTo(tx, ty, 1.1, function()
                        api.Release()
                        api.After(0.8, done)
                    end)
                end)
            end,
        },
        {

            run = function(api, done)
                if not api.btn then done(); return end
                api.VirtualMouse(false)
                api.Say(L["SHOWME_SAY_TOGGLE"], 2.6)
                api.MoveToFrame(api.btn, 0.6, function()
                    api.Click(function()
                        api.btn:Click()
                        api.After(1.4, function()
                            api.Click(function()
                                api.btn:Click()
                                api.After(0.6, done)
                            end)
                        end)
                    end)
                end)
            end,
        },
        {

            run = function(api, done)
                if not api.btn then done(); return end
                api.VirtualMouse(true)
                api.MoveToFrame(api.btn, 0.5, function()
                    api.Press()
                    Ext():BeginVirtualDrag(api.btn)
                    api.Say(L["SHOWME_SAY_REMOVE"], 1.4)
                    local trash = _G.EasyFindExtensionTrash
                    api.MoveToFrame(trash, 1.0, function()
                        api.Release()
                        api.After(0.6, done)
                    end)
                end)
            end,
        },
    },

    cleanup = function(api)
        local ext = Ext()
        if ext then
            if ext.ClearVirtualMouse then ext:ClearVirtualMouse() end
            if api.btn and ext.Owns and ext:Owns(api.btn) then ext:RemoveButton(api.btn) end
        end
        if ns.AppsMenu and ns.AppsMenu.dropdown then ns.AppsMenu.dropdown:Hide() end
        if api.app and ns.IsApplicationOpen and ns.IsApplicationOpen(api.app) then
            ns.CloseApplication(api.app)
        end
        if not api.barWasVisible and ns.Search and ns.Search.Hide then
            ns.Search:Hide()
        end
    end,
})
