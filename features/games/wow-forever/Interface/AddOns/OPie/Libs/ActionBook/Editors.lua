local _, T = ...
if T.SkipLocalActionBook then return end

local AB = T.ActionBook:compatible(2, 36)
assert(AB and 1, "Incompatible library bundle")
local L = T.ActionBook.L
local MODERN = select(4,GetBuildInfo()) >= 12e4

local RegisterSimpleOptionsPanel do
	local optionsForHandle, curHandle, curHandleID = {}
	local f, fButtons = CreateFrame("Frame"), {}
	f:Hide()
	local function callSave()
		local p = f:GetParent()
		if p and type(p.OnActionChanged) == "function" then
			p:OnActionChanged(curHandle)
		end
	end
	local function updateCheckButtonHitRect(self)
		local b = self:GetParent()
		b:SetHitRectInsets(0, -self:GetStringWidth()-5, 4, 4)
	end
	for i=1,3 do
		local e = CreateFrame("CheckButton", nil, f, MODERN and "UICheckButtonTemplate" or "InterfaceOptionsCheckButtonTemplate")
		if MODERN then
			e:SetSize(24, 24)
		end
		e.Text:SetPoint("LEFT", e, "RIGHT", MODERN and 2 or 0, 1)
		e.Text:SetFontObject(GameFontHighlightLeft)
		hooksecurefunc(e.Text, "SetText", updateCheckButtonHitRect)
		e:SetMotionScriptsWhileDisabled(1)
		e:SetScript("OnClick", callSave)
		fButtons[i] = e
	end

	local function IsOwned(self, host)
		return curHandle == self and f:GetParent() == host
	end
	local function Release(self, host)
		if IsOwned(self, host) then
			curHandle, curHandleID = nil
			f:SetParent(nil)
			f:ClearAllPoints()
			f:Hide()
		end
	end
	local function SetAction(self, host, actionTable)
		local opts, op = optionsForHandle[self], f:GetParent()
		assert(actionTable[1] == opts[0], "Invalid editor")
		if curHandle and op and (op ~= host or self ~= curHandle) and type(op.OnEditorRelease) == "function" then
			securecall(op.OnEditorRelease, op, curHandle)
		end
		f:SetParent(nil)
		f:ClearAllPoints()
		f:SetAllPoints(host)
		f:SetParent(host)
		curHandle, curHandleID = self, actionTable[2]
		local ofsX = host.optionsColumnOffset
		ofsX = type(ofsX) == "number" and ofsX or 2
		local getState, fvm = opts.getOptionState, opts.flagValues
		local f3 = type(actionTable[3]) == "number" and actionTable[3] or 0
		local nOpts = (opts.skipID ~= nil and actionTable[2] == opts.skipID and 0 or #opts)
		for i=1,nOpts do
			local w, oi, isChecked = fButtons[i], opts[i], false
			w.Text:SetText(opts[oi])
			w:SetPoint("TOPLEFT", ofsX, 23-21*i)
			local flagMask = fvm and fvm[opts[i]]
			if getState then
				isChecked = getState(actionTable, oi)
			elseif flagMask then
				isChecked = bit.band(f3, flagMask) == flagMask
			elseif actionTable[opts[i]] ~= nil then
				isChecked = not not actionTable[oi]
			end
			w:SetChecked(isChecked)
			w:Show()
		end
		for i=nOpts+1,#fButtons do
			fButtons[i]:Hide()
		end
		f:Show()
	end
	local function GetAction(self, into)
		local opts = optionsForHandle[self]
		into[1], into[2] = opts[0], curHandleID
		if opts.skipID ~= nil and opts.skipID == curHandleID then
			into[3] = nil
		elseif opts.flagValues then
			local v, fv = 0, opts.flagValues
			for i=1, #opts do
				v = v + (fButtons[i]:GetChecked() and fv[opts[i]] or 0)
			end
			into[3] = v > 0 and v or nil
		else
			for i=1,#opts do
				into[opts[i]] = fButtons[i]:GetChecked() or nil
			end
		end
		if opts.saveState then
			opts.saveState(into)
		end
	end
	function RegisterSimpleOptionsPanel(atype, opts)
		local r = {IsOwned=IsOwned, Release=Release, SetAction=SetAction, GetAction=GetAction}
		optionsForHandle[r], opts[0] = opts, atype
		AB:RegisterEditorPanel(atype, r)
	end
end

AB.HUM.CreateSimpleEditorPanel = RegisterSimpleOptionsPanel

local forceShowFlag = {forceShow=1}
securecall(RegisterSimpleOptionsPanel, "item", {"byName", "forceShow", "onlyEquipped",
	byName=L"Also use items with the same name",
	forceShow=L"Show a placeholder when unavailable",
	onlyEquipped=L"Only show when equipped",
	flagValues={byName=2, forceShow=1, onlyEquipped=4},
})
securecall(RegisterSimpleOptionsPanel, "macro", {"forceShow",
	forceShow=L"Show a placeholder when unavailable",
	flagValues=forceShowFlag,
})
if MODERN then
	securecall(RegisterSimpleOptionsPanel, "extrabutton", {"forceShow",
		forceShow=L"Show a placeholder when unavailable",
		flagValues=forceShowFlag,
	})
	securecall(RegisterSimpleOptionsPanel, "toy", {"forceShow",
		forceShow=L"Show a placeholder when unavailable",
		flagValues=forceShowFlag,
	})
	securecall(RegisterSimpleOptionsPanel, "outfit", {"noInitialLock",
		noInitialLock=L"Unlock appearance when switching",
		flagValues={noInitialLock=1},
		skipID=0,
	})
else
	securecall(RegisterSimpleOptionsPanel, "spell", {"upRank",
		upRank=L"Use the highest known rank",
		getOptionState=function(actionTable, _optKey)
			return actionTable[3] ~= 16
		end,
		saveState=function(intoTable)
			intoTable[3], intoTable.upRank = not intoTable.upRank and 16 or nil
		end,
	})
end