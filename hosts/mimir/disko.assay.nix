# Colocated suite for hosts/mimir/disko.nix
#
# Upgraded from a bare non-empty check to assert full-disk encryption — Anduril NixOS STIG
# V-268144 (information at rest, CAT I), which the disk layout decides rather than any NixOS
# option. See hosts/drakkar/disko.assay.nix for the reasoning and
# features/security/stig/profiles/base-safe.nix for where this evidence is cited.
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./disko.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "mimir-disko" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;

    # V-268144.
    encryptsAtRest = assay.eq (has ".*type = \"luks\";.*") true;
    noKeyFileInStore = assay.eq (has ".*keyFile = null;.*") true;

    bootIsOwnerOnly = assay.eq (has ".*umask=0077.*") true;
  }
