let
  assay = import ../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "nfs-client" {
    hasNfsUtils = assay.eq (builtins.match ".*nfs-utils.*" src != null) true;
  }
