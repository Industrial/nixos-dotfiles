# vswitch as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vswitch links vdeploy (its apply transaction), vdiff and, through both,
# nix-store-core by path, so the source is rooted at rust/tools and holds all
# four crates; cargoRoot and buildAndTestSubdir point the build at this one.
{
  lib,
  rustPlatform,
  git,
}:
rustPlatform.buildRustPackage {
  pname = "vswitch";
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

  cargoRoot = "vswitch";
  buildAndTestSubdir = "vswitch";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite (through vdiff and nix-store-core's db) builds its bundled SQLite.
  # nixpkgs' cargoUseSystemLibs hook would have it link a system libsqlite3 that
  # is not among the build inputs (`ld: cannot find -lsqlite3`); build the
  # bundled sources instead, as vdeploy and vcache do.
  dontCargoUseSystemLibs = true;

  # The eval cache's clean-checkout test (GH-243) runs real git on a scratch repository
  # under $TMPDIR; git wants a HOME it can read.
  nativeCheckInputs = [git];
  preCheck = ''
    export HOME="$TMPDIR"
  '';

  meta = {
    description = "Local NixOS rebuild: build through vmon, closure diff with vdiff, then vdeploy's health-checked apply with rollback (replaces nixos-rebuild and nh)";
    license = lib.licenses.mit;
    mainProgram = "vswitch";
    platforms = lib.platforms.linux;
  };
}
