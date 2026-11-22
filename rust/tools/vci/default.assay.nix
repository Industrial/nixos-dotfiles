# Colocated suite for rust/tools/vci/default.nix — the buildRustPackage derivation
# of the fleet CI (GH-242).
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
  assay.suite "vci" {
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
    voltaicPinned = assay.eq [manifest.build-dependencies.voltaic-driver manifest.build-dependencies.voltaic-diag] ["=0.3.0" "=0.3.0"];

    # The command runner is vdeploy's, linked and not copied: vdeploy and vdiff by path.
    vdeployByPath = assay.eq manifest.dependencies.vdeploy {path = "../vdeploy";};
    vdiffByPath = assay.eq manifest.dependencies.vdiff {path = "../vdiff";};

    # rusqlite's bundled SQLite builds from its own sources; without this the
    # cargoUseSystemLibs hook links a libsqlite3 that is not there.
    vendoredSqlite = assay.eq (pkg.dontCargoUseSystemLibs or false) true;

    # The source is rooted at rust/tools, carries all four crates, and the build runs in this one.
    pathDependenciesInSource =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/${f}") ["vci/Cargo.lock" "vci/src/refs.vlt" "vdeploy/src/common.vlt" "vdiff/src/report.vlt" "nix-store-core/src/db.vlt"]) [true true true true true];
    buildsTheVciCrate = assay.eq [pkg.cargoRoot pkg.buildAndTestSubdir] ["vci" "vci"];

    mainProgram = assay.eq pkg.meta.mainProgram "vci";
    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
