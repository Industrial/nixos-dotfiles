# Mimir system configuration (file server)
{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./filesystems.nix
    ./hardware.nix
    ../../profiles/server.nix
  ];
}
