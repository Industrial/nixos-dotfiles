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
    -- the Sniper's notice has a Full scan button of its own that clicks this one (0.6 build 9)
    M.full_scan_button = btn
    btn:SetScript('OnClick', function()
        local count, shown_percent = 0
        scan.start{
            type = 'list',
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
            on_auction = function(auction_record, total)
                count = count + 1
                status_bar:update_status(count / total, 0)
                local percent = floor(count / total * 100)
                if percent ~= shown_percent then
                    shown_percent = percent
                    status_bar:set_text(format('Full scan: reading auctions, %d%%', percent))
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

    -- auxForever (0.6): two columns, as in the mockup Tyler approved (2026-10-08): Window and Posting
    -- on the left, the tooltip lines on the right, each setting a row with its control at the right.
    -- The player-facing name of a look is "theme" (Tyler, build 4).
    local WIDTH, PAD, COLUMN = 600, 14, 271
    local LEFT_X, RIGHT_X = PAD, WIDTH - PAD - COLUMN
    local popup = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    gui.set_panel_style(popup)
    popup:SetFrameStrata('DIALOG')
    -- 322: the tooltip column's rows (Usually added in 0.8.2) plus the padding
    gui.set_size(popup, WIDTH, 322)
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

    local function section(parent, x, y, text)
        local label = gui.label(parent, gui.font_size.small)
        label:SetPoint('TOPLEFT', x, y)
        label:SetText(text)
        gui.text_color(label, color.accent.background)
        return label
    end

    -- a row: its name on the left (with a short gray line under it when there is a hint), its
    -- control at the right; hovering the row explains it
    local function row(parent, x, y, height, name, hint, tip)
        local r = CreateFrame('Frame', nil, parent)
        r:SetPoint('TOPLEFT', x, y)
        gui.set_size(r, COLUMN, height)
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
            r:SetScript('OnEnter', function(self)
                GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                GameTooltip:AddLine(name)
                GameTooltip:AddLine(tip[1], 1, 1, 1, true)
                if tip[2] then GameTooltip:AddLine(tip[2], .6, .6, .6) end
                GameTooltip:Show()
            end)
            r:SetScript('OnLeave', function() GameTooltip:Hide() end)
        end
        return r
    end

    -- a value with - and + at the right of a row
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

    -- one lit option out of a few, right-aligned; returns the buttons by key
    local function choices(r, options, width)
        local buttons = {}
        local previous
        for i = #options, 1, -1 do
            local b = gui.button(r, gui.font_size.small)
            gui.set_size(b, width, 24)
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

    local function percent(x) return floor(x * 100 + .5) .. '%' end

    -- left column: Window
    section(popup, LEFT_X, -34, 'WINDOW')
    local opacity_minus, opacity_value, opacity_plus = stepper(row(popup, LEFT_X, -50, 30, 'Background',
        nil, {'How solid the window is, from 50% to 100%. Text and buttons stay solid.', '/aux opacity'}))
    local scale_minus, scale_value, scale_plus = stepper(row(popup, LEFT_X, -80, 30, 'Scale',
        nil, {'The size of the whole window, from 70% to 150%.', '/aux scale'}))
    M.scale_buttons = {scale_minus, scale_plus}
    M.scale_value = scale_value

    -- the look, New or Classic. Widgets are built once with the look of this login, so a new choice
    -- shows after a reload; the button for it appears once there is one.
    local look_row = row(popup, LEFT_X, -110, 30, 'Theme',
        nil, {'New: near black, square corners, gold accent. Classic: the theme of auxForever 0.5, slate panels, rounded corners, amber accent.', 'Shows after a reload.'})
    local look_buttons = choices(look_row, {{'new', 'New'}, {'classic', 'Classic'}}, 64)
    for name, b in pairs(look_buttons) do
        b:SetScript('OnClick', function()
            account_data.theme = name
            refresh_settings()
        end)
    end
    local reload_row = row(popup, LEFT_X, -140, 28, '')
    local reload_note = reload_row.label
    reload_note:SetFont(gui.font, gui.font_size.small)
    gui.text_color(reload_note, color.label.enabled)
    local reload_button = gui.button(reload_row, gui.font_size.small)
    gui.set_size(reload_button, 90, 22)
    reload_button:SetPoint('RIGHT', 0, 0)
    reload_button:SetText('Reload now')
    gui.set_primary(reload_button)
    reload_button:SetScript('OnClick', function() ReloadUI() end)
    M.look_buttons, M.reload_button, M.reload_note = look_buttons, reload_button, reload_note

    -- left column: Posting. It moves up when no reload is waiting (see refresh).
    local posting = CreateFrame('Frame', nil, popup)
    gui.set_size(posting, COLUMN, 100)
    section(posting, 0, 0, 'POSTING')
    local length_row = row(posting, 0, -16, 30, 'Default duration',
        nil, {'How long new auctions last unless you pick another length on the Post tab.', '/aux post duration'})
    local length_buttons = {}
    do
        -- the hours come from the auction house (util/info.lua, loaded later): written in refresh
        local by_code = choices(length_row, {{1, ''}, {2, ''}, {3, ''}}, 38)
        for i = 1, 3 do length_buttons[i] = by_code[i] end
    end
    M.auction_length_buttons = length_buttons
    -- Bid prices (/aux post bid) was here in build 3 and taken out in build 4: on Forever only gear
    -- can have bids, few sellers set one, and gear is one item per auction, so "per stack" means
    -- nothing (Tyler: "does the stack option even make any sense?"). The chat command stays.

    -- right column: the tooltip lines, also /aux tooltip ... (a player on CurseForge asked for the
    -- chat settings in this menu, FB-008). Kept per character, like the chat commands.
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
        {'money_icons', 'Coin icons', 'Gold, silver and copper coins', 'Show prices in tooltips with gold, silver and copper coins instead of text.'},
    }
    local tooltip_title = section(popup, RIGHT_X, -34, 'TOOLTIP LINES')
    local character_note = gui.label(popup, gui.font_size.small)
    character_note:SetPoint('LEFT', tooltip_title, 'RIGHT', 4, 0)
    character_note:SetText('(this character)')
    local tooltip_switches = {}
    local y = -50
    for i, line in ipairs(TOOLTIP_LINES) do
        local key = line[1]
        local height = line[3] and 36 or 30
        local r = row(popup, RIGHT_X, y, height, line[2], line[3], {line[4], '/aux tooltip'})
        y = y - height
        local switch = gui.switch(r)
        switch:SetPoint('RIGHT', 0, 0)
        switch.key = key
        switch.on_click = function()
            character_data.tooltip[key] = not character_data.tooltip[key]
            refresh_settings()
        end
        tooltip_switches[i] = switch
    end
    M.tooltip_boxes = tooltip_switches

    local function refresh()
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
        local chosen = account_data.theme == 'classic' and 'classic' or 'new'
        for name, b in pairs(look_buttons) do
            gui.style_choice(b, chosen == name)
        end
        -- a reload is only needed when the choice differs from what is on screen
        local pending = chosen ~= theme
        if pending then
            reload_note:SetText((chosen == 'new' and 'New' or 'Classic') .. ' theme after a reload')
            reload_row:Show()
        else
            reload_note:SetText('')
            reload_row:Hide()
        end
        if pending then reload_button:Show() else reload_button:Hide() end
        posting:ClearAllPoints()
        posting:SetPoint('TOPLEFT', LEFT_X, pending and -176 or -148)
        for _, switch in ipairs(tooltip_switches) do
            switch:SetChecked(character_data.tooltip[switch.key] and true or false)
        end
    end
    M.refresh_settings = refresh
    function M.set_background_opacity(opacity)
        account_data.background_opacity = gui.set_background_opacity(opacity)
        refresh()
    end
    function M.change_window_scale(scale)
        account_data.scale = set_window_scale(scale)
        refresh()
    end
    opacity_minus:SetScript('OnClick', function() set_background_opacity(account_data.background_opacity - .05) end)
    opacity_plus:SetScript('OnClick', function() set_background_opacity(account_data.background_opacity + .05) end)
    scale_minus:SetScript('OnClick', function() change_window_scale((account_data.scale or 1) - .05) end)
    scale_plus:SetScript('OnClick', function() change_window_scale((account_data.scale or 1) + .05) end)
    for i, b in ipairs(length_buttons) do
        b:SetScript('OnClick', function()
            account_data.post_duration = i
            refresh()
        end)
    end

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
end
do
    -- auxForever: credit to aux's creator, shown on every tab
    local label = gui.label(frame, gui.font_size.small)
    label:SetPoint('RIGHT', frame, 'BOTTOMRIGHT', -26, BOTTOM_BAR_HEIGHT / 2)
    label:SetText('aux by shirsig, re-imagined by a fan')
    gui.text_color(label, color.text.disabled)
    M.credit_label = label
end
