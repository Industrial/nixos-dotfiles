select(2, ...) 'aux.gui.item_listing'

local aux = require 'aux'
local info = require 'aux.util.info'
local gui = require 'aux.gui'

local ROW_HEIGHT = 39

function M:render()

	if #(self.item_records or empty) > #self.rows then
		self.content_frame:SetPoint('BOTTOMRIGHT', -15, 0)
	else
		self.content_frame:SetPoint('BOTTOMRIGHT', 0, 0)
	end

	FauxScrollFrame_Update(self.scroll_frame, #self.item_records, #self.rows, ROW_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(self.scroll_frame)

	local rows = self.rows

	for i, row in pairs(rows) do
		local item_record = self.item_records[i + offset]

        if item_record then
			row.item_record = item_record
			if self.selected and self.selected(item_record) then
				row.highlight:Show()
			else
				row.highlight:Hide()
			end
			row.item.texture:SetTexture(item_record.texture)
			row.item.name:SetText('[' .. item_record.name .. ']')
			local color = ITEM_QUALITY_COLORS[item_record.quality]
			row.item.name:SetTextColor(color.r, color.g, color.b)
			if item_record.count > 1 then
				row.item.count:SetText(item_record.count)
			else
				row.item.count:SetText()
			end
            row:Show()
        else
            row:Hide()
        end
	end
end

local function create_row(item_listing, row_index)
	local content_frame, selected = item_listing.content_frame, item_listing.selected
	local row = CreateFrame('Frame', nil, content_frame)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint('TOPLEFT', content_frame, 0, -((row_index - 1) * ROW_HEIGHT))
	row:SetPoint('TOPRIGHT', content_frame, 0, -((row_index - 1) * ROW_HEIGHT))
	row:EnableMouse(true)
	row:SetScript('OnMouseUp', item_listing.on_click)
	-- auxForever (0.5, docs/clicks.md): the row's clicks in a gray line
	local HINT = 'Click: select to post' .. gui.HINT_SEPARATOR .. 'Right-click: search'
	row:SetScript('OnEnter', function()
		row.mouseover = true
		row.hover:Show()
		if row.item_record then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			gui.add_click_hint(GameTooltip, HINT, true)
			GameTooltip:Show()
		end
	end)
	row:SetScript('OnLeave', function()
		row.mouseover = false
		GameTooltip:Hide()
		row.hover:Hide()
	end)

	row.item = gui.item(row)
	row.item:SetScale(.9)
	row.item:SetPoint('LEFT', 2.5, 0)
	row.item:SetPoint('RIGHT', -2.5, 0)
	row.item.button:SetScript('OnEnter', function(self)
		info.set_tooltip(row.item_record.link, self, 'ANCHOR_RIGHT')
		gui.add_click_hint(GameTooltip, HINT)
		GameTooltip:Show()
	end)
	row.item.button:SetScript('OnLeave', function() GameTooltip:Hide() end)
	-- auxForever (0.6.1.1, FB-011): the icon catches the mouse for its tooltip, so a click on it
	-- never reached the row. It now does the same as a click on the name.
	row.item.button:SetScript('OnMouseUp', function(_, button) item_listing.on_click(row, button) end)

	row.highlight = gui.row_selection(row)
	row.hover = gui.row_hover(row)

	row:Hide()
	return row
end

-- Forever: the window can be resized, so the list shows as many rows as fit its current height.
-- Rows are created when first needed and kept for when the window grows again.
local function fit_rows(item_listing)
	local height = item_listing.content_frame:GetHeight() or 0
	if height <= 0 then return end
	local count = max(floor((height - 1) / ROW_HEIGHT), 0)
	if count == #item_listing.rows then return end
	for i = count + 1, #item_listing.all_rows do
		item_listing.all_rows[i]:Hide()
	end
	item_listing.rows = {}
	for i = 1, count do
		item_listing.all_rows[i] = item_listing.all_rows[i] or create_row(item_listing, i)
		item_listing.rows[i] = item_listing.all_rows[i]
	end
	if item_listing.item_records then
		render(item_listing)
	end
end

function M.new(parent, on_click, selected)
	local content_frame = CreateFrame('Frame', nil, parent)
	content_frame:SetAllPoints()

	local scroll_frame = CreateFrame('ScrollFrame', gui.unique_name(), parent, 'FauxScrollFrameTemplate')
	scroll_frame:SetScript('OnVerticalScroll', function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() render(self.item_listing) end)
	end)
	scroll_frame:SetPoint('TOPLEFT', content_frame, 'TOPLEFT', 0, 29)
	scroll_frame:SetPoint('BOTTOMRIGHT', content_frame, 'BOTTOMRIGHT', 0, 0)

	local scroll_bar = _G[scroll_frame:GetName() .. 'ScrollBar']
	scroll_bar:ClearAllPoints()
	scroll_bar:SetPoint('TOPRIGHT', parent, -4, 2)
	scroll_bar:SetPoint('BOTTOMRIGHT', parent, -4, 4)
	scroll_bar:SetWidth(10)
	local thumbTex = scroll_bar:GetThumbTexture()
	thumbTex:SetPoint('CENTER', 0, 0)
	gui.texture_color(thumbTex, aux.color.scrollbar)
	thumbTex:SetHeight(150)
	thumbTex:SetWidth(6)
	_G[scroll_bar:GetName() .. 'ScrollUpButton']:Hide()
	_G[scroll_bar:GetName() .. 'ScrollDownButton']:Hide()

	local item_listing = {
		selected = selected,
		content_frame = content_frame,
		scroll_frame = scroll_frame,
		rows = {},
		all_rows = {},
		on_click = on_click,
	}
	scroll_frame.item_listing = item_listing
	content_frame:SetScript('OnSizeChanged', function() fit_rows(item_listing) end)
	content_frame:SetScript('OnShow', function() fit_rows(item_listing) end)
	fit_rows(item_listing)

	return item_listing
end

function M.populate(item_listing, item_records)
	item_listing.item_records = item_records
	render(item_listing)
end
