# Colocated suite for hosts/mimir/disko.nix.
#
# Evaluated through the real disko module (pinned from flake.lock): claims read what disko
# generates (fileSystems, initrd LUKS, partition devices) rather than the layout's text. The
# old suite counted `raid5Member "` occurrences in comment-stripped source; the evaluated disk
# set states the same invariants directly and survives a refactor of the helper.
#
# Full-disk encryption of the system SSD is this host's evidence for Anduril NixOS STIG
# V-268144 (information at rest, CAT I). Mimir also carries the fleet's only multi-device volume
# — the four-disk btrfs RAID5 holding ~55 TB at /data — so most claims guard that it stays one
# array, created once on the last disk, rather than reverting to four single-disk filesystems.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {
    modules = [nixos.flakeInputs.disko.nixosModules.disko ./disko.nix];
    settings.hostname = "mimir";
  };
  fs = cfg.fileSystems;
  luks = cfg.boot.initrd.luks.devices;
  disks = cfg.disko.devices.disk;
  ssd = disks.ssd.content.partitions;
  subvolOf = mount: lib.findFirst (lib.hasPrefix "subvol=") null fs.${mount}.options;

  hdds = builtins.filter (lib.hasPrefix "hdd-") (builtins.attrNames disks); # attrNames is sorted
  dataPart = name: disks.${name}.content.partitions.data;
  array = (dataPart "hdd-d").content;
  args = array.extraArgs;
  flag = f: builtins.elemAt args (lib.lists.findFirstIndex (a: a == f) null args + 1);
  # mkfs.btrfs <target> <extraArgs>: everything after the option flags is a further member.
  extraMembers = builtins.filter (lib.hasPrefix "/dev/") args;
in
  assay.suite "mimir-disko" {
    # /data is deliberately absent: ./filesystems.nix owns that mount, by label, and a second
    # definition here would collide on fileSystems."/data".device.
    mountSet = assay.eq (builtins.attrNames fs) ["/" "/boot" "/nix"];

    # V-268144: the system mounts sit on the unlocked LUKS mapper.
    systemMountsInsideLuks =
      assay.eq (map (m: fs.${m}.device) ["/" "/nix"]) ["/dev/mapper/cryptroot" "/dev/mapper/cryptroot"];
    unlocksSsdLuksPartition = assay.eq luks.cryptroot.device "/dev/disk/by-partlabel/disk-ssd-luks";
    noKeyFileInStore = assay.eq luks.cryptroot.keyFile null;

    rootIsBtrfs = assay.eq fs."/".fsType "btrfs";
    subvolumePerMount = assay.eq (lib.genAttrs ["/" "/nix"] subvolOf) {
      "/" = "subvol=@root";
      "/nix" = "subvol=@nix";
    };

    # No top-level btrfs mountpoint: with one, disko mounts subvolid 5 at the mount root during
    # install and nixos-install writes `/` into the bare volume while the installed system boots
    # with subvol=@root. Mimir feels this hardest: no @home or @var, so more lives in @root.
    btrfsHasNoTopLevelMountpoint = assay.eq ssd.luks.content.content.mountpoint null;
    rootDeclaredOnce =
      assay.eq (builtins.length (lib.catAttrs "/" cfg.disko.devices._config.fileSystems.contents)) 1;

    espPartitionType = assay.eq ssd.boot.type "EF00";
    bootIsOwnerOnly = assay.eq (builtins.elem "umask=0077" fs."/boot".options) true;

    hddDevices = assay.eq (lib.genAttrs hdds (n: disks.${n}.device)) {
      hdd-a = "/dev/sda";
      hdd-b = "/dev/sdb";
      hdd-c = "/dev/sdc";
      hdd-d = "/dev/sdd";
    };

    # One RAID5 volume for data and metadata, labelled `data`. The label is load-bearing:
    # ./filesystems.nix mounts /data by LABEL=data.
    arrayIsBtrfs = assay.eq array.type "btrfs";
    raid5Metadata = assay.eq (flag "-m") "raid5";
    raid5Data = assay.eq (flag "-d") "raid5";
    labelsVolumeData = assay.eq (flag "-L") "data";

    # The members passed to mkfs are exactly the partitions disko creates on the other three
    # disks — not hdd-d's own (the target would be passed twice), and by the partlabel disko
    # actually assigns, so a disk rename cannot leave a dangling path.
    extraMembersAreOtherDisks =
      assay.eq extraMembers (map (n: (dataPart n).device) ["hdd-a" "hdd-b" "hdd-c"]);

    # Members are created and labelled but never formatted on their own.
    membersCarryNoContent = assay.eq (map (n: (dataPart n).content) ["hdd-a" "hdd-b" "hdd-c"]) [null null null];

    # Ordering invariant: disko emits disks in attribute-name order and tracks no dependencies
    # for multi-device btrfs, so the only HDD that formats must sort last — after every member
    # partition exists — or mkfs.btrfs fails on a missing by-partlabel path.
    arrayOnLastHdd = assay.eq (builtins.filter (n: (dataPart n).content != null) hdds) [(lib.last hdds)];

    # Unmounted during install; ./filesystems.nix owns /data.
    arrayHasNoMountpoint = assay.eq array.mountpoint null;
  }
