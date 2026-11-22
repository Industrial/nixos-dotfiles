# Colocated suite for rust/tools/vhealth/default.nix — the buildRustPackage derivation
# of the vhealth probe runner.
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
  lock = builtins.fromTOML (builtins.readFile ./Cargo.lock);
  locked = map (p: p.name) lock.package;
in
  assay.suite "vhealth" {
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
    idEffectPinned = assay.eq [manifest.dependencies.id_effect manifest.dependencies.id_effect_cli] ["=0.13.0" "=0.13.0"];
    voltaicPinned = assay.eq [manifest.build-dependencies.voltaic-driver manifest.build-dependencies.voltaic-diag] ["=0.3.0" "=0.3.0"];

    # No C library in the closure, so nixpkgs' cargoUseSystemLibs hook has nothing to
    # swap; a dependency that brings one (libsqlite3-sys, aws-lc-sys) needs
    # dontCargoUseSystemLibs, as vcache and vverify set it.
    noNativeLibraries =
      assay.eq (builtins.filter (n: builtins.elem n locked) ["libsqlite3-sys" "aws-lc-sys" "openssl-sys"]) [];

    # The source is the crate alone, with its Voltaic sources.
    sourceIsTheCrate =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/${f}") ["Cargo.lock" "build.rs" "src/check.vlt" "src/probe.vlt"]) [true true true true];

    mainProgram = assay.eq pkg.meta.mainProgram "vhealth";
    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
