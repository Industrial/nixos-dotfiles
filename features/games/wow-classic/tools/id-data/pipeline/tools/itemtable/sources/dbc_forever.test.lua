-- The adapter against Forever's client vocabulary: numbers where the fixtures
-- had names. Every row below has the shape wago.tools' CSV export gives for
-- build 1.60.1.71037; the comments name the real item each mirrors.
local dbc = dofile("tools/itemtable/sources/dbc.lua")
local validate = dofile("tools/itemtable/validate.lua")

local function model(spellEffects, extra)
  local t = {
    item = { { ID = "1", ClassID = "0", SubclassID = "5" } },
    itemSparse = { { ID = "1", Display_lang = "Test Item", OverallQualityID = "1", ItemLevel = "5", Stackable = "20" } },
    spell = { { ID = "100", Name_lang = "Use" }, { ID = "200", Name_lang = "Triggered" } },
    itemEffect = { { ParentItemID = "1", SpellID = "100", TriggerType = "0", Charges = "-1" } },
    spellEffect = spellEffects,
  }
  for k, v in pairs(extra or {}) do t[k] = v end
  local doc = dbc.toModel(t, { build = "test" })
  return doc
end

local function effectsOf(doc, spellId)
  local out = {}
  for _, se in ipairs(doc.spellEffects) do
    if se.spellId == spellId then out[#out + 1] = se end
  end
  return out
end

local function row(spell, index, effect, aura, base, misc, trigger)
  return { SpellID = tostring(spell), EffectIndex = tostring(index), Effect = tostring(effect),
           EffectAura = tostring(aura), EffectBasePoints = tostring(base or 0),
           EffectMiscValue_0 = tostring(misc or 0), EffectTriggerSpell = tostring(trigger or 0) }
end

describe("itemtable dbc source on Forever's vocabulary", function()
  it("names consumable subclass 5 Food (Tough Jerky is 0/5)", function()
    local doc = model({ row(100, 0, 6, 84, 17) })
    assert.are.equal("Food", doc.items[1].subclass)
  end)

  it("names food's MOD_REGEN (84) and drink's MOD_POWER_REGEN (85) as the periodic restores", function()
    assert.are.equal("PERIODIC_HEAL", effectsOf(model({ row(100, 0, 6, 84, 17) }), 100)[1].auraType)
    assert.are.equal("PERIODIC_ENERGIZE", effectsOf(model({ row(100, 0, 6, 85, 17) }), 100)[1].auraType)
  end)

  it("names an effect with no aura by the effect (an instant potion is effect 10, HEAL)", function()
    assert.are.equal("HEAL", effectsOf(model({ row(100, 0, 10, 0, 70) }), 100)[1].auraType)
    assert.are.equal("ENERGIZE", effectsOf(model({ row(100, 0, 30, 0, 140) }), 100)[1].auraType)
  end)

  it("reads MOD_STAT's misc by the unit-stat enum (Elixir of Agility is misc 1)", function()
    local se = effectsOf(model({ row(100, 0, 6, 29, 4, 1) }), 100)[1]
    assert.are.equal("MOD_STAT", se.auraType)
    assert.are.equal("AGILITY", se.statType)
    assert.are.equal("STAMINA", effectsOf(model({ row(100, 0, 6, 29, 4, 2) }), 100)[1].statType)
  end)

  it("names physical-school MOD_RESISTANCE as ARMOR", function()
    local se = effectsOf(model({ row(100, 0, 6, 22, 100, 1) }), 100)[1]
    assert.are.equal("ARMOR", se.statType)
  end)

  it("follows a TRIGGER_SPELL (64) so Nutritious Food carries Food's restore", function()
    local doc = model({ row(100, 0, 64, 0, 0, 0, 200), row(200, 0, 6, 84, 58) })
    local names = {}
    for _, se in ipairs(effectsOf(doc, 100)) do names[#names + 1] = tostring(se.auraType) end
    assert.is_truthy(table.concat(names, ","):find("PERIODIC_HEAL", 1, true))
  end)

  it("follows a periodic trigger (227) so the Well Fed stat reaches the food", function()
    local doc = model({ row(100, 1, 6, 227, 3, 0, 200), row(200, 0, 6, 29, 1, 2) })
    local found = false
    for _, se in ipairs(effectsOf(doc, 100)) do
      if se.auraType == "MOD_STAT" and se.statType == "STAMINA" then found = true end
    end
    assert.is_true(found)
  end)

  it("names a weapon enchant's kind and strength from SpellItemEnchantment", function()
    local doc = model({ row(100, 0, 54, 0, 1800, 40) }, {
      spellItemEnchantment = { { ID = "40", Name_lang = "Sharpened +2", EffectPointsMin_0 = "2" } },
    })
    local se = effectsOf(doc, 100)[1]
    assert.are.equal("ENCHANT_HELD_ITEM", se.auraType)
    assert.are.equal("SHARPEN", se.enchantKind)
    assert.are.equal(2, se.amount)
  end)

  it("tells the four weapon-buff kinds apart", function()
    local kinds = {}
    for id, name in pairs({ [19] = "Weighted +2", [2623] = "Minor Wizard Oil", [2624] = "Minor Mana Oil", [25] = "Shadow Oil" }) do
      local doc = model({ row(100, 0, 54, 0, 1800, id) }, {
        spellItemEnchantment = { { ID = tostring(id), Name_lang = name, EffectPointsMin_0 = "1" } },
      })
      kinds[name] = effectsOf(doc, 100)[1].enchantKind
    end
    assert.are.same({ ["Weighted +2"] = "WEIGHT", ["Minor Wizard Oil"] = "WIZARD_OIL",
                      ["Minor Mana Oil"] = "MANA_OIL", ["Shadow Oil"] = "OTHER" }, kinds)
  end)

  it("reads the conjured flag (Flags_0 bit 2) that healthstones and conjured water carry", function()
    local doc = model({ row(100, 0, 10, 0, 500) })
    assert.is_false(doc.items[1].conjured)
    doc = model({ row(100, 0, 10, 0, 500) }, {
      itemSparse = { { ID = "1", Display_lang = "Healthstone", OverallQualityID = "1", ItemLevel = "5", Stackable = "1", Flags_0 = "66" } },
    })
    assert.is_true(doc.items[1].conjured)
  end)

  it("names who a buff lands on: self, one friend, the caster's group", function()
    local targets = {}
    for code, want in pairs({ [1] = "SELF", [21] = "FRIEND", [57] = "FRIEND", [56] = "GROUP", [20] = "GROUP", [153] = "GROUP", [6] = "ENEMY" }) do
      local r = row(100, 0, 6, 29, 4, 3)
      r.ImplicitTarget_0 = tostring(code)
      targets[code] = { want, effectsOf(model({ r }), 100)[1].target }
    end
    for code, pair in pairs(targets) do
      assert.are.equal(pair[1], pair[2], "ImplicitTarget " .. code)
    end
  end)

  it("links a conjure to the item it makes (Conjure Water makes 5350)", function()
    local r = row(100, 0, 24, 0, 2)
    r.EffectItemType = "5350"
    local se = effectsOf(model({ r }), 100)[1]
    assert.are.equal("CREATE_ITEM", se.effect)
    assert.are.equal(5350, se.createdItem)
  end)

  it("reads passive, hidden and channeled from the spell's attributes", function()
    local doc = model({ row(100, 0, 6, 29, 4, 3) }, {
      spellMisc = {
        { SpellID = "100", Attributes_0 = "262544", Attributes_1 = "16", DurationIndex = "0" },
        { SpellID = "200", Attributes_0 = "0", Attributes_1 = "139268", DurationIndex = "0" },
      },
    })
    local byId = {}
    for _, sp in ipairs(doc.spells) do byId[sp.id] = sp end
    assert.is_true(byId[100].passive) -- Weaponmaster: DO_NOT_DISPLAY
    assert.is_true(byId[200].channeled) -- Eagle Eye
  end)

  it("produces a document the model validator accepts", function()
    local doc = model({ row(100, 0, 64, 0, 0, 0, 200), row(200, 0, 6, 84, 58), row(100, 1, 54, 0, 1800, 40) }, {
      spellItemEnchantment = { { ID = "40", Name_lang = "Sharpened +2", EffectPointsMin_0 = "2" } },
    })
    local ok, errors = validate.validate(doc)
    assert.is_true(ok, errors and errors[1] and (errors[1].path .. ": " .. errors[1].message) or nil)
  end)
end)
