# Colocated suite for hosts/drakkar/filesystems.nix.
#
# This module carries what the disko layout cannot: the storage drivers the initrd needs to
# reach the disks, btrfs support, scrubbing of the /data HDD, and the directories living on it.
# Claims read the evaluated NixOS config; the scrub target is additionally checked against the
# mounts ./disko.nix really generates, since a scrub of a path that is not a btrfs mount fails
# monthly and silently.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {
    modules = [./filesystems.nix];
    settings.hostname = "drakkar";
  };

  withDisko = nixos.eval {
    modules = [nixos.flakeInputs.disko.nixosModules.disko ./disko.nix ./filesystems.nix];
    settings.hostname = "drakkar";
  };

  initrd = cfg.boot.initrd.availableKernelModules;
  scrub = cfg.services.btrfs.autoScrub;
in
  assay.suite "drakkar-filesystems" {
    # The root disk is NVMe and /data is a SATA HDD: without these drivers the initrd cannot see
    # the LUKS partition (nvme) or the data disk (ahci), and boot waits forever for a device.
    initrdHasNvme = assay.eq (builtins.elem "nvme" initrd) true;
    initrdHasAhci = assay.eq (builtins.elem "ahci" initrd) true;

    loadsKvmAmd = assay.eq (builtins.elem "kvm-amd" cfg.boot.kernelModules) true;
    supportsBtrfs = assay.eq (cfg.boot.supportedFilesystems.btrfs or false) true;

    # Monthly scrub of the HDD, the one volume with no other integrity check.
    scrubsData = assay.subset scrub {
      enable = true;
      fileSystems = ["/data"];
      interval = "monthly";
    };
    scrubTargetIsBtrfsMount = assay.eq withDisko.fileSystems."/data".fsType "btrfs";

    # Cache and the local game root live on /data, owned by the user.
    dataDirectories = assay.eq (builtins.filter (lib.hasPrefix "d /data/") cfg.systemd.tmpfiles.rules) [
      "d /data/cache 0755 tom users -"
      "d /data/Games 0755 tom users -"
    ];

    # Mounts are disko's job; this module must not declare any of its own.
    addsNoMounts = assay.eq (builtins.attrNames cfg.fileSystems) (builtins.attrNames nixos.baseline.fileSystems);
  }
