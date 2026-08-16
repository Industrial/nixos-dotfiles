# Colocated suite for rust/tools/nixos-update-notifier/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "nixos-update-notifier" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
    usesBuildRustPackage = assay.eq (builtins.match ".*buildRustPackage.*" src != null) true;
  }
