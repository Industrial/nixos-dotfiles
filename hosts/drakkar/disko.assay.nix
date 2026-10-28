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
  }
