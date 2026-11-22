# Colocated suite for rust/tools/vfetch/default.nix — the buildRustPackage
# derivation of vfetch.
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
  assay.suite "vfetch" {
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
    idEffectPinned =
      assay.eq [manifest.dependencies.id_effect manifest.dependencies.id_effect_cli manifest.dependencies.id_effect_platform] ["=0.13.0" "=0.13.0" "=0.13.0"];
    voltaicPinned = assay.eq manifest.build-dependencies.voltaic-driver "=0.3.0";

    # Bundled SQLite, liblzma, zstd and aws-lc build their vendored sources: without
    # this the fleet build fails at `ld: cannot find -lsqlite3` while cargo passes.
    vendoredSystemLibs = assay.eq (pkg.dontCargoUseSystemLibs or false) true;

    # nix-store-core is a path dependency: the source is rooted at rust/tools,
    # carries both crates, and the build runs in this one.
    pathDependencyInSource =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/${f}") ["vfetch/Cargo.lock" "nix-store-core/Cargo.toml" "nix-store-core/src/narinfo.vlt"]) [true true true];
    buildsTheVfetchCrate = assay.eq [pkg.cargoRoot pkg.buildAndTestSubdir] ["vfetch" "vfetch"];

    mainProgram = assay.eq pkg.meta.mainProgram "vfetch";
    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
