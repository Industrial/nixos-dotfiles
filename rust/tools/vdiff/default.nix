# vdiff as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vdiff takes nix-store-core as a path dependency (`../nix-store-core`), so the
# source is rooted at rust/tools and holds both crates; cargoRoot and
# buildAndTestSubdir point the build at this one.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vdiff";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./..;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./build.rs
      ./src
      # The golden cases the tests read (src/golden.vlt).
      ./tests/fixtures
      ../nix-store-core/Cargo.toml
      ../nix-store-core/build.rs
      ../nix-store-core/src
    ];
  };

  cargoRoot = "vdiff";
  buildAndTestSubdir = "vdiff";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite (through nix-store-core's db) is built with its bundled SQLite.
  # nixpkgs' cargoUseSystemLibs hook would have libsqlite3-sys link a system
  # libsqlite3 that is not in the build inputs (`ld: cannot find -lsqlite3`);
  # build the vendored sources instead, as vcache does.
  dontCargoUseSystemLibs = true;

  # The tests run here. The ones that read this machine's /nix/var/nix/db or
  # /run/current-system find neither in the sandbox and pass vacuously; the
  # golden cases need no store.

  meta = {
    description = "Package-level closure diff between two Nix store paths or system generations (replaces nvd)";
    license = lib.licenses.mit;
    mainProgram = "vdiff";
    platforms = lib.platforms.linux;
  };
}
