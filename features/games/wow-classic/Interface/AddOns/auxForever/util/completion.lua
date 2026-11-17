select(2, ...) 'aux.util.completion'

local aux = require 'aux'
local filter_util = require 'aux.util.filter'

function M.complete_filter(self)
	if IsControlKeyDown() then -- TODO problem is ctrl-v, maybe find a better solution
		return
	end

	local filter_string = self:GetText()

	local completed_filter_string = select(3, strfind(filter_string, '([^;]*)/[^/;]*$'))
	-- 0.8.2.1 (second pass of the outside review): the item names are looked through below, not
	-- handed over as a list. For the first word of a search the suggestions held every item name
	-- with "/exact" added, built anew at every key press and compared in upper case one by one:
	-- about 28 ms per key with 25,000 names in aux's tests, a hitch at every letter typed.
	local _, suggestions = filter_util.query(completed_filter_string, true)

	local start_index, _, current_modifier = strfind(filter_string, '([^/;]*)$')
	current_modifier = current_modifier or ''
	local length = strlen(current_modifier)

	local function complete_with(suggestion)
        self:SetText(strlower(strsub(filter_string, 1, start_index - 1) ..  suggestion))
        self:HighlightText(strlen(filter_string), -1)
	end

	local upper = strupper(current_modifier)
	for _, suggestion in ipairs(suggestions) do
		if strsub(strupper(suggestion), 1, length) == upper then
			complete_with(suggestion)
			return
		end
	end

	-- the first word of a search can be an item name (they are kept in lower case, shortest first)
	if completed_filter_string == nil then
		local lower = strlower(current_modifier)
		for _, name in ipairs(aux.account_data.auctionable_items) do
			if strsub(name, 1, length) == lower then
				complete_with(name .. '/exact')
				return
			end
		end
	end
end

function M.complete(candidates)
	return function(self)
		if IsControlKeyDown() then -- TODO problem is ctrl-v, maybe find a better solution
			return
		end

		local text = self:GetText()

		local t = candidates()
		for i = 1, #t do
			if strsub(strupper(t[i]), 1, strlen(text)) == strupper(text) then
				self:SetText(t[i])
				self:HighlightText(strlen(text), -1)
				return
			end
		end
	end
end