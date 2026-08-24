# Colocated suite: sonarr service + declarative config symlink wiring.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {
      sonarr = "sonarr";
      diffutils = "/bin/cmp";
    };
  in
    import ./default.nix {inherit pkgs;};
  activation =
    mod.system.activationScripts.sonarrConfig.text;
  configExists = builtins.pathExists ./config/config.xml;
  configSrc =
    if configExists
    then builtins.readFile ./config/config.xml
    else "";
  declaredKey = (import ../api-keys.nix).sonarr;
  liveKey = builtins.head
    (builtins.match ".*<ApiKey>([^<]*)</ApiKey>.*" configSrc);
in
  assay.suite "sonarr" {
    description = assay.eq mod.systemd.services.sonarr.description "Sonarr Daemon";
    systemUser = assay.eq mod.users.users.sonarr.isSystemUser true;
    activationScriptDeclared =
      assay.eq (mod.system.activationScripts ? sonarrConfig) true;
    linksDeclarativeConfig = assay.eq
      (builtins.match ".*/data/dotfiles/features/media/sonarr/config/config.xml.*" activation != null)
      true;
    symlinksIdempotently = assay.eq
      (builtins.match ".*ln -sfn .*" activation != null)
      true;
    backsUpDivergentLiveFile = assay.eq
      (builtins.match ".*cmp -s.*target.*source.*" activation != null)
      true;
    degradesWithoutRepoClone = assay.eq
      (builtins.match ".*keeping existing config.*" activation != null)
      true;
    repoConfigPresent = assay.eq configExists true;
    repoConfigHasPort = assay.eq
      (builtins.match ".*<Port>8989</Port>.*" configSrc != null)
      true;
    repoConfigKeyMatchesApiKeys = assay.eq liveKey declaredKey;
  }
