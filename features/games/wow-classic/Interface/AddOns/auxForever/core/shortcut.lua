select(2, ...) 'aux.core.shortcut'

local aux = require 'aux'
local info = require 'aux.util.info'
local search_tab = require 'aux.tabs.search'

-- Shift-click, Alt-click or right-click an item in your bags while aux is open to bring it into aux
-- (docs/clicks.md, the 0.5 click standard): the Post tab selects it for posting, the Search tab
-- searches for it, and any other tab switches to the Search tab and searches for it.
-- Forever: a Shift-click normally goes into Blizzard's own auction house search box, which aux
-- keeps hidden, so it is taken over here. With a chat box open, Shift-click still links to chat.
-- auxForever (0.4): Alt-click on a recipe in the profession window searches its item and materials
-- (Shift-click on a recipe is Blizzard's "track recipe", so only Alt is used for recipes)
-- auxForever (0.8): Alt-click on a Waylaid Crate searches its bundles (Shift-click and right-click
-- still bring the crate itself into aux)

-- the current tab uses the item, or the Search tab searches it
function M.use_item(item_id, suffix_id, _, _, name)
    local tab = aux.get_tab()
    if not (tab and tab.USE_ITEM) then
        aux.set_tab(1)
        tab = aux.get_tab()
    end
    if tab and tab.USE_ITEM then
        -- the name tells gear endings apart (info.price_key)
        tab.USE_ITEM(item_id, suffix_id or 0, name)
    end
end

function M.on_modified_click(item_link)
    if not item_link or not aux.frame:IsShown() then
        return
    end
    local recipe_id = search_tab.recipe_id_from_link(item_link)
    if recipe_id then
        if IsAltKeyDown() then
            search_tab.search_recipe(recipe_id)
        end
        return
    end
    if not strfind(item_link, 'item:', 1, true) then
        return
    end
    -- clicks on aux's own result rows are handled by aux itself
    if aux.frame:IsMouseOver() then
        return
    end
    -- auxForever (0.8, FB-020): Alt-click a Waylaid Crate searches every bundle that fills it
    if IsAltKeyDown() and search_tab.search_crate(item_link) then
        return
    end
    local chat_open = ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow()
    if IsAltKeyDown() or (IsModifiedClick('CHATLINK') and not chat_open) then
        use_item(info.parse_link(item_link))
    end
end

hooksecurefunc('HandleModifiedItemClick', function(item_link)
    on_modified_click(item_link)
end)

-- auxForever (0.5, FB-002): a plain right-click on a bag item with the auction house open is sent by
-- Blizzard's bag code (ContainerFrameItemButton_OnClick, Forever's UI source) to
-- AuctionHouseFrame:SetPostItem, which puts the item into Blizzard's own Sell tab. aux keeps that
-- window open but invisible, so the item went there and nothing visible happened (Darkhorse:
-- "nothing happened"). aux follows the call and brings the item into aux instead. Bag addons that
-- use Blizzard's bag click code take the same path.
function M.on_post_item(item_location)
    if not aux.frame:IsShown() or aux.blizzard_frame_shown() then
        return
    end
    -- only a right-click: Blizzard can set its post item for other reasons
    local button = GetMouseButtonClicked and GetMouseButtonClicked()
    if button and button ~= 'RightButton' then
        return
    end
    local link = item_location and item_location.IsValid and item_location:IsValid() and C_Item.GetItemLink(item_location)
    if type(link) == 'string' and strfind(link, 'item:', 1, true) then
        -- Blizzard's Sell tab locks the item it holds (C_Item.LockItem in its item display), so the
        -- bag item could not be picked up or posted by aux afterwards (Tyler, build 3). Empty it.
        if AuctionHouseFrame.ClearPostItem then
            AuctionHouseFrame:ClearPostItem()
        elseif C_Item.UnlockItem then
            C_Item.UnlockItem(item_location)
        end
        use_item(info.parse_link(link))
    end
end

-- hooked once, whoever loaded Blizzard's auction house first
function M.hook_post_item()
    if post_item_hooked or not (AuctionHouseFrame and AuctionHouseFrame.SetPostItem) then
        return
    end
    post_item_hooked = true
    hooksecurefunc(AuctionHouseFrame, 'SetPostItem', function(_, item_location)
        on_post_item(item_location)
    end)
end

function aux.event.AUX_LOADED()
    hook_post_item()
    aux.event_listener('ADDON_LOADED', function(name)
        if name == 'Blizzard_AuctionHouseUI' then
            hook_post_item()
        end
    end)
    aux.event_listener('AUCTION_HOUSE_SHOW', function()
        hook_post_item()
    end)
end
