# Colocated suite for hosts/drakkar/disko.nix
#
# Upgraded from a bare non-empty check: this now asserts full-disk encryption, which is where
# Anduril NixOS STIG V-268144 ("must protect the confidentiality and integrity of all
# information at rest", CAT I) is actually decided. That control is satisfied by the disk
# layout rather than by any NixOS option, so this file is its evidence, and
# features/security/stig/profiles/base-safe.nix cites it via
# `security.stig.satisfiedExternally`.
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./disko.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "drakkar-disko" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;

    # V-268144.
    encryptsAtRest = assay.eq (has ".*type = \"luks\";.*") true;
    noKeyFileInStore = assay.eq (has ".*keyFile = null;.*") true;

    # The ESP cannot be encrypted, so its permissions carry the weight instead.
    bootIsOwnerOnly = assay.eq (has ".*umask=0077.*") true;

    # The btrfs filesystem under LUKS must have no top-level mountpoint. With one, disko mounts
    # subvolid 5 at the mount root during install — it wins the attrset collision against the
    # @root subvolume mount — so nixos-install writes `/` into the bare volume while the
    # installed system boots with subvol=@root. The /data volume keeps its mountpoint: it
    # declares no subvolumes, so there is no collision to lose.
    rootMountedViaSubvolumeOnly =
      assay.eq (has ".*type = \"btrfs\";[[:space:]]*mountpoint = \"/\";.*") false;
  }
