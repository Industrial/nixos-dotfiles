# vci as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vci links vdeploy (its command runner), vdiff and, through both,
# nix-store-core by path, so the source is rooted at rust/tools and holds all
# four crates; cargoRoot and buildAndTestSubdir point the build at this one.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vci";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./..;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./build.rs
      ./src
      ../vdeploy/Cargo.toml
      ../vdeploy/build.rs
      ../vdeploy/src
      ../vdiff/Cargo.toml
      ../vdiff/build.rs
      ../vdiff/src
      ../nix-store-core/Cargo.toml
      ../nix-store-core/build.rs
      ../nix-store-core/src
    ];
  };

  cargoRoot = "vci";
  buildAndTestSubdir = "vci";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite (through vdiff and nix-store-core's db) builds its bundled SQLite.
  # nixpkgs' cargoUseSystemLibs hook would have it link a system libsqlite3 that
  # is not among the build inputs (`ld: cannot find -lsqlite3`); build the
  # bundled sources instead, as vdeploy and vcache do.
  dontCargoUseSystemLibs = true;

  meta = {
    description = "Fleet CI on the cache host: every fleet host built for main and open PRs, into the store vcache serves";
    license = lib.licenses.mit;
    mainProgram = "vci";
    platforms = lib.platforms.linux;
  };
}
