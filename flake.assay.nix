# Colocated suite for root flake.nix
let
  assay = import ./common/assay/default.nix;
  src = builtins.readFile ./flake.nix;
in
  assay.suite "flake" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 200) true;
    hasDrakkar = assay.eq (builtins.match ".*drakkar.*" src != null) true;
    hasDeployRs = assay.eq (builtins.match ".*deploy-rs.*" src != null) true;
    hasDeployNodes = assay.eq (builtins.match ".*genAttrs hosts mkDeployNode.*" src != null) true;
    hasNixIndexDatabase = assay.eq (builtins.match ".*nix-community/nix-index-database.*" src != null) true;
    hasNuScripts = assay.eq (builtins.match ".*nushell/nu_scripts.*" src != null) true;
  }
