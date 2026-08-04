# Meta-suite: assay DSL constructors produce the expected claim shapes.
let
  assay = import ./default.nix;
  dsl = import ./default.nix;
in
  assay.suite "assay-dsl" {
    suiteName = assay.eq (dsl.suite "s" { }).name "s";
    eqClaim = assay.eq (dsl.eq 1 1).claim "eq";
    throwsClaim = assay.eq (dsl.throws (_: true) ".*").claim "throws";
    subsetClaim = assay.eq (dsl.subset { a = 1; } { a = 1; }).claim "subset";
    hasAttrsClaim = assay.eq (dsl.hasAttrs { a = 1; } [ "a" ]).claim "hasAttrs";
    snapshotClaim = assay.eq (dsl.snapshot "n" 1).claim "snapshot";
    suiteHasCase = assay.hasAttrs (dsl.suite "shape" { one = dsl.eq 1 1; }) [ "name" "cases" ];
  }
