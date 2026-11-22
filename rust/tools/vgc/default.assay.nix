# Colocated suite for rust/tools/vgc/default.nix: the buildRustPackage that
# features/nixos/vgc runs. Evaluated, not built; Cargo.toml is parsed so the
# package is checked against the crate's own identity and pins.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  pkg = pkgs.callPackage ./default.nix {};
  manifest = builtins.fromTOML (builtins.readFile ./Cargo.toml);
in
  assay.suite "vgc-package" {
    nameIsTheCrateName = assay.eq pkg.pname manifest.package.name;
    versionIsTheCrateVersion = assay.eq pkg.version manifest.package.version;
    mainProgramIsVgc = assay.eq pkg.meta.mainProgram "vgc";
    # Voltaic and id_effect are pinned exactly: Voltaic's surface still moves between
    # minors, and two id_effect versions' types do not unify.
    voltaicPinnedExactly = assay.eq manifest.build-dependencies.voltaic-driver "=0.3.0";
    idEffectPinnedExactly = assay.eq manifest.dependencies.id_effect "=0.13.0";
    # Standalone crate: its own lockfile, never a member of rust/Cargo.toml.
    isStandalone = assay.eq (manifest ? workspace) true;
  }
