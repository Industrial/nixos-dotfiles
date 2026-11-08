-- src/support/_end.lua
--
-- Closes the support-data block and hands `QuestieLoader` back.

local _, LibQuestieDB = ...
LibQuestieDB.Support.Remove()
