-- src/corrections/manifest.lua
--
-- Initially generated from the provider inventory declared in
-- tools/questie-sync/port-corrections.lua. See PROVENANCE.md for the Questie source reference.
-- Now maintained here. Update this table when adding or reclassifying providers.
--
-- Which correction file provides which functions, and whether each is Static or
-- Dynamic. The classification is declared by the author, never inferred — folder names
-- are not a reliable signal, as `Sod/static/sodItemQuestStartFixes.lua` registering
-- dynamic in the prototype demonstrates. `minExpansionOrder` also identifies the source
-- expansion; only ungated Era entries need an explicit `sourceExpansionOrder`.

local _, LibQuestieDB = ...

local manifest = {
  { file = 'Era/classicQuestFixes.lua', module = 'QuestieQuestFixes', datatype = 'Quest', static = {'Load'}, dynamic = {'LoadFactionFixes'}, sourceExpansionOrder = 1 },
  { file = 'Era/classicNPCFixes.lua', module = 'QuestieNPCFixes', datatype = 'Npc', static = {'Load'}, dynamic = {'LoadFactionFixes'}, sourceExpansionOrder = 1 },
  { file = 'Era/classicItemFixes.lua', module = 'QuestieItemFixes', datatype = 'Item', static = {'Load'}, dynamic = {'LoadFactionFixes'}, sourceExpansionOrder = 1 },
  { file = 'Era/classicObjectFixes.lua', module = 'QuestieObjectFixes', datatype = 'Object', static = {'Load'}, dynamic = {'LoadFactionFixes'}, sourceExpansionOrder = 1 },
  { file = 'Era/classicQuestReputationFixes.lua', module = 'QuestieClassicQuestReputationFixes', datatype = 'Quest', static = {'Load'}, expansions = {['Classic']=true}, generated = true },
  { file = 'Tbc/tbcQuestFixes.lua', module = 'QuestieTBCQuestFixes', datatype = 'Quest', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 2 },
  { file = 'Tbc/tbcNPCFixes.lua', module = 'QuestieTBCNpcFixes', datatype = 'Npc', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 2 },
  { file = 'Tbc/tbcItemFixes.lua', module = 'QuestieTBCItemFixes', datatype = 'Item', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 2 },
  { file = 'Tbc/tbcObjectFixes.lua', module = 'QuestieTBCObjectFixes', datatype = 'Object', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 2 },
  { file = 'Wotlk/wotlkQuestFixes.lua', module = 'QuestieWotlkQuestFixes', datatype = 'Quest', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 3 },
  { file = 'Wotlk/wotlkNPCFixes.lua', module = 'QuestieWotlkNpcFixes', datatype = 'Npc', static = {'LoadAutomatics','Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 3 },
  { file = 'Wotlk/wotlkItemFixes.lua', module = 'QuestieWotlkItemFixes', datatype = 'Item', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 3 },
  { file = 'Wotlk/wotlkObjectFixes.lua', module = 'QuestieWotlkObjectFixes', datatype = 'Object', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 3 },
  { file = 'Titan/titanReforgedQuestFixes.lua', module = 'TitanReforgedQuestFixes', datatype = 'Quest', dynamic = {'LoadQuests','LoadQuestOverrides'}, expansions = {['Wotlk']=true} },
  { file = 'Titan/titanReforgedNPCFixes.lua', module = 'TitanReforgedNpcFixes', datatype = 'Npc', dynamic = {'LoadNPCs','LoadNPCOverrides','LoadFactionNPCOverrides'}, expansions = {['Wotlk']=true} },
  { file = 'Titan/titanReforgedItemFixes.lua', module = 'TitanReforgedItemFixes', datatype = 'Item', dynamic = {'LoadItems','LoadItemOverrides'}, expansions = {['Wotlk']=true} },
  { file = 'Titan/titanReforgedObjectFixes.lua', module = 'TitanReforgedObjectFixes', datatype = 'Object', dynamic = {'LoadObjects'}, expansions = {['Wotlk']=true} },
  { file = 'Cata/cataQuestFixes.lua', module = 'CataQuestFixes', datatype = 'Quest', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 4 },
  { file = 'Cata/cataNPCFixes.lua', module = 'CataNpcFixes', datatype = 'Npc', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 4 },
  { file = 'Cata/cataItemFixes.lua', module = 'CataItemFixes', datatype = 'Item', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 4 },
  { file = 'Cata/cataObjectFixes.lua', module = 'CataObjectFixes', datatype = 'Object', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 4 },
  { file = 'MoP/mopQuestFixes.lua', module = 'MopQuestFixes', datatype = 'Quest', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 5 },
  { file = 'MoP/mopNPCFixes.lua', module = 'MopNpcFixes', datatype = 'Npc', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 5 },
  { file = 'MoP/mopItemFixes.lua', module = 'MopItemFixes', datatype = 'Item', static = {'Load'}, minExpansionOrder = 5 },
  { file = 'MoP/mopObjectFixes.lua', module = 'MopObjectFixes', datatype = 'Object', static = {'Load'}, dynamic = {'LoadFactionFixes'}, minExpansionOrder = 5 },
  { file = 'Sod/sodQuestFixes.lua', module = 'SeasonOfDiscovery', datatype = 'Quest', dynamic = {'LoadQuests','LoadFactionQuestFixes'}, expansions = {['Classic']=true} },
  { file = 'Sod/sodNPCFixes.lua', module = 'SeasonOfDiscovery', datatype = 'Npc', dynamic = {'LoadNPCs'}, expansions = {['Classic']=true} },
  { file = 'Sod/sodItemFixes.lua', module = 'SeasonOfDiscovery', datatype = 'Item', dynamic = {'LoadItems'}, expansions = {['Classic']=true} },
  { file = 'Sod/sodObjectFixes.lua', module = 'SeasonOfDiscovery', datatype = 'Object', dynamic = {'LoadObjects'}, expansions = {['Classic']=true} },
  { file = 'Sod/sodBaseQuests.lua', module = 'SeasonOfDiscovery', datatype = 'Quest', dynamic = {'LoadBaseQuests'}, expansions = {['Classic']=true}, generated = true },
  { file = 'Sod/sodBaseNPCs.lua', module = 'SeasonOfDiscovery', datatype = 'Npc', dynamic = {'LoadBaseNPCs'}, expansions = {['Classic']=true}, generated = true },
  { file = 'Sod/sodBaseItems.lua', module = 'SeasonOfDiscovery', datatype = 'Item', dynamic = {'LoadBaseItems'}, expansions = {['Classic']=true}, generated = true },
  { file = 'Sod/sodBaseObjects.lua', module = 'SeasonOfDiscovery', datatype = 'Object', dynamic = {'LoadBaseObjects'}, expansions = {['Classic']=true}, generated = true },
  { file = 'Shared/itemStartFixes.lua', module = 'QuestieItemStartFixes', datatype = 'Item', static = {'LoadAutomaticQuestStarts'}, options = {['noNewEntries']=true,['noOverwrites']=true}, generated = true },
}

local config = LibQuestieDB and LibQuestieDB.config or dofile("src/config.lua")
for _, spec in ipairs(config.ownedCorrections) do manifest[#manifest + 1] = spec end

if LibQuestieDB then
  LibQuestieDB.CorrectionManifest = manifest
end

return manifest
