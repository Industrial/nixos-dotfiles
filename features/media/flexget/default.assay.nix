# Colocated suite: flexget via the native services.flexget module.
# Asserts our declared options and the repo-owned YAML content; full
# module eval is covered by the mimir toplevel build gate.
let
  assay = import ./../../../common/assay/default.nix;
  opts.services.flexget = {
    enable = true;
    user = "flexget";
    homeDir = "/data/services/flexget";
    systemScheduler = false;
    config = builtins.readFile ./config/config.yml;
  };
  cfg = builtins.readFile ./config/config.yml;
in
  assay.suite "flexget" {
    enabled = assay.eq opts.services.flexget.enable true;
    homeDirOnNfsVolume =
      assay.eq
      opts.services.flexget.homeDir "/data/services/flexget";
    systemSchedulerOff = assay.eq opts.services.flexget.systemScheduler false;
    webuiPort5050 = assay.eq (builtins.match ".*port: 5050.*" cfg != null) true;
    targetsTransmissionRpc =
      assay.eq (builtins.match ".*127.0.0.1:9091.*" cfg != null) true;
    sourcesJackettTorznab =
      assay.eq (builtins.match ".*127.0.0.1:9117/torznab.*" cfg != null) true;
  }
