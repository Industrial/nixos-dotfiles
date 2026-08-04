# Dogfood: exercise common/assert.nix with first-class values; throws stay as strings.
let
  assay = import ../default.nix;
  al = import ../../assert.nix;
in
  assay.suite "assert-concepts" {
    supportedSystemPasses = assay.eq (al.assertSupportedSystem "x86_64-linux") "x86_64-linux";

    nonEmptyStringPasses = assay.eq (al.assertNonEmptyString "hello") "hello";

    patternMatchPasses = assay.eq (al.assertMatches "[a-z]+" "abc") "abc";

    intInRangePasses = assay.eq (al.assertIntInRange 0 10 5) 5;

    listOfTypePasses = assay.eq (al.assertListOfType "string" [ "a" "b" ]) [ "a" "b" ];

    hasAttrsPasses = assay.eq (al.assertHasAttrs [ "a" "b" ] { a = 1; b = 2; }) { a = 1; b = 2; };

    elemPasses = assay.eq (al.assertElem "x" [ "x" "y" ]) "x";

    emptyStringThrows = assay.throws "(import ${./../../assert.nix}).assertNonEmptyString \"\"" null;

    unsupportedSystemThrows = assay.throws "(import ${./../../assert.nix}).assertSupportedSystem \"i686-linux\"" null;

    outOfRangeThrows = assay.throws "(import ${./../../assert.nix}).assertIntInRange 0 10 99" null;

    badPatternThrows = assay.throws "(import ${./../../assert.nix}).assertMatches \"^[0-9]+$\" \"abc\"" null;

    missingAttrThrows = assay.throws "(import ${./../../assert.nix}).assertHasAttrs [ \"missing\" ] {}" null;
  }
