# Make the oomkiller tool available in the system.
{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "oomkiller";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  meta = with lib; {
    description = "A daemon that monitors system memory and kills the highest memory-consuming process when memory usage exceeds 90%";
    homepage = "";
    license = licenses.mit;
    maintainers = [];
  };
}
