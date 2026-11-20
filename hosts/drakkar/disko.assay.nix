# Colocated suite for hosts/drakkar/disko.nix.
#
# The layout is evaluated through the real disko module (pinned from flake.lock), so the claims
# read the fileSystems and initrd LUKS entries disko actually generates for this host rather
# than the text of its layout. A refactor through a helper binding keeps them passing; a layout
# that would mount `/` somewhere else fails them.
#
# Full-disk encryption here is the evidence for Anduril NixOS STIG V-268144 ("must protect the
# confidentiality and integrity of all information at rest", CAT I): that control is decided by
# the disk layout rather than by any NixOS option, and
# features/security/stig/profiles/base-safe.nix cites this suite via
# `security.stig.satisfiedExternally`.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {
    modules = [nixos.flakeInputs.disko.nixosModules.disko ./disko.nix];
    settings.hostname = "drakkar";
  };
  fs = cfg.fileSystems;
  luks = cfg.boot.initrd.luks.devices;
  ssd = cfg.disko.devices.disk.ssd.content.partitions;
  subvolOf = mount: lib.findFirst (lib.hasPrefix "subvol=") null fs.${mount}.options;
in
  assay.suite "drakkar-disko" {
    # Exactly the mounts the layout promises: the system subvolumes, the ESP, and the HDD.
    mountSet = assay.eq (builtins.attrNames fs) ["/" "/boot" "/data" "/home" "/nix" "/var"];

    # V-268144: every system mount sits on the unlocked LUKS mapper, not a raw partition.
    systemMountsInsideLuks =
      assay.eq (map (m: fs.${m}.device) ["/" "/nix" "/home" "/var"])
      ["/dev/mapper/cryptroot" "/dev/mapper/cryptroot" "/dev/mapper/cryptroot" "/dev/mapper/cryptroot"];
    unlocksSsdLuksPartition = assay.eq luks.cryptroot.device "/dev/disk/by-partlabel/disk-ssd-luks";
    # No keyfile baked into the world-readable store: the passphrase is entered at boot.
    noKeyFileInStore = assay.eq luks.cryptroot.keyFile null;
    # dm-crypt skips its kcryptd workqueues on the NVMe: lower latency under write bursts,
    # where fsync() callers otherwise stall behind the queue.
    bypassesCryptWorkqueues = assay.eq luks.cryptroot.bypassWorkqueues true;

    rootIsBtrfs = assay.eq fs."/".fsType "btrfs";
    # Each system mount is its own subvolume, so /nix, /home and /var snapshot independently.
    subvolumePerMount = assay.eq (lib.genAttrs ["/" "/nix" "/home" "/var"] subvolOf) {
      "/" = "subvol=@root";
      "/nix" = "subvol=@nix";
      "/home" = "subvol=@home";
      "/var" = "subvol=@var";
    };

    # The btrfs filesystem under LUKS must have no top-level mountpoint. With one, disko mounts
    # subvolid 5 at the mount root during install — it wins the attrset collision against the
    # @root subvolume mount — so nixos-install writes `/` into the bare volume while the
    # installed system boots with subvol=@root.
    btrfsHasNoTopLevelMountpoint = assay.eq ssd.luks.content.content.mountpoint null;
    rootDeclaredOnce =
      assay.eq (builtins.length (lib.catAttrs "/" cfg.disko.devices._config.fileSystems.contents)) 1;

    # The ESP cannot be encrypted, so its permissions carry the weight instead.
    espPartitionType = assay.eq ssd.boot.type "EF00";
    bootIsVfat = assay.eq fs."/boot".fsType "vfat";
    bootIsOwnerOnly = assay.eq (builtins.elem "umask=0077" fs."/boot".options) true;

    # The HDD carries one btrfs volume at /data (no subvolumes, so its mountpoint is safe).
    dataOnHdd = assay.eq fs."/data".device "/dev/disk/by-partlabel/disk-hdd-data";
    dataIsBtrfs = assay.eq fs."/data".fsType "btrfs";

    # Install targets: formatting the wrong device is the one mistake this file can make.
    diskDevices = assay.eq (lib.mapAttrs (_: d: d.device) cfg.disko.devices.disk) {
      ssd = "/dev/nvme0n1";
      hdd = "/dev/sda";
    };
  }
