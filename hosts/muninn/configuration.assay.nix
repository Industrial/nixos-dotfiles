# Colocated suite for hosts/muninn/configuration.nix — evaluated selection, not source text.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  features = import ../../lib/features.nix {inherit (nixos) lib;};
  cfg = features.evalSelection {
    modules = [
      ./configuration.nix
      {disabledModules = [./disko.nix ./filesystems.nix ./hardware.nix];}
    ];
  };
  has = f: builtins.elem f (features.enabledFeatures cfg);
in
  assay.suite "configuration" {
    enablesFleetAccess = assay.eq (has "fleet.remote-access") true;
    enablesAi = assay.eq cfg.profiles.ai.enable true;
    # muninn is the monitoring standby for when mimir is down.
    monitoringStandby = assay.eq [(has "monitoring.prometheus") (has "monitoring.grafana")] [true true];
    noRelay = assay.eq (has "fleet.remote-desktop-relay") false;
    # Work laptop: no personal files, so no NFS client for mimir's /data.
    noNfsClient = assay.eq (has "storage.nfs-client") false;
  }
