# Colocated suite: transmission via the native services.transmission module.
# Asserts our declared settings (the values the module merges into
# settings.json on every start), and, evaluated against the real NixOS option
# tree, that tmpfiles alone makes the directories the unit bind-mounts (GH-219).
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  directoryPath = "/data/services/transmission";
  opts = {
    services.transmission = {
      enable = true;
      home = directoryPath;
      group = "data";
      performanceNetParameters = true;
      openPeerPorts = true;
      settings = {
        download-dir = "${directoryPath}/downloads";
        incomplete-dir = "${directoryPath}/downloads/incomplete";
        incomplete-dir-enabled = true;
        rpc-bind-address = "0.0.0.0";
        rpc-host-whitelist-enabled = false;
        rpc-whitelist-enabled = false;
        start-added-torrents = true;
        umask = 2;
      };
    };
  };
  s = opts.services.transmission.settings;

  cfg = (nixos.evalSystem {modules = [./default.nix];}).config;
  dirs = [directoryPath "${directoryPath}/downloads" "${directoryPath}/downloads/incomplete"];
  # What the deleted transmissionDirs script did to each dir: mkdir -p, then
  # chown transmission:data and chmod 0770. A `d` line with that owner and mode
  # does the same, and adjusts an existing dir's owner and mode as well.
  sameAsTheOldScript = d: "d ${d} 0770 transmission data - -";
  bound = cfg.systemd.services.transmission.serviceConfig.BindPaths;
  resetup = cfg.systemd.services.systemd-tmpfiles-resetup;
in
  assay.suite "transmission" {
    enabled = assay.eq opts.services.transmission.enable true;
    homeOnNfsVolume = assay.eq opts.services.transmission.home directoryPath;
    groupDataForNfs = assay.eq opts.services.transmission.group "data";
    rpcPort9091Default = assay.eq (s ? "rpc-port") false;
    whitelistsOff =
      assay.eq
      (!s.rpc-host-whitelist-enabled && !s.rpc-whitelist-enabled)
      true;
    bindAllInterfaces = assay.eq s.rpc-bind-address "0.0.0.0";
    downloadsUnderServiceVolume =
      assay.eq
      s.download-dir "${directoryPath}/downloads";
    peerPort51413Default = assay.eq opts.services.transmission.openPeerPorts true;

    # GH-219: the transmissionDirs activation script is gone, and tmpfiles makes the same
    # three dirs, owned transmission:data, mode 0770.
    noActivationScript = assay.eq (cfg.system.activationScripts ? transmissionDirs) false;
    tmpfilesMakesTheSameDirs =
      assay.eq (map (d: builtins.elem (sameAsTheOldScript d) cfg.systemd.tmpfiles.rules) dirs) [true true true];
    ownerIsTheServiceUser = assay.eq [cfg.services.transmission.user cfg.services.transmission.group] ["transmission" "data"];
    # The unit bind-mounts both download dirs, which is why they must exist before it starts.
    unitBindsTheDownloadDirs =
      assay.eq (map (d: builtins.elem d bound) (lib.tail dirs)) [true true];
    # On a switch, tmpfiles re-runs before switch-to-configuration starts any unit.
    tmpfilesRerunsBeforeUnitsOnSwitch = assay.eq (builtins.elem "sysinit-reactivation.target" resetup.before) true;
  }
