select(2, ...) 'aux'

local gui = require 'aux.gui'
local scan = require 'aux.core.scan'
local search = require 'aux.tabs.search'
local info = require 'aux.util.info'

function event.AUX_LOADED()
	for _, v in ipairs(tab_info) do
		tabs:create_tab(v.name)
	end
	-- the saved position and size are in the window's own scale, so the scale comes first
	account_data.scale = clean_scale(account_data.scale)
	frame:SetScale(account_data.scale)
	restore_window()
	account_data.background_opacity = gui.set_background_opacity(account_data.background_opacity)
	if register_options_panel then
		register_options_panel()
	end
end

-- Forever: the window can be resized from its bottom right corner (double-click the corner for the
-- default size), and it remembers its size and position.
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 1100, 660
local MIN_WIDTH, MIN_HEIGHT = 1000, 549
-- auxForever: the logo, tabs, full scan, Blizzard UI and close sit in a bar across the top
local TOP_BAR_HEIGHT = 40
local BOTTOM_BAR_HEIGHT = 35

local function max_size()
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return max(MIN_WIDTH, UIParent:GetWidth() / scale), max(MIN_HEIGHT, UIParent:GetHeight() / scale)
end

function save_window()
	local window = account_data.window
	window.width, window.height = frame:GetWidth(), frame:GetHeight()
	local point, _, relative_point, x, y = frame:GetPoint(1)
	window.point, window.relative_point, window.x, window.y = point, relative_point, x, y
end

-- the window keeps its top left corner where it is; sizing and scaling then grow it to the right
-- and down only. Sizing from the corner while it hung from another point (it starts out anchored
-- by its left edge) could make the window jump to full screen on a single click.
function M.anchor_top_left()
	local left, top = frame:GetLeft(), frame:GetTop()
	local point, relative, relative_point, x, y = frame:GetPoint(1)
	-- already there: leave it, so a click never moves the window by a rounding error
	if point == 'TOPLEFT' and relative == UIParent and relative_point == 'BOTTOMLEFT' and left and top
		and abs((x or 0) - left) < .5 and abs((y or 0) - top) < .5 then
		return
	end
	if left and top then
		frame:ClearAllPoints()
		frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left, top)
	end
end

MIN_SCALE, MAX_SCALE = .7, 1.5

-- auxForever: window scale, 70% to 150% (the Scale setting and /aux scale)
function M.clean_scale(scale)
	return bounded(MIN_SCALE, MAX_SCALE, floor((tonumber(scale) or 1) * 20 + .5) / 20)
end

function M.set_window_scale(scale)
	scale = clean_scale(scale)
	anchor_top_left()
	local left, top = frame:GetLeft(), frame:GetTop()
	local old = frame:GetScale()
	frame:SetScale(scale)
	-- keep the top left corner in place on screen: anchor offsets are in the window's own scale
	if left and top and old and old > 0 then
		frame:ClearAllPoints()
		frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left * old / scale, top * old / scale)
	end
	-- never bigger than the screen at the new scale
	local max_width, max_height = max_size()
	gui.set_size(frame, bounded(MIN_WIDTH, max_width, frame:GetWidth()), bounded(MIN_HEIGHT, max_height, frame:GetHeight()))
	save_window()
	return scale
end

function M.restore_window()
	local window = account_data.window
	local max_width, max_height = max_size()
	local width = bounded(MIN_WIDTH, max_width, window.width or DEFAULT_WIDTH)
	local height = bounded(MIN_HEIGHT, max_height, window.height or DEFAULT_HEIGHT)
	gui.set_size(frame, width, height)
	if window.point then
		frame:ClearAllPoints()
		frame:SetPoint(window.point, UIParent, window.relative_point, window.x, window.y)
	end
end

do
	local frame = CreateFrame('Frame', 'aux_frame', UIParent, 'BackdropTemplate')
	tinsert(UISpecialFrames, 'aux_frame')
	gui.set_window_style(frame)
	gui.register_background(frame, color.window.background)
	-- Forever: wider, and resizable (see restore_window)
	gui.set_size(frame, DEFAULT_WIDTH, DEFAULT_HEIGHT)
	frame:SetPoint('LEFT', 100, 0)
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
	frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', frame.StartMoving)
    frame:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()
        save_window()
    end)
	frame:SetClampedToScreen(true)
--	frame:CreateTitleRegion():SetAllPoints() TODO classic why
	frame:SetScript('OnShow', function() PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN) end)
	frame:SetScript('OnHide', function() PlaySound(SOUNDKIT.AUCTION_WINDOW_CLOSE); C_AuctionHouse.CloseAuctionHouse() end)
	-- everything under the top bar; each tab's frame fills it
	frame.body = CreateFrame('Frame', nil, frame)
	frame.body:SetPoint('TOPLEFT', 0, -TOP_BAR_HEIGHT)
	frame.body:SetPoint('BOTTOMRIGHT', 0, 0)
	frame.content = CreateFrame('Frame', nil, frame)
	frame.content:SetPoint('TOPLEFT', frame.body, 'TOPLEFT', 4, -80)
	frame.content:SetPoint('BOTTOMRIGHT', -4, 35)
	-- auxForever (0.6, the UI Kit): darker bands across the top (logo, tabs) and the bottom (status
	-- bar, credit), each with a black edge toward the middle
	local function band(point, height)
		local band = frame:CreateTexture(nil, 'BACKGROUND', nil, -5)
		band:SetTexture([[Interface\Buttons\WHITE8X8]])
		-- fades with the Background setting, like the window
		gui.register_background({SetBackdropColor = function(_, ...) band:SetVertexColor(...) end}, color.band)
		band:SetPoint(point .. 'LEFT', 1, point == 'TOP' and -1 or 1)
		band:SetPoint(point .. 'RIGHT', -1, point == 'TOP' and -1 or 1)
		band:SetHeight(height - 1)
		local edge = frame:CreateTexture(nil, 'BORDER')
		gui.texture_color(edge, color.band_edge)
		edge:SetHeight(1)
		edge:SetPoint(point == 'TOP' and 'TOPLEFT' or 'BOTTOMLEFT', band, point == 'TOP' and 'BOTTOMLEFT' or 'TOPLEFT')
		edge:SetPoint(point == 'TOP' and 'TOPRIGHT' or 'BOTTOMRIGHT', band, point == 'TOP' and 'BOTTOMRIGHT' or 'TOPRIGHT')
	end
	band('TOP', TOP_BAR_HEIGHT)
	band('BOTTOM', BOTTOM_BAR_HEIGHT)
	frame:Hide()
	M.frame = frame
end
do
    local status_bar = gui.status_bar(frame.content)
    status_bar:SetWidth(265)
    status_bar:SetHeight(22)
    status_bar:SetPoint('LEFT', frame, 'BOTTOMLEFT', 6, BOTTOM_BAR_HEIGHT / 2)
    status_bar:update_status(1, 1)
    M.status_bar = status_bar
end
do
	local logo = gui.label(frame, 20)
	logo:SetFont(gui.font_bold, 20)
	logo:SetPoint('LEFT', frame, 'TOPLEFT', 12, -TOP_BAR_HEIGHT / 2)
	gui.themed(function() logo:SetText(color.text.enabled'aux' .. color.accent.background'Forever') end)
	logo_label = logo
end
do
	tabs = gui.tabs(frame, 'BAR', logo_label)
	tabs._on_select = on_tab_click
	function M.set_tab(id) tabs:select(id) end
end
do
	local grip = CreateFrame('Button', nil, frame)
	grip:SetPoint('BOTTOMRIGHT', -2, 2)
	gui.set_size(grip, 16, 16)
	grip:SetNormalTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up]])
	grip:SetHighlightTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight]])
	grip:SetPushedTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Down]])
	-- auxForever (0.4.1): aux sizes the window itself instead of the game's StartSizing. With
	-- StartSizing a single click on the corner could make the whole window jump diagonally, again
	-- with each click (Tyler; not reproduced here). Now the size follows the mouse only while it is
	-- dragged, measured from where the drag started, so a click that does not move changes nothing.
	-- The top left corner stays put and the window stays on screen. Runs only during a drag.
	local function cursor()
		local x, y = GetCursorPosition()
		local scale = frame:GetEffectiveScale()
		return x / scale, y / scale
	end
	local function stop_sizing()
		if grip:GetScript('OnUpdate') then
			grip:SetScript('OnUpdate', nil)
			save_window()
		end
	end
	grip:SetScript('OnMouseDown', function(_, button)
		if button ~= 'LeftButton' then return end
		anchor_top_left()
		local x0, y0 = cursor()
		local width0, height0 = frame:GetWidth(), frame:GetHeight()
		-- room up to the right and bottom edges of the screen, in the window's own scale
		local screen = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
		local max_width = max(MIN_WIDTH, UIParent:GetWidth() * screen - (frame:GetLeft() or 0))
		local max_height = max(MIN_HEIGHT, frame:GetTop() or UIParent:GetHeight() * screen)
		local last_width, last_height = width0, height0
		grip:SetScript('OnUpdate', function()
			if not IsMouseButtonDown('LeftButton') then
				stop_sizing()
				return
			end
			local x, y = cursor()
			local width = floor(bounded(MIN_WIDTH, max_width, width0 + x - x0) + .5)
			local height = floor(bounded(MIN_HEIGHT, max_height, height0 + y0 - y) + .5)
			if width ~= last_width or height ~= last_height then
				last_width, last_height = width, height
				gui.set_size(frame, width, height)
			end
		end)
	end)
	grip:SetScript('OnMouseUp', stop_sizing)
	grip:SetScript('OnDoubleClick', function()
		stop_sizing()
		anchor_top_left()
		gui.set_size(frame, DEFAULT_WIDTH, DEFAULT_HEIGHT)
		save_window()
	end)
	grip:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_TOP')
		GameTooltip:AddLine('Drag to resize')
		GameTooltip:AddLine('Double-click for the default size', 1, 1, 1)
		GameTooltip:Show()
	end)
	grip:SetScript('OnLeave', function() GameTooltip:Hide() end)
	resize_grip = grip
end
do
	local btn = gui.button(frame, 22)
	btn:SetPoint('RIGHT', frame, 'TOPRIGHT', -6, -TOP_BAR_HEIGHT / 2)
	gui.set_size(btn, 26, 26)
	btn:SetText('\195\151')
	gui.themed(function()
		btn:SetBackdropColor(0, 0, 0, 0)
		btn:SetBackdropBorderColor(0, 0, 0, 0)
		btn.aux_sheen:SetShown(false)
		btn:GetFontString():SetTextColor(.85, .85, .85)
	end)
	btn:SetScript('OnClick', function() frame:Hide() end)
	btn:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
		GameTooltip:AddLine('Close')
		GameTooltip:Show()
	end)
	btn:SetScript('OnLeave', function() GameTooltip:Hide() end)
	close_button = btn
end
do
	local btn = gui.button(frame, gui.font_size.small)
	btn:SetPoint('RIGHT', close_button, 'LEFT' , -4, 0)
	gui.set_size(btn, 80, 26)
	btn:SetText(color.blizzard'Blizzard UI')
	btn:SetScript('OnClick',function()
		set_blizzard_frame_shown(not blizzard_frame_shown())
	end)
	btn:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
		GameTooltip:AddLine(blizzard_frame_shown() and 'Hide the Blizzard auction house' or 'Show the Blizzard auction house')
		GameTooltip:AddLine('It opens on top of aux. Click aux to bring aux back to the front.', 1, 1, 1, true)
		GameTooltip:Show()
	end)
	btn:SetScript('OnLeave', function() GameTooltip:Hide() end)
    blizzard_button = btn
    -- lit while the Blizzard window is shown, so its state is always visible
    function M.update_blizzard_button()
        gui.set_default(btn)
        if blizzard_frame_shown() then
            btn:SetBackdropBorderColor(color.blizzard())
        end
    end
end
do
    local btn = gui.button(frame)
    btn:SetPoint('RIGHT', blizzard_button, 'LEFT' , -4, 0)
    gui.set_size(btn, 80, 26)
    btn:SetText('Full scan')
    -- Forever: a full scan uses C_AuctionHouse.ReplicateItems, which the server allows once every 15 minutes
    local function seconds_until_scan()
        return max(0, account_data.replicate_time + scan.REPLICATE_COOLDOWN - time())
    end
    -- auxForever: checked twice a second and restyled only when ready changes (it was every frame)
    local ready, next_check
    btn:SetScript('OnUpdate', function(self)
        if GetTime() < (next_check or 0) then return end
        next_check = GetTime() + .5
        -- 0.8.2 build 6 (Tyler: "I had to stop sniper for full scan to ungrey"): only another Full
        -- scan keeps it gray. A search or a Sniper round under way is stopped by it (the Sniper then
        -- waits for the Full scan, build 1); the button was gray whenever any scan ran.
        local now_ready = seconds_until_scan() == 0 and not scan.is_full_scan()
        if now_ready == ready then return end
        ready = now_ready
        if ready then
            self:Enable()
        else
            self:Disable()
        end
    end)
    btn:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:AddLine('Full scan')
        local seconds = seconds_until_scan()
        if seconds > 0 then
            GameTooltip:AddLine(format('Available again in %d:%02d', floor(seconds / 60), seconds % 60), 1, 1, 1)
        else
            GameTooltip:AddLine('Records prices of everything on the auction house.', 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    btn:SetScript('OnLeave', function() GameTooltip:Hide() end)
    btn:SetMotionScriptsWhileDisabled(true)
    -- Starts a Full scan (PR #37, Dragoy). Both the top button and the Sniper's notice button call
    -- this; if clicked while on cooldown, it says when the next one is allowed instead of silently
    -- doing nothing.
    M.full_scan_button = btn
    function M.start_full_scan(auto)
        if scan.is_full_scan() or (auto and scan.is_scanning()) then
            return
        end
        local seconds = seconds_until_scan()
        if seconds > 0 then
            if not auto then
                print(format('Full scan is available again in %d:%02d. The game allows one every 15 minutes.', floor(seconds / 60), seconds % 60))
            end
            return
        end
        local count, shown_percent = 0
        scan.start{
            type = 'list',
            priority = auto and scan.PRIORITY_BACKGROUND or scan.PRIORITY_USER,
            queries = {{blizzard_query = {}}},
            get_all = true,
            on_scan_start = function()
                status_bar:update_status(0, 0)
                -- auxForever (0.5): the server takes several seconds before the list arrives; say
                -- so, or the scan looks stuck (Tyler, build 3)
                status_bar:set_text('Full scan: waiting for the auction house...')
                search.clear_selection()
            end,
            -- 0.8.2 (FB-037): since launch the answer can take minutes; show how long so far
            on_wait = function(seconds)
                if seconds >= 5 then
                    status_bar:set_text(format('Full scan: waiting for the auction house, %d:%02d so far. A search now would stop it.', floor(seconds / 60), seconds % 60))
                end
            end,
            -- 0.8.2.1 (FB-027): how far the read is, once per pause of the scan (no auction record is
            -- built for a Full scan any more, and the bar was redrawn for every auction)
            on_progress = function(done, total)
                count = done
                if total > 0 then
                    status_bar:update_status(done / total, 0)
                    local percent = floor(done / total * 100)
                    if percent ~= shown_percent then
                        shown_percent = percent
                        status_bar:set_text(format('Full scan: reading auctions, %d%%', percent))
                    end
                end
            end,
            on_abort = function()
                status_bar:update_status(1, 1)
                status_bar:set_text()
            end,
            on_complete = function(result)
                status_bar:update_status(1, 1)
                status_bar:set_text()
                -- 0.8.2: nothing more when the auction house never answered (the scan said why)
                local line = scan.full_scan_summary(result, count)
                if line then
                    print(line)
                end
            end,
        }
    end
    btn:SetScript('OnClick', function()
        start_full_scan()
    end)
    scan_button = btn
end
do
    -- auxForever: settings (background opacity, scale, default duration, look, tooltip lines), behind
    -- a gear in the top bar
    local btn = gui.button(frame)
    btn:SetPoint('RIGHT', scan_button, 'LEFT', -4, 0)
    gui.set_size(btn, 26, 26)
    local icon = btn:CreateTexture(nil, 'ARTWORK')
    icon:SetTexture([[Interface\AddOns\auxForever\textures\gear.tga]])
    icon:SetSize(15, 15)
    icon:SetPoint('CENTER')
    icon:SetVertexColor(.85, .85, .85)
    btn:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
        GameTooltip:AddLine('Settings')
        GameTooltip:Show()
    end)
    btn:SetScript('OnLeave', function() GameTooltip:Hide() end)
    settings_button = btn

    -- auxForever (0.6): two columns, as in the mockup Tyler approved (2026-10-08): Window, Posting,
    -- Buying and General on the left, tooltip lines on the right.
    -- 0.9 (FB-057, LLanwrst, jebbush): shared builder populates both the AH gear popup and the
    -- Blizzard Options > AddOns > auxForever canvas panel so every control stays 100% synced.
    local TOOLTIP_LINES = {
        {'value', 'Value', 'Price from your latest scan', 'The market price from your latest look at the item.'},
        -- 0.8.2 (FB-035, suggested by deep_structure): the usual price could only go with Value. Since
        -- build 4 a percent on the Value line (Tyler), so the saved key stays "usually"
        {'usually', '% of usual', nil, "After Value: Value as a percent of the usual price over the last days, the same number and colors as the Search tab's % of usual column."},
        {'daily', 'Today', "Today's lowest, against the usual", "Today's lowest price, and how it compares with the usual price."},
        {'merchant_sell', 'Vendor sell price', nil, 'What a vendor pays you for it.'},
        {'merchant_buy', 'Vendor buy price', nil, 'What a vendor sells it for, once you have seen it at one.'},
        {'disenchant_value', 'Disenchant value', nil, 'What its disenchant materials are worth.'},
        {'disenchant_distribution', 'Disenchants into', nil, 'Which materials it can give, and how likely each is.'},
        -- 0.8.2.1 build 7 (FB-041, suggested by user_tdsvrjvpe8rufw54): the crate lines had no switch
        {'crate', 'Waylaid Crates', 'Cheapest fill price', 'Under a Waylaid Crate: what each bundle it asks for costs, the cheapest in gold, and how many you already have.'},
        -- 0.9 (FB-058, suggested by jebbush; Tyler): full stack by default, hold Shift for 1 item
        {'stack', 'Stack prices by default', 'Hold Shift for 1 item', 'Show Vendor, Value and Today prices for the whole stack by default, and hold Shift for 1 item. Off: show 1 item by default and hold Shift for the stack.'},
        {'money_icons', 'Coin icons', 'Gold, silver and copper coins', 'Show prices in tooltips with gold, silver and copper coins instead of text.'},
    }

    local function percent(x) return floor(x * 100 + .5) .. '%' end

    local refresh_views = {}
    local function refresh()
        for _, fn in ipairs(refresh_views) do
            fn()
        end
    end
    M.refresh_settings = refresh

    -- the switches and chat commands both come here, so they behave the same
    function M.set_buy_confirm(on)
        account_data.buy_confirm = on and true or false
        refresh()
    end
    function M.set_buy_default(mode)
        account_data.buy_default = mode == 'stack' and 'stack' or '1'
        refresh()
    end
    function M.set_right_click_post(on)
        account_data.right_click_post = on and true or false
        refresh()
    end
    function M.set_auto_full_scan(on)
        account_data.auto_full_scan = on and true or false
        refresh()
    end
    function M.set_crafting_cost(on)
        account_data.crafting_cost = on and true or false
        if search.refresh_cost_line then
            search.refresh_cost_line()
        end
        refresh()
    end
    function M.set_background_opacity(opacity)
        account_data.background_opacity = gui.set_background_opacity(opacity)
        refresh()
    end
    function M.change_window_scale(scale)
        account_data.scale = set_window_scale(scale)
        refresh()
    end

    local function build_settings_body(parent, top_y, width, pad, column, resize_popup)
        local left_x = pad
        local right_x = width - pad - column

        local function section(p, x, y, text)
            local label = gui.label(p, gui.font_size.small)
            label:SetPoint('TOPLEFT', x, y)
            label:SetText(text)
            gui.text_color(label, color.accent.background)
            return label
        end

        local function row(p, x, y, height, name, hint, tip, tip_anchor)
            local r = CreateFrame('Frame', nil, p)
            r:SetPoint('TOPLEFT', x, y)
            gui.set_size(r, column, height)
            r:EnableMouse(true)
            local label = gui.label(r, gui.font_size.medium)
            label:SetText(name)
            gui.text_color(label, color.text.enabled)
            if hint then
                label:SetPoint('TOPLEFT', 0, -3)
                local small = gui.label(r, gui.font_size.small)
                small:SetPoint('TOPLEFT', label, 'BOTTOMLEFT', 0, -2)
                small:SetText(hint)
                r.hint = small
            else
                label:SetPoint('LEFT', 0, 0)
            end
            r.label = label
            if tip then
                local anchor = tip_anchor or 'ANCHOR_RIGHT'
                r.tip_anchor = anchor
                r:SetScript('OnEnter', function(self)
                    GameTooltip:SetOwner(self, anchor)
                    GameTooltip:AddLine(name)
                    GameTooltip:AddLine(tip[1], 1, 1, 1, true)
                    if tip[2] then GameTooltip:AddLine(tip[2], .6, .6, .6) end
                    GameTooltip:Show()
                end)
                r:SetScript('OnLeave', function() GameTooltip:Hide() end)
            end
            return r
        end

        local function stepper(r)
            local plus = gui.button(r, gui.font_size.large)
            gui.set_size(plus, 26, 24)
            plus:SetPoint('RIGHT', 0, 0)
            plus:SetText('+')
            local value = gui.label(r, gui.font_size.medium)
            value:SetWidth(46)
            value:SetJustifyH('CENTER')
            value:SetPoint('RIGHT', plus, 'LEFT', -2, 0)
            gui.text_color(value, color.text.enabled)
            local minus = gui.button(r, gui.font_size.large)
            gui.set_size(minus, 26, 24)
            minus:SetPoint('RIGHT', value, 'LEFT', -2, 0)
            minus:SetText('-')
            return minus, value, plus
        end

        local function choices(r, options, btn_width)
            local buttons = {}
            local previous
            for i = #options, 1, -1 do
                local b = gui.button(r, gui.font_size.small)
                gui.set_size(b, btn_width, 24)
                if previous then
                    b:SetPoint('RIGHT', previous, 'LEFT', -3, 0)
                else
                    b:SetPoint('RIGHT', 0, 0)
                end
                b:SetText(options[i][2])
                buttons[options[i][1]] = b
                previous = b
            end
            return buttons
        end

        -- left column: Window
        section(parent, left_x, top_y, 'WINDOW')
        local opacity_minus, opacity_value, opacity_plus = stepper(row(parent, left_x, top_y - 16, 30, 'Background',
            nil, {'How solid the window is, from 50% to 100%. Text and buttons stay solid.', '/aux opacity'}))
        local scale_minus, scale_value, scale_plus = stepper(row(parent, left_x, top_y - 46, 30, 'Scale',
            nil, {'The size of the whole window, from 70% to 150%.', '/aux scale'}))
        opacity_minus:SetScript('OnClick', function() set_background_opacity(account_data.background_opacity - .05) end)
        opacity_plus:SetScript('OnClick', function() set_background_opacity(account_data.background_opacity + .05) end)
        scale_minus:SetScript('OnClick', function() change_window_scale((account_data.scale or 1) - .05) end)
        scale_plus:SetScript('OnClick', function() change_window_scale((account_data.scale or 1) + .05) end)

        -- the look, New or Classic. Widgets are built once with the look of this login, so a new choice
        -- shows after a reload; the button for it appears once there is one.
        local look_row = row(parent, left_x, top_y - 76, 30, 'Theme',
            nil, {'New: near black, square corners, gold accent. Classic: the theme of auxForever 0.5, slate panels, rounded corners, amber accent.', 'Shows after a reload.'})
        local look_buttons = choices(look_row, {{'new', 'New'}, {'classic', 'Classic'}}, 64)
        for name, b in pairs(look_buttons) do
            b:SetScript('OnClick', function()
                account_data.theme = name
                refresh_settings()
            end)
        end
        local reload_row = row(parent, left_x, top_y - 106, 28, '')
        local reload_note = reload_row.label
        reload_note:SetFont(gui.font, gui.font_size.small)
        gui.text_color(reload_note, color.label.enabled)
        local reload_button = gui.button(reload_row, gui.font_size.small)
        gui.set_size(reload_button, 90, 22)
        reload_button:SetPoint('RIGHT', 0, 0)
        reload_button:SetText('Reload now')
        gui.set_primary(reload_button)
        reload_button:SetScript('OnClick', function() ReloadUI() end)

        -- left column: Posting, Buying and General. Moves up when no reload is waiting (see refresh).
        local posting = CreateFrame('Frame', nil, parent)
        gui.set_size(posting, column, 276)
        section(posting, 0, 0, 'POSTING')
        local length_row = row(posting, 0, -16, 30, 'Default duration',
            nil, {'How long new auctions last unless you pick another length on the Post tab.', '/aux post duration'})
        local length_buttons = {}
        do
            local by_code = choices(length_row, {{1, ''}, {2, ''}, {3, ''}}, 38)
            for i = 1, 3 do
                length_buttons[i] = by_code[i]
                by_code[i]:SetScript('OnClick', function()
                    account_data.post_duration = i
                    refresh()
                end)
            end
        end

        -- 0.9 (FB-062, rokstar8872, deep_structure, bubbledn42; Tyler: on by default): right-click bag opens Post
        local right_click_row = row(posting, 0, -46, 36, 'Right-click bag to sell', 'Always opens Post tab',
            {'Right-clicking an item in your bags switches to the Post tab and loads it, even from Search or Sniper. Shift-click and Alt-click still use the current tab.', '/aux right click post'})
        local right_click_switch = gui.switch(right_click_row)
        right_click_switch:SetPoint('RIGHT', 0, 0)
        right_click_switch.on_click = function()
            set_right_click_post(not account_data.right_click_post)
        end

        -- Buying (0.8.2.2, FB-049 Confirm before buying; 0.9 build 4, FB-066 Default quantity)
        section(posting, 0, -92, 'BUYING')
        local confirm_row = row(posting, 0, -108, 36, 'Confirm before buying', 'A second click on Confirm',
            {'Buy first shows the price on a Confirm button, and a second click buys. Off: one click on Buy buys. For trade goods and gear, on the Search and Sniper tabs.', '/aux buy confirm'})
        local confirm_switch = gui.switch(confirm_row)
        confirm_switch:SetPoint('RIGHT', 0, 0)
        confirm_switch.on_click = function()
            set_buy_confirm(not account_data.buy_confirm)
        end

        local buy_default_row = row(posting, 0, -144, 30, 'Default quantity',
            nil, {'Starting quantity on the Search tab buy bar for trade goods: 1 (safer for one-click buying) or Stack (a full stack, capped by what is for sale). The Sniper always starts at the deal\'s units.', '/aux buy quantity'})
        local buy_default_buttons = choices(buy_default_row, {{'1', '1'}, {'stack', 'Stack'}}, 48)
        for mode, b in pairs(buy_default_buttons) do
            b:SetScript('OnClick', function()
                set_buy_default(mode)
            end)
        end

        -- 0.9: General (FB-032 Auto Full scan, FB-061 Professions cost line)
        section(posting, 0, -184, 'GENERAL')
        local auto_scan_row = row(posting, 0, -200, 36, 'Auto Full scan', 'When auction house opens',
            {'Starts a Full scan automatically when you open the auction house, if the 15-minute cooldown is over. Starting your own search or Post scan takes priority.', '/aux auto scan'})
        local auto_scan_switch = gui.switch(auto_scan_row)
        auto_scan_switch:SetPoint('RIGHT', 0, 0)
        auto_scan_switch.on_click = function()
            set_auto_full_scan(not account_data.auto_full_scan)
        end

        local crafting_row = row(posting, 0, -236, 36, 'Professions cost line', 'Materials and profit on recipes',
            {'Shows the Materials and Profit line under reagents in the Professions window. Turn off to hide it while keeping Search in aux at the auction house.', '/aux crafting cost'})
        local crafting_switch = gui.switch(crafting_row)
        crafting_switch:SetPoint('RIGHT', 0, 0)
        crafting_switch.on_click = function()
            set_crafting_cost(not account_data.crafting_cost)
        end

        -- right column: tooltip lines (per character; ANCHOR_LEFT keeps hover tooltips inside the window)
        local tooltip_title = section(parent, right_x, top_y, 'TOOLTIP LINES')
        local character_note = gui.label(parent, gui.font_size.small)
        character_note:SetPoint('LEFT', tooltip_title, 'RIGHT', 4, 0)
        character_note:SetText('(this character)')
        local tooltip_switches = {}
        local y = top_y - 16
        for i, line in ipairs(TOOLTIP_LINES) do
            local key = line[1]
            local height = line[3] and 36 or 30
            local r = row(parent, right_x, y, height, line[2], line[3], {line[4], '/aux tooltip'}, 'ANCHOR_LEFT')
            y = y - height
            local switch = gui.switch(r)
            switch:SetPoint('RIGHT', 0, 0)
            switch.key = key
            switch.row = r
            switch.on_click = function()
                character_data.tooltip[key] = not character_data.tooltip[key]
                refresh_settings()
            end
            tooltip_switches[i] = switch
        end

        local function refresh_one()
            if not (account_data and character_data) then return end
            local opacity = account_data.background_opacity
            opacity_value:SetText(percent(opacity))
            if opacity > gui.MIN_BACKGROUND_OPACITY + .001 then opacity_minus:Enable() else opacity_minus:Disable() end
            if opacity < .999 then opacity_plus:Enable() else opacity_plus:Disable() end
            local scale = account_data.scale or 1
            scale_value:SetText(percent(scale))
            if scale > MIN_SCALE + .001 then scale_minus:Enable() else scale_minus:Disable() end
            if scale < MAX_SCALE - .001 then scale_plus:Enable() else scale_plus:Disable() end
            for i, b in ipairs(length_buttons) do
                b:SetText(info.duration_hours(i) .. 'h')
                gui.style_choice(b, account_data.post_duration == i)
            end
            local buy_mode = account_data.buy_default == 'stack' and 'stack' or '1'
            for mode, b in pairs(buy_default_buttons) do
                gui.style_choice(b, buy_mode == mode)
            end
            local chosen = account_data.theme == 'classic' and 'classic' or 'new'
            for name, b in pairs(look_buttons) do
                gui.style_choice(b, chosen == name)
            end
            local pending = chosen ~= theme
            if pending then
                reload_note:SetText((chosen == 'new' and 'New' or 'Classic') .. ' theme after a reload')
                reload_row:Show()
            else
                reload_note:SetText('')
                reload_row:Hide()
            end
            if pending then reload_button:Show() else reload_button:Hide() end
            if resize_popup then
                parent:SetHeight(pending and 474 or 446)
            end
            posting:ClearAllPoints()
            posting:SetPoint('TOPLEFT', left_x, pending and (top_y - 142) or (top_y - 114))
            for _, switch in ipairs(tooltip_switches) do
                switch:SetChecked(character_data.tooltip[switch.key] and true or false)
            end
            confirm_switch:SetChecked(account_data.buy_confirm and true or false)
            right_click_switch:SetChecked(account_data.right_click_post and true or false)
            auto_scan_switch:SetChecked(account_data.auto_full_scan and true or false)
            crafting_switch:SetChecked(account_data.crafting_cost ~= false)
        end
        tinsert(refresh_views, refresh_one)

        return {
            scale_buttons = {scale_minus, scale_plus},
            scale_value = scale_value,
            look_buttons = look_buttons,
            reload_button = reload_button,
            reload_note = reload_note,
            auction_length_buttons = length_buttons,
            buy_confirm_switch = confirm_switch,
            buy_default_buttons = buy_default_buttons,
            right_click_post_switch = right_click_switch,
            auto_full_scan_switch = auto_scan_switch,
            crafting_cost_switch = crafting_switch,
            tooltip_boxes = tooltip_switches,
        }
    end

    -- 1. Auction house Settings gear popup
    local WIDTH, PAD, COLUMN = 600, 14, 271
    local popup = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    gui.set_panel_style(popup)
    popup:SetFrameStrata('DIALOG')
    -- 446 normally (474 when Theme reload is waiting): clean bottom margin inside MIN_HEIGHT = 549
    gui.set_size(popup, WIDTH, 446)
    popup:SetPoint('TOPRIGHT', btn, 'BOTTOMRIGHT', 0, -4)
    popup:EnableMouse(true)
    popup:Hide()
    settings_popup = popup

    local title = gui.label(popup, gui.font_size.small)
    title:SetPoint('TOPLEFT', PAD, -12)
    title:SetText('SETTINGS')
    gui.text_color(title, color.accent.background)

    local divider = popup:CreateTexture(nil, 'ARTWORK')
    divider:SetWidth(1)
    divider:SetPoint('TOPLEFT', WIDTH / 2, -34)
    divider:SetPoint('BOTTOMLEFT', WIDTH / 2, PAD)
    gui.texture_color(divider, color.window.border)

    local ah_view = build_settings_body(popup, -34, WIDTH, PAD, COLUMN, true)
    M.scale_buttons = ah_view.scale_buttons
    M.scale_value = ah_view.scale_value
    M.look_buttons = ah_view.look_buttons
    M.reload_button = ah_view.reload_button
    M.reload_note = ah_view.reload_note
    M.auction_length_buttons = ah_view.auction_length_buttons
    M.buy_confirm_switch = ah_view.buy_confirm_switch
    M.buy_default_buttons = ah_view.buy_default_buttons
    M.right_click_post_switch = ah_view.right_click_post_switch
    M.auto_full_scan_switch = ah_view.auto_full_scan_switch
    M.crafting_cost_switch = ah_view.crafting_cost_switch
    M.tooltip_boxes = ah_view.tooltip_boxes

    popup:SetScript('OnShow', function()
        refresh()
        gui.set_selected(btn, true)
    end)
    popup:SetScript('OnHide', function()
        gui.set_default(btn)
    end)
    -- a click anywhere else closes it
    pcall(popup.RegisterEvent, popup, 'GLOBAL_MOUSE_DOWN')
    popup:SetScript('OnEvent', function(self)
        if self:IsShown() and not self:IsMouseOver() and not btn:IsMouseOver() then
            self:Hide()
        end
    end)
    btn:SetScript('OnClick', function()
        if popup:IsShown() then popup:Hide() else popup:Show() end
    end)

    -- 2. Blizzard Options > AddOns > auxForever panel (0.9, FB-057, LLanwrst & jebbush)
    -- Accessible anywhere in the world via Escape > Options > AddOns > auxForever or /aux settings.
    StaticPopupDialogs.AUX_CLEAR_POST_CONFIRM = {
        text = 'Clear all saved Post tab prices for this realm and faction?',
        button1 = ACCEPT,
        button2 = CANCEL,
        OnAccept = function()
            clear_post_data()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopupDialogs.AUX_CLEAR_CACHE_CONFIRM = {
        text = 'Clear auxForever\'s saved item cache? Names rebuild automatically as you play.',
        button1 = ACCEPT,
        button2 = CANCEL,
        OnAccept = function()
            clear_item_cache()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    local OPT_WIDTH, OPT_PAD, OPT_COLUMN = 632, 16, 286
    local options_panel = CreateFrame('Frame')
    options_panel.name = 'auxForever'
    options_panel:Hide()

    local opt_logo = gui.label(options_panel, 20)
    opt_logo:SetFont(gui.font_bold, 20)
    opt_logo:SetPoint('TOPLEFT', OPT_PAD, -14)
    gui.themed(function() opt_logo:SetText(color.text.enabled'aux' .. color.accent.background'Forever') end)

    local opt_version = gui.label(options_panel, gui.font_size.small)
    opt_version:SetPoint('BOTTOMLEFT', opt_logo, 'BOTTOMRIGHT', 8, 2)
    local toc_version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata('auxForever', 'Version') or ''
    opt_version:SetText(gsub(toc_version, '^forever%-', ''))
    gui.text_color(opt_version, color.label.enabled)

    local opt_cmd = gui.label(options_panel, gui.font_size.small)
    opt_cmd:SetPoint('TOPRIGHT', options_panel, 'TOPLEFT', OPT_WIDTH - OPT_PAD, -22)
    opt_cmd:SetText('Open anywhere with /aux settings')
    gui.text_color(opt_cmd, color.label.enabled)

    local top_rule = options_panel:CreateTexture(nil, 'ARTWORK')
    top_rule:SetHeight(1)
    top_rule:SetWidth(OPT_WIDTH - OPT_PAD * 2)
    top_rule:SetPoint('TOPLEFT', OPT_PAD, -44)
    gui.texture_color(top_rule, color.window.border)

    local opt_divider = options_panel:CreateTexture(nil, 'ARTWORK')
    opt_divider:SetWidth(1)
    opt_divider:SetHeight(430)
    opt_divider:SetPoint('TOPLEFT', OPT_WIDTH / 2, -56)
    gui.texture_color(opt_divider, color.window.border)

    local blizz_view = build_settings_body(options_panel, -56, OPT_WIDTH, OPT_PAD, OPT_COLUMN, false)

    local bottom_rule = options_panel:CreateTexture(nil, 'ARTWORK')
    bottom_rule:SetHeight(1)
    bottom_rule:SetWidth(OPT_WIDTH - OPT_PAD * 2)
    bottom_rule:SetPoint('TOPLEFT', OPT_PAD, -496)
    gui.texture_color(bottom_rule, color.window.border)

    local keybind_note = gui.label(options_panel, gui.font_size.small)
    keybind_note:SetPoint('TOPLEFT', OPT_PAD, -514)
    keybind_note:SetText('Keybinds: Options > Keybindings > auxForever')
    gui.text_color(keybind_note, color.label.enabled)

    local clear_cache_btn = gui.button(options_panel, gui.font_size.small)
    gui.set_size(clear_cache_btn, 114, 24)
    clear_cache_btn:SetPoint('TOPRIGHT', options_panel, 'TOPLEFT', OPT_WIDTH - OPT_PAD, -506)
    clear_cache_btn:SetText('Clear item cache')
    clear_cache_btn:SetScript('OnClick', function()
        (show_popup or StaticPopup_Show)('AUX_CLEAR_CACHE_CONFIRM')
    end)

    local clear_post_btn = gui.button(options_panel, gui.font_size.small)
    gui.set_size(clear_post_btn, 118, 24)
    clear_post_btn:SetPoint('RIGHT', clear_cache_btn, 'LEFT', -8, 0)
    clear_post_btn:SetText('Clear post prices')
    clear_post_btn:SetScript('OnClick', function()
        (show_popup or StaticPopup_Show)('AUX_CLEAR_POST_CONFIRM')
    end)

    options_panel.OnRefresh = function() refresh() end
    options_panel:SetScript('OnShow', function() refresh() end)

    M.options_panel = options_panel
    M.options_view = blizz_view
    M.options_clear_post_button = clear_post_btn
    M.options_clear_cache_button = clear_cache_btn

    local settings_category_id
    function register_options_panel()
        if settings_category_id then return end
        if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
            local category = Settings.RegisterCanvasLayoutCategory(options_panel, 'auxForever')
            if category then
                settings_category_id = category.GetID and category:GetID() or category.ID
                Settings.RegisterAddOnCategory(category)
            end
        end
    end
    M.register_options_panel = register_options_panel

    function M.open_settings()
        if InCombatLockdown and InCombatLockdown() then
            print('Cannot open Blizzard Options during combat. Try again after combat.')
            return false, 'combat'
        end
        register_options_panel()
        if Settings and Settings.OpenToCategory and settings_category_id then
            Settings.OpenToCategory(settings_category_id)
            return true
        end
        print('Open Escape > Options > AddOns > auxForever to change settings.')
        return false, 'unavailable'
    end
end
do
    -- auxForever: credit to aux's creator, shown on every tab
    local label = gui.label(frame, gui.font_size.small)
    label:SetPoint('RIGHT', frame, 'BOTTOMRIGHT', -26, BOTTOM_BAR_HEIGHT / 2)
    label:SetText('aux by shirsig, re-imagined by a fan')
    gui.text_color(label, color.text.disabled)
    M.credit_label = label
end
