# Colocated suite for common/assay/default.nix — the claim DSL every other suite is written in.
#
# The runner dispatches on the `claim` tag and reads fixed field names, so a constructor that
# renamed a field or dropped the tag would turn every suite built on it into a runner error or,
# worse, a claim compared against the wrong value. Each constructor's output shape is pinned here
# by evaluating it, not by reading its source.
let
  assay = import ./default.nix;
in
  assay.suite "assay" {
    suiteCarriesNameAndCases = assay.eq (assay.suite "s" {c = 1;}) {
      name = "s";
      cases = {c = 1;};
    };

    eqKeepsActualAndExpected = assay.eq (assay.eq 1 2) {
      claim = "eq";
      actual = 1;
      expected = 2;
    };

    subsetKeepsActualAndExpected = assay.eq (assay.subset {a = 1;} {}) {
      claim = "subset";
      actual = {a = 1;};
      expected = {};
    };

    hasAttrsKeepsActualAndNames = assay.eq (assay.hasAttrs {a = 1;} ["a"]) {
      claim = "hasAttrs";
      actual = {a = 1;};
      attrs = ["a"];
    };

    # throws and forces carry an expression STRING: the runner re-evaluates it in isolation to
    # observe a failure, which a value already forced here could not show.
    throwsKeepsExprStringAndPattern = assay.eq (assay.throws "1" "boom") {
      claim = "throws";
      expr = "1";
      pattern = "boom";
    };
    forcesKeepsExprStringAndPaths = assay.eq (assay.forces "x" ["a.b"]) {
      claim = "forces";
      expr = "x";
      paths = ["a.b"];
    };

    snapshotKeepsNameAndExpr = assay.eq (assay.snapshot "n" "e") {
      claim = "snapshot";
      name = "n";
      expr = "e";
    };

    # module / drv / pathInfo pass their arguments through, tagged.
    moduleTagsItsArgs = assay.eq (assay.module {x = 1;}) {
      claim = "module";
      x = 1;
    };
    drvTagsItsArgs = assay.eq (assay.drv {x = 1;}) {
      claim = "drv";
      x = 1;
    };
    pathInfoTagsItsArgs = assay.eq (assay.pathInfo {x = 1;}) {
      claim = "pathInfo";
      x = 1;
    };
  }
