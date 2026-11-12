select(2, ...) 'aux'

-- each color object keeps its numbers in a table that set_palette rewrites in place, so every
-- holder of a color (aux.color.accent.background, kept in a local or a widget) follows the look
local function C(r, g, b, a)
	local mt = { __metatable = false, __newindex = pass, color = {r, g, b, a} }
	function mt:__call(text)
		local r, g, b, a = unpack(mt.color)
		if text then
			return format('|c%02X%02X%02X%02X', a, r, g, b) .. text .. FONT_COLOR_CODE_CLOSE
		else
			return r/255, g/255, b/255, a
		end
	end
	function mt:__concat(text)
		local r, g, b, a = unpack(mt.color)
		return format('|c%02X%02X%02X%02X', a, r, g, b) .. text
	end
	return setmetatable({}, mt), mt.color
end

-- auxForever (0.6): two looks, chosen in Settings and applied at login (aux-addon.lua). Both palettes
-- have the same names; a name missing from one is an error the tests catch.
--   new      the UI Kit in the Paper file "auxForever Screens" (webster): near black
--            surfaces, black edges, one gold accent. Its blacks are a little lighter than the kit's
--            and sunken fields have a gray edge, so text boxes stand out from the panels (Tyler,
--            2026-10-08: "it's hard to tell where the text boxes are").
--   classic  the 0.5 look: warm text on dark slate, amber accent
M.PALETTES = {
	new = {
		text = {enabled = {235, 235, 235, 1}, disabled = {107, 107, 107, 1}},
		label = {enabled = {168, 168, 168, 1}, disabled = {94, 94, 94, 1}},
		link = {153, 255, 255, 1},
		window = {background = {26, 26, 26, .97}, border = {0, 0, 0, 1}},
		-- the darker bands across the top and bottom of the window
		band = {16, 16, 16, 1},
		band_edge = {0, 0, 0, 1},
		panel = {background = {19, 19, 19, 1}, border = {0, 0, 0, 1}},
		-- raised things (buttons, tabs): 42 at the top, darker toward the bottom (gui.add_sheen)
		content = {background = {42, 42, 42, 1}, border = {0, 0, 0, 1}},
		-- sunken things (tables, inputs, the status bar)
		input = {background = {12, 12, 12, 1}, border = {64, 64, 64, 1}, focus = {229, 190, 91, .6}},
		header = {background = {34, 34, 34, 1}, text = {207, 207, 207, 1}},
		state = {enabled = {77, 204, 102, 1}, disabled = {122, 58, 52, 1}},
		accent = {background = {229, 190, 91, 1}, text = {229, 190, 91, 1}, selected = {42, 35, 18, 1}, hover = {242, 212, 138, 1}, raised = {39, 32, 18, 1}},
		selected = {229, 190, 91, .13},
		hover = {255, 255, 255, .06},
		-- every second table row (Tyler, 2026-10-08: zebra rows in dark gray)
		stripe = {255, 255, 255, .04},
		scrollbar = {229, 190, 91, .35},
		-- the knob of a switch that is off (gui.switch)
		switch_knob = {110, 110, 110, 1},
		status = {track = {9, 9, 9, 1}, buffer = {89, 71, 36, .6}, loading = {150, 120, 61, 1}, idle = {255, 255, 255, .06}},
		-- money coming to the player (green) and going out (red)
		positive = {77, 204, 102, 1},
		negative = {232, 87, 74, 1},
		-- status and deals (percentages of the usual price, errors)
		blue = {90, 169, 255, 1},
		green = {77, 204, 102, 1},
		yellow = {232, 212, 77, 1},
		orange = {240, 148, 60, 1},
		red = {232, 87, 74, 1},
		-- far below the player's level (the Req column, 0.7): Blizzard's gray for trivial
		trivial = {128, 128, 128, 1},
	},
	classic = {
		text = {enabled = {243, 239, 230, 1}, disabled = {125, 122, 115, 1}},
		label = {enabled = {168, 164, 155, 1}, disabled = {110, 107, 100, 1}},
		link = {153, 255, 255, 1},
		window = {background = {22, 24, 27, .97}, border = {43, 47, 53, 1}},
		-- no bands in this look (clear, so they never darken a faded window)
		band = {22, 24, 27, 0},
		band_edge = {0, 0, 0, 0},
		panel = {background = {24, 26, 29, 1}, border = {38, 42, 47, 1}},
		content = {background = {29, 32, 36, 1}, border = {47, 52, 58, 1}},
		input = {background = {15, 17, 19, 1}, border = {58, 63, 70, 1}, focus = {58, 63, 70, 1}},
		header = {background = {29, 32, 36, 1}, text = {142, 138, 129, 1}},
		state = {enabled = {63, 174, 106, 1}, disabled = {122, 58, 52, 1}},
		accent = {background = {227, 164, 59, 1}, text = {26, 20, 8, 1}, selected = {58, 46, 21, 1}, hover = {240, 190, 110, 1}, raised = {58, 46, 21, 1}},
		selected = {227, 164, 59, .22},
		hover = {255, 255, 255, .08},
		stripe = {255, 255, 255, .035},
		scrollbar = {47, 52, 58, 1},
		switch_knob = {125, 122, 115, 1},
		status = {track = {22, 24, 27, .97}, buffer = {107, 107, 107, .7}, loading = {227, 163, 59, .55}, idle = {77, 82, 89, .6}},
		positive = {111, 211, 154, 1},
		negative = {255, 138, 126, 1},
		blue = {41, 146, 255, 1},
		green = {22, 255, 22, 1},
		yellow = {255, 255, 0, 1},
		orange = {255, 146, 24, 1},
		red = {255, 0, 0, 1},
		trivial = {128, 128, 128, 1},
	},
}

-- the same in both looks
local SHARED = {
	tooltip = {
		value = {255, 255, 154, 1},
		merchant = {204, 127, 25, 1},
		disenchant = {
			value = {25, 153, 153, 1},
			distribution = {204, 204, 51, 1},
			source = {178, 178, 178, 1},
		}
	},
	gray = {187, 187, 187, 1},
	gold = {255, 255, 154, 1},
	blizzard = {0, 180, 255, 1},
}

-- a leaf is a list of numbers; anything else is a group of names
local function is_leaf(t) return type(t[1]) == 'number' end

-- the numbers of every color, by path ('accent.background'), for set_palette
local slots = {}

local function build(spec, path)
	local group = {}
	for name, value in pairs(spec) do
		local key = path and path .. '.' .. name or name
		if is_leaf(value) then
			local color, numbers = C(value[1], value[2], value[3], value[4])
			slots[key] = numbers
			group[name] = color
		else
			group[name] = build(value, key)
		end
	end
	return group
end

local function merge(into, from)
	for k, v in pairs(from) do into[k] = v end
	return into
end

local function freeze(group)
	for name, value in pairs(group) do
		if getmetatable(value) == nil then
			group[name] = freeze(value)
		end
	end
	return immutable-group
end

do
	local tree = build(merge(merge({}, SHARED), PALETTES.new))
	tree.none = setmetatable({}, {__metatable=false, __newindex=pass, __call=function(_, v) return v end, __concat=function(_, v) return v end})
	M.color = freeze(tree)
end

M.theme = 'new'

-- every color path of a palette, for the tests
function M.palette_paths(palette)
	local paths = {}
	local function walk(spec, path)
		for name, value in pairs(spec) do
			local key = path and path .. '.' .. name or name
			if is_leaf(value) then paths[key] = true else walk(value, key) end
		end
	end
	walk(palette)
	return paths
end

-- switch every color to a look's palette; an unknown name is the new look
function M.set_palette(name)
	if not PALETTES[name] then name = 'new' end
	local function walk(spec, path)
		for key, value in pairs(spec) do
			local full = path and path .. '.' .. key or key
			if is_leaf(value) then
				local numbers = slots[full]
				if numbers then
					numbers[1], numbers[2], numbers[3], numbers[4] = value[1], value[2], value[3], value[4]
				end
			else
				walk(value, full)
			end
		end
	end
	walk(PALETTES[name])
	M.theme = name
	return name
end
