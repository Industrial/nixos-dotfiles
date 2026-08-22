# Huginn system configuration (tablet)
{...}: {
  imports = [
    ./filesystems.nix
    ./hardware.nix
    ../../profiles/mobile.nix
      ../../features/monitoring/prometheus-agent/default.nix
  ];
}
