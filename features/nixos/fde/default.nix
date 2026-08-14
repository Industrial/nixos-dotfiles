{ config, lib, pkgs, settings, ... }:

{
  # Full Disk Encryption (FDE) configuration
  # This configuration enables LUKS encrypted root partition

  # Enable LUKS encryption for the root device
  boot.initrd.luks.devices = {
    root = {
      device = "LABEL=nixos-root";
      allowDiscards = true;
    };
  };

  # Configure LUKS actions for early unlock
  boot.initrd.luks.actions = {
    root = {
      # Schedule LUKS unlock during early initrd phase
      # The actual passphrase is provided via cmdline or /etc/crypttab
    };
  };

  # Add crypttab entry for manual LUKS mappings
  # services.cryptocfg = {
  #   enable = true;
  #   config = {
  #     root = {
  #       device = "/dev/disk/by-uuid/${settings.uuid}";
  #     };
  #   };
  # };
}