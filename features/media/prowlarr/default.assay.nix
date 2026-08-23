# Colocated suite: prowlarr service + declarative config symlink wiring.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {
      prowlarr = "prowlarr";
      diffutils = "/bin/cmp";
    };
  in
    import ./default.nix {inherit pkgs;};
  activation =
    mod.system.activationScripts.prowlarrConfig.text;
  configExists = builtins.pathExists ./config/config.xml;
  configSrc =
    if configExists
    then builtins.readFile ./config/config.xml
    else "";
  declaredKey = (import ../api-keys.nix).prowlarr;
  liveKey = builtins.head
    (builtins.match ".*<ApiKey>([^<]*)</ApiKey>.*" configSrc);
in
  assay.suite "prowlarr" {
    description = assay.eq mod.systemd.services.prowlarr.description "Prowlarr Daemon";
    systemUser = assay.eq mod.users.users.prowlarr.isSystemUser true;
    activationScriptDeclared =
      assay.eq (mod.system.activationScripts ? prowlarrConfig) true;
    linksDeclarativeConfig = assay.eq
      (builtins.match ".*/data/dotfiles/features/media/prowlarr/config/config.xml.*" activation != null)
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
      (builtins.match ".*<Port>9696</Port>.*" configSrc != null)
      true;
    repoConfigKeyMatchesApiKeys = assay.eq liveKey declaredKey;
  }
