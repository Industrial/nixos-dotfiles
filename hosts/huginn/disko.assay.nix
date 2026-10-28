# Colocated suite for hosts/huginn/disko.nix.
#
# Beyond the repo's usual non-empty smoke check, this asserts full-disk encryption. That is
# Anduril NixOS STIG V-268144 ("must protect the confidentiality and integrity of all
# information at rest", CAT I) — the one CAT I control whose answer lives in the disko layout
# rather than in a NixOS option, so this is where it can be proven.
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./disko.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "huginn-disko" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;

    # V-268144: the root filesystem sits inside a LUKS container.
    encryptsAtRest = assay.eq (has ".*type = \"luks\";.*") true;
    namesCryptroot = assay.eq (has ".*name = \"cryptroot\";.*") true;
    # No keyfile baked into the store — the passphrase is entered at boot.
    noKeyFileInStore = assay.eq (has ".*keyFile = null;.*") true;

    # The ESP cannot be encrypted, so its permissions carry the weight instead: umask 0077
    # keeps /boot unreadable to non-root.
    bootIsOwnerOnly = assay.eq (has ".*umask=0077.*") true;

    btrfsRootInsideLuks = assay.eq (has ".*type = \"btrfs\";.*") true;
    separatesNixAndHomeSubvolumes =
      assay.eq (has ".*\"@nix\".*" && has ".*\"@home\".*") true;
  }
