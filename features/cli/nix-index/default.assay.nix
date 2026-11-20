# Colocated suite: nix-index and comma from the prebuilt nix-index-database.
#
# The module is evaluated against the real NixOS option tree with the locked
# nix-index-database flake input, so the claims are about what the imported module and this
# one together put on a host — not about which strings default.nix happens to contain.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  system = nixos.evalSystem {modules = [./default.nix];};
  cfg = system.config;

  indexUnits = cfg:
    builtins.filter (lib.hasInfix "nix-index")
    (builtins.attrNames cfg.systemd.services ++ builtins.attrNames cfg.systemd.timers);
in
  assay.suite "nix-index" {
    # The database module, from the input: its option tree only exists if it was imported.
    importsDatabaseModule = assay.eq (system.options.programs ? nix-index-database) true;

    commaEnabled = assay.eq cfg.programs.nix-index-database.comma.enable true;
    # comma wrapped so NIX_INDEX_DATABASE resolves to the prebuilt database.
    installsCommaWithDb = assay.eq (nixos.hasPackage cfg "comma-with-db") true;

    # The prebuilt database is the point: nix-locate and the command_not_found hooks run the
    # database-carrying nix-index, not the bare nixpkgs one.
    nixIndexIsOn = assay.eq cfg.programs.nix-index.enable true;
    nixIndexUsesThePrebuiltDb = assay.eq (lib.getName cfg.programs.nix-index.package) "nix-index-with-full-db";

    # programs.nix-index.enable (and .package) stay the imported module's lib.mkDefault,
    # governed by programs.nix-index-database.enable, so this module must not write them.
    # See the reasoning in default.nix.
    declaresNoNixIndexEnable = assay.eq (builtins.elem (toString ./default.nix)
      (map (d: d.file) system.options.programs.nix-index.enable.definitionsWithLocations))
    false;
    declaresNoNixIndexPackage = assay.eq (builtins.elem (toString ./default.nix)
      (map (d: d.file) system.options.programs.nix-index.package.definitionsWithLocations))
    false;
    # nixpkgs asserts command-not-found and nix-index are mutually exclusive.
    commandNotFoundStaysOff = assay.eq cfg.programs.command-not-found.enable false;

    # The database comes from the input, never from a local `nix-index` run.
    schedulesNoLocalIndexBuild = assay.eq (indexUnits cfg) (indexUnits nixos.baseline);
  }
