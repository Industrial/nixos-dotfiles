# vhealth as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here.
#
# vhealth has no path dependencies, so the source is the crate alone. Nothing in
# its closure links a C library (no rusqlite, no rustls), so the
# cargoUseSystemLibs hook is left as it is.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vhealth";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./build.rs
      ./src
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  # The tests run here, in the sandbox: TCP and unix-socket probes against
  # listeners on loopback, command probes against coreutils (true, false, sleep),
  # file probes against the build's own filesystem.

  meta = {
    description = "Service health probes run concurrently with timeouts: a CLI, a library and a node_exporter textfile daemon";
    license = lib.licenses.mit;
    mainProgram = "vhealth";
    platforms = lib.platforms.linux;
  };
}
