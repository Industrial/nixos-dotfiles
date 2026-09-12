local COMPAT, _, T = select(4,GetBuildInfo()), ...
if T.TenEnv then T.TenEnv() end
local XU = T.exUI
local SECRETS = COMPAT >= 12e4 or nil
local _assert, getWidgetData, newWidgetData, setWidgetData, _AddObjectMethods, _CallObjectScript = XU:GetImpl()

local IndicatorData, Indicator, CooldownData = {}, {}, {}
local IndicatorProps = {
	api=Indicator,
	iconAspect=1,
	ustate=-1,
	rcTextShown=false,
	cdTextShown=false,
}

local darken do
	local CSL = CreateFrame("ColorSelect")
	function darken(r,g,b, vf, sf)
		CSL:SetColorRGB(r,g,b)
		local h,s,v = CSL:GetColorHSV()
		CSL:SetColorHSV(h, s*(sf or 1), v*(vf or 1))
		return CSL:GetColorRGB()
	end
end

local function cooldownFormat(cd)
	if (cd or 0) == 0 then return "" end
	local f, n, unit = cd >= 9.95 and "%d%s" or "%.1f", cd, ""
	if n > 86400 then n, unit = ceil(n/86400), "d"
	elseif n > 3600 then n, unit = ceil(n/3600), "h"
	elseif n > 90 then n, unit = ceil(n/60), "m"
	elseif cd >= 9.95 then n = ceil(n) end
	return f, n, unit
end
local createCDTextBinding if SECRETS then
	local cdTextFormat = C_StringUtil.CreateNumericRuleFormatter()
	cdTextFormat:AddBreakpoint({threshold=0, format=""})
	cdTextFormat:AddBreakpoint({threshold=2^-20, step=0.1, format="%.1f"})
	cdTextFormat:AddBreakpoint({threshold=9.95, step=1, format="%d"})
	cdTextFormat:AddBreakpoint({threshold=90, format="%dm", components={div=60, step=1}})
	cdTextFormat:AddBreakpoint({threshold=5400, format="%dh", components={div=3600, step=1}})
	cdTextFormat:AddBreakpoint({threshold=259200, format="%dd", components={div=86400, step=1}})
	function createCDTextBinding(fs)
		local w = C_DurationUtil.CreateDurationTextBinding()
		w:SetFontString(fs)
		w:SetFormatter(cdTextFormat)
		return w
	end
end

local function adjustIconAspect(d, aspect)
	if d.iconAspect ~= aspect then
		d.iconAspect = aspect
		local w, h = d.iconbg:GetSize()
		d.icon:SetSize(aspect < 1 and h*aspect or w, aspect > 1 and w/aspect or h)
	end
end
local CreateCooldown, CallCooldownUpdate do
	local ninf = -math.huge
	local AROUND_LEFT, TAU = {x=0, y=0.5}, 2*math.pi
	local sparkPos, SPARK_CORNER_PROG do
		local CORNER_CUT = 3.5/62
		local CORNER_A4MIN = math.atan2(0.5-CORNER_CUT, 0.5)
		local CORNER_A4MAX = math.atan2(0.5, 0.5-CORNER_CUT)
		local CORNER_R = (0.5 - CORNER_CUT + CORNER_CUT^2)^0.5
		SPARK_CORNER_PROG = 0.125-CORNER_A4MIN/TAU
		local mcos, msin, mtan = math.cos, math.sin, math.tan
		function sparkPos(p)
			local a4, x, y = (p % 0.25) * TAU
			if a4 > CORNER_A4MIN and a4 < CORNER_A4MAX then
				x, y = mcos(a4)*CORNER_R, msin(a4)*CORNER_R
			elseif a4 <= CORNER_A4MIN then
				x, y = 0.5, 0.5*mtan(a4)
			else
				x, y = 0.5/mtan(a4), 0.5
			end
			if p < 0.25 then
				x, y = y, x
			elseif p < 0.50 then
				x, y = x, -y
			elseif p < 0.75 then
				x, y = -y, -x
			else
				x, y = -x, y
			end
			return x+0.5, y+0.5
		end
	end
	local Curve = SECRETS and (function()
		local function addPoints(c, x, y, z, zz, ...)
			if x == nil then
				return c
			elseif x == z then
				c:AddPoint(z, zz)
				z, zz = x, y
			else
				c:AddPoint(x, y)
			end
			return addPoints(c, z, zz, ...)
		end
		local function curve(ct, ...)
			local c = C_CurveUtil.CreateCurve()
			c:SetType(ct)
			return addPoints(c, ...)
		end
		local function bindCurve(m, c)
			return function(o, ...)
				return o[m](o, c, ...)
			end
		end
		local function boundCurve(m, ...)
			return bindCurve(m, curve(...))
		end

		local sparkX, sparkY = C_CurveUtil.CreateCurve(), C_CurveUtil.CreateCurve() do
			local function addX(px)
				local p2 = px >= 0.5 and (px - 0.5) or (px + 0.5)
				sparkX:AddPoint(px, (sparkPos(px)))
				sparkX:AddPoint(p2, (sparkPos(p2)))
			end
			local function addY(py)
				local _, vy = sparkPos(py)
				local _, vy2 = sparkPos(0.5 + py)
				sparkY:AddPoint(py, vy)
				sparkY:AddPoint(0.5+py, vy2)
			end
			for i=0, 120 do
				local sp = i/480
				addX((0.875 + sp) % 1)
				addY(0.125 + sp)
			end
			for i=1, 2 do
				addX(0.125+SPARK_CORNER_PROG/i)
				addX(0.875-SPARK_CORNER_PROG/i)
				addY(0.125-SPARK_CORNER_PROG/i)
				addY(0.375+SPARK_CORNER_PROG/i)
			end
		end

		return {
			ZeroRemainingDurationAlpha=boundCurve("EvaluateRemainingDuration", 1, 0,0, 2^-40,1),
			CooldownSpiralAngle=boundCurve("EvaluateRemainingPercent", 0, 0,0, 1,2*math.pi),
			MaskedBorder={
				boundCurve("EvaluateRemainingPercent", 1, 0,0,  0.50,1.00),
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 2^-20,1.00, 0.50,0),
				boundCurve("EvaluateRemainingPercent", 1, 0,0,  0.50,0.45),
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 2^-20,0.45, 0.50,0),
			},
			RestBorder={
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 0.50,0),
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 0.50,1),
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 0.50,0),
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 0.50,0.45),
			},
			MaskedVeil={
				boundCurve("EvaluateRemainingPercent", 1, 0,0,  0.50,0.85),
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 2^-20,0.85, 0.50,0),
				boundCurve("EvaluateRemainingPercent", 1, 0,0,  0.50,0.25),
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 2^-20,0.25, 0.50,0),
			},
			RestVeil={
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 0.50,0),
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 0.50,0.85),
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 0.50,0),
				boundCurve("EvaluateRemainingPercent", 1, 0,0, 0.50,0.25),
			},
			SparkX=bindCurve("EvaluateElapsedPercent", sparkX),
			SparkY=bindCurve("EvaluateElapsedPercent", sparkY),
		}
	end)()
	local function cdMarkSecret(d)
		d.secretMode = 1
		local spark, s0, s1 = d.spark, d, d.sst1
		for i=1, 4 do
			s0[i]:Show()
			s1[i]:Show()
		end
		spark:Show()
		spark:SetAlpha(0)
		spark:ClearAllPoints()
		spark:SetPoint("CENTER", d.sparkYT, "TOPLEFT")
	end
	local function cdClearSecret(d)
		d.secretMode, d.pos, d.updateCooldown = nil
		d.spark:SetAlpha(1)
		d.parentControl.veil:SetAlpha(d.parentControl.ustate == 0 and 0 or 0.40)
	end
	local function cdOnUpdate_Secret(d, _elapsed)
		if d.secretMode ~= 1 then
			cdMarkSecret(d)
		end
		local ev = C_CurveUtil.EvaluateColorValueFromBoolean
		local MaskBorder, MaskVeil = Curve.MaskedBorder, Curve.MaskedVeil
		local RestBorder, RestVeil = Curve.RestBorder, Curve.RestVeil
		local pd, s0, s1 = d.parentControl, d, d.sst1
		local dur, isRecharge, usable = d.cdDuration, d.cdIsRecharge, d.usable
		local zero = dur and dur:IsZero()
		if dur then
			s1.mask:SetRotation(Curve.CooldownSpiralAngle(dur), AROUND_LEFT)
			pd.veil:SetAlpha(usable and (isRecharge and 0 or ev(zero, 0, 0.40)) or 0.40)
			for i=1, 2 do
				local j = i+2
				local k = isRecharge and j or i
				s1[i]:SetAlpha(MaskBorder[k](dur))
				s1[j]:SetAlpha(MaskVeil[k](dur))
				s0[i]:SetAlpha(RestBorder[k](dur))
				s0[j]:SetAlpha(RestVeil[k](dur))
			end
		else
			pd.veil:SetAlpha(0)
			for i=1,4 do
				s0[i]:SetAlpha(0)
				s1[i]:SetAlpha(0)
			end
		end
		if isRecharge then
			d.spark:Show()
			d.spark:SetAlpha(usable and Curve.ZeroRemainingDurationAlpha(dur) or 0)
			d.sparkX:SetValue(Curve.SparkX(dur))
			d.sparkY:SetValue(Curve.SparkY(dur))
		else
			d.spark:SetAlpha(0)
		end
	end
	local function cdOnUpdate(self, elapsed)
		local d = getWidgetData(self, CooldownData)
		if d.cdDuration then
			d.updateCooldown = 0
			return cdOnUpdate_Secret(d, elapsed)
		elseif d.secretMode then
			cdClearSecret(d)
		end
		local ucd, expire, time = d.updateCooldown or 0, d.expire or ninf, GetTime()
		if ucd > elapsed and time < expire then
			d.updateCooldown = ucd - elapsed
			return
		end
		d.updateCooldown = d.updateCooldownStep

		local duration, progress = d.duration or 0, expire - time
		if progress >= duration or duration == 0 then
			self:Hide()
			return
		end
		local s0, s1 = d, d.sst1
		progress = progress < 0 and 0 or (1 - progress/duration)
		local pos = progress >= 0.5 and 2 or 1
		for i=1, d.pos ~= pos and 2 or 0 do
			local j = i+2
			s0[i]:SetShown(i > pos)
			s0[j]:SetShown(i > pos)
			s1[i]:SetShown(i == pos)
			s1[j]:SetShown(i == pos)
		end
		d.pos = pos
		s1.mask:SetRotation((1-progress)*TAU, AROUND_LEFT)

		local sx, sy = sparkPos(progress)
		d.spark:SetPoint("CENTER", self, "CENTER", 45*(sx-0.5), 45*(sy-0.5))
	end
	local function cdSetVeilShown(d, shown)
		local s0, s1 = d, d.sst1
		for i=3, 4 do
			s0[i]:SetShown(shown)
			s1[i]:SetShown(shown)
		end
	end
	local function cdOnHide(self)
		local d = getWidgetData(self, CooldownData)
		local toExpire = GetTime() - (d.expire or 0)
		d.expire, d.pos, d.cdDuration = nil
		cdSetVeilShown(d, false)
		d.self:Hide()
		d.spark:Hide()
		if -0.1 < toExpire and toExpire < 0.25 then
			d.flashAG:Play()
		end
	end
	local function cdOnShow(self)
		local d = getWidgetData(self, CooldownData)
		cdSetVeilShown(d, true)
		d.pos = nil -- Forces quad texture update
		return cdOnUpdate(self, 0)
	end
	function CallCooldownUpdate(d)
		local self = d.self
		d.updateCooldown = nil
		self:Show()
		if d.updateCooldown == nil then
			return cdOnUpdate(self, 0)
		end
	end
	local function maybeAddMask(tex, mask)
		return mask and tex:AddMaskTexture(mask)
	end
	local function createSpiralOverlay(cd, parent, d, borderTex, white128, scale, mask, iconmask)
		local w, l
		if mask then
			w = parent:CreateMaskTexture()
			w:SetTexture(white128, 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE', 'NEAREST')
			w:SetSize(34*scale, 68*scale)
			w:SetPoint("LEFT", parent, "CENTER")
			d.mask, mask = w, w
		end
		for i=1,2 do
			w = cd:CreateTexture(nil, "ARTWORK", nil, 2)
			l, d[i] = i == 2, w
			w:SetTexture(borderTex)
			w:SetSize(24, 48)
			w:SetTexCoord(l and 0 or 0.5, l and 0.5 or 1, 0, 1)
			w:SetPoint(l and "RIGHT" or "LEFT", cd, "CENTER")
			maybeAddMask(w, mask)
			w:Hide()
			w = parent:CreateTexture(nil, "ARTWORK", nil, 4)
			w:SetColorTexture(1,1,1)
			w:SetPoint(l and "RIGHT" or "LEFT", cd, "CENTER")
			w:SetSize(21*scale, 42*scale)
			maybeAddMask(w, mask)
			maybeAddMask(w, iconmask)
			w:Hide()
			d[2+i] = w
		end
		return d
	end
	function CreateCooldown(parent, size, overParent, gx, pd, iconmask)
		local cd, scale = CreateFrame("Frame", nil, parent), size * 87/4032
		local d, w, b = setWidgetData(cd, CooldownData, {self=cd, parent=parent, parentControl=pd, secretMode=0})
		cd:SetScale(size/48)
		cd:SetAllPoints()
		cd:SetScript("OnShow", cdOnShow)
		cd:SetScript("OnHide", cdOnHide)
		cd:SetScript("OnUpdate", cdOnUpdate)
		w = (overParent or cd):CreateTexture(nil, "OVERLAY", nil, 2)
		w:SetTexture(gx.CooldownSpark)
		w:SetSize(24,24)
		w, d.spark = w:CreateAnimationGroup(), w
		w:SetLooping("REPEAT")
		b = w:CreateAnimation("Rotation")
		b:SetDegrees(90)
		b:SetDuration(1/3)
		w:Play()

		w = parent:CreateTexture(nil, "OVERLAY")
		w:SetSize(size*60/64, size*60/64)
		w:SetPoint("CENTER")
		w:SetTexture(gx.CooldownStar)
		w:SetBlendMode("ADD")
		w:SetAlpha(0)
		w, d.flash = w:CreateAnimationGroup(), w
		b, d.flashAG = w:CreateAnimation("ROTATION"), w
		b:SetDuration(1/2)
		b:SetDegrees(-90)
		b = w:CreateAnimation("Alpha")
		b:SetFromAlpha(0)
		b:SetToAlpha(0.7)
		b:SetDuration(1/8)
		b = w:CreateAnimation("Alpha")
		b:SetFromAlpha(0.7)
		b:SetToAlpha(0)
		b:SetDuration(1/8)
		b:SetStartDelay(3/8)

		createSpiralOverlay(cd, parent, d, gx.BorderLow, gx.White128, scale, false, iconmask)
		local s1 = createSpiralOverlay(cd, parent, {}, gx.BorderLow, gx.White128, scale, true, iconmask)
		d.sst1 = s1

		if SECRETS then
			local c = (overParent or cd):CreateTexture()
			c:SetSize(45, 45)
			c:SetPoint("CENTER")
			local cd, w, mx, my = d.self
			for i=1, 2 do
				w = CreateFrame("StatusBar", nil, cd)
				w:SetScale(2^-15)
				w:SetMinMaxValues(0, 1)
				w:SetValue(0.5)
				w:SetStatusBarTexture("Interface/Buttons/White8x8")
				w:SetAlpha(0)
				my, mx = w, my
			end
			mx:SetHeight(1)
			mx:SetPoint("LEFT", c, "BOTTOMLEFT")
			mx:SetPoint("RIGHT", c, "BOTTOMRIGHT")
			my:SetWidth(1)
			my:SetOrientation("VERTICAL")
			my:SetPoint("BOTTOMLEFT", mx:GetStatusBarTexture(), "RIGHT", 0, 0)
			my:SetPoint("TOP", c)
			d.sparkX, d.sparkY, d.sparkYT = mx, my, my:GetStatusBarTexture()
		end
		return cd, d
	end
end

function Indicator:SetIcon(texture, aspect)
	local d = getWidgetData(self, IndicatorData)
	d.icon:SetTexture(texture)
	local ofs = 2.5/64
	d.icon:SetTexCoord(ofs, 1-ofs, ofs, 1-ofs)
	return adjustIconAspect(d, aspect)
end
function Indicator:SetIconAtlas(atlas, aspect)
	local d = getWidgetData(self, IndicatorData)
	d.icon:SetAtlas(atlas)
	return adjustIconAspect(d, aspect)
end
function Indicator:SetIconTexCoord(a,b,c,dc, e,f,g,h)
	if a and b and c and dc then
		local d = getWidgetData(self, IndicatorData)
		if e and f and g and h then
			d.icon:SetTexCoord(a,b,c,dc, e,f,g,h)
		else
			d.icon:SetTexCoord(a,b,c,dc)
		end
	end
end
function Indicator:SetIconVertexColor(r,g,b)
	local d = getWidgetData(self, IndicatorData)
	d.icon:SetVertexColor(r,g,b)
end
function Indicator:SetUsable(usable, _usableCharge, _cd, nomana, norange)
	local d = getWidgetData(self, IndicatorData)
	local state = usable and 0 or (norange and 1 or (nomana and 2 or 3))
	d.veil:SetAlpha(usable and 0 or 0.40)
	if d.ustate == state then return end
	d.ustate = state
	if not usable and (nomana or norange) then
		d.ribbon:Show()
		if norange then
			d.ribbon:SetVertexColor(1, 0.20, 0.15)
		else
			d.ribbon:SetVertexColor(0.15, 0.75, 1)
		end
	else
		d.ribbon:Hide()
	end
end
function Indicator:SetDominantColor(r,g,b)
	local d = getWidgetData(self, IndicatorData)
	r, g, b = r or 1, g or 1, b or 0.6
	local cdd, r2, g2, b2 = d.cdControl, darken(r,g,b, 0.20)
	local r3, g3, b3 = darken(r,g,b, 0.10, 0.50)
	local s1 = cdd.sst1
	d.hiEdge:SetVertexColor(r, g, b)
	d.iglow:SetVertexColor(r, g, b)
	d.oglow:SetVertexColor(r, g, b)
	d.edge:SetVertexColor(darken(r,g,b, 0.80))
	d.cdText:SetTextColor(r, g, b)
	cdd.spark:SetVertexColor(r, g, b)
	for i=1,2 do
		local j = i+2
		cdd[i]:SetVertexColor(r2, g2, b2)
		cdd[j]:SetVertexColor(r3, g3, b3)
		if s1 then
			s1[i]:SetVertexColor(r2, g2, b2)
			s1[j]:SetVertexColor(r3, g3, b3)
		end
	end
end
function Indicator:SetOverlayIcon(tex, w, h, ...)
	local oi = getWidgetData(self, IndicatorData).overIcon
	if not tex then
		return oi:Hide()
	end
	oi:Show()
	oi:SetTexture(tex)
	oi:SetSize(w, h)
	if ... then
		oi:SetTexCoord(...)
	else
		oi:SetTexCoord(0,1, 0,1)
	end
end
function Indicator:SetOverlayIconVertexColor(...)
	getWidgetData(self, IndicatorData).overIcon:SetVertexColor(...)
end
function Indicator:SetCount(count)
	getWidgetData(self, IndicatorData).count:SetText(count or "")
end
function Indicator:SetBinding(binding)
	binding = binding and GetBindingText(binding, 1) or ""
	getWidgetData(self, IndicatorData).key:SetText(binding)
end
function Indicator:SetCooldown(remain, duration, usableCharge)
	local d = getWidgetData(self, IndicatorData)
	local cdd = d.cdControl
	cdd.cdDuration, cdd.cdIsRecharge = nil
	if SECRETS then
		d.cdTextBinding:Disable()
	end
	if (duration or 0) <= 0 or (remain or 0) <= 0 then
		d.cd:Hide()
		d.cdText:SetText("")
	else
		local now = GetTime()
		local expire, usable = now + remain, not not usableCharge
		local td, showSpark, secret = expire - (cdd.expire or 0), usable and d.ustate == 0, cdd.secretMode
		if td < -0.05 or td > 0.05 or secret then
			cdd.duration, cdd.expire, cdd.updateCooldownStep, cdd.updateCooldown = duration, expire, duration/1536/d.self:GetEffectiveScale()
			cdd.spark:SetShown(showSpark)
		end
		if cdd.usable ~= usable or secret then
			cdd.usable = usable
			local s0, s1 = cdd, cdd.sst1
			for i=1,2 do
				local j = 2+i
				s0[i]:SetAlpha(usable and 0.45 or 1)
				s0[j]:SetAlpha(usable and 0.25 or 0.85)
				s1[i]:SetAlpha(usable and 0.45 or 1)
				s1[j]:SetAlpha(usable and 0.25 or 0.85)
			end
			cdd.spark:SetShown(showSpark)
		end
		local gcS, gcL = GetSpellCooldown(61304)
		if (duration ~= gcL or gcS+gcL-now < remain) and d[usableCharge and "rcTextShown" or "cdTextShown"] then
			d.cdText:SetFormattedText(cooldownFormat(remain))
			d.cdText:SetAlpha(1)
		else
			d.cdText:SetText("")
		end
		CallCooldownUpdate(cdd)
	end
end
function Indicator:SetCooldownTextShown(cooldownShown, rechargeShown)
	local d = getWidgetData(self, IndicatorData)
	d.cdTextShown, d.rcTextShown = cooldownShown, rechargeShown
end
function Indicator:SetHighlighted(highlight)
	getWidgetData(self, IndicatorData).hiEdge:SetShown(highlight)
end
function Indicator:SetActive(active)
	getWidgetData(self, IndicatorData).iglow:SetShown(active)
end
function Indicator:SetOuterGlow(shown)
	getWidgetData(self, IndicatorData).oglow:SetShown(shown)
end
function Indicator:SetEquipState(isInContainer, isInInventory)
	local s = getWidgetData(self, IndicatorData).equipBanner
	local v, r, g, b = isInContainer or isInInventory, 0.1, 0.9, 0.15
	s:SetShown(v)
	if v then
		if not isInInventory then
			r, g, b = 1, 0.9, 0.2
		end
		s:SetVertexColor(r, g, b)
	end
end
function Indicator:SetShortLabel(text)
	getWidgetData(self, IndicatorData).label:SetText(text)
end
function Indicator:SetQualityOverlay(_qualID, qualAtlas)
	local s = getWidgetData(self, IndicatorData).qualityMark
	if qualAtlas then
		s:SetAtlas(qualAtlas)
	end
	s:SetShown(qualAtlas ~= nil)
end
function Indicator:SetCooldownDuration(duration, isRecharge)
	local d = getWidgetData(self, IndicatorData)
	local cdd = d.cdControl
	d.cdTextBinding:SetDuration(duration)
	d.cdTextBinding:SetEnabled(d[isRecharge and "rcTextShown" or "cdTextShown"])
	cdd.cdDuration, cdd.cdIsRecharge, cdd.usable, cdd.expire = duration, isRecharge, d.ustate == 0, nil
	CallCooldownUpdate(cdd)
end

local function CreateIndicator(name, parent, size, nested, gx)
	local cf, d, w, ef = CreateFrame("Frame", name, parent)
		cf:SetSize(size, size)
	d = newWidgetData(cf, IndicatorData, IndicatorProps)
	ef = CreateFrame("Frame", nil, cf)
		ef:SetAllPoints()
	w = ef:CreateTexture(nil, "OVERLAY")
		w:SetAllPoints()
		w:SetTexture(gx.BorderLow)
	w, d.edge = ef:CreateTexture(nil, "OVERLAY", nil, 1), w
		w:SetAllPoints()
		w:SetTexture(gx.BorderHigh)
	w, d.hiEdge = T.CreateQuadTexture("BACKGROUND", size*2, gx.OuterGlow, cf), w
		w:SetShown(false)
	w, d.oglow = ef:CreateTexture(nil, "ARTWORK", nil, 1), w
		w:SetAllPoints()
		w:SetTexture(gx.InnerGlow)
		w:SetAlpha(nested and 0.6 or 1)
	w, d.iglow = ef:CreateTexture(nil, "ARTWORK"), w
		w:SetPoint("CENTER")
		w:SetSize(60*size/64, 60*size/64)
	w, d.icon = ef:CreateTexture(nil, "ARTWORK", nil, -2), w
		w:SetPoint("CENTER")
		w:SetSize(60*size/64, 60*size/64)
		w:SetColorTexture(0.15, 0.15, 0.15, 0.85)
	w, d.iconbg = ef:CreateMaskTexture(), w
		w:SetTexture(gx.IconMask)
		w:SetAllPoints()
		d.icon:AddMaskTexture(w)
		d.iconbg:AddMaskTexture(w)
	w, d.iconmask = CreateFrame("Frame", nil, cf), w
		w:SetAllPoints()
		w:SetFrameLevel(ef:GetFrameLevel()+5)
	d.cd, d.cdControl = CreateCooldown(ef, size, w, gx, d, d.iconmask)
	w = d.cd:CreateFontString(nil, "OVERLAY", "GameFontNormalLargeOutline")
		w:SetPoint("CENTER")
	w, d.cdText, d.cdTextBinding = ef:CreateTexture(nil, "ARTWORK", nil, 2), w, createCDTextBinding and createCDTextBinding(w)
		w:SetSize(60*size/64, 60*size/64)
		w:SetPoint("CENTER")
		w:SetColorTexture(0,0,0)
	w, d.veil = ef:CreateTexture(nil, "ARTWORK", nil, 3), w
		w:SetAllPoints()
		w:SetTexture(gx.Ribbon)
		w:Hide()
	w, d.ribbon = ef:CreateTexture(nil, "ARTWORK", nil, 5), w
		w:SetPoint("BOTTOMLEFT", 4, 4)
	w, d.overIcon = ef:CreateFontString(nil, "OVERLAY", "NumberFontNormal"), w
		w:SetJustifyH("RIGHT")
		w:SetPoint("BOTTOMRIGHT", -2, 4)
	w, d.count = ef:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray"), w
		w:SetJustifyH("RIGHT")
		w:SetPoint("TOPRIGHT", -2, -3)
	w, d.key = ef:CreateTexture(nil, "ARTWORK", nil, 2), w
		w:SetSize(size/5, size/4)
		w:SetTexture("Interface\\GuildFrame\\GuildDifficulty")
		w:SetTexCoord(0, 42/128, 6/64, 52/64)
		w:SetPoint("TOPLEFT", 6*size/64, -3*size/64)
	w, d.equipBanner = ef:CreateFontString(nil, "OVERLAY", "TextStatusBarText", -1), w
		w:SetSize(size-4, 12)
		w:SetJustifyH("CENTER")
		w:SetJustifyV("BOTTOM")
		w:SetMaxLines(1)
		w:SetPoint("BOTTOMLEFT", 3, 4)
		w:SetPoint("BOTTOMRIGHT", d.count, "BOTTOMLEFT", 2, 0)
	w, d.label = ef:CreateTexture(nil, "ARTWORK", nil, 3), w
		w:SetPoint("TOPLEFT", 4, -4)
		w:SetSize(14,14)
		w:Hide()
	d.qualityMark = w
	return cf
end

XU:RegisterFactory("OPie:MirageIndicator", CreateIndicator)