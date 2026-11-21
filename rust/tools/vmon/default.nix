# vmon as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vmon takes nix-store-core as a path dependency (`../nix-store-core`), so the
# source is rooted at rust/tools and holds both crates; cargoRoot and
# buildAndTestSubdir point the build at this one.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vmon";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./..;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./build.rs
      ./src
      # The captured logs the tests replay (src/golden.vlt).
      ./tests/fixtures
      ../nix-store-core/Cargo.toml
      ../nix-store-core/build.rs
      ../nix-store-core/src
    ];
  };

  cargoRoot = "vmon";
  buildAndTestSubdir = "vmon";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite (through nix-store-core's db) is built with its bundled SQLite.
  # nixpkgs' cargoUseSystemLibs hook would have libsqlite3-sys link a system
  # libsqlite3 that is not in the build inputs (`ld: cannot find -lsqlite3`);
  # build the vendored sources instead, as vcache does.
  dontCargoUseSystemLibs = true;

  # The tests run here, the replays of the captured logs (src/golden.vlt)
  # included; none needs the store or a daemon.

  meta = {
    description = "A Nix build-log monitor: live build tree, plain mode, failure summaries, build-time metrics (replaces nix-output-monitor)";
    license = lib.licenses.mit;
    mainProgram = "vmon";
    platforms = lib.platforms.linux;
  };
}
