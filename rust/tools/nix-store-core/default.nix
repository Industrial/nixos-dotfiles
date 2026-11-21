# nix-store-core as a Nix package: buildRustPackage over the library, so the
# derivation is its test run (cargo test in checkPhase, golden fixtures
# included). It installs nothing; consumers take the crate as a Cargo path
# dependency and put ../nix-store-core in their own source (see vcache).
#
# The tests that read this machine's store (/nix/store, /nix/var/nix/db) find
# none in the sandbox and pass vacuously; the fixture-only ones run in full.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "nix-store-core";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./build.rs
      ./src
      ./tests/fixtures
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  # A library: nothing to install but the proof that it built and passed.
  postInstall = ''
    mkdir -p $out
    echo "nix-store-core: tests passed" > $out/passed
  '';

  meta = {
    description = "Nix store primitives in Voltaic: store paths, nix32, hashes, NAR, narinfo, signing, .drv and the store database";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
