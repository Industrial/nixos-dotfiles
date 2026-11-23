local Logger = _G.idUpkeep_Logger
local Anchor = _G.idUpkeep_Anchor
local _rawOf
_rawOf = function(x)
  if type(x) == "table" and x.__class == _G.idUpkeep_Frame then
    return x.raw
  else
    return x
  end
end
local _pointName
_pointName = function(p)
  if type(p) == "table" and p.name then
    return p.name
  else
    return p
  end
end
local Frame
do
  local _class_0
  local _base_0 = {
    release = function(self)
      if self.pooled then
        local pool = Frame._poolFor(self.frameType, self.parent, self.template)
        if pool then
          pool:Release(self.raw)
        end
      elseif self.raw and self.raw.Hide then
        self.raw:Hide()
      end
      return self
    end,
    destroy = function(self)
      self:clearPoints()
      return self:release()
    end,
    point = function(self, anchorPoint, relativeToOrX, relativePointOrY, x, y)
      local p = _pointName(anchorPoint)
      if type(relativeToOrX) == "number" then
        self.raw:SetPoint(p, relativeToOrX, relativePointOrY)
      elseif relativeToOrX == nil then
        self.raw:SetPoint(p)
      else
        self.raw:SetPoint(p, (_rawOf(relativeToOrX)), (_pointName(relativePointOrY)), x, y)
      end
      return self
    end,
    anchorTo = function(self, other, anchorPoint, relativePoint, x, y)
      if x == nil then
        x = 0
      end
      if y == nil then
        y = 0
      end
      local ap
      if type(anchorPoint) == "string" then
        ap = (Anchor.fromString(anchorPoint) or error("Frame:anchorTo: invalid anchor point '" .. tostring(anchorPoint) .. "'", 2))
      else
        ap = anchorPoint
      end
      return self:point(ap, other, (relativePoint or ap:opposite()), x, y)
    end,
    clearPoints = function(self)
      self.raw:ClearAllPoints()
      return self
    end,
    size = function(self, w, h)
      if h == nil then
        h = w
      end
      self.raw:SetSize(w, h)
      return self
    end,
    width = function(self, w)
      self.raw:SetWidth(w)
      return self
    end,
    height = function(self, h)
      self.raw:SetHeight(h)
      return self
    end,
    strata = function(self, s)
      self.raw:SetFrameStrata(s)
      return self
    end,
    level = function(self, l)
      self.raw:SetFrameLevel(l)
      return self
    end,
    parentTo = function(self, p)
      self.raw:SetParent(_rawOf(p))
      return self
    end,
    backdrop = function(self, info)
      if self.raw.SetBackdrop then
        self.raw:SetBackdrop(info)
      end
      return self
    end,
    color = function(self, r, g, b, a)
      if a == nil then
        a = 1
      end
      if self.raw.SetColorTexture then
        self.raw:SetColorTexture(r, g, b, a)
      elseif self.raw.SetTextColor then
        self.raw:SetTextColor(r, g, b, a)
      end
      return self
    end,
    text = function(self, str)
      if self.raw.SetText then
        self.raw:SetText(str)
      end
      return self
    end,
    font = function(self, fontObject)
      if self.raw.SetFontObject then
        self.raw:SetFontObject(fontObject)
      end
      return self
    end,
    justify = function(self, h, v)
      if h and self.raw.SetJustifyH then
        self.raw:SetJustifyH(h)
      end
      if v and self.raw.SetJustifyV then
        self.raw:SetJustifyV(v)
      end
      return self
    end,
    show = function(self)
      self.raw:Show()
      return self
    end,
    hide = function(self)
      self.raw:Hide()
      return self
    end,
    shown = function(self, flag)
      self.raw:SetShown(flag == true)
      return self
    end,
    isShown = function(self)
      return self.raw:IsShown()
    end,
    enable = function(self, flag)
      if flag == nil then
        flag = true
      end
      if self.raw.SetEnabled then
        self.raw:SetEnabled(flag)
      end
      return self
    end,
    mouse = function(self, flag)
      if flag == nil then
        flag = true
      end
      if self.raw.EnableMouse then
        self.raw:EnableMouse(flag)
      end
      return self
    end,
    attribute = function(self, name, value)
      self.raw:SetAttribute(name, value)
      return self
    end,
    id = function(self, v)
      self.raw:SetID(v)
      return self
    end,
    registerForClicks = function(self, ...)
      self.raw:RegisterForClicks(...)
      return self
    end,
    registerForDrag = function(self, ...)
      self.raw:RegisterForDrag(...)
      return self
    end,
    on = function(self, event, fn)
      self.raw:SetScript(event, fn)
      return self
    end,
    onClick = function(self, fn)
      return self:on("OnClick", fn)
    end,
    onEnter = function(self, fn)
      return self:on("OnEnter", fn)
    end,
    onLeave = function(self, fn)
      return self:on("OnLeave", fn)
    end,
    onShow = function(self, fn)
      return self:on("OnShow", fn)
    end,
    onHide = function(self, fn)
      return self:on("OnHide", fn)
    end,
    onValueChanged = function(self, fn)
      return self:on("OnValueChanged", fn)
    end,
    onTextChanged = function(self, fn)
      return self:on("OnTextChanged", fn)
    end,
    registerEvent = function(self, event)
      self.raw:RegisterEvent(event)
      return self
    end,
    unregisterEvent = function(self, event)
      self.raw:UnregisterEvent(event)
      return self
    end,
    child = function(self, child)
      (_rawOf(child)):SetParent(self.raw)
      return self
    end,
    label = function(self, layer, fontObject)
      if layer == nil then
        layer = "OVERLAY"
      end
      if not (fontObject) then
        local Theme = _G.idUpkeep_Theme
        fontObject = Theme and Theme.font("row") or "GameFontHighlightSmall"
      end
      return Frame(self.raw:CreateFontString(nil, layer, fontObject))
    end,
    texture = function(self, layer)
      if layer == nil then
        layer = "ARTWORK"
      end
      return Frame(self.raw:CreateTexture(nil, layer))
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, raw, opts)
      if opts == nil then
        opts = { }
      end
      self.raw = raw
      self.frameType = opts.frameType
      self.parent = opts.parent
      self.template = opts.template
      self.pooled = opts.pooled == true
    end,
    __base = _base_0,
    __name = "Frame"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.wrap = function(raw)
    return Frame(raw)
  end
  self.create = function(frameType, name, parent, template)
    local rawParent = _rawOf(parent)
    return Frame((_G.CreateFrame(frameType, name, rawParent, template)), {
      frameType = frameType,
      parent = rawParent,
      template = template
    })
  end
  self._pools = { }
  self._poolKey = function(frameType, parent, template)
    local parentKey = (parent and parent.GetName and parent:GetName()) or tostring(parent)
    return tostring(frameType) .. "|" .. tostring(template or '') .. "|" .. tostring(parentKey)
  end
  self._poolFor = function(frameType, parent, template, resetter)
    local key = Frame._poolKey(frameType, parent, template)
    local pool = Frame._pools[key]
    if not (pool) then
      if not (_G.CreateFramePool) then
        Logger:getInstance():warn("Frame: CreateFramePool unavailable on this client, falling back to plain CreateFrame (no reuse).")
        return nil
      end
      pool = _G.CreateFramePool(frameType, parent, template, resetter)
      Frame._pools[key] = pool
    end
    return pool
  end
  self.acquire = function(frameType, parent, template, resetter)
    local rawParent = _rawOf(parent)
    local pool = Frame._poolFor(frameType, rawParent, template, resetter)
    if pool then
      local raw, isNew = pool:Acquire()
      raw:Show()
      return Frame(raw, {
        frameType = frameType,
        parent = rawParent,
        template = template,
        pooled = true
      }), isNew
    end
    return Frame.create(frameType, nil, rawParent, template), true
  end
  self.releaseAll = function()
    for _, pool in pairs(Frame._pools) do
      pool:ReleaseAll()
    end
  end
  Frame = _class_0
end
_G.idUpkeep_Frame = Frame
return Frame
