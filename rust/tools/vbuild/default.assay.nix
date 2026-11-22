# Colocated suite for rust/tools/vbuild/default.nix — the buildRustPackage
# derivation of the vbuild build hook.
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
  assay.suite "vbuild" {
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

    # rusqlite (through nix-store-core) builds its bundled SQLite: without this
    # the fleet build fails with `ld: cannot find -lsqlite3`.
    bundledSqlite = assay.eq (pkg.dontCargoUseSystemLibs or false) true;

    # nix-store-core is a path dependency: the source is rooted at rust/tools,
    # carries both crates, and the build runs in this one.
    pathDependencyInSource =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/${f}") ["vbuild/Cargo.lock" "nix-store-core/Cargo.toml" "nix-store-core/src/drv.vlt"]) [true true true];
    buildsTheVbuildCrate = assay.eq [pkg.cargoRoot pkg.buildAndTestSubdir] ["vbuild" "vbuild"];

    mainProgram = assay.eq pkg.meta.mainProgram "vbuild";
    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
