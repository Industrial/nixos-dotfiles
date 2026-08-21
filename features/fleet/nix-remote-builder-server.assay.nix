let
  assay = import ../../common/assay/default.nix;
  src = builtins.readFile ./nix-remote-builder-server.nix;
in
  assay.suite "nix-remote-builder-server" {
    hasKvmFeature = assay.eq (builtins.match ".*kvm.*" src != null) true;
    hasSystemFeatures = assay.eq (builtins.match ".*system-features.*" src != null) true;
  }
