# vwhy as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vwhy takes nix-store-core and vdiff (for its package-name parser) as path
# dependencies, so the source is rooted at rust/tools and holds all three
# crates; cargoRoot and buildAndTestSubdir point the build at this one.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vwhy";
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

  cargoRoot = "vwhy";
  buildAndTestSubdir = "vwhy";
  cargoLock.lockFile = ./Cargo.lock;

  # rusqlite (through nix-store-core's db) is built with its bundled SQLite.
  # nixpkgs' cargoUseSystemLibs hook would have libsqlite3-sys link a system
  # libsqlite3 that is not in the build inputs (`ld: cannot find -lsqlite3`);
  # build the vendored sources instead, as vcache does.
  dontCargoUseSystemLibs = true;

  # vwhy's own tests run here. The ones that read this machine's
  # /nix/var/nix/db or /run/current-system have neither in the sandbox and
  # pass vacuously; the graph, rendering and in-memory database cases need no
  # store.

  meta = {
    description = "Why one Nix store path depends on another, and what a closure's size is made of (replaces nix why-depends and nix-tree)";
    license = lib.licenses.mit;
    mainProgram = "vwhy";
    platforms = lib.platforms.linux;
  };
}
