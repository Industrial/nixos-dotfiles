# Colocated suite: the three plugins on systemPackages, and the activation
# script that registers them into the per-user registry.
#
# Evaluated against the real NixOS option tree, so the activation script is the generated
# text a host runs, with real store paths in it — not default.nix's source.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  lib = nixos.lib;

  system = nixos.evalSystem {
    modules = [./default.nix];
    settings.username = "alice";
  };
  cfg = system.config;
  pkgs = system._module.args.pkgs;
  plugins = with pkgs.nushellPlugins; [polars query formats];

  script = cfg.system.activationScripts.registerNushellPlugins.text;
  has = needle: lib.hasInfix needle script;
  registry = "/home/alice/.config/nushell/plugin.msgpackz";
in
  assay.suite "nushell-plugins" {
    systemPackages =
      assay.eq (builtins.all (p: nixos.hasPackage cfg (lib.getName p)) plugins) true;
    # Each plugin is built against one engine version and nushell refuses a mismatch, so they
    # must come from the same nixpkgs as pkgs.nushell.
    pluginsMatchTheEngine =
      assay.eq (map (p: p.version) plugins) (map (_: pkgs.nushell.version) plugins);

    registersOnActivate = assay.eq (cfg.system.activationScripts ? registerNushellPlugins) true;
    # Registered by store path to the plugin binary, not the store root, so entries never
    # name a collected generation.
    registersEachPluginBinary =
      assay.eq
      (map (p: has (builtins.unsafeDiscardStringContext "${p}/bin/nu_plugin_")) plugins)
      [true true true];
    # Registration runs as the user, not root: the registry is their state.
    registersAsUser =
      assay.eq (builtins.match ".*/bin/runuser -u alice -- \\\\\n *env HOME=/home/alice .*" script != null) true;
    # `plugin add`, not the removed `register`, into the user's own registry file.
    usesPluginAdd = assay.eq (has "plugin add --plugin-config '${registry}' '$plugin'") true;
    # A version bump moves the store paths; the registry is rebuilt from scratch then.
    rebuildsTheRegistryWhenPathsMove = assay.eq (has "rm -f ${registry}") true;
    # A plugin that will not register must not fail the whole activation.
    nonFatal =
      assay.eq (has ''echo "registerNushellPlugins: could not register $plugin, skipping" >&2'') true;
    # Only a complete registry is stamped, so a partial run retries next switch.
    stampsOnlyACompleteRegistry = assay.eq (has ''if [ "$registered" = 1 ]; then'') true;
  }
