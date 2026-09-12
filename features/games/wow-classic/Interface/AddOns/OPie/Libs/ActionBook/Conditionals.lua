local COMPAT, _, T = select(4, GetBuildInfo()), ...
if T.SkipLocalActionBook then return end
if T.TenEnv then T.TenEnv() end

local MODERN, CI_ERA, CF_CATA, CF_MISTS = COMPAT >= 11e4 or nil, COMPAT < 2e4, COMPAT > 4e4 and COMPAT < 11e4, COMPAT > 5e4 and COMPAT < 11e4
local SECRETS, NO_SECRETS = MODERN, not MODERN
local EV, WR = T.Evie, T.Ware
local AB = T.ActionBook:compatible(2, 31)
local KR = T.ActionBook:compatible("Kindred", 1,33)
local RW = T.ActionBook:compatible("Rewire", 1,40)
assert(EV and WR and AB and KR and RW and 1, "Incompatible library bundle")
local playerClassLocal, playerClass = UnitClass("player")

local stringArgCache = {} do
	local empty = {}
	setmetatable(stringArgCache, {__index=function(t,k)
		if k then
			local at
			for s in k:gmatch("[^/]+") do
				s = s:match("^%s*(%S.-)%s*$")
				if s then
					at = at or {}
					at[#at + 1] = KR:UnescapeCmdOptionsValue(s)
				end
			end
			at = at or empty
			t[k] = at
			return at
		end
		return empty
	end})
end
local function prependCountDelta(delta, ...)
	return delta + select("#", ...), ...
end

securecall(function() -- zone:Zone/Sub Zone
	local function onZoneUpdate()
		local cz
		for i=1,4 do
			local z = (i == 1 and GetRealZoneText or i == 2 and GetSubZoneText or i == 3 and GetZoneText or GetMinimapZoneText)()
			if z and z ~= "" then
				cz = (cz and (cz .. "/") or "") .. z:gsub("%s*[,/%[%]][[,/%[%]]%s]*", " ")
			end
		end
		KR:SetStateConditionalValue("zone", cz or false)
	end
	onZoneUpdate()
	EV.ZONE_CHANGED = onZoneUpdate
	EV.ZONE_CHANGED_INDOORS = onZoneUpdate
	EV.ZONE_CHANGED_NEW_AREA = onZoneUpdate
	EV.PLAYER_ENTERING_WORLD = onZoneUpdate
end)
securecall(function() -- me:Player Name/Class
	KR:SetStateConditionalValue("me", UnitName("player") .. "/" .. playerClassLocal .. "/" .. playerClass)
end)
securecall(function() -- spec:id/name
	local s, _, _, cid = nil, UnitClass("player")
	for i=1,MODERN and 5 or 0 do
		local id, name = GetSpecializationInfoForClassID(cid, i)
		if id and name then
			s = ("%s[spec:%d] %d/%d/%s"):format(s and s .. "; " or "", i, i, id, name:lower())
		end
	end
	if s then
		KR:SetStateConditionalDriver("spec", s, true)
	end
end)
securecall(function() -- form:token
	local GetSpellName = C_Spell.GetSpellName
	local map, curCnd, pending =
		playerClass == "DRUID" and {
			[GetSpellName(40120) or 1]="/flight",
			[GetSpellName(33943) or 1]="/flight",
			[GetSpellName(1066) or 1]="/aquatic",
			[GetSpellName(783) or 1]="/travel",
			[GetSpellName(24858) or 1]="/moon/moonkin",
			[GetSpellName(768) or 1]="/cat",
			[GetSpellName(171745) or 1]="/cat",
			[GetSpellName(5487) or 1]="/bear",
			[not MODERN and GetSpellName(9634) or 1]="/bear",
			[GetSpellName(114282) or 1]="/treant",
			[GetSpellName(210053) or 1]="/stag",
		} or
		playerClass == "WARRIOR" and {
			[GetSpellName(197690) or 1]="/defensive",
			[GetSpellName(386164) or 1]="/battle",
			[GetSpellName(386196) or 1]="/berserker",
			[GetSpellName(386208) or 1]="/defensive",
			[CI_ERA and GetSpellName(412513) or 1]="/gladiator",
			[GetSpellName(2457) or 1]="/battle",
			[GetSpellName(71) or 1]="/defensive",
			[GetSpellName(2458) or 1]="/berserker",
		}
	if map then
		KR:SetAliasConditional("stance", "form")
		local function syncForm()
			local GetSpellName, s = C_Spell.GetSpellName, ""
			for i=1,10 do
				local _, _, _, fsid = GetShapeshiftFormInfo(i)
				local name = fsid and GetSpellName(fsid)
				s = ("%s[form:%d] %d%s;"):format(s, i,i, map[name] or "")
			end
			if curCnd ~= s then
				KR:SetStateConditionalDriver("form", s, true)
			end
			curCnd, pending = s, nil
			return "remove"
		end
		EV.PLAYER_LOGIN = syncForm
		function EV.UPDATE_SHAPESHIFT_FORMS()
			if InCombatLockdown() then
				pending = pending or EV.RegisterEvent("PLAYER_REGEN_ENABLED", syncForm) or 1
			else
				syncForm()
			end
		end
	end
end)
securecall(function() -- instance:arena/bg/ratedbg/lfr/raid/scenario + outland/northrend/...
	local mapTypes = {
		party="dungeon", pvp="battleground/bg", ratedbg="ratedbg/rgb", none="world",
		[1116]="world/draenor", [1464]="world/draenor", [1191]="world/draenor/ashran/worldpvp",
		[974]="world/darkmoon faire",
		[870]="world/pandaria", [1064]="world/pandaria",
		[530]="world/outland", [571]="world/northrend",
		[1220]="world/broken isles", [1669]="world/argus",
		[1642]="world/bfa/zandalar", [1643]="world/bfa/kul tiras", [1718]="world/bfa/nazjatar",
		[2222]="world/shadowlands",
		[2453]="world/torghast", -- lobby
		[2162]="torghast", -- towers
		[2444]="world/dragon isles/df",
		[2516]="dungeon/nokhud",
		[2454]="world/zaralek/df",
		[2548]="world/emerald dream/df",
		[2552]="world/khaz algar/tww",
		[2601]="world/khaz algar/tww",
		[2127]="world/siren isle/tww",
		[2706]="world/undermine/tww",
		[2738]="world/karesh/tww",
		[0]=MODERN and "world/midnight", [2694]="world/midnight", [2771]="world/midnight",
		[3047]="world/midnight/val", [3075]="world/midnight/naigtal",
		[2662]="dungeon/dawnbreaker",
		[2769]="raid/undermine",
		[2827]="hvision", [2828]="hvision", [2212]="hvision", [2213]="hvision",
		hvision="scenario/hvision",
		
		garrison="world/draenor/garrison",
		[1158]="garrison", [1331]="garrison", [1159]="garrison",
		[1152]="garrison", [1330]="garrison", [1153]="garrison",
		
		[1893]="island", -- The Dread Chain
		[1814]="island", -- Havenswood (?)
		[1879]="island", -- Jorundall (?)
		[1897]="island", -- Molten Cay
		[1892]="island", -- The Rotting Mire
		[1898]="island", -- Skittering Hollow
		[1813]="island", -- Un'gol Ruins
		[1955]="island", -- Uncharted Island (tutorial)
		[1882]="island", -- Verdant Wilds
		[1883]="island", -- Whispering Reef
	}
	local mapZoneCheck, zoneChecked = {
		[2512]="world/gta", [2085e6+2512]="world/dragon isles/df/gta"
	}, true
	local function syncInstance(e)
		local _, itype, did, _, _, _, _, imid = GetInstanceInfo()
		local stype, itype0 = itype == "raid" and did == 7 and "/lfr", itype
		if mapZoneCheck[imid] then
			if e == "PLAYER_ENTERING_WORLD" and zoneChecked then
				zoneChecked, EV.ZONE_CHANGED_NEW_AREA = false, syncInstance
			end
			local bm = C_Map.GetBestMapForUnit("player")
			itype = mapZoneCheck[bm and bm*1e6 + imid or nil] or mapZoneCheck[imid] or mapTypes[imid]
		elseif mapTypes[imid] then
			itype = mapTypes[imid]
		elseif itype == "pvp" and MODERN and C_PvP.IsRatedBattleground() then
			itype = "ratedbg"
		elseif itype == "scenario" and C_DelvesUI and C_DelvesUI.HasActiveDelve(imid) then
			itype = "scenario/delve"
		end
		if itype0 == "none" and MODERN and IsInActiveWorldPVP() then
			stype = (stype or "") .. "/worldpvp"
		end
		if C_Loot.IsLegacyLootModeEnabled() then
			stype = (stype or "") .. "/legacy"
		end
		itype = mapTypes[itype] or itype or "daze"
		itype = stype and (itype .. stype) or itype
		KR:SetStateConditionalValue("in", itype)
		if e == "ZONE_CHANGED_NEW_AREA" then
			zoneChecked = true
			return "remove"
		end
	end
	EV.PLAYER_ENTERING_WORLD = syncInstance
	EV.WALK_IN_DATA_UPDATE = syncInstance
	EV.LEGACY_LOOT_RULES_CHANGED = syncInstance
	function EV:PLAYER_MAP_CHANGED(_old, _new)
		-- [11.0.2] Delve airlocks: PEW doesn't fire; GetInstanceInfo() returns stale data during PMC
		EV.After(0, syncInstance)
	end
	KR:SetAliasConditional("instance", "in")
	KR:SetStateConditionalValue("in", "daze")
end)
securecall(function() -- petcontrol
	local hasControl = (playerClass ~= "HUNTER" and playerClass ~= "WARLOCK") or UnitLevel("player") >= 10
	KR:SetStateConditionalValue("petcontrol", hasControl)
	if not hasControl then
		function EV.PLAYER_LEVEL_UP(_, level)
			if level >= 10 then
				KR:SetStateConditionalValue("petcontrol", "*")
				return "remove"
			end
		end
	end
end)
securecall(function() -- outpost
	if not MODERN then
		KR:SetStateConditionalValue("outpost", "")
		return
	end
	local map, state, name = {
		[161676]="garrison", [161332]="garrison",
		[164012]="arena", [164050]="lumber yard/yard",
		[161767]="sanctum", [162075]="arsenal",
		[168499]="brewery", [168487]="brewery", [170108]="smuggling run/run", [170097]="smuggling run/run",
		[164222]="corral", [165803]="corral", [160240]="tankworks", [160241]="tankworks",
	}, false, C_Spell.GetSpellName(161691)
	local function syncOutpost()
		local ns = map[select(7, GetSpellInfo(name))]
		if state ~= ns then
			KR:SetStateConditionalValue("outpost", ns or "")
			state = ns
		end
	end
	EV.SPELLS_CHANGED = syncOutpost
	syncOutpost()
end)
securecall(function() -- level:floor
	local function syncLevel()
		KR:SetThresholdConditionalValue("level", UnitLevel("player") or 0)
	end
	syncLevel()
	EV.PLAYER_LEVEL_UP = syncLevel
end)
securecall(function() -- horde/alliance
	local function syncFactionGroup(e, u)
		if e ~= "UNIT_FACTION" or u == "player" then
			local fg = UnitFactionGroup("player")
			KR:SetStateConditionalValue("horde", fg == "Horde" and "*" or "")
			KR:SetStateConditionalValue("alliance", fg == "Alliance" and "*" or "")
			KR:SetStateConditionalValue("merc", MODERN and UnitIsMercenary("player") and "*" or "")
		end
	end
	syncFactionGroup()
	EV.PLAYER_ENTERING_WORLD, EV.UNIT_FACTION = syncFactionGroup, syncFactionGroup
	KR:SetAliasConditional("mercenary", "merc")
end)
securecall(function() -- moving
	KR:SetNonSecureConditional("moving", function()
		return IsPlayerMoving()
	end)
end)
securecall(function() -- falling
	KR:SetNonSecureConditional("falling", function()
		return IsFalling()
	end)
end)
securecall(function() -- ready:spell name/spell id/item name/item id
	KR:SetNonSecureConditional("ready", function(_name, args)
		local gcS, gcL = GetSpellCooldown(61304)
		if not args or args == "" then
			return SECRETS and gcL and issecretvalue(gcL) and "lockdown" or (gcS == 0 and gcL == 0)
		end
		
		local at = stringArgCache[args]
		local gcE = gcS and gcL and (gcS + gcL) or math.huge
		for i=1,#at do
			local rc = at[i]
			local cdS, cdL, _cdA = GetSpellCooldown(rc)
			if cdL == nil then
				local _, iid = C_Item.GetItemInfo(rc)
				iid = tonumber((iid or rc):match("item:(%d+)"))
				if iid then
					cdS, cdL, _cdA = C_Container.GetItemCooldown(iid)
				end
			end
			if SECRETS and cdL and issecretvalue(cdL) then
				return "lockdown"
			elseif cdL == 0 or (cdS and cdL and (cdS + cdL) <= gcE) then
				return true
			end
		end
		
		return false
	end)
end)
securecall(function() -- have:item name/id
	KR:SetNonSecureConditional("have", function(_name, args)
		if not args or args == "" then
			return false
		end
		
		local at, GetItemCount = stringArgCache[args], C_Item.GetItemCount
		for i=1,#at do
			if (GetItemCount(at[i]) or 0) > 0 then
				return true
			end
		end
		
		return false
	end)
end)
securecall(function() -- self(de)buff:name, own(de)buff:name, (de)buff:name, cleanse
	local conditionalFilter = {
		selfbuff="HELPFUL", selfdebuff="HARMFUL",
		ownbuff="HELPFUL PLAYER", owndebuff="HARMFUL PLAYER",
		buff="HELPFUL", debuff="HARMFUL",
	}
	local function checkAura(name, args, target)
		if MODERN and C_Secrets.ShouldAurasBeSecret() then
			return "lockdown"
		end
		target = (name == "selfbuff" or name == "selfdebuff") and "player" or target or "target"
		if not args or args == "" or not UnitExists(target) then
			return false
		end
		local issecretvalue = SECRETS and issecretvalue
		local at, query, filter = stringArgCache[args], C_UnitAuras.GetAuraSlots, conditionalFilter[name]
		local count, ctok, a,b,c,d,e
		repeat
			count, ctok, a,b,c,d,e = prependCountDelta(-1, query(target, filter, 5, ctok))
			for i=1, count do
				local dat = C_UnitAuras.GetAuraDataBySlot(target, a)
				local name = dat and dat.name
				for j=1, name and #at or 0 do
					if (NO_SECRETS or not issecretvalue(name)) and strcmputf8i(name, at[j]) == 0 then
						return true
					end
				end
				a,b,c,d = b,c,d,e
			end
		until not ctok
		return false
	end
	KR:SetNonSecureConditional("selfbuff", checkAura)
	KR:SetNonSecureConditional("selfdebuff", checkAura)
	KR:SetNonSecureConditional("debuff", checkAura)
	KR:SetNonSecureConditional("owndebuff", checkAura)
	KR:SetNonSecureConditional("buff", checkAura)
	KR:SetNonSecureConditional("ownbuff", checkAura)
	KR:SetNonSecureConditional("cleanse", function(_, _, target)
		target = target or "target"
		return UnitIsFriend("player", target) and select(2,C_UnitAuras.GetAuraSlots(target, MODERN and "HARMFUL RAID_PLAYER_DISPELLABLE" or "HARMFUL RAID", 1)) ~= nil
	end)
end)
securecall(function() -- combo:count
	local power, powerMap = 4, {[265]=7, [267]=14, [258]=13, PALADIN=9, MONK=12}
	local defaultPower = powerMap[playerClass] or 4
	KR:SetNonSecureConditional("combo", function(_name, args)
		local pow = UnitPower("player", power)
		if SECRETS and issecretvalue(pow) then
			return "lockdown"
		end
		return pow >= (tonumber(args) or 1)
	end)
	local function syncComboPower()
		local specid = MODERN and C_SpecializationInfo.GetSpecializationInfo(C_SpecializationInfo.GetSpecialization() or 0)
		power = powerMap[specid] or defaultPower
	end
	EV.PLAYER_SPECIALIZATION_CHANGED, EV.PLAYER_ENTERING_WORLD = syncComboPower, syncComboPower
end)
securecall(function() -- near:oid/cid
	local argCache, nearValue, nearGroup, holdGroup, holdExpire = {}
	local GROUP_HOLD_TIME = {["tww-herb-overload"]=5, ["tww-mine-overload"]=5, ["mid-herb-overload"]=5, ["mid-mine-overload"]=5}
	local typePrefix, groups = {GameObject="o", Creature="c"}, {}
	for k, v in pairs({
		["herb-overload"] = "o375245/o381199/o381213/o356536/o381202/o381210/o381196/o381205/o375242/o375244/o381214/o381201/o381200/o381212/o375246/o381198/o381203/o381197/o381211/o375243/o381204/o390141/o390140/o390142/o390139/o398761/o398760/o398759/o398762/o398767/o398764/o398765/o398766/o407696/o407688/o407698/o407693",
		["mine-overload"] = "o381516/o375235/o375234/o381515/o381517/o375238/o375239/o381518/o381519/o375240/o390137/o390138/o407669/o407668",
		["tww-herb-overload"] = "o414327/o414329/o414326/o414328/o414325/o414337/o414339/o454053/o454008/o414338/o454084/o414336/o414335/o454066/o454079/o454069/o454074/o423363/o454082/o454067/o423368/o454077/o423364/o423366/o423367/o454072/o454064/o454006/o454050/o414332/o414331/o414330",
		["tww-mine-overload"] = "o413886/o413895/o413905/o430351/o430335/o430352/o413900/o413883/o413890/o413902/o413892/o413884",
		["mid-herb-overload"] = "o516967/o516966/o516965/o516964/o516963//o516979/o516980/o516981/o516982/o516983//o516973/o516974/o516975/o516976/o516977//o516968/o516969/o516970/o516971/o516972",
		["mid-mine-overload"] = "o523284/o523294/o523303//o523287/o523293/o523301//o523285/o523291/o523299//o523286/o523292/o523300",
	}) do
		for e in v:gmatch("[^/]+") do
			groups[e] = k
		end
	end
	local function checkNearHoldExpire()
		if holdGroup and holdExpire < GetTime() then
			holdGroup, holdExpire = nil
			KR:PokeConditional("near")
		end
	end
	KR:SetNonSecureConditional("near", function(_name, args)
		checkNearHoldExpire()
		if args == nil then
			return nearValue ~= nil
		end
		local ca = argCache[args]
		if ca == nil then
			ca = {}
			for v in args:gmatch("[^%s/][^/]*") do
				ca[v:match("^(.-)%s*$")] = 1
			end
			argCache[args] = ca
		end
		return (ca[nearValue] or ca[nearGroup] or ca[holdGroup]) ~= nil
	end)
	function EV:PLAYER_SOFT_INTERACT_CHANGED(_, guid)
		local ct, oid
		if guid and not InCombatLockdown() and (NO_SECRETS or not issecretvalue(guid)) then
			ct, oid = guid:match("^(%a+)%-[-%d]+%-(%d+)%-[^-]+$")
			ct = typePrefix[ct]
			oid = ct and ct .. oid or nil
		end
		if oid ~= nearValue then
			local ht = not oid and GROUP_HOLD_TIME[nearGroup]
			if ht then
				holdGroup, holdExpire = nearGroup, GetTime() + ht
				EV.After(ht+1/128, checkNearHoldExpire)
			elseif oid then
				holdGroup, holdExpire = nil
			end
			nearValue, nearGroup = oid, groups[oid]
			KR:PokeConditional("near")
		end
	end
end)
securecall(function() -- race:token
	local map, _, raceToken = {
		Scourge="Scourge/Undead/Forsaken",
		LightforgedDraenei="LightforgedDraenei/Lightforged",
		HighmountainTauren="HighmountainTauren/Highmountain",
		MagharOrc="MagharOrc/Maghar",
		ZandalariTroll="ZandalariTroll/Zandalari",
		DarkIronDwarf="DarkIronDwarf/DarkIron",
		EarthenDwarf="EarthenDwarf/Earthen",
		Harronir="Harronir/Haranir",
	}, UnitRace("player")
	KR:SetStateConditionalValue("race", map[raceToken] or raceToken)
end)
securecall(function() -- professions
	KR:SetStateConditionalValue("prof", false)
	local MODERN_PROFS = MODERN or CF_MISTS
	local ct, ot, curProfState, syncProfInner = {}, {}, false
	local map = MODERN_PROFS and {
		[197]="tail", [165]="lw", [164]="bs",
		[171]="alch", [202]="engi", [333]="ench", [755]="jc", [773]="scri",
		[182]="herb", [186]="mine", [393]="skin",
		[794]="arch", [185]="cook", [356]="fish",
		[129]="faid",
		[20219]="nomeng", [20222]="gobeng",
	}
	local GetSpellName = C_Spell.GetSpellName
	map = map or {
		[GetSpellName(3908) or ""]="tail",
		[GetSpellName(2108) or ""]="lw",
		[GetSpellName(2018) or ""]="bs",
		[GetSpellName(2259) or ""]="alch",
		[GetSpellName(4036) or ""]="engi",
		[GetSpellName(7411) or ""]="ench",
		[GetSpellName(2366) or ""]="herb", -- Herb Gathering (skill line is Herbalism, oops)
		[GetSpellName(2383) or ""]="herb", -- Find Herbs, in spellbook
		[GetSpellName(2575) or ""]="mine",
		[GetSpellName(2580) or ""]="mine", -- Find Minerals, in spellbook
		[GetSpellName(8613) or ""]="skin",
		[GetSpellName(2550) or ""]="cook",
		[GetSpellName(3273) or ""]="faid",
		[GetSpellName(7620) or ""]="fish",
		[GetSpellName(20221) or ""]="gobeng",
		[GetSpellName(20222) or ""]="gobeng",
		[GetSpellName(20220) or ""]="nomeng",
		[GetSpellName(20219) or ""]="nomeng",
	}
	local spellIDProfs = {
		[264636]="cook3",
		[264620]="tail3", [264626]="tail6",
		[271662]="fish5",
		[264588]="lw6", [264590]="lw7",
		[264479]="eng2", [264481]="eng3", [264483]="eng4", [264485]="eng5", [264488]="eng6", [264490]="eng7", [310542]="eng9",
		-- eng8 is in sync code, because factions
	}
	map[""]=nil
	syncProfInner = MODERN_PROFS and function(n, id, ...)
		if id then
			local _1, _2, cur, _cap, ns, sofs, skid, _bonus, specIdx, _ = GetProfessionInfo(id)
			local et, sid = GetSpellBookItemInfo(ns == 2 and sofs and specIdx > -1 and sofs+2 or 0, "spell")
			local e1, e2 = map[skid], map[et == "SPELL" and sid or nil]
			if e1 then ct[e1] = cur end
			if e2 then ct[e2] = cur end
		end
		if n > 1 then
			return syncProfInner(n-1, ...)
		end
	end or function()
		local idx, nLines0 = 1, GetNumSkillLines()
		while idx < nLines0 do
			local hidx, curSkill, skey = idx
			local text, isHeader, isExpanded = GetSkillLineInfo(idx)
			if text and isHeader then
				ExpandSkillHeader(idx)
				repeat
					idx, text, isHeader, _, curSkill = idx + 1, GetSkillLineInfo(idx+1)
					skey = map[text]
					if skey and not isHeader then
						ct[skey] = curSkill
					end
				until isHeader or not text
				idx = idx - 1
				if not isExpanded or isExpanded == 0 then
					CollapseSkillHeader(hidx)
					idx = hidx
				end
			end
			idx = idx + 1
		end
		local GetSpellName = C_Spell.GetSpellName
		for k,v in pairs(map) do
			if ct[v] == nil and GetSpellName(k) then
				ct[v] = 1
			end
		end
	end
	local function syncProf()
		ct, ot = ot, ct
		for k in pairs(ct) do ct[k] = nil end
		if MODERN_PROFS then
			syncProfInner(prependCountDelta(0, GetProfessions()))
		else
			syncProfInner()
		end
		for sid, cnd in pairs(spellIDProfs) do
			ct[cnd] = GetSpellInfo(GetSpellInfo(sid) or "\1") and 1 or nil
		end
		ct["eng8"] = GetSpellInfo(GetSpellInfo(UnitFactionGroup("player") == "Horde" and 265807 or 264492) or "\1") and 1 or nil
		local s = false
		for k,v in pairs(ct) do
			if ot[k] ~= v then
				KR:SetThresholdConditionalValue(k, v)
				ot[k] = v
			end
			s = s and (s .. "/" .. k) or k
		end
		if curProfState ~= s then
			curProfState = s
			KR:SetStateConditionalValue("prof", s)
		end
		for k,v in pairs(ot) do
			if ct[k] ~= v then
				KR:SetThresholdConditionalValue(k, false)
				ot[k] = nil
			end
		end
	end
	for _, v in pairs(map) do
		KR:SetThresholdConditionalValue(v, false)
	end
	for _, v in pairs(spellIDProfs) do
		KR:SetThresholdConditionalValue(v, false)
	end
	for alias, real in ("tailoring:tail leatherworking:lw alchemy:alch engineering:engi enchanting:ench jewelcrafting:jc blacksmithing:bs inscription:scri herbalism:herb archaeology:arch cooking:cook fishing:fish firstaid:faid mining:mine skinning:skin"):gmatch("(%a+):(%a+)") do
		KR:SetAliasConditional(alias, real)
	end
	EV.PLAYER_LOGIN, EV.CHAT_MSG_SKILL = syncProf, syncProf
end)
securecall(function() -- pet:stable id; havepet:stable id
	if playerClass ~= "HUNTER" then
		KR:SetStateConditionalValue("havepet", false)
		return
	end
	local pt, noPendingSync = {}, true
	local specTokenSuf = {} if MODERN or CF_MISTS then
		local function addPetSpec(specID, tk)
			specTokenSuf[specID] = tk
			for i=1, CF_MISTS and 2 or 0 do
				local _, n = GetSpecializationInfoForSpecID(specID, i)
				specTokenSuf[n or 0] = tk
			end
		end
		addPetSpec(74, "/ferocity")
		addPetSpec(79, "/cunning")
		addPetSpec(81, "/tenacity")
		specTokenSuf[0] = nil
	end
	local function syncPet(e)
		if InCombatLockdown() then
			if noPendingSync then
				EV.PLAYER_REGEN_ENABLED, noPendingSync = syncPet, false
			end
			return
		end
		for k in pairs(pt) do pt[k] = nil end
		local o, hpo
		for i=1,5 do
			local _, n, _, r, spN, spID = GetStablePetInfo(i)
			if n and r then
				local stk = specTokenSuf[spID or spN]
				local k = n == r and n or (n .. "/" .. r)
				pt[k] = (pt[k] or ("[pet:" .. n .. (n ~= r and ",pet:" .. r .. "] " or "] ") .. k)) .. "/" .. i .. (stk or "")
				hpo = (hpo and hpo .. "/" .. i or i)
			end
		end
		for k, v in pairs(pt) do
			o = k:match("/") and (v .. (o and "; " .. o or "")) or ((o and o .. "; " or "") .. v)
		end
		KR:SetStateConditionalDriver("pet","[nopet]; " .. (o and o .. "; 0" or " 0"), true)
		KR:SetStateConditionalValue("havepet", tostring(hpo or ""))
		noPendingSync = true
		return (e == "PLAYER_LOGIN" or e == "PLAYER_REGEN_ENABLED") and "remove"
	end
	KR:SetStateConditionalValue("havepet", false)
	EV.PLAYER_LOGIN, EV.PET_STABLE_UPDATE, EV.PET_INFO_UPDATE, EV.LOCALPLAYER_PET_RENAMED = syncPet, syncPet, syncPet, syncPet
end)
securecall(function() -- game:modern/remix/era/sod/classic + era/hc
	KR:SetStateConditionalValue("game", "daze")
	function EV.PLAYER_LOGIN()
		local s
		if CI_ERA then
			local season, st = C_Seasons.GetActiveSeason(), Enum.SeasonID
			s = not season and "era" or
			    season == st.SeasonOfDiscovery and "sod" or
			    (season == st.Fresh or season == st.FreshHardcore) and "fresh" or
			    "era"
			if C_GameRules.IsHardcoreActive() then
				s = s and s .. "/hc" or "hc"
			end
		elseif MODERN then
			s = PlayerGetTimerunningSeasonID() and "remix" or "modern"
		else
			s = "classic"
		end
		KR:SetStateConditionalValue("game", s)
		return "remove"
	end
end)
securecall(function() -- visual
	local f = CreateFrame("Frame", nil, nil, "SecureFrameTemplate")
	f:SetAttribute("EvaluateMacroConditional", 'return false')
	KR:SetSecureExternalConditional("visual", f, function() return true end)
end)
securecall(function() -- coven:kyrian/venthyr/fae/necro
	KR:SetStateConditionalValue("coven", false)
	KR:SetStateConditionalValue("acoven80", false)
	KR:SetAliasConditional("covenant", "coven")
	KR:SetAliasConditional("acovenant80", "acoven80")
	if not MODERN then
		return
	end
	local cv, covMap = false, {"kyrian", "venthyr", "fae/nightfae", "necro/necrolord"}
	local c8, p8 = false, {1, 4, 3, 2}
	local noPendingSync, noPendingTimer, syncCovenTimer = true, true
	local function syncCoven(e)
		if InCombatLockdown() then
			if noPendingSync then
				EV.PLAYER_REGEN_ENABLED = syncCoven
			end
			return
		end
		noPendingSync = true
		local nv = covMap[C_Covenants.GetActiveCovenantID()] or false
		if nv ~= cv then
			cv = nv
			KR:SetStateConditionalValue("coven", nv)
		end
		if GetAchievementNumCriteria(15646) == 4 then
			local n8 = false
			for i=1,4 do
				if select(3, GetAchievementCriteriaInfo(15646, i)) then
					n8 = n8 and (n8 .. "/" .. covMap[p8[i]]) or covMap[p8[i]]
				end
			end
			if n8 ~= c8 then
				c8 = n8
				KR:SetStateConditionalValue("acoven80", n8)
			end
		elseif noPendingTimer then
			noPendingTimer = false
			EV.After(0.25, syncCovenTimer)
		end
		return e == "PLAYER_REGEN_ENABLED" and "remove"
	end
	function syncCovenTimer()
		noPendingTimer = true
		syncCoven()
	end
	EV.COVENANT_CHOSEN, EV.COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED, EV.PLAYER_ENTERING_WORLD = syncCoven, syncCoven, syncCoven
end)
securecall(function() -- worldhover
	KR:SetStateConditionalValue("worldhover", false)
	local wf = CreateFrame("Frame", nil, nil, "SecureFrameTemplate")
	wf:SetFrameStrata("BACKGROUND")
	wf:SetFrameLevel(0)
	local function wfOnMotion()
		if not InCombatLockdown() then
			local nv = wf:IsMouseMotionFocus()
			if nv == (KR:EvaluateCmdOptions("[worldhover]") == nil) then
				KR:SetStateConditionalValue("worldhover", nv)
			end
		end
	end
	wf:SetScript("OnEnter", wfOnMotion)
	wf:SetScript("OnLeave", wfOnMotion)
	function EV.PLAYER_REGEN_ENABLED()
		wfOnMotion(wf)
	end
	SecureHandlerSetFrameRef(wf, "KR", KR:seclib())
	SecureStateDriverManager:SetAttribute("setframe", wf)
	SecureStateDriverManager:SetAttribute("setstate", "_wrapentered 1")
	SecureHandlerExecute(wf, [[KR = self:GetFrameRef("KR"); self:SetAttribute("frameref-KR", nil)]])
	SecureHandlerWrapScript(wf, "OnEnter", wf, 'KR:RunAttribute("UpdateStateConditional", "worldhover", "*", nil)')
	SecureHandlerWrapScript(wf, "OnLeave", wf, 'KR:RunAttribute("UpdateStateConditional", "worldhover", nil, "*")')
	wf:EnableMouse(false)
	wf:EnableMouseMotion(true)
	wf:SetPropagateMouseMotion(true)
	wf:SetAllPoints(WorldFrame)
end)
securecall(function() -- imbuedmh, imbuedoh, imbuedrw
	KR:SetStateConditionalValue("imbuedmh", false)
	KR:SetStateConditionalValue("imbuedoh", false)
	KR:SetStateConditionalValue("imbuedrw", false)
	local weaponInfoOffset = {
		imbuedmh = MODERN and 1,
		imbuedoh = MODERN and 5,
		imbuedrw = not MODERN and 9 or nil, -- BUG[Classic/2408]: SAHT ignores ranged weapon; Modern has no ranged slot
	}
	local function checkWeaponImbued(name, _args)
		local isImbued, _expire, _charges, _enchantID = select(weaponInfoOffset[name], GetWeaponEnchantInfo())
		return not not isImbued
	end
	for k in pairs(weaponInfoOffset) do
		KR:SetNonSecureConditional(k, checkWeaponImbued)
	end
	if MODERN then
		return
	end
	local h = CreateFrame("Frame", nil, nil, "SecureAuraHeaderTemplate")
	SecureHandlerSetFrameRef(h, "KR", KR:seclib())
	SecureHandlerExecute(h, [[KR = self:GetFrameRef("KR")]])
	local t1 = CreateFrame("Frame", nil, h, "SecureFrameTemplate")
	local t2 = CreateFrame("Frame", nil, h, "SecureFrameTemplate")
	local t3 = nil -- BUG[Classic/2408]: SAHT ignores ranged weapon
	h:SetAttribute("unit", "none")
	h:SetAttribute("includeWeapons", -1)
	h:SetAttribute("filter", "NONE")
	for i=1, t3 and 3 or 2 do
		local sf = i == 1 and t1 or i == 2 and t2 or t3
		h:SetAttribute("tempEnchant" .. i, sf)
		sf:SetAttribute('cname', i == 1 and 'imbuedmh' or i == 2 and 'imbuedoh' or 'imbuedrw')
		SecureHandlerWrapScript(sf, 'OnShow', h, [[KR:RunAttribute("UpdateStateConditional", self:GetAttribute("cname"), "*", nil)]])
		SecureHandlerWrapScript(sf, 'OnHide', h, [[KR:RunAttribute("UpdateStateConditional", self:GetAttribute("cname"), nil, "*")]])
		sf:Hide()
	end
	h:Show()
end)
securecall(function() -- bar:id (future-aware)
	local CMD_SWAP, CMD_SET, NUM_PAGES = SLASH_SWAPACTIONBAR1, SLASH_CHANGEACTIONBAR1, NUM_ACTIONBAR_PAGES
	local argCache = {}
	local f = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
	local re = WR.GetRestrictedEnvironment(f)
	f:SetAttribute("type", "actionbar")
	f:SetAttribute("useOnKeyDown", false)
	re.argCache = WR.newtable
	re.CMD_SWAP, re.NUM_PAGES = CMD_SWAP, NUM_PAGES
	re.RW, re.KR = RW:seclib(), KR:seclib()
	f:SetAttribute("RunSlashCmd", [=[-- AB_bar_runslash 
		local setTo, cmd, v = nil, ...
		if cmd == CMD_SWAP then
			local a, b = v:match("(%d+)%s+(%d+)")
			a, b = tonumber(a), tonumber(b)
			if a and b and a >= 1 and b >= 1 and a <= NUM_PAGES and b <= NUM_PAGES then
				setTo = KR:RunAttribute("EvaluateCmdOptions", "[bar:" .. a .. "]") and b or a
			end
		else
			local a = tonumber(v)
			if a and a >= 1 and a <= NUM_PAGES then
				setTo = a
			end
		end
		if setTo then
			pendingValue, pendingRunID = setTo, RW:GetAttribute("PyrolysisRunID")
			return cmd .. " " .. v, "notified-click", setTo
		end
	]=])
	f:SetAttribute("RunSlashCmd-PreClick", [[-- AB_bar_runslash_pre 
		local cmd, v = ...
		pendingValue, pendingRunID = nil
		self:SetAttribute("action", v)
	]])
	f:SetAttribute("EvaluateMacroConditional", [=[-- AB_bar_evalmc 
		local name, cv, target, _mark, futureID = ...
		if name ~= "bar" or not cv or cv == "" then return end
		if futureID == "driver-construct" then
			return nil, "use-scop"
		elseif not pendingRunID or RW:GetAttribute("PyrolysisRunID") ~= pendingRunID then
			pendingValue, pendingRunID = nil
			return nil, "use-scop"
		end
		local am = argCache[cv]
		if am == nil then
			am = newtable()
			for d in cv:gmatch("%s*(%d*)[^/]*/*") do
				am[d ~= "" and d+0 or 0] = true
			end
			argCache[cv], am[0] = am, nil
		end
		return am[pendingValue] ~= nil
	]=])

	local currentFutureID, currentBarState
	local function hintBarCommand(slash, _unparsed, clause, _target, _, _, _, speculationID)
		if (clause or "") == "" then return end
		if slash == CMD_SWAP then
			local a, b = clause:match("(%d+)%s+(%d+)")
			a, b = tonumber(a), tonumber(b)
			if a and b and a >= 1 and b >= 1 and a <= NUM_PAGES and b <= NUM_PAGES then
				if currentFutureID ~= speculationID then
					currentFutureID, currentBarState = speculationID, GetActionBarPage()
				end
				currentBarState = currentBarState == a and b or a
			end
		else
			local a = tonumber(clause)
			if a and a >= 1 and a <= NUM_PAGES then
				currentFutureID, currentBarState = speculationID, a
			end
		end
	end
	local function hintBarCondition(_name, cv, _target, _, futureID)
		if not cv or cv == "" then
			return false
		end
		local am = argCache[cv]
		if am == nil then
			am = {}
			for d in cv:gmatch("%s*(%d*)[^/]*/*") do
				am[d ~= "" and d+0 or 0] = true
			end
			am[0] = nil
			argCache[cv] = next(am) and am or false
		end
		return am and am[futureID == currentFutureID and currentBarState or GetActionBarPage()] or false
	end
	if RW:IsPyrolysisActive() then
		RW:RegisterCommandEx(CMD_SET, RW:GetCommandFlags(CMD_SET), f)
		RW:RegisterCommandEx(CMD_SWAP, RW:GetCommandFlags(CMD_SWAP), f)
	end
	RW:SetCommandHint(CMD_SET, math.huge, hintBarCommand)
	RW:SetCommandHint(CMD_SWAP, math.huge, hintBarCommand)
	KR:SetSecureExternalConditional("bar", f, hintBarCondition)
end)
securecall(function() -- anyflyable
	KR:SetStateConditionalValue("blockedflyable", false)
	KR:SetStateConditionalValue("superflyable", false)
	KR:SetStateConditionalDriver("anyflyable", ("[superflyable] *; [blockedflyable]; [flyable] %s;"):format(MODERN and "[advflyable] *" or "*"), false)
end)
securecall(function() -- holiday:veil/brew/hend/fire/east/luna
	KR:SetStateConditionalValue("holiday", false)
	if not (MODERN or CF_CATA) then
		return
	end
	local events = {
		[235485]="veil", [235484]="veil", [235482]="veil", veil="winterveil",
		[235441]="brew", [235440]="brew", [235442]="brew", brew="brewfest",
		[235462]="hend", [235461]="hend", [235460]="hend", hend="hallowsend",
		[235474]="fire", [235473]="fire", [235472]="fire", fire="midsummer",
		[235477]="east", [235476]="east", [235475]="east", east="noblegarden",
		[235471]="luna", [235470]="luna", [235469]="luna", luna="lunarfestival",
		[235466]="love", [235467]="love", [235468]="love", love="loveair",
	}
	local function nextHolidayInfo(md, idx)
		local d, x = (md % 100), (idx or 0)+1
		local info = C_Calendar.GetHolidayInfo((md-d)/100, d, x)
		return info and x or nil, info
	end
	local function toEpoch(ct)
		ct.day, ct.min, ct.sec = ct.monthDay, ct.minute or 0, 0
		return time(ct)
	end
	local function syncHoliday()
		local m0, cnow, tnow = C_Calendar.GetMonthInfo(0), C_DateAndTime.GetCurrentCalendarTime(), GetTime()
		local ofs = (cnow.year-m0.year)*12 + cnow.month - m0.month
		local mnow, d = ofs == 0 and m0 or C_Calendar.GetMonthInfo(ofs), cnow.monthDay
		C_Calendar.SetMonth(ofs)
		local cv, nextTime = false
		for i=1,2 do
			for _, info in nextHolidayInfo, i == 1 and d or d < mnow.numDays and d + 1 or 101 do
				local ek, st, et = events[info and info.texture], info and info.startTime, info and info.endTime
				ek = events[ek] or ek
				if ek and st and C_DateAndTime.CompareCalendarTime(cnow, st) >= 0 then
					local nt = GetTime() + toEpoch(st) - toEpoch(cnow) + 60
					nextTime = cv and nt > nextTime and nextTime or nt
				elseif ek and et and C_DateAndTime.CompareCalendarTime(cnow, et) > 0 then
					local nt = GetTime() + toEpoch(et) - toEpoch(cnow)
					nextTime = cv and nt > nextTime and nextTime or nt
					cv = cv and cv .. "/" .. ek or ek -- KR will filter out the duplicates
				end
			end
		end
		C_Calendar.SetMonth(-ofs)
		KR:SetStateConditionalValue("holiday", cv)
		if nextTime and (nextTime - tnow) < 1e5 then
			nextTime = tnow+15 < nextTime and tnow + 15 or nextTime
			local function holidayTick()
				local d = nextTime - GetTime()
				if d <= 0 then
					syncHoliday()
				else
					EV.After(d > 120 and 120 or d, holidayTick)
				end
			end
			holidayTick()
		end
		return "remove"
	end
	EV.PLAYER_LOGIN = syncHoliday
end)
securecall(function() -- uslot:(slot token)
	KR:SetStateConditionalValue("uslot", false)
	local state, noPendingSync, slots = "", 1, {}
	for tk, sk in pairs({
		head="HEADSLOT", neck="NECKSLOT", shoulders="SHOULDERSLOT", shirt="SHIRTSLOT", chest="CHESTSLOT",
		waist="WAISTSLOT", legs="LEGSSLOT", feet="FEETSLOT", wrist="WRISTSLOT", hands="HANDSSLOT",
		finger1="FINGER0SLOT", finger2="FINGER1SLOT", trinket1="TRINKET0SLOT", trinket2="TRINKET1SLOT",
		back="BACKSLOT", tabard="TABARDSLOT",
	}) do
		local ok, slot = pcall(GetInventorySlotInfo, sk)
		slots[tk] = ok and slot or nil
	end
	local function syncActiveSlots()
		if InCombatLockdown() then
			return
		end
		local GetItemSpell, o = C_Item.GetItemSpell
		for token, i in next, slots do
			local link, _, sid = token and (GetInventoryItemLink("player", i) or GetInventoryItemID("player", i))
			if link then
				_, sid = GetItemSpell(link)
			end
			if sid and not IsPassiveSpell(sid) then
				o = o and (o .. "/" .. token) or token
			end
		end
		o, noPendingSync = o or "", 1
		if state ~= o then
			state = o
			KR:SetStateConditionalValue("uslot", o)
		end
	end
	local function syncActiveSlotsIfPending()
		if not noPendingSync then
			syncActiveSlots()
		end
	end
	local function cueActiveSlotsSync(e)
		if noPendingSync and not InCombatLockdown() then
			EV.After(0, syncActiveSlots)
		end
		noPendingSync = nil
		return e ~= "PLAYER_EQUIPMENT_CHANGED" and "remove"
	end
	EV.PLAYER_REGEN_DISABLED = syncActiveSlotsIfPending
	EV.PLAYER_REGEN_ENABLED = syncActiveSlotsIfPending
	EV.PLAYER_EQUIPMENT_CHANGED = cueActiveSlotsSync
	EV.PLAYER_ENTERING_WORLD = cueActiveSlotsSync
	EV.PLAYER_EQUIPED_SPELLS_CHANGED = cueActiveSlotsSync
end)
securecall(function() -- encount:(e-{id}/token)
	KR:SetStateConditionalValue("encount", false)
	KR:SetAliasConditional("encounter", "encount")
	local CV_ENCOUNT_STATE, state, enTokens = "actionbook-encount-state", nil, {
		[3135]="dimensius/ff-mount",
		[2837]="shadowcrown/ff-mount",
		[2839]="rashanan/ff-mount",
	}
	local function setEncounterState(newstate)
		state = newstate
		KR:SetStateConditionalValue("encount", state)
		C_CVar.SetCVar(CV_ENCOUNT_STATE, state or "")
	end
	function EV:ENCOUNTER_START(eid)
		if eid and not InCombatLockdown() then
			setEncounterState(enTokens[eid] and enTokens[eid] .. "/e-" .. eid or ("e-" .. eid))
		end
	end
	function EV:PLAYER_REGEN_ENABLED()
		if state then
			setEncounterState(false)
		end
	end
	function EV:PLAYER_ENTERING_WORLD(_, isReload)
		local s2 = isReload and C_CVar.GetCVar(CV_ENCOUNT_STATE) or ""
		if not InCombatLockdown() and s2 ~= "" and not state then
			setEncounterState(s2)
		else
			C_CVar.RegisterCVar(CV_ENCOUNT_STATE, "")
		end
		return "remove"
	end
end)
securecall(function() -- myth:token
	KR:SetStateConditionalValue("myth", false)
	if not MODERN then
		return
	end
	local mapTokens = {
		-- Raids:
		[2769]="liberation/lou",
		[2810]="manaforge/mfo",
		-- Midnight S1:
		[2526]="academy/aca",
		[2811]="magterr/mgt",
		[2874]="maisara/mac",
		[658]="saronpit/pos",
		[1209]="skyreach/sky",
		[1753]="sottrium/tri",
		[2805]="windspire/wnd",
		[2915]="xenas/npx",
		-- Midnight S2:
		[2993]="altar/aof",
		[2813]="murder/row",
		[2825]="nalorakk/den",
		[2859]="blindvale/blv",
		[2923]="voidscar/vsa",
		[1762]="krest/rst",
		[1877]="sethraliss/sss",
		[2521]="rubypools/rlp",
	}
	local KEYSTONE_LINK_FRAGMENT = "|Hitem:180653:"
	local KEYSTONE_ICON_ID = C_Item.GetItemIconByID(KEYSTONE_LINK_FRAGMENT)
	local CV_MYTH_STATE = "actionbook-myth-state"
	local groupActivityID, groupActivityMapID, state
	local function syncMythState()
		local ns = mapTokens[groupActivityMapID]
		        or mapTokens[not IsInRaid() and C_MythicPlus.GetOwnedKeystoneMapID()]
		        or (IsInGroup() and state) or false
		if state ~= ns then
			state = ns
			KR:SetStateConditionalValue("myth", state)
		end
	end
	local function updateActivity(aid)
		if aid == nil then
			local ad = C_LFGList.GetActiveEntryInfo()
			aid = ad and ad.activityIDs and ad.activityIDs[1]
		end
		if aid and aid ~= groupActivityID then
			local ai = aid and C_LFGList.GetActivityInfoTable(aid)
			groupActivityID, groupActivityMapID = aid, ai and ai.mapID
			C_CVar.SetCVar(CV_MYTH_STATE, groupActivityMapID and aid .. ":" .. groupActivityMapID or "")
		end
		syncMythState()
	end
	local function clearGroupMyth()
		groupActivityID, groupActivityMapID = nil
		C_CVar.SetCVar(CV_MYTH_STATE, "")
		syncMythState()
	end
	function EV:LFG_LIST_ACTIVE_ENTRY_UPDATE()
		return nil, updateActivity()
	end
	function EV:LFG_LIST_JOINED_GROUP(srID)
		local ad = C_LFGList.GetSearchResultInfo(srID)
		local aid = ad and ad.activityIDs and ad.activityIDs[1]
		return nil, aid and updateActivity(aid)
	end
	EV.GROUP_LEFT = clearGroupMyth
	function EV:PLAYER_ENTERING_WORLD(_, isReload)
		local savedState, sa, sm = isReload and C_CVar.GetCVar(CV_MYTH_STATE) or ""
		if savedState ~= "" then
			sa, sm = savedState:match("^(%d+):(%d+)$")
		end
		if sa then
			groupActivityID, groupActivityMapID = sa+0, sm+0
			syncMythState()
		else
			C_CVar.RegisterCVar(CV_MYTH_STATE, "")
			C_CVar.SetCVar(CV_MYTH_STATE, "")
			updateActivity()
		end
		return "remove"
	end
	local keyUpdateTimerState = 0
	local function onKeyUpdateTimerTick()
		if keyUpdateTimerState == 1 then
			keyUpdateTimerState = 0
		else
			keyUpdateTimerState = 1
			EV.After(1, onKeyUpdateTimerTick)
		end
		syncMythState()
	end
	local function cueKeyUpdateTimer()
		keyUpdateTimerState = keyUpdateTimerState + 1
		if keyUpdateTimerState == 1 then
			EV.After(1, onKeyUpdateTimerTick)
		end
	end
	function EV:ITEM_CHANGED(oldlink, _newlink)
		if oldlink and string.match(oldlink, KEYSTONE_LINK_FRAGMENT) then
			cueKeyUpdateTimer()
		end
	end
	function EV:CHALLENGE_MODE_COMPLETED()
		cueKeyUpdateTimer()
		clearGroupMyth()
	end
	function EV:ITEM_PUSH(_, icon)
		if icon == KEYSTONE_ICON_ID then
			cueKeyUpdateTimer()
		end
	end
	function EV:PLAYER_LOGIN()
		if PlayerGetTimerunningSeasonID() == 2 then
			KEYSTONE_LINK_FRAGMENT = "|Hitem:187786:"
			KEYSTONE_ICON_ID = C_Item.GetItemIconByID(KEYSTONE_LINK_FRAGMENT)
		end
		return "remove"
	end
end)
securecall(function() -- prey:qid
	KR:SetStateConditionalValue("prey", false)
	if not MODERN then
		return
	end
	local PREY_WIDGET_ID = 7663
	local currentState, goalState, pendingCheck, checkWidget = false, false
	local function syncPrey()
		if pendingCheck then
			return checkWidget()
		elseif goalState ~= currentState then
			KR:SetStateConditionalValue("prey", goalState)
			currentState = goalState
		end
	end
	function checkWidget()
		if InCombatLockdown() then
			pendingCheck = 1
			return
		end
		local qid = C_QuestLog.GetActivePreyQuest()
		local qidActive = qid and not C_QuestLog.IsComplete(qid) and qid
		local viz = qidActive and C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo(PREY_WIDGET_ID)
		goalState, pendingCheck = viz and viz.shownState == 1 and tostring(qid) or false, nil
		return syncPrey()
	end
	function EV:UPDATE_UI_WIDGET(winfo)
		if winfo and winfo.widgetID == PREY_WIDGET_ID then
			return checkWidget()
		end
	end
	EV.UPDATE_ALL_UI_WIDGETS = checkWidget
	EV.PLAYER_REGEN_ENABLED = syncPrey
	EV.PLAYER_LOGIN = checkWidget
end)
securecall(function() -- Housing Return
	KR:SetStateConditionalValue("housereturn", false)
	if not MODERN then
		return
	end
	local function syncReturn()
		local v = not not C_HousingNeighborhood.CanReturnAfterVisitingHouse()
		KR:SetStateConditionalValue("housereturn", v)
	end
	EV.PLAYER_ENTERING_WORLD = syncReturn
	EV.UPDATE_UI_WIDGET = syncReturn
end)
securecall(function() -- Warbank
	KR:SetStateConditionalValue("warbank", false)
	if MODERN then
		function EV.PLAYER_ENTERING_WORLD()
			local isAvailable = C_Bank.FetchBankLockedReason(2) == nil
			KR:SetStateConditionalValue("warbank", isAvailable)
		end
	end
end)

securecall(function() -- Managed role units
	local mh = CreateFrame("Frame", nil, nil, "SecureFrameTemplate")
	SecureHandlerSetFrameRef(mh, "KR", KR:seclib())
	SecureHandlerExecute(mh, [=[-- MRU_Init_Manager 
		KR, uf, ul, spare = self:GetFrameRef("KR"), newtable(), newtable(), newtable()
		self:SetAttribute("frameref-KR", nil)
	]=])
	local syncUnits = [==[-- MRU_Sync 
		local nl, key, nj, fa = spare, %q, 1
		ul[key], spare, fa = nl, ul[key], uf[key]
		for i=1,40 do
			local u = fa[i]:GetAttribute("unit")
			if u then
				nl[i] = u
			else
				for j=i,#nl do
					nl[j] = nil
				end
				break
			end
		end
		for i=1,#nl do
			local u = nl[i]
			if u ~= playerUnit then
				KR:RunAttribute("SetAliasUnit", key .. nj, u)
				nj = nj + 1
			end
		end
		for i=nj,#spare do
			KR:RunAttribute("SetAliasUnit", key .. i, "raid42")
		end
		self:Show()
	]==]
	local function SpawnHeader(key, ...)
		local h = CreateFrame("Frame", nil, nil, "SecureGroupHeaderTemplate")
		for i=1,40 do
			local c = CreateFrame("Frame", nil, h, "SecureFrameTemplate")
			h:SetAttribute("child" .. i, c)
			SecureHandlerSetFrameRef(mh, "u" .. i, c)
			KR:SetAliasUnit(key .. i, "raid42")
		end
		SecureHandlerExecute(mh, ([[-- MRU_SpawnHeader_Init 
			local a, k = newtable(), %q
			for i=1,40 do
				a[i] = self:GetFrameRef("u" .. i)
				self:SetAttribute("frameref-u" .. i, nil)
			end
			uf[k], ul[k] = a, newtable()
		]]):format(key))
		local cu = CreateFrame("Frame", nil, h, "SecureFrameTemplate")
		SecureHandlerWrapScript(cu, "OnHide", mh, syncUnits:format(key))
		h:SetAttribute("child41", cu)
		h:SetAttribute("template", "ImpossibleFrameTemplate")
		h:SetAttribute("templateType", "Frame")
		h:SetAttribute("showRaid", true)
		h:SetAttribute("showParty", true)
		h:SetAttribute("showPlayer", false)
		h:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
		h:SetAttribute("sortMethod", "NAME")
		for i=1, select("#", ...), 2 do
			local k, v = select(i, ...)
			h:SetAttribute(k, v)
		end
		return h
	end
	local ph = CreateFrame("Frame", nil, nil, "SecureGroupHeaderTemplate") do
		local c = CreateFrame("Frame", nil, ph, "SecureFrameTemplate")
		ph:SetAttribute("child1", c)
		SecureHandlerWrapScript(c, "OnAttributeChanged", mh, [=[-- MRU_Player_Change 
			if name ~= "unit" or value == playerUnit then return end
			playerUnit = value
			for key, v in pairs(ul) do
				local nj = 1
				for i=1,#v do
					local u = v[i]
					if u ~= playerUnit then
						KR:RunAttribute("SetAliasUnit", key .. nj, u)
						nj = nj + 1
					end
				end
				KR:RunAttribute("SetAliasUnit", key .. nj, "raid42")
			end
		]=])
		ph:SetAttribute("showRaid", true)
		ph:SetAttribute("showParty", false)
		ph:SetAttribute("showPlayer", false)
		ph:SetAttribute("nameList", (UnitName("player")))
		ph:Show()
	end
	SpawnHeader("tank", "roleFilter","TANK"):Show()
	SpawnHeader("mtank", "roleFilter","MAINTANK"):Show()
	SpawnHeader("assist", "roleFilter","MAINASSIST"):Show()
	SpawnHeader("healer", "roleFilter","HEALER"):Show()
	SpawnHeader("dps", "roleFilter","DAMAGER"):Show()
end)