# vdaemon-proxy as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library, so no
# voltaic binary is needed here.
#
# vdaemon-proxy takes nix-store-core as a path dependency (`../nix-store-core`), so the
# source is rooted at rust/tools and holds both crates; cargoRoot and buildAndTestSubdir
# point the build at this one.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vdaemon-proxy";
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

  cargoRoot = "vdaemon-proxy";
  buildAndTestSubdir = "vdaemon-proxy";
  cargoLock.lockFile = ./Cargo.lock;

  # nix-store-core links rusqlite with its bundled SQLite. nixpkgs' cargoUseSystemLibs
  # hook would point libsqlite3-sys at a system SQLite that is not there (the link
  # fails on -lsqlite3); build the vendored sources instead, as vcache does.
  dontCargoUseSystemLibs = true;

  meta = {
    description = "A logging proxy in front of nix-daemon: every worker-protocol op as one JSON line";
    license = lib.licenses.mit;
    mainProgram = "vdaemon-proxy";
    platforms = lib.platforms.linux;
  };
}
