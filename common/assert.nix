# Common assertion and type checking utilities for the dotfiles
{...}: {
  # Check if a system is supported
  assertSupportedSystem = system: let
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  in
    assert (builtins.elem system supportedSystems); system;

  # Check if a string is not empty
  assertNonEmptyString = value:
    assert (builtins.typeOf value == "string" && value != ""); value;

  # Check if a string matches a pattern
  assertMatches = pattern: value:
    assert (builtins.match pattern value != null); value;

  # Check if an integer is within range
  assertIntInRange = min: max: value:
    assert (builtins.isInt value && value >= min && value <= max); value;

  # Check if a list contains only items of a given type
  assertListOfType = type: list:
    assert (builtins.isList list && builtins.all (item: builtins.typeOf item == type) list); list;

  # Check if an attribute set has required keys
  assertHasAttrs = requiredAttrs: attrs:
    assert (builtins.all (attr: builtins.hasAttr attr attrs) requiredAttrs); attrs;

  # Check if a list contains a specific element
  # Renamed from assertHasValue to assertElem for clarity and to avoid removing name argument from existing functions
  assertElem = elem: list:
    assert (builtins.isList list && builtins.elem elem list); elem;
}
