local json = dofile("tools/itemtable/json.lua")
return describe("itemtable json encoder", function()
  describe("determinism", function()
    it("sorts object keys regardless of insertion order", function()
      local a = {
        zebra = 1,
        alpha = 2,
        mango = 3
      }
      local b = {
        mango = 3,
        zebra = 1,
        alpha = 2
      }
      assert.are.equal(json.encode(a), json.encode(b))
      return assert.are.equal('{"alpha":2,"mango":3,"zebra":1}', json.encode(a))
    end)
    it("is stable across repeated encodes of a large map", function()
      local big = { }
      for i = 1, 200 do
        big["key" .. tostring(i)] = i
      end
      return assert.are.equal(json.encode(big), json.encode(big))
    end)
    return it("sorts nested keys too", function()
      return assert.are.equal('{"outer":{"a":2,"b":1}}', json.encode({
        outer = {
          b = 1,
          a = 2
        }
      }))
    end)
  end)
  describe("scalars", function()
    it("writes integers without a decimal point", function()
      assert.are.equal('{"n":5}', json.encode({
        n = 5
      }))
      assert.are.equal('{"n":-17}', json.encode({
        n = -17
      }))
      return assert.are.equal('{"n":0}', json.encode({
        n = 0
      }))
    end)
    it("writes floats stably", function()
      assert.are.equal(json.encode({
        n = 1 / 3
      }), json.encode({
        n = 1 / 3
      }))
      return assert.is_truthy(json.encode({
        n = 1.5
      }):find("1.5", 1, true))
    end)
    it("refuses non-finite numbers rather than emitting invalid JSON", function()
      assert.has_error(function()
        return json.encode({
          n = math.huge
        })
      end)
      return assert.has_error(function()
        return json.encode({
          n = 0 / 0
        })
      end)
    end)
    it("encodes booleans and strings", function()
      assert.are.equal('{"t":true}', json.encode({
        t = true
      }))
      return assert.are.equal('{"s":"hi"}', json.encode({
        s = "hi"
      }))
    end)
    it("escapes quotes, backslashes and control characters", function()
      assert.are.equal('{"s":"a\\"b"}', json.encode({
        s = 'a"b'
      }))
      assert.are.equal('{"s":"a\\\\b"}', json.encode({
        s = "a\\b"
      }))
      assert.are.equal('{"s":"a\\nb"}', json.encode({
        s = "a\nb"
      }))
      return assert.are.equal('{"s":"a\\tb"}', json.encode({
        s = "a\tb"
      }))
    end)
    return it("refuses types with no JSON representation", function()
      return assert.has_error(function()
        return json.encode({
          f = print
        })
      end)
    end)
  end)
  describe("structure", function()
    it("encodes arrays as arrays", function()
      return assert.are.equal("[1,2,3]", json.encode({
        1,
        2,
        3
      }))
    end)
    it("encodes an empty table as an empty array", function()
      return assert.are.equal("[]", json.encode({ }))
    end)
    it("encodes a nested empty table as an empty array", function()
      return assert.are.equal('{"a":[]}', json.encode({
        a = { }
      }))
    end)
    it("pretty-prints with two-space indent when asked", function()
      local out = json.encode({
        a = 1,
        b = {
          2
        }
      }, true)
      assert.is_truthy(out:find("\n", 1, true))
      return assert.is_truthy(out:find('  "a": 1', 1, true))
    end)
    return it("round-trips through the schema emitter without changing", function()
      local validate = dofile("tools/itemtable/validate.lua")
      local first = json.encode(validate.toJsonSchema(), true)
      local second = json.encode(validate.toJsonSchema(), true)
      return assert.are.equal(first, second)
    end)
  end)
  return describe("decoding", function()
    it("round-trips a metrics-shaped document", function()
      local original = {
        build = "1.60.1.70790",
        domains = {
          Consumable = {
            status = "active",
            classified = 8,
            unclassifiedCount = 0,
            sets = 20
          },
          Tradeskill = {
            status = "not-started",
            reason = "later"
          }
        }
      }
      return assert.are.same(original, json.decode(json.encode(original, true)))
    end)
    it("decodes scalars", function()
      assert.are.equal(5, json.decode('{"n":5}').n)
      assert.are.equal(-17.5, json.decode('{"n":-17.5}').n)
      assert.is_true(json.decode('{"b":true}').b)
      assert.is_false(json.decode('{"b":false}').b)
      return assert.are.equal("hi", json.decode('{"s":"hi"}').s)
    end)
    it("decodes arrays and nesting", function()
      assert.are.same({
        1,
        2,
        3
      }, json.decode("[1,2,3]"))
      return assert.are.same({
        a = {
          b = {
            1
          }
        }
      }, json.decode('{"a":{"b":[1]}}'))
    end)
    it("decodes empty containers", function()
      assert.are.same({ }, json.decode("{}"))
      return assert.are.same({ }, json.decode("[]"))
    end)
    it("handles escapes our encoder emits", function()
      assert.are.equal("a\nb", json.decode('{"s":"a\\nb"}').s)
      assert.are.equal('a"b', json.decode('{"s":"a\\"b"}').s)
      return assert.are.equal("a\\b", json.decode('{"s":"a\\\\b"}').s)
    end)
    it("tolerates whitespace and indentation", function()
      return assert.are.equal(1, json.decode('{\n  "a": 1\n}').a)
    end)
    it("reports a position instead of throwing on malformed input", function()
      local value, err = json.decode("{bogus}")
      assert.is_nil(value)
      return assert.is_string(err)
    end)
    it("rejects a non-string input", function()
      local value, err = json.decode(42)
      assert.is_nil(value)
      return assert.are.equal("not a string", err)
    end)
    return it("reports a missing file rather than throwing", function()
      local value, err = json.decodeFile("/nonexistent/metrics.json")
      assert.is_nil(value)
      return assert.is_truthy(err:find("cannot open", 1, true))
    end)
  end)
end)
