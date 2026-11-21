# vgc, the Voltaic Nix garbage collector, as a package (buildRustPackage).
#
# build.rs runs voltaic-driver (a crates.io build-dependency, vendored from
# Cargo.lock like any other), so the build needs no voltaic binary and no
# bootstrap step. rusqlite's `bundled` feature compiles SQLite with stdenv's cc.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vgc";
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

  cargoRoot = "vgc";
  buildAndTestSubdir = "vgc";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite's `bundled` SQLite is the one to link. nixpkgs' cargoUseSystemLibs
  # hook would point libsqlite3-sys at a system libsqlite3 that is not in the
  # build inputs, and the link fails with `cannot find -lsqlite3` (it did, on
  # drakkar's first deploy of vgc); vcache opts out the same way.
  dontCargoUseSystemLibs = true;

  meta = {
    description = "Nix garbage collector in Voltaic: plans exactly what nix-collect-garbage would delete";
    license = lib.licenses.mit;
    mainProgram = "vgc";
    platforms = lib.platforms.linux;
  };
}
