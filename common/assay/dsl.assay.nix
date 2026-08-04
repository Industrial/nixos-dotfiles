# Meta-suite: assay DSL constructors produce the expected claim shapes.
let
  assay = import ./default.nix;
in
  assay.suite "assay-dsl" {
    suiteName = assay.eq "((import ${./default.nix}).suite \"s\" { }).name" "\"s\"";
    eqClaim = assay.eq "((import ${./default.nix}).eq 1 1).claim" "\"eq\"";
    throwsClaim = assay.eq "((import ${./default.nix}).throws (_: true) \".*\").claim" "\"throws\"";
    subsetClaim = assay.eq "((import ${./default.nix}).subset { a = 1; } { a = 1; }).claim" "\"subset\"";
    hasAttrsClaim = assay.eq "((import ${./default.nix}).hasAttrs { a = 1; } [ \"a\" ]).claim" "\"hasAttrs\"";
    snapshotClaim = assay.eq "((import ${./default.nix}).snapshot \"n\" 1).claim" "\"snapshot\"";
    suiteHasCase = assay.hasAttrs "(import ${./default.nix}).suite \"shape\" { one = (import ${./default.nix}).eq 1 1; }" [ "name" "cases" ];
  }
