-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSUtils = private.NewLib("RareScannerUtils")

---============================================================================
-- Table utils
---============================================================================

function RSUtils.FilterRepeated(originTable, tableToCompate)
	if (originTable and type(originTable) == "table") then
		local notRepeatedValues = {}
		local seen = {}

		local compareMap = nil
		if (tableToCompate and type(tableToCompate) == "table") then
			compareMap = {}
			for _, val in ipairs(tableToCompate) do
				compareMap[val] = true
			end
		end

		for _, value in ipairs(originTable) do
			if (not seen[value]) then
				seen[value] = true
				if (not compareMap or not compareMap[value]) then
					table.insert(notRepeatedValues, value)
				end
			end
		end

		if (next(notRepeatedValues) ~= nil) then
			return notRepeatedValues
		end
	end

	return nil
end

function RSUtils.JoinTables(table1, table2)
	local joinedTable = {}
	local seen = {}
	local joined = false

	if (table1 and type(table1) == "table") then
		for _, value in ipairs(table1) do
			if (not seen[value]) then
				seen[value] = true
				tinsert(joinedTable, value)
				joined = true
			end
		end
	end

	if (table2 and type(table2) == "table") then
		for _, value in ipairs(table2) do
			if (not seen[value]) then
				seen[value] = true
				tinsert(joinedTable, value)
				joined = true
			end
		end
	end

	if (joined) then
		return joinedTable
	end
	
	return nil
end

function RSUtils.GetTableLength(table)
	if (not table) then
		return 0
	end
	
	local getN = 0
	for n in pairs(table) do 
    	getN = getN + 1 
	end
	
  	return getN
end

function RSUtils.CloneTable(src, dest)
	for index, value in pairs(src) do
		if (type(value) == "table") then
			dest[index] = {}
			RSUtils.CloneTable(value, dest[index])
		else
			dest[index] = value
		end
	end
end

function RSUtils.GetSortedKeysByValue(tbl, sortFunction)
	local keys = {}
	
	if (tbl) then
		for key in pairs(tbl) do
	    	table.insert(keys, key)
	 	end
	
	  	table.sort(keys, function(a, b)
	    	return sortFunction(tbl[a], tbl[b])
	  	end)
	end

  	return keys
end

---============================================================================
-- Auxiliar utils
---============================================================================

function RSUtils.Contains(cTable, item)
	if (not cTable or not item) then
		return false
	end

	if (cTable == item) then
		return true
	end

	if (type(cTable) == "table") then
		local itemIsString = type(item) == "string"
		local itemUpper = itemIsString and string.upper(strtrim(item)) or nil

		for _, v in pairs(cTable) do
			if (v == item) then
				return true
			elseif (type(v) == "table") then
				if (RSUtils.Contains(v, item)) then
					return true
				end
			elseif (type(item) == "table") then
				if (RSUtils.Contains(item, v)) then
					return true
				end
			elseif (itemIsString and type(v) == "string") then
				if (string.find(string.upper(strtrim(v)), itemUpper, 1, true)) then
					return true
				end
			end
		end
	else
		if (type(item) == "table") then
			return RSUtils.Contains(item, cTable)
		elseif (type(cTable) == "string" and type(item) == "string") then
			return string.find(string.upper(strtrim(cTable)), string.upper(strtrim(item)), 1, true) ~= nil
		end
	end

	return false
end

function RSUtils.ContainsKeyValue(table, keyTable, value)
	if (not table or not keyTable or not value) then
		return false
	end
	
	if (type(table) ~= "table") then
		return false
	elseif (type(keyTable) ~= "table") then
		return false
	else
		for k, _ in pairs (table) do
			local currentKey = nil
			for _, key in ipairs (keyTable) do
				if (k == key) then
					currentKey = k;
					break
				end
			end
			
			if (currentKey and table[currentKey][value]) then
				return true
			end
		end
		
		return false
	end
end

---============================================================================
-- String utils
---============================================================================

function RSUtils.StartsWith(string, start)
	return string.sub(string,1,string.len(start)) == start
end

function RSUtils.Lpad(s, l, c)
	if (type(s) ~= "string") then
		s = tostring(s)
	end
	
	local res = string.rep(c or ' ', l - #s) .. s
	return res, res ~= s
end

function RSUtils.Rpad(s, l, c)
	if (type(s) ~= "string") then
		s = tostring(s)
	end
	
	if (l - #s > 0) then
		local res = s.. string.rep(c or ' ', l - #s)
		return res, res ~= s
	end

	return s
end

function RSUtils.tostring(s)
	if (s) then
		return tostring(s)
	end
	
	return nil
end

function RSUtils.IsNumber(n)
	if (n and type(n) == "number") then
		return true
	end
	
	return false
end

---============================================================================
-- Arithmetic utils
---============================================================================

function RSUtils.DistanceBetweenCoords(x1, x2, y1, y2)
	local fx1 = RSUtils.FixCoord(x1)
	local fx2 = RSUtils.FixCoord(x2)
	local fy1 = RSUtils.FixCoord(y1)
	local fy2 = RSUtils.FixCoord(y2)
	if (fx1 and fx2 and fy1 and fy2) then
		local dx = fx1 - fx2
		local dy = fy1 - fy2
		return math.sqrt((dx * dx) + (dy * dy))
	else
		return -1
	end
end

function RSUtils.Distance(POIa, POIb)
	if (not POIa or not POIb) then
		return -1
	end
	return RSUtils.DistanceBetweenCoords(POIa.x, POIb.x, POIa.y, POIb.y)
end

function RSUtils.DistanceBetweenPointsNoFix(p1, p2)
	if (not p1 or not p2 or not p1.x or not p1.y or not p2.x or not p2.y) then
		return -1
	end
	local dx, dy = p1.x - p2.x, p1.y - p2.y
	return math.sqrt((dx * dx) + (dy * dy))
end

function RSUtils.GetDistanceInYards(mapID, x1, y1, x2, y2)
    if not (mapID and x1 and y1 and x2 and y2) then return 0 end

    x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
    if not (x1 and y1 and x2 and y2) then return 0 end

    if x1 > 1 then x1 = x1 / 100 end
    if y1 > 1 then y1 = y1 / 100 end
    if x2 > 1 then x2 = x2 / 100 end
    if y2 > 1 then y2 = y2 / 100 end

    local mapWidth, mapHeight = C_Map.GetMapWorldSize(mapID)
    if (mapWidth and mapHeight and mapWidth > 0 and mapHeight > 0) then
        local deltaX = (x2 - x1) * mapWidth
        local deltaY = (y2 - y1) * mapHeight
        return math.sqrt(deltaX * deltaX + deltaY * deltaY)
    end

    return 0
end

---
-- @param #string text Text to add color
-- @param #string color Color
-- @return Text with color
---
function RSUtils.TextColor(text, color)
	return string.format("|cff%s%s|r", color, text)
end

---
-- @param #number Number to round
-- @param #decimals Number of decimals
-- @return Rounded number
---
function RSUtils.Round(number, decimals)
    return (("%%.%df"):format(decimals)):format(number)
end

---============================================================================
-- Adjust coordinates to the new format
---============================================================================

function RSUtils.FixCoord(coord)
	if (not coord) then
		return nil
	end

	if (type(coord) == "number") then
		if (coord >= 0 and coord <= 1) then
			return coord
		else
			return coord / 10000
		end
	end

	if (type(coord) == "string") then
		if (string.find(coord, ".", 1, true)) then
			return tonumber(coord)
		end

		local num = tonumber(coord)
		if (num) then
			if (num >= 0 and num <= 1) then
				return num
			else
				return num / 10000
			end
		end
	end

	return nil
end

---============================================================================
-- RGB to HEX
---============================================================================

local color = CreateFromMixins(ColorMixin)

function RSUtils.RGBToHex(r, g, b)
	color:SetRGBA(r, g, b)
	return string.sub(color:GenerateHexColor(), 3, 8)
end

function RSUtils.HexToRGB(hex)
	local rhex, ghex, bhex = string.sub(hex, 1, 2), string.sub(hex, 3, 4), string.sub(hex, 5, 6)
	return tonumber(rhex, 16)/255, tonumber(ghex, 16)/255, tonumber(bhex, 16)/255
end