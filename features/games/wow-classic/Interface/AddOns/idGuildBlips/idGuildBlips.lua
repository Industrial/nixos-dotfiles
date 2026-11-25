-- Guild members on the world map and minimap, like party blips. LibGuildPositions hears where guildies running it are; it already leaves out you and your group.
local pins,lgp,ref=LibStub("HereBeDragons-Pins-2.0"),LibStub("LibGuildPositions-1.0"),"idGuildBlips"
local world,mini={},{}
local function blip(name,size)
  local f=CreateFrame("Frame")f:SetSize(size,size)f:EnableMouse(true)
  local t=f:CreateTexture(nil,"OVERLAY")t:SetAllPoints()t:SetTexture("Interface\\WorldMap\\WorldMapPartyIcon")
  f:SetScript("OnEnter",function(s)GameTooltip:SetOwner(s,"ANCHOR_RIGHT")GameTooltip:SetText(name)GameTooltip:Show()end)
  f:SetScript("OnLeave",GameTooltip_Hide)
  return f
end
lgp.RegisterCallback(ref,"Position",function(_,name,x,y,map)
  world[name]=world[name]or blip(name,16)mini[name]=mini[name]or blip(name,12)
  pins:AddWorldMapIconMap(ref,world[name],map,x,y,HBD_PINS_WORLDMAP_SHOW_PARENT)
  pins:AddMinimapIconMap(ref,mini[name],map,x,y)
end)
lgp.RegisterCallback(ref,"Clear",function(_,name)
  if world[name]then pins:RemoveWorldMapIcon(ref,world[name])pins:RemoveMinimapIcon(ref,mini[name])end
end)
