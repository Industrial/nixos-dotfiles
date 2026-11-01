# Colocated suite for hosts/mimir/disko.nix
#
# Upgraded from a bare non-empty check to assert full-disk encryption — Anduril NixOS STIG
# V-268144 (information at rest, CAT I), which the disk layout decides rather than any NixOS
# option. See hosts/drakkar/disko.assay.nix for the reasoning and
# features/security/stig/profiles/base-safe.nix for where this evidence is cited.
#
# Mimir also carries the fleet's only multi-device volume — the four-disk btrfs RAID5 holding
# ~55 TB at /data — so most of what follows guards that it stays one array, created only when
# absent, rather than reverting to four separate single-disk filesystems.
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./disko.nix;
  has = pat: builtins.match pat src != null;

  # Counting assertions must not count prose in the comments.
  lines = builtins.filter builtins.isString (builtins.split "\n" src);
  code = builtins.concatStringsSep "\n" (
    builtins.filter (l: builtins.match "[[:space:]]*#.*" l == null) lines
  );
  # builtins.split returns 2n+1 elements for n matches.
  occurrences = pat: (builtins.length (builtins.split pat code) - 1) / 2;
in
  assay.suite "mimir-disko" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;

    # V-268144.
    encryptsAtRest = assay.eq (has ".*type = \"luks\";.*") true;
    namesCryptroot = assay.eq (has ".*name = \"cryptroot\";.*") true;
    noKeyFileInStore = assay.eq (has ".*keyFile = null;.*") true;

    bootIsOwnerOnly = assay.eq (has ".*umask=0077.*") true;
    btrfsRootInsideLuks = assay.eq (has ".*type = \"btrfs\";.*") true;

    # The /data array must be one RAID5 volume labelled `data`, not four filesystems. The label
    # is load-bearing: ./filesystems.nix mounts /data by LABEL=data, so losing it means the
    # mount fails and — absent nofail — the host boots to an emergency shell.
    declaresRaid5 =
      assay.eq (has ".*\"-m\" \"raid5\".*" && has ".*\"-d\" \"raid5\".*") true;
    labelsVolumeData = assay.eq (has ".*\"-L\" \"data\".*") true;

    # mkfs.btrfs takes one target device plus the rest as arguments, so exactly three of the
    # four members ride in extraArgs and the fourth is the target.
    membersCoverABC =
      assay.eq (
        has ".*disk-hdd-a-data.*"
        && has ".*disk-hdd-b-data.*"
        && has ".*disk-hdd-c-data.*"
      )
      true;
    # hdd-d is the mkfs target; naming it in extraArgs too would pass the same device twice.
    arrayTargetNotAlsoAMember = assay.eq (has ".*disk-hdd-d-data.*") false;

    # Three members are declared partition-only (content = null) via one shared helper, so
    # disko creates and labels their partitions but never formats them individually.
    threeUnformattedMembers = assay.eq (occurrences "raid5Member \"") 3;
    membersCarryNoContent = assay.eq (occurrences "content = null") 1;

    # Ordering invariant: disko emits disks in attribute-name order and tracks no dependencies
    # for multi-device btrfs, so the mkfs must sit on the alphabetically last disk — after
    # every member partition exists. If hdd-d became a plain member, the mkfs would move
    # earlier and fail on a missing by-partlabel path.
    arrayNotOnAPlainMember = assay.eq (has ".*raid5Member \"/dev/sdd\".*") false;

    # The btrfs filesystem must have no top-level mountpoint. With one, disko mounts subvolid 5
    # at the mount root during install — it wins the attrset collision against the @root
    # subvolume mount — so nixos-install writes `/` into the bare volume while the installed
    # system boots with subvol=@root. Mimir feels this hardest: it declares no @home or @var,
    # so more of the tree lives in @root.
    rootMountedViaSubvolumeOnly =
      assay.eq (has ".*type = \"btrfs\";[[:space:]]*mountpoint = \"/\";.*") false;
  }
