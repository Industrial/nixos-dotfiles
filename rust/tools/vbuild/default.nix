# vbuild as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vbuild takes nix-store-core as a path dependency (`../nix-store-core`), so the
# source is rooted at rust/tools and holds both crates; cargoRoot and
# buildAndTestSubdir point the build at this one.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vbuild";
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

  cargoRoot = "vbuild";
  buildAndTestSubdir = "vbuild";
  cargoLock.lockFile = ./Cargo.lock;

  # nix-store-core links rusqlite with its bundled SQLite (libsqlite3-sys).
  # nixpkgs' cargoUseSystemLibs hook would have it link a system -lsqlite3
  # that is not in the build inputs; build the bundled sources instead, as
  # rust/tools/vcache/default.nix does.
  dontCargoUseSystemLibs = true;

  # vbuild's own tests run here (protocol, selection, slots, the hook flow
  # against fakes); nix-store-core's run in its own package.

  meta = {
    description = "A load-aware Nix build hook: build-remote's protocol, builders ranked by live load, fast declines when none answers";
    license = lib.licenses.mit;
    mainProgram = "vbuild";
    platforms = lib.platforms.linux;
  };
}
