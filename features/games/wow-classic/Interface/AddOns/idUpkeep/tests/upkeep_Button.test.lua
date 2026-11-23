local Button = require("src.modules.automation.upkeep.Button")
local fakeButton
fakeButton = function()
  local attrs = { }
  return {
    attrs = attrs,
    SetAttribute = function(self, name, value)
      attrs[name] = value
    end
  }
end
return describe("Upkeep.Button", function()
  describe("attrsFor", function()
    it("maps a self-cast spell", function()
      local a = Button.attrsFor({
        kind = "spell",
        spell = "Arcane Intellect"
      })
      assert.are.equal("spell", a.type)
      assert.are.equal("Arcane Intellect", a.spell)
      return assert.is_nil(a.unit)
    end)
    it("maps a spell cast on a unit", function()
      local a = Button.attrsFor({
        kind = "spell",
        spell = "Mark of the Wild",
        unit = "party2"
      })
      return assert.are.equal("party2", a.unit)
    end)
    it("maps an item, prefixed as the secure API wants", function()
      local a = Button.attrsFor({
        kind = "item",
        item = 8950
      })
      assert.are.equal("item", a.type)
      return assert.are.equal("item:8950", a.item)
    end)
    it("maps a weapon item to its slot", function()
      local a = Button.attrsFor({
        kind = "item",
        item = 8928,
        targetSlot = 16
      })
      return assert.are.equal(16, a["target-slot"])
    end)
    it("turns a shapeshift-cancelling step into a macro", function()
      local a = Button.attrsFor({
        kind = "spell",
        spell = "Mark of the Wild",
        cancelForm = true
      })
      assert.are.equal("macro", a.type)
      assert.are.equal("/cancelform\n/cast Mark of the Wild", a.macrotext)
      return assert.is_nil(a.spell)
    end)
    it("carries a ready-made macro through", function()
      local a = Button.attrsFor({
        kind = "macro",
        macrotext = "/use [combat] item:1; item:2"
      })
      assert.are.equal("macro", a.type)
      return assert.are.equal("/use [combat] item:1; item:2", a.macrotext)
    end)
    it("returns nothing for nil, which means `clear the button`", function()
      return assert.are.same({ }, Button.attrsFor(nil))
    end)
    return it("returns nothing for a step shape it cannot perform", function()
      assert.are.same({ }, Button.attrsFor({
        kind = "spell"
      }))
      assert.are.same({ }, Button.attrsFor({
        kind = "item"
      }))
      return assert.are.same({ }, Button.attrsFor({
        kind = "nonsense"
      }))
    end)
  end)
  describe("macroText", function()
    it("cancels the form before casting on a party member", function()
      local text = Button.macroText({
        kind = "spell",
        spell = "Mark of the Wild",
        unit = "party1",
        cancelForm = true
      })
      return assert.are.equal("/cancelform\n/cast [@party1] Mark of the Wild", text)
    end)
    it("uses the item and then the slot it applies to", function()
      local text = Button.macroText({
        kind = "item",
        item = 8928,
        targetSlot = 16,
        cancelForm = true
      })
      return assert.are.equal("/cancelform\n/use item:8928\n/use 16", text)
    end)
    it("writes no /cancelform when the step does not need one", function()
      local text = Button.macroText({
        kind = "macro",
        macrotext = "/use item:1"
      })
      return assert.is_nil(text:find("cancelform", 1, true))
    end)
    return it("is nil for a step with nothing to do", function()
      assert.is_nil(Button.macroText({
        kind = "spell"
      }))
      return assert.is_nil(Button.macroText(nil))
    end)
  end)
  describe("writing to a button", function()
    it("writes the mapped attributes", function()
      local b = fakeButton()
      Button.write(b, "", {
        kind = "spell",
        spell = "Fortitude"
      })
      assert.are.equal("spell", b.attrs.type)
      return assert.are.equal("Fortitude", b.attrs.spell)
    end)
    it("clears every attribute a previous step left behind", function()
      local b = fakeButton()
      Button.write(b, "", {
        kind = "item",
        item = 8950,
        targetSlot = 16
      })
      Button.write(b, "", {
        kind = "spell",
        spell = "Fortitude"
      })
      assert.is_nil(b.attrs.item)
      assert.is_nil(b.attrs["target-slot"])
      return assert.are.equal("Fortitude", b.attrs.spell)
    end)
    it("clears everything for a nil step", function()
      local b = fakeButton()
      Button.write(b, "", {
        kind = "spell",
        spell = "Fortitude",
        unit = "party1"
      })
      Button.write(b, "", nil)
      local _list_0 = Button.SECURE_ATTRS
      for _index_0 = 1, #_list_0 do
        local name = _list_0[_index_0]
        assert.is_nil(b.attrs[name])
      end
    end)
    it("uses the left-button-only suffix when asked", function()
      local b = fakeButton()
      Button.write(b, "1", {
        kind = "spell",
        spell = "Fortitude"
      })
      assert.are.equal("spell", b.attrs.type1)
      return assert.is_nil(b.attrs.type)
    end)
    it("reports failure for a frame that cannot take attributes", function()
      assert.is_false(Button.write(nil, "", {
        kind = "spell",
        spell = "x"
      }))
      return assert.is_false(Button.write({ }, "", {
        kind = "spell",
        spell = "x"
      }))
    end)
    return it("writes the same step to every target", function()
      local a, b = fakeButton(), fakeButton()
      local written = Button.writeAll({
        {
          a,
          ""
        },
        {
          b,
          "1"
        }
      }, {
        kind = "spell",
        spell = "Fortitude"
      })
      assert.are.equal(2, written)
      assert.are.equal("Fortitude", a.attrs.spell)
      return assert.are.equal("Fortitude", b.attrs.spell1)
    end)
  end)
  return describe("isEmpty", function()
    it("is true for a step that would do nothing", function()
      assert.is_true(Button.isEmpty(nil))
      return assert.is_true(Button.isEmpty({
        kind = "spell"
      }))
    end)
    return it("is false for a step that would act", function()
      assert.is_false(Button.isEmpty({
        kind = "spell",
        spell = "Fortitude"
      }))
      return assert.is_false(Button.isEmpty({
        kind = "macro",
        macrotext = "/use item:1"
      }))
    end)
  end)
end)
