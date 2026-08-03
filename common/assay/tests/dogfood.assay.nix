# Dogfood: exercise common/assert.nix via string exprs (JSON-exportable).
let
  assay = import ../default.nix;
  # Relative import from this file when evaluated as --file.
  al = "(import ${./../../assert.nix})";
in
  assay.suite "assert-concepts" {
    supportedSystemPasses = assay.eq "${al}.assertSupportedSystem \"x86_64-linux\"" "\"x86_64-linux\"";

    nonEmptyStringPasses = assay.eq "${al}.assertNonEmptyString \"hello\"" "\"hello\"";

    patternMatchPasses = assay.eq "${al}.assertMatches \"[a-z]+\" \"abc\"" "\"abc\"";

    intInRangePasses = assay.eq "${al}.assertIntInRange 0 10 5" "5";

    listOfTypePasses = assay.eq "${al}.assertListOfType \"string\" [ \"a\" \"b\" ]" "[ \"a\" \"b\" ]";

    hasAttrsPasses = assay.eq "${al}.assertHasAttrs [ \"a\" \"b\" ] { a = 1; b = 2; }" "{ a = 1; b = 2; }";

    elemPasses = assay.eq "${al}.assertElem \"x\" [ \"x\" \"y\" ]" "\"x\"";

    emptyStringThrows = assay.throws "${al}.assertNonEmptyString \"\"" null;

    unsupportedSystemThrows = assay.throws "${al}.assertSupportedSystem \"i686-linux\"" null;

    outOfRangeThrows = assay.throws "${al}.assertIntInRange 0 10 99" null;

    badPatternThrows = assay.throws "${al}.assertMatches \"^[0-9]+$\" \"abc\"" null;

    missingAttrThrows = assay.throws "${al}.assertHasAttrs [ \"missing\" ] {}" null;
  }
