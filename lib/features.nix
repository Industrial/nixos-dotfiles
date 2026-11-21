# Feature wrapper — gives every feature module an enable switch without editing it.
#
#   feature ../features/fleet/comin.nix
#
# returns a NixOS module that
#   - declares `features.fleet.comin.enable` (default false),
#   - applies the original module's config only under `mkIf enable`,
#   - keeps the original's `options`, `_module`, `disabledModules` and `meta`
#     unconditional, because option surfaces must exist on every host whether or
#     not the feature is on (flake.nix's stigReport reads `security.stig.*` on all
#     four, for one), and `_module.args` under mkIf would recurse.
#
# The wrapped module's own `imports` are rewritten:
#   - a file in the same feature directory (neovim's ./buffers.nix, gnome's
#     ./dconf.nix) is a PART: wrapped under the parent's switch, no switch of its own;
#   - any other feature path (claude-code's ../lean-ctx) is a DEPENDENCY: wrapped
#     with its own switch, which the parent turns on with mkDefault — so a host
#     can still force it off;
#   - anything else (inputs.*.nixosModules.*) passes through unconditionally, as
#     an upstream module guards itself with its own enable option.
#
# Feature bodies stay plain modules, so the colocated assay suites that
# `import ./default.nix { ... }` and inspect the attrset keep working unchanged.
{lib}: let
  inherit (builtins) baseNameOf dirOf;

  root = toString ../features;

  normalize = p:
    if lib.pathIsDirectory p
    then p + "/default.nix"
    else p;

  isFeaturePath = p: (lib.isPath p || lib.isString p) && lib.hasPrefix (root + "/") (toString p);

  # features/fleet/comin.nix -> ["fleet" "comin"]; features/ai/paseo/default.nix -> ["ai" "paseo"]
  namePath = p:
    lib.splitString "/" (lib.removeSuffix ".nix" (lib.removeSuffix "/default.nix" (lib.removePrefix (root + "/") (toString p))));

  optionPath = p: ["features"] ++ namePath p;

  isPartOf = parent: child:
    baseNameOf (toString parent)
    == "default.nix"
    && lib.hasPrefix (dirOf (toString parent) + "/") (toString child);

  # Attributes the module system treats as structure rather than config.
  # (`meta` is config in the shorthand form, so it stays in the gated body there.)
  structural = ["imports" "options" "config" "_file" "key" "disabledModules" "freeformType" "_class" "require"];

  wrap = {
    path,
    # Option path of the switch this module obeys; null = declare its own.
    gate ? null,
  }: let
    file = normalize path;
    own = gate == null;
    switch =
      if own
      then optionPath file
      else gate;
    raw = import file;

    module = args: let
      m =
        if lib.isFunction raw
        then raw args
        else raw;
      explicit = m ? config || m ? options;
      body =
        if explicit
        then m.config or {}
        else removeAttrs m structural;
      # `_module` must not sit under mkIf; only separable from a plain attrset.
      plain = lib.isAttrs body && !(body ? _type);
      moduleArgs =
        if plain
        then body._module or null
        else null;
      gated =
        if plain
        then removeAttrs body ["_module"]
        else body;

      enabled = lib.attrByPath (switch ++ ["enable"]) false args.config;

      imports' = map (i: let
        child = normalize i;
      in
        if !isFeaturePath i
        then {
          module = i;
          dep = null;
        }
        else if isPartOf file child
        then {
          module = wrap {
            path = child;
            gate = switch;
          };
          dep = null;
        }
        else {
          module = wrap {path = child;};
          dep = optionPath child;
        }) (m.imports or []);

      deps = lib.filter (d: d != null) (map (x: x.dep) imports');
    in
      {
        key = "feature:${toString file}";
        _file = toString file;
        imports =
          map (x: x.module) imports'
          ++ lib.optional own {
            options = lib.setAttrByPath switch {
              enable = lib.mkEnableOption "the ${lib.concatStringsSep "." (namePath file)} feature (${lib.removePrefix (dirOf root + "/") (toString file)})";
            };
          };
        options = m.options or {};
        config = lib.mkMerge (
          lib.optional (moduleArgs != null) {_module = moduleArgs;}
          ++ [
            (lib.mkIf enabled gated)
            (lib.mkIf enabled (lib.mkMerge (map (d: lib.setAttrByPath (d ++ ["enable"]) (lib.mkDefault true)) deps)))
          ]
        );
      }
      // lib.optionalAttrs (m ? disabledModules) {inherit (m) disabledModules;}
      // lib.optionalAttrs (explicit && m ? meta) {inherit (m) meta;}
      // lib.optionalAttrs (m ? freeformType) {inherit (m) freeformType;};
  in
    # Mirror the original's argument list so the module system still hands it
    # `pkgs` and other _module.args it asks for by name.
    lib.setFunctionArgs module (
      (
        if lib.isFunction raw
        then lib.functionArgs raw
        else {}
      )
      // {config = false;}
    );

  catalog = map normalize (import ../features/catalog.nix);

  profiles = map (name: ../profiles + "/${name}") (
    lib.attrNames (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name && !lib.hasSuffix ".assay.nix" name)
      (builtins.readDir ../profiles))
  );

  # Just the switches: one `features.<path>.enable` per catalog entry, no bodies. A
  # feature's own options (features.nix.vdaemon-proxy.native, say) land in the stub's
  # freeform part, one key each, so a host may set several of them.
  optionStubs =
    map (p: {
      options = lib.setAttrByPath (optionPath p) (lib.mkOption {
        type = lib.types.submodule {
          freeformType = lib.types.lazyAttrsOf lib.types.raw;
          options.enable = lib.mkEnableOption (lib.concatStringsSep "." (namePath p));
        };
        default = {};
      });
    })
    catalog;

  isEnabled = cfg: p: lib.attrByPath (optionPath p ++ ["enable"]) false cfg;
in {
  feature = path: wrap {inherit path;};

  # Every host's module set, used by lib/mk-host.nix.
  modules = map (path: wrap {inherit path;}) catalog ++ profiles;

  inherit catalog profiles namePath optionPath optionStubs;

  # Selection-only evaluation, for suites: which profiles and features a set of
  # modules (a profile, a host's configuration.nix) switches on — evaluated through
  # the real profiles, but against option stubs rather than the feature bodies, so
  # it needs no nixpkgs and no flake inputs and runs in milliseconds. `modules` may
  # carry `disabledModules` for host files that set real NixOS options
  # (disko.nix, hardware.nix, filesystems.nix).
  #
  # Anything else a profile or host sets (environment.systemPackages, say) is accepted by
  # a lazy freeform catch-all and never evaluated, so `pkgs` is never needed — it throws
  # if something does force it.
  evalSelection = {modules ? []}:
    (lib.evalModules {
      modules =
        [
          {
            freeformType = lib.types.lazyAttrsOf lib.types.raw;
            config._module.args.pkgs = throw "lib/features.nix evalSelection: no pkgs in a selection-only evaluation";
          }
        ]
        ++ optionStubs
        ++ profiles
        ++ modules;
      specialArgs = {
        inputs = {
          disko.nixosModules.disko = {};
          stylix.nixosModules.stylix = {};
        };
        settings = {};
      };
    })
    .config;

  # Dotted names of every catalogued feature `cfg` switches on.
  enabledFeatures = cfg: map (p: lib.concatStringsSep "." (namePath p)) (lib.filter (isEnabled cfg) catalog);
}
