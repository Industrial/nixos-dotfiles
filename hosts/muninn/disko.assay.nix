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
  }
