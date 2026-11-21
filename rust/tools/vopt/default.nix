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

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./build.rs ./src];
  };

  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "Nix store optimiser in Voltaic: incremental hard-link deduplication into /nix/store/.links";
    license = lib.licenses.mit;
    mainProgram = "vopt";
    platforms = lib.platforms.linux;
  };
}
