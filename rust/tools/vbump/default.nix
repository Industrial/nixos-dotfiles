# vbump as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vbump takes vdiff (the closure diff, as a library) and nix-store-core by path
# (`../vdiff`, `../nix-store-core`), so the source is rooted at rust/tools and
# holds all three crates; cargoRoot and buildAndTestSubdir point the build at
# this one.
{
  lib,
  rustPlatform,
  git,
}:
rustPlatform.buildRustPackage {
  pname = "vbump";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./..;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./build.rs
      ./src
      ../vdiff/Cargo.toml
      ../vdiff/build.rs
      ../vdiff/src
      ../nix-store-core/Cargo.toml
      ../nix-store-core/build.rs
      ../nix-store-core/src
    ];
  };

  cargoRoot = "vbump";
  buildAndTestSubdir = "vbump";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite (through vdiff and nix-store-core's db) builds its bundled SQLite.
  # nixpkgs' cargoUseSystemLibs hook would have it link a system libsqlite3 that
  # is not among the build inputs (`ld: cannot find -lsqlite3`); build the
  # bundled sources instead, as vcache does.
  dontCargoUseSystemLibs = true;

  # The forge test builds a proposal's commit with git plumbing and pushes it to
  # a bare repository under $TMPDIR; git wants a HOME it can read.
  nativeCheckInputs = [git];
  preCheck = ''
    export HOME="$TMPDIR"
  '';

  meta = {
    description = "Per-input flake.lock updates: relock one input, evaluate and dry-build every host, diff each host's closure, open one pull request per input";
    license = lib.licenses.mit;
    mainProgram = "vbump";
    platforms = lib.platforms.linux;
  };
}
