# vverify as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vverify takes nix-store-core as a path dependency (`../nix-store-core`), so the
# source is rooted at rust/tools and holds both crates; cargoRoot and
# buildAndTestSubdir point the build at this one.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vverify";
  version = "0.1.0";

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

  cargoRoot = "vverify";
  buildAndTestSubdir = "vverify";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite builds its bundled SQLite (libsqlite3-sys). nixpkgs' cargoUseSystemLibs
  # hook would have it link a system libsqlite3 that is not among the build inputs
  # (`ld: cannot find -lsqlite3`); build the vendored sources instead, as vcache does.
  dontCargoUseSystemLibs = true;

  # vverify's own tests run here; nix-store-core's run in its own package. The tests
  # that read this machine's store database find none in the sandbox and pass
  # vacuously.

  meta = {
    description = "Scheduled parallel verification of the Nix store against its database, reported as JSON and node_exporter textfile metrics";
    license = lib.licenses.mit;
    mainProgram = "vverify";
    platforms = lib.platforms.linux;
  };
}
