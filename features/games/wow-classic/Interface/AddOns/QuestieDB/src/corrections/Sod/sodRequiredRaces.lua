-- Explicit SoD race masks, registered after the other SoD providers.
--
-- Why these rows exist
-- --------------------
-- Questie's Initialize applies SoD Quest/Npc corrections, infers requiredRaces from creature
-- starters, then calls MinimalInit for faction-specific corrections. QuestieDB's base Derived
-- Pass runs before SoD's Dynamic Corrections, so it cannot infer these SoD-added quests.
-- Against legacy Questie 92ab8206f8fa24fdbf772a0d2330abddbc78396a, all 25 rows below returned
-- zero here but a faction mask from Questie's compiled public reads. Alliance and Horde
-- personas agreed on the same 20 Alliance and five Horde masks; plain Vanilla had no gaps.
--
-- These are deliberately RETURNED-VALUE corrections, not claims about game availability.
-- In particular, 13 shipment quests infer Alliance from NPC 214101 before Horde's later
-- corrections replace their starters. Questie never recomputes that mask. Rune entries can
-- also use an enemy NPC as a map anchor rather than a friendly quest giver. Inferring from
-- final starters, or making the masks more plausible, would change the migration contract.
--
-- Representation and ownership
-- ----------------------------
-- Explicit data uses the normal Dynamic Correction lifecycle in both Source and Baked modes:
-- no extra inference pass, eager entity decoding, generated sidecar, or cross-entity cache.
-- These rows run after the other SoD providers; consumers still override them through
-- normal owner ranking.
-- Correcting gameplay meaning is a separate, evidence-backed data change, not this parity fix.
--
-- Updating this file
-- ------------------
-- The migration-parity-complete tag preserves the original inference-stage audit under
-- tools/differential/evidence/sod-required-races-before.tsv. New corrections should use game
-- evidence rather than treating that old compiler output as permanent truth.

local _, LibQuestieDB = ...
local flavor = LibQuestieDB.flavor

-- Vanilla's Baked artifact serves both Era and SoD. File presence is not seasonal admission.
if not flavor or flavor.expansion ~= "Classic" or not LibQuestieDB.CorrectionRegister.IsSodActive() then
  return
end

local registry = LibQuestieDB.Corrections
local questKeys = LibQuestieDB.Meta.Quest.keys
local raceKeys = LibQuestieDB.Enum.byExpansion[flavor.expansion].raceKeys

---@return table<integer, table<integer, integer>> rows Explicit requiredRaces values.
local function corrections()
  return {
    -- Shipment masks stay Alliance even on Horde: these reproduce pre-MinimalInit inference.
    [78611] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Waylaid Shipment
    [78612] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Full Shipment
    [78872] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Full Shipment
    [79100] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Waylaid Shipment
    [79101] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Full Shipment
    [79102] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Full Shipment
    [79103] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Full Shipment
    [80307] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Full Shipment
    [80308] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Full Shipment
    [80309] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Full Shipment
    [82307] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Full Shipment
    [82308] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Full Shipment
    [82309] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- A Full Shipment

    -- Other SoD additions. Legacy of Valor and Convocation also preserve questionable masks;
    -- the audit's goal is parity, not replacing starter inference with our own faction policy.
    [81764] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- The Mysterious Merchant
    [84124] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- Legacy of Valor
    [84329] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- The Convocation Assembles
    [90117] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- Seal of Martyrdom
    [90123] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- Rebuke
    [90125] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- Rebuke
    [90250] = { [questKeys.requiredRaces] = raceKeys.ALL_ALLIANCE }, -- Aeonas Whereabouts

    -- Endless Rage and Chronostatic Preservation inherit Horde from their NPC anchors.
    -- Do not flip them based on the player's faction or the represented discovery route.
    [90114] = { [questKeys.requiredRaces] = raceKeys.ALL_HORDE }, -- Endless Rage
    [90236] = { [questKeys.requiredRaces] = raceKeys.ALL_HORDE }, -- Chronostatic Preservation
    [90241] = { [questKeys.requiredRaces] = raceKeys.ALL_HORDE }, -- Fire Nova: Step 3
    [90242] = { [questKeys.requiredRaces] = raceKeys.ALL_HORDE }, -- Fire Nova: Step 4
    [90243] = { [questKeys.requiredRaces] = raceKeys.ALL_HORDE }, -- Fire Nova: Step 5
  }
end

-- Copied SoD providers occupy offsets 2 and 11/12. Keep our final field values after them
-- within the same owner, without changing registry phases or consumer precedence.
registry.RegisterRuntimeCorrection(registry.OWNER, "Quest", "Sod:sodRequiredRaces",
  corrections, registry.loadOrder.SoDDynamic + 20)
