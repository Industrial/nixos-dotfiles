# vexporter as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vexporter takes nix-store-core as a path dependency (`../nix-store-core`), so the
# source is rooted at rust/tools and holds both crates; cargoRoot and
# buildAndTestSubdir point the build at this one.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vexporter";
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

  cargoRoot = "vexporter";
  buildAndTestSubdir = "vexporter";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite (through nix-store-core's db) is built with its bundled SQLite; the
  # cargoUseSystemLibs hook would link a system libsqlite3 that is not there.
  dontCargoUseSystemLibs = true;

  meta = {
    description = "The Nix and fleet metrics no other tool owns, as a node_exporter textfile: the store, the system generations, the deploy lag";
    license = lib.licenses.mit;
    mainProgram = "vexporter";
    platforms = lib.platforms.linux;
  };
}
