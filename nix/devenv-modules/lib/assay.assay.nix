# Colocated suite for nix/devenv-modules/lib/assay.nix.
#
# lib/assay.nix re-exports the pinned Industrial/assay claim DSL that the vendored feature
# suites are written against. The runner interprets claim objects by shape, so the shapes are
# the contract: if the pinned DSL drifted from the one common/assay/default.nix provides, the
# same `assay.eq` would mean different things in different suites of one repo. Checked with
# the in-repo DSL, so the module is not vouching for itself.
let
  assay = import ../../../common/assay/default.nix;
  pinned = import ./assay.nix;
  common = assay;
  sample = dsl: {
    eq = dsl.eq 1 2;
    throws = dsl.throws "expr" "pattern";
    subset = dsl.subset {a = 1;} {a = 1;};
    hasAttrs = dsl.hasAttrs {a = 1;} ["a"];
    suite = dsl.suite "s" {c = dsl.eq 1 1;};
  };
in
  assay.suite "devenv-modules-lib-assay" {
    exportsDsl =
      assay.eq (builtins.attrNames pinned)
      ["drv" "eq" "forces" "hasAttrs" "module" "pathInfo" "snapshot" "subset" "suite" "throws"];
    eqClaimShape = assay.eq (pinned.eq 1 2) {
      claim = "eq";
      actual = 1;
      expected = 2;
    };
    throwsClaimShape = assay.eq (pinned.throws "expr" "pattern") {
      claim = "throws";
      expr = "expr";
      pattern = "pattern";
    };
    suiteShape = assay.eq (pinned.suite "s" {}) {
      name = "s";
      cases = {};
    };
    agreesWithCommonDsl = assay.eq (sample pinned) (sample common);
  }
