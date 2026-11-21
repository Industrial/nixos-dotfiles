# vgen as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vgen takes nix-store-core and vdiff as path dependencies (`../nix-store-core`,
# `../vdiff`), so the source is rooted at rust/tools and holds all three crates;
# cargoRoot and buildAndTestSubdir point the build at this one. vdiff's test
# fixtures are read only by vdiff's own tests, so they stay out.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vgen";
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
      ../vdiff/Cargo.toml
      ../vdiff/build.rs
      ../vdiff/src
    ];
  };

  cargoRoot = "vgen";
  buildAndTestSubdir = "vgen";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite (through nix-store-core's db) is built with its bundled SQLite.
  # nixpkgs' cargoUseSystemLibs hook would have libsqlite3-sys link a system
  # libsqlite3 that is not in the build inputs (`ld: cannot find -lsqlite3`);
  # build the vendored sources instead, as vcache and vdiff do.
  dontCargoUseSystemLibs = true;

  # The tests run here. They work on scratch directories under $TMPDIR; none
  # needs a store, a profile or root.

  meta = {
    description = "Nix generation manager: list with closure diffs, pin, and prune with the boot entries kept in step";
    license = lib.licenses.mit;
    mainProgram = "vgen";
    platforms = lib.platforms.linux;
  };
}
