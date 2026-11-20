# Colocated suite for common/assert.nix.
#
# Every helper there is a guard: it hands its value back when the check holds and fails
# evaluation when it does not. Both halves are claims — a guard that never fails is a no-op, and
# one that fails on good input breaks every caller — so each helper is called both ways.
let
  assay = import ./assay/default.nix;
  a = import ./assert.nix;
  # `assert` failures surface as "assertion '<expr>' failed".
  fails = call: assay.throws "(import ${toString ./assert.nix}).${call}" "assertion";
in
  assay.suite "assert" {
    supportedSystemPassesThrough = assay.eq (a.assertSupportedSystem "aarch64-darwin") "aarch64-darwin";
    unsupportedSystemFails = fails ''assertSupportedSystem "riscv64-linux"'';

    nonEmptyStringPassesThrough = assay.eq (a.assertNonEmptyString "x") "x";
    emptyStringFails = fails ''assertNonEmptyString ""'';
    nonStringFails = fails "assertNonEmptyString 1";

    matchingValuePassesThrough = assay.eq (a.assertMatches "[a-z]+" "abc") "abc";
    # builtins.match anchors the whole string, so a partial match is a failure.
    partialMatchFails = fails ''assertMatches "[a-z]+" "abc1"'';

    intInRangePassesThrough = assay.eq (a.assertIntInRange 1 3 3) 3;
    intOutOfRangeFails = fails "assertIntInRange 1 3 4";
    nonIntFails = fails ''assertIntInRange 1 3 "2"'';

    listOfTypePassesThrough = assay.eq (a.assertListOfType "int" [1 2]) [1 2];
    mixedListFails = fails ''assertListOfType "int" [1 "2"]'';

    hasAttrsPassesThrough = assay.eq (a.assertHasAttrs ["x"] {x = 1;}) {x = 1;};
    missingAttrFails = fails ''assertHasAttrs ["x" "y"] {x = 1;}'';

    # Returns the element, not the list.
    elemReturnsTheElement = assay.eq (a.assertElem 2 [1 2]) 2;
    absentElemFails = fails "assertElem 3 [1 2]";
  }
