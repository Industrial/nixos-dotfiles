# Make the dwm-status tool available in the system.
{
  pkgs ? import <nixpkgs> {},
  rustPlatform ? pkgs.rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "dwm-status";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  # cargoSha256 = pkgs.lib.fakeSha256;
  doCheck = true;
  nativeBuildInputs = [
    pkgs.pkg-config
  ];
  buildInputs = [
    pkgs.xorg.libxcb
    pkgs.libpulseaudio
  ];
  meta = with pkgs.lib; {
    description = "Status bar generator for DWM";
    homepage = "https://github.com/Industrial";
    license = licenses.mit;
    maintainers = [];
  };
}
