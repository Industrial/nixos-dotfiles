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

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./build.rs ./src];
  };

  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "Nix garbage collector in Voltaic: plans exactly what nix-collect-garbage would delete";
    license = lib.licenses.mit;
    mainProgram = "vgc";
    platforms = lib.platforms.linux;
  };
}
