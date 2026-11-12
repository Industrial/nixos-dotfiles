select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local gui = require 'aux.gui'
local completion = require 'aux.util.completion'

-- auxForever: the right side of the Filter Builder, "Only show auctions where". Conditions in plain
-- words, Match All / Any, a "not" switch on every row and group, and groups inside groups (aux's
-- and/or/not). The tree lives in filter.lua; this file draws it as rows and edits it.

local TEXTURES = [[Interface\AddOns\auxForever\textures\]]
local RIGHT_X = 348
local ROW_HEIGHT = 30
local ROW_GAP = 4
local INDENT = 24
local TYPE_WIDTH = 176
local VALUE_WIDTH = 112
local CROSS = '\195\151'

local rows_frame, rows_child, empty_hint, words_text, words_box
local row_pool, box_pool = {}, {}
M.builder_rows = row_pool

local function choice_button(parent, text, width)
    local btn = gui.button(parent, gui.font_size.small)
    gui.set_size(btn, width or 40, 22)
    btn:SetText(text)
    return btn
end

local function caption(parent, text, size, color)
    local label = gui.label(parent, size or gui.font_size.small)
    label:SetText(text)
    gui.text_color(label, color or aux.color.label.enabled)
    return label
end

local function tooltip(widget, title, text)
    widget:HookScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:AddLine(title)
        if text then
            GameTooltip:AddLine(text, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    widget:HookScript('OnLeave', function() GameTooltip:Hide() end)
end

-- the "not" switch: red when on
local function style_not(btn, on)
    if on then
        btn:SetBackdropColor(.23, .10, .09, 1)
        btn:SetBackdropBorderColor(.77, .35, .29, 1)
        btn:GetFontString():SetTextColor(1, .6, .54)
    else
        btn:SetBackdropColor(0, 0, 0, 0)
        btn:SetBackdropBorderColor(aux.color.content.border())
        btn:GetFontString():SetTextColor(aux.color.label.disabled())
    end
end

-- One menu for picking a condition (in columns with headers) or one of a condition's choices.
local menu, menu_buttons, menu_labels = nil, {}, {}
local function create_menu()
    menu = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    gui.set_panel_style(menu)
    menu:SetFrameStrata('DIALOG')
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:Hide()
    pcall(menu.RegisterEvent, menu, 'GLOBAL_MOUSE_DOWN')
    menu:SetScript('OnEvent', function(self)
        if self:IsShown() and not self:IsMouseOver() and not (self.anchor and self.anchor:IsMouseOver()) then
            self:Hide()
        end
    end)
    frame:HookScript('OnHide', function() menu:Hide() end)
    M.builder_menu = menu
    M.builder_menu_buttons = menu_buttons
end

-- columns: { {header = 'Price', entries = { {text, detail, value}, ... }}, ... }; several sections
-- can share a column by giving the same column number
local function open_menu(anchor, sections, on_pick, column_width)
    if not menu then
        create_menu()
    end
    column_width = column_width or 240
    for _, b in ipairs(menu_buttons) do b:Hide() end
    for _, l in ipairs(menu_labels) do l:Hide() end
    local used_buttons, used_labels = 0, 0
    local column_y, columns = {}, 0
    for _, section in ipairs(sections) do
        local column = section.column or 1
        columns = max(columns, column)
        local x, y = 8 + (column - 1) * (column_width + 8), column_y[column] or 10
        if section.header then
            used_labels = used_labels + 1
            local label = menu_labels[used_labels] or caption(menu, '', gui.font_size.small, aux.color.accent.background)
            menu_labels[used_labels] = label
            label:SetText(strupper(section.header))
            label:ClearAllPoints()
            label:SetPoint('TOPLEFT', menu, 'TOPLEFT', x + 6, -y)
            label:Show()
            y = y + 18
        end
        for _, entry in ipairs(section.entries) do
            used_buttons = used_buttons + 1
            local btn = menu_buttons[used_buttons]
            if not btn then
                btn = CreateFrame('Button', nil, menu)
                btn.highlight = gui.add_highlight(btn, 5, 1, 1, 1, .07)
                btn.text = gui.label(btn, gui.font_size.medium)
                btn.text:SetPoint('TOPLEFT', 6, -4)
                btn.text:SetPoint('RIGHT', -6, 0)
                btn.text:SetJustifyH('LEFT')
                btn.detail = gui.label(btn, gui.font_size.small)
                btn.detail:SetPoint('BOTTOMLEFT', 6, 4)
                btn.detail:SetPoint('RIGHT', -6, 0)
                btn.detail:SetJustifyH('LEFT')
                btn:SetScript('OnClick', function(self)
                    menu:Hide()
                    menu.on_pick(self.value)
                end)
                menu_buttons[used_buttons] = btn
            end
            btn.value = entry.value
            btn.text:SetText(entry.text)
            btn.text:SetTextColor(aux.color.text.enabled())
            btn.detail:SetText(entry.detail or '')
            local height = entry.detail and 36 or 24
            btn:SetSize(column_width, height)
            btn:ClearAllPoints()
            btn:SetPoint('TOPLEFT', menu, 'TOPLEFT', x, -y)
            btn:Show()
            y = y + height + 2
        end
        column_y[column] = y + 6
    end
    local height = 0
    for _, y in pairs(column_y) do height = max(height, y) end
    menu:SetSize(8 + columns * (column_width + 8), height + 4)
    menu.on_pick, menu.anchor = on_pick, anchor
    menu:ClearAllPoints()
    menu:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -3)
    menu:Show()
end

local function condition_sections()
    local sections = {}
    local column_of = {Price = 1, Profit = 1, Item = 2, Auction = 2}
    for _, group in ipairs(CONDITION_GROUPS) do
        local section = {header = group, column = column_of[group], entries = {}}
        for _, c in ipairs(CONDITIONS) do
            if c.group == group then
                local text = c.label .. (c.op ~= '' and ', ' .. c.op or '')
                tinsert(section.entries, {text = text .. '  ' .. aux.color.accent.background(c.key), detail = c.hint, value = c.key})
            end
        end
        tinsert(sections, section)
    end
    return sections
end

function M.open_condition_menu(anchor, on_pick)
    open_menu(anchor, condition_sections(), on_pick, 250)
end

-- Rows ---------------------------------------------------------------------------------------------

local rebuild

local function changed()
    sync_builder()
    rebuild()
end

local function focus_value(node)
    for _, row in ipairs(row_pool) do
        if row:IsShown() and row.item and row.item.node == node and row.value_box:IsShown() then
            row.value_box:SetFocus()
            return
        end
    end
end

local function create_row()
    local row = CreateFrame('Frame', nil, rows_child)
    row:SetHeight(ROW_HEIGHT)

    row.not_btn = choice_button(row, 'not', 36)
    row.not_btn:SetPoint('LEFT', 4, 0)
    row.not_btn:SetScript('OnClick', function()
        row.item.node.negated = not row.item.node.negated
        changed()
    end)
    tooltip(row.not_btn, 'Not', 'Turns this condition (or the whole group) around: the auction must NOT match it.')

    -- condition rows
    row.type_btn = gui.button(row, gui.font_size.medium)
    gui.set_size(row.type_btn, TYPE_WIDTH, 24)
    row.type_btn:SetPoint('LEFT', row.not_btn, 'RIGHT', 6, 0)
    row.type_btn.label:ClearAllPoints()
    row.type_btn.label:SetPoint('LEFT', 8, 0)
    row.type_btn.label:SetPoint('RIGHT', -22, 0)
    row.type_btn.label:SetJustifyH('LEFT')
    row.type_btn.chevron = row.type_btn:CreateTexture(nil, 'ARTWORK')
    row.type_btn.chevron:SetTexture(TEXTURES .. 'chevron.tga')
    row.type_btn.chevron:SetSize(9, 9)
    row.type_btn.chevron:SetPoint('RIGHT', -8, 0)
    gui.vertex_color(row.type_btn.chevron, aux.color.label.enabled)
    row.type_btn:SetScript('OnClick', function(self)
        open_condition_menu(self, function(key)
            local node = row.item.node
            if key ~= node.filter then
                node.filter, node.value = key, nil
            end
            changed()
            focus_value(node)
        end)
    end)

    row.op = caption(row, '', gui.font_size.medium)
    row.op:SetWidth(58)
    row.op:SetJustifyH('CENTER')
    row.op:SetPoint('LEFT', row.type_btn, 'RIGHT', 4, 0)

    row.value_box = gui.editbox(row)
    gui.set_size(row.value_box, VALUE_WIDTH, 24)
    row.value_box:SetPoint('LEFT', row.op, 'RIGHT', 4, 0)
    row.value_box.change = function(self, is_user_input)
        if is_user_input and row.item then
            row.item.node.value = self:GetText()
            row:update_validity()
            sync_builder()
        end
    end
    row.value_box.enter = function(self) self:ClearFocus() end
    row.value_box.char = function(self)
        if self.complete then self:complete() end
    end

    row.value_btn = gui.button(row, gui.font_size.medium)
    gui.set_size(row.value_btn, VALUE_WIDTH, 24)
    row.value_btn:SetPoint('LEFT', row.op, 'RIGHT', 4, 0)
    row.value_btn:SetScript('OnClick', function(self)
        local node = row.item.node
        local entries = {}
        for _, choice in ipairs(condition_choices(node.filter) or empty) do
            tinsert(entries, {text = choice, value = choice})
        end
        open_menu(self, {{entries = entries}}, function(choice)
            node.value = choice
            changed()
        end, VALUE_WIDTH)
    end)

    row.unit = caption(row, '%', gui.font_size.medium)
    row.unit:SetPoint('LEFT', row.value_box, 'RIGHT', 4, 0)

    row.hint = caption(row, '', gui.font_size.small, aux.color.label.disabled)
    row.hint:SetJustifyH('LEFT')

    row.remove = choice_button(row, CROSS, 24)
    row.remove:SetPoint('RIGHT', -4, 0)
    gui.themed(function()
        row.remove:SetBackdropColor(0, 0, 0, 0)
        row.remove:SetBackdropBorderColor(0, 0, 0, 0)
        row.remove:GetFontString():SetTextColor(aux.color.label.enabled())
    end)
    row.remove:SetScript('OnClick', function()
        local item = row.item
        for i, node in ipairs(item.parent.items) do
            if node == item.node then
                tremove(item.parent.items, i)
                break
            end
        end
        changed()
    end)

    -- group header rows
    row.group_label = caption(row, 'Group: match', gui.font_size.medium)
    row.group_label:SetPoint('LEFT', row.not_btn, 'RIGHT', 8, 0)
    row.all_btn = choice_button(row, 'All', 40)
    row.all_btn:SetPoint('LEFT', row.group_label, 'RIGHT', 8, 0)
    row.any_btn = choice_button(row, 'Any', 40)
    row.any_btn:SetPoint('LEFT', row.all_btn, 'RIGHT', 2, 0)
    row.of_these = caption(row, 'of these', gui.font_size.medium)
    row.of_these:SetPoint('LEFT', row.any_btn, 'RIGHT', 8, 0)
    row.all_btn:SetScript('OnClick', function() row.item.node.mode = 'and' changed() end)
    row.any_btn:SetScript('OnClick', function() row.item.node.mode = 'or' changed() end)
    tooltip(row.all_btn, 'Match all', 'Every condition in this group must be true. Faded while the group has fewer than two conditions: then it makes no difference.')
    tooltip(row.any_btn, 'Match any', 'At least one condition in this group must be true. Faded while the group has fewer than two conditions: then it makes no difference.')

    -- "+ Condition" / "+ Group" rows
    row.add_cond = gui.button(row, gui.font_size.medium)
    gui.set_size(row.add_cond, 104, 24)
    row.add_cond:SetPoint('LEFT', 4, 0)
    row.add_cond:SetText('+ Condition')
    row.add_cond:SetScript('OnClick', function(self)
        local group = row.item.group
        open_condition_menu(self, function(key)
            local node = new_condition(key)
            tinsert(group.items, node)
            changed()
            focus_value(node)
        end)
    end)
    row.add_group = gui.button(row, gui.font_size.medium)
    gui.set_size(row.add_group, 84, 24)
    row.add_group:SetPoint('LEFT', row.add_cond, 'RIGHT', 6, 0)
    row.add_group:SetText('+ Group')
    row.add_group:SetScript('OnClick', function()
        tinsert(row.item.group.items, new_group(row.item.group.mode == 'and' and 'or' or 'and'))
        changed()
    end)
    tooltip(row.add_group, 'Group', 'A box of conditions with its own All / Any switch, for searches like "cheap, AND (from this seller OR ending soon)". Groups can hold groups.')

    function row:update_validity()
        local node = self.item.node
        local bad = node.value and aux.trim(node.value) ~= '' and not condition_complete(node)
        if bad then
            self.value_box:SetBackdropBorderColor(aux.color.negative())
        else
            self.value_box:SetBackdropBorderColor(aux.color.input.border())
        end
    end

    return row
end

-- an All / Any switch with fewer than two conditions under it changes nothing: shown faded
local function style_match(all_btn, any_btn, group)
    gui.style_choice(all_btn, group.mode == 'and')
    gui.style_choice(any_btn, group.mode == 'or')
    local idle = active_count(group) < 2
    for _, btn in ipairs{all_btn, any_btn} do
        btn.idle = idle
        btn:SetAlpha(idle and .45 or 1)
    end
end

local function show_only(row, kind)
    local sets = {
        cond = {'not_btn', 'type_btn', 'op', 'hint', 'remove'},
        group = {'not_btn', 'group_label', 'all_btn', 'any_btn', 'of_these', 'remove'},
        add = {'add_cond', 'add_group'},
    }
    for _, name in ipairs{'not_btn', 'type_btn', 'op', 'value_box', 'value_btn', 'unit', 'hint', 'remove', 'group_label', 'all_btn', 'any_btn', 'of_these', 'add_cond', 'add_group'} do
        row[name]:Hide()
    end
    for _, name in ipairs(sets[kind]) do
        row[name]:Show()
    end
end

local function fill_condition(row, node)
    local c = condition_info(node.filter)
    row.type_btn:SetText(c.label)
    row.op:SetText(c.op)
    local input_type = input_type(node.filter)
    local value_anchor
    if condition_choices(node.filter) then
        row.value_btn:Show()
        row.value_btn:SetText(node.value or 'Choose')
        if node.value then
            row.value_btn:GetFontString():SetTextColor(aux.color.text.enabled())
        else
            row.value_btn:GetFontString():SetTextColor(aux.color.label.disabled())
        end
        value_anchor = row.value_btn
    elseif input_type ~= '' then
        row.value_box:Show()
        if not row.value_box:HasFocus() then
            row.value_box:SetText(node.value or '')
        end
        row.value_box:SetNumeric(input_type == 'number')
        row.value_box.complete = node.filter == 'item' and completion.complete(function() return aux.account_data.auctionable_items end) or nil
        row:update_validity()
        value_anchor = row.value_box
        if c.unit then
            row.unit:SetText(c.unit)
            row.unit:Show()
            value_anchor = row.unit
        end
    end
    row.hint:ClearAllPoints()
    row.hint:SetPoint('LEFT', value_anchor or row.op, 'RIGHT', 10, 0)
    row.hint:SetPoint('RIGHT', row.remove, 'LEFT', -6, 0)
    row.hint:SetText(c.hint)
    style_not(row.not_btn, node.negated)
end

local function flatten(group, depth, list)
    for _, node in ipairs(group.items) do
        if node.kind == 'cond' then
            tinsert(list, {kind = 'cond', node = node, parent = group, depth = depth})
        else
            local header = {kind = 'group', node = node, parent = group, depth = depth}
            tinsert(list, header)
            flatten(node, depth + 1, list)
            local add = {kind = 'add', group = node, depth = depth + 1}
            tinsert(list, add)
            header.add_row = add
        end
    end
end

function rebuild()
    if not rows_child then return end
    local root = get_builder_root()
    local list = {}
    flatten(root, 0, list)
    tinsert(list, {kind = 'add', group = root, depth = 0})

    local width = rows_frame:GetWidth()
    rows_child:SetWidth(width)
    local y = 4
    for i, item in ipairs(list) do
        local row = row_pool[i] or create_row()
        row_pool[i] = row
        row.item = item
        item.row = row
        show_only(row, item.kind)
        if item.kind == 'group' then
            y = y + 4
        end
        row:ClearAllPoints()
        row:SetPoint('TOPLEFT', rows_child, 'TOPLEFT', item.depth * INDENT, -y)
        row:SetPoint('RIGHT', rows_child, 'RIGHT', -item.depth * 6, 0)
        row:SetFrameLevel(rows_child:GetFrameLevel() + 20)
        if item.kind == 'cond' then
            fill_condition(row, item.node)
        elseif item.kind == 'group' then
            style_not(row.not_btn, item.node.negated)
            style_match(row.all_btn, row.any_btn, item.node)
        end
        row:Show()
        y = y + ROW_HEIGHT + ROW_GAP
        if item.kind == 'add' and item.group ~= root then
            y = y + 6
        end
    end
    for i = #list + 1, #row_pool do
        row_pool[i]:Hide()
        row_pool[i].item = nil
    end

    -- a box around each group, from its header row to its "+ Condition" row
    local boxes = 0
    for _, item in ipairs(list) do
        if item.kind == 'group' then
            boxes = boxes + 1
            local box = box_pool[boxes]
            if not box then
                box = CreateFrame('Frame', nil, rows_child, 'BackdropTemplate')
                gui.set_frame_style(box, aux.color.panel.background, aux.color.input.border, nil, nil, nil, nil, 7)
                box_pool[boxes] = box
            end
            box:ClearAllPoints()
            box:SetPoint('TOPRIGHT', item.row, 'TOPRIGHT', 2, 3)
            box:SetPoint('BOTTOMLEFT', item.add_row.row, 'BOTTOMLEFT', -INDENT - 2, -4)
            box:SetFrameLevel(rows_child:GetFrameLevel() + 1 + item.depth)
            box:Show()
        end
    end
    for i = boxes + 1, #box_pool do
        box_pool[i]:Hide()
    end

    style_match(root_all_button, root_any_button, root)
    rows_child:SetHeight(y + 8)
    empty_hint:SetShown(#root.items == 0)
    update_builder_words()
end

function M.update_builder()
    rebuild()
end

function M.update_builder_words()
    if words_text then
        words_text:SetTextColor(aux.color.text.enabled())
        words_text:SetText(builder_words())
    end
end

function M.show_builder_error(error)
    if words_text then
        words_text:SetTextColor(aux.color.negative())
        words_text:SetText('The search bar text cannot be shown here yet: ' .. (error or 'unknown error') .. '. Fix it there, or press Clear all.')
    end
end

-- Layout ---------------------------------------------------------------------------------------------

do
    local title = caption(frame.filter, 'WHICH ITEMS', gui.font_size.small, aux.color.accent.background)
    title:SetPoint('TOPLEFT', 14, -12)
    local note = caption(frame.filter, 'Asked from the auction house. The narrower, the faster.', gui.font_size.small)
    note:SetPoint('TOPLEFT', 14, -28)
end

do
    local title = caption(frame.filter, 'ONLY SHOW AUCTIONS WHERE', gui.font_size.small, aux.color.accent.background)
    title:SetPoint('TOPLEFT', RIGHT_X, -12)
    local note = caption(frame.filter, 'Checked on every result as it comes in.', gui.font_size.small)
    note:SetPoint('TOPLEFT', RIGHT_X, -28)

    local of_these = caption(frame.filter, 'of these', gui.font_size.medium)
    of_these:SetPoint('TOPRIGHT', -16, -16)
    local any = choice_button(frame.filter, 'Any', 44)
    any:SetPoint('RIGHT', of_these, 'LEFT', -8, 0)
    local all = choice_button(frame.filter, 'All', 44)
    all:SetPoint('RIGHT', any, 'LEFT', -2, 0)
    local match = caption(frame.filter, 'Match', gui.font_size.medium)
    match:SetPoint('RIGHT', all, 'LEFT', -8, 0)
    all:SetScript('OnClick', function()
        get_builder_root().mode = 'and'
        sync_builder()
        update_builder()
    end)
    any:SetScript('OnClick', function()
        get_builder_root().mode = 'or'
        sync_builder()
        update_builder()
    end)
    tooltip(all, 'Match all', 'An auction is shown only when every condition below is true. Faded while there are fewer than two conditions here: then it makes no difference.')
    tooltip(any, 'Match any', 'An auction is shown when at least one condition below is true. Faded while there are fewer than two conditions here: then it makes no difference.')
    root_all_button, root_any_button = all, any
end

do
    local box = CreateFrame('Frame', nil, frame.filter, 'BackdropTemplate')
    gui.set_frame_style(box, aux.color.input.background, aux.color.panel.border, nil, nil, nil, nil, 6)
    box:SetPoint('BOTTOMLEFT', frame.filter, 'BOTTOMLEFT', RIGHT_X, 10)
    box:SetPoint('BOTTOMRIGHT', frame.filter, 'BOTTOMRIGHT', -16, 10)
    box:SetHeight(52)
    local label = caption(box, 'In words:', gui.font_size.small)
    label:SetPoint('TOPLEFT', 10, -8)
    local text = caption(box, '', gui.font_size.small, aux.color.text.enabled)
    text:SetPoint('TOPLEFT', label, 'TOPRIGHT', 8, 0)
    text:SetPoint('RIGHT', -10, 0)
    text:SetJustifyH('LEFT')
    text:SetJustifyV('TOP')
    text:SetWordWrap(true)
    text:SetHeight(40)
    words_box, words_text = box, text
    M.builder_words_text = text
end

do
    local scroll = CreateFrame('ScrollFrame', nil, frame.filter)
    scroll:SetPoint('TOPLEFT', frame.filter, 'TOPLEFT', RIGHT_X, -50)
    scroll:SetPoint('BOTTOMRIGHT', words_box, 'TOPRIGHT', 0, 8)
    scroll:EnableMouseWheel(true)
    local child = CreateFrame('Frame', nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript('OnMouseWheel', function(self, delta)
        local max_scroll = max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(aux.bounded(0, max_scroll, self:GetVerticalScroll() - delta * (ROW_HEIGHT + ROW_GAP)))
    end)
    scroll:SetScript('OnSizeChanged', function() rebuild() end)
    rows_frame, rows_child = scroll, child

    empty_hint = caption(frame.filter, 'No conditions yet, so every auction the search finds is shown. Add one to narrow it down.', gui.font_size.small)
    empty_hint:SetPoint('TOPLEFT', scroll, 'TOPLEFT', 4, -(ROW_HEIGHT + ROW_GAP + 10))
    empty_hint:SetPoint('RIGHT', scroll, 'RIGHT', -4, 0)
    empty_hint:SetJustifyH('LEFT')
    empty_hint:SetWordWrap(true)
end

do
    local clear = gui.button(frame.filter)
    clear:SetPoint('LEFT', aux.status_bar, 'RIGHT', 5, 0)
    clear:SetText('Clear all')
    clear:SetWidth(90)
    clear:SetScript('OnClick', clear_builder)
    tooltip(clear, 'Clear all', 'Empties the builder and the search bar.')

    local save = gui.button(frame.filter)
    save:SetPoint('LEFT', clear, 'RIGHT', 5, 0)
    save:SetText('Save to favorites')
    save:SetWidth(150)
    save:SetScript('OnClick', function()
        save_favorite(search_box:GetText())
    end)
    M.builder_clear_button, M.builder_save_button = clear, save
end

-- typing in the search bar while the builder is open shows the change here too
do
    local change = search_box.change
    search_box.change = function(self, is_user_input)
        do (change or pass)(self, is_user_input) end
        if is_user_input and frame.filter:IsShown() and not is_syncing() then
            load_builder()
        end
    end
end
