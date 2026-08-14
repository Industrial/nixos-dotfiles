# Colocated suite for features/ai/hermes-agent/package.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
in
  assay.suite "package" {
    hasPname = assay.eq (builtins.match ".*pname = \"hermes-agent\".*" src != null) true;
    unsetsPythonPath =
      assay.eq (builtins.match ".*--unset-env\".*\"PYTHONPATH\".*" src != null) true;
  }
