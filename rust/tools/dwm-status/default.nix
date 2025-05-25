# Make the dwm-status tool available in the system.
{
  lib,
  pkgs,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "dwm-status";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [
    pkgs.pkg-config
  ];
  buildInputs = [
    pkgs.xorg.libxcb
  ];
  meta = with lib; {
    description = "Status bar generator for DWM";
    homepage = "https://github.com/Industrial";
    license = licenses.mit;
    maintainers = [];
  };
}
