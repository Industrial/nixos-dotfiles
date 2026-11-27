# vfleet, the typed fleet inventory and feature catalog (GH-417 S2), as a package
# (buildRustPackage, dependencies vendored from the checked-in Cargo.lock). build.rs
# compiles src/*.vlt with Voltaic as a library, so no voltaic binary is needed here.
#
# The source is rooted at the repository so it also carries the two generated files,
# common/fleet.json and features/catalog.json: the drift test (src/app.vlt) compares
# them with what the inventory generates, and runs here in the sandbox as well as under
# `bin/ci/cargo-standalone test vfleet`. A stale JSON fails the build.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vfleet";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../../..;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./build.rs
      ./src
      ../../../common/fleet.json
      ../../../features/catalog.json
    ];
  };

  cargoRoot = "rust/tools/vfleet";
  buildAndTestSubdir = "rust/tools/vfleet";
  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "Fleet inventory and feature catalog as Voltaic types: checks cross-host invariants and emits the JSON NixOS reads";
    license = lib.licenses.mit;
    mainProgram = "vfleet";
    platforms = lib.platforms.linux;
  };
}
