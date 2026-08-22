let
  assay = import ../../common/assay/default.nix;
  src = builtins.readFile ./configuration.nix;
in
  assay.suite "configuration" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 50) true;
    importsFleet = assay.eq (builtins.match ".*features/fleet/remote-access.*" src != null) true;
    importsNfsServer = assay.eq (builtins.match ".*features/storage/nfs-server.*" src != null) true;
  }
