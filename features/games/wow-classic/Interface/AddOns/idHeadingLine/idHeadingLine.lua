-- A thin line from the player arrow to the edge of the minimap and world map, the way the arrow faces. Line it up with where you want to go.
local PIXELS,R,G,B,A=2,1,.9,.2,.9
local sin,cos,abs,max,min=math.sin,math.cos,math.abs,math.max,math.min

local function overlay(parent,level)
  local f=CreateFrame("Frame",nil,parent)f:SetAllPoints()f:SetFrameLevel(level)
  local l=f:CreateLine(nil,"OVERLAY",nil,7)l:SetColorTexture(R,G,B,A)f.line=l
  return f
end
local function thickness(l)
  local t=PIXELS*768/select(2,GetPhysicalScreenSize())/l:GetEffectiveScale()
  l:SetThickness(PixelUtil and PixelUtil.GetNearestPixelSize(t,l:GetEffectiveScale(),PIXELS)or t)
end
-- GetPlayerFacing: radians, 0 is north, counter-clockwise. nil where it is hidden (instances).
local function heading()local f=GetPlayerFacing()if f then return -sin(f),cos(f)end end

-- Minimap: the player sits at the centre. A rotating minimap keeps the arrow pointing up.
local mini=overlay(Minimap,Minimap:GetFrameLevel()+10)
mini:SetScript("OnUpdate",function(self)
  local l,dx,dy=self.line,heading()
  if not dx then return l:Hide()end
  if GetCVar("rotateMinimap")=="1"then dx,dy=0,1 end
  local r=Minimap:GetWidth()/2
  if GetMinimapShape and GetMinimapShape()=="SQUARE"then r=r/max(abs(dx),abs(dy))end
  thickness(l)l:SetStartPoint("CENTER",self,0,0)l:SetEndPoint("CENTER",self,dx*r,dy*r)l:Show()
end)

-- World map: north is always up. Work in screen pixels, then end the line at the edge of what is visible.
local function worldMap()
  local sc=WorldMapFrame.ScrollContainer
  local map=overlay(sc,9000)
  map:SetScript("OnUpdate",function(self)
    local l,dx,dy=self.line,heading()
    local id=WorldMapFrame:GetMapID()
    local pos=dx and id and C_Map.GetPlayerMapPosition(id,"player")
    if not pos then return l:Hide()end
    local x,y=pos:GetXY()
    local c=sc.Child local cs,ss=c:GetEffectiveScale(),sc:GetEffectiveScale()
    local cl,ct=c:GetLeft(),c:GetTop()
    local sl,sb,sw,sh=sc:GetRect()
    if not(cl and sl)then return l:Hide()end
    cl,ct=cl*cs,ct*cs
    local px,py=cl+x*c:GetWidth()*cs,ct-y*c:GetHeight()*cs
    local L,Rt=max(sl*ss,cl),min((sl+sw)*ss,cl+c:GetWidth()*cs)
    local Bt,T=max(sb*ss,ct-c:GetHeight()*cs),min((sb+sh)*ss,ct)
    if px<L or px>Rt or py<Bt or py>T then return l:Hide()end
    local t=math.huge
    if dx>0 then t=min(t,(Rt-px)/dx)elseif dx<0 then t=min(t,(L-px)/dx)end
    if dy>0 then t=min(t,(T-py)/dy)elseif dy<0 then t=min(t,(Bt-py)/dy)end
    local os=self:GetEffectiveScale()local ol,ob=self:GetLeft(),self:GetBottom()
    thickness(l)
    l:SetStartPoint("BOTTOMLEFT",self,px/os-ol,py/os-ob)
    l:SetEndPoint("BOTTOMLEFT",self,(px+dx*t)/os-ol,(py+dy*t)/os-ob)
    l:Show()
  end)
end
if WorldMapFrame and WorldMapFrame.ScrollContainer then worldMap()
else EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap",worldMap)end
