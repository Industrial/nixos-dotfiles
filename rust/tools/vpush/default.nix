# vpush as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vpush takes nix-store-core as a path dependency (`../nix-store-core`), so the
# source is rooted at rust/tools and holds both crates; cargoRoot and
# buildAndTestSubdir point the build at this one.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vpush";
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

  cargoRoot = "vpush";
  buildAndTestSubdir = "vpush";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite builds its bundled SQLite (libsqlite3-sys). nixpkgs' cargoUseSystemLibs
  # hook would have it link a system libsqlite3 that is not among the build inputs
  # (`ld: cannot find -lsqlite3`); build the vendored sources instead, as vcache does.
  dontCargoUseSystemLibs = true;

  # vpush's own tests run here; nix-store-core's run in its own package. The tests
  # that read this machine's store database find none in the sandbox and pass
  # vacuously.

  meta = {
    description = "Push locally built Nix store paths to the fleet's vcache host over the nix-daemon worker protocol (post-build-hook + spool daemon)";
    license = lib.licenses.mit;
    mainProgram = "vpush";
    platforms = lib.platforms.linux;
  };
}
