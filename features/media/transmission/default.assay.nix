# Colocated suite: transmission service + declarative settings symlink.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    pkgs = {
      transmission_4 = "transmission_4";
      coreutils = "/bin/mkdir";
      diffutils = "/bin/cmp";
    };
  };
  svc = mod.systemd.services.transmission;
  activation =
    mod.system.activationScripts.transmissionSettings.text;
  settingsExists = builtins.pathExists ./config/settings.json;
  settings = builtins.fromJSON (builtins.readFile ./config/settings.json);
in
  assay.suite "transmission" {
    description = assay.eq svc.description "Transmission BitTorrent Daemon";
    systemUser = assay.eq mod.users.users.transmission.isSystemUser true;
    groupData = assay.eq svc.serviceConfig.Group "data";
    foregroundFlag = assay.eq
      (builtins.match ".*transmission-daemon -f -g /data/services/transmission/.config/transmission-daemon.*" svc.serviceConfig.ExecStart != null)
      true;
    activationScriptDeclared =
      assay.eq (mod.system.activationScripts ? transmissionSettings) true;
    linksDeclarativeSettings = assay.eq
      (builtins.match ".*/data/dotfiles/features/media/transmission/config/settings.json.*" activation != null)
      true;
    symlinksIdempotently = assay.eq
      (builtins.match ".*ln -sfn .*" activation != null)
      true;
    backsUpDivergentLiveFile = assay.eq
      (builtins.match ".*cmp -s.*target.*source.*" activation != null)
      true;
    degradesWithoutRepoClone = assay.eq
      (builtins.match ".*keeping existing settings.*" activation != null)
      true;
    repoSettingsPresent = assay.eq settingsExists true;
    repoRpcPort9091 = assay.eq settings.rpc-port 9091;
    repoPeerPort51413 = assay.eq settings.peer-port 51413;
    repoDownloadDirOnNfsVolume = assay.eq
      settings.download-dir "/data/services/transmission/downloads";
  }
