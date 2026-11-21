# vopt, the Voltaic Nix store optimiser, as a package (buildRustPackage).
#
# build.rs runs voltaic-driver (a crates.io build-dependency, vendored from
# Cargo.lock like any other), so the build needs no voltaic binary and no
# bootstrap step. rusqlite's `bundled` feature compiles SQLite with stdenv's cc.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vopt";
  version = "0.1.0";

  # nix-store-core is a path dependency (`../nix-store-core`), so the source is
  # rooted at rust/tools and holds both crates (as rust/tools/vcache does).
  src = lib.fileset.toSource {
    root = ./..;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./build.rs
      ./src
      ../nix-store-core/Cargo.toml
      ../nix-store-core/build.rs
      ../nix-store-core/src
    ];
  };

  cargoRoot = "vopt";
  buildAndTestSubdir = "vopt";
  cargoLock.lockFile = ./Cargo.lock;

  # Link rusqlite's `bundled` SQLite: nixpkgs' cargoUseSystemLibs hook would
  # point libsqlite3-sys at a system libsqlite3 that is not in the build inputs
  # (it broke vgc's first drakkar deploy, #171).
  dontCargoUseSystemLibs = true;

  meta = {
    description = "Nix store optimiser in Voltaic: incremental hard-link deduplication into /nix/store/.links";
    license = lib.licenses.mit;
    mainProgram = "vopt";
    platforms = lib.platforms.linux;
  };
}
