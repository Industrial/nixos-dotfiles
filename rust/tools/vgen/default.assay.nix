# Colocated suite for rust/tools/vgen/default.nix — the buildRustPackage
# derivation of the vgen generation manager.
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
  assay.suite "vgen" {
    pnameIsTheCrateName = assay.eq pkg.pname crate.name;
    versionIsTheCrateVersion = assay.eq pkg.version crate.version;

    # buildRustPackage with the dependencies vendored from the checked-in
    # Cargo.lock, so no cargoHash has to be bumped alongside it.
    usesBuildRustPackage = assay.eq (pkg ? cargoDeps && pkg ? cargoBuildType) true;
    vendorsFromCargoLock = assay.eq (pkg.cargoHash or null) null;

    # Standalone: its own lockfile and an empty [workspace].
    standaloneWorkspace = assay.eq (manifest.workspace or null) {};

    # One id_effect version per build, pinned exactly; Voltaic pinned past
    # 0.2.0's miscompiles.
    idEffectPinned = assay.eq manifest.dependencies.id_effect "=0.13.0";
    voltaicPinned = assay.eq manifest.build-dependencies.voltaic-driver "=0.3.0";

    # rusqlite's bundled SQLite builds from source: without this the fleet's
    # Nix build fails with `ld: cannot find -lsqlite3`.
    vendoredSqlite = assay.eq (pkg.dontCargoUseSystemLibs or false) true;

    # The retention rule is nix-store-core's (lifted from vgc), the closure
    # diff vdiff's: both are path dependencies whose sources ship with vgen's.
    pathDependenciesInSource =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/${f}") ["vgen/Cargo.lock" "nix-store-core/src/generations.vlt" "vdiff/src/report.vlt"]) [true true true];
    dependsOnCoreAndVdiff =
      assay.eq [manifest.dependencies.nix-store-core.path manifest.dependencies.vdiff.path] ["../nix-store-core" "../vdiff"];
    buildsTheVgenCrate = assay.eq [pkg.cargoRoot pkg.buildAndTestSubdir] ["vgen" "vgen"];

    mainProgram = assay.eq pkg.meta.mainProgram "vgen";
    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
