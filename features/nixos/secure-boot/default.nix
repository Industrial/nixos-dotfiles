{ config, lib, pkgs, settings, ... }:

{
  # Secure Boot configuration
  # Enables UEFI Secure Boot with systemd-boot as the bootloader

  boot.loader.systemd-boot.enable = true;
  boot.loader.secureBoot.enable = true;
  boot.loader.secureBoot.bitlocker = false;

  # Configure secure boot to use systemd-boot
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable modsecureboot for additional security
  # This requires MokManager to be set up for key enrollment
}
