# Colocated suite: flexget service module.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    pkgs = {
      flexget = "flexget";
      coreutils = "/bin/install";
    };
  };
  svc = mod.systemd.services.flexget;
in
  assay.suite "flexget" {
    description = assay.eq svc.description "FlexGet Daemon";
    systemUser = assay.eq mod.users.users.flexget.isSystemUser true;
    groupData = assay.eq svc.serviceConfig.Group "data";
    daemonStart = assay.eq
      (builtins.match ".*flexget -c .* daemon start --webui.*" svc.serviceConfig.ExecStart != null)
      true;
    installsRepoConfig = assay.eq
      (builtins.match ".*/data/dotfiles/features/media/flexget/config/config.yml.*" svc.serviceConfig.ExecStartPre != null)
      true;
    webuiPort5050InRepoConfig = let
      cfg = builtins.readFile ./config/config.yml;
    in
      assay.eq (builtins.match ".*port: 5050.*" cfg != null) true;
    targetsTransmissionRpc = let
      cfg = builtins.readFile ./config/config.yml;
    in
      assay.eq (builtins.match ".*port: 9091.*" cfg != null) true;
  }
