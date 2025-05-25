# Make the cl tool available in the system.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "cl";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  meta = with lib; {
    description = "A simple terminal clear command written in Rust";
    homepage = "";
    license = licenses.mit;
    maintainers = [];
  };
}
