# Colocated suite: sonarr service + declarative config link (tmpfiles, GH-219).
#
# The service and user claims read the module directly; the link claims evaluate it
# against the real NixOS option tree, so they are about the rules the host gets.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {
      sonarr = "sonarr";
    };
  in
    import ./default.nix {inherit pkgs;};
  nixos = import ./../../../common/assay/nixos.nix;
  cfg = (nixos.evalSystem {modules = [./default.nix];}).config;
  inherit (cfg.systemd.tmpfiles) rules;
  live = "/data/services/sonarr/config.xml";
  repo = "/data/dotfiles/features/media/sonarr/config/config.xml";
  configExists = builtins.pathExists ./config/config.xml;
  configSrc =
    if configExists
    then builtins.readFile ./config/config.xml
    else "";
  declaredKey = (import ../api-keys.nix).sonarr;
  liveKey =
    builtins.head
    (builtins.match ".*<ApiKey>([^<]*)</ApiKey>.*" configSrc);
in
  assay.suite "sonarr" {
    description = assay.eq mod.systemd.services.sonarr.description "Sonarr Daemon";
    systemUser = assay.eq mod.users.users.sonarr.isSystemUser true;
    # The sonarrConfig activation script is gone; tmpfiles links the repo config instead.
    noActivationScript = assay.eq (cfg.system.activationScripts ? sonarrConfig) false;
    linksDeclarativeConfig = assay.eq (builtins.elem "L ${live} - - - - ${repo}" rules) true;
    # `L`, never `L+`: a real config.xml in the data dir is never deleted.
    neverReplacesALiveFile = assay.eq (builtins.any (r: builtins.match "L\\+.*${live}.*" r != null) rules) false;
    repoConfigGroupWritable = assay.eq (builtins.elem "z ${repo} 0664 - data - -" rules) true;
    dataDirsStillMade = assay.eq (builtins.elem "d /data/services/sonarr 0770 sonarr data - -" rules) true;
    repoConfigPresent = assay.eq configExists true;
    repoConfigHasPort =
      assay.eq
      (builtins.match ".*<Port>8989</Port>.*" configSrc != null)
      true;
    repoConfigKeyMatchesApiKeys = assay.eq liveKey declaredKey;
  }
