# Colocated suite for rust/tools/vfiles/default.nix — the buildRustPackage derivation
# of the vfiles declarative file linker.
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
  assay.suite "vfiles" {
    pnameIsTheCrateName = assay.eq pkg.pname crate.name;
    versionIsTheCrateVersion = assay.eq pkg.version crate.version;

    # buildRustPackage with the dependencies vendored from the checked-in
    # Cargo.lock, so no cargoHash has to be bumped alongside it.
    usesBuildRustPackage = assay.eq (pkg ? cargoDeps && pkg ? cargoBuildType) true;
    vendorsFromCargoLock = assay.eq (pkg.cargoHash or null) null;

    # Standalone: its own lockfile and an empty [workspace].
    standaloneWorkspace = assay.eq (manifest.workspace or null) {};

    # One id_effect version per build, pinned exactly; Voltaic pinned past 0.2.0's
    # miscompiles.
    idEffectPinned = assay.eq [manifest.dependencies.id_effect manifest.dependencies.id_effect_cli] ["=0.13.0" "=0.13.0"];
    voltaicPinned = assay.eq [manifest.build-dependencies.voltaic-driver manifest.build-dependencies.voltaic-diag] ["=0.2.1" "=0.2.1"];

    # Nothing in the tree builds a C library the cargoUseSystemLibs hook could misdirect.
    noBundledCLibraries =
      assay.eq (builtins.any (d: builtins.hasAttr d manifest.dependencies) ["rusqlite" "id_effect_axum" "reqwest" "nix-store-core"]) false;

    sourceIsTheCrate =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/${f}") ["Cargo.lock" "build.rs" "src/app.vlt" "src/plan.vlt"]) [true true true true];

    mainProgram = assay.eq pkg.meta.mainProgram "vfiles";
    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
