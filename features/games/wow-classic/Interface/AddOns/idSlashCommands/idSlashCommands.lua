-- Short slash commands for the game's panels. Each one clicks the micro-menu button, so it opens what the button opens.
local function click(name)return function()local b=_G[name]if b then b:Click()end end end
local commands={
  RELOAD={ReloadUI,"/rl","/reload"},
  LFG={click"LFDMicroButton","/lfg","/lookingforgroup"},
  CALENDAR={function()if ToggleCalendar then ToggleCalendar()else GameTimeFrame:Click()end end,"/cal","/calendar"},
  CHARACTER={click"CharacterMicroButton","/char","/character"},
  PROFESSIONS={click"ProfessionMicroButton","/prof","/professions"},
  SPELLBOOK={click"SpellbookMicroButton","/spell","/spellbook"},
  TALENTS={click"TalentMicroButton","/tal","/talents"},
  LEGACY={click"LegacyMicroButton","/leg","/legacy"},
  QUESTLOG={click"QuestLogMicroButton","/ql","/questlog"},
  -- /guild is also Blizzard's guild-chat command, which wins over slash commands. Free it, and keep "/guild <text>" talking in guild chat (/g still does).
  GUILD={function(msg)if msg~=""then SendChatMessage(msg,"GUILD")else click"GuildMicroButton"()end end,"/guild"},
  COLLECTIONS={click"CollectionsMicroButton","/col","/collections"},
  SHOP={click"StoreMicroButton","/shop"},
  MENU={click"MainMenuMicroButton","/menu"},
}
for key,c in pairs(commands)do
  key="IDSLASH_"..key
  for i=2,#c do _G["SLASH_"..key..(i-1)]=c[i]end
  SlashCmdList[key]=c[1]
end
if hash_ChatTypeInfoList then hash_ChatTypeInfoList["/GUILD"]=nil end
