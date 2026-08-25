# Colocated suite: jackett service module.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    pkgs = {
      jackett = "jackett";
    };
  };
  svc = mod.systemd.services.jackett;
in
  assay.suite "jackett" {
    description = assay.eq svc.description "Jackett Indexer Proxy";
    systemUser = assay.eq mod.users.users.jackett.isSystemUser true;
    groupData = assay.eq svc.serviceConfig.Group "data";
    noUpdatesFlag = assay.eq
      (builtins.match ".*--NoUpdates.*" svc.serviceConfig.ExecStart != null)
      true;
    port9117 = assay.eq
      (builtins.match ".*--Port 9117.*" svc.serviceConfig.ExecStart != null)
      true;
    dataFolderOnNfsVolume = assay.eq
      (builtins.match ".*--DataFolder /data/services/jackett.*" svc.serviceConfig.ExecStart != null)
      true;
    dataDirTmpfile = assay.eq
      (builtins.elem "d /data/services/jackett 0770 jackett data - -"
        mod.systemd.tmpfiles.rules)
      true;
  }
