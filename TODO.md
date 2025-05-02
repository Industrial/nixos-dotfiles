

Sure! Below is a complete, production-grade Markdown document you can save into your flake repo (e.g., docs/remote-nixos-nas-setup.md). It includes:

    Disko layout with LUKS, RAID5, swap

    NixOS integration with impermanence and hibernation

    Explanation for each part

Remote NixOS NAS Setup with Disko, LUKS, Btrfs RAID5, Hibernate & Impermanence

    Author: YourName
    Date: 2025-05-01
    Usage: Remote install or reprovisioning of NixOS NAS using flakes + disko + nixos-anywhere

Overview

This guide walks through a remote-installable NixOS NAS configuration using:

    LUKS encryption on SSD and RAID

    btrfs RAID5 on 4× HDDs

    Hibernate support with swap on encrypted SSD

    impermanence for ephemeral root with persistent state

    disko for declarative disk layout

    nixos-anywhere for remote installation over SSH

System Layout
Device	Role	Encryption	Notes
/dev/nvme0n1	System SSD	LUKS	Contains root, swap
/dev/sd[a-d]	4x HDDs	LUKS	Used in btrfs RAID5 /data
Disko Layout – hosts/mimir/disko.nix

{ config, lib, ... }:

{
  disko.devices = {
    disk = {
      ssd = {
        device = "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                content = {
                  type = "btrfs";
                  mountpoint = "/";
                  subvolumes = {
                    "@root" = { mountpoint = "/"; };
                    "@nix" = { mountpoint = "/nix"; };
                    "@persist" = { mountpoint = "/persist"; };
                  };
                };
              };
            };
          };
        };
      };

      hdds = {
        device = [ "/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" ];
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptdata";
                content = {
                  type = "btrfs";
                  mountpoint = "/data";
                  options = [ "nofail" "compress=zstd" ];
                  raid = {
                    level = 5;
                    devices = [
                      "/dev/mapper/cryptdata-a"
                      "/dev/mapper/cryptdata-b"
                      "/dev/mapper/cryptdata-c"
                      "/dev/mapper/cryptdata-d"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };

    luks = {
      cryptroot = {
        device = "/dev/nvme0n1p2";
        allowDiscards = true;
        keyFile = null;
      };

      cryptdata-a = { device = "/dev/sda1"; };
      cryptdata-b = { device = "/dev/sdb1"; };
      cryptdata-c = { device = "/dev/sdc1"; };
      cryptdata-d = { device = "/dev/sdd1"; };
    };

    swapDevices = [
      {
        device = "/dev/mapper/cryptroot";
        size = "8G";
        priority = 1;
        resumeDevice = true;
      }
    ];
  };
}

Host Configuration – hosts/mimir.nix

{ ... }:

{
  imports = [
    ../common/base.nix
    ./disko.nix
  ];

  # Encrypted root and data
  boot.initrd.luks.devices = {
    cryptroot.device = "/dev/nvme0n1p2";
    cryptdata-a.device = "/dev/sda1";
    cryptdata-b.device = "/dev/sdb1";
    cryptdata-c.device = "/dev/sdc1";
    cryptdata-d.device = "/dev/sdd1";
  };

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Resume from swap (hibernation)
  boot.resumeDevice = "/dev/mapper/cryptroot";

  # Impermanence support
  environment.persistence."/persist" = {
    directories = [
      "/etc/nixos"
      "/var/lib"
      "/var/log"
      "/home"
    ];
    files = [
      "/etc/machine-id"
    ];
  };

  fileSystems."/persist".neededForBoot = true;

  # Btrfs scrub on /data
  services.btrfs.autoScrub.enable = true;
  services.btrfs.autoScrub.fileSystems = [ "/data" ];

  # SSH for remote access
  services.openssh.enable = true;
  users.users.youruser = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3Nz..." ];
  };

  system.stateVersion = "24.05";
}

Installation Instructions
Option A: Manual via Live ISO

    Boot your NAS with a NixOS live USB.

    Enable SSH:

systemctl start sshd
passwd

SSH into the machine and run:

    git clone <your-flake>
    cd your-flake
    nix run github:nix-community/disko -- --mode disko .#mimir
    nixos-install --flake .#mimir
    reboot

Option B: Remote Install via nixos-anywhere

From your main workstation:

nix run github:nix-community/nixos-anywhere -- --flake ./#mimir root@nas-ip

This performs:

    Full disk setup (via Disko)

    NixOS install with your flake config

    Reboot into the system

Testing and Safety Tips

    Test this layout in QEMU before touching your NAS.

    Use nixos-rebuild boot instead of switch when testing new flakes.

    Enable boot entries for rollback.

    Set nofail on /data to avoid boot lock if the RAID is disconnected.

    Keep a minimal /etc/nixos config as a fallback rescue option.

References

    Disko GitHub

    nixos-anywhere

    impermanence