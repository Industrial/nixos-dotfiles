# Remote NixOS NAS Setup with Disko, LUKS, Btrfs RAID5, Hibernate & Impermanence

> Author: YourName  
> Date: 2025-05-01  
> Usage: Remote install or reprovisioning of NixOS NAS using flakes + disko + nixos-anywhere

## Overview

This guide walks through a remote-installable NixOS NAS configuration using:

- LUKS encryption on SSD and RAID
- btrfs RAID5 on 4× HDDs
- Hibernate support with swap on encrypted SSD
- `impermanence` for ephemeral root with persistent state
- `disko` for declarative disk layout
- `nixos-anywhere` for remote installation over SSH

[...]

## References

- [Disko GitHub](https://github.com/nix-community/disko)
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
- [impermanence](https://github.com/nix-community/impermanence)
"""

secure_hardening_nix = """
# lib/profiles/hardening.nix
#
# Hardened NixOS profile for maximum security.

{ config, lib, pkgs, ... }:

let
  fido2User = "youruser";  # Change this to your actual user
in
{
  imports = [
    <nixpkgs/nixos/modules/security/apparmor.nix>
  ];

  security.apparmor.enable = true;
  security.apparmor.profiles = "complain";

  boot.kernelParams = [ "lockdown=confidentiality" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  security.secureBoot.enable = true;
  security.secureBoot.signing.keyPath = "/etc/secureboot/db.key";
  security.secureBoot.signing.certPath = "/etc/secureboot/db.crt";

  boot.initrd.luks.devices = {
    cryptroot.tpm2Device = "/dev/tpmrm0";
  };

  security.pam.u2f.enable = true;
  security.pam.u2f.control = "required";
  security.pam.u2f.authFile = "/etc/u2f_keys";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
    };
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
    flake = "github:youruser/yourflake";
    dates = "03:00";
  };

  services.auditd.enable = true;

  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_hardlinks" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.tcp_syncookies" = 1;
  };

  services.avahi.enable = false;
  services.printing.enable = false;

  fileSystems."/nix".options = [ "noexec" "nodev" "nosuid" ];
}
"""
