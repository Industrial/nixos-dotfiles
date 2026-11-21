# Colocated suite for rust/tools/vopt/default.nix: the buildRustPackage that
# features/nixos/vopt runs. Evaluated, not built; Cargo.toml is parsed so the
# package is checked against the crate's own identity and pins.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  pkg = pkgs.callPackage ./default.nix {};
  manifest = builtins.fromTOML (builtins.readFile ./Cargo.toml);
in
  assay.suite "vopt-package" {
    nameIsTheCrateName = assay.eq pkg.pname manifest.package.name;
    versionIsTheCrateVersion = assay.eq pkg.version manifest.package.version;
    mainProgramIsVopt = assay.eq pkg.meta.mainProgram "vopt";
    voltaicPinnedExactly = assay.eq manifest.build-dependencies.voltaic-driver "=0.2.1";
    idEffectPinnedExactly = assay.eq manifest.dependencies.id_effect "=0.13.0";
    isStandalone = assay.eq (manifest ? workspace) true;
  }
