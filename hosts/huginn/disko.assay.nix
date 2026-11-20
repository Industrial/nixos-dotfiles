# Colocated suite for hosts/huginn/disko.nix.
#
# Evaluated through the real disko module (pinned from flake.lock): claims read the fileSystems,
# swapDevices and initrd LUKS entries disko generates, not the layout's text. The old suite had
# to count `compress=zstd` occurrences in comment-stripped source to approximate "only the data
# subvolumes are compressed"; the evaluated mount options state it directly.
#
# Full-disk encryption here is this host's evidence for Anduril NixOS STIG V-268144
# (information at rest, CAT I). The tablet-specific departures (compression, noatime, a
# hibernation swapfile) are each a deliberate choice that a copy-paste from another host would
# silently undo, so each gets a claim.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {
    modules = [nixos.flakeInputs.disko.nixosModules.disko ./disko.nix];
    settings.hostname = "huginn";
  };
  fs = cfg.fileSystems;
  luks = cfg.boot.initrd.luks.devices;
  ssd = cfg.disko.devices.disk.ssd.content.partitions;
  btrfs = ssd.luks.content.content;
  subvolOf = mount: lib.findFirst (lib.hasPrefix "subvol=") null fs.${mount}.options;
  dataMounts = ["/" "/nix" "/home" "/var"];
  btrfsMounts = dataMounts ++ ["/swap"];
  hasOpt = opt: mount: builtins.elem opt fs.${mount}.options;
in
  assay.suite "huginn-disko" {
    mountSet = assay.eq (builtins.attrNames fs) ["/" "/boot" "/home" "/nix" "/swap" "/var"];

    # V-268144: every btrfs mount, swap included, sits on the unlocked LUKS mapper — a swapfile
    # outside it would write RAM contents to disk in the clear on every hibernate.
    btrfsMountsInsideLuks =
      assay.eq (lib.unique (map (m: fs.${m}.device) btrfsMounts)) ["/dev/mapper/cryptroot"];
    unlocksSsdLuksPartition = assay.eq luks.cryptroot.device "/dev/disk/by-partlabel/disk-ssd-luks";
    # No keyfile baked into the world-readable store: the passphrase is entered at boot.
    noKeyFileInStore = assay.eq luks.cryptroot.keyFile null;

    rootIsBtrfs = assay.eq fs."/".fsType "btrfs";
    subvolumePerMount = assay.eq (lib.genAttrs btrfsMounts subvolOf) {
      "/" = "subvol=@root";
      "/nix" = "subvol=@nix";
      "/home" = "subvol=@home";
      "/var" = "subvol=@var";
      "/swap" = "subvol=@swap";
    };

    # Smallest disk in the fleet and the development scratch disk: compression buys capacity
    # and fewer NVMe writes.
    compressesDataSubvolumes = assay.eq (builtins.all (hasOpt "compress=zstd") dataMounts) true;
    # Nothing reads atimes, and every atime update is a write.
    noatimeOnEveryBtrfsMount = assay.eq (builtins.all (hasOpt "noatime") btrfsMounts) true;
    # @swap stays uncompressed, so a working swapfile never depends on mkswapfile's per-file
    # NODATACOW flag surviving a future edit.
    swapMountUncompressed =
      assay.eq (builtins.filter (lib.hasPrefix "compress") fs."/swap".options) [];

    # Hibernation: the swapfile disko creates is what the system swaps to, and it is large
    # enough for the StarLite 5's 16G of RAM plus headroom.
    swapsToSwapfile = assay.eq (map (s: s.device) cfg.swapDevices) ["/swap/swapfile"];
    swapfileFitsRam = assay.eq btrfs.subvolumes."@swap".swap.swapfile.size "20G";

    # No top-level btrfs mountpoint: with one, disko mounts subvolid 5 at the mount root during
    # install and nixos-install writes `/` into the bare volume while the installed system
    # boots with subvol=@root.
    btrfsHasNoTopLevelMountpoint = assay.eq btrfs.mountpoint null;
    rootDeclaredOnce =
      assay.eq (builtins.length (lib.catAttrs "/" cfg.disko.devices._config.fileSystems.contents)) 1;

    # The ESP cannot be encrypted, so its permissions carry the weight instead.
    espPartitionType = assay.eq ssd.boot.type "EF00";
    bootIsVfat = assay.eq fs."/boot".fsType "vfat";
    bootIsOwnerOnly = assay.eq (builtins.elem "umask=0077" fs."/boot".options) true;

    # One soldered-in NVMe, no second disk.
    diskDevices = assay.eq (lib.mapAttrs (_: d: d.device) cfg.disko.devices.disk) {ssd = "/dev/nvme0n1";};
  }
