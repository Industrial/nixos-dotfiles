# vagent as a Nix package (buildRustPackage, dependencies vendored from the
# checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a library,
# so no voltaic binary is needed here. features/ai/agent-vm wraps it with the
# host's absolute tool paths.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "vagent";
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

  meta = {
    description = "One microVM per agent session: start a slot, attach over vsock, export the branch, tear down";
    license = lib.licenses.mit;
    mainProgram = "vagent";
    platforms = lib.platforms.linux;
  };
}
