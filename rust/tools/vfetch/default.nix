# vfetch as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vfetch takes nix-store-core as a path dependency (`../nix-store-core`), so the
# source is rooted at rust/tools and holds both crates; cargoRoot and
# buildAndTestSubdir point the build at this one.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vfetch";
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

  cargoRoot = "vfetch";
  buildAndTestSubdir = "vfetch";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite (bundled SQLite), liblzma-sys and zstd-sys build their vendored C
  # sources, and id_effect_platform's reqwest reaches rustls and so aws-lc-sys.
  # nixpkgs' cargoUseSystemLibs hook would have them link system libraries that
  # are not in the build inputs (`ld: cannot find -lsqlite3`); build the
  # vendored sources instead, as rust/tools/vcache does.
  dontCargoUseSystemLibs = true;

  # vfetch's own tests run here: whole runs against an in-memory fake cache,
  # with a staging directory under $TMPDIR. nix-store-core's run in its own
  # package.

  meta = {
    description = "Concurrent closure substitution from Nix binary caches (a faster nix copy --from)";
    license = lib.licenses.mit;
    mainProgram = "vfetch";
    platforms = lib.platforms.linux;
  };
}
