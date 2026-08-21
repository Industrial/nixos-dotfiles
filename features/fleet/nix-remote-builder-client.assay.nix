let
  assay = import ../../common/assay/default.nix;
  src = builtins.readFile ./nix-remote-builder-client.nix;
in
  assay.suite "nix-remote-builder-client" {
    enablesDistributed = assay.eq (builtins.match ".*distributedBuilds = true.*" src != null) true;
    targetsDrakkar = assay.eq (builtins.match ".*hostName = \"drakkar\".*" src != null) true;
    usesSubstitutes = assay.eq (builtins.match ".*builders-use-substitutes = true.*" src != null) true;
  }
