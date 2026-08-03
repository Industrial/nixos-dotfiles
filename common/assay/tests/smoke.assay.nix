# Runnable smoke suite: string exprs so `nix eval --json` + assay run work.
# Values that are not strings are JSON-literal Nix expressions after export.
let
  assay = import ../default.nix;
in
  assay.suite "smoke" {
    add = assay.eq "builtins.add 1 1" "2";
    stringConcat = assay.eq "\"foo\" + \"bar\"" "\"foobar\"";
    listLength = assay.eq "builtins.length [ 1 2 3 ]" "3";
    typeOfInt = assay.eq "builtins.typeOf 42" "\"int\"";
    boolAnd = assay.eq "true && true" "true";
    nullLit = assay.eq "null" "null";
    attrGet = assay.eq "{ a = 1; }.a" "1";
    listConcat = assay.eq "[ 1 2 ] ++ [ 3 ]" "[ 1 2 3 ]";
    throwsBoom = assay.throws "builtins.throw \"boom\"" "boom";
    throwsType = assay.throws "builtins.add \"x\" 1" null;
    subsetSmoke = assay.subset "{ x = 1; y = 2; }" { x = 1; };
    hasAttrsSmoke = assay.hasAttrs "{ a = 1; b = 2; }" [ "a" "b" ];
  }
