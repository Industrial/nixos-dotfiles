# Colocated suite for hosts/muninn/disko.nix.
#
# Same shape as the huginn suite: asserts full-disk encryption, which is where Anduril NixOS
# STIG V-268144 (information at rest, CAT I) is actually decided for this host.
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./disko.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "muninn-disko" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;

    # V-268144.
    encryptsAtRest = assay.eq (has ".*type = \"luks\";.*") true;
    namesCryptroot = assay.eq (has ".*name = \"cryptroot\";.*") true;
    noKeyFileInStore = assay.eq (has ".*keyFile = null;.*") true;

    bootIsOwnerOnly = assay.eq (has ".*umask=0077.*") true;

    btrfsRootInsideLuks = assay.eq (has ".*type = \"btrfs\";.*") true;
    separatesNixAndHomeSubvolumes =
      assay.eq (has ".*\"@nix\".*" && has ".*\"@home\".*") true;

    # The btrfs filesystem must have no top-level mountpoint. With one, disko mounts subvolid 5
    # at the mount root during install — it wins the attrset collision against the @root
    # subvolume mount — so nixos-install writes `/` into the bare volume while the installed
    # system boots with subvol=@root.
    rootMountedViaSubvolumeOnly =
      assay.eq (has ".*type = \"btrfs\";[[:space:]]*mountpoint = \"/\";.*") false;
  }
