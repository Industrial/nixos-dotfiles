# Colocated suite: systemPackages from stubbed pkgs, plus the prune of the old config link.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {starship = "starship";};
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
      userdir = "/home/alice";
    };
    inherit pkgs;
  };
  activation = mod.vfiles.legacy.pruneStarshipConfig.text;
in
  assay.suite "starship" {
    systemPackages = assay.eq mod.environment.systemPackages ["starship"];

    # Starship renders its own default prompt, so there is no config file in this feature and
    # nothing links one into place. A reintroduced `starship.toml` has to come with its own
    # claims; it does not get to ride in on this suite.
    noDeclaredConfig = assay.eq (builtins.pathExists ./starship.toml) false;
    doesNotLinkAConfig =
      assay.eq (mod.vfiles.legacy ? linkStarshipConfig) false;
    # `linkFile` belongs to alacritty; a second definition collides on eval.
    doesNotClaimGenericLinkFile =
      assay.eq (mod.vfiles.legacy ? linkFile) false;

    # The prune exists because the old link outlives the rebuild that removed it: the store
    # path it names is readable until the next garbage collection.
    prunesStaleConfigLink =
      assay.eq
      (builtins.match ".*rm -f \"[$]target\".*" activation != null)
      true;
    prunesTheUsersPath =
      assay.eq
      (builtins.match ".*/home/alice/[.]config/starship[.]toml.*" activation != null)
      true;
    # A real file there is a hand-written config, not litter from this feature.
    prunesOnlySymlinks =
      assay.eq (builtins.match ".*-L \"[$]target\".*" activation != null) true;

    # vfiles (GH-188): the prune is an `absent` entry, which removes only a symlink.
    vfilesDeclaresTheConfigAbsent =
      assay.eq (map (f: f.mode) (builtins.attrValues mod.vfiles.files)) ["absent"];
    vfilesAbsentPath = assay.eq (builtins.attrNames mod.vfiles.files) ["/home/alice/.config/starship.toml"];
  }
