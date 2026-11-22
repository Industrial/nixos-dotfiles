# vdeploy as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vdeploy takes vdiff (the closure diff, as a library) and nix-store-core by path
# (`../vdiff`, `../nix-store-core`), so the source is rooted at rust/tools and
# holds all three crates; cargoRoot and buildAndTestSubdir point the build at
# this one.
{
  lib,
  rustPlatform,
  git,
  gnupg,
}:
rustPlatform.buildRustPackage {
  pname = "vdeploy";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./..;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./build.rs
      ./src
      # GH-221: the pinned GitHub key (features/nix/vdeploy's trustedSigningKeys), and the
      # signature tests' data (a real GitHub-signed commit of main, another GitHub key).
      ./keys
      ./testdata
      ../vdiff/Cargo.toml
      ../vdiff/build.rs
      ../vdiff/src
      ../nix-store-core/Cargo.toml
      ../nix-store-core/build.rs
      ../nix-store-core/src
    ];
  };

  cargoRoot = "vdeploy";
  buildAndTestSubdir = "vdeploy";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite (through vdiff and nix-store-core's db) builds its bundled SQLite.
  # nixpkgs' cargoUseSystemLibs hook would have it link a system libsqlite3 that
  # is not among the build inputs (`ld: cannot find -lsqlite3`); build the
  # bundled sources instead, as vcache does.
  dontCargoUseSystemLibs = true;

  # The source and dotfiles tests run real git on scratch repositories under
  # $TMPDIR; git wants a HOME it can read. The signature tests run gpgv (and gpg --dearmor
  # to make their keyrings, as features/nix/vdeploy does).
  nativeCheckInputs = [git gnupg];
  preCheck = ''
    export HOME="$TMPDIR"
  '';

  meta = {
    description = "Pull-based deploy agent: poll main, verify the commit, evaluate and realise this host's system, diff it against the running one; in observe mode log the switch, in deploy mode make it with a health check and rollback";
    license = lib.licenses.mit;
    mainProgram = "vdeploy";
    platforms = lib.platforms.linux;
  };
}
