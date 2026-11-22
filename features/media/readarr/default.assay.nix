# Colocated suite: readarr service + declarative config link (tmpfiles, GH-219).
#
# The service and user claims read the module directly; the link claims evaluate it
# against the real NixOS option tree, so they are about the rules the host gets.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {
      readarr = "readarr";
    };
  in
    import ./default.nix {inherit pkgs;};
  nixos = import ./../../../common/assay/nixos.nix;
  cfg = (nixos.evalSystem {modules = [./default.nix];}).config;
  inherit (cfg.systemd.tmpfiles) rules;
  live = "/data/services/readarr/config.xml";
  repo = "/data/dotfiles/features/media/readarr/config/config.xml";
  configExists = builtins.pathExists ./config/config.xml;
  configSrc =
    if configExists
    then builtins.readFile ./config/config.xml
    else "";
  declaredKey = (import ../api-keys.nix).readarr;
  liveKey =
    builtins.head
    (builtins.match ".*<ApiKey>([^<]*)</ApiKey>.*" configSrc);
in
  assay.suite "readarr" {
    description = assay.eq mod.systemd.services.readarr.description "Readarr Daemon";
    systemUser = assay.eq mod.users.users.readarr.isSystemUser true;
    # The readarrConfig activation script is gone; tmpfiles links the repo config instead.
    noActivationScript = assay.eq (cfg.system.activationScripts ? readarrConfig) false;
    linksDeclarativeConfig = assay.eq (builtins.elem "L ${live} - - - - ${repo}" rules) true;
    # `L`, never `L+`: a real config.xml in the data dir is never deleted.
    neverReplacesALiveFile = assay.eq (builtins.any (r: builtins.match "L\\+.*${live}.*" r != null) rules) false;
    repoConfigGroupWritable = assay.eq (builtins.elem "z ${repo} 0664 - data - -" rules) true;
    dataDirsStillMade = assay.eq (builtins.elem "d /data/services/readarr 0770 readarr data - -" rules) true;
    repoConfigPresent = assay.eq configExists true;
    repoConfigHasPort =
      assay.eq
      (builtins.match ".*<Port>8787</Port>.*" configSrc != null)
      true;
    repoConfigKeyMatchesApiKeys = assay.eq liveKey declaredKey;
  }
