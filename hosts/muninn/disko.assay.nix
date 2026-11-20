# Colocated suite for hosts/muninn/disko.nix.
#
# Evaluated through the real disko module (pinned from flake.lock): claims read the fileSystems
# and initrd LUKS entries disko generates, not the layout's text. Same fleet-standard shape as
# drakkar minus the HDD; full-disk encryption here is this host's evidence for Anduril NixOS
# STIG V-268144 (information at rest, CAT I), which the disk layout decides rather than any
# NixOS option.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {
    modules = [nixos.flakeInputs.disko.nixosModules.disko ./disko.nix];
    settings.hostname = "muninn";
  };
  fs = cfg.fileSystems;
  luks = cfg.boot.initrd.luks.devices;
  ssd = cfg.disko.devices.disk.ssd.content.partitions;
  subvolOf = mount: lib.findFirst (lib.hasPrefix "subvol=") null fs.${mount}.options;
in
  assay.suite "muninn-disko" {
    mountSet = assay.eq (builtins.attrNames fs) ["/" "/boot" "/home" "/nix" "/var"];

    # V-268144: every system mount sits on the unlocked LUKS mapper.
    systemMountsInsideLuks =
      assay.eq (map (m: fs.${m}.device) ["/" "/nix" "/home" "/var"])
      ["/dev/mapper/cryptroot" "/dev/mapper/cryptroot" "/dev/mapper/cryptroot" "/dev/mapper/cryptroot"];
    unlocksSsdLuksPartition = assay.eq luks.cryptroot.device "/dev/disk/by-partlabel/disk-ssd-luks";
    # No keyfile baked into the world-readable store: the passphrase is entered at boot.
    noKeyFileInStore = assay.eq luks.cryptroot.keyFile null;

    rootIsBtrfs = assay.eq fs."/".fsType "btrfs";
    subvolumePerMount = assay.eq (lib.genAttrs ["/" "/nix" "/home" "/var"] subvolOf) {
      "/" = "subvol=@root";
      "/nix" = "subvol=@nix";
      "/home" = "subvol=@home";
      "/var" = "subvol=@var";
    };

    # No top-level btrfs mountpoint: with one, disko mounts subvolid 5 at the mount root during
    # install and nixos-install writes `/` into the bare volume while the installed system
    # boots with subvol=@root.
    btrfsHasNoTopLevelMountpoint = assay.eq ssd.luks.content.content.mountpoint null;
    rootDeclaredOnce =
      assay.eq (builtins.length (lib.catAttrs "/" cfg.disko.devices._config.fileSystems.contents)) 1;

    # The ESP cannot be encrypted, so its permissions carry the weight instead.
    espPartitionType = assay.eq ssd.boot.type "EF00";
    bootIsVfat = assay.eq fs."/boot".fsType "vfat";
    bootIsOwnerOnly = assay.eq (builtins.elem "umask=0077" fs."/boot".options) true;

    diskDevices = assay.eq (lib.mapAttrs (_: d: d.device) cfg.disko.devices.disk) {ssd = "/dev/nvme0n1";};
  }
