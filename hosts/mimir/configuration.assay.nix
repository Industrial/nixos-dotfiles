let
  assay = import ../../common/assay/default.nix;
  src = builtins.readFile ./configuration.nix;
in
  assay.suite "configuration" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 50) true;
    importsFleet = assay.eq (builtins.match ".*features/fleet/remote-access.*" src != null) true;
    importsNfsServer = assay.eq (builtins.match ".*features/storage/nfs-server.*" src != null) true;

    # mimir is the always-on host, so it carries the RustDesk signal/relay for
    # the fleet. The other three hosts must not import this.
    importsRemoteDesktopRelay = assay.eq (builtins.match ".*features/fleet/remote-desktop-relay.*" src != null) true;
  }
