# Colocated suite: the three plugins on systemPackages, and the activation
# script that registers them into the per-user registry.
#
# Trap: the stub pkgs is a plain attrset with no `callPackage`, and forcing the
# activation `.text` would demand every pkgs attribute it interpolates. So the
# script is asserted over the source text instead of the evaluated module.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
      userdir = "/home/alice";
    };
    pkgs = {
      nushellPlugins = {
        polars = "polars";
        query = "query";
        formats = "formats";
      };
    };
  };
in
  assay.suite "nushell-plugins" {
    systemPackages = assay.eq mod.environment.systemPackages ["polars" "query" "formats"];
    registersOnActivate = assay.eq (builtins.match ".*registerNushellPlugins.*" src != null) true;
    # Registration runs as the user, not root: the registry is their state.
    registersAsUser = assay.eq (builtins.match ".*runuser -u .*" src != null) true;
    # `plugin add`, not the removed `register`, and from the store path.
    usesPluginAdd = assay.eq (builtins.match ".*plugin add --plugin-config.*" src != null) true;
    # A plugin that will not register must not fail the whole activation.
    nonFatal = assay.eq (builtins.match ".*skipping.*" src != null) true;
  }
