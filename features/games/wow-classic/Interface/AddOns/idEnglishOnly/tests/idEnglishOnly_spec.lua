-- busted spec for idEnglishOnly.lua. Run from the addon folder: busted tests/idEnglishOnly_spec.lua
local filter, event
local function hidden(msg) return filter(nil, "CHAT_MSG_CHANNEL", msg) == true end

before_each(function()
  _G.ChatFrameUtil = { AddMessageEventFilter = function(e, f) event, filter = e, f end }
  dofile("idEnglishOnly.lua")
end)

describe("idEnglishOnly", function()
  it("filters chat channels only", function()
    assert.are.equal("CHAT_MSG_CHANNEL", event)
  end)

  it("uses the older registry name on clients without ChatFrameUtil", function()
    _G.ChatFrameUtil = nil
    local got
    _G.ChatFrame_AddMessageEventFilter = function(e) got = e end
    dofile("idEnglishOnly.lua")
    assert.are.equal("CHAT_MSG_CHANNEL", got)
  end)

  local english = {
    "LFM DM east, need tank and heals",
    "WTS |cff1eff00|Hitem:2589::::::::40:::::|h[Linen Cloth]|h|r 5g per stack, pst",
    "anyone up for the Riverglades quests? inv me",
    "LF healer for Krol'dok, then UBRS",
    "selling iron ore cheap, whisper me",
    "does anyone know where Broken Tooth spawns",
    "the das boot movie is great",                         -- one foreign-looking word is not enough
    "WTB |cff0070dd|Hitem:1::::::::40:::::|h[Großer Helm]|h|r",  -- a link in the sender's language
    "{skull} pull at 3",
  }
  for _, m in ipairs(english) do
    it("keeps English: " .. m:gsub("|", "!"), function() assert.is_false(hidden(m)) end)
  end

  local foreign = {
    "Suche Gruppe für BRD",          -- umlaut
    "suche noch heiler für dm",      -- umlaut
    "suche noch einen tank",         -- no accents: suche, noch
    "je cherche un groupe pour dm",  -- je, cherche
    "hola alguien para dm",          -- hola, alguien, para
    "Ищу группу в БРД",              -- Cyrillic
    "ik zoek een groep",             -- ik, zoek, een
    "szukam kto idzie",              -- szukam, kto
    "¿alguien?",                     -- ¿ is not ASCII
  }
  for _, m in ipairs(foreign) do
    it("hides: " .. m, function() assert.is_true(hidden(m)) end)
  end
end)
