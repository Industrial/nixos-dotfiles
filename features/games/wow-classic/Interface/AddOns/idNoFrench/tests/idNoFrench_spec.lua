-- busted spec for idNoFrench.lua. Run from the addon folder: busted tests/idNoFrench_spec.lua
local filter, event
local function hidden(msg) return filter(nil, "CHAT_MSG_CHANNEL", msg) == true end

before_each(function()
  _G.ChatFrameUtil = { AddMessageEventFilter = function(e, f) event, filter = e, f end }
  dofile("idNoFrench.lua")
end)

describe("idNoFrench", function()
  it("filters chat channels only", function()
    assert.are.equal("CHAT_MSG_CHANNEL", event)
  end)

  it("uses the older registry name on clients without ChatFrameUtil", function()
    _G.ChatFrameUtil = nil
    local got
    _G.ChatFrame_AddMessageEventFilter = function(e) got = e end
    dofile("idNoFrench.lua")
    assert.are.equal("CHAT_MSG_CHANNEL", got)
  end)

  local english = {
    "LFM DM east, need tank and heals",
    "WTS |cff1eff00|Hitem:2589::::::::40:::::|h[Linen Cloth]|h|r 5g per stack, pst",
    "anyone up for the Riverglades quests? inv me",
    "LF healer for Krol'dok, then UBRS",
    "selling iron ore cheap, whisper me",
    "does anyone know where Broken Tooth spawns",
    "need a tank for this place, any class",          -- place, table, possible are French too
    "is it possible to solo the table event",
    "my cache of gold is in the foyer lol",           -- English words that are French loanwords
    "WTB |cff0070dd|Hitem:1::::::::40:::::|h[Chapeau Élégant]|h|r",  -- a link in the sender's language
    "{skull} pull at 3",
    "ok",
    "LFG",
    "omw",
  }
  for _, m in ipairs(english) do
    it("keeps English: " .. m:gsub("|", "!"), function() assert.is_false(hidden(m)) end)
  end

  local french = {
    "je cherche un groupe pour dm",
    "salut",
    "bonjour tout le monde",
    "quelqu'un pour aider sur une quête ?",
    "merci beaucoup",
    "c'est pas grave, on recommence",
    "vous avez besoin d'un soigneur ?",
    "il faut tuer le boss avant",
    "ça marche, j'arrive",
    "garçon",                                          -- ç alone, on a short line
  }
  for _, m in ipairs(french) do
    it("hides French: " .. m, function() assert.is_true(hidden(m)) end)
  end

  local otherLanguages = {
    "Suche Gruppe für BRD",          -- German
    "suche noch einen tank",
    "hola alguien para dm",          -- Spanish
    "Ищу группу в БРД",              -- Russian
    "ik zoek een groep",             -- Dutch
    "cerco gruppo per la quest",     -- Italian
  }
  for _, m in ipairs(otherLanguages) do
    it("shows other languages: " .. m, function() assert.is_false(hidden(m)) end)
  end
end)
