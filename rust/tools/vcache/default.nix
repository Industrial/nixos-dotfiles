# vcache as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vcache takes nix-store-core as a path dependency (`../nix-store-core`), so the
# source is rooted at rust/tools and holds both crates; cargoRoot and
# buildAndTestSubdir point the build at this one.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vcache";
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

  cargoRoot = "vcache";
  buildAndTestSubdir = "vcache";
  cargoLock.lockFile = ./Cargo.lock;

  # id_effect_axum reaches rustls (via id_effect_platform's reqwest), and so
  # aws-lc-sys. nixpkgs' cargoUseSystemLibs hook would have aws-lc-sys look for
  # a system AWS-LC that is not there; build its vendored sources instead — the
  # same escape hatch features/nixos/default.nix applies to other packages.
  dontCargoUseSystemLibs = true;

  # vcache's own tests run here; nix-store-core's run in its own package. The
  # store tests need this machine's /nix/var/nix/db; in the sandbox they find
  # none and pass vacuously.

  meta = {
    description = "A Nix binary cache server (narinfo + NAR over HTTP) that reads the local store read-only";
    license = lib.licenses.mit;
    mainProgram = "vcache";
    platforms = lib.platforms.linux;
  };
}
