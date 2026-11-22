Auctionator.Utilities.SuffixBonusIDs = {
[12688] = 1, --of Intellect
[12689] = 2, --of Spirit
[12690] = 3, --of Stamina
[12691] = 4, --of the Owl
[12718] = 5, --of the Eagle
[12719] = 6, --of the Whale
[12721] = 51, --of the Monkey
[12722] = 7, --of the Bear
[12723] = 8, --of the Gorilla
[12724] = 9, --of the Falcon
[12725] = 10, --of the Boar
[12726] = 11, --of the Wolf
[12727] = 12, --of the Tiger
[12728] = 13, --of Agility
[12729] = 14, --of Intellect
[12730] = 15, --of Spirit
[12731] = 16, --of Stamina
[12732] = 17, --of Strength
[12733] = 18, --of Power
[12734] = 19, --of Magic
[12735] = 20, --of Healing
[12736] = 21, --of Defense
[12737] = 22, --of Regeneration
[12738] = 23, --of Concentration
[12739] = 24, --of Eluding
[12740] = 25, --of Arcane Protection
[12741] = 26, --of Fire Protection
[12742] = 27, --of Frost Protection
[12743] = 28, --of Nature Protection
[12744] = 29, --of Shadow Protection
[12745] = 30, --of the Sorcerer
[12746] = 31, --of the Elder
[12747] = 32, --of the Channeler
[12748] = 33, --of the Physician
[12749] = 52, --of the Prophet
[12750] = 34, --of the Hierophant
[12751] = 35, --of the Bandit
[12752] = 36, --of the Beast
[12753] = 37, --of the Champion
[12754] = 38, --of the Defender
[12755] = 39, --of the Knight
[12756] = 40, --of Arcane Wrath
[12757] = 41, --of Fiery Wrath
[12758] = 42, --of Frozen Wrath
[12759] = 43, --of Holy Wrath
[12760] = 44, --of Nature's Wrath
[12761] = 45, --of Shadow Wrath
[12963] = 46, --of Arcane Resistance
[12986] = 48, --of Frost Resistance
[12987] = 49, --of Nature Resistance
[12988] = 50, --of Shadow Resistance
[12989] = 47, --of Fire Resistance
}
Auctionator.Utilities.SuffixLabels = {
"of Intellect",
"of Spirit",
"of Stamina",
"of the Owl",
"of the Eagle",
"of the Whale",
"of the Bear",
"of the Gorilla",
"of the Falcon",
"of the Boar",
"of the Wolf",
"of the Tiger",
"of Agility",
"of Intellect",
"of Spirit",
"of Stamina",
"of Strength",
"of Power",
"of Magic",
"of Healing",
"of Defense",
"of Regeneration",
"of Concentration",
"of Eluding",
"of Arcane Protection",
"of Fire Protection",
"of Frost Protection",
"of Nature Protection",
"of Shadow Protection",
"of the Sorcerer",
"of the Elder",
"of the Channeler",
"of the Physician",
"of the Hierophant",
"of the Bandit",
"of the Beast",
"of the Champion",
"of the Defender",
"of the Knight",
"of Arcane Wrath",
"of Fiery Wrath",
"of Frozen Wrath",
"of Holy Wrath",
"of Nature's Wrath",
"of Shadow Wrath",
"of Arcane Resistance",
"of Fire Resistance",
"of Frost Resistance",
"of Nature Resistance",
"of Shadow Resistance",
"of the Monkey",
"of the Prophet",
}

Auctionator.Utilities.SuffixesToLabel = {}
local itemID = 10259
local link = "item:10259::::::::14:1485::1:1:12753:1:28:5239:::::"
Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
  local baseName = C_Item.GetItemNameByID(itemID) .. " "
  local len = string.len(baseName .. " ")
  for bonusID, index in pairs(Auctionator.Utilities.SuffixBonusIDs) do
    local bonusLink = link:gsub("12753", bonusID)
    local bonusName = C_Item.GetItemNameByID(bonusLink):sub(len)
    Auctionator.Utilities.SuffixesToLabel[bonusName] = Auctionator.Utilities.SuffixLabels[index]
  end
end)
