# Colocated suite: transmission via the native services.transmission module.
# Asserts our declared settings (the values the module merges into
# settings.json on every start); full module eval is covered by the mimir
# toplevel build gate.
let
  assay = import ./../../../common/assay/default.nix;
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
in
  assay.suite "transmission" {
    enabled = assay.eq opts.services.transmission.enable true;
    homeOnNfsVolume = assay.eq opts.services.transmission.home directoryPath;
    groupDataForNfs = assay.eq opts.services.transmission.group "data";
    rpcPort9091Default = assay.eq (s ? "rpc-port") false;
    whitelistsOff = assay.eq
      (s.rpc-host-whitelist-enabled == false && s.rpc-whitelist-enabled == false)
      true;
    bindAllInterfaces = assay.eq s.rpc-bind-address "0.0.0.0";
    downloadsUnderServiceVolume = assay.eq
      s.download-dir "${directoryPath}/downloads";
    peerPort51413Default = assay.eq opts.services.transmission.openPeerPorts true;
  }
