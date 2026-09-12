
	----------------------------------------------------------------------
	-- Leatrix Maps Icons for Classic Era
	----------------------------------------------------------------------

	local void, Leatrix_Maps = ...
	local L = Leatrix_Maps.L

	-- Dungeons
	local dnTex, rdTex = "Dungeon", "Raid"

	-- Flight points
	local tATex, tHTex, tNTex = "TaxiNode_Alliance", "TaxiNode_Horde", "TaxiNode_Neutral"

	-- Boat harbors, zeppelin towers and tram stations (these are just templates, they will be replaced)
	local fATex, fHTex, fNTex = "Vehicle-TempleofKotmogu-CyanBall", "Vehicle-TempleofKotmogu-CyanBall", "Vehicle-TempleofKotmogu-CyanBall"

	-- Spirit healers
	local spTex = "Vehicle-TempleofKotmogu-GreenBall"

	-- Zone crossings
	local arTex = "Garr_LevelUpgradeArrow"

	Leatrix_Maps["Icons"] = {

		----------------------------------------------------------------------
		--	Eastern Kingdoms
		----------------------------------------------------------------------

		--[[Alterac Mountains]] [1416] = {
			{"Spirit", 42.9, 38.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 80.7, 34.2, L["Western Plaguelands"], nil, arTex, nil, nil, nil, nil, nil, 0, 1422},
			{"Arrow", 51.8, 68.8, L["Hillsbrad Foothills"], nil, arTex, nil, nil, nil, nil, nil, 3, 1424},
			{"Arrow", 81.7, 77.5, L["Hillsbrad Foothills"], L["Ravenholdt Manor"], arTex, nil, nil, nil, nil, nil, 2.2, 1424},
		},
		--[[Arathi Highlands]] [1417] = {
			{"FlightA", 45.8, 46.1, L["Refuge Pointe"] .. ", " .. L["Arathi Highlands"], nil, tATex, nil, nil},
			{"FlightH", 73.1, 32.7, L["Hammerfall"] .. ", " .. L["Arathi Highlands"], nil, tHTex, nil, nil},
			{"Spirit", 48.8, 55.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 45.4, 88.9, L["Wetlands"], L["Thandol Span"], arTex, nil, nil, nil, nil, nil, 3.2, 1437},
			{"Arrow", 20.9, 30.6, L["Hillsbrad Foothills"], nil, arTex, nil, nil, nil, nil, nil, 1, 1424},
			{"Arrow", 29.6, 67.5, L["Faldir's Cove"], L["Just follow the path west"], arTex, nil, nil, nil, nil, nil, 1.9, 1417},
		},
		--[[Badlands]] [1418] = {
			{"Dungeon", 44.6, 12.1, L["Uldaman"], L["Dungeon"], dnTex, 41, 51},
			{"FlightH", 4.0, 44.8, L["Kargath"] .. ", " .. L["Badlands"], nil, tHTex, nil, nil},
			{"Spirit", 56.7, 23.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 8.4, 55.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 51.1, 14.8, L["Loch Modan"], nil, arTex, nil, nil, nil, nil, nil, 0.8, 1432},
			{"Arrow", 5.3, 61.1, L["Searing Gorge"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1427},
		},
		--[[Blasted Lands]] [1419] = {
			{"FlightA", 65.5, 24.3, L["Nethergarde Keep"] .. ", " .. L["Blasted Lands"], nil, tATex, nil, nil},
			{"Spirit", 51.1, 12.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 52.2, 10.7, L["Swamp of Sorrows"], nil, arTex, nil, nil, nil, nil, nil, 0, 1435},
		},
		--[[Tirisfal Glades]] [1420] = {
			{"Dungeon", 82.6, 33.8, L["Scarlet Monastery"], L["Dungeon"], dnTex, 34, 45},
			{"TravelH", 60.7, 58.8, L["Zeppelin to"] .. " " .. L["Orgrimmar"] .. ", " .. L["Durotar"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1411},
			{"TravelH", 61.9, 59.1, L["Zeppelin to"] .. " " .. L["Grom'gol Base Camp"] .. ", " .. L["Stranglethorn Vale"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1434},
			{"Spirit", 30.8, 64.9, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 56.2, 49.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 79.0, 41.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 62.3, 67.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 82.0, 69.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 83.4, 70.6, L["Western Plaguelands"], L["The Bulwark"], arTex, nil, nil, nil, nil, nil, 4.7, 1422},
			{"Arrow", 61.9, 65.0, L["Undercity"], nil, arTex, nil, nil, nil, nil, nil, 3, 1458},
			{"Arrow", 54.9, 72.7, L["Silverpine Forest"], nil, arTex, nil, nil, nil, nil, nil, 3, 1421},
		},
		--[[Silverpine Forest]] [1421] = {
			{"Dungeon", 44.8, 67.8, L["Shadowfang Keep"], L["Dungeon"], dnTex, 22, 30},
			{"FlightH", 45.6, 42.6, L["The Sepulcher"] .. ", " .. L["Silverpine Forest"], nil, tHTex, nil, nil},
			{"Spirit", 44.1, 42.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 55.6, 73.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 66.3, 79.8, L["Hillsbrad Foothills"], nil, arTex, nil, nil, nil, nil, nil, 4.3, 1424},
			{"Arrow", 67.7, 5.0, L["Tirisfal Glades"], nil, arTex, nil, nil, nil, nil, nil, 5.7, 1420},
		},
		--[[Western Plaguelands]] [1422] = {
			{"Dungeon", 69.7, 73.2, L["Scholomance"], L["Dungeon"], dnTex, 58, 60},
			{"FlightA", 42.9, 85.1, L["Chillwind Camp"] .. ", " .. L["Western Plaguelands"], nil, tATex, nil, nil},
			{"Spirit", 59.7, 53.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 65.8, 74.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 45.0, 86.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 44.1, 87.1, L["Alterac Mountains"], nil, arTex, nil, nil, nil, nil, nil, 3, 1416},
			{"Arrow", 28.6, 57.5, L["Tirisfal Glades"], L["The Bulwark"], arTex, nil, nil, nil, nil, nil, 1.6, 1420},
			{"Arrow", 69.7, 50.3, L["Eastern Plaguelands"], nil, arTex, nil, nil, nil, nil, nil, 4.7, 1423},
			{"Arrow", 65.3, 86.4, L["The Hinterlands"], nil, arTex, nil, nil, nil, nil, nil, 3, 1425},
		},
		--[[Eastern Plaguelands]] [1423] = {
			{"Dungeon", 31.3, 15.7, L["Stratholme (Main Gate)"], L["Dungeon"], dnTex, 58, 60}, {"Dungeon", 47.9, 23.9, L["Stratholme (Service Gate)"], L["Dungeon"], dnTex, 58, 60}, {"Dungeon", 39.9, 25.9, L["Naxxramas"], L["Raid"], rdTex, 60, 60},
			{"FlightA", 81.6, 59.3, L["Light's Hope Chapel"] .. ", " .. L["Eastern Plaguelands"], nil, tATex, nil, nil},
			{"FlightH", 80.2, 57.0, L["Light's Hope Chapel"] .. ", " .. L["Eastern Plaguelands"], nil, tHTex, nil, nil},
			{"Spirit", 47.3, 44.9, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 37.8, 70.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 39.2, 93.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 80.4, 65.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 11.8, 72.7, L["Western Plaguelands"], nil, arTex, nil, nil, nil, nil, nil, 1.6, 1422},
		},
		--[[Hillsbrad Foothills]] [1424] = {
			{"FlightA", 49.3, 52.3, L["Southshore"] .. ", " .. L["Hillsbrad Foothills"], nil, tATex, nil, nil},
			{"FlightH", 60.1, 18.6, L["Tarren Mill"] .. ", " .. L["Hillsbrad Foothills"], nil, tHTex, nil, nil},
			{"Spirit", 64.5, 19.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 51.8, 52.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 84.6, 31.8, L["The Hinterlands"], nil, arTex, nil, nil, nil, nil, nil, 5.4, 1425},
			{"Arrow", 54.8, 11.3, L["Alterac Mountains"], nil, arTex, nil, nil, nil, nil, nil, 0, 1416},
			{"Arrow", 13.7, 46.2, L["Silverpine Forest"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1421},
			{"Arrow", 81.0, 56.1, L["Arathi Highlands"], nil, arTex, nil, nil, nil, nil, nil, 4.1, 1417},
			{"Arrow", 75.5, 24.6, L["Alterac Mountains"], L["Ravenholdt Manor"], arTex, nil, nil, nil, nil, nil, 0.0, 1416},
		},
		--[[The Hinterlands]] [1425] = {
			{"FlightA", 11.1, 46.2, L["Aerie Peak"] .. ", " .. L["The Hinterlands"], nil, tATex, nil, nil},
			{"FlightH", 81.7, 81.8, L["Revantusk Village"] .. ", " .. L["The Hinterlands"], nil, tHTex, nil, nil},
			{"Spirit", 16.9, 44.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 73.1, 68.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 24.1, 30.4, L["Western Plaguelands"], nil, arTex, nil, nil, nil, nil, nil, 0, 1422},
			{"Arrow", 6.4, 61.5, L["Hillsbrad Foothills"], nil, arTex, nil, nil, nil, nil, nil, 2.3, 1424},
			{"Arrow", 70.6, 63.7, L["The Overlook Cliffs"], L["Follow the westward path"], arTex, nil, nil, nil, nil, nil, 4.1, 1425},
			{"Arrow", 76.9, 61.0, L["The Hinterlands"], L["Follow the eastward path"], arTex, nil, nil, nil, nil, nil, 1.8, 1425},
		},
		--[[Dun Morogh]] [1426] = {
			{"Dungeon", 24.3, 39.8, L["Gnomeregan"], L["Dungeon"], dnTex, 29, 38},
			{"Spirit", 30.0, 69.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 47.3, 54.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 54.4, 39.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 84.3, 31.1, L["Loch Modan"], L["North Gate Pass"], arTex, nil, nil, nil, nil, nil, 0, 1432},
			{"Arrow", 82.2, 53.5, L["Loch Modan"], L["South Gate Pass"], arTex, nil, nil, nil, nil, nil, 5, 1432},
			{"Arrow", 30.5, 34.5, L["Wetlands"], L["You will die!"], arTex, nil, nil, nil, nil, nil, 6.2, 1437},
			{"Arrow", 53.3, 35.1, L["Ironforge"], nil, arTex, nil, nil, nil, nil, nil, 5.4, 1455},
		},
		--[[Searing Gorge]] [1427] = {
			{"Dunraid", 34.8, 85.3, L["Blackrock Mountain"], L["Blackrock Depths"] .. ", " .. L["Lower Blackrock Spire"] .. ", " .. L["Upper Blackrock Spire"] .. ", |n" .. L["Molten Core"] .. ", " .. L["Blackwing Lair"], dnTex, 52, 60},
			{"FlightA", 37.9, 30.8, L["Thorium Point"] .. ", " .. L["Searing Gorge"], nil, tATex, nil, nil},
			{"FlightH", 34.8, 30.9, L["Thorium Point"] .. ", " .. L["Searing Gorge"], nil, tHTex, nil, nil},
			{"Spirit", 35.5, 22.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 54.4, 51.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 78.5, 17.4, L["Loch Modan"], L["Requires Key to Searing Gorge"], arTex, nil, nil, nil, nil, nil, 5.4, 1432},
			{"Arrow", 33.6, 79.0, L["Burning Steppes"], L["Blackrock Mountain"], arTex, nil, nil, nil, nil, nil, 3, 1428},
			{"Arrow", 68.8, 53.9, L["Badlands"], nil, arTex, nil, nil, nil, nil, nil, 4.5, 1418},
		},
		--[[Burning Steppes]] [1428] = {
			{"Dunraid", 29.4, 38.3, L["Blackrock Mountain"], L["Blackrock Depths"] .. ", " .. L["Lower Blackrock Spire"] .. ", " .. L["Upper Blackrock Spire"] .. ", |n" .. L["Molten Core"] .. ", " .. L["Blackwing Lair"], dnTex, 52, 60},
			{"FlightA", 84.3, 68.3, L["Morgan's Vigil"] .. ", " .. L["Burning Steppes"], nil, tATex, nil, nil},
			{"FlightH", 65.7, 24.2, L["Flame Crest"] .. ", " .. L["Burning Steppes"], nil, tHTex, nil, nil},
			{"Spirit", 64.1, 24.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 78.3, 77.8, L["Redridge Mountains"], nil, arTex, nil, nil, nil, nil, nil, 3.3, 1433},
			{"Arrow", 31.9, 50.4, L["Searing Gorge"], L["Blackrock Mountain"], arTex, nil, nil, nil, nil, nil, 0.8, 1427},
		},
		--[[Elwynn Forest]] [1429] = {
			{"Spirit", 39.5, 60.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 49.7, 42.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 83.6, 69.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 21.0, 79.6, L["Westfall"], nil, arTex, nil, nil, nil, nil, nil, 2.2, 1436},
			{"Arrow", 93.2, 72.3, L["Redridge Mountains"], nil, arTex, nil, nil, nil, nil, nil, 4.7, 1433},
			{"Arrow", 32.2, 49.7, L["Stormwind City"], nil, arTex, nil, nil, nil, nil, nil, 0.6, 1453},
		},
		--[[Deadwind Pass]] [1430] = {
			{"Spirit", 40.0, 74.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 32.0, 35.3, L["Duskwood"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1431},
			{"Arrow", 58.8, 42.2, L["Swamp of Sorrows"], nil, arTex, nil, nil, nil, nil, nil, 5.2, 1435},
		},
		--[[Duskwood]] [1431] = {
			{"FlightA", 77.5, 44.3, L["Darkshire"] .. ", " .. L["Duskwood"], nil, tATex, nil, nil},
			{"Spirit", 20.0, 49.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 75.1, 59.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 7.9, 63.8, L["Westfall"], nil, arTex, nil, nil, nil, nil, nil, 1.7, 1436},
			{"Arrow", 44.6, 87.9, L["Stranglethorn Vale"], nil, arTex, nil, nil, nil, nil, nil, 3, 1434},
			{"Arrow", 94.2, 10.3, L["Redridge Mountains"], nil, arTex, nil, nil, nil, nil, nil, 5.8, 1433},
			{"Arrow", 88.4, 40.9, L["Deadwind Pass"], nil, arTex, nil, nil, nil, nil, nil, 4.6, 1430},
		},
		--[[Loch Modan]] [1432] = {
			{"FlightA", 33.9, 50.9, L["Thelsamar"] .. ", " .. L["Loch Modan"], nil, tATex, nil, nil},
			{"Spirit", 32.6, 47.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 18.4, 83.0, L["Searing Gorge"], L["Requires Key to Searing Gorge"], arTex, nil, nil, nil, nil, nil, 2.6, 1427},
			{"Arrow", 20.4, 17.4, L["Dun Morogh"], L["North Gate Pass"], arTex, nil, nil, nil, nil, nil, 1.1, 1426},
			{"Arrow", 46.8, 76.9, L["Badlands"], nil, arTex, nil, nil, nil, nil, nil, 3.2, 1418},
			{"Arrow", 21.5, 66.2, L["Dun Morogh"], L["South Gate Pass"], arTex, nil, nil, nil, nil, nil, 0.5, 1426},
			{"Arrow", 25.4, 10.9, L["Wetlands"], L["Dun Algaz"], arTex, nil, nil, nil, nil, nil, 0.1, 1437},
		},
		--[[Redridge Mountains]] [1433] = {
			{"FlightA", 30.6, 59.4, L["Lake Everstill"] .. ", " .. L["Redridge Mountains"], nil, tATex, nil, nil},
			{"Spirit", 20.8, 56.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 8.5, 88.1, L["Duskwood"], nil, arTex, nil, nil, nil, nil, nil, 2.2, 1431},
			{"Arrow", 3.3, 73.1, L["Elwynn Forest"], nil, arTex, nil, nil, nil, nil, nil, 2.1, 1429},
			{"Arrow", 47.3, 14.3, L["Burning Steppes"], nil, arTex, nil, nil, nil, nil, nil, 5.9, 1428},
		},
		--[[Stranglethorn Vale]] [1434] = {
			{"Raid", 53.9, 17.6, L["Zul'Gurub"], L["Raid"], rdTex, 60, 60},
			{"FlightA", 27.5, 77.8, L["Booty Bay"] .. ", " .. L["Stranglethorn Vale"], nil, tATex, nil, nil},
			{"FlightH", 26.9, 77.1, L["Booty Bay"] .. ", " .. L["Stranglethorn Vale"], nil, tHTex, nil, nil},
			{"FlightH", 32.5, 29.4, L["Grom'gol Base Camp"] .. ", " .. L["Stranglethorn Vale"], nil, tHTex, nil, nil},
			{"TravelN", 25.9, 73.1, L["Boat to"] .. " " .. L["Ratchet"] .. ", " .. L["The Barrens"], nil, fNTex, nil, nil, nil, nil, nil, 0, 1413},
			{"TravelH", 31.4, 30.2, L["Zeppelin to"] .. " " .. L["Orgrimmar"] .. ", " .. L["Durotar"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1411},
			{"TravelH", 31.6, 29.1, L["Zeppelin to"] .. " " .. L["Undercity"] .. ", " .. L["Tirisfal Glades"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1420},
			{"Spirit", 38.4, 9.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 30.4, 73.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 39.2, 6.5, L["Duskwood"], nil, arTex, nil, nil, nil, nil, nil, 0, 1431},
		},
		--[[Swamp of Sorrows]] [1435] = {
			{"Dungeon", 69.9, 53.6, L["Temple of Atal'Hakkar"], L["Dungeon"], dnTex, 50, 60},
			{"FlightH", 46.1, 54.8, L["Stonard"] .. ", " .. L["Swamp of Sorrows"], nil, tHTex, nil, nil},
			{"Spirit", 50.3, 62.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 3.7, 61.1, L["Deadwind Pass"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1430},
			{"Arrow", 33.4, 74.8, L["Blasted Lands"], nil, arTex, nil, nil, nil, nil, nil, 3.1, 1419},
		},
		--[[Westfall]] [1436] = {
			{"Dungeon", 42.5, 71.7, L["The Deadmines"], L["Dungeon"], dnTex, 17, 26},
			{"FlightA", 56.6, 52.6, L["Sentinel Hill"] .. ", " .. L["Westfall"], nil, tATex, nil, nil},
			{"Spirit", 51.7, 49.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 62.0, 17.9, L["Elwynn Forest"], nil, arTex, nil, nil, nil, nil, nil, 5.4, 1429},
			{"Arrow", 67.9, 62.8, L["Duskwood"], nil, arTex, nil, nil, nil, nil, nil, 4.7, 1431},
		},
		--[[Wetlands]] [1437] = {
			{"FlightA", 9.5, 59.7, L["Menethil Harbor"] .. ", " .. L["Wetlands"], nil, tATex, nil, nil},
			{"TravelA", 5.0, 63.5, L["Boat to"] .. " " .. L["Theramore Isle"] .. ", " .. L["Dustwallow Marsh"], nil, fATex, nil, nil, nil, nil, nil, 0, 1445},
			{"TravelA", 4.6, 57.1, L["Boat to"] .. " " .. L["Auberdine"] .. ", " .. L["Darkshore"], nil, fATex, nil, nil, nil, nil, nil, 0, 1439},
			{"Spirit", 11.0, 43.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 49.3, 41.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 51.3, 10.3, L["Arathi Highlands"], L["Thandol Span"], arTex, nil, nil, nil, nil, nil, 0, 1417},
			{"Arrow", 56.0, 70.3, L["Loch Modan"], L["Dun Algaz"], arTex, nil, nil, nil, nil, nil, 1.8, 1432},
		},
		--[[Stormwind City]] [1453] = {
			{"Dungeon", 42.3, 59.0, L["The Stockade"], L["Dungeon"], dnTex, 24, 32},
			{"FlightA", 66.3, 62.1, L["Trade District"] .. ", " .. L["Stormwind"], nil, tATex, nil, nil},
			{"TravelA", 60.5, 12.4, L["Tram to"] .. " " .. L["Tinker Town"] .. ", " .. L["Ironforge"], nil, fATex, nil, nil, nil, nil, nil, 0, 1455},
			{"Arrow", 62.3, 72.3, L["Elwynn Forest"], nil, arTex, nil, nil, nil, nil, nil, 3.8, 1429},
		},
		--[[Ironforge]] [1455] = {
			{"FlightA", 55.5, 47.8, L["The Great Forge"] .. ", " .. L["Ironforge"], nil, tATex, nil, nil},
			{"TravelA", 73.0, 50.2, L["Tram to"] .. " " .. L["Dwarven District"] .. ", " .. L["Stormwind"], nil, fATex, nil, nil, nil, nil, nil, 0, 1453},
			{"Arrow", 21.9, 77.5, L["Dun Morogh"], nil, arTex, nil, nil, nil, nil, nil, 2.2, 1426},
		},
		--[[Undercity]] [1458] = {
			{"FlightH", 63.3, 48.5, L["Trade Quarter"] .. ", " .. L["Undercity"], nil, tHTex, nil, nil},
			{"Spirit", 67.9, 14.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 66.2, 5.2, L["Tirisfal Glades"], nil, arTex, nil, nil, nil, nil, nil, 0, 1420},
		},

		----------------------------------------------------------------------
		--	Kalimdor
		----------------------------------------------------------------------

		--[[Durotar]] [1411] = {
			{"TravelH", 50.9, 13.9, L["Zeppelin to"] .. " " .. L["Undercity"] .. ", " .. L["Tirisfal Glades"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1420},
			{"TravelH", 50.6, 12.6, L["Zeppelin to"] .. " " .. L["Grom'gol Base Camp"] .. ", " .. L["Stranglethorn Vale"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1434},
			{"Spirit", 47.4, 17.9, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 53.5, 44.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 44.2, 69.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 57.2, 73.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 35.1, 42.4, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1413},
			{"Arrow", 45.5, 12.3, L["Orgrimmar"], nil, arTex, nil, nil, nil, nil, nil, 0, 1454},
		},
		--[[Mulgore]] [1412] = {
			{"Spirit", 46.5, 55.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 42.6, 78.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 69.0, 60.5, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 4.9, 1413},
			{"Arrow", 37.7, 32.9, L["Thunder Bluff"], L["South"], arTex, nil, nil, nil, nil, nil, 0.9, 1456},
			{"Arrow", 40.5, 20.1, L["Thunder Bluff"], L["North"], arTex, nil, nil, nil, nil, nil, 2.8, 1456},
		},
		--[[The Barrens]] [1413] = {
			{"Dungeon", 46.0, 36.4, L["Wailing Caverns"], L["Dungeon"], dnTex, 17, 24}, {"Dungeon", 42.9, 90.2, L["Razorfen Kraul"], L["Dungeon"], dnTex, 29, 38}, {"Dungeon", 49.0, 93.9, L["Razorfen Downs"], L["Dungeon"], dnTex, 37, 46},
			{"FlightN", 63.1, 37.2, L["Ratchet"] .. ", " .. L["The Barrens"], nil, tNTex, nil, nil},
			{"FlightH", 51.5, 30.3, L["The Crossroads"] .. ", " .. L["The Barrens"], nil, tHTex, nil, nil},
			{"FlightH", 44.4, 59.2, L["Camp Taurajo"] .. ", " .. L["The Barrens"], nil, tHTex, nil, nil},
			{"TravelN", 63.7, 38.6, L["Boat to"] .. " " .. L["Booty Bay"] .. ", " .. L["Stranglethorn Vale"], nil, fNTex, nil, nil, nil, nil, nil, 0, 1434},
			{"Spirit", 50.7, 32.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 60.2, 39.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 45.3, 61.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 45.8, 82.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 41.2, 58.6, L["Mulgore"], nil, arTex, nil, nil, nil, nil, nil, 1.6, 1412},
			{"Arrow", 49.8, 78.4, L["Dustwallow Marsh"], nil, arTex, nil, nil, nil, nil, nil, 4.7, 1445},
			{"Arrow", 44.1, 91.5, L["Thousand Needles"], L["The Great Lift"], arTex, nil, nil, nil, nil, nil, 3, 1441},
			{"Arrow", 36.3, 27.5, L["Stonetalon Mountains"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1442},
			{"Arrow", 48.8, 7.1, L["Ashenvale"], nil, arTex, nil, nil, nil, nil, nil, 0, 1440},
			{"Arrow", 62.6, 19.2, L["Durotar"], nil, arTex, nil, nil, nil, nil, nil, 4.6, 1411},
		},
		--[[Teldrassil]] [1438] = {
			{"FlightA", 58.4, 94.0, L["Rut'theran Village"] .. ", " .. L["Teldrassil"], nil, tATex, nil, nil},
			{"TravelA", 54.9, 96.8, L["Boat to"] .. " " .. L["Auberdine"] .. ", " .. L["Darkshore"], nil, fATex, nil, nil, nil, nil, nil, 0, 1439},
			{"Arrow", 55.9, 89.7, L["Darnassus"], "", arTex, nil, nil, nil, nil, nil, 0.3, 1457},
			{"Spirit", 58.7, 42.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 56.2, 63.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 36.2, 54.4, L["Darnassus"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1457},
		},
		--[[Darkshore]] [1439] = {
			{"FlightA", 36.3, 45.6, L["Auberdine"] .. ", " .. L["Darkshore"], nil, tATex, nil, nil},
			{"TravelA", 32.4, 43.8, L["Boat to"] .. " " .. L["Menethil Harbor"] .. ", " .. L["Wetlands"], nil, fATex, nil, nil, nil, nil, nil, 0, 1437},
			{"TravelA", 33.2, 40.1, L["Boat to"] .. " " .. L["Rut'theran Village"] .. ", " .. L["Teldrassil"], nil, fATex, nil, nil, nil, nil, nil, 0, 1438},
			{"Spirit", 41.8, 36.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 43.6, 92.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 43.3, 94.0, L["Ashenvale"], nil, arTex, nil, nil, nil, nil, nil, 4, 1440},
			{"Arrow", 37.5, 94.8, L["Ashenvale"], nil, arTex, nil, nil, nil, nil, nil, 3.1, 1440},
			{"Arrow", 27.7, 92.9, L["Ashenvale"], L["The Zoram Strand"], arTex, nil, nil, nil, nil, nil, 2.5, 1440},
		},
		--[[Ashenvale]] [1440] = {
			{"Dungeon", 14.5, 14.2, L["Blackfathom Deeps"], L["Dungeon"], dnTex, 24, 32},
			{"FlightA", 34.4, 48.0, L["Astranaar"] .. ", " .. L["Ashenvale"], nil, tATex, nil, nil},
			{"FlightH", 73.2, 61.6, L["Splintertree Post"] .. ", " .. L["Ashenvale"], nil, tHTex, nil, nil},
			{"FlightH", 12.2, 33.8, L["Zoram'gar Outpost"] .. ", " .. L["Ashenvale"], nil, tHTex, nil, nil},
			{"Spirit", 40.5, 52.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 80.7, 58.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 29.1, 14.8, L["Darkshore"], nil, arTex, nil, nil, nil, nil, nil, 0, 1439},
			{"Arrow", 42.3, 71.1, L["Stonetalon Mountains"], L["The Talondeep Path"], arTex, nil, nil, nil, nil, nil, 2.7, 1442},
			{"Arrow", 55.8, 30.2, L["Felwood"], nil, arTex, nil, nil, nil, nil, nil, 0, 1448},
			{"Arrow", 94.2, 47.3, L["Azshara"], nil, arTex, nil, nil, nil, nil, nil, 4.4, 1447},
			{"Arrow", 68.6, 86.8, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 3.2, 1413},
			{"Arrow", 20.6, 16.1, L["Darkshore"], nil, arTex, nil, nil, nil, nil, nil, 6.1, 1439},
			{"Arrow", 9.5, 10.7, L["Darkshore"], L["Twilight Shore"], arTex, nil, nil, nil, nil, nil, 5.3, 1439},
		},
		--[[Thousand Needles]] [1441] = {
			{"FlightH", 45.1, 49.1, L["Freewind Post"] .. ", " .. L["Thousand Needles"], nil, tHTex, nil, nil},
			{"Spirit", 30.6, 23.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 68.7, 53.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 74.9, 93.3, L["Tanaris"], nil, arTex, nil, nil, nil, nil, nil, 3.2, 1446},
			{"Arrow", 8.3, 11.9, L["Feralas"], nil, arTex, nil, nil, nil, nil, nil, 0.7, 1444},
			{"Arrow", 32.2, 23.9, L["The Barrens"], L["The Great Lift"], arTex, nil, nil, nil, nil, nil, 5.4, 1413},
		},
		--[[Stonetalon Mountains]] [1442] = {
			{"FlightA", 36.4, 7.2, L["Stonetalon Peak"] .. ", " .. L["Stonetalon Mountains"], nil, tATex, nil, nil},
			{"FlightH", 45.1, 59.8, L["Sun Rock Retreat"] .. ", " .. L["Stonetalon Mountains"], nil, tHTex, nil, nil},
			{"Spirit", 40.3, 5.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 36.4, 75.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 57.5, 61.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 80.2, 92.4, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 3.4, 1413},
			{"Arrow", 30.4, 75.4, L["Desolace"], nil, arTex, nil, nil, nil, nil, nil, 2.7, 1443},
			{"Arrow", 78.2, 42.8, L["Ashenvale"], L["The Talondeep Path"], arTex, nil, nil, nil, nil, nil, 6.1, 1440},
			{"Arrow", 37.9, 67.8, L["Sun Rock Retreat"], L["Mountain Pass (Horde Only)"], arTex, nil, nil, nil, nil, nil, 4.1, 1442},
		},
		--[[Desolace]] [1443] = {
			{"Dungeon", 29.1, 62.5, L["Maraudon"], L["Dungeon"], dnTex, 46, 55},
			{"FlightA", 64.7, 10.5, L["Nijel's Point"] .. ", " .. L["Desolace"], nil, tATex, nil, nil},
			{"FlightH", 21.6, 74.1, L["Shadowprey Village"] .. ", " .. L["Desolace"], nil, tHTex, nil, nil},
			{"Spirit", 50.4, 62.9, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 53.4, 5.9, L["Stonetalon Mountains"], nil, arTex, nil, nil, nil, nil, nil, 5.9, 1442},
			{"Arrow", 41.6, 94.4, L["Feralas"], nil, arTex, nil, nil, nil, nil, nil, 3.3, 1444},
		},
		--[[Feralas]] [1444] = {
			{"FlightA", 30.2, 43.2, L["Feathermoon Stronghold"] .. ", " .. L["Feralas"], nil, tATex, nil, nil},
			{"FlightH", 75.4, 44.4, L["Camp Mojache"] .. ", " .. L["Feralas"], nil, tHTex, nil, nil},
			{"FlightA", 89.5, 45.9, L["Thalanaar"] .. ", " .. L["Feralas"], nil, tATex, nil, nil},
			{"Dungeon", 62.5, 24.9, L["Dire Maul (North)"], L["Dungeon"], dnTex, 56, 60},
			{"Dungeon", 60.3, 30.2, L["Dire Maul (West)"], L["Dungeon"], dnTex, 56, 60},
			{"Dungeon", 64.8, 30.2, L["Dire Maul (East)"], L["Dungeon"], dnTex, 56, 60},
			{"TravelA", 43.3, 42.8, L["Boat to"] .. " " .. L["Feathermoon Stronghold"] .. ", " .. L["Feralas"], nil, fATex, nil, nil},
			{"TravelA", 31.0, 39.8, L["Boat to"] .. " " .. L["The Forgotten Coast"] .. ", " .. L["Feralas"], nil, fATex, nil, nil},
			{"Spirit", 31.8, 48.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 54.8, 48.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 73.0, 44.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 44.9, 7.7, L["Desolace"], nil, arTex, nil, nil, nil, nil, nil, 6, 1443},
			{"Arrow", 88.7, 41.1, L["Thousand Needles"], nil, arTex, nil, nil, nil, nil, nil, 4.5, 1441},
			-- {"Dungeon", 77.1, 36.9, L["Dire Maul (East)"], L["The Hidden Reach (requires Crescent Key)"], dnTex, 56, 60},
		},
		--[[Dustwallow Marsh]] [1445] = {
			{"Raid", 52.6, 76.8, L["Onyxia's Lair"], L["Raid"], rdTex, 60, 60},
			{"FlightA", 67.5, 51.3, L["Theramore Isle"] .. ", " .. L["Dustwallow Marsh"], nil, tATex, nil, nil},
			{"FlightH", 35.6, 31.9, L["Brackenwall Village"] .. ", " .. L["Dustwallow Marsh"], nil, tHTex, nil, nil},
			{"TravelA", 71.6, 56.4, L["Boat to"] .. " " .. L["Menethil Harbor"] .. ", " .. L["Wetlands"], nil, fATex, nil, nil, nil, nil, nil, 0, 1437},
			{"Spirit", 39.5, 31.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 46.6, 57.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 41.2, 74.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 63.6, 42.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 30.0, 47.1, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 1.6, 1413},
		},
		--[[Tanaris]] [1446] = {
			{"Dungeon", 38.7, 20.0, L["Zul'Farrak"], L["Dungeon"], dnTex, 44, 54},
			{"FlightA", 51.0, 29.3, L["Gadgetzan"] .. ", " .. L["Tanaris"], nil, tATex, nil, nil},
			{"FlightH", 51.6, 25.4, L["Gadgetzan"] .. ", " .. L["Tanaris"], nil, tHTex, nil, nil},
			{"Spirit", 53.9, 28.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 49.4, 59.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 69.0, 40.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 50.6, 24.4, L["Thousand Needles"], nil, arTex, nil, nil, nil, nil, nil, 5.7, 1441},
			{"Arrow", 27.1, 57.7, L["Un'Goro Crater"], nil, arTex, nil, nil, nil, nil, nil, 0.5, 1449},
		},
		--[[Azshara]] [1447] = {
			{"FlightA", 11.9, 77.6, L["Talrendis Point"] .. ", " .. L["Azshara"], nil, tATex, nil, nil},
			{"FlightH", 22.0, 49.6, L["Valormok"] .. ", " .. L["Azshara"], nil, tHTex, nil, nil},
			{"Spirit", 70.4, 16.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 54.3, 71.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 14.0, 78.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 10.6, 75.3, L["Ashenvale"], nil, arTex, nil, nil, nil, nil, nil, 0.9, 1440},
		},
		--[[Felwood]] [1448] = {
			{"FlightA", 62.5, 24.2, L["Talonbranch Glade"] .. ", " .. L["Felwood"], nil, tATex, nil, nil},
			{"FlightH", 34.4, 54.0, L["Bloodvenom Post"] .. ", " .. L["Felwood"], nil, tHTex, nil, nil},
			{"Spirit", 49.5, 31.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 56.8, 87.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 65.0, 8.3, L["Winterspring"], L["Timbermaw Hold"], arTex, nil, nil, nil, nil, nil, 5.9, 1452},
			{"Arrow", 54.5, 89.2, L["Ashenvale"], nil, arTex, nil, nil, nil, nil, nil, 3, 1440},
		},
		--[[Un'Goro Crater]] [1449] = {
			{"FlightN", 45.2, 5.8, L["Marshal's Refuge"] .. ", " .. L["Un'Goro Crater"], nil, tNTex, nil, nil},
			{"Spirit", 45.3, 7.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 50.0, 56.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 80.3, 50.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 70.5, 78.6, L["Tanaris"], nil, arTex, nil, nil, nil, nil, nil, 3.3, 1446},
			{"Arrow", 29.4, 22.3, L["Silithus"], nil, arTex, nil, nil, nil, nil, nil, 0.9, 1451},
		},
		--[[Moonglade]] [1450] =  {
			{"FlightA", 48.1, 67.4, L["Lake Elune'ara"] .. ", " .. L["Moonglade"], nil, tATex, nil, nil},
			{"FlightH", 32.1, 66.6, L["Moonglade"], nil, tHTex, nil, nil},
			{"Spirit", 62.2, 70.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 35.7, 72.4, L["Felwood"] .. ", " .. L["Winterspring"], L["Timbermaw Hold"], arTex, nil, nil, nil, nil, nil, 3, 1448},
		},
		--[[Silithus]] [1451] = {
			{"Raid", 28.6, 92.4, L["Ahn'Qiraj"], L["Ruins of Ahn'Qiraj"] .. ", " .. L["Temple of Ahn'Qiraj"], rdTex, 60, 60},
			{"FlightA", 50.6, 34.5, L["Cenarion Hold"] .. ", " .. L["Silithus"], nil, tATex, nil, nil},
			{"FlightH", 48.7, 36.7, L["Cenarion Hold"] .. ", " .. L["Silithus"], nil, tHTex, nil, nil},
			{"Spirit", 47.2, 37.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 28.2, 87.1, L["Spirit Healer"], "(" .. L["Ahn'Qiraj"] .. ")", spTex, nil, nil},
			{"Spirit", 81.2, 20.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 82.4, 16.0, L["Un'Goro Crater"], nil, arTex, nil, nil, nil, nil, nil, 5.4, 1449},
		},
		--[[Winterspring]] [1452] = {
			{"FlightA", 62.3, 36.6, L["Everlook"] .. ", " .. L["Winterspring"], nil, tATex, nil, nil},
			{"FlightH", 60.5, 36.3, L["Everlook"] .. ", " .. L["Winterspring"], nil, tHTex, nil, nil},
			{"Spirit", 61.5, 35.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 62.7, 61.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 27.9, 34.5, L["Felwood"], L["Timbermaw Hold"], arTex, nil, nil, nil, nil, nil, 0.7, 1448},
		},
		--[[Orgrimmar]] [1454] =  {
			{"Dungeon", 52.6, 49.0, L["Ragefire Chasm"], L["Dungeon"], dnTex, 13, 18},
			{"FlightH", 45.1, 63.9, L["Valley of Strength"] .. ", " .. L["Orgrimmar"], nil, tHTex, nil, nil},
			{"Arrow", 52.4, 83.7, L["Durotar"], nil, arTex, nil, nil, nil, nil, nil, 3, 1411},
			{"Arrow", 18.1, 60.6, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 2.1, 1413},
		},
		--[[Thunder Bluff]] [1456] = {
			{"FlightH", 47.0, 49.8, L["Central Mesa"] .. ", " .. L["Thunder Bluff"], nil, tHTex, nil, nil},
			{"Spirit", 56.7, 19.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 35.7, 62.8, L["Mulgore"], L["South"], arTex, nil, nil, nil, nil, nil, 2.0, 1412},
			{"Arrow", 51.3, 31.3, L["Mulgore"], L["North"], arTex, nil, nil, nil, nil, nil, 5.7, 1412},
		},
		--[[Darnassus]] [1457] = {
			{"Spirit", 77.7, 25.9, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 30.3, 41.4, L["Teldrassil"], L["Rut'theran Village"], arTex, nil, nil, nil, nil, nil, 1.5, 1438},
			{"Arrow", 86.9, 35.8, L["Teldrassil"], nil, arTex, nil, nil, nil, nil, nil, 4.8, 1438},
		},

		----------------------------------------------------------------------
		--	BCC
		----------------------------------------------------------------------

		--[[Isle of Quel'Danas]] [1957] = {
			{"Spirit", 46.6, 32.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Dungeon", 61.2, 30.9, L["Magisters' Terrace"], L["Dungeon"], dnTex, 68, 70},
			{"Raid", 44.3, 45.6, L["Sunwell Plateau"], L["Raid"], rdTex, 70, 70}, -- The Sunwell
			{"FlightA", 48.5, 25.2, L["Shattered Sun Staging Area"] .. ", " .. L["Isle of Quel Danas"], nil, tATex, nil, nil},
			{"FlightH", 48.4, 25.1, L["Shattered Sun Staging Area"] .. ", " .. L["Isle of Quel Danas"], nil, tHTex, nil, nil},
		},

		--[[Eversong Woods]] [1941] = {
			{"FlightH", 43.9, 70.0, L["Fairbreeze Village"] .. ", " .. L["Eversong Woods"], nil, tHTex, nil, nil},
			{"FlightH", 54.4, 50.7, L["Silvermoon City"] .. ", " .. L["Eversong Woods"], nil, tHTex, nil, nil},
			{"FlightH", 46.2, 46.8, L["Falconwing Square"] .. ", " .. L["Eversong Woods"], nil, tHTex, nil, nil},
			{"Spirit", 38.2, 17.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 48.0, 49.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 44.3, 71.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 60.0, 64.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 48.7, 91.0, L["Ghostlands"], nil, arTex, nil, nil, nil, nil, nil, 3, 1942},
			{"Arrow", 56.7, 49.7, L["Silvermoon City"], nil, arTex, nil, nil, nil, nil, nil, 0.0, 1954},
		},

		--[[Ghostlands]] [1942] = {
			{"Dungeon", 82.3, 64.3, L["Zul'Aman"], L["Dungeon"], dnTex, 70, 70},
			{"FlightH", 45.4, 30.5, L["Tranquillien"] .. ", " .. L["Ghostlands"], nil, tHTex, nil, nil},
			{"FlightN", 74.7, 67.1, L["Zul'Aman"] .. ", " .. L["Ghostlands"], nil, tNTex, nil, nil},
			{"Spirit", 43.9, 25.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 61.5, 57.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 80.5, 69.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 47.5, 84.0, L["Eastern Plaguelands"], nil, arTex, nil, nil, nil, nil, nil, 3, 1423},
			{"Arrow", 48.4, 13.2, L["Eversong Woods"], nil, arTex, nil, nil, nil, nil, nil, 0, 1941},
		},

		--[[Silvermoon City]] [1954] = {
			{"TravelH", 49.5, 14.8, L["Undercity"], L["Orb of Translocation"], nil, nil, nil, nil, nil, nil, 0, 1458},
			{"Arrow", 72.6, 85.9, L["Eversong Woods"], nil, arTex, nil, nil, nil, nil, nil, 3.2, 1941},
		},

		--[[The Exodar]] [1947] = {
			{"FlightA", 54.5, 36.3, L["The Exodar"] .. ", " .. L["Azuremyst Isle"], nil, tATex, nil, nil},
			{"TravelA", 48.3, 62.9, L["Stormwind"], L["Portal"], pATex},
			{"Arrow", 76.0, 55.5, L["Azuremyst Isle"], L["Seat of the Naaru"], arTex, nil, nil, nil, nil, nil, 4.5, 1943},
			{"Arrow", 35.0, 74.8, L["Azuremyst Isle"], L["The Vault of Lights"], arTex, nil, nil, nil, nil, nil, 0.9, 1943},
		},

		--[[Azuremyst Isle]] [1943] = {
			{"FlightA", 49.7, 49.1, L["Azure Watch"] .. ", " .. L["Azuremyst Isle"], nil, tATex, nil, nil},
			{"TravelA", 20.3, 54.2, L["Boat to"] .. " " .. L["Rut'theran Village"] .. ", " .. L["Teldrassil"], nil, fATex, nil, nil, nil, nil, nil, 0, 1439},
			{"Spirit", 39.2, 19.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 47.2, 55.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 77.7, 48.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 36.9, 47.0, L["The Exodar"], L["Seat of the Naaru"], arTex, nil, nil, nil, nil, nil, 1.5, 1947},
			{"Arrow", 24.7, 49.4, L["The Exodar"], L["The Vault of Lights"], arTex, nil, nil, nil, nil, nil, 5.8, 1947},
			{"Arrow", 42.5, 5.4, L["Bloodmyst Isle"], nil, arTex, nil, nil, nil, nil, nil, 0.2, 1950},
		},

		--[[Bloodmyst Isle]] [1950] = {
			{"FlightA", 57.7, 53.9, L["Blood Watch"] .. ", " .. L["Bloodmyst Isle"], nil, tATex, nil, nil},
			{"Spirit", 30.1, 45.9, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 58.1, 57.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 65.4, 92.6, L["Azuremyst Isle"], nil, arTex, nil, nil, nil, nil, nil, 3, 1943},
		},

		--[[Blade's Edge Mountains]] [1949] = {
			{"Raid", 68.7, 24.3, L["Gruul's Lair"], L["Raid"], rdTex, 70, 70},
			{"FlightA", 37.8, 61.4, L["Sylvanaar"] .. ", " .. L["Blade's Edge Mountains"], nil, tATex, nil, nil},
			{"FlightA", 61.0, 70.4, L["Toshley's Station"] .. ", " .. L["Blade's Edge Mountains"], nil, tATex, nil, nil},
			{"FlightH", 52.0, 54.2, L["Thunderlord Stronghold"] .. ", " .. L["Blade's Edge Mountains"], nil, tHTex, nil, nil},
			{"FlightH", 76.4, 65.8, L["Mok'Nathal Village"] .. ", " .. L["Blade's Edge Mountains"], nil, tHTex, nil, nil},
			{"FlightN", 61.6, 39.6, L["Evergrove"] .. ", " .. L["Blade's Edge Mountains"], nil, tNTex, nil, nil},
			{"Spirit", 37.2, 24.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 33.6, 58.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 38.3, 67.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 52.1, 60.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 60.4, 66.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 69.3, 58.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 74.6, 26.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 62.8, 37.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 61.8, 14.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 37.3, 80.5, L["Zangarmarsh"], L["Blade Tooth Canyon"], arTex, nil, nil, nil, nil, nil, 3, 1946},
			{"Arrow", 51.7, 74.7, L["Zangarmarsh"], L["Blades' Run"], arTex, nil, nil, nil, nil, nil, 3, 1946},
			{"Arrow", 82.4, 28.7, L["Netherstorm"], nil, arTex, nil, nil, nil, nil, nil, 4.7, 1953},
		},

		--[[Hellfire Peninsula]] [1944] = {
			{"Dungeon", 47.7, 53.6, L["Hellfire Ramparts"], L["Dungeon"], dnTex, 58, 67},
			{"Dungeon", 47.7, 52.0, L["The Shattered Halls"], L["Dungeon"], dnTex, 69, 70},
			{"Dungeon", 46.0, 51.8, L["The Blood Furnace"], L["Dungeon"], dnTex, 61, 68},
			{"Raid", 46.6, 52.8, L["Magtheridon's Lair"], L["Raid"], rdTex, 70, 70},
			{"FlightA", 25.2, 37.2, L["Temple of Telhamat"] .. ", " .. L["Hellfire Peninsula"], nil, tATex, nil, nil},
			{"FlightA", 54.6, 62.4, L["Honor Hold"] .. ", " .. L["Hellfire Peninsula"], nil, tATex, nil, nil},
			{"FlightA", 87.4, 52.4, L["The Dark Portal"] .. ", " .. L["Hellfire Peninsula"], nil, tATex, nil, nil},
			{"FlightH", 56.2, 36.2, L["Thrallmar"] .. ", " .. L["Hellfire Peninsula"], nil, tHTex, nil, nil},
			{"FlightH", 27.8, 60.0, L["Falcon Watch"] .. ", " .. L["Hellfire Peninsula"], nil, tHTex, nil, nil},
			{"FlightH", 87.4, 48.2, L["The Dark Portal"] .. ", " .. L["Hellfire Peninsula"], nil, tHTex, nil, nil},
			{"FlightH", 61.6, 81.2, L["Spinebreaker Ridge"] .. ", " .. L["Hellfire Peninsula"], nil, tHTex, nil, nil},
			{"FlightA", 78.4, 34.9, L["Shatter Point"] .. ", " .. L["Hellfire Peninsula"], nil, tATex, nil, nil},
			{"TravelA", 88.6, 52.8, L["Stormwind City"], L["Portal"], pATex, nil, nil, nil, nil, nil, 0, 1453},
			{"TravelH", 88.6, 47.7, L["Orgrimmar"], L["Portal"], pHTex, nil, nil, nil, nil, nil, 0, 1454},
			{"PortalH", 88.6, 47.7, L["Orgrimmar"], L["Portal"]},
			{"PortalA", 88.6, 52.8, L["Stormwind"], L["Portal"]},
			{"Spirit", 22.8, 38.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 27.7, 63.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 60.0, 79.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 54.5, 66.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 57.5, 38.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 64.3, 22.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 86.8, 51.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 68.7, 27.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 40.3, 85.9, L["Terokkar Forest"], L["Razorthorn Trail"], arTex, nil, nil, nil, nil, nil, 2.7, 1952},
			{"Arrow", 6.7, 50.4, L["Zangarmarsh"], nil, arTex, nil, nil, nil, nil, nil, 1.6, 1946},
		},

		--[[Nagrand]] [1951] = {
			{"FlightA", 54.2, 75.0, L["Telaar"] .. ", " .. L["Nagrand"], nil, tATex, nil, nil},
			{"FlightH", 57.2, 35.2, L["Garadar"] .. ", " .. L["Nagrand"], nil, tHTex, nil, nil},
			{"Spirit", 20.4, 36.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 32.8, 56.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 39.8, 30.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 42.5, 46.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 66.6, 24.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 63.1, 69.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 33.5, 17.8, L["Zangararsh"], nil, arTex, nil, nil, nil, nil, nil, 0, 1946},
			{"Arrow", 77.5, 77.0, L["Terokkar Forest"], nil, arTex, nil, nil, nil, nil, nil, 3.7, 1952},
			{"Arrow", 72.3, 36.6, L["Zangarmarsh"], nil, arTex, nil, nil, nil, nil, nil, 5.4, 1946},
			{"Arrow", 77.5, 55.7, L["Shattrath City"], L["Aldor"], arTex, nil, nil, nil, nil, nil, 5.4, 1955},
		},

		--[[Netherstorm]] [1953] = {
			{"Dungeon", 71.7, 55.0, L["The Botanica"], L["Dungeon"], dnTex, 70, 70},
			{"Dungeon", 74.4, 57.7, L["The Arcatraz"], L["Dungeon"], dnTex, 70, 70},
			{"Dungeon", 70.6, 69.7, L["The Mechanar"], L["Dungeon"], dnTex, 70, 70},
			{"Raid", 73.7, 63.7, L["The Eye"], L["Raid"], rdTex, 70, 70, nil, 69, 70}, -- Tempest Keep
			{"FlightN", 33.8, 64.0, L["Area 52"] .. ", " .. L["Netherstorm"], nil, tNTex, nil, nil},
			{"FlightN", 45.2, 34.8, L["The Stormspire"] .. ", " .. L["Netherstorm"], nil, tNTex, nil, nil},
			{"FlightN", 65.2, 66.6, L["Cosmowrench"] .. ", " .. L["Netherstorm"], nil, tNTex, nil, nil},
			{"Spirit", 42.9, 29.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 33.8, 65.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 64.8, 66.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 56.6, 83.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 22.7, 55.6, L["Blade's Edge Mountains"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1949},
		},

		--[[Shadowmoon Valley]] [1948] = {
			{"Raid", 71.0, 46.4, L["Black Temple"], L["Raid"], rdTex, 70, 70},
			{"FlightA", 37.6, 55.4, L["Wildhammer Stronghold"] .. ", " .. L["Shadowmoon Valley"], nil, tATex, nil, nil},
			{"FlightH", 30.2, 29.2, L["Shadowmoon Village"] .. ", " .. L["Shadowmoon Valley"], nil, tHTex, nil, nil},
			{"FlightN", 63.4, 30.4, L["Altar of Sha'tar"] .. ", " .. L["Shadowmoon Valley"], nil, tNTex, nil, nil},
			{"FlightN", 56.2, 57.8, L["Sanctum of the Stars"] .. ", " .. L["Shadowmoon Valley"], nil, tNTex, nil, nil},
			{"Spirit", 32.2, 28.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 39.5, 56.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 57.5, 59.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 63.6, 32.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 65.5, 43.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 65.7, 45.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 22.7, 28.6, L["Terokkar Forest"], nil, arTex, nil, nil, nil, nil, nil, 0.8, 1952},
		},

		--[[Shattrath City]] [1955] = {
			{"FlightN", 64.1, 41.1, L["Shattrath City"] .. ", " .. L["Terokkar Forest"], nil, tNTex, nil, nil},
			{"TravelN", 48.5, 42.0, L["Isle of Quel'Danas"], L["Portal"], pNTex, nil, nil, nil, nil, nil, 0, 1957},
			{"TravelA", 55.8, 36.5, L["Alliance Cities"], L["Darnassus"] .. ", " .. L["Stormwind"] .. ", " .. L["Ironforge"], pATex},
			{"TravelH", 52.2, 52.9, L["Horde Cities"], L["Thunder Bluff"] .. ", " .. L["Orgrimmar"] .. ", " .. L["Undercity"], pHTex},
			{"TravelA", 59.6, 46.7, L["The Exodar"], L["Portal"], pATex},
			{"TravelH", 59.2, 48.4, L["Silvermoon City"], L["Portal"], pHTex},
			--{"TravelA", 57.2, 48.2, L["Stormwind City"] .. ", " .. L["Elwynn Forest"], L["Portal"], pATex},
			--{"TravelH", 56.8, 48.9, L["Orgrimmar"] .. ", " .. L["Durotar"], L["Portal"], pHTex},
			{"Arrow", 62.3, 7.9, L["Terokkar Forest"], nil, arTex, nil, nil, nil, nil, nil, 6.1, 1952},
			{"Arrow", 79.0, 57.5, L["Terokkar Forest"], nil, arTex, nil, nil, nil, nil, nil, 4, 1952},
			{"Arrow", 23.0, 49.5, L["Nagrand"], L["Aldor"], arTex, nil, nil, nil, nil, nil, 1.9, 1951},
			{"Arrow", 68.3, 65.1, L["Terokkar Forest"], nil, arTex, nil, nil, nil, nil, nil, 3.9, 1952},
			{"Arrow", 71.1, 21.9, L["Terokkar Forest"], nil, arTex, nil, nil, nil, nil, nil, 5.8, 1952},
			{"Arrow", 76.3, 43.2, L["Terokkar Forest"], nil, arTex, nil, nil, nil, nil, nil, 4.7, 1952},
		},

		--[[Terokkar Forest]] [1952] = {
			{"Dungeon", 43.2, 65.6, L["Sethekk Halls"], L["Dungeon"], dnTex, 67, 70},
			{"Dungeon", 36.1, 65.6, L["Auchenai Crypts"], L["Dungeon"], dnTex, 65, 70},
			{"Dungeon", 39.6, 71.0, L["Shadow Labyrinth"], L["Dungeon"], dnTex, 69, 70},
			{"Dungeon", 39.7, 60.2, L["Mana-Tombs"], L["Dungeon"], dnTex, 64, 70},
			{"FlightA", 59.4, 55.4, L["Allerian Stronghold"] .. ", " .. L["Terokkar Forest"], nil, tATex, nil, nil},
			{"FlightH", 49.2, 43.4, L["Stonebreaker Hold"] .. ", " .. L["Terokkar Forest"], nil, tHTex, nil, nil},
			{"FlightN", 33.1, 23.1, L["Shattrath City"] .. ", " .. L["Terokkar Forest"], nil, tNTex, nil, nil},
			{"Spirit", 39.9, 21.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 44.8, 40.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 59.5, 42.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 44.6, 71.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 62.9, 81.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 70.6, 49.4, L["Shadowmoon Valley"], nil, arTex, nil, nil, nil, nil, nil, 3.9, 1948},
			{"Arrow", 58.3, 19.3, L["Hellfire Peninsula"], L["Razorthorn Trail"], arTex, nil, nil, nil, nil, nil, 5.0, 1944},
			{"Arrow", 20.3, 56.3, L["Nagrand"], nil, arTex, nil, nil, nil, nil, nil, 0.3, 1951},
			{"Arrow", 33.1, 6.2, L["Zangarmarsh"], nil, arTex, nil, nil, nil, nil, nil, 0.6, 1946},
			{"Arrow", 34.8, 13.4, L["Shattrath City"], nil, arTex, nil, nil, nil, nil, nil, 2.4, 1955},
			{"Arrow", 38.2, 26.6, L["Shattrath City"], nil, arTex, nil, nil, nil, nil, nil, 1.4, 1955},
		},

		--[[Zangarmarsh]] [1946] = {
			{"Dunraid", 50.4, 40.9, L["Coilfang Reservoir"],
				L["Slave Pens"]  .. " (62-69)|n" ..
				L["Underbog"]  .. " (63-70)|n" ..
				L["Steamvault"]  .. " (69-70)|n" ..
				L["Serpentshrine Cavern"]  .. " (70)",
				dnTex, 62, 70, nil, 61, 70},
			{"FlightA", 41.2, 28.8, L["Orebor Harborage"] .. ", " .. L["Zangarmarsh"], nil, tATex, nil, nil},
			{"FlightA", 67.8, 51.4, L["Telredor"] .. ", " .. L["Zangarmarsh"], nil, tATex, nil, nil},
			{"FlightH", 33.0, 51.0, L["Zabra'jin"] .. ", " .. L["Zangarmarsh"], nil, tHTex, nil, nil},
			{"FlightH", 84.8, 55.0, L["Swamprat Post"] .. ", " .. L["Zangarmarsh"], nil, tHTex, nil, nil},
			{"Spirit", 17.0, 48.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 36.8, 47.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 43.6, 31.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 47.5, 50.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 65.1, 50.9, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 77.2, 64.1, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 81.2, 64.4, L["Hellfire Peninsula"], nil, arTex, nil, nil, nil, nil, nil, 5.4, 1944},
			{"Arrow", 82.0, 90.8, L["Terokkar Forest"], nil, arTex, nil, nil, nil, nil, nil, 3.3, 1952},
			{"Arrow", 69.6, 35.3, L["Blade's Edge Mountains"], L["Blades' Run"], arTex, nil, nil, nil, nil, nil, 5.4, 1949},
			{"Arrow", 40.8, 31.0, L["Blade's Edge Mountains"], L["Blade Tooth Canyon"], arTex, nil, nil, nil, nil, nil, 5.4, 1949},
			{"Arrow", 21.1, 70.5, L["Nagrand"], nil, arTex, nil, nil, nil, nil, nil, 3.1, 1951},
			{"Arrow", 67.9, 86.9, L["Nagrand"], nil, arTex, nil, nil, nil, nil, nil, 2.6, 1951},
		},

	}

	local frame = CreateFrame("FRAME")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:SetScript("OnEvent", function()

		-- Add situational data
		local void, class = UnitClass("player")
		if class == "DRUID" then
			-- Moonglade flight points for druids only
			tinsert(Leatrix_Maps["Icons"][1450], {"FlightA", 44.1, 45.2, L["Nighthaven"] .. ", " .. L["Moonglade"], L["Druid only flight point to Darnassus"], tATex, nil, nil})
			tinsert(Leatrix_Maps["Icons"][1450], {"FlightH", 44.3, 45.9, L["Nighthaven"] .. ", " .. L["Moonglade"], L["Druid only flight point to Thunder Bluff"], tHTex, nil, nil})
		end

	end)
