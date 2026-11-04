-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSProfessionDB = private.NewLib("RareScannerProfessionDB")


---============================================================================
-- Professions
---============================================================================

local function HasProffesion(index, prof)
	if (index and prof) then
		local _, _, _, _, _, _, skillLine, _, _, _ = GetProfessionInfo(index)
		return skillLine and skillLine == prof
	end
	
	return false
end

function RSProfessionDB.HasPlayerProfession(prof)
	local pindex1, pindex2, pindex3, pindex4, pindex5, _ = GetProfessions();

	if (HasProffesion(pindex1, prof)) then
		return true
	end
	if (HasProffesion(pindex2, prof)) then
		return true
	end
	if (HasProffesion(pindex3, prof)) then
		return true
	end
	if (HasProffesion(pindex4, prof)) then
		return true
	end
	if (HasProffesion(pindex5, prof)) then
		return true
	end
	
	return false
end