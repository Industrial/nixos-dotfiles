# Colocated suite for rust/tools/vexporter/default.nix — the buildRustPackage derivation
# of the fleet metrics exporter (GH-248).
#
# Built with callPackage from the pinned nixpkgs. Claims read the derivation's
# attributes; Cargo.toml is TOML and is parsed, so the Nix identity is checked
# against the crate's own.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  pkg = pkgs.callPackage ./default.nix {};
  manifest = builtins.fromTOML (builtins.readFile ./Cargo.toml);
  crate = manifest.package;
in
  assay.suite "vexporter" {
    pnameIsTheCrateName = assay.eq pkg.pname crate.name;
    versionIsTheCrateVersion = assay.eq pkg.version crate.version;
    usesBuildRustPackage = assay.eq (pkg ? cargoDeps && pkg ? cargoBuildType) true;
    vendorsFromCargoLock = assay.eq (pkg.cargoHash or null) null;
    standaloneWorkspace = assay.eq (manifest.workspace or null) {};
    idEffectPinned = assay.eq [manifest.dependencies.id_effect manifest.dependencies.id_effect_cli] ["=0.13.0" "=0.13.0"];
    voltaicPinned = assay.eq [manifest.build-dependencies.voltaic-driver manifest.build-dependencies.voltaic-diag] ["=0.3.0" "=0.3.0"];
    nixStoreCoreByPath = assay.eq manifest.dependencies.nix-store-core {path = "../nix-store-core";};
    vendoredSqlite = assay.eq (pkg.dontCargoUseSystemLibs or false) true;
    pathDependenciesInSource =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/${f}") ["vexporter/Cargo.lock" "vexporter/src/render.vlt" "nix-store-core/src/db.vlt"]) [true true true];
    buildsTheVexporterCrate = assay.eq [pkg.cargoRoot pkg.buildAndTestSubdir] ["vexporter" "vexporter"];
    mainProgram = assay.eq pkg.meta.mainProgram "vexporter";
    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
