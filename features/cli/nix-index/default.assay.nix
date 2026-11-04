# Colocated suite: module shape with `inputs` stubbed — this feature consumes the
# nix-index-database flake input, so the import path is the thing worth pinning.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  mod = import ./default.nix {
    inputs.nix-index-database.nixosModules.nix-index = "nix-index-database-module";
  };
in
  assay.suite "nix-index" {
    # Exactly the database module, by its flake output path — not nixosModules.default,
    # which is an alias, and not the home-manager module.
    importsDatabaseModule = assay.eq mod.imports ["nix-index-database-module"];

    # Option path confirmed against the locked input's nixos-module.nix.
    commaEnabled = assay.eq mod.programs.nix-index-database.comma.enable true;

    # The prebuilt database is the point. programs.nix-index.enable (and .package) stay the
    # imported module's lib.mkDefault, governed by programs.nix-index-database.enable, so
    # this module must not write them. See the reasoning in default.nix.
    declaresNoNixIndexOptions = assay.eq (mod.programs ? nix-index) false;

    # The database comes from the input, never from a local `nix-index` run.
    schedulesNoLocalIndexBuild = assay.eq (builtins.match ".*systemd\\.(timers|services).*" src != null) false;
  }
