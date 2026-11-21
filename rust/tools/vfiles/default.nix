# vfiles as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here. No path dependencies: the source is this
# crate alone.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vfiles";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./build.rs
      ./src
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  # No rusqlite or rustls in the tree, so the cargoUseSystemLibs hook has nothing
  # to misdirect. The tests use temporary directories only.

  meta = {
    description = "A declarative file linker: places NixOS-declared user files atomically, owns them through a manifest, removes what it owned, and reports hand edits";
    license = lib.licenses.mit;
    mainProgram = "vfiles";
    platforms = lib.platforms.linux;
  };
}
